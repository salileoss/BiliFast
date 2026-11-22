import 'package:bili_core/api.dart'
    show Chapter, Dash, QualityOption, VideoCard, VideoCodec, VideoDetail, VideoPage, VideoShot, VideoView;
import 'package:bilifast/playback/overlay_stats.dart';
import 'package:bilifast/player/bili_player.dart';
import 'package:bilifast/player/playback_clock.dart';
import 'package:bilifast/player_ui/player_readout.dart';
import 'package:bilifast/video/player_session.dart';
import 'package:flutter/foundation.dart';

import 'fake_player.dart';

/// A [PlayerSession] for widget tests: fields the test sets, and [calls] recording what the controls asked for.
/// Change a field, then [changed] to notify.
class FakePlayerSession extends ChangeNotifier implements PlayerSession {
  FakePlayerSession({FakePlayer? player, PlaybackClock? clock}) : player = player ?? FakePlayer(), clock = clock ?? PlaybackClock() {
    readout = PlayerReadout(clock: this.clock, events: this.player.events);
  }

  @override
  final FakePlayer player;

  @override
  final PlaybackClock clock;

  @override
  late final PlayerReadout readout;

  final List<String> calls = [];

  void changed() => notifyListeners();

  @override
  final ValueNotifier<double> duration = ValueNotifier(0);

  @override
  VideoView? video;

  @override
  VideoPage? part;

  @override
  VideoDetail? detail;

  @override
  String title = '';

  @override
  bool isVertical = false;

  /// Set to hold a shape through an in-page open, as the page's session does; [isVertical] otherwise.
  bool? heldVertical;

  @override
  bool get layoutVertical => heldVertical ?? isVertical;

  @override
  ({int width, int height})? videoShape;

  @override
  bool loopsAtEnd = false;

  @override
  List<Chapter> chapters = const [];

  @override
  List<VideoCard> related = const [];

  @override
  bool offline = false;

  @override
  List<Episode> episodes = const [];

  @override
  bool episodesAreParts = true;

  @override
  bool detailFailed = false;

  int detailRetries = 0;

  @override
  void retryDetail() => detailRetries += 1;

  @override
  Uri? shareLink;

  @override
  void togglePlay() => calls.add('togglePlay');

  @override
  final ValueNotifier<double?> scrubbing = ValueNotifier(null);

  @override
  double get position => scrubbing.value ?? readout.seconds.value;

  @override
  void scrub(double seconds) {
    calls.add('scrub $seconds');
    scrubbing.value = seconds;
  }

  @override
  void hint(double seconds) => calls.add('hint $seconds');

  @override
  void cancelScrub() {
    calls.add('cancelScrub');
    scrubbing.value = null;
  }

  @override
  final ValueNotifier<VideoShot?> seekFrames = ValueNotifier(null);

  @override
  void wantSeekFrames() => calls.add('wantSeekFrames');

  @override
  Future<void> commitSeek(double seconds, {bool precise = false}) async {
    calls.add('commitSeek $seconds${precise ? ' precise' : ''}');
    scrubbing.value = null;
  }

  @override
  double rate = 1;

  @override
  Future<String?> setRate(double rate) async {
    calls.add('setRate $rate');
    this.rate = rate;
    notifyListeners();
    return failure;
  }

  /// What every setter completes with: null for success, or a failure's toast text.
  String? failure;

  @override
  bool speedingUp = false;

  @override
  void speedUp(bool on) {
    calls.add('speedUp $on');
    speedingUp = on;
    notifyListeners();
  }

  @override
  FitMode fit = FitMode.fit;

  @override
  Future<String?> setFit(FitMode fit) async {
    calls.add('setFit ${fit.name}');
    this.fit = fit;
    notifyListeners();
    return failure;
  }

  @override
  bool mirrored = false;

  @override
  Future<String?> setMirrored(bool on) async {
    calls.add('setMirrored $on');
    mirrored = on;
    notifyListeners();
    return failure;
  }

  @override
  LoopMode loop = LoopMode.off;

  @override
  void setLoop(LoopMode mode) {
    calls.add('setLoop ${mode.name}');
    loop = mode;
    notifyListeners();
  }

  @override
  bool autoplayNext = true;

  @override
  void setAutoplayNext(bool on) {
    calls.add('setAutoplayNext $on');
    autoplayNext = on;
    notifyListeners();
  }

  @override
  Duration? sleepTimer;

  @override
  final ValueNotifier<Duration?> sleepRemaining = ValueNotifier(null);

  @override
  void setSleepTimer(Duration? after) {
    calls.add('setSleepTimer ${after?.inMinutes}');
    sleepTimer = after;
    sleepRemaining.value = after;
    notifyListeners();
  }

  @override
  bool danmakuOn = true;

  @override
  void setDanmakuOn(bool on) {
    calls.add('setDanmakuOn $on');
    danmakuOn = on;
    notifyListeners();
  }

  @override
  bool showStats = false;

  @override
  void setShowStats(bool on) {
    calls.add('setShowStats $on');
    showStats = on;
    notifyListeners();
  }

  @override
  final ValueNotifier<OverlayStats> stats = ValueNotifier(const OverlayStats());

  @override
  bool btr = true;

  @override
  Future<String?> setBtr(bool on) async {
    calls.add('setBtr $on');
    btr = on;
    notifyListeners();
    return failure;
  }

  @override
  List<QualityOption> qualities = const [];

  @override
  Dash? dash;

  @override
  int quality = 80;

  int? playing;

  @override
  int get playingQuality => playing ?? quality;

  @override
  String qualityName(int qn) => qualities.where((option) => option.id == qn).firstOrNull?.name ?? '$qn';

  @override
  bool isVip = false;

  @override
  Future<String?> setQuality(int qn) async {
    calls.add('setQuality $qn');
    quality = qn;
    notifyListeners();
    return failure;
  }

  @override
  VideoCodec codec = VideoCodec.hevc;

  @override
  Future<String?> setCodec(VideoCodec codec) async {
    calls.add('setCodec ${codec.name}');
    this.codec = codec;
    notifyListeners();
    return failure;
  }

  @override
  bool ended = false;

  @override
  bool opening = false;

  @override
  Episode? next;

  @override
  Future<void> replay() async => calls.add('replay');

  @override
  void playEpisode(Episode episode) => calls.add('playEpisode ${episode.bvid} ${episode.cid}');

  @override
  void playRelated(VideoCard card) => calls.add('playRelated ${card.bvid}');

  ActionResult watchLaterResult = const ActionResult('已添加至稍后再看', ok: true);

  @override
  Future<ActionResult> watchLater() async {
    calls.add('watchLater');
    return watchLaterResult;
  }

  @override
  bool pictureInPictureSupported = true;

  @override
  Future<String?> startPictureInPicture() async {
    calls.add('startPictureInPicture');
    return failure;
  }

  @override
  bool canCaptureFrame = true;

  ActionResult captureResult = const ActionResult('已保存到相册', ok: true);

  @override
  Future<ActionResult> captureFrame() async {
    calls.add('captureFrame');
    return captureResult;
  }

  @override
  bool active = true;

  @override
  void dispose() {
    readout.dispose();
    duration.dispose();
    scrubbing.dispose();
    sleepRemaining.dispose();
    stats.dispose();
    super.dispose();
  }
}
