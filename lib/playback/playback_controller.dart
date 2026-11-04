import 'dart:async';
import 'dart:io' show FileSystemException, IOException, ProcessInfo;
import 'dart:math';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart';
import 'package:bili_core/logic.dart';
import 'package:bili_core/shared.dart';
import 'package:flutter/foundation.dart';

import '../player/bili_player.dart';
import '../player/playback_clock.dart';
import 'codec_memory.dart';
import 'danmaku_feed.dart';
import 'overlay_stats.dart';
import 'playing_stream.dart';
import 'seek_timer.dart';

typedef StartTimer = Timer Function(Duration delay, void Function() callback);

enum PlaybackPhase { idle, loading, playing, failed }

enum PlaybackFailure implements Exception {
  /// Every codec left is one this phone's codec memory refuses.
  noPlayableCodec('本机无法播放这个视频的任何编码，可重启应用后重试'),

  /// Every codec failed in this playback, without a verdict worth remembering.
  unplayable('这个视频暂时无法在本机播放，请稍后重试'),
  network('网络连接中断，请检查网络后重试'),

  /// 番剧 and other PGC pages: the view redirects, and their playurl is another API.
  unsupported('暂不支持播放此类视频'),

  /// A cached part this phone's player can't decode: its files hold one codec, so there is nothing to fall back to.
  localUnplayable('本机无法播放这个缓存视频的编码'),

  /// A cached part whose files are gone or can't be read.
  localMissing('缓存文件已损坏或丢失，请删除后重新缓存');

  const PlaybackFailure(this.userMessage);

  final String userMessage;
}

/// Moments the speed test measures, emitted where the controller logs them.
sealed class PlaybackMark {
  const PlaybackMark();
}

final class FirstFrame extends PlaybackMark {
  const FirstFrame(this.ms, {required this.timed});

  final double ms;

  /// False when the load waited on the user (loaded paused), so [ms] means nothing.
  final bool timed;
}

final class SeekResumed extends PlaybackMark {
  const SeekResumed(this.ms);

  final double ms;
}

final class Stall extends PlaybackMark {
  const Stall(this.atSeconds);

  final double atSeconds;
}

final class MemoryWarning extends PlaybackMark {
  const MemoryWarning(this.rssBytes);

  final int rssBytes;
}

/// Business codes that say the video itself is gone or hidden; the unsigned view would only say it again.
const _videoUnavailable = {-404, 62002, 62004, 62012};

/// The video and part number a link names. The unsigned view endpoint answers 412 to dart:io (the spike, and every
/// open on Windows) while its WBI-signed twin works, so a BV link asks the signed one first. Only the signed view
/// says when a video redirects (番剧); the unsigned one has no such field. [onDetail] hears the signed view's answer
/// when it is the one that resolved the link.
Future<(VideoView, int?)> resolveVideoLink(BiliClient client, VideoLink link,
    {Logger? logger, void Function(VideoDetail detail)? onDetail}) async {
  final log = logger ?? Logger.shared;
  Future<VideoView> signedView({String? bvid, int? aid}) async {
    final detail = await client.videoDetail(bvid: bvid, aid: aid);
    onDetail?.call(detail);
    if (detail.redirectURL != null) {
      log.info(LogCategory.player, 'view redirects, not playable here', {'bvid': detail.bvid});
      throw PlaybackFailure.unsupported;
    }
    return _viewOf(detail);
  }

  await client.ensureRiskCookies();
  if (link is BvidLink) {
    try {
      return (await signedView(bvid: link.id), link.page);
    } on BiliError catch (error) {
      // Only a refusal is worth asking the unsigned view; a timeout or a lost connection would cost as long a wait.
      final refused = error is BiliHTTPError || (error is BiliAPIError && !_videoUnavailable.contains(error.code));
      if (!refused) rethrow;
      log.warn(LogCategory.player, 'signed view failed, trying the unsigned view', {'error': '$error'});
    }
    return (await client.view(bvid: link.id), link.page);
  }
  try {
    final resolved = await client.resolve(link);
    return (resolved.view, resolved.page);
  } on BiliHTTPError catch (error) {
    if (error.status != 412 || link is! AidLink) rethrow;
    log.warn(LogCategory.player, 'view refused, trying the signed view', {'status': error.status});
    return (await signedView(aid: link.id), link.page);
  }
}

VideoView _viewOf(VideoDetail detail) =>
    VideoView(bvid: detail.bvid, aid: detail.aid, title: detail.title, owner: detail.owner.name, pages: detail.pages);

/// A finished 离线缓存 part as the controller plays it: what the page shows of it, its two files, and its saved
/// danmaku (none when [danmakuFolder] is null).
@immutable
final class LocalVideo {
  const LocalVideo({
    required this.view,
    required this.page,
    required this.files,
    this.qualityName = '',
    this.danmakuFolder,
    this.danmakuSegments = 0,
  });

  final VideoView view;
  final VideoPage page;
  final LocalPlaybackRequest files;
  final String qualityName;
  final String? danmakuFolder;
  final int danmakuSegments;
}

enum ItemFailure { format, network, unknown }

/// When only AVPlayer's error log saw the failure (an expired URL's 403), the code is the HTTP status and the
/// domain CoreMedia's; Swift counted those as network failures too.
ItemFailure classifyFailure(PlayerFailed event) {
  if (event.formatRejected) return ItemFailure.format;
  final code = event.code;
  if (event.domain == 'NSURLErrorDomain' || (code != null && code >= 400 && code <= 599)) return ItemFailure.network;
  return ItemFailure.unknown;
}

enum ItemFailureReaction {
  fallBackToDirect,
  nextCodec,
  nextCodecRemembered,

  /// Fresh URLs, unless a restart happened recently.
  restart,

  /// Fresh URLs once per codec, then the next codec.
  restartOnceThenNextCodec,
}

/// Plays one video at a time on one player (port of PlaybackController.swift, the parts slice 1 needs):
/// link → view → playurl → track choice → engine.prepare → player.load, with BTR and 直连, codec fallback,
/// signed URL refresh, the local server check, stall and seek timing, and the stats overlay. [openLocal] plays a
/// 离线缓存 part from the phone instead: engine.prepareLocal → player.load, with no call to Bilibili at all.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required BiliClient client,
    required PlaybackEngine engine,
    required this.player,
    this._startEngine,
    CodecMemory? codecMemory,
    int quality = defaultQuality,
    this._codec = VideoCodec.hevc,
    PlaybackMode mode = PlaybackMode.btr,
    String transportName = '',
    MonotonicClock? clock,
    DateTime Function()? now,
    StartTimer? startTimer,
    Logger? logger,
  })  : _client = client,
        _engine = engine,
        _memory = codecMemory ?? CodecMemory(),
        _selectedQuality = quality,
        _mode = mode,
        _transportName = transportName,
        _monotonic = clock ?? MonotonicClock.system,
        _now = now ?? DateTime.now,
        _startTimer = startTimer ?? Timer.new,
        _logger = logger ?? Logger.shared,
        clock = PlaybackClock(clock: clock),
        stats = ValueNotifier(OverlayStats(mode: mode, transport: transportName.isEmpty ? null : transportName)),
        duration = ValueNotifier(0),
        danmaku = DanmakuFeed(client: client, logger: logger) {
    _playerEvents = player.events.listen(_onPlayerEvent);
    _engineStats = _listenToStats(engine);
    _engineFatals = _listenToFatals(engine);
  }

  /// 4K, as the Swift app's `settings.quality` default; HDR and 杜比视界 are picked from [qualities].
  static const defaultQuality = 120;

  /// Signed URLs are refreshed this long before their deadline, and count as stale within it.
  static const urlMarginSeconds = 300.0;
  static const refreshRetrySeconds = 30.0;
  static const minRefreshWaitSeconds = 30.0;

  /// A network failure in direct mode restarts with fresh URLs at most this often.
  static const networkRestartSeconds = 60.0;

  /// The waits before asking again for a detail that failed; after the last ask fails, [detailFailed] is set.
  static const detailRetryGaps = [Duration(seconds: 2), Duration(seconds: 6)];

  /// The engine hears the playhead at most this often, as Swift's 0.25 s time observer fed the session; the
  /// players report about ten times a second.
  static const engineFeedMs = 250.0;

  final BiliPlayer player;

  /// Fed from the player's events; the player UI only reads it.
  final PlaybackClock clock;
  final ValueNotifier<OverlayStats> stats;

  /// Seconds; 0 until the player reports it.
  final ValueNotifier<double> duration;
  final DanmakuFeed danmaku;

  final _marks = StreamController<PlaybackMark>.broadcast();

  final BiliClient _client;
  PlaybackEngine _engine;

  /// Starts a replacement once the engine isolate has exited; without it a dead engine stays dead.
  final Future<PlaybackEngine> Function()? _startEngine;
  bool _engineClosed = false;
  Future<void>? _swapping;
  NodeMode? _nodeMode;
  final CodecMemory _memory;
  final String _transportName;
  final MonotonicClock _monotonic;
  final DateTime Function() _now;
  final StartTimer _startTimer;
  final Logger _logger;
  late final StreamSubscription<PlayerEvent> _playerEvents;
  late StreamSubscription<EngineSnapshot> _engineStats;
  late StreamSubscription<FatalReport> _engineFatals;

  PlaybackPhase _phase = PlaybackPhase.idle;
  String? _error;
  String? _playerFailure;
  PlaybackMode _mode;
  bool _fellBack = false;
  VideoView? _video;
  VideoPage? _page;
  List<QualityOption> _qualities = const [];
  int _selectedQuality;
  VideoCodec _codec;
  PlayingStream? _playing;
  bool _pictureInPicture = false;
  ({int width, int height})? _videoSize;

  /// Bumped by every stop, restart, switch and failure; async work of an older epoch does nothing.
  int _epoch = 0;
  TrackChoice? _choice;

  /// The last playurl answer's streams, so another codec can be chosen without asking again.
  Dash? _dash;

  /// The cached part playing from the phone; null for everything Bilibili serves.
  LocalVideo? _local;
  PreparedSource? _source;
  String? _token;
  Timer? _refreshTimer;
  final Set<Timer> _stallChecks = {};
  final SeekTimer _seekTimer = SeekTimer();
  final StallFilter _stallFilter = StallFilter();

  /// Codec kinds that failed in this playback only: not the player's verdict on the phone.
  final Set<String> _rejectedHere = {};

  /// Codec kinds whose unexplained failure already got one retry with fresh URLs.
  final Set<String> _unknownRetried = {};
  DateTime? _lastNetworkRestart;

  /// A BTR request failed for good once in this start: the URLs were refreshed, and the next failure goes direct.
  bool _refreshedAfterFatal = false;
  bool _refreshingAfterFatal = false;
  double? _lastFeedMs;
  List<({double start, double end})> _buffered = const [];

  /// The position to report while nothing is loaded, so a retry resumes where playback stopped.
  double _heldPosition = 0;

  /// Whether a load starts playback; reloading a player the user paused leaves it paused.
  bool _playWhenLoaded = true;

  /// The page is covered: every load starts paused, and [_playWhenLoaded] keeps whether it would have played.
  bool _autoplayHeld = false;

  /// Set by an [openVideo] without a start until the playurl answer's saved progress has placed it.
  bool _resumeFromHistory = false;

  /// The current load reached playing; a format failure after that is not a codec refusal.
  bool _itemPlayed = false;
  bool _sawFirstFrame = false;

  /// False when this playback's first frame waited on the user (loaded paused), so its time means nothing.
  bool _firstFrameTimed = true;
  bool _loggedPlayUrl = false;
  bool _autoPipSet = false;

  /// Off while the page is covered: auto picture in picture belongs to the page on top.
  bool _autoPipWanted = true;
  bool _seekPrecise = true;
  double _startedAtMs = 0;

  /// Set when a playback is torn down and from just before `player.load`, until the player reports loading:
  /// anything earlier belongs to an item that was dropped or replaced.
  bool _awaitingLoad = false;
  PlayerStatus _status = PlayerStatus.idle;
  double _rate = 1;
  double _wantedRate = 1;
  FitMode _fit = FitMode.fit;
  bool _mirrored = false;
  VideoDetail? _detail;

  /// The video whose signed view was refused on its last resolve: another part or a reopen doesn't ask it again.
  String? _signedRefused;
  ({String bvid, Future<VideoDetail> answer})? _detailFetch;

  /// The open whose detail is being asked for, and its video; any open, close or engine change forgets it. Kept after
  /// the asks run out, so [retryDetail] knows what to ask for.
  ({int open, String bvid})? _detailFor;
  Timer? _detailRetry;
  bool _detailFailed = false;
  ({int cid, PlayerInfo info})? _playerInfo;
  final _endings = StreamController<void>.broadcast();
  bool _disposed = false;

  PlaybackEngine get engine => _engine;

  /// A playurl answer is in hand, so [replay] needs no call to Bilibili (unless its URLs are about to expire).
  bool get canReplay => _dash != null && _choice != null && _page != null;

  Stream<PlaybackMark> get marks => _marks.stream;

  PlaybackPhase get phase => _phase;

  /// What to tell the user when [phase] is failed.
  String? get error => _error;

  /// The player's own words for its last failure, shown under [error].
  String? get playerFailure => _playerFailure;

  /// The mode the user picked.
  PlaybackMode get mode => _mode;

  /// BTR failed in this playback and it went on direct.
  bool get fellBack => _fellBack;
  PlaybackMode get activeMode => _local != null ? PlaybackMode.local : (_fellBack ? PlaybackMode.direct : _mode);
  String get modeLabel => _local != null ? PlaybackMode.local.label : (_fellBack ? '直连（回退）' : _mode.label);

  /// Playing a 离线缓存 part from the phone ([openLocal]).
  bool get isLocal => _local != null;
  VideoView? get video => _video;
  VideoPage? get page => _page;
  List<QualityOption> get qualities => _qualities;

  /// The current part's playurl answer: its streams, for 缓存's size estimates.
  Dash? get dash => _dash;

  /// The ceiling asked for; [playing] is the stream actually chosen. A cached part has only the quality it was cached
  /// at.
  int get selectedQuality => _local?.files.video.id ?? _selectedQuality;
  VideoCodec get codec => _codec;
  PlayingStream? get playing => _playing;
  bool get pictureInPicture => _pictureInPicture;
  ({int width, int height})? get videoSize => _videoSize;

  double get currentSeconds => _token != null ? clock.seconds : _heldPosition;

  /// The speed chosen; every load plays at it.
  double get rate => _wantedRate;

  FitMode get fit => _fit;

  bool get mirrored => _mirrored;

  /// The signed view's detail: resolved here, handed to [openVideo] with the view, or asked for after a view came
  /// without one; null until then, and when the signed view was refused or the follow-up ask failed.
  VideoDetail? get detail => _detail;

  /// The follow-up ask for [detail] failed, its retries too; [retryDetail] asks once more.
  bool get detailFailed => _detailFailed;

  /// The 合集 holding the video, from [detail].
  UgcSeason? get season => _detail?.season;

  /// Fires when the playing item reaches its end.
  Stream<void> get endings => _endings.stream;

  /// The player info [openVideo] asked for to choose the part, when it was asked with [cid] for this video.
  PlayerInfo? playerInfoFor(int cid) {
    final asked = _playerInfo;
    return asked != null && asked.cid == cid ? asked.info : null;
  }

  /// The look setters below show the new value at once and put the old one back when the player refuses it, unless a
  /// newer value was set meanwhile; the failure is rethrown for the toast.
  Future<void> setRate(double rate) async {
    final old = _wantedRate;
    _wantedRate = rate;
    _notify();
    await _orRestore(() => player.setRate(rate), () {
      if (_wantedRate == rate) _wantedRate = old;
    });
  }

  Future<void> setFit(FitMode fit) async {
    final old = _fit;
    _fit = fit;
    _notify();
    await _orRestore(() => player.setFit(fit), () {
      if (_fit == fit) _fit = old;
    });
  }

  Future<void> setMirrored(bool on) async {
    final old = _mirrored;
    _mirrored = on;
    _notify();
    await _orRestore(() => player.setMirrored(on), () {
      if (_mirrored == on) _mirrored = old;
    });
  }

  Future<void> _orRestore(Future<void> Function() call, void Function() restore) async {
    try {
      await call();
    } catch (_) {
      restore();
      _notify();
      rethrow;
    }
  }

  String qualityName(int qn) =>
      QualityNames.full(qn: qn, serverText: _qualities.where((option) => option.id == qn).firstOrNull?.name);

  /// Counts [open] and [openVideo] calls, so a watch reporter can tell a newer open moved the controller on.
  int get opens => _opens;
  int _opens = 0;

  Future<void> open(String text) async {
    _opens += 1;
    final link = LinkParser.parse(text);
    _clearVideo();
    if (link == null) {
      _failWith(BiliError.invalidLink, 'no link');
      return;
    }
    await _openWith((current) async {
      VideoDetail? resolved;
      final (view, pageNumber) = await _resolve(link, onDetail: (detail) => resolved = detail);
      if (current != _epoch) return null;
      _detail = resolved;
      // A BV link without a detail had its signed view refused just now; asking again would only be refused again.
      if (resolved == null && link is BvidLink) _signedRefused = view.bvid;
      if (resolved == null && link is! BvidLink) _fetchDetail(view.bvid);
      final pages = view.pages;
      if (pages.isEmpty) throw const BiliError.decoding('view has no pages');
      return (view, pages.where((page) => page.page == pageNumber).firstOrNull ?? pages.first);
    }, start: 0);
  }

  /// The video page's open: part [cid], or without one the part Bilibili saw this account watch last, or the first;
  /// from [start] seconds, or without one from where Bilibili saw it last (`ResumePoint`), which only arrives with
  /// the playurl answer. A [view] already resolved (a pasted link, another part) saves asking for it again, and the
  /// signed [detail] that came with it keeps the 合集; a [detail] alone gives the view as well. A [view] without its
  /// detail plays at once and the detail is asked for alongside.
  Future<void> openVideo(String bvid, {int? cid, double? start, VideoView? view, VideoDetail? detail}) async {
    _opens += 1;
    // Another part keeps the video's shape until its stream gives its own, so the layout doesn't flip meanwhile.
    _clearVideo(keepSize: _video?.bvid == bvid);
    final knownDetail = detail != null && detail.bvid == bvid && detail.redirectURL == null ? detail : null;
    final known = view?.bvid == bvid ? view : (knownDetail == null ? null : _viewOf(knownDetail));
    await _openWith((current) async {
      var resolved = knownDetail;
      final view = known ?? (await _resolve(BvidLink(bvid), onDetail: (detail) => resolved = detail)).$1;
      if (current != _epoch) return null;
      _detail = resolved;
      if (known == null && resolved == null) _signedRefused = view.bvid;
      if (known != null && resolved == null && view.bvid != _signedRefused) _fetchDetail(view.bvid);
      final pages = view.pages;
      if (pages.isEmpty) throw const BiliError.decoding('view has no pages');
      if (cid != null) {
        final match = pages.where((page) => page.cid == cid).firstOrNull;
        if (match == null) {
          _logger.warn(LogCategory.player, 'part not in the video, playing P1', {'bvid': view.bvid, 'cid': cid});
        }
        return (view, match ?? pages.first);
      }
      if (pages.length == 1) return (view, pages.first);
      PlayerInfo? info;
      // last_play_cid is per video, so any part's cid asks for it; the playurl answer has it too, but only after a
      // part is chosen.
      try {
        info = await _client.playerInfo(bvid: view.bvid, cid: pages.first.cid);
      } catch (error) {
        _logger.warn(LogCategory.player, 'player info failed, playing P1',
            {'bvid': view.bvid, 'cid': pages.first.cid, 'error': '$error'});
      }
      if (current != _epoch) return null;
      // P1's chapters come with it, so the page needn't ask again when P1 is the one chosen.
      if (info != null) _playerInfo = (cid: pages.first.cid, info: info);
      final saved = info?.lastPlayCid;
      return (view, pages.where((page) => page.cid == saved).firstOrNull ?? pages.first);
    }, start: start);
  }

  /// A 离线缓存 part from the phone, from [start] seconds: [find] hands over its files, or null when they are gone. A
  /// [start] still to come (the account's history, asked alongside [find]) is waited for before the load.
  /// Nothing here asks Bilibili: no view, no playurl, no URL refresh, no direct fallback. The quality, codec and mode
  /// can't change, and a codec the player refuses fails the playback, as the files hold no other.
  Future<void> openLocal(Future<LocalVideo?> Function() find, {FutureOr<double> start = 0}) async {
    _opens += 1;
    _clearVideo();
    final current = _advance();
    _phase = PlaybackPhase.loading;
    _playWhenLoaded = true;
    _error = null;
    _playerFailure = null;
    _notify();
    try {
      if (_engineClosed) {
        await _replaceEngine();
        if (current != _epoch) return;
      }
      final local = await find();
      if (current != _epoch) return;
      if (local == null) throw PlaybackFailure.localMissing;
      final from = start is Future<double> ? await start : start;
      if (current != _epoch) return;
      _local = local;
      _video = local.view;
      _page = local.page;
      final video = local.files.video;
      _qualities = [QualityOption(id: video.id, name: local.qualityName)];
      danmaku.loadLocal(
        cid: local.page.cid,
        durationMs: local.page.duration * 1000,
        folder: local.danmakuFolder,
        segments: local.danmakuSegments,
      );
      if (from > 0) danmaku.seeked((from * 1000).round());
      _logger.info(LogCategory.player, 'open local', {
        'cid': local.page.cid,
        'quality': video.id,
        'codecs': video.codecs,
        'danmaku': local.danmakuFolder == null ? 0 : local.danmakuSegments,
      });
      _resetStart(autoplay: _playWhenLoaded);
      await _beginLocal(from);
    } catch (error, stack) {
      if (current == _epoch) _fail(error, stack);
    }
  }

  Future<void> _beginLocal(double time) async {
    final local = _local!;
    final current = _advance();
    _phase = PlaybackPhase.loading;
    _heldPosition = time;
    _playing = null;
    _notify();
    try {
      final choice = TrackChoice(video: local.files.video, audio: local.files.audio);
      _choice = choice;
      final playing = PlayingStream(choice.video);
      _playing = playing;
      if (choice.video.width > 0 && choice.video.height > 0) {
        _videoSize = (width: choice.video.width, height: choice.video.height);
      }
      stats.value = stats.value.copyWith(stream: playing.line(qualityName: qualityName(choice.video.id)));
      _notify();
      await _prepareAndLoad(choice, time, current);
    } catch (error, stack) {
      await _handle(error, stack, time, current);
    }
  }

  /// Its playback closed: playback stops and nothing of it stays.
  void close() {
    _clearVideo();
    _error = null;
    _playerFailure = null;
    // Paused, AVPlayer would keep its item and go on filling the forward buffer while home shows.
    _quietly(player.unload, 'unload');
    _notify();
  }

  /// The player UI reads the clock and the duration as soon as the next video is set, before its load resets them.
  void _clearVideo({bool keepSize = false}) {
    _stopPlayback();
    _local = null;
    _video = null;
    _page = null;
    _detail = null;
    _detailFor = null;
    _detailFailed = false;
    _detailRetry?.cancel();
    _detailRetry = null;
    if (!keepSize) _videoSize = null;
    _playerInfo = null;
    _qualities = const [];
    _resumeFromHistory = false;
    danmaku.clear();
    duration.value = 0;
    _heldPosition = 0;
    _buffered = const [];
    clock.clear();
  }

  /// [pick] resolves the video and its part, or answers null once a newer open has taken over.
  Future<void> _openWith(Future<(VideoView, VideoPage)?> Function(int current) pick, {required double? start}) async {
    final current = _advance();
    _phase = PlaybackPhase.loading;
    // Its load autoplays; until then a covered page reads this as about to play.
    _playWhenLoaded = true;
    _error = null;
    _playerFailure = null;
    _notify();
    try {
      if (_engineClosed) {
        await _replaceEngine();
        if (current != _epoch) return;
      }
      final picked = await pick(current);
      if (picked == null || current != _epoch) return;
      final (view, page) = picked;
      _video = view;
      _page = page;
      danmaku.load(cid: page.cid, durationMs: page.duration * 1000);
      _logger.info(LogCategory.player, 'open', {'bvid': view.bvid, 'page': page.page, 'parts': view.pages.length});
      _resumeFromHistory = start == null;
      // A hold lifted with play: false while the video resolved has already said no.
      await _startPlayback(start ?? 0, autoplay: _playWhenLoaded);
    } catch (error, stack) {
      if (current == _epoch) _fail(error, stack);
    }
  }

  Future<void> setMode(PlaybackMode mode) async {
    if (mode == _mode && !_fellBack) return;
    _logger.info(LogCategory.ui, 'btr switch', {'on': mode == PlaybackMode.btr});
    _mode = mode;
    _fellBack = false;
    _unknownRetried.clear();
    _lastNetworkRestart = null;
    _updateModeStats();
    _notify();
    await _restart(sameChoice: true);
  }

  Future<void> setQuality(int quality) async {
    if (quality == _selectedQuality) return;
    _logger.info(LogCategory.ui, 'quality', {'id': quality});
    _selectedQuality = quality;
    _notify();
    await _restart(sameChoice: false);
  }

  /// Closes the video and puts [start]'s engine in place of the current one; the next [open] plays on it.
  Future<void> useEngine(Future<PlaybackEngine> Function() start) async {
    _clearVideo();
    _error = null;
    _playerFailure = null;
    _notify();
    await _replaceEngine(start);
  }

  /// The same video again from 0 s, cold: the playing source is released first so it stops downloading, then the
  /// engine is replaced if [engine] is given, and the streams are chosen again from the playurl answer in hand. A
  /// [mode] is taken as [setMode] would, without its reload.
  Future<void> replay({Future<PlaybackEngine> Function()? engine, int? quality, PlaybackMode? mode}) async {
    if (_page == null) return;
    _heldPosition = 0;
    final current = _advance();
    _teardownPlayback();
    _phase = PlaybackPhase.loading;
    _playWhenLoaded = true;
    _error = null;
    _playerFailure = null;
    _notify();
    if (engine != null) {
      try {
        await _replaceEngine(engine);
      } catch (error, stack) {
        if (error is! _Stale) _fail(error, stack);
        return;
      }
      // An open while the engine started has taken over.
      if (current != _epoch) return;
    }
    if (quality != null) _selectedQuality = quality;
    if (mode != null && (mode != _mode || _fellBack)) {
      _mode = mode;
      _fellBack = false;
      _unknownRetried.clear();
      _lastNetworkRestart = null;
      _updateModeStats();
    }
    _logger.info(LogCategory.player, 'replay',
        {'quality': _selectedQuality, 'engineReplaced': engine != null, 'mode': _mode.label});
    danmaku.seeked(0);
    _resetStart(autoplay: true);
    await _chooseAgain(0);
  }

  Future<void> setCodec(VideoCodec codec) async {
    if (codec == _codec) return;
    _logger.info(LogCategory.ui, 'codec', {'codec': codec.name});
    _codec = codec;
    _notify();
    await _restart(sameChoice: false);
  }

  /// A seek the user made, after the player was told. One that is not [precise] lands on a keyframe near [seconds].
  void userSeeked(double seconds, {bool precise = true}) {
    final now = _nowMs();
    _stallFilter.jumped(now);
    clock.jump(seconds, precise: precise);
    _jumpedTo(seconds);
    danmaku.seeked((seconds * 1000).round());
    if (!_sawFirstFrame) return;
    final timed = _seekTimer.jumped(position: seconds, atMs: now, rate: _playerRate, exact: precise);
    _seekPrecise = precise;
    _logger.info(
        LogCategory.player, 'seek', {'to': seconds.round(), 'mode': modeLabel, 'timed': timed, 'precise': precise});
  }

  /// The finger rests on the seek bar at [seconds] while dragging: the engine starts loading there. Null when the
  /// drag ended without a seek.
  void seekHint(double? seconds) {
    final token = _btrToken;
    if (token == null) return;
    _engine.hint(token, seconds);
    _logger.info(LogCategory.player, 'seek hint', {'at': seconds?.round() ?? -1});
  }

  /// 设置's CDN 节点: the next video's sessions use [mode], on this engine and on any that replaces it. The video
  /// playing now keeps its nodes.
  void setNodeMode(NodeMode mode) {
    _nodeMode = mode;
    _engine.setNodeMode(mode);
  }

  /// 设置's 重置编码记忆: codecs the player refused are tried again.
  void resetCodecMemory() => _memory.reset();

  /// The system is short of memory: the engine drops its prefetched segments and playback goes on. On the shared
  /// engine AppPlayback drops them once for every page, and the lease leaves the drop to it.
  void memoryPressure() {
    _engine.dropCache();
    final rss = ProcessInfo.currentRss;
    _logger.warn(LogCategory.player, 'memory warning, prefetch cache dropped', {'rssMB': rss ~/ (1024 * 1024)});
    _mark(MemoryWarning(rss));
  }

  Future<void> startPictureInPicture() async {
    if (!player.capabilities.pictureInPicture) return;
    _logger.info(LogCategory.ui, 'pip start');
    await player.startPictureInPicture();
  }

  Future<void> stopPictureInPicture() async {
    if (!player.capabilities.pictureInPicture || !_pictureInPicture) return;
    _logger.info(LogCategory.ui, 'pip stop');
    await player.stopPictureInPicture();
  }

  /// Whether the small window's restore button waits for a page to come back for this player (PipKeeper).
  Future<void> setRestorable(bool restorable) async {
    if (!player.capabilities.pictureInPicture) return;
    await player.setRestorable(restorable);
  }

  /// Whether the small window starts by itself when the app leaves while this plays. It is first turned on at the
  /// first play, so a page covered before then never gets it. [now] turns it on at once, for a page taking 推荐's big
  /// card over while it plays, which has no first play to come.
  void setAutoPictureInPicture(bool on, {bool now = false}) {
    _autoPipWanted = on;
    if (!player.capabilities.pictureInPicture) return;
    if (!on || _autoPipSet || now) {
      _autoPipSet = on || _autoPipSet;
      _quietly(() => player.setAutoPictureInPicture(on), 'auto pip');
    }
  }

  /// The small window's restore button was tapped.
  Stream<void> get restoreRequests => _restores.stream;
  final _restores = StreamController<void>.broadcast(sync: true);

  /// While [hold] (its page covered), every load starts paused: an open, a reload, a URL refresh, a codec fallback,
  /// a server restart. [loadWillPlay] still says whether it would have played. Lifted, a load still to come plays
  /// only if [play].
  void holdAutoplay(bool hold, {bool play = true}) {
    _autoplayHeld = hold;
    if (!hold) _playWhenLoaded = play;
  }

  /// A load is under way that starts playing when it lands, or would were it not held.
  bool get loadWillPlay => _phase == PlaybackPhase.loading && _playWhenLoaded;

  /// The page was covered: this playback's prefetched segments go, as Swift's cover() did, and the player keeps
  /// what it has.
  void dropPrefetch() {
    final token = _btrToken;
    if (token != null) _engine.dropPrefetch(token);
  }

  /// iOS can take a suspended app's listening socket: once back in the foreground the local server is probed,
  /// and a playback prepared before a restart is prepared again where it was. A detail whose asks ran out (likely
  /// while the network was away) is asked for once more.
  Future<void> appResumed() async {
    retryDetail();
    if (_choice == null || _token == null) return;
    final current = _epoch;
    final bool restarted;
    try {
      restarted = await _ensureServing();
    } catch (error, stack) {
      if (current == _epoch) _fail(error, stack);
      return;
    }
    if (!restarted || current != _epoch) return;
    _logger.warn(LogCategory.player, 'local server restarted, preparing again', {'at': currentSeconds});
    await _reload(current);
  }

  Future<(VideoView, int?)> _resolve(VideoLink link, {void Function(VideoDetail detail)? onDetail}) =>
      resolveVideoLink(_client, link, logger: _logger, onDetail: onDetail);

  /// A video that opened with only a view (a b23.tv or av link, a view handed in alone) plays at once, and its signed
  /// detail (简介, the 合集, the actions) follows when it lands, if the same open is still showing it. A failed ask is
  /// tried again after each of [detailRetryGaps] while the open stands, then [detailFailed] is set. Another part
  /// opened while the call is out waits on the same call.
  void _fetchDetail(String bvid, {int attempt = 0}) {
    final open = _opens;
    _detailFor = (open: open, bvid: bvid);
    var pending = _detailFetch;
    if (pending == null || pending.bvid != bvid) {
      Future<VideoDetail> ask() async {
        await _client.ensureRiskCookies();
        return _client.videoDetail(bvid: bvid);
      }

      final fetch = (bvid: bvid, answer: ask());
      pending = fetch;
      _detailFetch = fetch;
      unawaited(fetch.answer.then((_) {}, onError: (Object error) {
        _logger.warn(LogCategory.player, 'detail failed, playing without it',
            {'bvid': bvid, 'attempt': attempt, 'error': '$error'});
      }).whenComplete(() {
        if (identical(_detailFetch, fetch)) _detailFetch = null;
      }));
    }
    unawaited(pending.answer.then((detail) {
      if (_disposed || _detailFor?.open != open) return;
      _detailFor = null;
      if (detail.bvid != bvid || detail.redirectURL != null) {
        _logger.info(LogCategory.player, 'detail dropped',
            {'bvid': bvid, 'answered': detail.bvid, 'redirects': detail.redirectURL != null});
        return;
      }
      _detail = detail;
      _notify();
    }, onError: (Object _) {
      if (_disposed || _detailFor?.open != open) return;
      if (attempt >= detailRetryGaps.length) {
        _detailFailed = true;
        _notify();
        return;
      }
      _detailRetry = _startTimer(detailRetryGaps[attempt], () {
        _detailRetry = null;
        if (_disposed || _detailFor?.open != open) return;
        _fetchDetail(bvid, attempt: attempt + 1);
      });
    }));
  }

  /// 简介's 点击重试: one more ask for a detail whose asks ran out, with no retries of its own.
  void retryDetail() {
    final wanted = _detailFor;
    if (_disposed || !_detailFailed || wanted == null) return;
    _detailFailed = false;
    _notify();
    _fetchDetail(wanted.bvid, attempt: detailRetryGaps.length);
  }

  Future<PlayURLInfo> _playUrl() => _client.runInSession(_client.sessionGeneration, () async {
    final page = _page;
    final video = _video;
    if (page == null || video == null) throw BiliError.invalidLink;
    await _client.ensureRiskCookies();
    return _client.playURL(bvid: video.bvid, cid: page.cid, quality: _selectedQuality);
  });

  Future<void> _startPlayback(double time, {required bool autoplay}) async {
    _resetStart(autoplay: autoplay);
    await _begin(time);
  }

  void _resetStart({required bool autoplay}) {
    _rejectedHere.clear();
    _unknownRetried.clear();
    _lastNetworkRestart = null;
    _fellBack = false;
    _loggedPlayUrl = false;
    _playWhenLoaded = autoplay;
    _seekTimer.cancel();
    _sawFirstFrame = false;
    _firstFrameTimed = true;
    _startedAtMs = _nowMs();
    stats.value = OverlayStats(mode: activeMode, transport: _transportName.isEmpty ? null : _transportName);
  }

  Future<void> _begin(double time) async {
    // Every way back to a playurl call passes here; a cached part has none to make.
    if (_local != null) return _beginLocal(time);
    final current = _advance();
    _cancelRefresh();
    _phase = PlaybackPhase.loading;
    _heldPosition = time;
    _refreshedAfterFatal = false;
    _refreshingAfterFatal = false;
    _playing = null;
    _notify();
    var at = time;
    try {
      final info = await _playUrl();
      _ensureCurrent(current);
      _qualities = info.qualityOptions;
      if (!_loggedPlayUrl) {
        _loggedPlayUrl = true;
        _logger.info(LogCategory.player, 'playurl', playURLSummary(info));
      }
      at = _resumePoint(info) ?? time;
      final dash = info.dash;
      if (dash == null) throw BiliError.notDash;
      _dash = dash;
      final choice = _choose(dash);
      _preconnect(choice);
      await _prepareAndLoad(choice, at, current);
      _scheduleRefresh(choice, current);
    } catch (error, stack) {
      await _handle(error, stack, at, current);
    }
  }

  /// Where an [openVideo] without a start begins, from the first playurl answer's saved progress; null after that,
  /// so a restart or a URL refresh keeps the playhead.
  double? _resumePoint(PlayURLInfo info) {
    final page = _page;
    if (!_resumeFromHistory || page == null) return null;
    _resumeFromHistory = false;
    final at = ResumePoint.start(
      lastPlayTimeMs: info.lastPlayTimeMs,
      lastPlayCid: info.lastPlayCid,
      cid: page.cid,
      duration: page.duration.toDouble(),
    );
    _logger.info(LogCategory.player, 'resume', {'at': at.round(), 'saved': info.lastPlayTimeMs ~/ 1000});
    if (at > 0) {
      _heldPosition = at;
      danmaku.seeked((at * 1000).round());
    }
    return at;
  }

  /// The engine opens its connections to the nodes while the local server check and the prepare call make their
  /// round trips; direct mode's media requests are the player's own.
  void _preconnect(TrackChoice choice) {
    if (activeMode != PlaybackMode.btr) return;
    _engine.preconnect([
      choice.video.baseURL,
      ...choice.video.backupURLs,
      choice.audio.baseURL,
      ...choice.audio.backupURLs,
    ]);
  }

  /// Another codec from the playurl answer already in hand, while its URLs are fresh: the Swift app asks
  /// Bilibili again here, and KaiC's account should see as few calls as possible.
  Future<void> _chooseAgain(double time) async {
    final dash = _dash;
    final previous = _choice;
    if (dash == null || previous == null || urlsNearExpiry(previous, _now())) {
      await _begin(time);
      return;
    }
    final current = _advance();
    _cancelRefresh();
    _phase = PlaybackPhase.loading;
    _heldPosition = time;
    try {
      final choice = _choose(dash);
      await _prepareAndLoad(choice, time, current);
      _scheduleRefresh(choice, current);
    } catch (error, stack) {
      await _handle(error, stack, time, current);
    }
  }

  TrackChoice _choose(Dash dash) {
    final choice = _pickTracks(dash, skipHEV1: activeMode == PlaybackMode.direct && _memory.hev1LabelsHoldHEV1);
    _choice = choice;
    final playing = PlayingStream(choice.video);
    _playing = playing;
    if (choice.video.width > 0 && choice.video.height > 0) {
      _videoSize = (width: choice.video.width, height: choice.video.height);
    }
    stats.value = stats.value.copyWith(stream: playing.line(qualityName: qualityName(choice.video.id)));
    _logger.info(LogCategory.player, 'choice', {
      'quality': choice.video.id,
      'codecs': choice.video.codecs,
      'kbps': choice.video.bandwidth ~/ 1000,
      'audio': choice.audio.id,
      'host': Uri.tryParse(choice.video.baseURL)?.host ?? '',
      'btr': activeMode == PlaybackMode.btr,
    });
    _notify();
    return choice;
  }

  TrackChoice _pickTracks(Dash dash, {required bool skipHEV1}) {
    final excluded = {..._memory.failedKinds, ..._rejectedHere};
    final choice = choose(dash,
        quality: _selectedQuality, codecOrder: _memory.order(preferred: _codec), excluded: excluded, skipHEV1: skipHEV1);
    if (choice != null) return choice;
    final offered = TrackSelector.choose(dash, quality: _selectedQuality, codecOrder: const []) != null;
    final withoutMemory = choose(dash,
            quality: _selectedQuality, codecOrder: VideoCodec.values, excluded: _rejectedHere, skipHEV1: skipHEV1) !=
        null;
    _logger.warn(LogCategory.player, 'no track', {
      'excluded': (excluded.toList()..sort()).join(','),
      'offered': offered,
      'skipHEV1': skipHEV1,
      'memoryDecided': withoutMemory,
    });
    if (!offered) throw const PlaybackError(PlaybackErrorKind.noTrack);
    throw withoutMemory ? PlaybackFailure.noPlayableCodec : PlaybackFailure.unplayable;
  }

  /// TrackSelector falls back to any codec the quality has, so rejected kinds are removed from the streams
  /// first. Once anything was rejected, codecs of unknown kind are left out too.
  static TrackChoice? choose(Dash dash,
      {required int quality,
      required List<VideoCodec> codecOrder,
      required Set<String> excluded,
      bool skipHEV1 = false}) {
    final banned = {...excluded};
    if (banned.isNotEmpty) banned.add('other');
    final videos = dash.video
        .where((stream) => !banned.contains(TrackSelector.codecKind(stream)) && !(skipHEV1 && _isHEV1(stream)))
        .toList();
    if (videos.isEmpty) return null;
    return TrackSelector.choose(Dash(duration: dash.duration, video: videos, audio: dash.audio),
        quality: quality, codecOrder: codecOrder.where((codec) => !banned.contains(codec.name)).toList());
  }

  static bool _isHEV1(DashStream stream) => stream.codecs.startsWith('hev1');

  /// Direct mode serves Bilibili's bytes unchanged and AVPlayer refuses hev1: a hev1 label plays only when the
  /// bytes hold hvc1.
  static bool directCanPlay(DashStream stream, {required String? sourceEntry}) =>
      !_isHEV1(stream) || sourceEntry == 'hvc1';

  /// Unix seconds from the signed URL's `deadline` parameter.
  static double? urlDeadline(DashStream stream) {
    final value = Uri.tryParse(stream.baseURL)?.queryParameters['deadline'];
    return value == null ? null : double.tryParse(value);
  }

  static bool urlsNearExpiry(TrackChoice choice, DateTime now) {
    final deadline = urlDeadline(choice.video);
    if (deadline == null) return false;
    return deadline - now.millisecondsSinceEpoch / 1000 < urlMarginSeconds;
  }

  /// What the playurl answer offered, for the log: qualities, codecs and hosts, never a URL.
  static Map<String, Object> playURLSummary(PlayURLInfo info) {
    String hosts(List<DashStream> streams) {
      final all = {
        for (final stream in streams)
          for (final url in [stream.baseURL, ...stream.backupURLs]) ?Uri.tryParse(url)?.host,
      }.toList()
        ..sort();
      return all.join(',');
    }

    final video = info.dash?.video ?? const <DashStream>[];
    return {
      'accept': info.acceptQuality.join(','),
      'streams': video.map((stream) => '${stream.id}:${stream.codecs}').join(','),
      'videoHosts': hosts(video),
      'audioHosts': hosts(info.dash?.audio ?? const []),
      'durl': '${info.hasDurl}',
    };
  }

  /// The local server serves an init AVPlayer can read (hev1 renamed to hvc1), so a format failure in BTR mode
  /// is the player's verdict on the codec, and the same quality is tried in the next codec, still in BTR mode.
  /// A format failure after the load played only moves this playback to the next codec.
  static ItemFailureReaction reaction(ItemFailure failure,
      {required bool btr, required bool servedUnpatchedHEV1, required bool played}) {
    if (failure == ItemFailure.format && played) return ItemFailureReaction.nextCodec;
    if (failure == ItemFailure.format && btr) return ItemFailureReaction.nextCodecRemembered;
    if (btr) return ItemFailureReaction.fallBackToDirect;
    return switch (failure) {
      ItemFailure.network => ItemFailureReaction.restart,
      ItemFailure.unknown => ItemFailureReaction.restartOnceThenNextCodec,
      // A hev1 entry served unpatched says nothing about what this phone can decode.
      ItemFailure.format =>
        servedUnpatchedHEV1 ? ItemFailureReaction.nextCodec : ItemFailureReaction.nextCodecRemembered,
    };
  }

  Future<void> _prepareAndLoad(TrackChoice choice, double time, int current) async {
    // Prepared on an engine that is about to be replaced, the source would go with it.
    final swapping = _swapping;
    if (swapping != null) {
      await swapping.then((_) {}, onError: (Object _) {});
      _ensureCurrent(current);
    }
    final requested = activeMode;
    await _ensureServing();
    _ensureCurrent(current);
    final PreparedSource source;
    final local = _local;
    try {
      source = local != null
          ? await _engine.prepareLocal(local.files)
          : await _engine.prepare(PlaybackRequest(
              choice: choice, mode: requested, mediaHeaders: BiliClient.mediaHeaders, startSeconds: time));
    } catch (error) {
      if (_isClosed(error)) throw _engineGone();
      final codec = error is PlaybackError && error.kind == PlaybackErrorKind.codecUnplayable;
      if (current != _epoch || requested != PlaybackMode.btr || codec) rethrow;
      _logger.warn(LogCategory.player, 'btr start failed, going direct', {'error': '$error'});
      _fellBack = true;
      _updateModeStats();
      _notify();
      return _prepareAndLoad(choice, time, current);
    }
    if (current != _epoch) {
      _release(source.token);
      throw const _Stale();
    }
    _noteSourceEntry(source, choice);
    if (source.mode == PlaybackMode.direct && !directCanPlay(choice.video, sourceEntry: source.sourceEntry)) {
      _release(source.token);
      _logger.info(LogCategory.player, 'hev1 label holds hev1, choosing again for direct mode');
      throw const _Reroute();
    }
    final previous = _token;
    _token = source.token;
    _source = source;
    if (previous != null && previous != source.token) _release(previous);
    await _load(source, time, current);
  }

  void _noteSourceEntry(PreparedSource source, TrackChoice choice) {
    if (!_isHEV1(choice.video)) return;
    if (source.sourceEntry == 'hev1') _memory.noteHEV1Entry();
    _logger.info(LogCategory.player, 'hev1 label',
        {'entry': source.sourceEntry ?? 'none', 'rewritten': source.rewroteHEV1, 'mode': source.mode.label});
  }

  Future<void> _load(PreparedSource source, double time, int current) async {
    _seekTimer.reloadBegan();
    _itemPlayed = false;
    final autoplay = _playWhenLoaded && !_autoplayHeld;
    // Loaded paused, the first frame waits on the user: that wait is not startup time.
    if (!autoplay && !_sawFirstFrame) _firstFrameTimed = false;
    clock.reset(time);
    _buffered = const [];
    _jumpedTo(time);
    _awaitingLoad = true;
    await player.load(PlayerSource(
      master: source.master,
      video: source.video,
      audio: source.audio,
      headers: source.mode == PlaybackMode.direct ? source.mediaHeaders : const {},
      startSeconds: time,
      autoplay: autoplay,
    ));
    _ensureCurrent(current);
    _applyLook();
    if (!autoplay) _phase = PlaybackPhase.playing;
    _updateModeStats();
    _notify();
    _logger.info(LogCategory.player, 'load', {'mode': modeLabel, 'at': time, 'play': autoplay});
  }

  /// The rate, fit and mirroring chosen outlive the item; the defaults need no call.
  void _applyLook() {
    if (_wantedRate != 1) _quietly(() => player.setRate(_wantedRate), 'rate');
    if (_fit != FitMode.fit) _quietly(() => player.setFit(_fit), 'fit');
    if (_mirrored) _quietly(() => player.setMirrored(true), 'mirror');
  }

  /// A server that could not be bound again, or an engine isolate that is gone, fails the playback; the user
  /// retries from there.
  Future<bool> _ensureServing() async {
    try {
      final restarted = await _engine.ensureServing();
      if (restarted) _logger.warn(LogCategory.server, 'restarted');
      return restarted;
    } on PlaybackError catch (error) {
      _logger.error(LogCategory.server, 'probe failed', {'error': '$error'});
      rethrow;
    } catch (error) {
      _logger.error(LogCategory.server, 'probe failed', {'error': '$error'});
      if (_isClosed(error)) throw _engineGone();
      return false;
    }
  }

  static bool _isClosed(Object error) => error is RipperError && error.kind == RipperErrorKind.closed;

  /// The next [open] starts a new engine.
  PlaybackError _engineGone() {
    if (!_engineClosed) _logger.error(LogCategory.engine, 'engine closed, a new one starts on the next open');
    _engineClosed = true;
    return const PlaybackError(PlaybackErrorKind.serverDown);
  }

  /// Swaps run one after another, so the engine asked for last is the one left, whatever each takes to start.
  Future<void> _replaceEngine([Future<PlaybackEngine> Function()? starter]) {
    final swap = _swapEngine(_swapping, starter);
    _swapping = swap;
    return swap.whenComplete(() {
      if (identical(_swapping, swap)) _swapping = null;
    });
  }

  Future<void> _swapEngine(Future<void>? previous, Future<PlaybackEngine> Function()? starter) async {
    if (previous != null) await previous.then((_) {}, onError: (Object _) {});
    final start = starter ?? _startEngine;
    if (start == null) throw const PlaybackError(PlaybackErrorKind.serverDown);
    final old = _engine;
    final next = await start();
    if (_disposed) {
      _quietly(next.dispose, 'engine dispose');
      throw const _Stale();
    }
    unawaited(_engineStats.cancel());
    unawaited(_engineFatals.cancel());
    _engine = next;
    _engineStats = _listenToStats(next);
    _engineFatals = _listenToFatals(next);
    _engineClosed = false;
    if (_nodeMode case final mode?) next.setNodeMode(mode);
    _quietly(old.dispose, 'old engine dispose');
    _logger.info(LogCategory.engine, 'engine replaced');
  }

  StreamSubscription<EngineSnapshot> _listenToStats(PlaybackEngine engine) =>
      engine.stats.listen(_onEngineStats, onError: (Object error) {
        _logger.warn(LogCategory.engine, 'stats failed', {'error': '$error'});
      });

  StreamSubscription<FatalReport> _listenToFatals(PlaybackEngine engine) => engine.fatals.listen(_onEngineFatal);

  /// Prepares the current choice again at the current position, or starts over with fresh URLs when they
  /// are about to expire.
  Future<void> _reload(int current) async {
    final choice = _choice;
    if (choice == null || current != _epoch) return;
    final time = currentSeconds;
    if (urlsNearExpiry(choice, _now())) {
      await _begin(time);
      return;
    }
    if (activeMode == PlaybackMode.direct && !directCanPlay(choice.video, sourceEntry: _source?.sourceEntry)) {
      await _chooseAgain(time);
      return;
    }
    final next = _advance();
    _cancelRefresh();
    try {
      await _prepareAndLoad(choice, time, next);
      _scheduleRefresh(choice, next);
    } catch (error, stack) {
      await _handle(error, stack, time, next);
    }
  }

  /// A user's pause survives a mode, quality or codec change. A cached part has one stream in one mode.
  Future<void> _restart({required bool sameChoice}) async {
    if (_page == null || _local != null) return;
    if (sameChoice && _choice != null && _token != null) {
      await _reload(_epoch);
      return;
    }
    final time = currentSeconds;
    final autoplay = _phase == PlaybackPhase.playing ? _playWhenLoaded : true;
    _stopPlayback();
    await _startPlayback(time, autoplay: autoplay);
  }

  Future<void> _handle(Object error, StackTrace stack, double time, int current) async {
    if (current != _epoch || error is _Stale) return;
    if (_local != null) {
      _logger.warn(LogCategory.player, 'local prepare failed', {'error': _logged(error)});
      _fail(_localFailure(error), stack);
      return;
    }
    if (error is _Reroute) {
      await _chooseAgain(time);
      return;
    }
    final choice = _choice;
    if (error is PlaybackError && error.kind == PlaybackErrorKind.codecUnplayable && choice != null) {
      _logger.warn(LogCategory.player, 'codec unplayable', {'reason': error.detail ?? ''});
      await _nextCodec(TrackSelector.codecKind(choice.video), remember: false, time: time);
      return;
    }
    _fail(error, stack);
  }

  Future<void> _nextCodec(String kind, {required bool remember, required double time}) async {
    if (remember) {
      _memory.markFailed(kind);
    } else {
      _rejectedHere.add(kind);
    }
    _logger.warn(LogCategory.player, 'codec failed', {'kind': kind, 'remembered': remember, 'mode': modeLabel});
    await _chooseAgain(time);
  }

  Future<void> _itemFailed(PlayerFailed event) async {
    final choice = _choice;
    if (choice == null) return;
    final current = _epoch;
    final failure = classifyFailure(event);
    _playerFailure = event.message;
    _logger.error(LogCategory.player, 'item failed', {
      'mode': modeLabel,
      'kind': failure.name,
      'error': event.message,
      'domain': event.domain ?? '',
      'code': event.code ?? 0,
    });
    final time = currentSeconds;
    if (_local != null) {
      await _localItemFailed(failure, current);
      return;
    }
    final kind = TrackSelector.codecKind(choice.video);
    final source = _source;
    final unpatched = source != null && source.mode == PlaybackMode.direct && source.sourceEntry == 'hev1';
    switch (reaction(failure, btr: activeMode == PlaybackMode.btr, servedUnpatchedHEV1: unpatched, played: _itemPlayed)) {
      case ItemFailureReaction.fallBackToDirect:
        await _fallBackToDirect('item failed in btr mode', current);
      case ItemFailureReaction.nextCodec:
        await _nextCodec(kind, remember: false, time: time);
      case ItemFailureReaction.nextCodecRemembered:
        await _nextCodec(kind, remember: true, time: time);
      case ItemFailureReaction.restart:
        if (!_claimNetworkRestart()) {
          _fail(PlaybackFailure.network, StackTrace.current);
          return;
        }
        _logger.warn(LogCategory.player, 'restarting with fresh urls', {'at': time});
        await _begin(time);
      case ItemFailureReaction.restartOnceThenNextCodec:
        // Unexplained failures are often expired URLs: one fresh start before the codec is blamed.
        if (!_unknownRetried.contains(kind) && _claimNetworkRestart()) {
          _unknownRetried.add(kind);
          _logger.warn(LogCategory.player, 'unexplained failure, restarting with fresh urls', {'at': time, 'kind': kind});
          await _begin(time);
        } else {
          await _nextCodec(kind, remember: false, time: time);
        }
    }
  }

  /// The files hold one codec, so a refusal ends it; anything else is the local server's, which is prepared again
  /// once a minute at most.
  Future<void> _localItemFailed(ItemFailure failure, int current) async {
    if (failure == ItemFailure.format) {
      _fail(PlaybackFailure.localUnplayable, StackTrace.current);
      return;
    }
    if (!_claimNetworkRestart()) {
      _fail(PlaybackFailure.unplayable, StackTrace.current);
      return;
    }
    _logger.warn(LogCategory.player, 'local item failed, preparing again', {'at': currentSeconds});
    await _reload(current);
  }

  /// What a cached part's failure tells the user: its codec, its files, or the local server.
  static Object _localFailure(Object error) => switch (error) {
        PlaybackError(kind: PlaybackErrorKind.codecUnplayable) => PlaybackFailure.localUnplayable,
        PlaybackError(kind: PlaybackErrorKind.serverDown) => error,
        PlaybackError() || FileSystemException() => PlaybackFailure.localMissing,
        _ => error,
      };

  Future<void> _fallBackToDirect(String reason, int current) async {
    final choice = _choice;
    if (current != _epoch || choice == null) return;
    final next = _advance();
    _cancelRefresh();
    _fellBack = true;
    _phase = PlaybackPhase.loading;
    _updateModeStats();
    _notify();
    final time = currentSeconds;
    final expiring = urlsNearExpiry(choice, _now());
    _logger.warn(LogCategory.player, 'fallback to direct', {'reason': reason, 'at': time, 'urlsExpiring': expiring});
    if (expiring) {
      await _begin(time);
      return;
    }
    if (!directCanPlay(choice.video, sourceEntry: _source?.sourceEntry)) {
      await _chooseAgain(time);
      return;
    }
    try {
      await _prepareAndLoad(choice, time, next);
      _scheduleRefresh(choice, next);
    } catch (error, stack) {
      await _handle(error, stack, time, next);
    }
  }

  /// A BTR request failed after every retry: fresh URLs once per start, then direct mode.
  Future<void> _ripperFailed(String error, int current) async {
    if (current != _epoch || _choice == null) return;
    // A pipelined request that failed before the refresh landed says nothing about the new URLs.
    if (_refreshingAfterFatal) {
      _logger.info(LogCategory.player, 'btr range failed during url refresh, ignored', {'error': error});
      return;
    }
    if (!_refreshedAfterFatal) {
      _refreshedAfterFatal = true;
      _refreshingAfterFatal = true;
      _logger.warn(LogCategory.player, 'btr range failed, refreshing urls', {'error': error});
      await _refreshUrls(current);
      if (current == _epoch) _refreshingAfterFatal = false;
      return;
    }
    await _fallBackToDirect('btr failed again', current);
  }

  bool _claimNetworkRestart() {
    final now = _now();
    final last = _lastNetworkRestart;
    if (last != null && now.difference(last).inMilliseconds < networkRestartSeconds * 1000) return false;
    _lastNetworkRestart = now;
    return true;
  }

  void _scheduleRefresh(TrackChoice choice, int current, {bool retry = false}) {
    _cancelRefresh();
    final double wait;
    if (retry) {
      wait = refreshRetrySeconds;
    } else {
      final deadline = urlDeadline(choice.video);
      if (deadline == null) return;
      wait = max(minRefreshWaitSeconds, deadline - _now().millisecondsSinceEpoch / 1000 - urlMarginSeconds);
    }
    _refreshTimer = _startTimer(Duration(milliseconds: (wait * 1000).round()), () {
      _refreshTimer = null;
      if (current == _epoch) unawaited(_refreshUrls(current));
    });
  }

  /// BTR swaps the engine's URLs in place; direct mode's playlists name the CDN, so it reloads where it is.
  Future<void> _refreshUrls(int current) async {
    final choice = _choice;
    final token = _token;
    if (choice == null || token == null || current != _epoch) return;
    final TrackChoice refreshed;
    try {
      final info = await _playUrl();
      if (current != _epoch || token != _token) return;
      final dash = info.dash;
      // Another codec chosen later must come from these URLs, not the ones about to expire.
      if (dash != null) _dash = dash;
      _qualities = info.qualityOptions;
      _notify();
      final video = dash?.video
          .where((stream) => stream.id == choice.video.id && stream.codecid == choice.video.codecid)
          .firstOrNull;
      final audio = dash?.audio.where((stream) => stream.id == choice.audio.id).firstOrNull;
      if (video == null || audio == null) {
        _logger.warn(LogCategory.player, 'url refresh found no matching streams');
        return;
      }
      refreshed = TrackChoice(video: video, audio: audio);
      if (activeMode == PlaybackMode.btr) {
        await _engine.replaceUrls(token, TrackKind.video, primary: video.baseURL, backups: video.backupURLs);
        await _engine.replaceUrls(token, TrackKind.audio, primary: audio.baseURL, backups: audio.backupURLs);
        if (current != _epoch || token != _token) return;
        _choice = refreshed;
        _logger.info(LogCategory.player, 'urls refreshed', {'mode': modeLabel});
        _scheduleRefresh(refreshed, current);
        return;
      }
    } catch (error) {
      _logger.warn(LogCategory.player, 'url refresh failed, retrying',
          {'error': '$error', 'seconds': refreshRetrySeconds});
      if (current == _epoch && token == _token) _scheduleRefresh(choice, current, retry: true);
      return;
    }
    _logger.info(LogCategory.player, 'urls refreshed, reloading direct', {'at': currentSeconds});
    _choice = refreshed;
    await _reload(current);
  }

  void _onPlayerEvent(PlayerEvent event) {
    if (_disposed) return;
    // Readings from before the player took the new load would move the clock back to the old one.
    if (_awaitingLoad && (event is PositionChanged || event is DurationChanged)) return;
    final accepted = clock.handle(event);
    switch (event) {
      case PositionChanged(:final seconds, :final rate):
        if (rate > 0) _rate = rate;
        final playing = _status == PlayerStatus.playing;
        // A stale reading from before a seek landed would time the seek as done.
        if (accepted) {
          final ms = _seekTimer.ticked(position: seconds, rate: _playerRate, playing: playing, atMs: _nowMs());
          if (ms != null) _seekResumed(ms, 'playhead');
          _feedEngine(seconds);
        }
        danmaku.update(positionMs: (seconds * 1000).round(), playing: playing);
      case DurationChanged(:final seconds):
        if (seconds > 0 && seconds.isFinite) {
          duration.value = seconds;
          danmaku.durationMs = (seconds * 1000).round();
        }
      case StatusChanged(:final status):
        _statusChanged(status);
      case RateChanged(:final rate):
        if (rate > 0) _rate = rate;
      case SizeChanged(:final width, :final height):
        _videoSize = (width: width, height: height);
        _notify();
      case PlayerFailed():
        if (_awaitingLoad || _choice == null || _phase == PlaybackPhase.idle || _phase == PlaybackPhase.failed) return;
        unawaited(_itemFailed(event).catchError((Object error, StackTrace stack) => _fail(error, stack)));
      case PictureInPictureChanged(:final active):
        _pictureInPicture = active;
        _logger.info(LogCategory.player, 'pip', {'active': active});
        _notify();
      case PictureInPictureRestore():
        _restores.add(null);
      case BufferedChanged(:final ranges):
        _buffered = ranges;
      case PlayerLog(:final kind, :final fields):
        _logger.info(LogCategory.player, kind, {
          for (final MapEntry(:key, :value) in fields.entries) key: ?value,
        });
    }
  }

  void _statusChanged(PlayerStatus status) {
    _status = status;
    if (status == PlayerStatus.loading) {
      _awaitingLoad = false;
      return;
    }
    if (_awaitingLoad || _choice == null) return;
    final now = _nowMs();
    switch (status) {
      case PlayerStatus.playing:
        _playWhenLoaded = true;
        _itemPlayed = true;
        if (!_sawFirstFrame) {
          _sawFirstFrame = true;
          final ms = now - _startedAtMs;
          if (_firstFrameTimed) stats.value = stats.value.copyWith(firstFrameMs: ms);
          final choice = _choice;
          _mark(FirstFrame(ms, timed: _firstFrameTimed));
          _logger.info(LogCategory.player, 'first frame', {
            'ms': ms.round(),
            'timed': _firstFrameTimed,
            'mode': modeLabel,
            'quality': choice?.video.id ?? 0,
            'codecs': choice?.video.codecs ?? '',
            'kbps': (choice?.video.bandwidth ?? 0) ~/ 1000,
            'audioKbps': (choice?.audio.bandwidth ?? 0) ~/ 1000,
          });
        }
        final seekMs = _seekTimer.playing(atMs: now);
        if (seekMs != null) _seekResumed(seekMs, 'status');
        if (!_autoPipSet && _autoPipWanted && player.capabilities.pictureInPicture) {
          _autoPipSet = true;
          _quietly(() => player.setAutoPictureInPicture(true), 'auto pip');
        }
        _phase = PlaybackPhase.playing;
        _notify();
      case PlayerStatus.buffering:
        // Waits before this load first played are startup, not stalls.
        if (_itemPlayed && !_seekTimer.isRunning) {
          final token = _btrToken;
          if (token != null) _engine.reportStall(token);
          _checkStall();
        }
      case PlayerStatus.paused:
        _seekTimer.paused();
        if (_itemPlayed) _playWhenLoaded = false;
      case PlayerStatus.ended:
        _playWhenLoaded = false;
        _logger.info(LogCategory.player, 'ended', {'mode': modeLabel});
        if (!_endings.isClosed) _endings.add(null);
      case PlayerStatus.idle || PlayerStatus.loading:
        break;
    }
  }

  void _checkStall() {
    final current = _epoch;
    final stalledAt = _nowMs();
    final at = currentSeconds;
    late final Timer timer;
    timer = _startTimer(const Duration(milliseconds: 750), () {
      _stallChecks.remove(timer);
      // Playing again within the wait is a hiccup, not a 卡顿.
      if (current != _epoch || _disposed || _status != PlayerStatus.buffering) return;
      final fields = <String, Object>{'at': at.round(), 'mode': modeLabel};
      if (_stallFilter.isSeekWait(stalledAt)) {
        _logger.info(LogCategory.player, 'seek wait', fields);
      } else {
        stats.value = stats.value.copyWith(stalls: stats.value.stalls + 1);
        _logger.warn(LogCategory.player, 'stall', fields);
        _mark(Stall(at));
      }
    });
    _stallChecks.add(timer);
  }

  void _seekResumed(double ms, String via) {
    final s = stats.value;
    final lag = StallFilter.isLag(ms);
    stats.value = s.copyWith(
      lastSeekMs: ms,
      worstSeekMs: max(s.worstSeekMs ?? 0, ms),
      stalls: lag ? s.stalls + 1 : s.stalls,
    );
    _logger.info(LogCategory.player, 'seek resumed',
        {'ms': ms.round(), 'mode': modeLabel, 'via': via, 'lag': lag, 'precise': _seekPrecise});
    _mark(SeekResumed(ms));
  }

  void _mark(PlaybackMark mark) {
    if (!_marks.isClosed) _marks.add(mark);
  }

  /// The token of the source playing through the engine; null in direct mode and while nothing is loaded.
  String? get _btrToken => _source?.mode == PlaybackMode.btr ? _token : null;

  /// A regular playhead reading: the engine hears it, with the buffer ahead, at most every [engineFeedMs].
  void _feedEngine(double seconds) {
    final token = _btrToken;
    if (token == null) return;
    final now = _nowMs();
    final last = _lastFeedMs;
    if (last != null && now - last < engineFeedMs) return;
    _lastFeedMs = now;
    _engine.updatePlayhead(token, seconds: seconds, rate: _playerRate);
    final ahead = _buffered.where((range) => range.start <= seconds + 0.5 && range.end >= seconds).firstOrNull;
    _engine.reportBuffer(token,
        aheadSeconds: ahead == null ? 0 : ahead.end - seconds, playing: _status == PlayerStatus.playing);
  }

  /// Swift fed the session from AVPlayer's time observer, which also fires on jumps: a seek or a load reaches the
  /// engine at once. The rate is the one playback resumes at; the buffer waits for the next regular reading.
  void _jumpedTo(double seconds) {
    final token = _btrToken;
    if (token == null) return;
    _lastFeedMs = _nowMs();
    _engine.updatePlayhead(token, seconds: seconds, rate: _rate);
  }

  void _onEngineFatal(FatalReport report) {
    if (_disposed || report.token != _btrToken) return;
    unawaited(_ripperFailed(report.message, _epoch).catchError((Object error, StackTrace stack) => _fail(error, stack)));
  }

  void _onEngineStats(EngineSnapshot snapshot) {
    if (_disposed || _token == null || activeMode != PlaybackMode.btr) return;
    // Another page's playback on the shared engine.
    if (snapshot.token case final token? when token != _token) return;
    stats.value = stats.value.copyWith(
      engine: snapshot,
      downloadBps: snapshot.downloadBps,
      transport: snapshot.transport.isEmpty ? null : snapshot.transport,
    );
  }

  /// Direct mode has no engine stats; its download speed is the player's business.
  void _updateModeStats() {
    final s = stats.value;
    final btr = activeMode == PlaybackMode.btr;
    stats.value = OverlayStats(
      mode: activeMode,
      stream: s.stream,
      transport: s.transport,
      firstFrameMs: s.firstFrameMs,
      lastSeekMs: s.lastSeekMs,
      worstSeekMs: s.worstSeekMs,
      stalls: s.stalls,
      downloadBps: btr ? s.downloadBps : 0,
      engine: btr ? s.engine : null,
    );
  }

  /// The player's rate as AVPlayer reports it: zero unless playing or waiting to play.
  double get _playerRate =>
      _status == PlayerStatus.playing || _status == PlayerStatus.buffering ? _rate : 0;

  void _stopPlayback() {
    _heldPosition = currentSeconds;
    _advance();
    _teardownPlayback();
    _choice = null;
    _dash = null;
    _playing = null;
    _phase = PlaybackPhase.idle;
  }

  void _fail(Object error, StackTrace stack) {
    _heldPosition = currentSeconds;
    _advance();
    _teardownPlayback();
    _choice = null;
    _dash = null;
    _playing = null;
    _failWith(error, _logged(error));
  }

  /// A file error's own text carries its path, which names the app's container: the OS's words only.
  static String _logged(Object error) {
    if (error is! FileSystemException) return '$error';
    final os = error.osError?.message ?? '';
    return os.isEmpty ? error.message : os;
  }

  void _failWith(Object error, String detail) {
    _phase = PlaybackPhase.failed;
    _error = userMessage(error);
    _logger.error(LogCategory.player, 'failed', {'error': detail});
    _notify();
  }

  static String userMessage(Object error) => switch (error) {
        BiliError() => error.userMessage,
        PlaybackError() => error.userMessage,
        PlaybackFailure() => error.userMessage,
        IOException() || TimeoutException() => '网络连接失败，请检查网络后重试',
        _ => '播放失败，请稍后重试',
      };

  void _teardownPlayback() {
    _cancelRefresh();
    for (final timer in _stallChecks) {
      timer.cancel();
    }
    _stallChecks.clear();
    _seekTimer.cancel();
    // The released item can still report a failure; it must not take over the next load.
    _awaitingLoad = true;
    final token = _token;
    _token = null;
    _source = null;
    if (token != null) _release(token);
    if (!_disposed) _quietly(player.pause, 'pause');
  }

  void _release(String token) => _quietly(() => _engine.release(token), 'release');

  void _cancelRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  int _advance() => ++_epoch;

  void _ensureCurrent(int current) {
    if (current != _epoch) throw const _Stale();
  }

  double _nowMs() => _monotonic.nowMs();

  void _quietly(Future<void> Function() action, String what) {
    unawaited(Future.sync(action).catchError((Object error) {
      _logger.warn(LogCategory.player, '$what failed', {'error': '$error'});
    }));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _advance();
    _teardownPlayback();
    _detailRetry?.cancel();
    unawaited(_playerEvents.cancel());
    unawaited(_engineStats.cancel());
    unawaited(_engineFatals.cancel());
    _quietly(player.dispose, 'player dispose');
    _quietly(_engine.dispose, 'engine dispose');
    danmaku.dispose();
    stats.dispose();
    duration.dispose();
    unawaited(_marks.close());
    unawaited(_endings.close());
    unawaited(_restores.close());
    super.dispose();
  }
}

/// Work of an older epoch; dropped without a word.
final class _Stale implements Exception {
  const _Stale();
}

/// Direct mode got a stream whose hev1 label holds a real hev1 entry: choose again without one.
final class _Reroute implements Exception {
  const _Reroute();
}
