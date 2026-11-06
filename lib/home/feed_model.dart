import 'dart:async' show Completer, TimeoutException, Timer, unawaited;
import 'dart:io' show IOException;
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';

import '../app/form_factor.dart';
import '../devtools/crash_log.dart';
import '../playback/playback_controller.dart' show PlaybackFailure;
import '../shared/cover_format.dart';
import '../shared/image_disk_cache.dart';
import '../shared/remote_image.dart' show secureImageUrl;
import '../video/player_prefs.dart';
import 'feed_preferences.dart';

/// The words for a failed request: the BiliError's or PlaybackFailure's message (a 番剧 link), a network message
/// when the connection failed or timed out, otherwise [fallback].
String requestFailureMessage(Object error, {String fallback = '加载失败，请稍后重试'}) {
  if (error is BiliError) return error.userMessage;
  if (error is PlaybackFailure) return error.userMessage;
  // package:http's ClientException, which the app does not import, from both transports.
  if (error is IOException || error is TimeoutException || '$error'.startsWith('ClientException')) {
    return '网络连接失败，请检查网络后重试';
  }
  return fallback;
}

/// Where the cards on screen came from.
enum FeedSource {
  /// The official app's feed (`/x/v2/feed/index`), personalised by the app token; its pages count from 0.
  official,

  /// The website's (`/x/web-interface/wbi/index/top/feed/rcmd`); its pages count from 1.
  web,
}

/// A 不感兴趣, 撤销 or reason that didn't go through; the card is already back as it was.
sealed class DislikeFailure {
  const DislikeFailure();
}

/// Bilibili or the connection said no, in [message]'s words.
final class DislikeError extends DislikeFailure {
  const DislikeError(this.message);

  final String message;
}

/// The app token was turned down (-101, -2) or isn't held. The web login is fine, so this is no 需要登录: the
/// token's confirm is what answers it.
final class DislikeTokenRefused extends DislikeFailure {
  const DislikeTokenRefused();
}

/// A failure's log fields: its type, and Bilibili's code or the HTTP status. Never `'$error'`, as a transport
/// error's text can carry the request's URL and with it the app token.
Map<String, Object> feedLogFields(Object error) => {
  'error': '${error.runtimeType}',
  if (error case BiliAPIError(:final code)) 'code': code,
  if (error case BiliHTTPError(:final status)) 'status': status,
};

typedef _Page = ({List<FeedCard> cards, List<FeedCard> remaining, FeedSource source, int index, int received});

/// A fetch belongs to one account session, including an armed pull later joined by its release.
class _FeedRequest {
  const _FeedRequest(this.session, this.owner);

  final int session;
  final int? owner;
}

/// Page 1 asked for while a pull is held past its trigger, kept out of sight until the pull lets go there.
class _EarlyPage {
  _EarlyPage({
    required this.generation,
    required this.official,
    required this.token,
    required this.started,
    required this.warm,
    required this.page,
    required this.request,
  });

  /// What it was asked under: a refresh since, another source or another token make it stale.
  final int generation;
  final bool official;
  final AppToken? token;

  final DateTime started;

  /// The warm sent as the pull armed; the release that takes this page sends none.
  final _Warm warm;
  final Future<_Page> page;
  final _FeedRequest request;

  /// When it answered or failed; null while still out.
  DateTime? landed;
  _Page? answer;
  bool failed = false;

  /// Whether the pull is past its trigger now.
  bool armed = true;

  /// Whether its first screen's covers have been asked for, and how they are doing if any were.
  bool warmed = false;
  _CoverCount? covers;
}

/// Why a refresh asked for no covers for its cards.
enum CoverSkip { noGrid, unmounted, noLayout, noRows }

/// A refresh's [PictureSession.warm]: [none] when it sent none (the connection was open, one was already out, the
/// top card's cover was on another host, or no session).
enum _WarmState { none, pending, ok, failed }

class _Warm {
  _Warm(Future<bool>? sent) : state = sent == null ? _WarmState.none : _WarmState.pending {
    if (sent != null) unawaited(sent.then((ok) => state = ok ? _WarmState.ok : _WarmState.failed));
  }

  _WarmState state;
}

/// What [FeedModel.beforeShow] started for a refresh's cards: a future per cover it asked for, true once that cover
/// is ready and false if it failed; or, having asked for none, why.
@immutable
class CoverPrefetch {
  const CoverPrefetch(this.covers) : skipped = null;

  const CoverPrefetch.skipped(CoverSkip this.skipped) : covers = const [];

  final List<Future<bool>> covers;
  final CoverSkip? skipped;
}

/// A [CoverPrefetch]'s covers, counted as they finish.
class _CoverCount {
  _CoverCount(
    CoverPrefetch prefetch, {
    required DateTime Function() now,
    required this.warm,
    required this.warming,
    required this.format,
  }) : of = prefetch.covers.length,
       skipped = prefetch.skipped,
       asked = now() {
    for (final cover in prefetch.covers) {
      unawaited(
        cover.then<void>(
          (ok) {
            if (ok) {
              ready++;
              readyMs.add(now().difference(asked).inMilliseconds);
            } else {
              failed++;
            }
            _check();
          },
          onError: (Object _) {
            failed++;
            _check();
          },
        ),
      );
    }
  }

  final int of;
  final CoverSkip? skipped;

  /// When they were asked for, as the answer landed.
  final DateTime asked;

  /// Whether the picture connection was open then, and whether a warm was still opening it.
  final bool warm;
  final bool warming;

  /// How 推荐's covers were asked ([CoverFormat.name]).
  final String format;

  int ready = 0;
  int failed = 0;

  /// Each ready cover's ms after [asked], in the order they came.
  final readyMs = <int>[];

  final _done = Completer<void>();

  bool get finished => ready + failed == of;

  /// Completes once every cover is ready or failed.
  Future<void> get done => _done.future;

  void _check() {
    if (finished && !_done.isCompleted) _done.complete();
  }
}

/// A card after 不感兴趣: the reason it went with, and the 反馈 picked in the reasons sheet, if any.
@immutable
class CardDislike {
  const CardDislike(this.reason, {this.feedback});

  final FeedReason reason;
  final FeedReason? feedback;
}

/// The 推荐 feed (port of FeedModel.swift): page 1 on refresh, then the next index for every load more. With the app
/// token and 开发者's 推荐 on 官方 it reads the official app's feed; without the token it never asks it, since the
/// feed is generic without one. When the official feed answers that the token is refused, the same load is done
/// from the website's, so 推荐 never goes blank.
///
/// A refresh with cards on screen keeps them as the official app does (122): its page on top, then 刚刚看到这里，点击刷新
/// ([dividerAt]), then the cards before it, with load more still adding at the bottom.
class FeedModel extends ChangeNotifier {
  FeedModel({
    required this._client,
    Logger? logger,
    bool Function()? officialWanted,
    bool Function()? pad,
    DateTime Function()? now,
    PictureSession? Function()? pictures,
    String Function()? coverFormat,
    this._preferences,
    int? Function()? accountMid,
    this._minimumRefresh = FeedModel.minimumRefresh,
    this._webPage,
  }) : _accountMid = accountMid ?? (() => null),
       _logger = logger ?? Logger.shared,
       _officialWanted = officialWanted ?? (() => PlayerPrefs.shared.officialFeed),
       _pad = pad ?? (() => FormFactor.device.isPad),
       _now = now ?? DateTime.now,
       _pictures = pictures ?? (() => ImageDiskCache.session),
       _coverFormat = coverFormat ?? (() => CoverFormat.shared.name);

  static const emptyMessage = '暂时没有推荐的视频';
  static const endMessage = '没有更多了';

  /// How long a pull's early page, once in, still serves a pull armed again after the last one went back under its
  /// trigger. Within it an arming asks nothing, so wiggling across the trigger costs one call.
  static const earlyReuse = Duration(seconds: 10);

  /// The shortest a refresh that replaces cards on screen takes, from its start (the tap, the pull's release or the
  /// account's change) to the swap, so its TV stays up that long; the covers asked for as the answer lands load
  /// meanwhile. A later answer swaps at once; the first load, with no cards to replace, is never held.
  static const minimumRefresh = Duration(milliseconds: 1500);

  /// An optional variety page must not hold a successful first response indefinitely.
  static const extraPageTimeout = Duration(seconds: 2);

  /// A shown page logs `feed covers done` this long after asking for its covers, if some are still out.
  static const coversDoneAfter = Duration(seconds: 10);

  /// The most cards a refresh leaves on screen, its page included; the oldest go from the bottom. 首页 lives as long as
  /// the app, and each refresh would otherwise add its page for good, every one walked by each refresh and load more.
  static const keptCards = 200;

  /// Pages in a row that may add nothing before a load more gives up and the feed counts as [exhausted].
  static const _emptyPagesAllowed = 3;

  /// The official answers that mean the token is no longer taken (账号未登录, Access Key错误).
  static const _refusedCodes = {-101, -2};

  final BiliClient _client;
  final Logger _logger;
  final bool Function() _officialWanted;

  /// Whether the official feed is asked as the iPad (`mobi_app=android_i`), which is sent no big inline card.
  final bool Function() _pad;
  final DateTime Function() _now;
  final PictureSession? Function() _pictures;
  final String Function() _coverFormat;
  final Duration _minimumRefresh;
  final FeedPreferences? _preferences;
  final int? Function() _accountMid;
  _FeedRequest? _request;
  List<FeedCard> _pending = const [];
  int _pendingSession = -1;
  int? _pendingOwner;

  /// Answers the website's pages in place of the client: tests whose cards the web feed can't send (the big card).
  final Future<List<FeedCard>> Function(int index)? _webPage;
  List<FeedCard> _cards = const [];
  List<FeedCard> _newest = const [];
  int? _dividerAt;
  bool _loading = false;
  String? _error;
  bool _exhausted = false;
  int _nextWebIndex = 2;
  int _nextOfficialIndex = 1;
  FeedSource? _source;

  /// Set when the official feed refused the token, so the rest of this scroll asks the website's; a refresh tries
  /// the official one again.
  bool _officialRefused = false;

  final _dislikes = <String, CardDislike>{};
  final _dislikeBusy = <String>{};

  /// Called with a refresh's cards just before they take the top of [cards], which still hold the ones there, and with
  /// a held pull's page as soon as it is in: it starts getting the first screen's covers ready. Nothing waits on them;
  /// a cover still loading when its card shows pops in over the placeholder rather than holding the swap.
  CoverPrefetch Function(List<FeedCard> fresh)? beforeShow;

  /// A refresh changes the list (its page on top, or all of it), so a load more already running must not append.
  int _generation = 0;

  _EarlyPage? _early;
  final _coverTimers = <Timer>{};

  /// Each refresh's [minimumRefresh] still running, ended by dispose so no refresh is left waiting.
  final _holds = <Timer, Completer<void>>{};
  bool _disposed = false;

  List<FeedCard> get cards => _cards;

  /// The last refresh's page, at the top of [cards]: the list [beforeShow] was handed for it.
  List<FeedCard> get newest => _newest;

  /// How many of [cards] are above 刚刚看到这里，点击刷新: [newest]'s, when cards from before that refresh follow them.
  /// Null after the first load and a [refresh] that replaced everything.
  int? get dividerAt => _dividerAt;

  bool get loading => _loading;

  /// Where the last page shown came from; null before the first.
  FeedSource? get source => _source;

  /// Old cards may remain drawn while an account's replacement is fetched. They must not play or count as the
  /// new account's exposure until a response for that identity has been accepted.
  bool get belongsToCurrentAccount => _source != null &&
      _pendingSession == _client.sessionGeneration && _pendingOwner == _accountMid();

  /// Why the cards are missing (nothing on screen) or the next page is (under the cards); endless scroll waits for
  /// [retry] instead of asking again by itself.
  String? get error => _error;

  /// The last load more got only pages of cards already shown (or ads); scrolling stops asking until [retry].
  bool get exhausted => _exhausted;

  /// Whether endless scroll may ask for the next page now.
  bool get canLoadMore => _cards.isNotEmpty && !_loading && _error == null && !_exhausted;

  /// Whether the next load would read the official feed.
  bool get wantsOfficial => _officialPossible && !_officialRefused;

  /// Whether a refresh would read the official feed.
  bool get _officialPossible => _officialWanted() && _client.appToken != null;

  /// The card's 不感兴趣, while it stands.
  CardDislike? dislikeOf(FeedCard card) => _dislikes[card.bvid];

  /// Page 1 again, on top of the cards shown, or in place of them all when [replace] (another account's or token's
  /// cards must not stay). With cards on screen a failure (or an empty page) keeps them, and its words come back for a
  /// toast; with none, it becomes [error]. Null otherwise.
  ///
  /// A [pulled] refresh takes the page [pullArmed] asked for, if it still counts, instead of asking again; any other
  /// refresh drops it. With cards on screen, a page that comes sooner than [minimumRefresh] waits out the rest before
  /// it shows, counted for a held pull from when it armed, so a long hold still shows the page at the release; a
  /// failure doesn't wait.
  Future<String?> refresh({bool pulled = false, bool replace = false}) async {
    final early = pulled ? _joinable() : null;
    _early = null;
    final request = early?.request ?? _beginRequest();
    final hold = _cards.isEmpty ? null : _hold(since: early?.started);
    final mine = ++_generation;
    _loading = true;
    _officialRefused = false;
    final warm = early == null ? _openPictures() : early.warm;
    _notify();
    final heldMs = early == null ? null : _now().difference(early.started).inMilliseconds;
    String? failure;
    try {
      final page = await (early?.page ?? _fetch(refresh: true, request: request));
      if (mine != _generation || !_currentRequest(request)) return null;
      if (early != null && early.official && page.source == FeedSource.web) _officialRefused = true;
      final fresh = _appending(page.cards, const []);
      final shownIds = {for (final card in _cards) card.bvid};
      _logPage(page, fresh.where((card) => !shownIds.contains(card.bvid)).length);
      if (fresh.isEmpty) {
        failure = emptyMessage;
      } else {
        final asked = _askCovers(fresh);
        // A held pull's covers were asked for when its page came in; those are the ones that can be ready by now.
        final shown = early?.covers ?? asked;
        if (hold != null) {
          await hold;
          if (mine != _generation || !_currentRequest(request)) return null;
        }
        _logCovers(shown, heldMs: heldMs);
        if (shown != null) _whenCoversDone(shown, early: heldMs != null, warm: warm);
        final kept = replace ? const <FeedCard>[] : _keptUnder(fresh);
        _cards = kept.isEmpty ? fresh : [...fresh, ...kept];
        _newest = fresh;
        _dividerAt = kept.isEmpty ? null : fresh.length;
        _advance(page);
        _source = page.source;
        _pending = page.remaining;
        _pendingSession = request.session;
        _pendingOwner = request.owner;
        _dislikes.clear();
        _error = null;
        _exhausted = false;
      }
    } catch (error) {
      if (mine != _generation || !_currentRequest(request)) return null;
      _logger.warn(LogCategory.ui, 'feed refresh failed', feedLogFields(error));
      failure = requestFailureMessage(error);
    } finally {
      if (!_disposed && mine == _generation) {
        _loading = false;
        if (failure != null && _cards.isEmpty) _error = failure;
        _notify();
      }
    }
    return _cards.isNotEmpty ? failure : null;
  }

  Future<void> loadMore() async {
    if (_loading) return;
    if (_cards.isEmpty) {
      await refresh();
      return;
    }
    final mine = _generation;
    final request = _beginRequest();
    _loading = true;
    _error = null;
    _exhausted = false;
    _notify();
    try {
      // A page of cards already shown (or only ads) adds nothing, and then no card appears to ask for the next one;
      // ask on, a few times.
      var added = 0;
      if (_pendingSession != request.session || _pendingOwner != request.owner) _pending = const [];
      if (_pending.isNotEmpty) {
        final pending = _pending;
        _pending = const [];
        final selected = _preferences?.select(pending, accountMid: request.owner, limit: pending.length) ?? pending;
        final before = _cards.length;
        _cards = _appending(selected, _cards);
        added = _cards.length - before;
        final source = _source!;
        _logPage((
          cards: selected,
          remaining: const <FeedCard>[],
          source: source,
          index: (source == FeedSource.official ? _nextOfficialIndex : _nextWebIndex) - 1,
          received: pending.length,
        ), added);
      }
      for (var attempt = 0; attempt < _emptyPagesAllowed && added == 0; attempt++) {
        final page = await _fetch(refresh: false, request: request);
        if (mine != _generation || !_currentRequest(request)) return;
        final before = _cards.length;
        _cards = _appending(page.cards, _cards);
        _advance(page);
        _source = page.source;
        added = _cards.length - before;
        _logPage(page, added);
      }
      _exhausted = added == 0;
    } catch (error) {
      if (mine != _generation || !_currentRequest(request)) return;
      _logger.warn(LogCategory.ui, 'feed load more failed', feedLogFields(error));
      _error = requestFailureMessage(error);
    } finally {
      if (mine == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  /// 重试 under a message: page 1 when no cards are shown (the refresh is what failed), otherwise the next page.
  Future<void> retry() => _cards.isEmpty ? refresh() : loadMore();

  /// A pull is held past its trigger: page 1 is asked for now and its first screen's covers once it is in, but
  /// nothing changes on screen until a [refresh] with `pulled` takes it. One still out, or one in within
  /// [earlyReuse] of the pull going back under, is kept instead of asking again.
  void pullArmed() {
    if (_disposed) return;
    final held = _early;
    if (held != null && _current(held) && !_expired(held)) {
      held.armed = true;
      _warm(held);
      return;
    }
    final warm = _openPictures();
    final request = _beginRequest();
    final early = _EarlyPage(
      generation: _generation,
      official: _officialPossible,
      token: _client.appToken,
      started: _now(),
      warm: warm,
      page: _fetch(refresh: true, early: true, request: request),
      request: request,
    );
    _early = early;
    unawaited(
      early.page.then(
        (page) {
          early
            ..landed = _now()
            ..answer = page;
          _warm(early);
        },
        onError: (Object error) {
          early
            ..landed = _now()
            ..failed = true;
          if (!_disposed && identical(_early, early)) {
            _logger.warn(LogCategory.ui, 'feed early page failed', feedLogFields(error));
          }
        },
      ),
    );
  }

  /// The pull went back under its trigger, or ended without refreshing: the early page stays out of sight, kept for
  /// [earlyReuse] in case the pull comes back.
  void pullDisarmed() {
    final early = _early;
    if (early == null || !early.armed) return;
    early.armed = false;
    _logger.info(LogCategory.ui, 'feed pull cancelled', {
      'answered': early.landed != null,
      'heldMs': _now().difference(early.started).inMilliseconds,
    });
  }

  bool _current(_EarlyPage early) =>
      early.generation == _generation &&
      early.official == _officialPossible &&
      _currentRequest(early.request) &&
      identical(early.token, _client.appToken);

  bool _expired(_EarlyPage early) {
    final landed = early.landed;
    return !early.armed && landed != null && _now().difference(landed) > earlyReuse;
  }

  /// The early page a pull's refresh may take: a failed one is asked again, as the release is a new request.
  _EarlyPage? _joinable() {
    final held = _early;
    if (held == null || held.failed || !_current(held) || _expired(held)) return null;
    return held;
  }

  /// Asks for the first screen's covers of an early page that is in while its pull is armed, so they are ready by
  /// the release; the refresh asks again then, finding them done or joining their downloads.
  void _warm(_EarlyPage early) {
    final answer = early.answer;
    if (_disposed || answer == null || early.warmed || !early.armed) return;
    if (!identical(_early, early) || !_current(early)) return;
    early.warmed = true;
    final fresh = _appending(answer.cards, const []);
    if (fresh.isNotEmpty) early.covers = _askCovers(fresh);
  }

  /// Completes [_minimumRefresh] after [since] (now by default), or at once on dispose; null when none is left.
  Future<void>? _hold({DateTime? since}) {
    final left = _minimumRefresh - (since == null ? Duration.zero : _now().difference(since));
    if (left <= Duration.zero) return null;
    final done = Completer<void>();
    late final Timer timer;
    timer = Timer(left, () {
      _holds.remove(timer);
      done.complete();
    });
    _holds[timer] = done;
    return done.future;
  }

  /// Opens the picture connection while page 1 is out, so the covers it brings start on it. Before any picture has
  /// downloaded, the top card's cover is the one asked for, or with no cards (the first load) the host itself.
  _Warm _openPictures() {
    final cover = _cards.firstOrNull?.cover;
    return _Warm(_pictures()?.warm(picture: cover == null || cover.isEmpty ? null : secureImageUrl(cover)));
  }

  /// Hands [fresh] to [beforeShow]; null if it threw, which goes to the crash log.
  _CoverCount? _askCovers(List<FeedCard> fresh) {
    final hook = beforeShow;
    final pictures = _pictures();
    try {
      return _CoverCount(
        hook == null ? const CoverPrefetch.skipped(CoverSkip.noGrid) : hook(fresh),
        now: _now,
        warm: pictures?.open ?? false,
        warming: pictures?.warming ?? false,
        format: _coverFormat(),
      );
    } catch (error, stack) {
      CrashLog.report(error, stack, source: 'feed covers', logger: _logger);
      return null;
    }
  }

  /// As the cards show: how many of the first screen's covers were ready then and how many had failed (the rest still
  /// loading), or why none were asked for, and whether the page was a held pull's ([heldMs] since it was asked for).
  void _logCovers(_CoverCount? count, {int? heldMs}) {
    if (count == null) return;
    _logger.info(LogCategory.ui, 'feed covers', {
      'ready': count.ready,
      'failed': count.failed,
      'of': count.of,
      if (count.skipped case final why?) 'why': why.name,
      'early': heldMs != null,
      'heldMs': ?heldMs,
    });
  }

  /// Logs `feed covers done` once a shown page's covers are all ready or failed, or [coversDoneAfter] after they were
  /// asked for: when the 3rd and the last ready one came (ms after asking), whether the picture connection was open or
  /// opening then, what the page's [warm] came to, and the format the covers were asked in.
  void _whenCoversDone(_CoverCount count, {required bool early, required _Warm warm}) {
    if (count.of == 0 || _disposed) return;
    var logged = false;
    void log() {
      if (logged || _disposed) return;
      logged = true;
      _logger.info(LogCategory.ui, 'feed covers done', {
        'of': count.of,
        'ready': count.ready,
        'failed': count.failed,
        'thirdMs': ?count.readyMs.elementAtOrNull(2),
        'lastMs': ?count.readyMs.lastOrNull,
        'warm': count.warm,
        if (count.warming) 'warming': true,
        'warmed': warm.state.name,
        'early': early,
        if (!count.finished) 'timedOut': true,
        'format': count.format,
      });
    }

    if (count.finished) return log();
    late final Timer timer;
    void finish() {
      timer.cancel();
      _coverTimers.remove(timer);
      log();
    }

    timer = Timer(coversDoneAfter - _now().difference(count.asked), finish);
    _coverTimers.add(timer);
    unawaited(count.done.then((_) => finish()));
  }

  _FeedRequest _beginRequest() => _request = _FeedRequest(_client.sessionGeneration, _accountMid());

  bool _currentRequest(_FeedRequest request) =>
      !_disposed && identical(_request, request) &&
      request.session == _client.sessionGeneration && request.owner == _accountMid();

  void _checkRequest(_FeedRequest request) {
    if (!_currentRequest(request)) throw const BiliSessionChangedError();
  }

  /// Keeps the server's personalized candidates. A mostly repeated refresh can ask one more page, then the local
  /// memory chooses a batch of the original size. Fetching never records a video as seen.
  Future<_Page> _fetch({required bool refresh, required _FeedRequest request, bool early = false}) async {
    var page = await _fetchPage(refresh: refresh, early: early, request: request);
    _checkRequest(request);
    final preferences = _preferences;
    if (preferences == null) return page;
    final first = _appending(page.cards, const []);
    var candidates = first;
    if (refresh && first.isNotEmpty && preferences.unseenCount(first, accountMid: request.owner) * 2 < first.length) {
      try {
        _checkRequest(request);
        final extraIndex = page.index + 1;
        // Stay on the first answer's source. A refused optional page must not start another fallback request.
        final extraFuture = page.source == FeedSource.official
            ? _client.officialFeed(index: extraIndex, pad: _pad())
            : (_webPage?.call(extraIndex) ?? _client.recommendFeed(index: extraIndex));
        final extra = await extraFuture.timeout(extraPageTimeout);
        _checkRequest(request);
        candidates = _appending(extra, first);
        page = (cards: candidates, remaining: const <FeedCard>[], source: page.source, index: extraIndex,
          received: page.received + extra.length);
      } catch (error) {
        _checkRequest(request);
        _logger.warn(LogCategory.ui, 'feed extra page unavailable', feedLogFields(error));
      }
    }
    final selected = preferences.select(candidates, accountMid: request.owner, limit: first.length);
    final selectedIds = {for (final card in selected) card.bvid};
    return (cards: selected,
      remaining: refresh ? candidates.where((card) => !selectedIds.contains(card.bvid)).take(keptCards).toList() : const <FeedCard>[],
      source: page.source, index: page.index, received: page.received);
  }

  /// One page from the source this load should read. The indexes only move when its caller accepts the answer.
  /// An [early] page leaves the refused token for its refresh to note.
  Future<_Page> _fetchPage({required bool refresh, required _FeedRequest request, bool early = false}) async {
    _checkRequest(request);
    if (early ? _officialPossible : wantsOfficial) {
      final index = refresh ? 0 : _nextOfficialIndex;
      try {
        final cards = await _client.officialFeed(index: index, pad: _pad());
        return (cards: cards, remaining: const <FeedCard>[], source: FeedSource.official, index: index, received: cards.length);
      } catch (error) {
        _checkRequest(request);
        if (!_refused(error)) rethrow;
        _logger.warn(LogCategory.ui, 'official feed refused, web feed instead', feedLogFields(error));
        if (!early) _officialRefused = true;
      }
    }
    // The first launch reaches here before the account check has fetched the fingerprint cookies.
    if (refresh) await _client.ensureRiskCookies();
    _checkRequest(request);
    final index = refresh ? 1 : _nextWebIndex;
    final cards = await (_webPage?.call(index) ?? _client.recommendFeed(index: index));
    return (cards: cards, remaining: const <FeedCard>[], source: FeedSource.web, index: index, received: cards.length);
  }

  static bool _refused(Object error) =>
      error is BiliNoAppTokenError || error is BiliAPIError && _refusedCodes.contains(error.code);

  void _advance(_Page page) {
    switch (page.source) {
      case FeedSource.official:
        _nextOfficialIndex = page.index + 1;
      case FeedSource.web:
        _nextWebIndex = page.index + 1;
    }
  }

  /// 不感兴趣 with [reason] (one of the card's [FeedDislike.reasons]): the card turns over at once and turns back if
  /// the call fails, which comes back for the page. Taps on a card whose call is still out are dropped.
  Future<DislikeFailure?> dislike(FeedCard card, FeedReason reason) async {
    final data = card.dislike;
    final key = card.bvid;
    if (data == null || _dislikes.containsKey(key) || !_dislikeBusy.add(key)) return null;
    _dislikes[key] = CardDislike(reason);
    _notify();
    try {
      await _send(data, reason);
      return null;
    } catch (error) {
      _logger.warn(LogCategory.ui, 'feed dislike failed', feedLogFields(error));
      _dislikes.remove(key);
      return _failure(error);
    } finally {
      _dislikeBusy.remove(key);
      _notify();
    }
  }

  /// 撤销: the card comes back at once, and goes over again if the server keeps the 不感兴趣.
  Future<DislikeFailure?> undo(FeedCard card) async {
    final data = card.dislike;
    final key = card.bvid;
    final standing = _dislikes[key];
    if (data == null || standing == null || !_dislikeBusy.add(key)) return null;
    _dislikes.remove(key);
    _notify();
    final reason = standing.reason;
    try {
      await _client.feedDislikeCancel(
        goto: data.goto,
        id: data.id,
        reasonId: reason.kind == FeedReasonKind.dislike ? reason.id : null,
        feedbackId: reason.kind == FeedReasonKind.feedback ? reason.id : null,
      );
      return null;
    } catch (error) {
      _logger.warn(LogCategory.ui, 'feed dislike undo failed', feedLogFields(error));
      _dislikes[key] = standing;
      return _failure(error);
    } finally {
      _dislikeBusy.remove(key);
      _notify();
    }
  }

  /// The reasons sheet's pick on a card already turned over; it is forgotten again if the call fails.
  Future<DislikeFailure?> sendReason(FeedCard card, FeedReason feedback) async {
    final data = card.dislike;
    final key = card.bvid;
    final standing = _dislikes[key];
    if (data == null || standing == null || !_dislikeBusy.add(key)) return null;
    _dislikes[key] = CardDislike(standing.reason, feedback: feedback);
    _notify();
    try {
      await _send(data, feedback);
      return null;
    } catch (error) {
      _logger.warn(LogCategory.ui, 'feed dislike reason failed', feedLogFields(error));
      if (_dislikes[key]?.feedback == feedback) _dislikes[key] = standing;
      return _failure(error);
    } finally {
      _dislikeBusy.remove(key);
      _notify();
    }
  }

  static DislikeFailure _failure(Object error) =>
      _refused(error) ? const DislikeTokenRefused() : DislikeError(requestFailureMessage(error));

  Future<void> _send(FeedDislike data, FeedReason reason) => _client.feedDislike(
    goto: data.goto,
    id: data.id,
    reasonId: reason.kind == FeedReasonKind.dislike ? reason.id : null,
    feedbackId: reason.kind == FeedReasonKind.feedback ? reason.id : null,
  );

  void _logPage(_Page page, int added) => _logger.info(LogCategory.ui, 'feed page', {
    'source': page.source.name,
    'index': page.index,
    'got': page.received,
    'new': added,
    'overlap': page.cards.length - added,
    'recentlySeen': page.cards.length - (_preferences?.unseenCount(page.cards, accountMid: _accountMid()) ?? page.cards.length),
    'uploaders': {for (final card in page.cards) if (card.ownerMid > 0) card.ownerMid}.length,
  });

  /// The cards on screen that stay under a refresh's [fresh] page: not one it brings again, nor one turned over by
  /// 不感兴趣 (its user asked not to see it), and no more than [keptCards] in all.
  List<FeedCard> _keptUnder(List<FeedCard> fresh) {
    final shown = {for (final card in fresh) card.bvid};
    return [
      for (final card in _cards)
        if (!shown.contains(card.bvid) && !_dislikes.containsKey(card.bvid)) card,
    ].take(math.max(keptCards - fresh.length, 0)).toList();
  }

  /// The feed repeats videos across pages, and the grid must not show one twice.
  static List<FeedCard> _appending(List<FeedCard> page, List<FeedCard> cards) {
    final seen = {for (final card in cards) card.bvid};
    return [
      ...cards,
      for (final card in page)
        if (seen.add(card.bvid)) card,
    ];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _coverTimers) {
      timer.cancel();
    }
    _coverTimers.clear();
    for (final MapEntry(key: timer, value: done) in _holds.entries) {
      timer.cancel();
      done.complete();
    }
    _holds.clear();
    super.dispose();
  }
}
