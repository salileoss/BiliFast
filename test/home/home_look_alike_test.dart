import 'dart:async';
import 'dart:io';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/home_tab_bar.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/search/search_glyphs.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/cover_placeholder.dart';
import 'package:bilifast/shared/loading_tv.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';
import '../video/mixed_lines.dart';
import 'feed_fakes.dart';

/// 01's default word, long enough to be cut short.
const _word = '爆了！崩铁4.7即将赠送限五！孩子们快来领取';

const _screen = ValueKey('screen');

FeedHttp _feed() => FeedHttp()
  ..pages[1] = [
    feedItem('BV1aaa', title: '猫猫为亚运会加油', reason: '1万点赞'),
    feedItem('BV1bbb', title: '海底捞过生日？这里弟子各有喜怒哀乐'),
    feedItem('BV1ccc', title: '荣荣猜你左手拿的是手机'),
    feedItem('BV1ddd', title: '超震撼的 8K 视频用于 OLED 显示测试'),
  ];

/// 首页 at 3× under the system font, its feed answered by [http], inside a boundary keyed [_screen].
Future<void> _showHome(WidgetTester tester, FeedHttp http, {bool dark = false}) async {
  final saved = BiliFonts.family;
  addTearDown(() => BiliFonts.family = saved);
  await tester.runAsync(loadSystemFontStandIns);
  showAsPhone(tester);
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
    searchApi: FakeSearchApi(defaultWord: _word),
  );
  BiliFonts.family = BiliFonts.system;
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? biliTheme(Brightness.dark) : appTheme(),
      builder: (context, child) => RepaintBoundary(
        key: _screen,
        child: AppScope(services: services, child: child!),
      ),
      home: const MainShell(),
    ),
  );
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 首页 as KaiC's iPhone draws it, under the system font, against 01's and 14's measures (px / 3). With
/// BILIFAST_SHOTS naming a folder outside the repo, the 3× shots are saved there for tools/screen_diff.py.
void main() {
  testWidgets('dark Home keeps the existing feed arrangement with charcoal page and pale titles', (tester) async {
    await _showHome(tester, _feed(), dark: true);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const BiliPalette(Brightness.dark).page);
    expect(tester.getRect(find.byType(HomeTabBar)).top, 873);
    expect(tester.getRect(find.byKey(const ValueKey('home-search'))), const Rect.fromLTRB(64, 67, 364, 101));
    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) {
      await tester.runAsync(loadIconFonts);
      await tester.pump();
      await saveShot(tester, find.byKey(_screen), '$shots/home-dark.png');
    }
  });

  testWidgets('首页 under the system font: the top row and the bottom bar where 01 has them', (tester) async {
    await _showHome(tester, _feed());

    final avatar = tester.getRect(find.byKey(const ValueKey('home-avatar')));
    final field = tester.getRect(find.byKey(const ValueKey('home-search')));
    expect(avatar.center.dy, 84);
    expect(field, const Rect.fromLTRB(64, 67, 364, 101));
    // 01 measures them from the rim's outer edge: the rim insets nothing.
    final magnifier = tester.getRect(
      find.descendant(of: find.byKey(const ValueKey('home-search')), matching: find.byType(SearchGlyphIcon)),
    );
    expect(magnifier.center.dx, moreOrLessEquals(field.left + HomeTabBarTheme.fieldGlyphCentre));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-search-word'))).dx,
      moreOrLessEquals(field.left + HomeTabBarTheme.fieldTextStart),
    );

    // 01's tab row ends at its hairline, 141.67 pt; the row's pieces are whole thirds, so ours lands on 142.
    expect(tester.getRect(find.byType(Divider).first).top, moreOrLessEquals(141.67, epsilon: 0.34));

    final bar = tester.getRect(find.byType(HomeTabBar));
    expect(bar.top, 873);
    expect(bar.bottom, 956);
    for (final (i, tab) in HomeTab.values.indexed) {
      final slot = tester.getRect(find.byKey(ValueKey('home-tab-${tab.name}')));
      expect(slot.center.dx, 44 + 88.0 * i);
    }

    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/01-home-ours.png');
  });

  testWidgets("推荐's cards under the system font: covers 248 pt apart from under the hairline, a loading one the "
      "official grey with its 小电视, as 01's and 14's", (tester) async {
    await _showHome(tester, _feed());
    await tester.runAsync(
      () => precacheImage(const AssetImage(CoverPlaceholder.asset), tester.element(find.byType(CoverPlaceholder).first)),
    );
    await tester.pump();

    final hairline = tester.getRect(find.byType(Divider).first);
    expect(hairline.height, moreOrLessEquals(1 / 3), reason: "one pixel, as 01's");
    final first = tester.getTopLeft(find.byKey(const ValueKey('feed-card-BV1aaa'))).dy;
    final third = tester.getTopLeft(find.byKey(const ValueKey('feed-card-BV1ccc'))).dy;
    expect(first, moreOrLessEquals(hairline.bottom + BiliMetrics.feedSpacing));
    expect(third - first, moreOrLessEquals(248), reason: "01's rows at 148, 396 and 644");

    final cover = tester.getRect(find.byType(CoverPlaceholder).first);
    final tv = tester.getRect(find.descendant(of: find.byType(CoverPlaceholder).first, matching: find.byType(Image)));
    expect(tv.width, moreOrLessEquals(39));
    expect(tv.height, moreOrLessEquals(109 / 3));
    expect((tv.center - cover.center).distance, moreOrLessEquals(0), reason: "14's 小电视 is centred within 0.33 pt");

    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/14-home-loading-ours.png');
  });

  testWidgets("首页's tap under the system font: the TV in its 60 pt band where 14 has it", (tester) async {
    final http = _feed();
    await _showHome(tester, http);
    final restTop = tester.getTopLeft(find.byKey(const ValueKey('feed-card-BV1aaa'))).dy;
    http.gates[1] = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('home-tab-home')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Measured from the tab row's hairline: 142 in 14, lower here because our tab row is taller than 01's.
    final band = tester.getTopLeft(find.byKey(const ValueKey('feed'))).dy;
    expect(tester.getRect(find.byType(LoadingTv)), Rect.fromLTWH(190, band, LoadingTvTheme.size, LoadingTvTheme.size));
    final cardTop = tester.getTopLeft(find.byKey(const ValueKey('feed-card-BV1aaa'))).dy;
    expect(cardTop, restTop + LoadingTvTheme.size);
    expect(cardTop - band, 66, reason: "14's first card, 208 under a hairline at 142");

    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/14-home-reload-ours.png');
    http.gates[1]!.complete();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}
