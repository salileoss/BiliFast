import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bili_core/devlog.dart';
import 'package:bili_core/shared.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/app/zoom_back_route.dart';
import 'package:bilifast/history/watch_history_page.dart';
import 'package:bilifast/home/avatar_page.dart';
import 'package:bilifast/home/feed_big_card.dart';
import 'package:bilifast/player/bili_player.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/feed_more_sheet.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/search/search_api.dart';
import 'package:bilifast/search/search_page.dart';
import 'package:bilifast/shared/cover_placeholder.dart';
import 'package:bilifast/shared/image_disk_cache.dart';
import 'package:bilifast/shared/loading_tv.dart';
import 'package:bilifast/shared/release_refresh.dart';
import 'package:bilifast/shared/remote_image.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/skin/skin_loading_view.dart';
import 'package:bilifast/skin/skin_model.dart';
import 'package:bilifast/video/intro/title_block.dart';
import 'package:bilifast/video/video_page.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import '../skin/skin_loading_fixtures.dart';
import '../support/fake_player.dart';
import '../video/mixed_lines.dart';
import 'fake_login_gate.dart';
import 'feed_fakes.dart';

const _watchLaterPath = '/x/v2/history/toview/add';

/// A store that keeps the system font on, where the default one would turn this platform's MiSans back on.
FontStore _systemFont() => FontStore.memory()..select(FontChoice.system);

/// The fingerprint cookies alone: logged out, with no `spi` call.
const _loggedOutCookies = {'buvid3': 'b3', 'buvid4': 'b4'};

/// The search entry's default word.
const _word = '崩铁新版本即将上线';

/// Stands in for the network's covers, as [HomePage.precacheCover]: ready at once, or while [holding] only once
/// [ready] says so.
class _Covers {
  bool holding = false;

  /// Each cover asked for, by its card's bvid, in order, and the cover box it was asked for.
  final asked = <String>{};
  final sizes = <String, Size>{};
  final _waiting = <String, Completer<bool>>{};

  static String bvidOf(String url) => url.substring(url.lastIndexOf('/') + 1, url.lastIndexOf('.'));

  Future<bool> precache(BuildContext context, String? url, Size size) {
    final bvid = bvidOf(url!);
    asked.add(bvid);
    sizes[bvid] = size;
    if (!holding) return Future.value(true);
    return (_waiting[bvid] ??= Completer<bool>()).future;
  }

  /// Every cover held so far ready, or only [bvids]'.
  void ready([Iterable<String>? bvids]) {
    for (final MapEntry(key: bvid, value: waiting) in _waiting.entries) {
      if ((bvids == null || bvids.contains(bvid)) && !waiting.isCompleted) waiting.complete(true);
    }
  }
}

/// A grey picture, as a cover's download.
Future<Uint8List> _coverPng() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 3), Paint()..color = const Color(0xFF808080));
  final image = await recorder.endRecording().toImage(4, 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

class _FailingSearchApi extends FakeSearchApi {
  @override
  Future<String?> defaultWord() async {
    calls.add('defaultWord');
    throw Exception('offline');
  }
}

void main() {
  late FeedHttp http;
  final players = <FakePlayer>[];
  late FakePlayer player;
  late PlaybackController controller;
  late RecentStore recents;
  late AppEnvironment environment;
  late FakeLoginGate gate;

  setUp(() {
    players.clear();
    http = FeedHttp();
    http.pages[1] = [feedItem('BV1aaa', reason: '1万点赞'), feedItem('BV1bbb')];
    player = FakePlayer();
    gate = FakeLoginGate();
    // These tests follow the swap from the answer, as when it comes after the minimum; 'the minimum refresh' turns it
    // back on.
    HomePage.feedMinimumRefresh = Duration.zero;
    addTearDown(() => HomePage.feedMinimumRefresh = FeedModel.minimumRefresh);
  });

  List<Map<String, Object?>> twenty() => [for (var i = 0; i < 20; i++) feedItem('BV1c$i')];

  Future<void> show(
    WidgetTester tester, {
    bool developer = false,
    double scale = 1,
    bool still = false,
    Map<String, String> cookies = Canned.cookies,
    ThemeData? theme,
    FontStore? fonts,
    SearchApi? search,
    String? initialLink,
    SkinModel Function(AppEnvironment environment)? skin,
    bool checkAccount = true,
  }) async {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (scale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    if (still) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    final logger = Logger(session: 'test');
    environment = await AppEnvironment.load(keychain: FakeKeychain(StoredCookies(cookies)), http: http, logger: logger);
    if (checkAccount) await environment.refreshAccount();
    final now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 1000) * 1000);
    // Each video page gets a controller and player of its own; [controller] is the newest.
    final playback = AppPlayback(() async {
      player = FakePlayer();
      players.add(player);
      return controller = PlaybackController(
        client: environment.client,
        engine: FakeEngine(),
        player: player,
        clock: ManualClock(10000).clock,
        now: () => now,
        startTimer: FakeTimers().start,
        logger: logger,
      );
    });
    recents = await RecentStore.load(null, logger: logger);
    addTearDown(playback.dispose);
    final services = AppServices(
      environment: environment,
      playback: playback,
      recents: recents,
      loginGate: gate,
      fonts: fonts,
      searchApi: search ?? FakeSearchApi(defaultWord: _word),
      skin: skin?.call(environment),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => AppScope(services: services, child: child!),
        home: MainShell(developerPage: developer ? (context) => const Text('开发者页面') : null, initialLink: initialLink),
      ),
    );
  }

  /// Lets requests answer and frames run without waiting on the loading cards' endless sweep.
  Future<void> settle(WidgetTester tester, [int frames = 10]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      for (final active in players) {
        if (!active.disposed && active.loaded != null) active.emit(const StatusChanged(PlayerStatus.playing));
      }
    }
  }

  /// Lets a toast run out, so its timer is not left pending.
  Future<void> toastGone(WidgetTester tester) => settle(tester, 60);

  Finder card(String bvid) => find.byKey(ValueKey('feed-card-$bvid'));

  /// The card's cover picture, only while drawn: not left Offstage in the Hero's placeholder from the push's flight.
  Finder cover(String bvid) => find.descendant(
    of: find.descendant(of: card(bvid), matching: find.byType(Hero)),
    matching: find.byType(RemoteImage),
  );

  Finder entrance(String bvid) => find.descendant(of: card(bvid), matching: find.byType(SlideTransition));

  testWidgets('loading cards sweep until the feed answers, then one column of video tiles', (tester) async {
    http.gates[1] = Completer<void>();
    await show(tester);
    await settle(tester, 2);
    expect(find.text('推荐'), findsOneWidget);
    expect(card('BV1aaa'), findsNothing);
    http.gates[1]!.complete();
    await settle(tester);
    expect(find.text('视频 BV1aaa'), findsOneWidget);
    expect(find.text('UP BV1aaa'), findsOneWidget, reason: 'the uploader row');
    expect(find.text('UP BV1bbb'), findsOneWidget);
    expect(find.text('1.2万'), findsNWidgets(2));
    expect(find.text('2:05'), findsOneWidget, reason: 'duration is hidden on the focused tile');
    final first = tester.getTopLeft(card('BV1aaa'));
    final second = tester.getTopLeft(card('BV1bbb'));
    expect(second.dy, greaterThan(first.dy), reason: 'single column');
    expect(http.asked.first, 1);
  });

  testWidgets('resolving an account without an initial uid restarts its in-flight feed', (tester) async {
    http.gates[1] = Completer<void>();
    await show(tester, checkAccount: false);
    await settle(tester, 2);
    expect(environment.account, isA<AccountUnknown>());
    expect(http.asked, [1]);
    await environment.refreshAccount();
    await settle(tester, 2);
    expect(environment.account, isA<LoggedIn>());
    expect(http.asked, [1, 1], reason: 'the first request had no resolved account owner');
    http.gates[1]!.complete();
    await settle(tester);
    expect(card('BV1aaa'), findsOneWidget);
    expect(card('BV1bbb'), findsOneWidget);
    expect(find.byKey(const ValueKey('feed-error')), findsNothing);
  });

  testWidgets('a phone tile reused across owners waits for that owners accepted response', (tester) async {
    await show(tester);
    await settle(tester, 30);
    final services = AppScope.of(tester.element(find.byType(HomePage)));
    expect(services.feedPreferences.recentlySeen('BV1aaa', accountMid: services.feedAccountMid), isTrue);
    http.gates[1] = Completer<void>();
    environment.cookies.remove('SESSDATA');
    http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
    await environment.refreshAccount();
    await settle(tester, 40);
    expect(services.feedAccountMid, isNull);
    expect(services.feedPreferences.recentlySeen('BV1aaa', accountMid: null), isFalse);
    http.gates[1]!.complete();
    await settle(tester, 40);
    expect(services.feedPreferences.recentlySeen('BV1aaa', accountMid: null), isTrue,
        reason: 'a reused video gets exposure for its new owner once that response is accepted');
  });

  group('under the system font a line mixing Latin and Chinese sits on the Chinese line', () {
    testWidgets('a card\'s title over both lines, its uploader and its reason', (tester) async {
      await useSystemFont(tester);
      http.pages[1] = [feedItem('BV1aaa', title: mixedLines, reason: '1万点赞'), feedItem('BV1bbb')];
      await show(tester, theme: appTheme(), fonts: _systemFont());
      await settle(tester);
      expectOnChineseLine(tester, find.text('$mixedLines BV1aaa'));
      expectOnChineseLine(tester, find.text('UP BV1bbb'));
      expectOnChineseLine(tester, find.text('UP BV1aaa'));
    });

    testWidgets("the search entry's default word", (tester) async {
      await useSystemFont(tester);
      await show(
        tester,
        theme: appTheme(),
        fonts: _systemFont(),
        search: FakeSearchApi(defaultWord: mixedLine),
      );
      await settle(tester);
      expectOnChineseLine(tester, find.text(mixedLine));
    });

    testWidgets('a failed feed\'s message', (tester) async {
      await useSystemFont(tester);
      http.failing.add(1);
      await show(tester, theme: appTheme(), fonts: _systemFont());
      await settle(tester);
      expectOnChineseLine(tester, find.byKey(const ValueKey('feed-error')));
    });
  });

  testWidgets('a failed feed says why, and 重试 loads it', (tester) async {
    http.failing.add(1);
    await show(tester);
    await settle(tester);
    expect(find.byKey(const ValueKey('feed-error')), findsOneWidget);
    http.failing.clear();
    await tester.tap(find.byKey(const ValueKey('feed-retry')));
    await settle(tester);
    expect(find.text('视频 BV1aaa'), findsOneWidget);
  });

  testWidgets('an empty first page says so with 重试 instead of loading forever', (tester) async {
    http.pages[1] = [];
    await show(tester);
    await settle(tester);
    expect(find.text(FeedModel.emptyMessage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    http.pages[1] = twenty();
    await tester.tap(find.byKey(const ValueKey('feed-retry')));
    await settle(tester);
    expect(card('BV1c0'), findsOneWidget);
    expect(http.asked, [1, 1]);
  });

  testWidgets('the next page is asked for only near the end of the grid, never by building cards', (tester) async {
    http.pages[1] = twenty();
    http.pages[2] = [for (var i = 20; i < 40; i++) feedItem('BV1c$i')];
    await show(tester);
    await settle(tester, 40);
    expect(http.asked, [1], reason: 'the end is far below the screen');
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -7000));
    await settle(tester, 20);
    expect(http.asked, [1, 2]);
  });

  testWidgets('a short feed whose next pages add nothing asks three more times, then offers 没有更多了', (tester) async {
    await show(tester);
    await settle(tester, 40);
    expect(http.asked, [1, 2, 3, 4]);
    expect(find.text(FeedModel.endMessage), findsOneWidget);
    expect(find.byKey(const ValueKey('feed-more')), findsNothing, reason: 'no spinner while nothing loads');

    http.pages[5] = [feedItem('BV1ccc')];
    await tester.tap(find.byKey(const ValueKey('feed-retry')));
    await settle(tester, 40);
    expect(http.asked.take(5), [1, 2, 3, 4, 5]);
    expect(card('BV1ccc'), findsOneWidget);
  });

  testWidgets('a failed load more waits for 重试 instead of asking again', (tester) async {
    http.pages[1] = twenty();
    http.failing.add(2);
    await show(tester);
    await settle(tester);
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -7000));
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('feed-error')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -300));
    await settle(tester, 20);
    expect(http.asked, [1, 2]);
    http.failing.clear();
    http.pages[2] = [for (var i = 20; i < 40; i++) feedItem('BV1c$i')];
    await tester.tap(find.byKey(const ValueKey('feed-retry')));
    await settle(tester, 20);
    expect(http.asked, [1, 2, 2]);
    expect(find.byKey(const ValueKey('feed-error')), findsNothing);
  });

  testWidgets('a pull to refresh that fails keeps the cards and says why in a toast', (tester) async {
    http.pages[1] = twenty();
    await show(tester);
    await settle(tester);
    http.failing.add(1);
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, 500));
    await settle(tester, 20);
    expect(http.asked, [1, 1]);
    expect(find.text('网络请求失败（HTTP 500）'), findsOneWidget);
    expect(find.byKey(const ValueKey('feed-error')), findsNothing);
    expect(card('BV1c0'), findsOneWidget);
    await toastGone(tester);
  });

  testWidgets("推荐's pull shows the TV: held while dragged short of the trigger, cycling while it refreshes", (
    tester,
  ) async {
    http.pages[1] = twenty();
    await show(tester);
    await settle(tester);
    Finder spinners() => find.descendant(
      of: find.byType(ReleaseRefreshControl),
      matching: find.byType(CupertinoActivityIndicator),
    );
    final feed = find.byKey(const ValueKey('feed'));
    final pull = await tester.startGesture(tester.getCenter(feed));
    for (var i = 0; i < 4; i++) {
      await pull.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(find.byType(LoadingTv), findsOneWidget);
    // The builder's box spans the width; the 60 pt face is scaled down into it, centred.
    expect(tester.getSize(find.byType(LoadingTv)).height, LoadingTvTheme.size);
    expect(tester.getCenter(find.byType(LoadingTv)).dx, 220);
    await tester.pump(LoadingTvTheme.frame * 2);
    expect(tvFace(tester), 0, reason: 'held');
    expect(spinners(), findsNothing);
    expect(http.asked, [1], reason: 'short of the trigger');

    http.gates[1] = Completer<void>();
    for (var i = 0; i < 10; i++) {
      await pull.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await pull.up();
    await settle(tester, 10);
    expect(http.asked, [1, 1]);
    expect(find.byType(LoadingTv), findsOneWidget);
    final first = tvFace(tester);
    await tester.pump(LoadingTvTheme.frame);
    expect(tvFace(tester), (first + 1) % LoadingTv.frames.length, reason: 'cycling');
    expect(spinners(), findsNothing);

    http.pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1n$i')];
    http.gates[1]!.complete();
    await settle(tester, 30);
    expect(card('BV1n0'), findsOneWidget);
    expect(find.byType(LoadingTv), findsNothing);
  });

  group("推荐's refresh with the 装扮's 加载动画 (119)", () {
    final view = find.byType(SkinLoadingView);

    /// 推荐 shown, then the stand-in 加载动画 put on.
    Future<LoadingSkinModel> wearing(WidgetTester tester) async {
      final animation = await standInLoading(tester);
      late LoadingSkinModel skin;
      http.pages[1] = twenty();
      await show(tester, skin: (environment) => skin = LoadingSkinModel(environment: environment));
      addTearDown(skin.dispose);
      await settle(tester);
      skin.shownLoading.value = animation;
      await tester.pump();
      return skin;
    }

    testWidgets('a pull draws it in place of the TV, held short of the trigger, then playing in its room', (
      tester,
    ) async {
      final skin = await wearing(tester);
      final cardTop = tester.getTopLeft(card('BV1c0')).dy;
      final pull = await tester.startGesture(tester.getTopLeft(find.byKey(const ValueKey('feed'))) + const Offset(220, 30));
      for (var i = 0; i < 4; i++) {
        await pull.moveBy(const Offset(0, 20));
        await tester.pump();
      }
      expect(find.byType(LoadingTv), findsNothing);
      expect(tester.widget<SkinLoadingView>(view).playing, isFalse, reason: 'short of the trigger');
      expect(identical(tester.widget<SkinLoadingView>(view).animation, skin.shownLoading.value), isTrue);
      expect(tester.getSize(view).height, SkinLoadingTheme.size);
      expect(tester.getCenter(view).dx, 220);

      http.gates[1] = Completer<void>();
      for (var i = 0; i < 10; i++) {
        await pull.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      expect(tester.widget<SkinLoadingView>(view).playing, isTrue, reason: 'armed');
      await pull.up();
      // The bounce back to the room takes a moment.
      await settle(tester, 40);
      expect(http.asked, [1, 1]);
      expect(tester.widget<SkinLoadingView>(view).playing, isTrue);
      final room = SkinLoadingTheme.room;
      expect(tester.getTopLeft(card('BV1c0')).dy, moreOrLessEquals(cardTop + room), reason: '85.33 pt held open');
      expect(tester.getRect(view).bottom, moreOrLessEquals(cardTop + room - FeedBigCardTheme.topGap));

      http.pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1n$i')];
      http.gates[1]!.complete();
      await settle(tester, 30);
      expect(card('BV1n0'), findsOneWidget);
      expect(view, findsNothing);
      expect(tester.getTopLeft(card('BV1n0')).dy, moreOrLessEquals(cardTop), reason: 'the room closed');
    });

    testWidgets("a pull arms once the whole picture shows, 60 pt, not the TV's 100", (tester) async {
      await wearing(tester);
      final cardTop = tester.getTopLeft(card('BV1c0')).dy;
      http.gates[1] = Completer<void>();
      final pull = await tester.startGesture(tester.getTopLeft(find.byKey(const ValueKey('feed'))) + const Offset(220, 30));
      double? armedAt;
      for (var i = 0; i < 60 && armedAt == null; i++) {
        await pull.moveBy(const Offset(0, 4));
        await tester.pump();
        if (view.evaluate().isNotEmpty && tester.widget<SkinLoadingView>(view).playing) armedAt = tester.getTopLeft(card('BV1c0')).dy - cardTop;
      }
      expect(armedAt, isNotNull);
      expect(armedAt, inInclusiveRange(SkinLoadingTheme.trigger, SkinLoadingTheme.trigger + 4));
      await pull.up();
      await settle(tester, 40);
      expect(http.asked, [1, 1], reason: 'let go past 60 pt, it refreshes');
      http.gates[1]!.complete();
      await settle(tester, 20);
    });

    testWidgets("首页's tap holds it at the bottom of its 85.33 pt band, in the TV's 60 pt box", (tester) async {
      await wearing(tester);
      final cardTop = tester.getTopLeft(card('BV1c0')).dy;
      http.gates[1] = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('home-tab-home')));
      await settle(tester, 10);
      final band = tester.getRect(find.byKey(const ValueKey('feed-reload')));
      expect(band.height, moreOrLessEquals(SkinLoadingTheme.room));
      final drawn = find.descendant(of: find.byKey(const ValueKey('feed-reload')), matching: view);
      expect(drawn, findsOneWidget);
      expect(find.byType(LoadingTv), findsNothing);
      expect(tester.getRect(drawn).bottom, moreOrLessEquals(band.bottom));
      expect(tester.getCenter(drawn).dx, moreOrLessEquals(band.center.dx));
      expect(tester.getSize(drawn), const Size.square(LoadingTvTheme.size));
      expect(tester.widget<SkinLoadingView>(drawn).playing, isTrue);
      expect(tester.getTopLeft(card('BV1c0')).dy, moreOrLessEquals(cardTop + SkinLoadingTheme.room));
      http.gates[1]!.complete();
      await settle(tester, 20);
      expect(view, findsNothing);
    });

    testWidgets('taken off, a pull shows the TV in its 60 pt room again', (tester) async {
      final skin = await wearing(tester);
      skin.shownLoading.value = null;
      await tester.pump();
      final cardTop = tester.getTopLeft(card('BV1c0')).dy;
      http.gates[1] = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('home-tab-home')));
      await settle(tester, 10);
      expect(view, findsNothing);
      expect(find.byType(LoadingTv), findsOneWidget);
      expect(tester.getTopLeft(card('BV1c0')).dy, moreOrLessEquals(cardTop + LoadingTvTheme.size));
      http.gates[1]!.complete();
      await settle(tester, 20);
    });
  });

  testWidgets('the feed goes idle when hidden: nothing ticks, no frame waits', (tester) async {
    http.pages[1] = twenty();
    http.gates[1] = Completer<void>();
    await show(tester);
    await settle(tester, 2);
    expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'the loading cards sweep');
    http.gates[1]!.complete();
    await settle(tester, 40);
    expect(card('BV1c0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('cards fade in the first time they appear, never again when scrolled back', (tester) async {
    http.pages[1] = twenty();
    await show(tester);
    await settle(tester, 20);
    expect(entrance('BV1c0'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -2500));
    await settle(tester, 20);
    expect(card('BV1c0'), findsNothing, reason: 'scrolled out and let go');
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, 2500));
    await tester.pump();
    expect(card('BV1c0'), findsOneWidget);
    expect(entrance('BV1c0'), findsNothing);
    await settle(tester, 20);
  });

  testWidgets('with reduced motion the cards just appear and the loading cards keep still', (tester) async {
    http.pages[1] = twenty();
    http.gates[1] = Completer<void>();
    await show(tester, still: true);
    await settle(tester, 2);
    expect(tester.binding.transientCallbackCount, 0);
    http.gates[1]!.complete();
    await tester.pump();
    await tester.pump();
    expect(card('BV1c0'), findsOneWidget);
    expect(entrance('BV1c0'), findsNothing);
  });

  testWidgets('--play= opens its part on the video page, with no zoom back, lands in 最近打开, and back closes it', (
    tester,
  ) async {
    await show(tester, initialLink: 'https://www.bilibili.com/video/BV1GJ411x7h7?p=2');
    await settle(tester, 20);
    expect(controller.video?.title, '测试视频');
    expect(controller.page?.cid, 137649200);
    expect(shownTitle(tester), '测试视频', reason: 'the page shows the video it opened');
    expect(recents.items.single.id, 'BV1GJ411x7h7#137649200');
    final route = tester.widget<VideoPage>(find.byType(VideoPage)).route;
    expect(route.detail?.bvid, 'BV1GJ411x7h7', reason: 'the signed view that resolved the link, for its 合集');
    expect(route.zoomSource, isNull);
    expect(ModalRoute.of(tester.element(find.byType(VideoPage))), isNot(isA<ZoomBackPageRoute<void>>()));
    expect(http.canned.to(Canned.signedViewPath).where((request) => request.url.queryParameters['bvid'] == 'BV1GJ411x7h7'), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('video-back')));
    await settle(tester, 20);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.byType(VideoPage), findsNothing, reason: 'the page closed and inline playback resumed');
  });

  testWidgets('--play= shows the spinner while its link resolves', (tester) async {
    http.canned.gates[Canned.signedViewPath] = Completer<void>();
    await show(tester, initialLink: 'https://www.bilibili.com/video/BV1GJ411x7h7?p=2');
    await settle(tester);
    expect(find.byKey(const ValueKey('opening')), findsOneWidget);
    expect(find.byType(VideoPage), findsNothing);
    http.canned.gates[Canned.signedViewPath]!.complete();
    await settle(tester, 20);
    expect(find.byType(VideoPage), findsOneWidget);
    expect(find.byKey(const ValueKey('opening')), findsNothing);
  });

  testWidgets('--play= to a video in parts asks which part, with no spinner left behind the sheet', (tester) async {
    await show(tester, initialLink: 'BV1GJ411x7h7');
    await settle(tester, 20);
    expect(find.text('选择分P'), findsOneWidget);
    expect(find.byKey(const ValueKey('opening')), findsNothing);
    await tester.tap(find.text('P1 第一集'));
    await settle(tester, 20);
    expect(controller.page?.cid, 137649199);
  });

  testWidgets('a card opens its video page with the card title first', (tester) async {
    http.canned.gates[Canned.signedViewPath] = Completer<void>();
    await show(tester);
    await settle(tester);
    await tester.tap(card('BV1aaa'));
    await settle(tester, 20);
    expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.title, '视频 BV1aaa');
    expect(shownTitle(tester), isNull, reason: '简介 waits for the video\'s detail');
    http.canned.gates[Canned.signedViewPath]!.complete();
    await settle(tester, 20);
    expect(controller.video?.title, '测试视频');
    expect(shownTitle(tester), '测试视频', reason: 'the page shows the video it opened');
  });

  testWidgets('a phone tile opens a sliding video page and returns to the feed', (tester) async {
    await show(tester);
    await settle(tester);
    await tester.tap(card('BV1aaa'));
    await settle(tester, 20);
    final page = tester.widget<VideoPage>(find.byType(VideoPage));
    expect(page.route.zoomSource, isNull);
    expect(page.route.title, '视频 BV1aaa');
    await tester.tap(find.byKey(const ValueKey('video-back')));
    await settle(tester, 20);
    expect(find.byType(VideoPage), findsNothing);
    expect(card('BV1aaa'), findsOneWidget);
  });

  testWidgets("〈 straight from a card's page flies back into it, and the card shows its cover again", (tester) async {
    await show(tester);
    await settle(tester);
    await tester.tap(card('BV1aaa'));
    await settle(tester, 20);
    await tester.tap(find.byKey(const ValueKey('video-back')));
    await settle(tester, 20);
    expect(find.byType(VideoPage), findsNothing);
    expect(cover('BV1aaa'), findsOneWidget, reason: 'not left Offstage in the Hero placeholder from the push');
  });

  group('swipe back on the real video page', () {
    for (final (where, y) in [('over the player', 150.0), ('over the body', 600.0)]) {
      testWidgets('from the left edge $where it flies back into the card', (tester) async {
        await show(tester);
        await settle(tester);
        final resting = tester.getRect(card('BV1aaa'));
        await tester.tap(card('BV1aaa'));
        await settle(tester, 20);
        expect(find.byType(VideoPage), findsOneWidget);
        final gesture = await tester.startGesture(Offset(5, y));
        for (var i = 1; i <= 10; i++) {
          await gesture.moveTo(Offset(5 + 25.0 * i, y), timeStamp: Duration(milliseconds: 16 * i));
          await tester.pump(const Duration(milliseconds: 16));
        }
        final shrunk = tester.getRect(find.byType(VideoPage));
        expect(shrunk.left, greaterThan(0), reason: 'the page slides under the finger');
        await gesture.up(timeStamp: const Duration(milliseconds: 176));
        await settle(tester, 20);
        expect(find.byType(VideoPage), findsNothing);
        expect(tester.getRect(card('BV1aaa')), resting);
        expect(cover('BV1aaa'), findsOneWidget, reason: "the card's cover is back");
      });
    }
  });

  testWidgets("⋮ opens 90's sheet whose 添加至稍后再看 adds the video; a web card has no 不感兴趣", (tester) async {
    http.canned.routes[_watchLaterPath] = (200, '{"code":0,"message":"0","ttl":1}');
    await show(tester);
    await settle(tester);
    final more = find.descendant(of: card('BV1aaa'), matching: find.byKey(const ValueKey('big-card-more')));
    expect(tester.getSize(more).width, FeedBigCardTheme.moreTarget);
    await tester.tap(more);
    await settle(tester);
    expect(find.byType(FeedSheetRow), findsOneWidget);
    expect(find.text('添加至稍后再看'), findsOneWidget);
    expect(find.textContaining('不感兴趣'), findsNothing);
    expect(find.descendant(of: find.byType(FeedSheetRow), matching: find.byType(InkWell)), findsNothing);
    await tester.tap(find.byKey(const ValueKey('feed-more-watch-later')));
    await settle(tester);
    expect(find.byType(FeedSheetRow), findsNothing);
    expect(find.text('已添加至稍后再看'), findsOneWidget);
    final sent = Uri.splitQueryString(utf8.decode(http.canned.to(_watchLaterPath).single.body!));
    expect(sent['aid'], '${'BV1aaa'.hashCode.abs()}');
    await toastGone(tester);

    await tester.tap(more);
    await settle(tester);
    await tester.tapAt(const Offset(220, 300));
    await settle(tester);
    expect(find.byType(FeedSheetRow), findsNothing, reason: 'a tap on the dim closes it');
    expect(http.canned.to(_watchLaterPath), hasLength(1));
  });

  testWidgets('the avatar opens its page, whose 全部 lists 最近打开 while logged out, and back returns home', (tester) async {
    http = FeedHttp(loggedIn: false);
    await show(tester, developer: true);
    await settle(tester);
    recents.add(const RecentVideo(bvid: 'BV1x', cid: 3, title: '最近的视频', part: '', page: 1, pageCount: 1));
    await tester.tap(find.byKey(const ValueKey('home-avatar')));
    await settle(tester, 20);
    expect(find.byType(AvatarPage), findsOneWidget);
    expect(find.text('最近的视频'), findsOneWidget, reason: 'in the card on the page');
    expect(find.text('开发者'), findsNothing, reason: '开发者 is in 设置');
    await tester.tap(find.byKey(const ValueKey('avatar-all')));
    await settle(tester, 20);
    expect(find.text('最近打开'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ListView), matching: find.byType(InkWell)),
      findsNothing,
      reason: 'recents rows highlight instead of rippling',
    );
    await tester.tap(find.byKey(const ValueKey('recents-clear')));
    await settle(tester, 20);
    await tester.tap(find.byKey(const ValueKey('recents-clear-confirm')));
    await settle(tester, 20);
    expect(recents.items, isEmpty);

    await tester.pageBack();
    await settle(tester, 20);
    expect(find.text('还没有打开过视频'), findsOneWidget, reason: 'the avatar page follows the store');
    await tester.tap(find.byKey(const ValueKey('avatar-back')));
    await settle(tester, 20);
    expect(find.byType(AvatarPage), findsNothing);
    expect(find.text('推荐'), findsOneWidget);
  });

  testWidgets('⚙ on the avatar page opens 设置 with the font in use', (tester) async {
    await show(tester);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-avatar')));
    await settle(tester, 20);
    await tester.tap(find.byKey(const ValueKey('avatar-settings')));
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('settings-font')), findsOneWidget);
    expect(find.text('MiSans'), findsOneWidget);
  });

  testWidgets('back on home from the avatar page, an account check that failed is tried again', (tester) async {
    http.canned.routes[Canned.navPath] = (500, '');
    await show(tester);
    await settle(tester);
    expect(environment.account, isA<AccountUnknown>());
    expect(environment.accountCheckFailed, isTrue);

    Future<void> visit() async {
      await tester.tap(find.byKey(const ValueKey('home-avatar')));
      await settle(tester, 20);
      expect(find.byType(AvatarPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('avatar-back')));
      await settle(tester, 20);
    }

    http.canned.routes[Canned.navPath] = (200, Canned.navLoggedIn);
    final asked = http.canned.to(Canned.navPath).length;
    await visit();
    expect(environment.account, isA<LoggedIn>());
    expect(http.canned.to(Canned.navPath), hasLength(asked + 1));

    await visit();
    expect(http.canned.to(Canned.navPath), hasLength(asked + 1), reason: 'a known account is not asked again');
  });

  testWidgets('历史记录 on the avatar page opens 历史记录, and back returns to the page', (tester) async {
    await show(tester);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-avatar')));
    await settle(tester, 20);
    await tester.tap(find.byKey(const ValueKey('avatar-history')));
    await settle(tester, 20);
    expect(find.byType(WatchHistoryPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester, 20);
    expect(find.byType(WatchHistoryPage), findsNothing);
    expect(find.byType(AvatarPage), findsOneWidget);
  });

  testWidgets('推荐 refreshes once when the account logs in or out, and not on other account news', (tester) async {
    http.pages[1] = twenty();
    http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
    await show(tester, cookies: _loggedOutCookies);
    await settle(tester, 20);
    expect(environment.account, isA<LoggedOut>());
    expect(http.asked, [1]);

    Future<void> check() async {
      await environment.refreshAccount();
      await settle(tester, 20);
    }

    await check();
    expect(http.asked, [1], reason: 'still logged out');

    http.canned.errors[Canned.navPath] = Exception('offline');
    await check();
    expect(environment.account, isA<LoggedOut>());
    expect(http.asked, [1], reason: 'a failed check changes nothing');
    http.canned.errors.remove(Canned.navPath);

    environment.cookies.set('SESSDATA', 's');
    http.canned.routes[Canned.navPath] = (200, Canned.navLoggedIn);
    await check();
    expect(environment.account, isA<LoggedIn>());
    expect(http.asked, [1, 1], reason: 'logged in');

    await check();
    expect(http.asked, [1, 1], reason: 'still logged in');

    http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
    await check();
    expect(environment.account, isA<LoginExpired>());
    expect(http.asked, [1, 1, 1], reason: 'expired');

    environment.cookies.remove('SESSDATA');
    await check();
    expect(environment.account, isA<LoggedOut>());
    expect(http.asked, [1, 1, 1], reason: 'expired to logged out is no flip');
  });

  for (final (state, cookies) in [('logged out', _loggedOutCookies), ('expired', Canned.cookies)]) {
    testWidgets('$state, ⋮ 稍后再看 opens the login page and sends nothing', (tester) async {
      http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
      http.canned.routes[_watchLaterPath] = (200, '{"code":0,"message":"0","ttl":1}');
      await show(tester, cookies: cookies);
      await settle(tester);
      expect(environment.account, anyOf(isA<LoggedOut>(), isA<LoginExpired>()));
      await tester.tap(find.descendant(of: card('BV1aaa'), matching: find.byKey(const ValueKey('big-card-more'))));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('feed-more-watch-later')));
      await settle(tester);
      expect(gate.requests, 1);
      expect(http.canned.to(_watchLaterPath), isEmpty);
      expect(find.text('已添加至稍后再看'), findsNothing);
    });
  }

  testWidgets('logged in, a needs-login answer to 稍后再看 opens the login page instead of a toast', (tester) async {
    http.canned.routes[_watchLaterPath] = (200, '{"code":-101,"message":"账号未登录","ttl":1}');
    await show(tester);
    await settle(tester);
    expect(environment.account, isA<LoggedIn>());
    await tester.tap(find.descendant(of: card('BV1aaa'), matching: find.byKey(const ValueKey('big-card-more'))));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('feed-more-watch-later')));
    await settle(tester);
    expect(http.canned.to(_watchLaterPath), hasLength(1));
    expect(gate.requests, 1);
    expect(find.text('需要登录'), findsNothing);
  });

  testWidgets('cards are buttons named by their title with 稍后再看 as their action, and ⋮ a button of its own', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    await settle(tester);
    expect(
      tester.getSemantics(find.descendant(of: card('BV1aaa'), matching: find.byKey(const ValueKey('big-card-open-title')))),
      isSemantics(
        label: '视频 BV1aaa',
        isButton: true,
        hasTapAction: true,
        customActions: const [CustomSemanticsAction(label: '稍后再看')],
      ),
    );
    final more = find.descendant(of: card('BV1aaa'), matching: find.byKey(const ValueKey('big-card-more-semantics')));
    expect(tester.getSemantics(more), isSemantics(label: '更多', isButton: true, hasTapAction: true));
    expect(
      tester.getRect(more),
      tester.getRect(find.descendant(of: card('BV1aaa'), matching: find.byKey(const ValueKey('big-card-more')))),
      reason: "over the ⋮ it names",
    );
    expect(find.semantics.byLabel('更多'), findsExactly(2), reason: 'one per card');

    tester.semantics.tap(find.semantics.byLabel('更多').first);
    await settle(tester);
    expect(find.text('添加至稍后再看'), findsOneWidget, reason: 'an accessibility press opens the sheet');
    semantics.dispose();
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets('nothing overflows at text scale $scale, on home or the avatar page', (tester) async {
      await show(tester, scale: scale);
      await settle(tester);
      expect(card('BV1aaa'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-avatar')));
      await settle(tester, 20);
      expect(find.byType(AvatarPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('the search entry', () {
    testWidgets('shows the default word, asked for once, and opens 搜索 with it; back returns home', (tester) async {
      final search = FakeSearchApi(defaultWord: _word);
      final semantics = tester.ensureSemantics();
      await show(tester, search: search);
      await settle(tester);
      expect(find.text(_word), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'a bar to tap, not a field');
      expect(
        tester.getSemantics(find.byKey(const ValueKey('home-search'))),
        isSemantics(label: '搜索', value: _word, isButton: true, hasTapAction: true),
      );

      await tester.tap(find.byKey(const ValueKey('home-search')));
      await settle(tester, 20);
      expect(tester.widget<SearchPage>(find.byType(SearchPage)).placeholder, _word);
      await tester.binding.handlePopRoute();
      await settle(tester, 20);
      expect(find.byType(SearchPage), findsNothing);
      expect(find.text(_word), findsOneWidget);
      expect(search.calls.where((call) => call == 'defaultWord'), hasLength(1));
      semantics.dispose();
    });

    testWidgets('greys while pressed, in its stadium, and clears when let go or the press moves off', (tester) async {
      await show(tester);
      await settle(tester);
      ShapeDecoration face() =>
          tester.widget<Container>(find.byKey(const ValueKey('home-search-field'))).foregroundDecoration!
              as ShapeDecoration;
      expect(face().color, isNull);

      final press = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-search'))));
      await tester.pump(kPressTimeout);
      expect(face().color, BiliColors.pressedFill);
      expect(face().shape, isA<StadiumBorder>());
      await press.moveBy(const Offset(0, 200));
      await tester.pump();
      expect(face().color, isNull, reason: 'dragged off, no tap');
      await press.up();
      await settle(tester);
      expect(find.byType(SearchPage), findsNothing);

      final tap = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-search'))));
      await tester.pump(kPressTimeout);
      expect(face().color, BiliColors.pressedFill);
      await tap.up();
      await tester.pump();
      expect(face().color, isNull);
      await settle(tester, 20);
      expect(find.byType(SearchPage), findsOneWidget);
    });

    testWidgets('a failed default word leaves the bar empty, and 搜索 opens with none', (tester) async {
      await show(tester, search: _FailingSearchApi());
      await settle(tester);
      expect(tester.widget<Text>(find.byKey(const ValueKey('home-search-word'))).data, isEmpty);
      await tester.tap(find.byKey(const ValueKey('home-search')));
      await settle(tester, 20);
      expect(tester.widget<SearchPage>(find.byType(SearchPage)).placeholder, isNull);
    });
  });

  group("首页's tap", () {
    ScrollPosition feedScroll(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(of: find.byKey(const ValueKey('feed')), matching: find.byType(Scrollable)).first,
        )
        .position;

    Finder reloadTv() =>
        find.descendant(of: find.byKey(const ValueKey('feed-reload')), matching: find.byType(LoadingTv));

    List<Map<String, Object?>> fresh() => [for (var i = 0; i < 20; i++) feedItem('BV1n$i')];

    Future<void> tapHome(WidgetTester tester) => tester.tap(find.byKey(const ValueKey('home-tab-home')));

    testWidgets('scrolled, goes back to the top and refreshes 推荐 once, the TV up until the new cards', (
      tester,
    ) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -1500));
      await settle(tester, 20);
      final from = feedScroll(tester).pixels;
      expect(from, greaterThan(1000));
      final asked = http.asked.length;
      http.pages[1] = fresh();
      http.gates[1] = Completer<void>();

      await tapHome(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(http.asked.sublist(asked), [1], reason: 'straight away, not after the scroll');
      expect(feedScroll(tester).pixels, inExclusiveRange(0, from), reason: 'scrolling, not jumped');
      expect(reloadTv(), findsNothing, reason: 'the TV opens once at the top');
      await settle(tester, 10);
      expect(feedScroll(tester).pixels, 0);
      expect(reloadTv(), findsOneWidget);
      expect(card('BV1c0'), findsOneWidget, reason: 'the old cards stay until the new ones come');

      http.gates[1]!.complete();
      await settle(tester, 20);
      expect(card('BV1n0'), findsOneWidget);
      expect(card('BV1c0'), findsNothing);
      expect(find.byKey(const ValueKey('feed-reload')), findsNothing);
      expect(http.asked.sublist(asked), [1]);
      await settle(tester, 40);
      expect(entrance('BV1c0'), findsNothing, reason: 'card entrances have finished');
    });

    testWidgets('the header holds the cycling TV centred in its 60 pt band, above the cards', (tester) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      final cardTop = tester.getTopLeft(card('BV1c0')).dy;
      http.gates[1] = Completer<void>();
      await tapHome(tester);
      await settle(tester, 10);
      final band = tester.getRect(find.byKey(const ValueKey('feed-reload')));
      // The band starts under a one-pixel hairline, at a third of a point.
      expect(band.height, moreOrLessEquals(LoadingTvTheme.size));
      final tv = tester.getRect(reloadTv());
      expect((tv.center - band.center).distance, moreOrLessEquals(0));
      expect(tv.width, moreOrLessEquals(60));
      expect(tv.height, moreOrLessEquals(60));
      expect(tester.getTopLeft(card('BV1c0')).dy, moreOrLessEquals(cardTop + LoadingTvTheme.size));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('feed-reload')),
          matching: find.byType(CupertinoActivityIndicator),
        ),
        findsNothing,
      );
      final first = tvFace(tester);
      await tester.pump(LoadingTvTheme.frame);
      expect(tvFace(tester), (first + 1) % LoadingTv.frames.length);
      http.gates[1]!.complete();
      await settle(tester, 20);
      expect(find.byType(LoadingTv), findsNothing);
    });

    testWidgets('at the top, refreshes 推荐 once with the TV up', (tester) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      expect(feedScroll(tester).pixels, 0);
      http.pages[1] = fresh();
      http.gates[1] = Completer<void>();
      await tapHome(tester);
      await settle(tester, 6);
      expect(http.asked, [1, 1]);
      expect(reloadTv(), findsOneWidget);
      expect(feedScroll(tester).pixels, 0);
      http.gates[1]!.complete();
      await settle(tester, 20);
      expect(card('BV1n0'), findsOneWidget);
      expect(find.byKey(const ValueKey('feed-reload')), findsNothing);
      expect(http.asked, [1, 1]);
    });

    testWidgets('does nothing more during the first load or a refresh, from a tap or a pull', (tester) async {
      http.pages[1] = twenty();
      http.gates[1] = Completer<void>();
      await show(tester);
      await settle(tester, 2);
      await tapHome(tester);
      await settle(tester, 2);
      expect(http.asked, [1], reason: 'the first load is running');
      http.gates[1]!.complete();
      await settle(tester);

      http.gates[1] = Completer<void>();
      await tapHome(tester);
      await settle(tester, 10);
      await tapHome(tester);
      await settle(tester, 10);
      final finger = await tester.startGesture(tester.getTopLeft(find.byKey(const ValueKey('feed'))) + const Offset(220, 30));
      for (var i = 0; i < 12; i++) {
        await finger.moveBy(const Offset(0, 25));
        await tester.pump(const Duration(microseconds: 16667));
      }
      expect(find.byType(LoadingTv), findsOneWidget, reason: 'held past the trigger: only the tap\'s TV');
      await finger.up();
      await settle(tester, 10);
      expect(http.asked, [1, 1]);
      expect(find.byType(LoadingTv), findsOneWidget, reason: 'released: no second gap opens');
      http.gates[1]!.complete();
      await settle(tester, 20);
      expect(http.asked, [1, 1]);
      expect(find.byKey(const ValueKey('feed-reload')), findsNothing);

      await tapHome(tester);
      await settle(tester, 20);
      expect(http.asked, [1, 1, 1], reason: 'once the refresh is done a tap refreshes again');
    });

    testWidgets('during the refresh after a login, a tap or a pull waits on it instead of asking again', (
      tester,
    ) async {
      http.pages[1] = twenty();
      http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
      await show(tester, cookies: _loggedOutCookies);
      await settle(tester, 20);
      expect(environment.account, isA<LoggedOut>());
      expect(http.asked, [1]);

      http.pages[1] = fresh();
      http.gates[1] = Completer<void>();
      environment.cookies.set('SESSDATA', 's');
      http.canned.routes[Canned.navPath] = (200, Canned.navLoggedIn);
      await environment.refreshAccount();
      await settle(tester, 4);
      expect(environment.account, isA<LoggedIn>());
      expect(http.asked, [1, 1], reason: 'the login refresh, held');

      await tapHome(tester);
      await settle(tester, 10);
      expect(http.asked, [1, 1], reason: 'a tap');
      await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, 500));
      await settle(tester, 10);
      expect(http.asked, [1, 1], reason: 'a pull');

      http.gates[1]!.complete();
      await settle(tester, 20);
      expect(http.asked, [1, 1]);
      expect(card('BV1n0'), findsOneWidget);
      expect(find.byKey(const ValueKey('feed-reload')), findsNothing);
    });

    testWidgets('with reduced motion jumps to the top and shows the TV at once, on its first face', (tester) async {
      http.pages[1] = twenty();
      await show(tester, still: true);
      await settle(tester);
      await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -1500));
      await settle(tester, 20);
      expect(feedScroll(tester).pixels, greaterThan(1000));
      http.gates[1] = Completer<void>();
      await tapHome(tester);
      await tester.pump();
      expect(feedScroll(tester).pixels, 0);
      expect(reloadTv(), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('feed-reload'))).height, 60, reason: 'already open');
      await tester.pump(LoadingTvTheme.frame * 2);
      expect(tvFace(tester), 0);
      http.gates[1]!.complete();
      await settle(tester, 4);
      expect(find.byKey(const ValueKey('feed-reload')), findsNothing);
    });

    testWidgets('a refresh that fails keeps the cards and says why in a toast', (tester) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      http.failing.add(1);
      await tapHome(tester);
      await settle(tester, 20);
      expect(http.asked, [1, 1]);
      expect(find.text('网络请求失败（HTTP 500）'), findsOneWidget);
      expect(find.byKey(const ValueKey('feed-error')), findsNothing);
      expect(find.byKey(const ValueKey('feed-reload')), findsNothing);
      expect(card('BV1c0'), findsOneWidget);
      await toastGone(tester);
    });

    group('the minimum refresh', () {
      setUp(() => HomePage.feedMinimumRefresh = FeedModel.minimumRefresh);

      testWidgets('answered at once, the TV is still up 1.4 s after the tap over the old cards, gone after the swap', (
        tester,
      ) async {
        http.pages[1] = twenty();
        await show(tester);
        await settle(tester);
        http.pages[1] = fresh();
        await tapHome(tester);
        await tester.pump();
        await settle(tester, 28);
        expect(http.asked, [1, 1]);
        expect(reloadTv(), findsOneWidget);
        expect(card('BV1c0'), findsOneWidget);
        expect(card('BV1n0'), findsNothing);
        await settle(tester, 4);
        expect(card('BV1n0'), findsOneWidget);
        await settle(tester, 20);
        expect(find.byKey(const ValueKey('feed-reload')), findsNothing);
        expect(find.byType(LoadingTv), findsNothing);
      });

      testWidgets("a pull's TV stays 1.4 s after the release, gone after the swap", (tester) async {
        http.pages[1] = twenty();
        await show(tester);
        await settle(tester);
        http.pages[1] = fresh();
        await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, 500));
        await tester.pump();
        await settle(tester, 28);
        expect(find.byType(LoadingTv), findsOneWidget);
        expect(card('BV1c0'), findsOneWidget);
        await settle(tester, 4);
        expect(card('BV1n0'), findsOneWidget);
        await settle(tester, 20);
        expect(find.byType(LoadingTv), findsNothing);
      });
    });
  });

  group('single-column refresh batches', () {
    final divider = find.byKey(const ValueKey('feed-divider'));
    Future<void> refresh(WidgetTester tester, String prefix, int count) async {
      http.pages[1] = [for (var i = 0; i < count; i++) feedItem('$prefix$i')];
      await tester.tap(find.byKey(const ValueKey('home-tab-home')));
      await settle(tester, 30);
    }
    Future<void> reveal(WidgetTester tester, Finder target) async {
      await tester.scrollUntilVisible(target, 250);
      await settle(tester);
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.3);
      await settle(tester);
    }

    testWidgets('a refresh stacks full-width tiles above the divider and keeps the previous batch', (tester) async {
      await show(tester);
      await settle(tester);
      await refresh(tester, 'BV1n', 3);
      final first = tester.getRect(card('BV1n0'));
      final second = tester.getRect(card('BV1n1'));
      expect(first.width, 408);
      expect(second.top, greaterThan(first.bottom));
      expect(second.left, first.left);
      await reveal(tester, divider);
      expect(divider, findsOneWidget);
      await reveal(tester, card('BV1aaa'));
      expect(card('BV1aaa'), findsOneWidget);
    });

    testWidgets('a second refresh leaves one divider under the newest batch', (tester) async {
      await show(tester);
      await settle(tester);
      await refresh(tester, 'BV1n', 2);
      await refresh(tester, 'BV1t', 2);
      await reveal(tester, divider);
      expect(divider, findsOneWidget);
      await reveal(tester, card('BV1n0'));
      expect(card('BV1n0'), findsOneWidget);
      await reveal(tester, card('BV1aaa'));
      expect(card('BV1aaa'), findsOneWidget);
    });

    testWidgets('pagination appends below old tiles after refreshing', (tester) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      await refresh(tester, 'BV1n', 4);
      http.pages[2] = [feedItem('BV1more')];
      await reveal(tester, card('BV1more'));
      expect(http.asked.take(3), [1, 1, 2]);
      expect(card('BV1more'), findsOneWidget);
    });

    testWidgets('tapping the divider returns to the top and refreshes', (tester) async {
      await show(tester);
      await settle(tester);
      await refresh(tester, 'BV1n', 3);
      await reveal(tester, divider);
      http.pages[1] = [feedItem('BV1latest')];
      await tester.tap(divider);
      await settle(tester, 30);
      expect(http.asked.where((index) => index == 1), hasLength(3));
      expect(card('BV1latest'), findsOneWidget);
    });

    testWidgets('an account change replaces old batches and removes the divider', (tester) async {
      await show(tester);
      await settle(tester);
      await refresh(tester, 'BV1n', 3);
      http.pages[1] = [feedItem('BV1account')];
      http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
      await environment.refreshAccount();
      await settle(tester, 40);
      expect(card('BV1account'), findsOneWidget);
      expect(divider, findsNothing);
      expect(find.byKey(const ValueKey('feed-card-BV1n0'), skipOffstage: false), findsNothing);
    });

    testWidgets('a previous-batch tile keeps watch-later and opens its video page', (tester) async {
      http.canned.routes[_watchLaterPath] = (200, '{"code":0}');
      await show(tester);
      await settle(tester);
      await refresh(tester, 'BV1n', 2);
      await reveal(tester, card('BV1aaa'));
      final more = find.descendant(of: card('BV1aaa'), matching: find.byKey(const ValueKey('big-card-more')));
      await tester.tap(more);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('feed-more-watch-later')));
      await toastGone(tester);
      expect(http.canned.to(_watchLaterPath), hasLength(1));
      await tester.tap(card('BV1aaa'));
      await settle(tester, 20);
      expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.title, '视频 BV1aaa');
      await tester.tap(find.byKey(const ValueKey('video-back')));
      await settle(tester, 20);
      expect(card('BV1aaa'), findsOneWidget);
    });
  });

  group("a refresh's covers and hand-off", () {
    late _Covers covers;
    late MemorySink logs;

    setUp(() {
      covers = _Covers();
      HomePage.precacheBigCover = covers.precache;
      logs = MemorySink();
      Logger.shared.add(logs);
    });

    tearDown(() {
      HomePage.precacheBigCover = FeedBigCardView.precacheCover;
      Logger.shared.remove(logs);
    });

    List<Map<String, Object?>> fresh() => [for (var i = 0; i < 20; i++) feedItem('BV1n$i')];

    Future<void> tapHome(WidgetTester tester) => tester.tap(find.byKey(const ValueKey('home-tab-home')));

    final reload = find.byKey(const ValueKey('feed-reload'));
    final reloadTv = find.descendant(of: reload, matching: find.byType(LoadingTv));

    Finder going(String bvid) => find.byKey(ValueKey('feed-card-going-$bvid'));

    double goingOpacity(WidgetTester tester, String bvid) {
      final fade = find.ancestor(of: going(bvid), matching: find.byType(FadeTransition)).first;
      return tester.widget<FadeTransition>(fade).opacity.value;
    }

    List<LogEvent> coverLines() => [for (final event in logs.events) if (event.msg == 'feed covers') event];

    /// Pumps 1 ms frames until the hand-off has begun (the old card [bvid] drawn over the new), so what follows counts
    /// from its first frame however many frames the covers' futures took to land.
    Future<void> untilHandOff(WidgetTester tester, [String bvid = 'BV1c0']) async {
      for (var i = 0; i < 20 && going(bvid).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(going(bvid), findsOneWidget, reason: 'the hand-off has begun');
    }

    /// The opacity the slot gives the card itself (under the going one, if any).
    double slotOpacity(WidgetTester tester, String bvid) => tester
        .widget<FadeTransition>(find.descendant(of: card(bvid), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;

    /// The new cards whose top is inside the list, once it rests at the top: both columns of every row it shows.
    List<String> firstScreen(WidgetTester tester) {
      final bottom = tester.getRect(find.byKey(const ValueKey('feed'))).bottom;
      final built = [for (var i = 0; i < 20; i++) 'BV1n$i'].where((bvid) => card(bvid).evaluate().isNotEmpty);
      return [
        for (final bvid in built)
          if (tester.getTopLeft(card(bvid)).dy < bottom) bvid,
      ];
    }

    testWidgets("首页's TV stays over the old cards until the answer; then it closes as the old cards cross-fade into "
        "the new in place, the first screen's covers asked for at their cards' size, never waited on", (tester) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      expect(covers.asked, contains('BV1c0'), reason: 'the first load gets its covers ready too');
      covers
        ..holding = true
        ..asked.clear();
      http.pages[1] = fresh();
      final answer = http.gates[1] = Completer<void>();
      await tapHome(tester);
      await settle(tester, 5);
      expect(http.asked, [1, 1]);
      expect(covers.asked, isEmpty, reason: 'no answer yet');
      expect(reloadTv, findsOneWidget);
      expect(card('BV1c0'), findsOneWidget, reason: 'the old cards stay, fully drawn');
      expect(card('BV1n0'), findsNothing);
      expect(coverLines(), hasLength(1), reason: 'the first load');

      answer.complete();
      await untilHandOff(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(card('BV1n0'), findsOneWidget, reason: 'the covers still loading');
      expect(going('BV1c0'), findsOneWidget, reason: 'the old card fading out over the new one');
      expect(goingOpacity(tester, 'BV1c0'), inExclusiveRange(0, 1));
      expect(slotOpacity(tester, 'BV1n0'), 1, reason: 'the new card stands at full opacity under it');
      expect(tester.getTopLeft(going('BV1c0')), tester.getTopLeft(card('BV1n0')), reason: 'in its slot');
      expect(
        tester.getSize(find.ancestor(of: reload, matching: find.byType(SizeTransition))).height,
        inExclusiveRange(0, LoadingTvTheme.size),
        reason: "the TV's room closing meanwhile",
      );
      expect(
        find.ancestor(of: going('BV1c0'), matching: find.byWidgetPredicate((w) => w is HeroMode && !w.enabled)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: going('BV1c0'), matching: find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring)),
        findsWidgets,
      );

      await tester.pump(const Duration(milliseconds: 60));
      expect(reload, findsNothing, reason: 'the TV room closes in 100 ms');
      expect(going('BV1c0'), findsOneWidget, reason: 'the cards fade a little longer');
      await tester.pump(HomeTabBarTheme.handOff);
      expect(going('BV1c0'), findsNothing);
      expect(find.byKey(const ValueKey('feed-card-going-BV1c1')), findsNothing);
      expect(card('BV1c0'), findsNothing);
      expect(card('BV1n0'), findsOneWidget);

      final screen = firstScreen(tester);
      expect(screen, isNotEmpty, reason: 'visible single-column tiles');
      expect(covers.asked, screen, reason: 'the rows that show, no more');
      expect(covers.sizes['BV1n0'], tester.getSize(cover('BV1n0')), reason: "the size the card's cover asks for");
      final line = coverLines().last;
      expect(line.f['ready']?.toJson(), 0, reason: 'none ready as the cards showed');
      expect(line.f['failed']?.toJson(), 0);
      expect(line.f['of']?.toJson(), screen.length);
      expect(line.f['early']?.toJson(), false);

      covers.ready();
      await settle(tester, 10);
      expect(find.byKey(const ValueKey('feed-skeleton')), findsNothing);
    });

    testWidgets("the pull's cards show at the answer and cross-fade too", (tester) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      covers.holding = true;
      http.pages[1] = fresh();
      final answer = http.gates[1] = Completer<void>();
      await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, 500));
      await settle(tester, 10);
      expect(http.asked, [1, 1]);
      expect(find.byType(LoadingTv), findsOneWidget);
      expect(card('BV1c0'), findsOneWidget);
      answer.complete();
      await untilHandOff(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(card('BV1n0'), findsOneWidget);
      expect(going('BV1c0'), findsOneWidget);
      expect(goingOpacity(tester, 'BV1c0'), inExclusiveRange(0, 1));
      await settle(tester, 30);
      expect(find.byType(LoadingTv), findsNothing);
      expect(going('BV1c0'), findsNothing);
    });

    group('a pull held past the trigger', () {
      final feedList = find.byKey(const ValueKey('feed'));

      List<LogEvent> lines(String msg) => [for (final event in logs.events) if (event.msg == msg) event];

      /// Down [steps] × 25 px at about 1500 px/s, a frame each; negative goes back up.
      Future<void> move(WidgetTester tester, TestGesture finger, int steps) async {
        for (var i = 0; i < steps.abs(); i++) {
          await finger.moveBy(Offset(0, steps.sign * 25.0));
          await tester.pump(const Duration(microseconds: 16667));
        }
      }

      Future<TestGesture> armed(WidgetTester tester) async {
        tester.state<ScrollableState>(find.descendant(of: feedList, matching: find.byType(Scrollable)).first).position.jumpTo(0);
        await settle(tester);
        final finger = await tester.startGesture(tester.getTopLeft(feedList) + const Offset(220, 30));
        await move(tester, finger, 12);
        expect(tester.widget<LoadingTv>(find.byType(LoadingTv)).playing, isTrue, reason: 'armed');
        return finger;
      }

      /// Shown on the first load, and the rest let settle.
      Future<void> shown(WidgetTester tester) async {
        http.pages[1] = twenty();
        await show(tester);
        await settle(tester);
        covers.asked.clear();
        http.pages[1] = fresh();
      }

      testWidgets('asks for page 1 once at the trigger and its covers once in, and shows nothing until the finger '
          'lifts; then the cards come at once', (tester) async {
        await shown(tester);
        final pages = lines('feed page').length;
        final finger = await armed(tester);
        await settle(tester, 4);
        expect(http.asked, [1, 1], reason: 'asked while held');
        expect(covers.asked, isNotEmpty, reason: "the first screen's covers on their way");
        await settle(tester, 20);
        expect(card('BV1c0'), findsOneWidget, reason: 'held for 1 s: nothing changes');
        expect(card('BV1n0'), findsNothing);
        expect(going('BV1c0'), findsNothing);
        expect(lines('feed page'), hasLength(pages));

        await finger.up();
        await untilHandOff(tester);
        expect(card('BV1n0'), findsOneWidget);
        expect(http.asked, [1, 1], reason: 'the release joined the early call');
        final line = coverLines().last;
        expect(line.f['early']?.toJson(), true);
        expect(line.f['heldMs']?.toJson(), greaterThan(0));
        expect(line.f['ready']?.toJson(), line.f['of']?.toJson(), reason: 'ready by the release');
        await settle(tester, 30);
        expect(find.byType(LoadingTv), findsNothing);
      });

      testWidgets('let go before the answer, the cards come with it', (tester) async {
        await shown(tester);
        final answer = http.gates[1] = Completer<void>();
        final finger = await armed(tester);
        await settle(tester, 2);
        expect(http.asked, [1, 1]);
        await finger.up();
        await settle(tester, 10);
        expect(find.byType(LoadingTv), findsOneWidget, reason: 'refreshing');
        expect(card('BV1c0'), findsOneWidget);
        expect(http.asked, [1, 1]);
        answer.complete();
        await untilHandOff(tester);
        expect(card('BV1n0'), findsOneWidget);
        expect(coverLines().last.f['early']?.toJson(), true);
        await settle(tester, 30);
      });

      for (final answerFirst in [true, false]) {
        testWidgets('pushed back up until the TV is gone and let go there refreshes nothing, the answer '
            '${answerFirst ? 'in before' : 'coming after'} the lift; a pull armed again soon asks nothing more', (
          tester,
        ) async {
          await shown(tester);
          final answer = http.gates[1] = Completer<void>();
          final pages = lines('feed page').length;
          final coverLog = coverLines().length;
          final finger = await armed(tester);
          await settle(tester, 2);
          expect(http.asked, [1, 1], reason: 'the early call is out');
          await move(tester, finger, -16);
          expect(find.byType(LoadingTv), findsNothing, reason: 'the TV gone');
          if (answerFirst) {
            answer.complete();
            await settle(tester, 4);
          }
          await finger.up();
          if (!answerFirst) {
            await settle(tester, 4);
            answer.complete();
          }
          await settle(tester, 30);
          expect(card('BV1c0'), findsOneWidget, reason: 'the cards untouched');
          expect(card('BV1n0'), findsNothing);
          expect(going('BV1c0'), findsNothing, reason: 'no hand-off');
          expect(find.byType(LoadingTv), findsNothing, reason: 'no TV held');
          expect(http.asked, [1, 1]);
          expect(lines('feed page'), hasLength(pages));
          expect(coverLines(), hasLength(coverLog));
          final cancelled = lines('feed pull cancelled').single;
          expect(cancelled.f.keys, unorderedEquals(['answered', 'heldMs']));

          final again = await armed(tester);
          await settle(tester, 2);
          expect(http.asked, [1, 1], reason: 'the unseen answer is taken again');
          await again.up();
          await untilHandOff(tester);
          expect(card('BV1n0'), findsOneWidget);
          expect(http.asked, [1, 1]);
          await settle(tester, 30);
        });
      }

      testWidgets('wiggled across the trigger many times, it asks once', (tester) async {
        await shown(tester);
        final answer = http.gates[1] = Completer<void>();
        final finger = await armed(tester);
        bool playing() => tester.widget<LoadingTv>(find.byType(LoadingTv)).playing;
        for (var i = 0; i < 6; i++) {
          await move(tester, finger, -6);
          expect(playing(), isFalse, reason: 'under the trigger');
          await move(tester, finger, 6);
          expect(playing(), isTrue, reason: 'armed again');
        }
        answer.complete();
        await settle(tester, 2);
        for (var i = 0; i < 4; i++) {
          await move(tester, finger, -6);
          await move(tester, finger, 6);
        }
        expect(http.asked, [1, 1]);
        await finger.up();
        await untilHandOff(tester);
        expect(card('BV1n0'), findsOneWidget);
        expect(http.asked, [1, 1]);
        await settle(tester, 30);
      });

      testWidgets("首页's tap after a cancelled pull drops its unseen answer: the next pull asks again", (tester) async {
        await shown(tester);
        final finger = await armed(tester);
        await settle(tester, 2);
        await move(tester, finger, -16);
        await finger.up();
        await settle(tester, 20);
        expect(http.asked, [1, 1]);
        http.pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1t$i')];
        await tapHome(tester);
        await settle(tester, 30);
        expect(http.asked, [1, 1, 1], reason: 'the tap asks for itself');
        expect(card('BV1t0'), findsOneWidget);
        expect(card('BV1n0'), findsNothing, reason: 'the unseen answer never shows');
        final again = await armed(tester);
        await settle(tester, 2);
        expect(http.asked, [1, 1, 1, 1]);
        await again.up();
        await settle(tester, 30);
      });

      testWidgets('an account change while an answer is held drops it', (tester) async {
        await shown(tester);
        final finger = await armed(tester);
        await settle(tester, 2);
        await move(tester, finger, -16);
        await finger.up();
        await settle(tester, 20);
        http.pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1t$i')];
        http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
        await environment.refreshAccount();
        await settle(tester, 30);
        expect(http.asked, [1, 1, 1]);
        expect(card('BV1t0'), findsOneWidget);
        final again = await armed(tester);
        await settle(tester, 2);
        expect(http.asked, [1, 1, 1, 1], reason: "the old account's answer is not taken");
        await again.up();
        await settle(tester, 30);
      });
    });

    testWidgets("a refresh's cards make no entrance; the first load's still rise", (tester) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester, 2);
      expect(entrance('BV1c0'), findsOneWidget);
      await settle(tester, 20);
      http.pages[1] = fresh();
      await tapHome(tester);
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (card('BV1n0').evaluate().isNotEmpty) expect(entrance('BV1n0'), findsNothing);
      }
      expect(card('BV1n0'), findsOneWidget);
      expect(entrance('BV1n0'), findsNothing);
      expect(entrance('BV1n7'), findsNothing);
    });

    testWidgets('a tap mid-fade opens the new card, and only the new card is read out', (tester) async {
      final semantics = tester.ensureSemantics();
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      http.pages[1] = fresh();
      final answer = http.gates[1] = Completer<void>();
      await tapHome(tester);
      await settle(tester, 4);
      answer.complete();
      await untilHandOff(tester);
      await tester.pump(const Duration(milliseconds: 40));
      expect(going('BV1c0'), findsOneWidget);
      expect(find.semantics.byLabel('视频 BV1c0'), findsNothing);
      expect(find.semantics.byLabel('视频 BV1n0'), findsOne);
      await tester.tap(card('BV1n0'), warnIfMissed: false);
      await settle(tester, 20);
      expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.title, '视频 BV1n0');
      semantics.dispose();
    });

    testWidgets('a refresh restarted while the first is out drops the stale answer', (tester) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      http.pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1s$i')];
      final stale = http.gates[1] = Completer<void>();
      await tapHome(tester);
      await settle(tester, 3);
      expect(http.asked, [1, 1]);

      http.gates.remove(1);
      http.pages[1] = fresh();
      http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
      await environment.refreshAccount();
      await settle(tester, 20);
      expect(http.asked, [1, 1, 1], reason: 'the account changed: a new refresh');
      expect(card('BV1n0'), findsOneWidget);

      http.pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1s$i')];
      stale.complete();
      await settle(tester, 20);
      expect(card('BV1s0'), findsNothing, reason: 'the stale answer is dropped');
      expect(card('BV1n0'), findsOneWidget);
    });

    testWidgets('with Reduce Motion the new cards replace the old at once', (tester) async {
      http.pages[1] = twenty();
      await show(tester, still: true);
      await settle(tester);
      http.pages[1] = fresh();
      final answer = http.gates[1] = Completer<void>();
      await tapHome(tester);
      await settle(tester, 4);
      expect(reloadTv, findsOneWidget);
      answer.complete();
      for (var i = 0; i < 10 && card('BV1n0').evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(card('BV1n0'), findsOneWidget);
      expect(card('BV1c0'), findsNothing);
      expect(going('BV1c0'), findsNothing);
      await tester.pump();
      expect(reload, findsNothing);
      expect(find.byKey(const ValueKey('feed-skeleton')), findsNothing);
    });

    testWidgets('a refresh that lands while 首页 is out of sight swaps at once: nothing fades when 首页 comes back', (
      tester,
    ) async {
      http.pages[1] = twenty();
      await show(tester);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('home-tab-mine')));
      await settle(tester, 10);
      http.pages[1] = fresh();
      http.canned.routes[Canned.navPath] = (200, Canned.navLoggedOut);
      await environment.refreshAccount();
      await settle(tester, 10);
      expect(http.asked, [1, 1], reason: 'the account changed: a refresh, 首页 hidden');
      expect(find.byKey(const ValueKey('feed-card-BV1n0'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('feed-card-going-BV1c0'), skipOffstage: false), findsNothing);

      await tapHome(tester);
      await tester.pump();
      expect(card('BV1n0'), findsOneWidget);
      expect(going('BV1c0'), findsNothing);
      expect(slotOpacity(tester, 'BV1n0'), 1);
      await tester.pump(const Duration(milliseconds: 16));
      expect(going('BV1c0'), findsNothing);
      expect(slotOpacity(tester, 'BV1n0'), 1);
    });

    testWidgets('more new cards than old: the slots with no old card fade the new one in, then it stands at full '
        'opacity', (tester) async {
      http.pages[1] = [feedItem('BV1c0'), feedItem('BV1c1')];
      await show(tester);
      await settle(tester, 20);
      http.pages[1] = fresh();
      final answer = http.gates[1] = Completer<void>();
      await tapHome(tester);
      await settle(tester, 4);
      answer.complete();
      await untilHandOff(tester);
      await tester.pump(const Duration(milliseconds: 60));
      expect(going('BV1c1'), findsOneWidget);
      expect(slotOpacity(tester, 'BV1n0'), 1, reason: 'an old card fades out over it');
      expect(slotOpacity(tester, 'BV1n1'), 1);
      expect(slotOpacity(tester, 'BV1n2'), inExclusiveRange(0, 1), reason: 'no old card here: it fades in');
      expect(going('BV1n2'), findsNothing);
      await settle(tester, 10);
      expect(slotOpacity(tester, 'BV1n2'), 1);
      expect(going('BV1c0'), findsNothing);
      expect(find.byKey(const ValueKey('feed-skeleton')), findsNothing);
    });

    testWidgets("with the real precache the first screen's new covers are downloaded once, at the size their cards "
        'ask for', (tester) async {
      HomePage.precacheBigCover = FeedBigCardView.precacheCover;
      final picture = (await tester.runAsync(_coverPng))!;
      final folder = (await tester.runAsync(() => Directory.systemTemp.createTemp('feed_covers')))!;
      final downloads = <String, int>{};
      final cache = ImageDiskCache(
        folder: folder.path,
        fetch: (url, _) async {
          downloads.update('$url', (count) => count + 1, ifAbsent: () => 1);
          return picture;
        },
      );
      ImageDiskCache.shared = cache;
      addTearDown(() => ImageDiskCache.shared = null);
      int downloadsOf(String bvid) => [
        for (final MapEntry(:key, :value) in downloads.entries)
          if (key.contains('/$bvid.jpg')) value,
      ].fold(0, (sum, count) => sum + count);
      // The slot's own card comes first; the one fading out over it, second.
      bool drawn(String bvid) =>
          tester.widget<RawImage>(find.descendant(of: cover(bvid).first, matching: find.byType(RawImage)).first).image !=
          null;

      /// Frames, with real time between them for the disk and the decoder.
      Future<void> run(int rounds, {bool Function()? until}) async {
        for (var i = 0; i < rounds && !(until?.call() ?? false); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 5));
        }
      }

      http.pages[1] = twenty();
      await show(tester);
      await run(60, until: () => card('BV1c0').evaluate().isNotEmpty);
      expect(card('BV1c0'), findsOneWidget);
      await run(10);

      http.pages[1] = fresh();
      await tapHome(tester);
      await run(100, until: () => card('BV1n0').evaluate().isNotEmpty);
      expect(card('BV1n0'), findsOneWidget);
      final screen = firstScreen(tester);
      expect(screen, isNotEmpty);
      expect(coverLines().last.f['of']?.toJson(), screen.length);

      await run(20);
      await settle(tester, 10);
      for (final bvid in screen) {
        expect(drawn(bvid), isTrue, reason: '$bvid drawn once in');
      }
      for (final bvid in screen) {
        expect(downloadsOf(bvid), 1, reason: "$bvid: the card's own picture is the precached one");
      }
      expect(downloads.values.every((count) => count == 1), isTrue, reason: 'no address downloaded twice');
      final coverAddresses = [
        for (final url in downloads.keys)
          if (url.contains('/bfs/archive/')) url,
      ];
      expect(coverAddresses, isNotEmpty);
      // 211 × 158.25 pt at 1x, rounded up to whole pixels.
      expect(coverAddresses, everyElement(endsWith('.jpg@408w_230h_1c_90q.jpg')), reason: "the cover box's size");
      Iterable<Image> images(String bvid) =>
          tester.widgetList<Image>(find.descendant(of: cover(bvid).first, matching: find.byType(Image)));
      final boxes = {
        for (final bvid in screen)
          for (final image in images(bvid))
            if (image.image case StoredNetworkImage(:final box?)) box,
      };
      expect(boxes, {const Size(408, 230)}, reason: "decoded for the cover box's own size");
      // The store's steps wait on frames as well as on the disk.
      var stored = false;
      unawaited(cache.settle().then((_) => stored = true));
      await run(50, until: () => stored);
      await tester.runAsync(() => folder.delete(recursive: true));
    });

    testWidgets("a cover still loading shows the official placeholder under the picture", (tester) async {
      await show(tester);
      await tester.pump();
      await tester.pump();
      await settle(tester, 2);
      final placeholder = find.descendant(of: cover('BV1aaa'), matching: find.byType(CoverPlaceholder));
      expect(placeholder, findsOneWidget);
      final stack = tester.widget<Stack>(find.descendant(of: cover('BV1aaa'), matching: find.byType(Stack)).first);
      expect(stack.children.first, isA<CoverPlaceholder>(), reason: 'under the picture');
      expect(tester.getRect(placeholder), tester.getRect(cover('BV1aaa')), reason: 'filling the cover');
    });
  });
}

/// The title the video page's title block shows; null before the video's detail arrives.
String? shownTitle(WidgetTester tester) {
  final blocks = find.byType(TitleBlock, skipOffstage: false);
  return blocks.evaluate().isEmpty ? null : tester.widget<TitleBlock>(blocks.first).detail.title;
}

/// The face the one loading TV on screen shows.
int tvFace(WidgetTester tester) {
  for (var face = 0; face < LoadingTv.frames.length; face++) {
    if (find.byKey(ValueKey('loading-tv-$face')).evaluate().isNotEmpty) return face;
  }
  fail('no loading TV');
}
