import 'dart:async';
import 'dart:convert';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart';
import 'package:bili_core/shared.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/player/bili_player.dart';
import 'package:bilifast/player/playback_clock.dart';
import 'package:bilifast/video/page_session.dart';
import 'package:bilifast/video/player_prefs.dart';
import 'package:bilifast/video/player_session.dart';
import 'package:bilifast/video/watch_reporter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../playback/fakes.dart';
import '../support/fake_player.dart';

const bv = 'BV1GJ411x7h7';
const p1 = 137649199;
const p2 = 137649200;
const playerInfoPath = '/x/player/wbi/v2';
const relatedPath = '/x/web-interface/archive/related';
const watchLaterPath = '/x/v2/history/toview/add';
const heartbeatPath = '/x/click-interface/web/heartbeat';

String playerInfo({int lastPlayCid = 0, String chapter = '开场'}) =>
    '{"code":0,"data":{"last_play_cid":$lastPlayCid,"view_points":['
    '{"type":2,"from":0,"to":60,"content":"$chapter"},{"type":2,"from":60,"to":120,"content":"正片"}]}}';

const related =
    '{"code":0,"data":[{"aid":9,"bvid":"BV1EF411e9oF","cid":5,"title":"相关视频","pic":"","duration":60,'
    '"owner":{"mid":7,"name":"UP"},"stat":{"view":1,"danmaku":0,"like":0}}]}';

String _episode(String bvid, int cid, String title) =>
    '{"aid":1,"cid":$cid,"title":"$title","bvid":"$bvid","arc":{"aid":1,"title":"$title","duration":100,'
    '"pic":"https://i0.hdslb.com/$cid.jpg","pubdate":1700000000,"stat":{"view":12000,"danmaku":34}}}';

Episode _seasonEpisode(String bvid, int cid, String title, {required bool current}) => Episode(
      bvid: bvid,
      cid: cid,
      title: title,
      current: current,
      cover: 'https://i0.hdslb.com/$cid.jpg',
      duration: 100,
      pubdate: 1700000000,
      views: 12000,
      danmaku: 34,
    );

/// A one-part video [bvid] in a 合集 of two sections: 第一集 and 第二集, then 番外.
String seasonView(String bvid, int cid) =>
    '{"code":0,"data":{"bvid":"$bvid","aid":2,"title":"合集里的视频",'
    '"owner":{"mid":1,"name":"UP"},"pages":[{"cid":$cid,"page":1,"part":"","duration":100}],'
    '"ugc_season":{"id":1,"title":"合集","sections":['
    '{"id":1,"title":"正片","episodes":[${_episode('BV1AA411a1aa', 1001, '第一集')},${_episode('BV1BB411b1bb', 1002, '第二集')}]},'
    '{"id":2,"title":"特别篇","episodes":[${_episode('BV1CC411c1cc', 1003, '番外')}]}]}}}';

final class FakePeriodic {
  final ticks = <void Function()>[];
  final timers = <FakeTimer>[];

  Timer start(Duration period, void Function() tick) {
    final timer = FakeTimer(period, tick);
    ticks.add(tick);
    timers.add(timer);
    return timer;
  }

  void tick() {
    for (var i = 0; i < timers.length; i++) {
      if (timers[i].isActive) ticks[i]();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CannedHttp http;
  late FakeEngine engine;
  late FakePlayer player;
  late ManualClock time;
  late FakePeriodic periodic;
  late FakeTimers timers;
  late PlayerPrefs prefs;
  late List<String> opened;
  late List<double> seeks;
  late PlaybackController controller;
  late Set<String> refused;
  late MemorySink logs;
  late bool loggedIn;
  late int logins;
  final sessions = <PagePlayerSession>[];
  final controllers = <PlaybackController>[];

  setUp(() {
    http = Canned.http()
      ..routes[relatedPath] = (200, related)
      ..routes[watchLaterPath] = (200, '{"code":0,"message":"0"}');
    engine = FakeEngine();
    player = FakePlayer();
    time = ManualClock(10000);
    periodic = FakePeriodic();
    timers = FakeTimers();
    prefs = PlayerPrefs.memory();
    opened = [];
    seeks = [];
    refused = {};
    logs = MemorySink();
    loggedIn = true;
    logins = 0;
  });

  tearDown(() {
    for (final session in sessions) {
      session.dispose();
    }
    sessions.clear();
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
  });

  PlaybackController makeController() {
    final now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 1000) * 1000);
    final logger = Logger(session: 'test');
    final client = BiliClient(transport: http, cookies: CookieJar(Canned.cookies), now: () => now, logger: logger);
    controller = PlaybackController(
      client: client,
      engine: engine,
      player: RefusingPlayer(player, refused),
      clock: time.clock,
      now: () => now,
      startTimer: FakeTimers().start,
      logger: logger,
    );
    controllers.add(controller);
    return controller;
  }

  /// A session as the video page makes it: `open` plays on the same controller. [on] is a controller another page's
  /// session already has; [onSeeked] hears the seeks the page's watch reports would, else [seeks] keeps them.
  PagePlayerSession makeSession({PlaybackController? on, void Function(double seconds)? onSeeked}) {
    final controller = on ?? makeController();
    final now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 1000) * 1000);
    final session = PagePlayerSession(
      controller: controller,
      client: BiliClient(transport: http, cookies: CookieJar(Canned.cookies), now: () => now),
      open: (bvid, {cid}) {
        opened.add('$bvid ${cid ?? '-'}');
        unawaited(controller.openVideo(bvid, cid: cid));
      },
      isVip: () => false,
      isLoggedIn: () => loggedIn,
      requestLogin: () => logins += 1,
      onSeeked: onSeeked ?? seeks.add,
      prefs: prefs,
      clock: time.clock,
      periodic: periodic.start,
      startTimer: timers.start,
      logger: Logger(session: 'test')..add(logs),
    );
    sessions.add(session);
    return session;
  }

  void playing() {
    player.emit(const StatusChanged(PlayerStatus.playing));
    player.emit(const DurationChanged(712));
  }

  Future<void> ended() async {
    player.emit(const StatusChanged(PlayerStatus.ended));
    await settle();
  }

  int pauses() => player.calls.where((call) => call == 'pause').length;

  List<String> callsAfterLastLoad() => player.calls.sublist(player.calls.lastIndexWhere((c) => c.startsWith('load')));

  test('the chosen rate plays the next part too, and a new page starts at 1×', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    await session.setRate(1.5);
    expect(player.calls.last, 'rate 1.5');
    session.playEpisode(session.episodes[1]);
    await settle();
    expect(controller.page?.cid, p2);
    expect(callsAfterLastLoad(), contains('rate 1.5'), reason: 'applied after the load');
    expect(session.rate, 1.5);

    session.dispose();
    sessions.remove(session);
    final next = PagePlayerSession(
      controller: controller,
      client: BiliClient(transport: http, cookies: CookieJar(Canned.cookies)),
      open: (_, {cid}) {},
      isVip: () => false,
      isLoggedIn: () => true,
      requestLogin: () {},
      prefs: prefs,
    );
    sessions.add(next);
    expect(next.rate, 1);
  });

  test('hold to speed up plays at 2× without changing the rate, then goes back', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    await session.setRate(1.25);
    var notified = 0;
    session.addListener(() => notified++);
    session.speedUp(true);
    expect(player.calls.last, 'rate 2.0');
    expect(session.speedingUp, isTrue);
    expect(session.rate, 1.25);
    session.speedUp(false);
    expect(player.calls.last, 'rate 1.25');
    expect(session.speedingUp, isFalse);
    expect(notified, 2);
  });

  test('a hold only changes the rate of the player: no pause, play, seek or load; the engine just hears the rate',
      () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    playing();
    player.emit(PositionChanged(seconds: 0.2, hostMs: time.clock.nowMs(), rate: 1));
    await settle();
    player.calls.clear();
    final prepares = engine.prepared.length;
    final releases = engine.released.length;
    final hints = engine.hints.length;
    final drops = engine.cacheDrops;

    session.speedUp(true);
    // As AVPlayer reports a rate change: the rate, then readings at it.
    player.emit(const RateChanged(2));
    time.advance(600);
    player.emit(PositionChanged(seconds: 1.4, hostMs: time.clock.nowMs(), rate: 2));
    await settle();
    session.speedUp(false);
    player.emit(const RateChanged(1));
    time.advance(600);
    player.emit(PositionChanged(seconds: 2.0, hostMs: time.clock.nowMs(), rate: 1));
    await settle();

    expect(player.calls, ['rate 2.0', 'rate 1.0']);
    expect(engine.prepared, hasLength(prepares));
    expect(engine.released, hasLength(releases));
    expect(engine.hints, hasLength(hints));
    expect(engine.cacheDrops, drops);
    expect(engine.stalls, isEmpty);
    expect(engine.playheads.map((playhead) => playhead.rate), containsAllInOrder([2.0, 1.0]));
    expect(controller.rate, 1);
    expect(controller.phase, PlaybackPhase.playing);
  });

  test('fit and mirroring reach the player and stay for the next load; fit is saved', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    await session.setFit(FitMode.fill);
    await session.setMirrored(true);
    expect(prefs.fit, FitMode.fill);
    await controller.openVideo(bv, cid: p2);
    await settle();
    expect(callsAfterLastLoad(), containsAll(['fit fill', 'mirrored true']));
  });

  group('at the end', () {
    test('单集循环 plays the same part again from 0', () async {
      final session = makeSession()..setLoop(LoopMode.single);
      await controller.openVideo(bv, cid: p1);
      playing();
      player.calls.clear();
      await ended();
      expect(player.calls, containsAllInOrder(['seek 0.0 precise', 'play']));
      expect(opened, isEmpty);
      expect(session.ended, isFalse);
    });

    test('自动连播 opens the next part through the page', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      expect(session.next, const Episode(bvid: bv, cid: p2, title: 'P2 第二集', current: false, duration: 100));
      playing();
      await ended();
      expect(opened, ['$bv $p2']);
      expect(controller.page?.cid, p2);
    });

    test('without 自动连播 or a loop, the end screen shows', () async {
      final session = makeSession()..setAutoplayNext(false);
      await controller.openVideo(bv, cid: p1);
      playing();
      var notified = 0;
      session.addListener(() => notified++);
      await ended();
      expect(opened, isEmpty);
      expect(session.ended, isTrue);
      expect(notified, greaterThan(0));
    });

    test('the last part with nothing after it ends', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p2);
      expect(session.next, isNull);
      playing();
      await ended();
      expect(opened, isEmpty);
      expect(session.ended, isTrue);
    });

    test('列表循环 wraps from the last part to the first', () async {
      final session = makeSession()..setLoop(LoopMode.list);
      await controller.openVideo(bv, cid: p2);
      expect(session.next?.cid, p1);
      playing();
      await ended();
      expect(opened, ['$bv $p1']);
    });

    test('列表循环 wraps a 合集 from its last episode to its first', () async {
      http.routes[Canned.signedViewPath] = (200, seasonView('BV1CC411c1cc', 1003));
      makeSession().setLoop(LoopMode.list);
      await controller.openVideo('BV1CC411c1cc');
      playing();
      await ended();
      expect(opened, ['BV1AA411a1aa 1001']);
    });

    test('replay after the end screen plays from 0, and togglePlay does the same', () async {
      final session = makeSession()..setAutoplayNext(false);
      await controller.openVideo(bv, cid: p2);
      playing();
      await ended();
      expect(session.ended, isTrue);
      player.calls.clear();
      session.togglePlay();
      await settle();
      expect(player.calls, containsAllInOrder(['seek 0.0 precise', 'play']));
      expect(session.ended, isFalse);
    });
  });

  group('in 竖屏 (loopsAtEnd)', () {
    test('with 自动连播 on and a next part, the end plays the same part again from 0', () async {
      final session = makeSession()..loopsAtEnd = true;
      await controller.openVideo(bv, cid: p1);
      expect(session.next?.cid, p2);
      playing();
      player.calls.clear();
      await ended();
      expect(player.calls, containsAllInOrder(['seek 0.0 precise', 'play']));
      expect(opened, isEmpty);
      expect(controller.page?.cid, p1);
      expect(session.ended, isFalse);
      expect(seeks, [0], reason: 'the page hears the jump to 0, as 单集循环 tells it');
      expect(logs.events.map((event) => event.msg), contains('vertical loop'));
    });

    test('with 自动连播 and the loop off, the last part plays again instead of the end screen, every time', () async {
      final session = makeSession()
        ..setAutoplayNext(false)
        ..loopsAtEnd = true;
      expect(session.loop, LoopMode.off);
      await controller.openVideo(bv, cid: p2);
      playing();
      player.calls.clear();
      await ended();
      playing();
      await ended();
      expect(player.calls.where((call) => call == 'seek 0.0 precise'), hasLength(2));
      expect(session.ended, isFalse);
      expect(opened, isEmpty);
    });

    test('列表循环 and a 合集\'s next episode give way to it too', () async {
      http.routes[Canned.signedViewPath] = (200, seasonView('BV1AA411a1aa', 1001));
      final session = makeSession()
        ..setLoop(LoopMode.list)
        ..loopsAtEnd = true;
      await controller.openVideo('BV1AA411a1aa');
      expect(session.next?.bvid, 'BV1BB411b1bb');
      playing();
      player.calls.clear();
      await ended();
      expect(player.calls, containsAllInOrder(['seek 0.0 precise', 'play']));
      expect(opened, isEmpty);
    });

    test('out of 竖屏 again, the end follows 自动连播 and shows the end screen as before', () async {
      final session = makeSession()
        ..loopsAtEnd = true
        ..loopsAtEnd = false;
      await controller.openVideo(bv, cid: p1);
      playing();
      await ended();
      expect(opened, ['$bv $p2']);
      expect(controller.page?.cid, p2);

      session.setAutoplayNext(false);
      playing();
      player.calls.clear();
      await ended();
      expect(session.ended, isTrue);
      expect(player.calls, isNot(contains('seek 0.0 precise')));
      expect(logs.events.map((event) => event.msg), isNot(contains('vertical loop')));
    });

    test('turned on over the end screen, it plays again from 0 at once; otherwise turning it does nothing', () async {
      final session = makeSession()..setAutoplayNext(false);
      await controller.openVideo(bv, cid: p2);
      playing();
      await ended();
      expect(session.ended, isTrue);
      player.calls.clear();
      session.loopsAtEnd = false;
      await settle();
      expect(player.calls, isEmpty);
      expect(session.ended, isTrue);

      session.loopsAtEnd = true;
      await settle();
      expect(player.calls, containsAllInOrder(['seek 0.0 precise', 'play']));
      expect(session.ended, isFalse);
      expect(seeks, [0]);

      player.calls.clear();
      session.loopsAtEnd = false;
      session.loopsAtEnd = true;
      await settle();
      expect(player.calls, isEmpty, reason: 'playing, nothing restarts');
    });

    test('a covered page turned on over its end screen plays nothing', () async {
      final session = makeSession()..setAutoplayNext(false);
      await controller.openVideo(bv, cid: p2);
      playing();
      await ended();
      session.active = false;
      player.calls.clear();
      session.loopsAtEnd = true;
      await settle();
      expect(player.calls, isEmpty);
      expect(session.ended, isTrue);
    });

    test('in the background it starts over too: paused by the background check without picture in picture, '
        'playing on in it', () async {
      final session = makeSession()..loopsAtEnd = true;
      await controller.openVideo(bv, cid: p1);
      playing();
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      player.calls.clear();
      await ended();
      expect(player.calls, containsAllInOrder(['seek 0.0 precise', 'play']));
      expect(opened, isEmpty);
      player.emit(const StatusChanged(PlayerStatus.playing));
      timers.activeWith(PagePlayerSession.backgroundGrace)!.fire();
      expect(player.calls.last, 'pause');

      session.didChangeAppLifecycleState(AppLifecycleState.resumed);
      player.emit(const StatusChanged(PlayerStatus.playing));
      player.emit(const PictureInPictureChanged(true));
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      player.calls.clear();
      await ended();
      expect(player.calls, containsAllInOrder(['seek 0.0 precise', 'play']));
      player.emit(const StatusChanged(PlayerStatus.playing));
      timers.activeWith(PagePlayerSession.backgroundGrace)!.fire();
      expect(player.calls, isNot(contains('pause')));
      expect(opened, isEmpty);
    });

    test('the watch reports go on over the loop: the end, 0, then every 15 s again', () async {
      http.routes[heartbeatPath] = (200, '{"code":0,"message":"0"}');
      final now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 1000) * 1000);
      WatchReporter? reporter;
      makeSession(onSeeked: (seconds) => reporter?.seeked(seconds)).loopsAtEnd = true;
      final opening = controller.openVideo(bv, cid: p1);
      reporter = WatchReporter(
        controller: controller,
        client: BiliClient(transport: http, cookies: CookieJar(Canned.cookies), now: () => now),
        loggedIn: () => true,
      );
      await opening;
      void position(double seconds) {
        time.advance(PlaybackClock.jumpSettleMs);
        player.emit(PositionChanged(seconds: seconds, hostMs: time.clock.nowMs(), rate: 1));
      }

      playing();
      position(16);
      await ended();
      player.emit(const StatusChanged(PlayerStatus.playing));
      position(5);
      position(16);
      await ended();
      await reporter.leave();
      final played = [
        for (final request in http.to(heartbeatPath))
          Uri.splitQueryString(utf8.decode(request.body!))['played_time'],
      ];
      expect(played, ['0', '16', '-1', '0', '16', '-1', '0', '0'], reason: 'the last is leaving, back at 0');
    });
  });

  test('a one-part video in a 合集: 选集 lists its section and 自动连播 plays the next episode', () async {
    http.routes[Canned.signedViewPath] = (200, seasonView('BV1AA411a1aa', 1001));
    final session = makeSession();
    await controller.openVideo('BV1AA411a1aa');
    expect(session.episodesAreParts, isFalse);
    expect(session.episodes, [
      _seasonEpisode('BV1AA411a1aa', 1001, '第一集', current: true),
      _seasonEpisode('BV1BB411b1bb', 1002, '第二集', current: false),
    ]);
    expect(session.next, _seasonEpisode('BV1BB411b1bb', 1002, '第二集', current: false));
    expect(session.title, '合集里的视频');
    playing();
    await ended();
    expect(opened, ['BV1BB411b1bb 1002']);
  });

  test('a video in parts lists its parts as P1 name, titles with the part and shares with ?p', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p2);
    expect(session.episodesAreParts, isTrue);
    expect(session.episodes.map((e) => (e.title, e.current, e.duration)), [
      ('P1 第一集', false, 712),
      ('P2 第二集', true, 100),
    ]);
    expect(session.episodes.map((e) => e.cover), [null, null], reason: 'parts have no cover of their own');
    expect(session.title, '第二集');
    expect(session.shareLink.toString(), 'https://www.bilibili.com/video/$bv?p=2');
    await controller.openVideo(bv, cid: p1);
    expect(session.shareLink.toString(), 'https://www.bilibili.com/video/$bv');
  });

  group('in the background', () {
    test('without picture in picture the player pauses; with it, it plays on', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      player.calls.clear();
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      timers.activeWith(PagePlayerSession.backgroundGrace)!.fire();
      expect(player.calls, ['pause']);

      session.didChangeAppLifecycleState(AppLifecycleState.resumed);
      player.emit(const StatusChanged(PlayerStatus.playing));
      player.emit(const PictureInPictureChanged(true));
      player.calls.clear();
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      timers.activeWith(PagePlayerSession.backgroundGrace)!.fire();
      expect(player.calls, isEmpty);
    });

    test('autoplay is skipped without picture in picture', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      await ended();
      expect(opened, isEmpty);
      expect(session.ended, isTrue);
    });

    test('with picture in picture autoplay goes on', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      player.emit(const PictureInPictureChanged(true));
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      await ended();
      expect(opened, ['$bv $p2']);
    });
  });

  test('定时关闭 counts down, pauses at zero and turns itself off', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    playing();
    session.setSleepTimer(const Duration(minutes: 1));
    expect(session.sleepTimer, const Duration(minutes: 1));
    expect(session.sleepRemaining.value, const Duration(minutes: 1));
    time.advance(30000);
    periodic.tick();
    expect(session.sleepRemaining.value, const Duration(seconds: 30));
    player.calls.clear();
    time.advance(30000);
    periodic.tick();
    expect(player.calls, ['pause']);
    expect(session.sleepTimer, isNull);
    expect(session.sleepRemaining.value, isNull);
    expect(periodic.timers.every((timer) => !timer.isActive), isTrue);

    session.setSleepTimer(const Duration(minutes: 15));
    session.setSleepTimer(null);
    expect(session.sleepRemaining.value, isNull);
    expect(periodic.timers.every((timer) => !timer.isActive), isTrue);
  });

  group('看点', () {
    test('the player info that chose the part gives its chapters; another part asks once for its own', () async {
      http.routes[playerInfoPath] = (200, playerInfo(lastPlayCid: p1));
      final session = makeSession();
      await controller.openVideo(bv);
      await settle();
      expect(http.to(playerInfoPath), hasLength(1));
      expect(session.chapters.map((c) => c.title), ['开场', '正片']);

      http.routes[playerInfoPath] = (200, playerInfo(chapter: '第二P开场'));
      session.playEpisode(session.episodes[1]);
      await settle();
      expect(http.to(playerInfoPath), hasLength(2));
      expect(http.to(playerInfoPath).last.url.queryParameters['cid'], '$p2');
      expect(session.chapters.first.title, '第二P开场');
    });

    test('a part given asks once; a failure leaves none', () async {
      http.routes[playerInfoPath] = (500, '');
      final session = makeSession();
      await controller.openVideo(bv, cid: p2);
      await settle();
      expect(http.to(playerInfoPath), hasLength(1));
      expect(session.chapters, isEmpty);
    });
  });

  test('related videos are asked for once per video, not per part', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    await settle();
    expect(session.related.single.bvid, 'BV1EF411e9oF');
    await controller.openVideo(bv, cid: p2);
    await settle();
    expect(http.to(relatedPath), hasLength(1));
    session.playRelated(session.related.single);
    expect(opened, ['BV1EF411e9oF -']);
  });

  test('once its page left, the session ignores the next page\'s video', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    await settle();
    session.active = false;
    controller.close();
    http.routes[Canned.signedViewPath] = (200, seasonView('BV1AA411a1aa', 1001));
    await controller.openVideo('BV1AA411a1aa');
    await settle();
    expect(http.to(relatedPath), hasLength(1));
    expect(session.related.single.bvid, 'BV1EF411e9oF');
    playing();
    await ended();
    expect(opened, isEmpty);
  });

  group('inactive (covered by another video page, or left)', () {
    test('a page left before its video arrived follows nothing of the next page\'s', () async {
      final gate = http.gates[Canned.signedViewPath] = Completer<void>();
      final first = makeSession();
      unawaited(controller.openVideo(bv, cid: p1));
      await settle();
      first.active = false;
      controller.close();
      final second = makeSession(on: controller);
      unawaited(controller.openVideo(bv, cid: p2));
      gate.complete();
      await settle();
      expect(controller.page?.cid, p2);
      expect(http.to(relatedPath), hasLength(1));
      expect(http.to(playerInfoPath), hasLength(1));
      expect(first.related, isEmpty);
      expect(second.related.single.bvid, 'BV1EF411e9oF');
    });

    test('a covered page runs no end rules: 单集循环 seeks once when the page above ends', () async {
      final first = makeSession()..setLoop(LoopMode.single);
      await controller.openVideo(bv, cid: p1);
      playing();
      first.active = false;
      final opening = controller.openVideo(bv, cid: p2);
      final second = makeSession(on: controller);
      await opening;
      playing();
      player.calls.clear();
      await ended();
      expect(player.calls.where((call) => call == 'seek 0.0 precise'), hasLength(1));
      expect(second.ended, isFalse);
    });

    test('a covered page\'s 定时关闭 stops counting, then counts on from where it was', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      session.setSleepTimer(const Duration(minutes: 1));
      time.advance(20000);
      periodic.tick();
      session.active = false;
      player.calls.clear();
      time.advance(120000);
      periodic.tick();
      expect(player.calls, isEmpty);
      expect(session.sleepRemaining.value, const Duration(seconds: 40));
      session.active = true;
      time.advance(39000);
      periodic.tick();
      expect(session.sleepRemaining.value, const Duration(seconds: 1));
      time.advance(1000);
      periodic.tick();
      expect(player.calls, ['pause']);
    });

    test('a covered page leaves the background alone', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      session.active = false;
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(timers.active, isEmpty);
      session.active = true;
      player.calls.clear();
      timers.activeWith(PagePlayerSession.backgroundGrace)!.fire();
      expect(player.calls, ['pause'], reason: 'active again in the background, it checks again');
    });

    test('active again, it catches up with its player at once', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      await settle();
      session.active = false;
      await controller.openVideo(bv, cid: p2);
      await settle();
      final asked = http.to(playerInfoPath).length;
      session.active = true;
      await settle();
      expect(http.to(playerInfoPath), hasLength(asked + 1), reason: "P2's 看点");
      playing();
      await ended();
      expect(session.ended, isTrue, reason: 'its end rules apply again: nothing plays after the last part');
    });
  });

  group('the end screen', () {
    test('gives way as soon as another open starts, before its video arrives', () async {
      final session = makeSession()..setAutoplayNext(false);
      await controller.openVideo(bv, cid: p1);
      playing();
      await ended();
      expect(session.ended, isTrue);
      final view = http.gates[Canned.signedViewPath] = Completer<void>();
      session.playEpisode(session.episodes[1]);
      expect(session.ended, isFalse);
      view.complete();
      await settle();

      playing();
      await ended();
      expect(session.ended, isTrue, reason: 'P2 is the last part');
      final again = http.gates[Canned.signedViewPath] = Completer<void>();
      unawaited(controller.openVideo(bv, cid: p1));
      expect(session.ended, isFalse, reason: "the page's own open");
      again.complete();
      await settle();
    });
  });

  group('backgrounded during a load', () {
    test('the load is paused as soon as it starts playing, once', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      timers.activeWith(PagePlayerSession.backgroundGrace)!.fire();
      player.calls.clear();
      player.emit(const StatusChanged(PlayerStatus.buffering));
      expect(pauses(), 1);
      player.emit(const StatusChanged(PlayerStatus.paused));
      player.emit(const StatusChanged(PlayerStatus.playing));
      expect(pauses(), 1);
    });

    test('back in front first, or in picture in picture, it plays', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      timers.activeWith(PagePlayerSession.backgroundGrace)!.fire();
      session.didChangeAppLifecycleState(AppLifecycleState.resumed);
      player.calls.clear();
      player.emit(const StatusChanged(PlayerStatus.playing));
      expect(pauses(), 0);

      await controller.openVideo(bv, cid: p2);
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      timers.activeWith(PagePlayerSession.backgroundGrace)!.fire();
      player.emit(const PictureInPictureChanged(true));
      player.calls.clear();
      player.emit(const StatusChanged(PlayerStatus.playing));
      expect(pauses(), 0);
    });
  });

  test('isVertical: the stream\'s shape once known, the signed view\'s before, nothing of the last video', () async {
    http.routes[Canned.signedViewPath] = (
      200,
      Canned.view.replaceFirst('"pages"', '"dimension":{"width":1080,"height":1920,"rotate":0},"pages"'),
    );
    final session = makeSession();
    final playUrl = http.gates[Canned.playUrlPath] = Completer<void>();
    final opening = controller.openVideo(bv, cid: p1);
    await settle();
    expect(session.detail?.bvid, bv);
    expect(session.isVertical, isTrue, reason: 'no stream yet');
    playUrl.complete();
    await opening;
    expect(session.isVertical, isFalse, reason: 'the chosen stream is 3840×2160');
    player.emit(const SizeChanged(width: 1080, height: 1920));
    expect(session.isVertical, isTrue);

    http.routes[Canned.signedViewPath] = (200, seasonView('BV1AA411a1aa', 1001));
    final next = http.gates[Canned.playUrlPath] = Completer<void>();
    final other = controller.openVideo('BV1AA411a1aa');
    await settle();
    expect(session.video?.bvid, 'BV1AA411a1aa');
    expect(session.isVertical, isFalse);
    next.complete();
    await other;
  });

  test("layoutVertical keeps the last video's shape through an open of another, until the next one's is in", () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    player.emit(const SizeChanged(width: 1080, height: 1920));
    expect(session.layoutVertical, isTrue);

    http.routes[Canned.signedViewPath] = (200, seasonView('BV1AA411a1aa', 1001));
    final view = http.gates[Canned.signedViewPath] = Completer<void>();
    final playUrl = http.gates[Canned.playUrlPath] = Completer<void>();
    final other = controller.openVideo('BV1AA411a1aa');
    expect(session.opening, isTrue);
    expect(session.isVertical, isFalse, reason: 'nothing of the last video');
    expect(session.layoutVertical, isTrue);
    view.complete();
    await settle();
    expect(session.detail?.bvid, 'BV1AA411a1aa');
    expect(session.layoutVertical, isTrue, reason: 'its detail has no shape');
    playUrl.complete();
    await other;
    expect(session.layoutVertical, isFalse, reason: 'its stream is 3840×2160');

    player.emit(const SizeChanged(width: 1080, height: 1920));
    const wideShape = '"dimension":{"width":1920,"height":1080,"rotate":0},"pages"';
    http.routes[Canned.signedViewPath] = (200, seasonView('BV1BB411b1bb', 1002).replaceFirst('"pages"', wideShape));
    final wideStream = http.gates[Canned.playUrlPath] = Completer<void>();
    final wide = controller.openVideo('BV1BB411b1bb');
    expect(session.layoutVertical, isTrue);
    await settle();
    expect(session.opening, isTrue);
    expect(session.layoutVertical, isFalse, reason: "the next one's detail says it is wide");
    wideStream.complete();
    await wide;
  });

  String lastRate() => player.calls.lastWhere((call) => call.startsWith('rate'));

  test('holding 2× through an autoplay part change plays the next part at 2×, and at the chosen rate when let go',
      () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    await session.setRate(1.5);
    playing();
    session.speedUp(true);
    expect(player.calls.last, 'rate 2.0');
    await ended();
    expect(controller.page?.cid, p2);
    playing();
    await settle();
    expect(lastRate(), 'rate 2.0', reason: 'the finger is still down');
    expect(session.speedingUp, isTrue);
    player.calls.clear();
    session.speedUp(false);
    await settle();
    expect(player.calls, ['rate 1.5']);
    expect(session.rate, 1.5);
    expect(session.speedingUp, isFalse);
  });

  test('a quality reload under a held finger stays at 2×, and a reload without one keeps the chosen rate', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    await session.setRate(1.25);
    playing();
    session.speedUp(true);
    await session.setQuality(80);
    await settle();
    playing();
    await settle();
    expect(callsAfterLastLoad(), contains('rate 1.25'), reason: 'the controller puts the chosen rate back');
    expect(lastRate(), 'rate 2.0');
    session.speedUp(false);
    expect(lastRate(), 'rate 1.25');

    await session.setQuality(120);
    await settle();
    playing();
    await settle();
    expect(lastRate(), 'rate 1.25');
  });

  group('a timestamp', () {
    test('seeks and plays a paused video', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      player.emit(const StatusChanged(PlayerStatus.paused));
      player.calls.clear();
      await session.seekAndPlay(30);
      expect(player.calls, containsAllInOrder(['seek 30.0', 'play']));
    });

    test('just seeks a playing video', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      player.calls.clear();
      await session.seekAndPlay(30);
      expect(player.calls, contains('seek 30.0'));
      expect(player.calls, isNot(contains('play')));
    });

    test('after the end plays from the timestamp, not from the start', () async {
      final session = makeSession()..setAutoplayNext(false);
      await controller.openVideo(bv, cid: p2);
      playing();
      await ended();
      expect(session.ended, isTrue);
      player.calls.clear();
      await session.seekAndPlay(50);
      expect(player.calls, containsAllInOrder(['seek 50.0', 'play']));
      expect(player.calls, isNot(contains('seek 0.0 precise')));
      expect(session.ended, isFalse);
    });
  });

  group('setters', () {
    test('one the player refuses answers with its toast, keeps the old value and logs why', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      expect(await session.setRate(1.5), isNull);
      refused.addAll({'rate', 'fit', 'mirrored', 'pip'});
      expect(await session.setRate(2), '切换倍速失败');
      expect(session.rate, 1.5);
      expect(await session.setFit(FitMode.fill), '切换画面尺寸失败');
      expect(session.fit, FitMode.fit);
      expect(prefs.fit, FitMode.fit, reason: 'the next page does not start with it');
      expect(await session.setMirrored(true), '切换镜像失败');
      expect(session.mirrored, isFalse);
      expect(await session.startPictureInPicture(), '小窗播放启动失败');
      expect(logs.events.map((event) => event.msg),
          containsAll(['rate failed', 'fit failed', 'mirror failed', 'pip start failed']));
    });

    test('a switch that throws answers with its toast', () async {
      final refusing = _RefusingController(
        client: BiliClient(transport: http, cookies: CookieJar(Canned.cookies)),
        engine: engine,
        player: player,
      );
      controllers.add(refusing);
      final session = makeSession(on: refusing);
      expect(await session.setBtr(false), '切换 BTR 加速失败');
      expect(await session.setQuality(80), '切换清晰度失败');
      expect(await session.setCodec(VideoCodec.avc), '切换编码失败');
    });
  });

  test('稍后再看 toasts what happened', () async {
    final session = makeSession();
    expect((await session.watchLater()).message, '视频还没有加载完');
    await controller.openVideo(bv, cid: p1);
    expect((await session.watchLater()).message, '已添加至稍后再看');
    expect(http.to(watchLaterPath), hasLength(1));
    http.routes[watchLaterPath] = (200, '{"code":-412,"message":""}');
    expect((await session.watchLater()).ok, isFalse);
    expect(logins, 0);
  });

  test('稍后再看 logged out asks for the login once and sends nothing', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    loggedIn = false;
    final result = await session.watchLater();
    expect((result.message, result.ok), ('', false));
    expect(logins, 1);
    expect(http.to(watchLaterPath), isEmpty);
  });

  test('稍后再看 that Bilibili answers with -101 asks for the login instead of toasting', () async {
    final session = makeSession();
    await controller.openVideo(bv, cid: p1);
    http.routes[watchLaterPath] = (200, '{"code":-101,"message":"账号未登录"}');
    final result = await session.watchLater();
    expect((result.message, result.ok), ('', false));
    expect(logins, 1);
    expect(http.to(watchLaterPath), hasLength(1));
  });

  test('the screenshot toasts 已保存到相册, or 保存失败 when the player cannot', () async {
    final session = makeSession();
    expect(session.canCaptureFrame, isTrue);
    expect((await session.captureFrame()).message, '已保存到相册');
    session.dispose();
    sessions.remove(session);

    player = FakePlayer(capabilities: PlayerCapabilities.none);
    final without = makeSession();
    expect(without.canCaptureFrame, isFalse);
    expect(without.pictureInPictureSupported, isFalse);
    expect((await without.captureFrame()).message, '保存失败');
  });

  group('seeks', () {
    test('a committed seek holds scrubbing at the target until it lands', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      session.scrub(90);
      expect(session.position, 90);
      session.hint(95);
      expect(engine.hints.last.seconds, 95);
      final commit = session.commitSeek(100);
      expect(session.scrubbing.value, 100, reason: 'held while the seek runs');
      expect(player.calls, contains('seek 100.0'));
      await commit;
      expect(session.scrubbing.value, isNull);
      expect(controller.clock.seconds, closeTo(100, 0.01));
    });

    test('a drag begun before the seek landed keeps its own target', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      final commit = session.commitSeek(100);
      session.scrub(200);
      await commit;
      expect(session.scrubbing.value, 200);
    });

    test('a drag that ends without a seek takes its hint back', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      session.scrub(50);
      session.hint(50);
      session.cancelScrub();
      expect(session.scrubbing.value, isNull);
      expect(engine.hints.last.seconds, isNull);
    });

    test('nothing seeks before the duration is known', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      session.scrub(10);
      await session.commitSeek(10);
      expect(session.scrubbing.value, isNull);
      expect(player.calls.where((c) => c.startsWith('seek')), isEmpty);
    });

    test('a drag whose duration went away lets go of the bar and takes its hint back', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      session.scrub(50);
      session.hint(50);
      controller.duration.value = 0;
      await session.commitSeek(60);
      expect(session.scrubbing.value, isNull);
      expect(engine.hints.last.seconds, isNull);
      expect(player.calls.where((c) => c.startsWith('seek')), isEmpty);
    });

    test('a seek the player refuses is logged and lets go of the bar', () async {
      final session = makeSession();
      await controller.openVideo(bv, cid: p1);
      playing();
      refused.add('seek');
      session.scrub(90);
      await session.commitSeek(100);
      expect(session.scrubbing.value, isNull);
      expect(logs.events.map((event) => event.msg), contains('seek failed'));
    });
  });

  test('settings that Swift kept are saved and applied to the next page', () async {
    final session = makeSession();
    session
      ..setLoop(LoopMode.list)
      ..setAutoplayNext(false)
      ..setShowStats(true)
      ..setDanmakuOn(false);
    await session.setBtr(false);
    await session.setQuality(80);
    await session.setCodec(VideoCodec.avc);
    expect(prefs.toJson(), {
      'autoplay': false,
      'loop': 'list',
      'fit': 'fit',
      'btr': false,
      'node': 'auto',
      'showStats': true,
      'danmakuOn': false,
      'coinAlsoLike': true,
      'quality': 80,
      'codec': 'avc',
    });

    final fresh = PlaybackController(
      client: BiliClient(transport: http, cookies: CookieJar(Canned.cookies)),
      engine: FakeEngine(),
      player: FakePlayer(),
    );
    final next = PagePlayerSession(
      controller: fresh,
      client: BiliClient(transport: http, cookies: CookieJar(Canned.cookies)),
      open: (_, {cid}) {},
      isVip: () => true,
      isLoggedIn: () => true,
      requestLogin: () {},
      prefs: prefs,
    );
    sessions.add(next);
    await settle();
    expect(fresh.mode, PlaybackMode.direct);
    expect(fresh.selectedQuality, 80);
    expect(fresh.codec, VideoCodec.avc);
    expect(next.btr, isFalse);
    expect(next.isVip, isTrue);
    expect(next.loop, LoopMode.list);
    controllers.add(fresh);
  });
}

/// A controller whose switches fail outright.
final class _RefusingController extends PlaybackController {
  _RefusingController({required super.client, required super.engine, required super.player});

  @override
  Future<void> setMode(PlaybackMode mode) => Future.error(StateError('mode refused'));

  @override
  Future<void> setQuality(int quality) => Future.error(StateError('quality refused'));

  @override
  Future<void> setCodec(VideoCodec codec) => Future.error(StateError('codec refused'));
}
