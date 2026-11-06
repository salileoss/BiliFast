import 'dart:async';
import 'dart:convert';

import 'package:bili_core/api.dart' hide VideoPage;
import 'package:bili_core/devlog.dart';
import 'package:bili_core/shared.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/danmaku/danmaku_layer.dart';
import 'package:bilifast/home/feed_big_card.dart';
import 'package:bilifast/home/feed_inline_gestures.dart';
import 'package:bilifast/home/feed_inline_player.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/feed_preferences.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/home_tab_bar.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/player/bili_player.dart';
import 'package:bilifast/player_ui/chrome_state.dart';
import 'package:bilifast/player_ui/player_gestures.dart';
import 'package:bilifast/player_ui/player_loading.dart';
import 'package:bilifast/player_ui/seek_bar.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:bilifast/video/video_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import '../support/fake_player.dart';
import 'fake_login_gate.dart';
import 'feed_fakes.dart';

const _bv = 'BV1GJ411x7h7';
const _heartbeat = '/x/click-interface/web/heartbeat';
const _loggedOutCookies = {'buvid3': 'b3', 'buvid4': 'b4'};

class _FeedSignals extends FeedPreferences {
  _FeedSignals() : super.memory();
  double watched = 0;

  @override
  void recordWatch({required int? accountMid, required String bvid, required int ownerMid,
      required double seconds, bool completed = false}) {
    watched += seconds;
  }
}

void main() {
  late FeedHttp http;
  late AppEnvironment environment;
  late AppServices services;
  late FakePageApi pageApi;
  late FakeLoginGate gate;
  late List<FakePlayer> players;
  late List<PlaybackController> controllers;
  late List<FakeEngine> engines;
  late Map<int, List<FeedCard>> pages;
  late List<int> feedRequests;

  /// While set, a player asked for comes only once it completes; [createError] fails it instead.
  Completer<void>? createGate;
  Object? createError;

  setUp(() {
    http = FeedHttp();
    pageApi = FakePageApi();
    gate = FakeLoginGate();
    players = [];
    controllers = [];
    engines = [];
    pages = {
      1: [bigCard(_bv), ...smalls('a', 12)],
    };
    feedRequests = [];
    createGate = null;
    createError = null;
    FeedInlineChoices.reset();
    HomePage.feedMinimumRefresh = Duration.zero;
    HomePage.precacheCover = (context, url, size) async => true;
    HomePage.precacheBigCover = (context, url, size) async => true;
    HomePage.feedPages = (index) async {
      feedRequests.add(index);
      return pages[index] ?? const [];
    };
    addTearDown(() {
      HomePage.feedMinimumRefresh = FeedModel.minimumRefresh;
      HomePage.precacheCover = (context, url, size) async => false;
      HomePage.precacheBigCover = FeedBigCardView.precacheCover;
      HomePage.feedPages = null;
      FeedInlineChoices.reset();
    });
  });

  Future<void> show(WidgetTester tester, {Map<String, String> cookies = Canned.cookies, bool muted = false,
      FeedPreferences? feedPreferences}) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final logger = Logger(session: 'test');
    environment = await AppEnvironment.load(keychain: FakeKeychain(StoredCookies(cookies)), http: http, logger: logger);
    await environment.refreshAccount();
    final now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 1000) * 1000);
    final playback = AppPlayback(() async {
      await createGate?.future;
      if (createError case final error?) throw error;
      final player = FakePlayer();
      players.add(player);
      final engine = FakeEngine();
      engines.add(engine);
      final controller = PlaybackController(
        client: environment.client,
        engine: engine,
        player: player,
        clock: ManualClock(10000).clock,
        now: () => now,
        startTimer: FakeTimers().start,
        logger: logger,
      );
      controllers.add(controller);
      return controller;
    }, muted: muted);
    final recents = await RecentStore.load(null, logger: logger);
    addTearDown(playback.dispose);
    services = AppServices(
      environment: environment,
      playback: playback,
      recents: recents,
      feedPreferences: feedPreferences,
      loginGate: gate,
      pageApi: pageApi,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppScope(services: services, child: child!),
        home: const MainShell(),
      ),
    );
  }

  Future<void> frames(WidgetTester tester, [int count = 10]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder card(String bvid) => find.byKey(ValueKey('feed-card-$bvid'));
  Finder inCard(String bvid, Key key) => find.descendant(of: card(bvid), matching: find.byKey(key));
  FakePlayer player([int index = 0]) => players[index];

  /// The big card's newest player is out and its video loaded; [playing] has it report playing.
  Future<void> started(WidgetTester tester, {bool playing = true}) async {
    await frames(tester, 20);
    expect(players, isNotEmpty, reason: 'the big card asked for a player');
    if (playing) {
      players.last.emit(const DurationChanged(600));
      players.last.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 2);
    }
  }

  /// The last play or pause since the last load, or the load's own autoplay.
  bool playingNow(FakePlayer player) {
    final calls = player.calls;
    final load = calls.lastIndexWhere((call) => call.startsWith('load'));
    final since = calls.skip(load + 1).where((call) => call == 'play' || call == 'pause');
    if (since.isEmpty) return player.loaded?.autoplay ?? false;
    return since.last == 'play';
  }

  FeedInlinePlayback inline(WidgetTester tester) =>
      tester.widget<FeedInlineGestures>(find.byType(FeedInlineGestures).first).playback;

  group('focused tile gestures', () {
    for (final direction in [1.0, -1.0]) {
      testWidgets('a ${direction > 0 ? 'right' : 'left'} swipe previews and commits one seek', (tester) async {
        await show(tester);
        await started(tester);
        player().emit(const PositionChanged(seconds: 0, hostMs: 10000, rate: 1));
        player().emit(const PositionChanged(seconds: 60, hostMs: 10000, rate: 1));
        await tester.pump();
        final playback = inline(tester);
        final video = tester.getRect(inCard(_bv, const ValueKey('big-card-open')));
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        final before = scroll.pixels;
        final gesture = await tester.startGesture(video.center);
        await gesture.moveBy(Offset(video.width / 4 * direction, 0));
        await tester.pump();
        final target = 60 + 22.5 * direction;
        expect(playback.session!.scrubbing.value, closeTo(target, 0.001));
        expect(playback.gestureChrome.hud.value, isA<SeekHud>());
        expect(player().calls.where((call) => call.startsWith('seek ')), isEmpty);
        await tester.pump(SeekBar.restDelay);
        expect(engines.first.hints.last.seconds, closeTo(target, 0.001));
        await gesture.up();
        await frames(tester, 8);
        expect(player().calls.where((call) => call.startsWith('seek ')), ['seek $target']);
        expect(playback.gestureChrome.hud.value, isNull);
        expect(scroll.pixels, before);
        expect(find.byType(VideoPage), findsNothing);
        expect(playingNow(player()), isTrue);
      });
    }

    testWidgets('a drag can reverse direction and clamps at both video boundaries', (tester) async {
      await show(tester);
      await started(tester);
      final playback = inline(tester);
      final video = tester.getRect(inCard(_bv, const ValueKey('big-card-open')));
      final duration = playback.session!.duration.value;
      player().emit(const PositionChanged(seconds: 0, hostMs: 10000, rate: 1));
      player().emit(PositionChanged(seconds: duration - 2, hostMs: 10000, rate: 1));
      await tester.pump();
      final gesture = await tester.startGesture(video.center);
      await gesture.moveBy(Offset(video.width, 0));
      await tester.pump();
      expect(playback.session!.scrubbing.value, duration);
      await gesture.moveBy(Offset(-video.width * 20, 0));
      await tester.pump();
      expect(playback.session!.scrubbing.value, 0);
      await gesture.up();
      await frames(tester, 8);
      expect(player().calls, contains('seek 0.0'));
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets('cancelling a held seek clears preloading without seeking', (tester) async {
      await show(tester);
      await started(tester);
      final playback = inline(tester);
      final gesture = await tester.startGesture(tester.getCenter(inCard(_bv, const ValueKey('big-card-open'))));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump(SeekBar.restDelay);
      expect(engines.first.hints.last.seconds, isNotNull);
      await gesture.cancel();
      await frames(tester, 8);
      expect(playback.session!.scrubbing.value, isNull);
      expect(playback.gestureChrome.hud.value, isNull);
      expect(engines.first.hints.last.seconds, isNull);
      expect(player().calls.where((call) => call.startsWith('seek ')), isEmpty);
      expect(find.byType(VideoPage), findsNothing);
    });

    for (final cancel in [false, true]) {
      testWidgets('holding uses 2x and restores the chosen rate on ${cancel ? 'cancel' : 'release'}', (tester) async {
        await show(tester);
        await started(tester);
        final playback = inline(tester);
        await playback.session!.setRate(1.5);
        final gesture = await tester.startGesture(tester.getCenter(inCard(_bv, const ValueKey('big-card-open'))));
        await tester.pump(PlayerGestureLayer.holdDelay + const Duration(milliseconds: 1));
        expect(player().calls.last, 'rate 2.0');
        expect(playback.session!.speedingUp, isTrue);
        expect(playback.gestureChrome.hud.value, isA<SpeedUpHud>());
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await frames(tester, 8);
        expect(player().calls.last, 'rate 1.5');
        expect(playback.session!.speedingUp, isFalse);
        expect(playback.gestureChrome.hud.value, isNull);
        expect(find.byType(VideoPage), findsNothing);
      });
    }

    for (final holding in [false, true]) {
      testWidgets('losing focus cancels ${holding ? 'speed-up' : 'scrubbing'} before the finger lifts', (tester) async {
        await show(tester);
        await started(tester);
        final playback = inline(tester);
        final session = playback.session!;
        final gesture = await tester.startGesture(tester.getCenter(inCard(_bv, const ValueKey('big-card-open'))));
        if (holding) {
          await tester.pump(PlayerGestureLayer.holdDelay + const Duration(milliseconds: 1));
        } else {
          await gesture.moveBy(const Offset(80, 0));
          await tester.pump(SeekBar.restDelay);
          expect(session.scrubbing.value, isNotNull);
        }
        await tester.tap(find.byKey(ValueKey('home-tab-${HomeTab.mine.name}')));
        await frames(tester, 8);
        expect(session.speedingUp, isFalse);
        expect(session.scrubbing.value, isNull);
        expect(playback.gestureChrome.hud.value, isNull);
        expect(playingNow(player()), isFalse);
        await gesture.up();
        await frames(tester, 8);
        expect(player().calls.where((call) => call.startsWith('seek ')), isEmpty);
        expect(find.byType(VideoPage), findsNothing);
      });
    }

    testWidgets('vertical swiping on the playing video scrolls the feed without seeking or opening', (tester) async {
      await show(tester);
      await started(tester);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final before = scroll.pixels;
      final gesture = await tester.startGesture(tester.getCenter(inCard(_bv, const ValueKey('big-card-open'))));
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -180));
      await frames(tester, 4);
      expect(scroll.pixels, greaterThan(before));
      await gesture.up();
      await frames(tester, 8);
      expect(player().calls.where((call) => call.startsWith('seek ')), isEmpty);
      expect(player().calls, isNot(contains('rate 2.0')));
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets('an unfocused tile has no playback gestures', (tester) async {
      await show(tester);
      await started(tester);
      final next = inCard('BV1a0', const ValueKey('big-card-open'));
      expect(find.descendant(of: next, matching: find.byType(FeedInlineGestures)), findsNothing);
      final calls = List.of(player().calls);
      final gesture = await tester.startGesture(tester.getCenter(next));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump(PlayerGestureLayer.holdDelay);
      await gesture.up();
      await frames(tester, 8);
      expect(player().calls, calls);
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets('paused playback rejects seeks and holds; an unknown duration rejects seeking', (tester) async {
      await show(tester);
      await started(tester);
      final playback = inline(tester);
      final center = tester.getCenter(inCard(_bv, const ValueKey('big-card-open')));
      controllers.first.duration.value = 0;
      var gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(80, 0));
      await gesture.up();
      await frames(tester, 8);
      expect(player().calls.where((call) => call.startsWith('seek ')), isEmpty);
      controllers.first.duration.value = 600;
      player().emit(const StatusChanged(PlayerStatus.paused));
      gesture = await tester.startGesture(center);
      await tester.pump(PlayerGestureLayer.holdDelay + const Duration(milliseconds: 1));
      expect(playback.session!.speedingUp, isFalse);
      await gesture.up();
      gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(80, 0));
      await gesture.up();
      await frames(tester, 8);
      expect(player().calls.where((call) => call.startsWith('seek ')), isEmpty);
      expect(player().calls, isNot(contains('rate 2.0')));
    });

    testWidgets('backgrounding cancels a pending seek preload and restores a held speed', (tester) async {
      await show(tester);
      await started(tester);
      final playback = inline(tester);
      final center = tester.getCenter(inCard(_bv, const ValueKey('big-card-open')));
      var gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(80, 0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await frames(tester, 8);
      expect(playback.session!.scrubbing.value, isNull);
      expect(engines.first.hints, isEmpty, reason: 'the 150 ms preload timer was cancelled');
      await gesture.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester, 8);
      gesture = await tester.startGesture(center);
      await tester.pump(PlayerGestureLayer.holdDelay + const Duration(milliseconds: 1));
      expect(playback.session!.speedingUp, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await frames(tester, 8);
      expect(playback.session!.speedingUp, isFalse);
      await gesture.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester, 8);
    });

    testWidgets('a native pause during a hold restores normal speed immediately', (tester) async {
      await show(tester);
      await started(tester);
      final playback = inline(tester);
      final gesture = await tester.startGesture(tester.getCenter(inCard(_bv, const ValueKey('big-card-open'))));
      await tester.pump(PlayerGestureLayer.holdDelay + const Duration(milliseconds: 1));
      expect(playback.session!.speedingUp, isTrue);
      player().emit(const StatusChanged(PlayerStatus.paused));
      expect(playback.session!.speedingUp, isFalse);
      await gesture.up();
      await frames(tester, 8);
    });

    testWidgets('page handoff clears a held gesture before transferring the player', (tester) async {
      await show(tester);
      await started(tester);
      final playback = inline(tester);
      final session = playback.session!;
      final gesture = await tester.startGesture(tester.getCenter(inCard(_bv, const ValueKey('big-card-open'))));
      await tester.pump(PlayerGestureLayer.holdDelay + const Duration(milliseconds: 1));
      await tester.tap(inCard(_bv, const ValueKey('big-card-open-title')));
      await frames(tester, 20);
      expect(session.speedingUp, isFalse);
      expect(find.byType(VideoPage), findsOneWidget);
      expect(players, hasLength(1));
      await gesture.up();
      await frames(tester, 8);
    });
  });

  testWidgets('an ordinary card autoplays and hands playback to its page', (tester) async {
    pages = {1: [smallCard(_bv), ...smalls('next', 5)]};
    await show(tester);
    await started(tester);
    expect(playingNow(player()), isTrue);
    expect(player().muted, isTrue);
    expect(inCard(_bv, const ValueKey('big-card-video')), findsOneWidget);
    final original = player();
    await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
    await frames(tester, 20);
    expect(find.byType(VideoPage), findsOneWidget);
    expect(players, hasLength(1), reason: 'detail page takes over the inline player');
    expect(original.muted, isFalse);
  });

  testWidgets('a feed upload date appears beside the uploader without a metadata request', (tester) async {
    final published = DateTime.now().subtract(const Duration(hours: 10)).millisecondsSinceEpoch ~/ 1000;
    pages = {1: [FeedCard.fromJson({
      ...feedItem(_bv),
      'pubdate': published,
      'owner': {'name': '上传者', 'mid': 7, 'face': 'https://i0.hdslb.com/face.jpg'},
    })]};
    await show(tester);
    await frames(tester, 15);
    expect(find.text('上传者 · 10小时前'), findsOneWidget);
    final byline = tester.getRect(inCard(_bv, const ValueKey('feed-uploader-byline')));
    final avatar = tester.getRect(inCard(_bv, const ValueKey('feed-uploader-avatar')));
    expect(byline.left, avatar.right + FeedBigCardTheme.avatarGap);
    expect(avatar.width, FeedBigCardTheme.avatar);
  });

  testWidgets('official cards missing an upload date resolve it from video details', (tester) async {
    final body = jsonDecode(Canned.view) as Map<String, dynamic>;
    body['data']['pubdate'] = DateTime.now().subtract(const Duration(hours: 16)).millisecondsSinceEpoch ~/ 1000;
    body['data']['owner']['face'] = 'https://i0.hdslb.com/uploader.jpg';
    http.canned.routes[Canned.signedViewPath] = (200, jsonEncode(body));
    pages = {1: [bigCard(_bv)]};
    await show(tester);
    await frames(tester, 20);
    expect(find.text('UP $_bv · 16小时前'), findsOneWidget);
  });

  testWidgets('every phone tile spans the feed width with an uploader row', (
    tester,
  ) async {
    await show(tester);
    await frames(tester);
    final big = tester.getRect(card(_bv));
    expect(big.left, FeedBigCardTheme.spacing);
    expect(big.right, 440 - FeedBigCardTheme.spacing);
    final video = tester.getRect(inCard(_bv, const ValueKey('big-card-open')));
    expect(video.height, closeTo(video.width * 9 / 16, 0.01));
    final first = tester.getRect(card('BV1a0'));
    final second = tester.getRect(card('BV1a1'));
    expect(first.top, closeTo(big.bottom + FeedBigCardTheme.topGap * 2 + 0.5, 0.01));
    expect(second.top, greaterThan(first.bottom), reason: 'single column');
    expect(second.width, first.width);
    expect(first.left, FeedBigCardTheme.spacing);
    expect(find.text('大卡片 $_bv'), findsOneWidget);
    expect(find.text('2.7万'), findsOneWidget, reason: "👍's count");
    expect(find.text('UP $_bv'), findsOneWidget, reason: 'uploader below the title');
    await frames(tester, 20);
  });

  testWidgets('a refresh puts its batch, big card first, above 刚刚看到这里; the old big card fades out over the new', (
    tester,
  ) async {
    final bigCovers = <String, Size>{};
    HomePage.precacheBigCover = (context, url, size) async {
      bigCovers[url!] = size;
      return true;
    };
    await show(tester);
    await frames(tester);
    pages[1] = [bigCard('BV1new'), ...smalls('n', 4)];
    await tester.tap(find.byKey(ValueKey('home-tab-${HomeTab.home.name}')));
    var faded = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byKey(const ValueKey('feed-card-going-$_bv')).evaluate().isNotEmpty) faded = true;
    }
    expect(faded, isTrue, reason: "the hand-off draws the old big card in the new one's slot");
    expect(
      bigCovers['https://i0.hdslb.com/bfs/archive/BV1new.jpg'],
      const Size(408, 408 * 9 / 16),
      reason: "the new big card's cover asked for at its video's size",
    );
    final fresh = tester.getRect(card('BV1new'));
    expect(fresh.left, FeedBigCardTheme.spacing);
    expect(fresh.width, 440 - FeedBigCardTheme.spacing * 2);
    expect(tester.getRect(card('BV1n0')).top, closeTo(fresh.bottom + FeedBigCardTheme.topGap * 2 + 0.5, 0.01));
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('feed-divider')), 200);
    await frames(tester, 10);
    final divider = tester.getRect(find.byKey(const ValueKey('feed-divider'))).bottom + position.pixels;
    await tester.scrollUntilVisible(card(_bv), 200);
    await frames(tester, 10);
    expect(
      tester.getRect(card(_bv)).top + position.pixels,
      moreOrLessEquals(divider),
      reason: 'the old batch, its big card first, right under the divider',
    );
    await frames(tester, 20);
  });

  testWidgets('it plays muted at once with the TV only while loading, then the video, danmaku, 弹 and the speaker', (
    tester,
  ) async {
    await show(tester);
    await started(tester, playing: false);
    expect(player().muted, isTrue);
    expect(player().calls, contains('pip auto false'));
    expect(find.byType(PlayerLoading), findsOneWidget, reason: 'loading');
    expect(inCard(_bv, const ValueKey('big-card-play')), findsNothing);

    player().emit(const StatusChanged(PlayerStatus.playing));
    await frames(tester, 2);
    expect(find.byType(PlayerLoading), findsNothing);
    expect(inCard(_bv, const ValueKey('big-card-video')), findsOneWidget);
    expect(inCard(_bv, const ValueKey('big-card-danmaku-toggle')), findsOneWidget);
    expect(inCard(_bv, const ValueKey('big-card-sound')), findsOneWidget);
    expect(inCard(_bv, const ValueKey('big-card-duration')), findsNothing, reason: 'no duration while it plays');
    expect(tester.widget<DanmakuLayer>(find.byType(DanmakuLayer)).enabled, isTrue);

    player().emit(const StatusChanged(PlayerStatus.buffering));
    await tester.pump(PlayerLoadingTheme.grace);
    await tester.pump();
    expect(find.byType(PlayerLoading), findsOneWidget, reason: 'a wait past the grace');
    player().emit(const StatusChanged(PlayerStatus.playing));
    await frames(tester, 2);
    expect(find.byType(PlayerLoading), findsNothing);
    expect(http.canned.requests.where((request) => request.url.path == _heartbeat), isEmpty);
  });

  testWidgets('the speaker and 弹 toggle for the run: sound on, danmaku off, both kept by the next card', (
    tester,
  ) async {
    await show(tester);
    await started(tester);
    await tester.tap(inCard(_bv, const ValueKey('big-card-sound')));
    await frames(tester, 2);
    expect(player().muted, isFalse);
    expect(FeedInlineChoices.sound.value, isTrue);
    await tester.tap(inCard(_bv, const ValueKey('big-card-danmaku-toggle')));
    await frames(tester, 2);
    expect(tester.widget<DanmakuLayer>(find.byType(DanmakuLayer)).enabled, isFalse);
    expect(pageApi.calls, isEmpty, reason: 'neither opened anything');
    expect(find.byType(VideoPage), findsNothing);

    await tester.tap(inCard(_bv, const ValueKey('big-card-sound')));
    await frames(tester, 2);
    expect(player().muted, isTrue);
  });

  testWidgets('under --mute the speaker turns but the player stays silent', (tester) async {
    await show(tester, muted: true);
    await started(tester);
    await tester.tap(inCard(_bv, const ValueKey('big-card-sound')));
    await frames(tester, 2);
    expect(FeedInlineChoices.sound.value, isTrue);
    expect(player().muted, isTrue);
  });

  testWidgets('dragging a video mostly off screen pauses before release; scrolling back resumes its progress', (
    tester,
  ) async {
    await show(tester);
    await started(tester);
    player().emit(const PositionChanged(seconds: 0, hostMs: 10000, rate: 1));
    player().emit(const PositionChanged(seconds: 37, hostMs: 10000, rate: 1));
    final video = tester.getRect(inCard(_bv, const ValueKey('big-card-open')));
    final gesture = await tester.startGesture(const Offset(220, 700));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(Offset(0, -(video.height * 0.7 + 60)));
    await frames(tester, 6);
    expect(playingNow(player()), isFalse, reason: 'mostly off screen, even with the finger held down');
    await frames(tester, 20);
    expect(players, hasLength(1), reason: 'passing tiles do not allocate players while the finger is down');
    await gesture.up();
    await frames(tester, 30);
    expect(playingNow(player()), isFalse);
    expect(inCard(_bv, const ValueKey('big-card-play')), findsOneWidget);
    final paused = player().calls.length;
    final asks = feedRequests.length;

    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    await tester.drag(find.byKey(const ValueKey('feed')), Offset(0, position.pixels));
    position.jumpTo(0);
    await frames(tester, 30);
    expect(playingNow(player()), isTrue);
    expect(feedRequests, hasLength(asks), reason: 'returning to the tile does not pull a refresh');
    expect(players, hasLength(2), reason: 'the next tile autoplayed; the first resumes its player');
    expect(player().calls.skip(paused).where((call) => call.startsWith('load')), isEmpty);
    expect(controllers.first.currentSeconds, 37);
  });

  testWidgets('a fling starts no passing players and waits briefly after ballistic scrolling ends', (tester) async {
    pages = {1: [bigCard(_bv), ...smalls('a', 50)]};
    await show(tester);
    await started(tester);
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    await tester.fling(find.byKey(const ValueKey('feed')), const Offset(0, -700), 3000);
    expect(position.isScrollingNotifier.value, isTrue);
    var framesLeft = 600;
    while (position.isScrollingNotifier.value && framesLeft-- > 0) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(players, hasLength(1), reason: 'no video loads while coasting, even after 300 ms');
    }
    expect(framesLeft, greaterThan(0));
    expect(playingNow(player()), isFalse);
    await tester.pump(const Duration(milliseconds: 250));
    expect(players, hasLength(1), reason: 'a short pause does not start playback');
    await frames(tester, 20);
    expect(players, hasLength(2), reason: 'only the final focused tile starts');
    expect(playingNow(players.last), isTrue);
  });

  testWidgets('a focused video pauses at one third visible and resumes when half visible again', (tester) async {
    await show(tester);
    await started(tester);
    final video = tester.getRect(inCard(_bv, const ValueKey('big-card-open')));
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final half = FeedBigCardTheme.topGap + video.height / 2;
    tester.view.physicalSize = Size(440, video.height + 142);
    await frames(tester, 2);
    position.jumpTo(half - 0.5);
    await frames(tester, 10);
    expect(playingNow(player()), isTrue);
    position.jumpTo(half + 1);
    await frames(tester, 10);
    expect(playingNow(player()), isTrue, reason: 'the focused video can remain below half visible');
    position.jumpTo(FeedBigCardTheme.topGap + video.height * 2 / 3 + 1);
    await frames(tester, 10);
    expect(playingNow(player()), isFalse);
    position.jumpTo(half + 1);
    await frames(tester, 10);
    expect(playingNow(player()), isFalse, reason: 'a paused video needs half visible to regain focus');
    position.jumpTo(half - 0.5);
    await frames(tester, 10);
    expect(playingNow(player()), isTrue);
  });

  testWidgets('one big card plays at a time: the most visible', (tester) async {
    pages = {
      1: [bigCard(_bv), bigCard('BV1two'), ...smalls('a', 8)],
    };
    await show(tester);
    await started(tester);
    expect(players, hasLength(1), reason: 'only the first, wholly on screen, asked for a player');
    final second = tester.getRect(card('BV1two'));
    expect(second.top, lessThan(956), reason: 'the second is partly on screen too');
    await tester.drag(find.byKey(const ValueKey('feed')), Offset(0, -(second.top - 160)));
    await frames(tester, 30);
    expect(players, hasLength(2));
    expect(playingNow(player(0)), isFalse);
    expect(playingNow(player(1)), isTrue);
  });

  testWidgets('a page over 首页, 我的 and ⋮\'s sheet pause it; back on 首页 it plays on', (tester) async {
    await show(tester);
    await started(tester);

    await tester.tap(card('BV1a0'));
    await frames(tester, 30);
    expect(find.byType(VideoPage), findsOneWidget);
    expect(playingNow(player()), isFalse, reason: 'a page over it');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.pop();
    await frames(tester, 30);
    expect(playingNow(player()), isTrue);

    await tester.tap(find.byKey(ValueKey('home-tab-${HomeTab.mine.name}')));
    await frames(tester, 10);
    expect(playingNow(player()), isFalse, reason: '我的 shown');
    await tester.tap(find.byKey(ValueKey('home-tab-${HomeTab.home.name}')));
    await frames(tester, 10);
    expect(playingNow(player()), isTrue);

    await tester.tap(inCard(_bv, const ValueKey('big-card-more')));
    await frames(tester, 10);
    expect(find.text('添加至稍后再看'), findsOneWidget);
    expect(playingNow(player()), isFalse, reason: 'a sheet over it');
    navigator.pop();
    await frames(tester, 20);
    expect(playingNow(player()), isTrue);
  });

  testWidgets('the app in the background pauses it; back in front it plays on', (tester) async {
    await show(tester);
    await started(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await frames(tester, 2);
    expect(playingNow(player()), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, 2);
    expect(playingNow(player()), isTrue);
  });

  testWidgets('paused off screen a while, its player is let go; back, it starts again where it stood', (tester) async {
    await show(tester);
    await started(tester);
    player().emit(const PositionChanged(seconds: 0, hostMs: 10000, rate: 1));
    player().emit(const PositionChanged(seconds: 37, hostMs: 10000, rate: 1));
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -500));
    await frames(tester, 30);
    expect(services.playback.live, 2);
    await tester.pump(FeedBigCardTheme.releaseAfter);
    await frames(tester, 2);
    expect(services.playback.live, 1, reason: 'offscreen player released, focused tile still playing');
    final asks = feedRequests.length;
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    await tester.drag(find.byKey(const ValueKey('feed')), Offset(0, position.pixels));
    position.jumpTo(0);
    await frames(tester, 30);
    expect(services.playback.live, 2);
    expect(players, hasLength(3));
    expect(player(2).loaded?.startSeconds, 37, reason: 'release preserves progress until the feed is refreshed');
    expect(feedRequests, hasLength(asks), reason: 'returning to the tile does not pull a refresh');
  });

  testWidgets('scrolling far enough to dispose a tile preserves its progress when rebuilt', (tester) async {
    await show(tester);
    await started(tester);
    final view = tester.widget<FeedBigCardView>(find.descendant(of: card(_bv), matching: find.byType(FeedBigCardView)));
    final host = view.host!;
    player().emit(const PositionChanged(seconds: 0, hostMs: 10000, rate: 1));
    player().emit(const PositionChanged(seconds: 37, hostMs: 10000, rate: 1));
    expect(controllers.first.currentSeconds, 37);
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    position.jumpTo(2000);
    await frames(tester, 30);
    expect(card(_bv), findsNothing);
    expect(player().disposed, isTrue);
    expect(host.positions[_bv], 37);
    position.jumpTo(0);
    await frames(tester, 30);
    expect(card(_bv), findsOneWidget);
    final resumed = players.last;
    expect(resumed.disposed, isFalse);
    expect(resumed.loaded?.startSeconds, 37);
    expect(playingNow(resumed), isTrue);
  });

  testWidgets('played to its end it starts over, the counts gone and the buttons dimmed', (tester) async {
    await show(tester);
    await started(tester);
    double opacity(Finder of) =>
        tester.widget<AnimatedOpacity>(find.descendant(of: of, matching: find.byType(AnimatedOpacity))).opacity;
    expect(opacity(inCard(_bv, const ValueKey('big-card-stats'))), 1);
    expect(opacity(inCard(_bv, const ValueKey('big-card-sound'))), 1);
    player().emit(const StatusChanged(PlayerStatus.ended));
    await frames(tester, 2);
    expect(player().calls, contains('seek 0.0 precise'));
    expect(player().calls.last, 'play');
    expect(opacity(inCard(_bv, const ValueKey('big-card-stats'))), 0);
    expect(opacity(inCard(_bv, const ValueKey('big-card-sound'))), FeedBigCardTheme.dimmed);
    expect(opacity(inCard(_bv, const ValueKey('big-card-danmaku-toggle'))), FeedBigCardTheme.dimmed);
  });

  testWidgets(
    'a tap on the playing video opens its page on the same playback, with sound; back, it plays again muted',
    (tester) async {
      await show(tester);
      await started(tester);
      await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
      await frames(tester, 30);
      final page = tester.widget<VideoPage>(find.byType(VideoPage));
      expect(page.route.playback, isNotNull);
      expect(page.route.playback!.controller, same(controllers.single));
      expect(page.route.playback!.inline, isFalse, reason: 'the page took it over');
      expect(players, hasLength(1), reason: 'no second player');
      expect(player().muted, isFalse, reason: 'with sound');
      expect(player().calls.where((call) => call.startsWith('load')), hasLength(1), reason: 'not loaded again');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('feed-card-$_bv'), skipOffstage: false),
          matching: find.byKey(const ValueKey('big-card-play'), skipOffstage: false),
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: 'the card under the page is back to its cover',
      );

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await frames(tester, 30);
      expect(find.byType(VideoPage), findsNothing);
      expect(players, hasLength(2), reason: 'the page closed the first; the card starts a player of its own again');
      expect(services.playback.live, 1);
      expect(player(1).muted, isTrue);
      expect(
        http.canned.requests.where((request) => request.url.path == _heartbeat),
        isNotEmpty,
        reason: "the page's reports, from the take-over on",
      );
    },
  );

  testWidgets('a tap on the title opens the page the same way', (tester) async {
    await show(tester);
    await started(tester);
    await tester.tap(inCard(_bv, const ValueKey('big-card-title')));
    await frames(tester, 30);
    expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.playback?.controller, same(controllers.single));
  });

  testWidgets('👍 shows at once, and is put back with a toast when Bilibili refuses', (tester) async {
    await show(tester);
    await frames(tester);
    pageApi.holds['like'] = Completer<void>();
    await tester.tap(inCard(_bv, const ValueKey('big-card-like')));
    await tester.pump();
    expect(find.text('2.8万'), findsOneWidget);
    expect(inCard(_bv, const ValueKey('big-card-liked')), findsOneWidget);
    expect(pageApi.calls, ['like on=true']);
    pageApi.holds.remove('like')!.complete();
    await frames(tester, 30);
    expect(find.text('2.8万'), findsOneWidget, reason: 'kept');

    pageApi.failures['like'] = const BiliAPIError(code: 65004, message: '取消点赞失败');
    pageApi.holds['like'] = Completer<void>();
    await tester.tap(inCard(_bv, const ValueKey('big-card-like')));
    await tester.pump();
    expect(find.text('2.7万'), findsOneWidget, reason: 'unliked at once');
    expect(inCard(_bv, const ValueKey('big-card-unliked')), findsOneWidget);
    pageApi.holds.remove('like')!.complete();
    await frames(tester, 4);
    expect(pageApi.calls, ['like on=true', 'like on=false']);
    expect(find.text('2.8万'), findsOneWidget, reason: 'put back');
    expect(inCard(_bv, const ValueKey('big-card-liked')), findsOneWidget);
    expect(find.text('取消点赞失败'), findsOneWidget, reason: "Bilibili's words in a toast");
    await frames(tester, 60);
  });

  testWidgets('logged out, 👍 asks for the login and sends nothing', (tester) async {
    http = FeedHttp(loggedIn: false);
    await show(tester, cookies: _loggedOutCookies);
    await frames(tester);
    await tester.tap(inCard(_bv, const ValueKey('big-card-like')));
    await frames(tester, 2);
    expect(gate.requests, 1);
    expect(pageApi.calls, isEmpty);
    expect(find.text('2.7万'), findsOneWidget);
  });

  testWidgets("the big card's ⋮ offers 稍后再看, as a small card's does", (tester) async {
    http.canned.routes['/x/v2/history/toview/add'] = (200, '{"code":0,"message":"0"}');
    await show(tester);
    await frames(tester);
    await tester.tap(inCard(_bv, const ValueKey('big-card-more')));
    await frames(tester, 10);
    await tester.tap(find.text('添加至稍后再看'));
    await frames(tester, 10);
    expect(http.canned.requests.where((request) => request.url.path == '/x/v2/history/toview/add'), hasLength(1));
    expect(find.text('已添加至稍后再看'), findsOneWidget);
    await frames(tester, 60);
  });

  group('review fixes', () {
    testWidgets('returning before a pending inline player starts restores local viewing signals', (tester) async {
      createGate = Completer<void>();
      final signals = _FeedSignals();
      await show(tester, feedPreferences: signals);
      await frames(tester, 10);
      final pending = FeedInlinePlayback(
        services: services,
        video: const InlineVideo(bvid: _bv, duration: 600),
        startAt: () => 0,
        released: (_) {},
      );
      pending
        ..play()
        ..pause()
        ..play();
      createGate!.complete();
      await frames(tester, 20);
      final native = players.last;
      native.emit(const StatusChanged(PlayerStatus.playing));
      for (var second = 0; second <= 35; second++) {
        native.emit(PositionChanged(seconds: second.toDouble(), hostMs: 10000 + second * 1000.0, rate: 1));
      }
      pending.pause();
      expect(signals.watched, 35);
      pending.dispose();
      await frames(tester, 2);
    });

    NavigatorState navigator(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);
    FeedInlineHost host(WidgetTester tester) =>
        tester.widget<FeedBigCardView>(find.byType(FeedBigCardView, skipOffstage: false).first).host!;

    testWidgets('nothing plays inline while a page keeps its video in the small window; ✕ and it plays', (
      tester,
    ) async {
      await show(tester);
      await started(tester);
      await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
      await frames(tester, 30);
      player().emit(const PictureInPictureChanged(true));
      await frames(tester, 2);
      navigator(tester).pop();
      await frames(tester, 30);
      expect(services.pipKeeper.kept, isNotNull);
      expect(players, hasLength(1), reason: 'no second player while the small window plays the video');
      expect(services.pipKeeper.showing, isTrue);

      services.pipKeeper.release();
      await frames(tester, 30);
      expect(players, hasLength(2), reason: 'the window closed: the card plays again');
    });

    testWidgets('a page taking the playing card over turns auto picture in picture on at once', (tester) async {
      await show(tester);
      await started(tester);
      expect(player().calls, isNot(contains('pip auto true')));
      await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
      await frames(tester, 30);
      expect(player().calls, contains('pip auto true'));
    });

    testWidgets('after a lap, the page that takes it over still reports', (tester) async {
      await show(tester);
      await started(tester);
      player().emit(const StatusChanged(PlayerStatus.ended));
      await frames(tester, 2);
      player().emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 2);
      await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
      await frames(tester, 30);
      final before = http.canned.requests.where((request) => request.url.path == _heartbeat).length;
      player().emit(const StatusChanged(PlayerStatus.paused));
      await frames(tester, 4);
      expect(http.canned.requests.where((request) => request.url.path == _heartbeat).length, before + 1);
    });

    testWidgets('a card the account liked shows it, and a tap unlikes, put back if refused', (tester) async {
      pages = {
        1: [bigCard(_bv, likes: 28000, liked: true), ...smalls('a', 4)],
      };
      await show(tester);
      await frames(tester);
      expect(inCard(_bv, const ValueKey('big-card-liked')), findsOneWidget);
      pageApi
        ..failures['like'] = const BiliAPIError(code: 65004, message: '取消点赞失败')
        ..holds['like'] = Completer<void>();
      await tester.tap(inCard(_bv, const ValueKey('big-card-like')));
      await tester.pump();
      expect(pageApi.calls, ['like on=false']);
      expect(find.text('2.7万'), findsOneWidget, reason: 'unliked at once');
      pageApi.holds.remove('like')!.complete();
      await frames(tester, 4);
      expect(find.text('2.8万'), findsOneWidget);
      expect(inCard(_bv, const ValueKey('big-card-liked')), findsOneWidget);
      await frames(tester, 60);
    });

    testWidgets("back from the page, the resume point is kept only while the page still showed the card's part", (
      tester,
    ) async {
      await show(tester);
      await started(tester);
      await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
      await frames(tester, 30);
      navigator(tester).pop();
      await frames(tester, 30);
      expect(host(tester).positions, contains(_bv));

      host(tester).positions.clear();
      await started(tester);
      await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
      await frames(tester, 30);
      final page = tester.widget<VideoPage>(find.byType(VideoPage));
      page.route.playback!.openOnPage(_bv, cid: 137649200);
      await frames(tester, 20);
      navigator(tester).pop();
      await frames(tester, 30);
      expect(host(tester).positions, isNot(contains(_bv)), reason: '选集 moved the page to the second part');
    });

    testWidgets('a tap before the inline player is in opens the page alone: the inline load is let go', (tester) async {
      createGate = Completer<void>();
      await show(tester);
      await frames(tester, 10);
      await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
      await frames(tester, 10);
      expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.playback, isNull);
      createGate!.complete();
      await frames(tester, 30);
      expect(services.playback.live, 1, reason: "the page's player only");
    });

    testWidgets("a player that can't start leaves the cover and its ▶, and a tap opens the page", (tester) async {
      createError = StateError('no player');
      await show(tester);
      await frames(tester, 20);
      expect(inCard(_bv, const ValueKey('big-card-play')), findsOneWidget);
      expect(find.byType(PlayerLoading), findsNothing);
      createError = null;
      await tester.tap(inCard(_bv, const ValueKey('big-card-open')));
      await frames(tester, 30);
      expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.playback, isNull);
    });
  });
}
