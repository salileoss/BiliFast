import 'dart:async';

import 'package:bili_core/api.dart' show FeedCard, VideoDetail;
import 'package:bili_core/devlog.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../player/bili_player.dart';
import '../player_ui/player_loading.dart';
import '../playback/playback_controller.dart';
import '../shared/theme.dart';
import '../video/page_playback.dart';
import '../video/pip_keeper.dart';
import '../video/player_session.dart';
import '../video/video_page.dart';
import '../video/video_route.dart';

/// The big cards' sound and 弹, kept for the app's run: muted with danmaku at launch, as the official app starts them.
abstract final class FeedInlineChoices {
  static final sound = ValueNotifier<bool>(false);
  static final danmaku = ValueNotifier<bool>(true);

  @visibleForTesting
  static void reset() {
    sound.value = false;
    danmaku.value = true;
  }
}

/// What an inline player plays: a 推荐 big card's video, or a 动态 card's.
@immutable
final class InlineVideo {
  const InlineVideo({required this.bvid, this.cid = 0, this.title = '', this.duration = 0, this.detail});

  InlineVideo.of(FeedCard card, {VideoDetail? detail})
    : this(bvid: card.bvid, cid: card.cid, title: card.title, duration: card.duration, detail: detail);

  final String bvid;
  final VideoDetail? detail;

  /// 0 when unknown: the player asks for the first part's.
  final int cid;
  final String title;

  /// Seconds; 0 when unknown.
  final int duration;
}

/// A big card as [FeedInlineHost] sees it.
abstract interface class FeedInlineCard {
  /// Its video box on screen, in global coordinates; null before it is laid out.
  Rect? videoRect();

  void inlinePlay();

  void inlinePause();
}

/// Plays the most visible video while the feed is shown and the app is in front, one at a time.
/// A new focus needs [FeedBigCardTheme.visibleToPlay] of its video on screen; the current focus can continue until
/// only [FeedBigCardTheme.visibleToKeepPlaying] remains. During scrolling only the existing player may continue;
/// new playback waits until the list has rested for [FeedBigCardTheme.autoplayAfterScroll].
class FeedInlineHost with WidgetsBindingObserver {
  FeedInlineHost({required this.viewport, required this._pip}) {
    _pip.addListener(settleSoon);
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state != AppLifecycleState.hidden && state != AppLifecycleState.paused;
  }

  /// The part of the screen the feed shows its cards in, in global coordinates.
  final Rect? Function() viewport;

  /// While a page's video is in the small window (or kept for it), no card plays: one video at a time.
  final PipKeeper _pip;

  /// Where each video stood when its player was let go or its page closed, so the card starts again there.
  final positions = <String, double>{};

  /// Upload dates and avatars missing from feed cards, fetched near the viewport.
  final metadata = <String, Future<VideoDetail>>{};

  final _cards = <FeedInlineCard>{};
  FeedInlineCard? _playing;
  bool _shown = false;
  bool _foreground = true;
  bool _queued = false;
  bool _disposed = false;
  bool _scrolling = false;
  Timer? _autoplayWait;

  @visibleForTesting
  FeedInlineCard? get playing => _playing;

  /// 首页 is the tab shown and no route is over it (a page, a sheet, ⋮'s menu).
  set shown(bool value) {
    if (value == _shown) return;
    _shown = value;
    settleSoon();
  }

  void register(FeedInlineCard card) {
    _cards.add(card);
    settleSoon();
  }

  void unregister(FeedInlineCard card) {
    _cards.remove(card);
    if (identical(_playing, card)) {
      _playing = null;
      settleSoon();
    }
  }

  /// Listen to the outer list, including ballistic scrolling. A fresh gesture cancels the idle wait.
  bool onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _disposed) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _scrolling = true;
      _autoplayWait?.cancel();
      _autoplayWait = null;
      settleSoon();
    } else if (notification is ScrollEndNotification) {
      _scrolling = false;
      _autoplayWait?.cancel();
      _autoplayWait = Timer(FeedBigCardTheme.autoplayAfterScroll, () {
        _autoplayWait = null;
        settleSoon();
      });
      settleSoon();
    }
    return false;
  }

  /// After the frame being built, once everything has its place.
  void settleSoon() {
    if (_queued || _disposed) return;
    _queued = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _queued = false;
        if (!_disposed) settle();
      })
      ..ensureVisualUpdate();
  }

  void settle() {
    final area = _shown && _foreground && !_pip.showing ? viewport() : null;
    FeedInlineCard? best;
    var bestShare = 0.0;
    var bestTop = double.infinity;
    if (area != null) {
      for (final card in _cards) {
        if ((_scrolling || _autoplayWait != null) && !identical(card, _playing)) continue;
        final box = card.videoRect();
        if (box == null || box.isEmpty || !box.overlaps(area)) continue;
        final seen = box.intersect(area);
        final share = (seen.width * seen.height) / (box.width * box.height);
        final eligible = identical(card, _playing)
            ? share > FeedBigCardTheme.visibleToKeepPlaying
            : share >= FeedBigCardTheme.visibleToPlay;
        if (eligible && (share > bestShare || (share == bestShare && box.top < bestTop))) {
          best = card;
          bestShare = share;
          bestTop = box.top;
        }
      }
    }
    for (final card in List.of(_cards)) {
      if (!identical(card, best)) card.inlinePause();
    }
    _playing = best;
    best?.inlinePlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state != AppLifecycleState.hidden && state != AppLifecycleState.paused;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      settleSoon();
    } else {
      settle();
    }
  }

  void dispose() {
    _disposed = true;
    _autoplayWait?.cancel();
    _pip.removeListener(settleSoon);
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// One big card's video (122, 123): a playback of the app's own ([PagePlayback], inline) on the shared engine, muted
/// unless the card's speaker was turned on this run. Paused it keeps its player, and plays on from there; paused for
/// [FeedBigCardTheme.releaseAfter] it lets it go. At its end it starts over, as the official card does (125). No
/// watch reports while it plays inline: they start when a page takes it over ([handOver]).
class FeedInlinePlayback extends ChangeNotifier {
  FeedInlinePlayback({
    required this._services,
    required this.video,
    required this._startAt,
    required this._released,
    Logger? logger,
  }) : _logger = logger ?? Logger.shared {
    FeedInlineChoices.sound.addListener(_applySound);
    _services.danmakuSettings.addListener(_applyFilter);
    _services.blockRules.addListener(_applyFilter);
  }

  final AppServices _services;
  final InlineVideo video;

  /// Where a new player starts.
  final double Function() _startAt;

  /// Hears where the video stood when its player was let go.
  final void Function(double seconds) _released;
  final Logger _logger;

  PagePlayback? _playback;
  PlaybackController? _controller;
  PlayerSession? _session;
  StreamSubscription<void>? _endings;
  PlayerWait? _wait;
  Timer? _release;
  bool _wanted = false;
  bool _shown = false;
  int _laps = 0;
  bool _disposed = false;

  /// Asked to play, whether it does yet or is loading.
  bool get wanted => _wanted;

  PlaybackController? get controller => _controller;
  PlayerSession? get session => _session;

  /// The video has played since its player came, so it shows over the cover.
  bool get shown => _shown && _controller != null;

  /// Times it has played to its end and started over.
  int get laps => _laps;

  /// The TV and 正在缓冲... show only while it loads: the player still starting, a load, or a wait for data past the
  /// player's grace.
  bool get loading {
    if (!_wanted || failed) return false;
    final controller = _controller;
    final session = _session;
    if (controller == null || session == null) return true;
    if (controller.phase == PlaybackPhase.failed) return false;
    final status = session.readout.status.value;
    return controller.phase == PlaybackPhase.loading ||
        status == PlayerStatus.loading ||
        status == PlayerStatus.idle ||
        (_wait?.value ?? false);
  }

  /// The player didn't start, or the video didn't load: the cover and its ▶ again.
  bool get failed => _playback?.startError != null || _controller?.phase == PlaybackPhase.failed;

  void play() {
    _release?.cancel();
    _release = null;
    if (_wanted || _disposed) return;
    _wanted = true;
    final playback = _playback;
    if (playback == null) {
      _start();
    } else if (_controller case final controller?) {
      controller.holdAutoplay(false, play: true);
      _quietly(controller.player.play, 'play');
    }
    notifyListeners();
  }

  void pause() {
    if (!_wanted || _disposed) return;
    _wanted = false;
    if (_controller case final controller?) {
      controller.holdAutoplay(true);
      _quietly(controller.player.pause, 'pause');
    }
    if (_playback != null) _release = Timer(FeedBigCardTheme.releaseAfter, release);
    notifyListeners();
  }

  void _start() {
    final at = _startAt();
    // A video left at its end (the page played it out) starts over, as the official card did after back (124).
    final start = video.duration > 0 && at > video.duration - 3 ? 0.0 : at;
    final playback = _playback = PagePlayback(
      services: _services,
      route: VideoRoute(
        bvid: video.bvid,
        cid: video.cid > 0 ? video.cid : null,
        start: start,
        title: video.title,
        detail: video.detail,
      ),
      createSession: pageSession,
      restorePage: (route) => VideoPage(route: route),
      inline: true,
    )..addListener(_playbackChanged);
    _logger.info(LogCategory.player, 'inline start', {'bvid': video.bvid, 'start': start.round()});
    playback.start();
  }

  void _playbackChanged() {
    final playback = _playback;
    if (playback == null) return;
    final controller = playback.controller;
    if (controller != null && !identical(controller, _controller)) {
      _controller = controller;
      controller.addListener(_changed);
      controller.danmaku.addListener(_changed);
      _endings = controller.endings.listen((_) => _lap());
      if (!_wanted) {
        controller.holdAutoplay(true);
        _quietly(controller.player.pause, 'pause');
      }
      _applySound();
      _applyFilter();
    }
    final session = playback.session;
    if (session != null && !identical(session, _session)) {
      _session = session;
      session.readout.status.addListener(_statusChanged);
      _wait = PlayerWait(session.readout.status)..addListener(_changed);
      _statusChanged();
    }
    _changed();
  }

  void _statusChanged() {
    if (_session?.readout.status.value == PlayerStatus.playing) _shown = true;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Played to its end: from the start again, the counts gone and the buttons dimmed from the second time on (125).
  /// The session's replay tells the watch reports, so a page taking it over later reports again.
  void _lap() {
    final session = _session;
    if (session == null || _disposed || !_wanted) return;
    _laps += 1;
    unawaited(session.replay());
    notifyListeners();
  }

  void _applySound() {
    final controller = _controller;
    if (controller == null) return;
    final muted = !FeedInlineChoices.sound.value || _services.playback.muted;
    _quietly(() => controller.player.setMuted(muted), 'mute');
  }

  /// The user's 弹幕设置 filters and 屏蔽词, as a page's danmaku session applies them.
  void _applyFilter() =>
      _controller?.danmaku.setFilter(_services.danmakuSettings.value.filter, _services.blockRules.rules);

  /// The playback for a page to take over as it stands (with sound, from where it is), playing; null while it has
  /// none to give. The card is left with its cover until it plays again.
  PagePlayback? handOver() {
    final playback = _playback;
    final controller = _controller;
    // A failed one isn't worth taking: the page opens the video afresh.
    if (playback == null || controller == null || _session == null || failed) return null;
    _logger.info(LogCategory.player, 'inline handed over', {'bvid': video.bvid});
    _forget();
    controller.holdAutoplay(false, play: true);
    if (controller.phase == PlaybackPhase.playing) _quietly(controller.player.play, 'play');
    _wanted = false;
    notifyListeners();
    return playback;
  }

  /// Stops and frees the player; the card plays again from where it stood.
  void release() {
    final playback = _playback;
    if (playback == null) return;
    final at = _controller?.currentSeconds;
    _forget();
    _wanted = false;
    playback.close();
    if (at != null) _released(at);
    _logger.info(LogCategory.player, 'inline released', {'bvid': video.bvid});
    _changed();
  }

  void _forget() {
    _release?.cancel();
    _release = null;
    _playback?.removeListener(_playbackChanged);
    _playback = null;
    _controller?.removeListener(_changed);
    _controller?.danmaku.removeListener(_changed);
    _controller = null;
    unawaited(_endings?.cancel());
    _endings = null;
    _session?.readout.status.removeListener(_statusChanged);
    _session = null;
    _wait?.dispose();
    _wait = null;
    _shown = false;
    _laps = 0;
  }

  @override
  void dispose() {
    release();
    _disposed = true;
    FeedInlineChoices.sound.removeListener(_applySound);
    _services.danmakuSettings.removeListener(_applyFilter);
    _services.blockRules.removeListener(_applyFilter);
    super.dispose();
  }

  static void _quietly(Future<void> Function() action, String what) {
    unawaited(
      Future.sync(action).catchError((Object error) {
        Logger.shared.warn(LogCategory.player, 'inline $what failed', {'error': '$error'});
      }),
    );
  }
}
