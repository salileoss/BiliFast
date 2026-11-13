import 'dart:async';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/home_tab_bar.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/loading_tv.dart';
import 'package:bilifast/video/video_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import 'fake_login_gate.dart';
import '../video/mixed_lines.dart' show appTheme;
import 'feed_fakes.dart';

/// The shell's two lists and their pulls: 首页's 推荐 and 我的, both kept alive.
void main() {
  late FeedHttp http;
  late FakeMeApi me;

  setUp(() {
    // These follow the swap from the answer, as when it comes after FeedModel.minimumRefresh.
    HomePage.feedMinimumRefresh = Duration.zero;
    addTearDown(() => HomePage.feedMinimumRefresh = FeedModel.minimumRefresh);
    http = FeedHttp()..pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1c$i')];
    me = FakeMeApi.demo();
  });

  Future<void> show(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(440, 956)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 62, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    final logger = Logger(session: 'test');
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(StoredCookies(Canned.cookies)),
      http: http,
      logger: logger,
    );
    await environment.refreshAccount();
    final playback = AppPlayback(() => throw StateError('no playback here'));
    addTearDown(playback.dispose);
    final services = AppServices(
      environment: environment,
      playback: playback,
      recents: await RecentStore.load(null, logger: logger),
      fonts: FontStore.memory(),
      searchApi: FakeSearchApi(defaultWord: 'w'),
      meApi: me,
      loginGate: FakeLoginGate(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => AppScope(services: services, child: child!),
        home: const MainShell(),
      ),
    );
  }

  Future<void> settle(WidgetTester tester, [int frames = 10]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapTab(WidgetTester tester, HomeTab tab) async {
    await tester.tap(find.byKey(ValueKey('home-tab-${tab.name}')));
    await tester.pump();
  }

  /// Past the trigger at about 1500 px/s, held.
  Future<TestGesture> pullAndHold(WidgetTester tester, Finder list) async {
    final finger = await tester.startGesture(tester.getCenter(list));
    for (var i = 0; i < 12; i++) {
      await finger.moveBy(const Offset(0, 25));
      await tester.pump(const Duration(microseconds: 16667));
    }
    return finger;
  }

  final feed = find.byKey(const ValueKey('feed'));
  final meList = find.byKey(const ValueKey('me-list'));

  ScrollPosition feedScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('feed'), skipOffstage: false),
              matching: find.byType(Scrollable, skipOffstage: false),
              skipOffstage: false,
            )
            .first,
      )
      .position;

  testWidgets('首页: held past the trigger asks for 推荐 at once but shows it only when the finger lifts', (tester) async {
    await show(tester);
    await settle(tester, 40);
    final asked = List.of(http.asked);
    http.pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1n$i')];
    final finger = await pullAndHold(tester, feed);
    await settle(tester, 20);
    expect(tester.widget<LoadingTv>(find.byType(LoadingTv)).playing, isTrue, reason: 'armed');
    expect(http.asked, [...asked, 1], reason: 'asked as it armed');
    expect(find.byKey(const ValueKey('feed-card-BV1c0')), findsOneWidget, reason: 'held for 1 s: nothing shown');
    await finger.up();
    await settle(tester, 30);
    expect(http.asked, [...asked, 1], reason: 'the release took that answer');
    expect(find.byKey(const ValueKey('feed-card-BV1n0')), findsOneWidget);
    expect(find.byType(LoadingTv), findsNothing);
  });

  testWidgets('both lists mounted: a pull on one refreshes only its own', (tester) async {
    await show(tester);
    await settle(tester, 40);
    await tapTab(tester, HomeTab.mine);
    await settle(tester, 20);
    expect(me.calls, unorderedEquals(['nav', 'stat']));
    await tapTab(tester, HomeTab.home);
    await settle(tester, 20);

    final asked = List.of(http.asked);
    var finger = await pullAndHold(tester, feed);
    await finger.up();
    await settle(tester, 30);
    expect(http.asked, [...asked, 1, 2],
        reason: '首页 refreshed once, with lookahead for repeated visible videos');
    expect(me.calls, hasLength(2), reason: 'hidden 我的 not refreshed by 首页 pull');

    await tapTab(tester, HomeTab.mine);
    await settle(tester, 20);
    final meAsked = me.calls.length;
    final feedAsked = List.of(http.asked);
    finger = await pullAndHold(tester, meList);
    await settle(tester, 10);
    expect(me.calls.length, meAsked, reason: 'held');
    await finger.up();
    await settle(tester, 30);
    expect(me.calls.length, meAsked + 2, reason: '我的 refreshed (nav, stat)');
    expect(http.asked, feedAsked, reason: 'hidden 首页 not refreshed by 我的 pull');
    expect(find.byType(LoadingTv, skipOffstage: false), findsNothing, reason: 'no TV left on either list');
  });

  testWidgets('推荐 left bouncing past the trigger under 我的 never refreshes from a touch on 我的', (tester) async {
    await show(tester);
    await settle(tester, 40);
    await tapTab(tester, HomeTab.mine);
    await settle(tester, 20);
    await tapTab(tester, HomeTab.home);
    await settle(tester, 20);
    final asked = List.of(http.asked);

    feedScroll(tester).jumpTo(-150);
    await tester.pump();
    await tapTab(tester, HomeTab.mine);
    await settle(tester, 4);
    final frozen = -feedScroll(tester).pixels;
    expect(frozen, greaterThan(100), reason: "hidden, 首页's bounce holds still past the trigger");

    final finger = await tester.startGesture(tester.getCenter(meList));
    await settle(tester, 4);
    await finger.up();
    await settle(tester, 20);
    expect(http.asked, asked, reason: 'a touch on 我的 is not a finger on 推荐');

    await tapTab(tester, HomeTab.home);
    await settle(tester, 30);
    expect(feedScroll(tester).pixels, 0);
    expect(http.asked, asked, reason: 'shown again, 推荐 settles without refreshing');
  });

  testWidgets('首页 tapped during a pull refresh asks nothing more and shows one TV', (tester) async {
    await show(tester);
    await settle(tester, 40);
    final asked = List.of(http.asked);
    http.gates[1] = Completer<void>();
    final finger = await pullAndHold(tester, feed);
    await finger.up();
    await settle(tester, 10);
    expect(http.asked, [...asked, 1]);
    await tapTab(tester, HomeTab.home);
    await settle(tester, 20);
    expect(http.asked, [...asked, 1], reason: 'the tap joins the pull');
    expect(find.byType(LoadingTv), findsOneWidget, reason: 'one TV');
    http.gates[1]!.complete();
    await settle(tester, 40);
    expect(find.byType(LoadingTv), findsNothing);
  });

  testWidgets('a pull during a 首页-tap refresh asks nothing more and shows one TV', (tester) async {
    await show(tester);
    await settle(tester, 40);
    final asked = List.of(http.asked);
    http.gates[1] = Completer<void>();
    await tapTab(tester, HomeTab.home);
    await settle(tester, 10);
    expect(find.byKey(const ValueKey('feed-reload')), findsOneWidget);
    final finger = await pullAndHold(tester, feed);
    expect(find.byType(LoadingTv), findsOneWidget, reason: 'held: one TV');
    await finger.up();
    await settle(tester, 10);
    expect(http.asked, [...asked, 1]);
    expect(find.byType(LoadingTv), findsOneWidget, reason: 'released: one TV');
    http.gates[1]!.complete();
    await settle(tester, 40);
    expect(find.byType(LoadingTv), findsNothing);
  });

  group('Hero flights', () {
    /// Pushes a page holding a cover Hero with the first 推荐 card's tag and reports whether a flight drew it.
    Future<bool> flies(WidgetTester tester) async {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => Align(
              alignment: Alignment.bottomCenter,
              child: Hero(
                tag: VideoRoute.coverTag('BV1c0'),
                flightShuttleBuilder: (_, _, _, _, _) => const SizedBox(key: ValueKey('shuttle')),
                child: const SizedBox(width: 100, height: 60),
              ),
            ),
          ),
        ),
      );
      var flew = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        flew = flew || find.byKey(const ValueKey('shuttle')).evaluate().isNotEmpty;
      }
      navigator.pop();
      await settle(tester, 20);
      return flew;
    }

    testWidgets("the hidden 首页's covers stay out of a page pushed over 我的", (tester) async {
      await show(tester);
      await settle(tester, 40);
      expect(await flies(tester), isTrue, reason: 'from 首页 showing, the cover flies');
      await tapTab(tester, HomeTab.mine);
      await settle(tester, 20);
      expect(await flies(tester), isFalse, reason: 'from 我的, hidden 首页 has no part in it');
    });

    testWidgets('the hidden page is out of flights both ways', (tester) async {
      await show(tester);
      await settle(tester, 40);
      bool flying(String list) => tester
          .widget<HeroMode>(
            find
                .ancestor(
                  of: find.byKey(ValueKey(list), skipOffstage: false),
                  matching: find.byType(HeroMode, skipOffstage: false),
                )
                .first,
          )
          .enabled;
      await tapTab(tester, HomeTab.mine);
      await settle(tester, 20);
      expect((flying('feed'), flying('me-list')), (false, true), reason: '我的 shown');
      await tapTab(tester, HomeTab.home);
      await settle(tester, 20);
      expect((flying('feed'), flying('me-list')), (true, false), reason: '首页 shown');
    });
  });
}
