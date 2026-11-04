import 'dart:async';
import 'dart:io';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/feed_card.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/home_tab_bar.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/home/tab_bar_icons.dart';
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/me/me_page.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/loading_tv.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';
import '../video/mixed_lines.dart';
import 'fake_login_gate.dart';
import 'feed_fakes.dart';

const _screen = ValueKey('screen');

void main() {
  late FeedHttp http;

  setUp(() {
    http = FeedHttp()..pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1c$i')];
  });

  /// The shell at 440×956 over a 34 pt home indicator; [phone] makes it KaiC's iPhone at 3× under the system font.
  Future<AppEnvironment> show(WidgetTester tester, {bool phone = false}) async {
    if (phone) {
      final saved = BiliFonts.family;
      addTearDown(() => BiliFonts.family = saved);
      await tester.runAsync(loadSystemFontStandIns);
      showAsPhone(tester);
    } else {
      tester.view
        ..physicalSize = const Size(440, 956)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(bottom: 34)
        ..viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
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
      searchApi: FakeSearchApi(defaultWord: '崩铁新版本即将上线'),
      meApi: FakeMeApi.demo(),
      loginGate: FakeLoginGate(),
    );
    if (phone) BiliFonts.family = BiliFonts.system;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => RepaintBoundary(
          key: _screen,
          child: AppScope(services: services, child: child!),
        ),
        home: MainShell(developerPage: (context) => const Text('开发者页面')),
      ),
    );
    return environment;
  }

  /// Lets requests answer and frames run without waiting on the loading cards' endless sweep.
  Future<void> settle(WidgetTester tester, [int frames = 10]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder slot(HomeTab tab) => find.byKey(ValueKey('home-tab-${tab.name}'));

  Future<void> tapTab(WidgetTester tester, HomeTab tab) async {
    await tester.tap(slot(tab));
    await tester.pump();
  }

  ScrollPosition feedScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: find.byKey(const ValueKey('feed')), matching: find.byType(Scrollable)).first,
      )
      .position;

  bool meActive(WidgetTester tester) => tester.widget<MePage>(find.byType(MePage, skipOffstage: false)).active;

  testWidgets('switching between logged-in accounts resets root pages and selects 我的', (tester) async {
    final environment = await show(tester);
    await settle(tester);
    final oldHome = tester.state(find.byType(HomePage, skipOffstage: false));
    environment.useFakeAccount();
    await environment.switchAccount(2);
    await settle(tester);
    expect(environment.activeAccountMid, 2);
    expect(meActive(tester), isTrue);
    expect(tester.state(find.byType(HomePage, skipOffstage: false)), isNot(same(oldHome)));
    final services = AppScope.of(tester.element(find.byType(MainShell)));
    await tester.pumpWidget(const SizedBox.shrink());
    services.dispose();
    environment.dispose();
    await tester.pump();
  });

  void expectSelected(WidgetTester tester, HomeTab selected) {
    for (final tab in HomeTab.values) {
      final on = tab == selected;
      expect(
        tester.getSemantics(slot(tab)),
        isSemantics(label: tab.label, isButton: true, hasTapAction: true, hasSelectedState: true, isSelected: on),
      );
      final icon = find.descendant(of: slot(tab), matching: find.byType(HomeTabIcon));
      expect(tester.widget<HomeTabIcon>(icon).selected, on, reason: tab.label);
      if (tab == HomeTab.post) continue;
      final glyph = tester.widget<CustomPaint>(find.descendant(of: icon, matching: find.byType(CustomPaint)));
      final painter = glyph.painter! as HomeTabGlyphPainter;
      expect(painter.selected, on, reason: tab.label);
      expect(painter.color, on ? TabIconTheme.selectedInk : TabIconTheme.ink, reason: tab.label);
      final label = tester.widget<Text>(find.descendant(of: slot(tab), matching: find.text(tab.label)));
      expect(label.style?.color, on ? HomeTabBarTheme.selected : HomeTabBarTheme.label, reason: tab.label);
    }
  }

  testWidgets('five slots across the bottom over the home indicator, 首页 selected, the pages ending at the bar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    await settle(tester);
    final bar = tester.getRect(find.byType(HomeTabBar));
    expect(bar.bottom, 956);
    expect(bar.height, HomeTabBarTheme.height + 34);
    expect(tester.getRect(find.byKey(const ValueKey('feed'))).bottom, bar.top);
    for (final (i, tab) in HomeTab.values.indexed) {
      expect(tester.getRect(slot(tab)), Rect.fromLTWH(88.0 * i, bar.top, 88, HomeTabBarTheme.height));
      if (tab == HomeTab.post) {
        expect(find.text(tab.label), findsNothing, reason: 'the + has no label');
        continue;
      }
      final label = find.text(tab.label);
      expect(tester.getCenter(label).dx, 44 + 88.0 * i);
      expect(tester.getTopLeft(label).dy, greaterThan(bar.top + 30));
    }
    expectSelected(tester, HomeTab.home);

    await tapTab(tester, HomeTab.mine);
    await settle(tester);
    expectSelected(tester, HomeTab.mine);
    expect(tester.getRect(find.byType(MePage)), Rect.fromLTRB(0, 0, 440, bar.top));
    expect(
      MediaQuery.paddingOf(tester.element(find.byType(MePage))).bottom,
      0,
      reason: 'the bar takes the home indicator',
    );
    semantics.dispose();
  });

  testWidgets('switching keeps both pages alive: 推荐 comes back where it was, with its cards, unrefreshed', (
    tester,
  ) async {
    await show(tester);
    await settle(tester);
    final home = tester.state(find.byType(HomePage));
    final me = tester.state(find.byType(MePage, skipOffstage: false));
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -1500));
    await settle(tester, 20);
    final at = feedScroll(tester).pixels;
    expect(at, greaterThan(1000));
    final asked = List.of(http.asked);
    Set<String> cards() => {
      for (final card in find.byWidgetPredicate((widget) => widget.key is ValueKey<String>).evaluate())
        if ((card.widget.key! as ValueKey<String>).value case final key when key.startsWith('feed-card-BV')) key,
    };
    final shown = cards();
    expect(shown, isNotEmpty);

    await tapTab(tester, HomeTab.mine);
    await settle(tester);
    expect(find.byType(HomePage), findsNothing, reason: 'offstage');
    expect(find.byType(MePage), findsOneWidget);
    await tapTab(tester, HomeTab.home);
    await settle(tester, 20);

    expect(tester.state(find.byType(HomePage)), same(home));
    expect(tester.state(find.byType(MePage, skipOffstage: false)), same(me));
    expect(feedScroll(tester).pixels, at);
    expect(cards(), shown);
    expect(find.byKey(const ValueKey('feed-reload')), findsNothing);
    expect(http.asked, asked, reason: 'no refresh');
  });

  testWidgets('首页 on 首页 refreshes 推荐; 首页 from 我的 only shows it again', (tester) async {
    await show(tester);
    await settle(tester, 40);
    final asked = List.of(http.asked);

    await tapTab(tester, HomeTab.mine);
    await settle(tester);
    await tapTab(tester, HomeTab.home);
    await settle(tester, 20);
    expect(http.asked, asked);

    await tapTab(tester, HomeTab.home);
    await settle(tester, 20);
    expect(http.asked, [...asked, 1]);
    await settle(tester, 40);
  });

  testWidgets("MePage is active only while 我的 is the tab; 我的 again changes nothing; the status bar stays dark", (
    tester,
  ) async {
    await show(tester);
    await settle(tester);
    expect(meActive(tester), isFalse);
    expect(tester.widget<MePage>(find.byType(MePage, skipOffstage: false)).developerPage, isNotNull);

    await tapTab(tester, HomeTab.mine);
    await settle(tester);
    expect(meActive(tester), isTrue);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    final me = tester.state(find.byType(MePage));

    await tapTab(tester, HomeTab.mine);
    await settle(tester);
    expect(meActive(tester), isTrue);
    expect(tester.state(find.byType(MePage)), same(me));
    expect(find.byType(HomePage), findsNothing);
    expectSelected(tester, HomeTab.mine);

    await tapTab(tester, HomeTab.home);
    await settle(tester);
    expect(meActive(tester), isFalse);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('+ and 消息 say 暂未开放 and change nothing, from either tab', (tester) async {
    await show(tester);
    await settle(tester, 40);
    final asked = List.of(http.asked);
    for (final from in [HomeTab.home, HomeTab.mine]) {
      if (from == HomeTab.mine) {
        await tapTab(tester, from);
        await settle(tester, 20);
      }
      for (final tab in [HomeTab.post, HomeTab.messages]) {
        await tapTab(tester, tab);
        expect(find.text('暂未开放'), findsOneWidget, reason: tab.label);
        await settle(tester, 60);
        expectSelected(tester, from);
        expect(meActive(tester), from == HomeTab.mine);
      }
    }
    expect(http.asked, asked, reason: 'no refresh');
  });

  testWidgets('hidden 首页 ticks nothing: the loading cards stop sweeping, the refresh TV holds its face', (
    tester,
  ) async {
    http.gates[1] = Completer<void>();
    await show(tester);
    await settle(tester, 2);
    String? sweep() => tester
        .state(find.byType(Shimmer, skipOffstage: false).first)
        .toDiagnosticsNode()
        .getProperties()
        .firstWhere((property) => property.name == 'ticker')
        .toDescription();
    bool homeTicks() => TickerMode.valuesOf(tester.element(find.byType(Shimmer, skipOffstage: false).first)).enabled;
    expect(sweep(), 'active');
    expect(homeTicks(), isTrue);

    await tapTab(tester, HomeTab.mine);
    await settle(tester);
    expect(homeTicks(), isFalse);
    expect(sweep(), 'active but muted');
    expect(TickerMode.valuesOf(tester.element(find.byType(MePage))).enabled, isTrue);
    expect(tester.binding.transientCallbackCount, 0, reason: '首页 asks for no frames while hidden');

    await tapTab(tester, HomeTab.home);
    await tester.pump();
    expect(homeTicks(), isTrue);
    expect(sweep(), 'active');
    http.gates[1]!.complete();
    await settle(tester, 40);

    int face() {
      for (var face = 0; face < LoadingTv.frames.length; face++) {
        if (find.byKey(ValueKey('loading-tv-$face'), skipOffstage: false).evaluate().isNotEmpty) return face;
      }
      fail('no loading TV');
    }

    http.gates[1] = Completer<void>();
    await tapTab(tester, HomeTab.home);
    await settle(tester, 10);
    final cycling = face();
    await tester.pump(LoadingTvTheme.frame);
    expect(face(), isNot(cycling), reason: 'cycling while shown');

    await tapTab(tester, HomeTab.mine);
    final held = face();
    for (var i = 0; i < 4; i++) {
      await tester.pump(LoadingTvTheme.frame);
      expect(face(), held, reason: 'held while hidden');
    }
    await tapTab(tester, HomeTab.home);
    await tester.pump(LoadingTvTheme.frame);
    await tester.pump(LoadingTvTheme.frame);
    expect(face(), isNot(held), reason: 'cycling again once shown');
    http.gates[1]!.complete();
    await settle(tester, 40);
  });

  /// The bar as KaiC's iPhone draws it under the system font, against 01 (首页 selected) and 02 (我的 selected). With
  /// BILIFAST_SHOTS naming a folder outside the repo, the 3× shots are saved there for tools/screen_diff.py.
  for (final (selected, shot) in [(HomeTab.home, '01'), (HomeTab.mine, '02')]) {
    testWidgets('under the system font, the bar with ${selected.label} selected where $shot has it', (tester) async {
      await show(tester, phone: true);
      await settle(tester, 40);
      if (selected == HomeTab.mine) {
        await tapTab(tester, HomeTab.mine);
        await settle(tester, 20);
      }
      expectSelected(tester, selected);
      final bar = tester.getRect(find.byType(HomeTabBar));
      expect(bar.top, 873);
      expect(bar.bottom, 956);
      for (final (i, tab) in HomeTab.values.indexed) {
        final icon = tester.getCenter(find.descendant(of: slot(tab), matching: find.byType(HomeTabIcon)));
        expect(icon.dx, 44 + 88.0 * i, reason: tab.label);
        expect(icon.dy, moreOrLessEquals(tab == HomeTab.post ? 897.67 : 891, epsilon: 0.01), reason: tab.label);
      }

      final shots = Platform.environment['BILIFAST_SHOTS'];
      if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/$shot-bar-ours.png');
    });
  }
}
