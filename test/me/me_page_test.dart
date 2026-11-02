import 'dart:async';

import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/favourites/favourites_page.dart';
import 'package:bilifast/history/watch_history_page.dart';
import 'package:bilifast/home/shortcut_glyphs.dart';
import 'package:bilifast/me/me_header.dart';
import 'package:bilifast/me/me_model.dart';
import 'package:bilifast/me/me_page.dart';
import 'package:bilifast/offline/pages/offline_list_page.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/settings/settings_page.dart';
import 'package:bilifast/shared/loading_tv.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/space/space_page.dart';
import 'package:bilifast/watch_later/watch_later_page.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/fake_login_gate.dart';
import '../video/mixed_lines.dart';
import 'me_page_support.dart';

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Lets a toast run out, so no timer outlives the test.
Future<void> _toastGone(WidgetTester tester) => _settle(tester, 60);

Finder _key(String key) => find.byKey(ValueKey(key));

const _plain = MeProfile(mid: 7, name: '普通用户', face: '', level: 3, coins: 12.5, bcoin: 0);

/// The 会员 centre handed to the official app's own browser.
final _inApp = Uri.parse('bilibili://browser?url=https%3A%2F%2Fbig.bilibili.com%2Fmobile%2Fhome');

/// The card's opacity as drawn now.
double _cardOpacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.ancestor(of: _key('me-vip-card'), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;

/// The style a Text is laid out with, the inherited one merged in.
TextStyle? _laidOut(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style;

void main() {
  testWidgets("a 大会员 reads as 87: the pink name, the pill, B币 and 硬币, the counts and the 会员 card", (tester) async {
    await showMe(tester);
    expect(find.text('KaiC5504'), findsOneWidget);
    expect(tester.widget<Text>(find.text('KaiC5504')).style?.color, MeTheme.vipName);
    expect(find.text('年度大会员'), findsOneWidget);
    expect(find.text('B币：2.3'), findsOneWidget);
    expect(find.text('硬币：878'), findsOneWidget);
    expect(find.bySemanticsLabel('LV5'), findsOneWidget);
    for (final (label, count) in [('动态', '0'), ('关注', '13'), ('粉丝', '0')]) {
      expect(find.text(label), findsOneWidget);
      expect(tester.getSemantics(_key('me-${_counts[label]}')).label, '$label $count');
    }
    expect(_key('me-vip-card'), findsOneWidget);
    expect(_key('me-vip-badge'), findsOneWidget);
    expect(_key('me-pendant'), findsOneWidget);
    expect(find.text('续订会员'), findsOneWidget);
    expect(find.text('更多独家内容'), findsOneWidget);
    expect(find.text('会员中心'), findsOneWidget);
    expect(tester.getRect(_key('me-vip-card')), const Rect.fromLTRB(12, 266, 428, 320));
  });

  testWidgets(
    'without 大会员 the name is plain, and no pill, badge, frame or card; the list starts where the card would',
    (tester) async {
      await showMe(tester, view: const MeShown(_plain, kaiCounts));
      expect(tester.widget<Text>(find.text('普通用户')).style?.color, MeTheme.name);
      expect(find.text('B币：0'), findsOneWidget);
      expect(find.text('硬币：12.5'), findsOneWidget);
      for (final key in ['me-vip-card', 'me-vip-label', 'me-vip-badge', 'me-pendant']) {
        expect(_key(key), findsNothing, reason: key);
      }
      expect(tester.getTopLeft(_key('me-list')).dy, 274, reason: 'cut 8 under the counts');
    },
  );

  test('B币 and 硬币 drop a whole number\'s .0 and keep halves', () {
    expect(MeHeader.amount(878), '878');
    expect(MeHeader.amount(2.3), '2.3');
    expect(MeHeader.amount(878.5), '878.5');
    expect(MeHeader.amount(0.1 + 0.2), '0.3');
    expect(MeHeader.amount(2.999), '3');
  });

  testWidgets('counts past ten thousand read as 万', (tester) async {
    await showMe(tester, view: const MeShown(kaiProfile, MeCounts(dynamics: 3, following: 120, followers: 23456)));
    expect(find.text('2.3万'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
  });

  testWidgets('with no mid, the avatar and 空间 › open nothing', (tester) async {
    const noMid = MeProfile(name: '无号', face: '', level: 1, coins: 0, bcoin: 0);
    await showMe(tester, view: const MeShown(noMid, kaiCounts));
    await tester.tap(_key('me-avatar'));
    await _settle(tester);
    await tester.tap(_key('me-space'));
    await _settle(tester);
    expect(find.byType(SpacePage), findsNothing);
  });

  testWidgets('the avatar and 空间 › open the account\'s own space; the name opens nothing', (tester) async {
    await showMe(tester);
    await tester.tap(_key('me-name'));
    await _settle(tester);
    expect(find.byType(SpacePage), findsNothing);
    expect(find.text('即将推出'), findsNothing);

    await tester.tap(_key('me-avatar'));
    await _settle(tester);
    final space = tester.widget<SpacePage>(find.byType(SpacePage));
    expect(space.uploader.mid, 2233);
    expect(space.uploader.name, 'KaiC5504');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await _settle(tester);
    expect(find.byType(SpacePage), findsNothing);

    await tester.tap(_key('me-space'));
    await _settle(tester);
    expect(tester.widget<SpacePage>(find.byType(SpacePage)).uploader.mid, 2233);
  });

  for (final key in [
    'me-cast',
    'me-scan',
    'me-outfit',
    'me-edit',
    'me-dynamics',
    'me-following',
    'me-followers',
    'me-support',
    'me-listen',
  ]) {
    testWidgets('$key says 即将推出', (tester) async {
      await showMe(tester);
      await tester.tap(_key(key));
      await tester.pump();
      expect(find.text('即将推出'), findsOneWidget);
      await _toastGone(tester);
    });
  }

  for (final (key, page) in [
    ('me-offline', OfflineListPage),
    ('me-history', WatchHistoryPage),
    ('me-favourites', FavouritesPage),
    ('me-later', WatchLaterPage),
  ]) {
    testWidgets('$key opens $page', (tester) async {
      await showMe(tester);
      await tester.tap(_key(key));
      await _settle(tester);
      expect(find.byType(page), findsOneWidget);
    });
  }

  testWidgets('设置 opens 设置 with the developer page passed on', (tester) async {
    Widget developer(BuildContext context) => const SizedBox();
    await showMe(tester, developerPage: developer);
    await tester.tap(_key('me-settings'));
    await _settle(tester);
    expect(tester.widget<SettingsPage>(find.byType(SettingsPage)).developerPage, developer);
  });

  testWidgets('the 会员 card and 会员中心 open the 会员 centre inside the official app', (tester) async {
    final harness = await showMe(tester);
    await tester.tap(_key('me-vip-centre'));
    await tester.tap(find.text('更多独家内容'));
    await tester.pump();
    expect(harness.opened, [_inApp, _inApp]);
    expect(MePage.vipCentre.toString(), 'https://big.bilibili.com/mobile/home');
    expect(find.text('无法打开链接'), findsNothing);
  });

  for (final (name, answer) in [
    ('answers false', () async => false),
    ('throws', () async => throw PlatformException(code: 'ACTIVITY_NOT_FOUND')),
  ]) {
    testWidgets('without the official app (it $name) the browser opens the 会员 centre', (tester) async {
      final harness = await showMe(tester, open: (link) => link.scheme == 'bilibili' ? answer() : Future.value(true));
      await tester.tap(_key('me-vip-card'));
      await tester.pump();
      expect(harness.opened, [_inApp, MePage.vipCentre]);
      expect(find.text('无法打开链接'), findsNothing);
    });

    testWidgets('when the browser also $name, it says so', (tester) async {
      final harness = await showMe(tester, open: (_) => answer());
      await tester.tap(_key('me-vip-centre'));
      await tester.pump();
      expect(harness.opened, [_inApp, MePage.vipCentre]);
      expect(find.text('无法打开链接'), findsOneWidget);
      await _toastGone(tester);
    });
  }

  testWidgets("where the official app isn't there (the PC), the 会员 centre goes straight to the browser", (
    tester,
  ) async {
    final harness = await showMe(tester, officialAppThere: false);
    await tester.tap(_key('me-vip-centre'));
    await tester.pump();
    expect(harness.opened, [MePage.vipCentre], reason: "the official app's link is never launched");
    expect(find.text('无法打开链接'), findsNothing);
  });

  testWidgets('logged out: the grey head and 点击登录, counts as -, no card; both ask for the login', (tester) async {
    final gate = FakeLoginGate();
    await showMe(tester, view: const MeLoggedOut(), loginGate: gate);
    expect(_key('me-avatar-blank'), findsOneWidget);
    expect(find.text('点击登录'), findsOneWidget);
    expect(find.textContaining('B币'), findsNothing);
    expect(find.text('空间'), findsNothing);
    expect(find.text('-'), findsNWidgets(3));
    expect(_key('me-vip-card'), findsNothing);
    expect(find.text('离线缓存'), findsOneWidget);
    expect(find.text('更多服务'), findsOneWidget);

    await tester.tap(_key('me-avatar'));
    await tester.pump();
    expect(gate.requests, 1);
    await tester.tap(_key('me-login'));
    await tester.pump();
    expect(gate.requests, 2);
  });

  for (final (name, view) in [('loading', const MeLoading()), ('failed', const MeFailed('网络不太好'))]) {
    testWidgets('$name: the header\'s layout with no name, counts as -, and nothing spinning over it', (tester) async {
      await showMe(tester, view: view);
      expect(_key('me-avatar-blank'), findsOneWidget);
      expect(_key('me-name'), findsNothing);
      expect(find.text('点击登录'), findsNothing);
      expect(find.text('-'), findsNWidgets(3));
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(LoadingTv), findsNothing);
      await tester.tap(_key('me-avatar'));
      await _settle(tester);
      expect(find.byType(SpacePage), findsNothing);
    });
  }

  testWidgets('a first load failing toasts its reason once; failing again after a retry toasts again', (tester) async {
    final harness = await showMe(tester, view: const MeLoading());
    harness.model.view = const MeFailed('网络不太好');
    await tester.pump();
    expect(find.text('网络不太好'), findsOneWidget);
    harness.model.view = const MeFailed('请求过于频繁，请稍后再试');
    await tester.pump();
    expect(find.text('请求过于频繁，请稍后再试'), findsNothing, reason: 'still failed: no second toast');
    await _toastGone(tester);

    harness.model.view = const MeLoading();
    await tester.pump();
    harness.model.view = const MeFailed('网络不太好');
    await tester.pump();
    expect(find.text('网络不太好'), findsOneWidget);
    await _toastGone(tester);
  });

  testWidgets('a pull that a failure lands under toasts once, its own answer', (tester) async {
    final harness = await showMe(tester, view: const MeLoading());
    harness.model
      ..refreshGate = Completer<void>()
      ..refreshAnswer = '网络不太好';
    await tester.drag(_key('me-list'), const Offset(0, 300));
    await tester.pump();
    harness.model.view = const MeFailed('网络不太好');
    await tester.pump();
    expect(find.text('网络不太好'), findsNothing, reason: 'the pull says it');
    harness.model.refreshGate!.complete();
    await _settle(tester, 4);
    expect(find.text('网络不太好'), findsOneWidget);
    await _toastGone(tester);
  });

  testWidgets('a 大会员 still loading keeps the card\'s room unseen; the card then fades in, nothing moving', (
    tester,
  ) async {
    final harness = await showMe(tester, view: const MeLoading(), checkAccount: true);
    expect(harness.services.environment.account, isA<LoggedIn>());
    expect(tester.getTopLeft(_key('me-list')).dy, 328);
    expect(_cardOpacity(tester), 0);
    expect(find.bySemanticsLabel('续订会员'), findsNothing);
    await tester.tap(_key('me-vip-centre'), warnIfMissed: false);
    await tester.pump();
    expect(harness.opened, isEmpty, reason: 'an unseen card takes no taps');

    harness.model.view = const MeShown(kaiProfile, kaiCounts);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(_key('me-list')).dy, 328);
    expect(_cardOpacity(tester), inExclusiveRange(0, 1));
    await _settle(tester, 6);
    expect(_cardOpacity(tester), 1);

    harness.model.view = const MeLoading();
    await _settle(tester, 6);
    harness.model.view = const MeShown(_plain, kaiCounts);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final top = tester.getTopLeft(_key('me-list')).dy;
    expect(top, inExclusiveRange(274, 328), reason: 'not a 大会员 after all: the room closes over 250 ms');
    await _settle(tester, 6);
    expect(tester.getTopLeft(_key('me-list')).dy, 274);
  });

  testWidgets('without a 大会员 known, the card grows in and fades in once the profile shows it', (tester) async {
    final harness = await showMe(tester, view: const MeLoading());
    expect(tester.getTopLeft(_key('me-list')).dy, 274);
    expect(_key('me-vip-card'), findsNothing);
    harness.model.view = const MeShown(kaiProfile, kaiCounts);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(_key('me-list')).dy, inExclusiveRange(274, 328));
    expect(_cardOpacity(tester), inExclusiveRange(0, 1));
    await _settle(tester, 6);
    expect(tester.getTopLeft(_key('me-list')).dy, 328);
    expect(_cardOpacity(tester), 1);
  });

  testWidgets('under Reduce Motion the card and its room come at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final harness = await showMe(tester, view: const MeLoading());
    harness.model.view = const MeShown(kaiProfile, kaiCounts);
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(_key('me-list')).dy, 328);
    expect(_cardOpacity(tester), 1);
  });

  testWidgets('rows and the 会员 card darken under a finger; glyphs, 空间, counts and shortcuts fade', (tester) async {
    await showMe(tester);
    for (final key in ['me-settings', 'me-vip-card']) {
      final finger = await tester.startGesture(tester.getTopLeft(_key(key)) + const Offset(30, 20));
      // In the list a tap down waits out the scroll's 100 ms.
      await tester.pump(const Duration(milliseconds: 150));
      final fill = tester.widget<DecoratedBox>(
        find.descendant(of: _key(key), matching: find.byType(DecoratedBox)).first,
      );
      expect((fill.decoration as BoxDecoration).color, BiliColors.pressedFill, reason: key);
      await finger.cancel();
      await tester.pump();
    }
    for (final key in ['me-cast', 'me-edit', 'me-space', 'me-following', 'me-offline', 'me-vip-centre', 'me-avatar']) {
      final finger = await tester.startGesture(tester.getCenter(_key(key)));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 200));
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.descendant(of: _key(key), matching: find.byType(CupertinoButton)),
          matching: find.byType(FadeTransition),
        ).first,
      );
      expect(fade.opacity.value, lessThan(1), reason: key);
      await finger.cancel();
      await _settle(tester, 6);
    }
  });

  testWidgets('labels in fading buttons keep the page\'s text style: untracked, with its fallback', (tester) async {
    await showMe(tester, theme: appTheme());
    for (final text in ['离线缓存', '空间', '关注', '13', '会员中心']) {
      final style = _laidOut(tester, text);
      expect(style?.letterSpacing ?? 0, 0, reason: text);
    }
    final page = _laidOut(tester, '更多服务');
    expect(_laidOut(tester, '空间')?.fontFamilyFallback, page?.fontFamilyFallback);
  });

  testWidgets('the page follows its model: a load landing shows the account', (tester) async {
    final harness = await showMe(tester, view: const MeLoading());
    expect(find.text('KaiC5504'), findsNothing);
    harness.model.view = const MeShown(kaiProfile, null);
    await tester.pump();
    expect(find.text('KaiC5504'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(3), reason: 'the counts not in yet');
  });

  testWidgets('showing: at start when 我的 is the tab, and each time it becomes the tab', (tester) async {
    final harness = await showMe(tester, active: false);
    expect(harness.model.showings, 0);
    harness.active.value = true;
    await tester.pump();
    expect(harness.model.showings, 1);
    harness.active.value = false;
    await tester.pump();
    harness.active.value = true;
    await tester.pump();
    expect(harness.model.showings, 2);
  });

  testWidgets('a model made from AppScope when none is given', (tester) async {
    final harness = await showMe(tester);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppScope(services: harness.services, child: child!),
        home: const MePage(active: true),
      ),
    );
    await tester.pump();
    expect(find.text('更多服务'), findsOneWidget);
  });

  testWidgets('the top row, header, counts and card stay put; the list scrolls under the card, cut 8 under it', (
    tester,
  ) async {
    await showMe(tester);
    final card = tester.getRect(_key('me-vip-card'));
    final name = tester.getRect(_key('me-name'));
    final viewport = tester.getRect(_key('me-list'));
    expect(viewport.top, card.bottom + 8, reason: "106's white band under the card");
    final restTop = tester.getTopLeft(_key('me-offline')).dy;
    expect(restTop, viewport.top);
    final icon = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is ShortcutPainter);
    expect(tester.getCenter(icon.first).dy, card.bottom + 26, reason: 'the rest position kept');

    final gesture = await tester.startGesture(tester.getCenter(_key('me-settings')));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final under = find.byKey(const ValueKey('me-offline'), skipOffstage: false);
    expect(tester.getTopLeft(under).dy, lessThan(card.bottom - 20), reason: 'under the card');
    expect(tester.getRect(_key('me-list')).top, viewport.top);
    expect(tester.getRect(_key('me-vip-card')), card);
    expect(tester.getRect(_key('me-name')), name);
    expect(tester.getRect(_key('me-cast')).center.dy, 84);
    expect(tester.widget<CustomScrollView>(_key('me-list')).clipBehavior, Clip.hardEdge, reason: 'cut at the card');
    await gesture.up();
    await _settle(tester);
    expect(tester.getTopLeft(_key('me-offline')).dy, restTop);
  });

  testWidgets('the pull refreshes the model and toasts what failed', (tester) async {
    final harness = await showMe(tester);
    harness.model.refreshAnswer = '网络不太好';
    await tester.drag(_key('me-list'), const Offset(0, 300));
    await _settle(tester, 10);
    expect(harness.model.refreshes, 1);
    expect(find.text('网络不太好'), findsOneWidget);
    await _toastGone(tester);
  });

  testWidgets('a pull that succeeds says nothing', (tester) async {
    final harness = await showMe(tester);
    await tester.drag(_key('me-list'), const Offset(0, 300));
    await _settle(tester, 10);
    expect(harness.model.refreshes, 1);
    expect(find.text('即将推出'), findsNothing);
    await _toastGone(tester);
  });

  testWidgets('every control answers an accessibility press, with a label', (tester) async {
    final handle = tester.ensureSemantics();
    await showMe(tester);
    for (final key in [
      'me-cast',
      'me-scan',
      'me-outfit',
      'me-night',
      'me-avatar',
      'me-edit',
      'me-space',
      'me-dynamics',
      'me-following',
      'me-followers',
      'me-vip-card',
      'me-vip-centre',
      'me-offline',
      'me-history',
      'me-favourites',
      'me-later',
      'me-support',
      'me-listen',
      'me-settings',
    ]) {
      final node = tester.getSemantics(_key(key));
      expect(node.label, isNotEmpty, reason: key);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue, reason: key);
    }
    handle.dispose();
  });

  testWidgets('the 会员 card and 会员中心 are pressable by their own labels', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = await showMe(tester);
    for (final label in ['续订会员', '会员中心']) {
      final node = find.semantics.byLabel(label);
      expect(node, findsOne, reason: label);
      tester.semantics.tap(node);
      await tester.pump();
    }
    expect(harness.opened, [_inApp, _inApp]);
    handle.dispose();
  });

  testWidgets('logged out, the avatar and 点击登录 answer accessibility presses too', (tester) async {
    final handle = tester.ensureSemantics();
    final gate = FakeLoginGate();
    await showMe(tester, view: const MeLoggedOut(), loginGate: gate);
    tester.semantics.tap(find.semantics.byLabel('点击登录').first);
    await tester.pump();
    expect(gate.requests, 1);
    handle.dispose();
  });

  testWidgets('the status bar is dark over the white page', (tester) async {
    await showMe(tester);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(of: find.byType(MePage), matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>)).first,
    );
    expect(region.value, SystemUiOverlayStyle.dark);
  });

  testWidgets('text follows the 字体 chosen', (tester) async {
    final saved = BiliFonts.family;
    addTearDown(() => BiliFonts.family = saved);
    BiliFonts.family = BiliFonts.system;
    await showMe(tester, fonts: FontStore.memory()..select(FontChoice.system));
    for (final text in ['KaiC5504', '更多服务', '离线缓存', '续订会员', '动态']) {
      expect(tester.widget<Text>(find.text(text)).style?.fontFamily, BiliFonts.system, reason: text);
    }
  });
}

const _counts = {'动态': 'dynamics', '关注': 'following', '粉丝': 'followers'};
