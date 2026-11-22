import 'dart:async';
import 'dart:math' show max;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart' show PlaybackMode;
import 'package:bili_core/logic.dart' as logic show Autoplay, LoopMode, NextPlay, NextReplay, NextStop, PlayItem;
import 'package:bili_core/shared.dart' show MonotonicClock;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../home/feed_model.dart' show requestFailureMessage;
import '../playback/overlay_stats.dart';
import '../playback/playback_controller.dart';
import '../player/bili_player.dart';
import '../player/playback_clock.dart';
import '../player_ui/player_readout.dart';
import 'player_prefs.dart';
import 'player_session.dart';

/// Plays another part or video on the same playback: PagePlayback opens it, so its watch reports stay right.
typedef SessionOpen = void Function(String bvid, {int? cid});

typedef PeriodicTimer = Timer Function(Duration period, void Function() tick);

/// A timestamp in the description seeks there and plays, as Swift's `activate(.timestamp)` does.
extension SeekAndPlay on PlayerSession {
  /// Plays once the seek has landed, unless already playing. Not [PlayerSession.togglePlay], which would play an
  /// ended video again from the start.
  Future<void> seekAndPlay(double seconds) async {
    // Before the duration is known commitSeek does nothing, and playing would start from the wrong place.
    if (duration.value <= 0) return;
    await commitSeek(seconds);
    if (readout.wantsPlay) return;
    if (this case final PagePlayerSession session) session._willPlay?.call();
    try {
      await player.play();
    } catch (error) {
      Logger.shared.warn(LogCategory.player, 'play failed', {'error': '$error'});
    }
  }
}

/// The video page's [PlayerSession] over the page's own controller. [onSeeked] hears every seek the session makes,
/// for the page's watch reports; ⋮'s 稍后再看 goes to [requestLogin] without an account; [willPlay] runs before it
/// plays.
PlayerSession createPageSession({
  required PlaybackController controller,
  required AppServices services,
  required SessionOpen open,
  required VoidCallback requestLogin,
  void Function(double seconds)? onSeeked,
  VoidCallback? willPlay,
  PlayerPrefs? prefs,
  SessionPlaylist? playlist,
}) {
  final environment = services.environment;
  return PagePlayerSession(
    controller: controller,
    client: environment.client,
    open: open,
    isVip: () => switch (environment.account) {
      LoggedIn(:final vip) => vip,
      _ => false,
    },
    isLoggedIn: () => environment.account is LoggedIn,
    requestLogin: requestLogin,
    accountChanges: environment,
    onSeeked: onSeeked,
    willPlay: willPlay,
    prefs: prefs,
    playlist: playlist,
  );
}

/// What an offline page plays in turn (离线缓存): its cached videos in place of the parts and the 合集, for 选集, ⏭ and
/// 自动连播. It notifies when the list changes; the session it is handed to disposes it.
abstract interface class SessionPlaylist implements Listenable {
  /// In order; [Episode.current] is left false, the session sets it.
  List<Episode> get episodes;

  void dispose();
}

/// The player half of BiliNative's VideoPageModel: seeks, speed, the end rules (单集循环, 自动连播, 列表循环), 定时关闭,
/// 看点 and related videos, and the panels' switches, over the page's [PlaybackController]. [willPlay] runs before every
/// play it starts (play, 重播, a timestamp), so another page's small window closes first. With a [playlist] it is an
/// offline page's: the cached videos stand in for the parts and the 合集, and it fetches nothing (no related videos,
/// 看点 or seek frames) and changes no quality, codec or mode.
class PagePlayerSession extends ChangeNotifier with WidgetsBindingObserver implements PlayerSession {
  PagePlayerSession({
    required PlaybackController controller,
    required this._client,
    required this._open,
    required this._isVip,
    required this._isLoggedIn,
    required this._requestLogin,
    Listenable? accountChanges,
    this._onSeeked,
    this._willPlay,
    PlayerPrefs? prefs,
    SessionPlaylist? playlist,
    MonotonicClock? clock,
    PeriodicTimer? periodic,
    StartTimer? startTimer,
    Logger? logger,
  })  : _controller = controller,
        _accountChanges = accountChanges,
        _prefs = prefs ?? PlayerPrefs.shared,
        _playlist = playlist,
        _monotonic = clock ?? MonotonicClock.system,
        _periodic = periodic ?? _systemPeriodic,
        _startTimer = startTimer ?? Timer.new,
        _logger = logger ?? Logger.shared {
    readout = PlayerReadout(clock: controller.clock, events: controller.player.events);
    final state = WidgetsBinding.instance.lifecycleState;
    _background = state == AppLifecycleState.hidden || state == AppLifecycleState.paused;
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_controllerChanged);
    accountChanges?.addListener(notifyListeners);
    playlist?.addListener(notifyListeners);
    _endings = controller.endings.listen((_) => unawaited(_handleEnd()));
    _applyPrefs();
    _controllerChanged();
    // Made after the app went to the background (the controller comes asynchronously), no lifecycle change follows.
    if (_background && _active) _startBackgroundCheck();
  }

  /// Hold to speed up plays at this rate.
  static const speedUpRate = 2.0;

  /// Auto picture in picture can report its start after the app is already in the background.
  static const backgroundGrace = Duration(seconds: 1);

  static Timer _systemPeriodic(Duration period, void Function() tick) => Timer.periodic(period, (_) => tick());

  final PlaybackController _controller;
  final BiliClient _client;
  final SessionOpen _open;
  final bool Function() _isVip;
  final bool Function() _isLoggedIn;
  final VoidCallback _requestLogin;
  final Listenable? _accountChanges;
  final void Function(double seconds)? _onSeeked;
  final VoidCallback? _willPlay;
  final PlayerPrefs _prefs;
  final SessionPlaylist? _playlist;
  final MonotonicClock _monotonic;
  final PeriodicTimer _periodic;
  final StartTimer _startTimer;
  final Logger _logger;
  late final StreamSubscription<void> _endings;

  @override
  late final PlayerReadout readout;

  @override
  final ValueNotifier<double?> scrubbing = ValueNotifier(null);

  @override
  final ValueNotifier<Duration?> sleepRemaining = ValueNotifier(null);

  /// Bumped by every scrub and seek, so a seek that lands after a newer drag began leaves [scrubbing] alone.
  int _seekCount = 0;

  /// A hint went out during this drag.
  bool _hinted = false;
  bool _speedingUp = false;
  bool _ended = false;
  bool _background = false;
  Timer? _backgroundCheck;

  /// In the background, waiting for a load to start playing so it can be paused.
  bool _watchingLoad = false;
  Duration? _sleepTimer;
  double _sleepDeadlineMs = 0;
  Timer? _sleepTicker;

  /// What 定时关闭 had left when the page was covered; it counts on from there once the page is active again.
  double? _sleepLeftMs;
  List<Chapter> _chapters = const [];
  List<VideoCard> _related = const [];

  /// The part [chapters] belong to, and the video [related] belongs to.
  logic.PlayItem? _chaptersFor;
  String? _relatedFor;
  logic.PlayItem? _current;
  PlaybackPhase? _phaseSeen;
  bool _disposed = false;
  bool _active = true;

  /// What a new page starts with: the saved settings, at 1× and unmirrored (Swift kept those per page). Before the
  /// part is chosen none of these restarts anything.
  void _applyPrefs() {
    final controller = _controller;
    if (controller.rate != 1) _quietly(() => controller.setRate(1), 'rate');
    if (controller.mirrored) _quietly(() => controller.setMirrored(false), 'mirror');
    if (controller.fit != _prefs.fit) _quietly(() => controller.setFit(_prefs.fit), 'fit');
    if (offline) return;
    final mode = _prefs.btr ? PlaybackMode.btr : PlaybackMode.direct;
    if (controller.mode != mode) _quietly(() => controller.setMode(mode), 'mode');
    final quality = _prefs.quality;
    if (quality != null && quality != controller.selectedQuality) {
      _quietly(() => controller.setQuality(quality), 'quality');
    }
    final codec = _prefs.codec;
    if (codec != null && codec != controller.codec) _quietly(() => controller.setCodec(codec), 'codec');
  }

  @override
  BiliPlayer get player => _controller.player;

  @override
  PlaybackClock get clock => _controller.clock;

  @override
  ValueListenable<double> get duration => _controller.duration;

  @override
  ValueListenable<OverlayStats> get stats => _controller.stats;

  @override
  VideoView? get video => _controller.video;

  @override
  VideoPage? get part => _controller.page;

  bool get _inParts => (video?.pages.length ?? 0) > 1;

  @override
  String get title {
    final part = this.part;
    if (_inParts && part != null && part.part.isNotEmpty) return part.part;
    return video?.title ?? '';
  }

  /// The stream's shape once known, before that the signed view's.
  @override
  bool get isVertical {
    final size = _controller.videoSize;
    if (size != null) return size.height > size.width;
    return detail?.isVertical ?? false;
  }

  @override
  bool get layoutVertical => opening && videoShape == null ? _shapeVertical : isVertical;

  /// [isVertical] when a shape was last known.
  bool _shapeVertical = false;

  @override
  ({int width, int height})? get videoShape {
    if (_controller.videoSize case final size?) return size;
    final detail = this.detail;
    if (detail == null || detail.width <= 0 || detail.height <= 0) return null;
    return (width: detail.width, height: detail.height);
  }

  @override
  bool get loopsAtEnd => _loopsAtEnd;
  bool _loopsAtEnd = false;

  /// Turned on over the end screen (entering 竖屏 after the end), it plays again from 0 at once. A covered page plays
  /// nothing.
  @override
  set loopsAtEnd(bool value) {
    _loopsAtEnd = value;
    final current = _current;
    if (!value || !_ended || _disposed || !_active || current == null) return;
    _logger.info(LogCategory.ui, 'vertical loop', {'cid': current.cid, 'ended': true});
    unawaited(replay());
  }

  @override
  List<Chapter> get chapters => _chapters;

  @override
  List<VideoCard> get related => _related;

  @override
  bool get offline => _playlist != null;

  @override
  bool get episodesAreParts => !offline && _inParts;

  /// Titles as EpisodesPanel.swift shows them: `P2 名字` for parts, the episode's own title for 合集. An offline page's
  /// are its cached videos.
  @override
  List<Episode> get episodes {
    final cid = part?.cid;
    if (_playlist case final playlist?) {
      return [
        for (final episode in playlist.episodes)
          episode.cid == cid ? _withCurrent(episode, current: true) : episode,
      ];
    }
    final video = this.video;
    if (video == null) return const [];
    if (_inParts) {
      return [for (final page in video.pages) _partEpisode(video, page, current: page.cid == cid)];
    }
    return [
      for (final episode in _section(video)?.episodes ?? const <SeasonEpisode>[])
        _seasonEpisode(episode, current: episode.bvid == video.bvid),
    ];
  }

  static String _partTitle(VideoPage page) => 'P${page.page} ${page.part}';

  Episode _partEpisode(VideoView video, VideoPage page, {required bool current}) => Episode(
        bvid: video.bvid,
        cid: page.cid,
        title: _inParts ? _partTitle(page) : video.title,
        current: current,
        duration: _known(page.duration),
      );

  static Episode _seasonEpisode(SeasonEpisode episode, {required bool current}) => Episode(
        bvid: episode.bvid,
        cid: episode.cid,
        title: episode.title,
        current: current,
        cover: episode.cover.isEmpty ? null : episode.cover,
        duration: _known(episode.duration),
        pubdate: _known(episode.pubdate),
        views: episode.views,
        danmaku: episode.danmaku,
      );

  /// The API models read a missing duration or date as 0.
  static int? _known(int value) => value > 0 ? value : null;

  static Episode _withCurrent(Episode episode, {required bool current}) => Episode(
        bvid: episode.bvid,
        cid: episode.cid,
        title: episode.title,
        current: current,
        cover: episode.cover,
        duration: episode.duration,
        pubdate: episode.pubdate,
        views: episode.views,
        danmaku: episode.danmaku,
      );

  /// The 合集 section holding [video], else the first.
  SeasonSection? _section(VideoView video) {
    final sections = _controller.season?.sections ?? const <SeasonSection>[];
    return sections.where((section) => section.episodes.any((episode) => episode.bvid == video.bvid)).firstOrNull ??
        sections.firstOrNull;
  }

  List<logic.PlayItem> get _partItems => offline
      ? const []
      : [for (final page in video?.pages ?? const <VideoPage>[]) logic.PlayItem(bvid: video!.bvid, cid: page.cid)];

  /// Every section's episodes in order, as Swift's `episodeItems`; an offline page's cached videos.
  List<logic.PlayItem> get _episodeItems => switch (_playlist) {
        final playlist? => [
            for (final episode in playlist.episodes) logic.PlayItem(bvid: episode.bvid, cid: episode.cid),
          ],
        null => [
            for (final section in _controller.season?.sections ?? const <SeasonSection>[])
              for (final episode in section.episodes) logic.PlayItem(bvid: episode.bvid, cid: episode.cid),
          ],
      };

  @override
  Episode? get next {
    final current = _current;
    if (current == null) return null;
    final step = logic.Autoplay.next(
      after: current,
      parts: _partItems,
      episodes: _episodeItems,
      autoplay: true,
      loop: loop == LoopMode.list ? logic.LoopMode.list : logic.LoopMode.none,
    );
    if (step is! logic.NextPlay) return null;
    return _episodeFor(step.item);
  }

  Episode _episodeFor(logic.PlayItem item) {
    if (_playlist case final playlist?) {
      return playlist.episodes.where((episode) => episode.cid == item.cid).firstOrNull ??
          Episode(bvid: item.bvid, cid: item.cid, title: '', current: false);
    }
    final video = this.video;
    if (video != null && item.bvid == video.bvid) {
      final page = video.pages.where((page) => page.cid == item.cid).firstOrNull;
      if (page != null) return _partEpisode(video, page, current: false);
    }
    final episode = _controller.season?.sections
        .expand((section) => section.episodes)
        .where((episode) => episode.bvid == item.bvid && episode.cid == item.cid)
        .firstOrNull;
    if (episode != null) return _seasonEpisode(episode, current: false);
    return Episode(bvid: item.bvid, cid: item.cid, title: '', current: false);
  }

  @override
  Uri? get shareLink {
    final video = this.video;
    if (video == null) return null;
    final page = part?.page ?? 1;
    return Uri.parse('https://www.bilibili.com/video/${video.bvid}${page > 1 ? '?p=$page' : ''}');
  }

  void _controllerChanged() {
    // Kept while covered too: the page can be shown again mid-open.
    if (videoShape != null) _shapeVertical = isVertical;
    if (_disposed || !_active) return;
    _follow();
  }

  /// Follows the controller's video: 看点 once per part, related videos once per video.
  void _follow() {
    final video = _controller.video;
    final page = _controller.page;
    final phase = _controller.phase;
    // Another open began: the end screen gives way to its spinner rather than waiting for the new part.
    if (phase == PlaybackPhase.loading && _phaseSeen != PlaybackPhase.loading) _ended = false;
    // A part change or reload under a held finger: the load put the chosen rate back, and the hold's end restores it.
    if (_speedingUp && phase == PlaybackPhase.playing && _phaseSeen == PlaybackPhase.loading) {
      _quietly(() => player.setRate(speedUpRate), 'speed up');
    }
    _phaseSeen = phase;
    if (offline) {
      final item = video == null || page == null ? null : logic.PlayItem(bvid: video.bvid, cid: page.cid);
      if (item != null && item != _current) {
        _current = item;
        _ended = false;
      }
      notifyListeners();
      return;
    }
    if (video != null && video.bvid != _relatedFor) {
      _relatedFor = video.bvid;
      _related = const [];
      unawaited(_loadRelated(video.bvid));
    }
    final item = video == null || page == null ? null : logic.PlayItem(bvid: video.bvid, cid: page.cid);
    if (item != null && item != _current) {
      _current = item;
      _ended = false;
      if (item != _chaptersFor) {
        _chaptersFor = item;
        final known = _controller.playerInfoFor(item.cid);
        _chapters = known?.chapters ?? const [];
        if (known == null) unawaited(_loadChapters(item));
      }
    }
    notifyListeners();
  }

  Future<void> _loadRelated(String bvid) async {
    try {
      final cards = await _client.related(bvid: bvid);
      if (_disposed || _relatedFor != bvid) return;
      _related = cards;
      notifyListeners();
    } catch (error) {
      _logger.warn(LogCategory.api, 'related failed', {'bvid': bvid, 'error': '$error'});
    }
  }

  @override
  ValueListenable<VideoShot?> get seekFrames => _seekFrames;
  final _seekFrames = ValueNotifier<VideoShot?>(null);
  logic.PlayItem? _seekFramesFor;

  /// An offline page shows the time alone: the frames are Bilibili's.
  @override
  void wantSeekFrames() {
    final item = _current;
    if (offline || item == null || item == _seekFramesFor) return;
    _seekFramesFor = item;
    _seekFrames.value = null;
    unawaited(_loadSeekFrames(item));
  }

  Future<void> _loadSeekFrames(logic.PlayItem item) async {
    try {
      final shot = await _client.videoShot(bvid: item.bvid, cid: item.cid);
      if (_disposed || _seekFramesFor != item) return;
      _seekFrames.value = shot.usable ? shot : null;
    } catch (error) {
      _logger.warn(LogCategory.api, 'seek frames failed', {'bvid': item.bvid, 'cid': item.cid, 'error': '$error'});
    }
  }

  Future<void> _loadChapters(logic.PlayItem item) async {
    try {
      final info = await _client.playerInfo(bvid: item.bvid, cid: item.cid);
      if (_disposed || _chaptersFor != item) return;
      _chapters = info.chapters;
      notifyListeners();
    } catch (error) {
      _logger.warn(LogCategory.api, 'player info failed', {'bvid': item.bvid, 'cid': item.cid, 'error': '$error'});
    }
  }

  @override
  void togglePlay() {
    if (readout.wantsPlay) {
      _quietly(player.pause, 'pause');
      return;
    }
    if (_ended || readout.status.value == PlayerStatus.ended) {
      unawaited(replay());
      return;
    }
    _willPlay?.call();
    _quietly(player.play, 'play');
  }

  @override
  double get position => scrubbing.value ?? readout.seconds.value;

  @override
  void scrub(double seconds) {
    if (duration.value <= 0) return;
    _seekCount += 1;
    scrubbing.value = seconds;
  }

  @override
  void hint(double seconds) {
    if (duration.value <= 0) return;
    _hinted = true;
    _controller.seekHint(seconds);
  }

  @override
  void cancelScrub() {
    scrubbing.value = null;
    if (_hinted) _controller.seekHint(null);
    _hinted = false;
  }

  @override
  Future<void> commitSeek(double seconds, {bool precise = false}) async {
    // No duration yet, or it went with the video under the finger: the bar lets go rather than holding a target.
    if (duration.value <= 0) {
      cancelScrub();
      return;
    }
    _hinted = false;
    final count = ++_seekCount;
    scrubbing.value = seconds;
    _setEnded(false);
    try {
      final seeked = player.seek(seconds, precise: precise);
      _controller.userSeeked(seconds, precise: precise);
      _onSeeked?.call(seconds);
      readout.refresh();
      await seeked;
    } catch (error) {
      _logger.warn(LogCategory.player, 'seek failed', {'error': '$error'});
    } finally {
      // The bar holds the target until the seek lands, so it doesn't jump back to the old position first.
      if (!_disposed && _seekCount == count) scrubbing.value = null;
    }
  }

  @override
  double get rate => _controller.rate;

  @override
  Future<String?> setRate(double rate) {
    _speedingUp = false;
    return _attempt(() => _controller.setRate(rate), 'rate', '切换倍速失败');
  }

  @override
  void speedUp(bool on) {
    if (on == _speedingUp) return;
    _speedingUp = on;
    _quietly(() => player.setRate(on ? speedUpRate : _controller.rate), 'speed up');
    notifyListeners();
  }

  @override
  bool get speedingUp => _speedingUp;

  @override
  FitMode get fit => _controller.fit;

  @override
  Future<String?> setFit(FitMode fit) async {
    final failure = await _attempt(() => _controller.setFit(fit), 'fit', '切换画面尺寸失败');
    // The controller put the old fit back, and the next page shouldn't start with the refused one.
    if (failure == null) _prefs.fit = fit;
    return failure;
  }

  @override
  bool get mirrored => _controller.mirrored;

  @override
  Future<String?> setMirrored(bool on) => _attempt(() => _controller.setMirrored(on), 'mirror', '切换镜像失败');

  @override
  LoopMode get loop => _prefs.loop;

  @override
  void setLoop(LoopMode mode) {
    _prefs.loop = mode;
    notifyListeners();
  }

  @override
  bool get autoplayNext => _prefs.autoplay;

  @override
  void setAutoplayNext(bool on) {
    _prefs.autoplay = on;
    notifyListeners();
  }

  @override
  Duration? get sleepTimer => _sleepTimer;

  @override
  void setSleepTimer(Duration? after) {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepLeftMs = null;
    if (after == null || after <= Duration.zero) {
      _sleepTimer = null;
      sleepRemaining.value = null;
      notifyListeners();
      return;
    }
    _sleepTimer = after;
    sleepRemaining.value = after;
    _logger.info(LogCategory.ui, 'sleep timer', {'minutes': after.inMinutes});
    if (_active) {
      _sleepDeadlineMs = _monotonic.nowMs() + after.inMilliseconds;
      _sleepTicker = _periodic(const Duration(seconds: 1), _sleepTick);
    } else {
      _sleepLeftMs = after.inMilliseconds.toDouble();
    }
    notifyListeners();
  }

  /// A covered page's 定时关闭 waits for it to show again.
  void _pauseSleepTimer() {
    final ticker = _sleepTicker;
    if (ticker == null) return;
    ticker.cancel();
    _sleepTicker = null;
    _sleepLeftMs = max(0.0, _sleepDeadlineMs - _monotonic.nowMs());
  }

  void _resumeSleepTimer() {
    final left = _sleepLeftMs;
    _sleepLeftMs = null;
    if (left == null || _sleepTimer == null) return;
    _sleepDeadlineMs = _monotonic.nowMs() + left;
    _sleepTicker = _periodic(const Duration(seconds: 1), _sleepTick);
  }

  void _sleepTick() {
    if (_disposed || !_active) return;
    final left = _sleepDeadlineMs - _monotonic.nowMs();
    if (left > 0) {
      sleepRemaining.value = Duration(milliseconds: left.round());
      return;
    }
    _logger.info(LogCategory.ui, 'sleep timer fired');
    _quietly(player.pause, 'pause');
    setSleepTimer(null);
  }

  @override
  bool get danmakuOn => _prefs.danmakuOn;

  @override
  void setDanmakuOn(bool on) {
    _prefs.danmakuOn = on;
    notifyListeners();
  }

  @override
  bool get showStats => _prefs.showStats;

  @override
  void setShowStats(bool on) {
    _prefs.showStats = on;
    notifyListeners();
  }

  @override
  bool get btr => _controller.mode == PlaybackMode.btr;

  /// An offline page's quality, codec and mode are its files': picking one changes nothing, the saved choice included.
  @override
  Future<String?> setBtr(bool on) {
    if (offline) return Future.value();
    _prefs.btr = on;
    final mode = on ? PlaybackMode.btr : PlaybackMode.direct;
    return _attempt(() => _controller.setMode(mode), 'btr switch', '切换 BTR 加速失败');
  }

  @override
  List<QualityOption> get qualities => _controller.qualities;

  @override
  Dash? get dash => _controller.dash;

  @override
  int get quality => _controller.selectedQuality;

  @override
  int get playingQuality => _controller.playing?.quality ?? quality;

  @override
  String qualityName(int qn) => _controller.qualityName(qn);

  @override
  bool get isVip => _isVip();

  @override
  Future<String?> setQuality(int qn) {
    if (offline) return Future.value();
    _prefs.quality = qn;
    return _attempt(() => _controller.setQuality(qn), 'quality', '切换清晰度失败');
  }

  @override
  VideoCodec get codec => _controller.codec;

  @override
  Future<String?> setCodec(VideoCodec codec) {
    if (offline) return Future.value();
    _prefs.codec = codec;
    return _attempt(() => _controller.setCodec(codec), 'codec', '切换编码失败');
  }

  @override
  bool get ended => _ended;

  @override
  bool get opening => _controller.phase == PlaybackPhase.loading;

  void _setEnded(bool value) {
    if (_ended == value) return;
    _ended = value;
    notifyListeners();
  }

  Future<void> _handleEnd() async {
    final current = _current;
    if (_disposed || !_active || current == null) return;
    // The same video, so unlike autoplay it isn't held back in the background: 单集循环's replay does the same.
    if (_loopsAtEnd) {
      _logger.info(LogCategory.ui, 'vertical loop', {'cid': current.cid});
      await replay();
      return;
    }
    final step = logic.Autoplay.next(
      after: current,
      parts: _partItems,
      episodes: _episodeItems,
      autoplay: autoplayNext,
      loop: switch (loop) {
        LoopMode.single => logic.LoopMode.single,
        LoopMode.list => logic.LoopMode.list,
        LoopMode.off => logic.LoopMode.none,
      },
    );
    switch (step) {
      case logic.NextReplay():
        await replay();
      case logic.NextPlay(:final item):
        // The next part would play as audio only.
        if (_background && !_controller.pictureInPicture) {
          _logger.info(LogCategory.ui, 'autoplay skipped in the background', {'cid': item.cid});
          _setEnded(true);
          return;
        }
        _logger.info(LogCategory.ui, 'autoplay', {'bvid': item.bvid, 'cid': item.cid});
        _open(item.bvid, cid: item.cid);
      case logic.NextStop():
        _setEnded(true);
    }
  }

  @override
  Future<void> replay() async {
    _willPlay?.call();
    _setEnded(false);
    unawaited(player.seek(0, precise: true).catchError((Object error) {
      _logger.warn(LogCategory.player, 'seek failed', {'error': '$error'});
    }));
    _controller.userSeeked(0);
    _onSeeked?.call(0);
    readout.refresh();
    try {
      await player.play();
    } catch (error) {
      _logger.warn(LogCategory.player, 'play failed', {'error': '$error'});
    }
  }

  @override
  void playEpisode(Episode episode) {
    if (episode.current) return;
    _setEnded(false);
    _open(episode.bvid, cid: episode.cid);
  }

  @override
  void playRelated(VideoCard card) {
    _setEnded(false);
    _open(card.bvid);
  }

  /// Empty when it asked for the login instead.
  @override
  Future<ActionResult> watchLater() async {
    if (!_isLoggedIn()) return _login();
    final aid = video?.aid ?? 0;
    if (aid == 0) return const ActionResult('视频还没有加载完', ok: false);
    try {
      await _client.addToWatchLater(aid: aid);
      return const ActionResult('已添加至稍后再看', ok: true);
    } catch (error) {
      _logger.warn(LogCategory.ui, 'watch later failed', {'error': '$error'});
      if (error is BiliError && error.needsLogin) return _login();
      return ActionResult(requestFailureMessage(error), ok: false);
    }
  }

  ActionResult _login() {
    if (!_disposed) _requestLogin();
    return const ActionResult('', ok: false);
  }

  @override
  bool get pictureInPictureSupported => player.capabilities.pictureInPicture;

  @override
  Future<String?> startPictureInPicture() =>
      _attempt(_controller.startPictureInPicture, 'pip start', '小窗播放启动失败');

  @override
  bool get canCaptureFrame => player.capabilities.frameCapture;

  @override
  Future<ActionResult> captureFrame() async {
    try {
      if (await player.captureFrame()) return const ActionResult('已保存到相册', ok: true);
      _logger.warn(LogCategory.ui, 'frame capture failed');
    } catch (error) {
      _logger.warn(LogCategory.ui, 'frame capture failed', {'error': '$error'});
    }
    return const ActionResult('保存失败', ok: false);
  }

  @override
  VideoDetail? get detail => _controller.detail;

  @override
  bool get detailFailed => _controller.detailFailed;

  @override
  void retryDetail() => _controller.retryDetail();

  @override
  set active(bool value) {
    if (_disposed || value == _active) return;
    _active = value;
    if (!value) {
      _pauseSleepTimer();
      _stopBackgroundChecks();
      return;
    }
    _resumeSleepTimer();
    if (_background) _startBackgroundCheck();
    _follow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state == AppLifecycleState.hidden || state == AppLifecycleState.paused;
    if (background == _background) return;
    _background = background;
    _stopBackgroundChecks();
    if (background && _active) _startBackgroundCheck();
  }

  void _startBackgroundCheck() {
    _backgroundCheck?.cancel();
    _backgroundCheck = _startTimer(backgroundGrace, () {
      _backgroundCheck = null;
      if (_disposed || !_active || !_background || _controller.pictureInPicture) return;
      if (readout.wantsPlay) {
        _pauseInBackground();
      } else if (_controller.phase == PlaybackPhase.loading || readout.status.value == PlayerStatus.loading) {
        // The load would start playing, with sound, after this check.
        _watchingLoad = true;
        readout.status.addListener(_loadStatusChanged);
      }
    });
  }

  void _loadStatusChanged() {
    if (!readout.wantsPlay) return;
    _stopBackgroundChecks();
    if (_disposed || !_active || !_background || _controller.pictureInPicture) return;
    _pauseInBackground();
  }

  void _stopBackgroundChecks() {
    _backgroundCheck?.cancel();
    _backgroundCheck = null;
    if (!_watchingLoad) return;
    _watchingLoad = false;
    readout.status.removeListener(_loadStatusChanged);
  }

  void _pauseInBackground() {
    _logger.info(LogCategory.ui, 'paused in the background');
    _quietly(player.pause, 'pause');
  }

  /// A setter's work: a failure is logged and answered with [toast].
  Future<String?> _attempt(Future<void> Function() action, String what, String toast) async {
    try {
      await action();
      return null;
    } catch (error) {
      _logger.warn(LogCategory.player, '$what failed', {'error': '$error'});
      return toast;
    }
  }

  void _quietly(Future<void> Function() action, String what) {
    unawaited(Future.sync(action).catchError((Object error) {
      _logger.warn(LogCategory.player, '$what failed', {'error': '$error'});
    }));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_controllerChanged);
    _accountChanges?.removeListener(notifyListeners);
    _playlist
      ?..removeListener(notifyListeners)
      ..dispose();
    unawaited(_endings.cancel());
    _sleepTicker?.cancel();
    _stopBackgroundChecks();
    if (_speedingUp) _quietly(() => player.setRate(_controller.rate), 'speed up');
    readout.dispose();
    scrubbing.dispose();
    _seekFrames.dispose();
    sleepRemaining.dispose();
    super.dispose();
  }
}
