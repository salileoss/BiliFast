import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/dynamic/follow_tab/follow_tab_page.dart';
import 'package:bilifast/home/feed_big_card.dart';
import 'package:bilifast/home/feed_card.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/home_tab_bar.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import '../support/look_alike.dart';
import '../video/mixed_lines.dart';
import 'fake_login_gate.dart';
import 'feed_fakes.dart';

/// 首页 on the iPad beside the phone: three columns against two, the iPad's bar and top, a big card drawn small.
void main() {
  late FeedHttp http;

  setUp(() {
    http = FeedHttp()..pages[1] = [for (var i = 0; i < 12; i++) feedItem('BV1p$i')];
  });

  Future<void> show(WidgetTester tester, {required bool pad, bool landscape = false}) async {
    if (pad) {
      showAsPad(tester, landscape: landscape);
    } else {
      showAsPhone(tester);
    }
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
      fonts: FontStore.memory()..select(FontChoice.system),
      searchApi: FakeSearchApi(defaultWord: '搜索词'),
      meApi: FakeMeApi.demo(),
      loginGate: FakeLoginGate(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => AppScope(services: services, child: child!),
        home: const MainShell(),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  double left(WidgetTester tester, String bvid) => tester.getTopLeft(find.byKey(ValueKey('feed-card-$bvid'))).dx;

  testWidgets('the iPad lays 推荐 out three to a row, the phone two', (tester) async {
    await show(tester, pad: true, landscape: true);
    expect(left(tester, 'BV1p3'), left(tester, 'BV1p0'), reason: 'the fourth card starts the second row');
    expect(left(tester, 'BV1p2'), greaterThan(left(tester, 'BV1p1')));
    await tester.pumpWidget(const SizedBox());

    await show(tester, pad: false);
    expect(left(tester, 'BV1p2'), left(tester, 'BV1p0'), reason: 'the third card starts the second row');
    expect(find.byKey(const ValueKey('feed-card-face')), findsNothing, reason: "the phone's card is unchanged");
  });

  testWidgets('the iPad remembers visible cards but not cached cards or a hidden tab', (tester) async {
    await show(tester, pad: true, landscape: true);
    final services = AppScope.of(tester.element(find.byType(HomePage)));
    final owner = services.feedAccountMid;
    expect(services.feedPreferences.recentlySeen('BV1p0', accountMid: owner), isTrue);
    expect(services.feedPreferences.recentlySeen('BV1p11', accountMid: owner), isFalse,
        reason: 'building an offscreen grid row is not an exposure');
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -900));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-tab-mine')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(services.feedPreferences.recentlySeen('BV1p11', accountMid: owner), isFalse,
        reason: 'switching tabs cancels the visibility wait');
  });

  testWidgets('old iPad cards do not count for a new owner while replacement is delayed', (tester) async {
    await show(tester, pad: true, landscape: true);
    final services = AppScope.of(tester.element(find.byType(HomePage)));
    final previousOwner = services.feedAccountMid;
    expect(services.feedPreferences.recentlySeen('BV1p0', accountMid: previousOwner), isTrue);
    http.canned.routes['/x/frontend/finger/spi'] =
        (200, '{"code":0,"data":{"b_3":"b3","b_4":"b4"}}');
    http.gates[1] = Completer<void>();
    await services.environment.logout();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(services.feedAccountMid, isNull);
    expect(services.feedPreferences.recentlySeen('BV1p0', accountMid: null), isFalse,
        reason: 'the previous account cards are still drawn but no longer belong to the active identity');
    http.gates[1]!.complete();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(services.feedPreferences.recentlySeen('BV1p0', accountMid: null), isTrue,
        reason: 'the same video can count after its new-owner response is accepted');
  });

  testWidgets("the iPad's bar: 首页 分区 动态 我的; 动态 is the 关注 place and 分区 says 暂未开放", (tester) async {
    await show(tester, pad: true);
    expect(find.byKey(ValueKey('home-tab-${HomeTab.post.name}')), findsNothing);
    expect(find.byKey(ValueKey('home-tab-${HomeTab.messages.name}')), findsNothing);
    for (final tab in PadTab.values) {
      expect(find.byKey(ValueKey('home-tab-${tab.key}')), findsOneWidget, reason: tab.label);
      expect(find.text(tab.label), findsOneWidget);
    }
    final asked = List.of(http.asked);

    await tester.tap(find.byKey(const ValueKey('home-tab-partition')));
    await tester.pump();
    expect(find.text('暂未开放'), findsOneWidget);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(http.asked, asked, reason: '分区 changes nothing');

    await tester.tap(find.byKey(const ValueKey('home-tab-follow')));
    await tester.pump();
    final follow = tester.widget<FollowTabPage>(find.byType(FollowTabPage));
    expect(follow.active, isTrue);
  });

  testWidgets("the iPad's top: all five tabs, scan and 消息 say 暂未开放, the other tabs answer nothing", (tester) async {
    await show(tester, pad: true);
    for (final tab in ['直播', '推荐', '热门', '追番', '影视']) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
    await tester.tap(find.byKey(const ValueKey('home-pad-tab-热门')));
    await tester.pump();
    expect(find.text('暂未开放'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-scan')));
    await tester.pump();
    expect(find.text('暂未开放'), findsOneWidget);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byKey(const ValueKey('home-messages')));
    await tester.pump();
    expect(find.text('暂未开放'), findsOneWidget);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const ValueKey('home-history')), findsOneWidget);
  });

  testWidgets('a big card that reaches the iPad is drawn as an ordinary card', (tester) async {
    HomePage.feedPages = (index) async => index == 1 ? [bigCard('BV1big'), ...smalls('s', 5)] : const [];
    addTearDown(() => HomePage.feedPages = null);
    await show(tester, pad: true, landscape: true);
    expect(find.byType(FeedBigCardView), findsNothing);
    expect(find.byType(FeedCardView), findsNWidgets(6));
    expect(left(tester, 'BV1s2'), left(tester, 'BV1big'), reason: 'it takes one slot of three');
  });

  group('the date under an iPad card', () {
    final now = DateTime(2026, 10, 29, 18);
    int ago(Duration d) => now.subtract(d).millisecondsSinceEpoch ~/ 1000;

    test('as 02 writes it: 昨天 HH:mm, N天前 two and three days back, then M月D日', () {
      expect(FeedCardView.padDate(ago(const Duration(hours: 3)), now: now), '3小时前');
      expect(FeedCardView.padDate(DateTime(2026, 10, 28, 12, 40).millisecondsSinceEpoch ~/ 1000, now: now), '昨天 12:40');
      expect(FeedCardView.padDate(DateTime(2026, 10, 26, 9).millisecondsSinceEpoch ~/ 1000, now: now), '3天前');
      expect(FeedCardView.padDate(DateTime(2026, 10, 24, 9).millisecondsSinceEpoch ~/ 1000, now: now), '10月24日');
    });

    test('the uploader alone when the card has no date (the official feed)', () {
      expect(FeedCardView.padByline(smallCard('BV1x'), now: now), 'UP BV1x');
      final dated = FeedCard.fromJson({
        ...feedItem('BV1y'),
        'pubdate': DateTime(2026, 10, 23, 9).millisecondsSinceEpoch ~/ 1000,
      });
      expect(FeedCardView.padByline(dated, now: now), 'UP BV1y · 10月23日');
    });
  });
}
