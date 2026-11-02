import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:bilifast/home/home_tab_bar.dart';
import 'package:bilifast/me/me_glyphs.dart';
import 'package:bilifast/me/me_page.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_page_support.dart';
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';

void main() {
  testWidgets(
    'the existing moon toggles appearance without reloading or replacing My',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final harness = await showMe(tester);
        final moon = find.byKey(const ValueKey('me-night'));
        final page = tester.state(find.byType(MePage));
        final showings = harness.model.showings;
        final node = tester.getSemantics(moon).getSemanticsData();
        expect(node.label, '夜间模式');
        expect(node.flagsCollection.isToggled, Tristate.isFalse);

        await tester.tap(moon);
        await tester.pumpAndSettle();

        expect(harness.services.appearance.isDark, isTrue);
        expect(
          Theme.of(tester.element(find.byType(MePage))).brightness,
          Brightness.dark,
        );
        expect(tester.state(find.byType(MePage)), same(page));
        expect(harness.model.showings, showings);
        expect(harness.model.refreshes, 0);
        expect(harness.skin.refreshes, 0);
        expect(find.text('即将推出'), findsNothing);
        final darkNode = tester.getSemantics(moon).getSemanticsData();
        expect(darkNode.label, '日间模式');
        expect(darkNode.flagsCollection.isToggled, Tristate.isTrue);
        final paint = tester.widget<CustomPaint>(
          find.descendant(of: moon, matching: find.byType(CustomPaint)),
        );
        expect(
          (paint.painter! as MeTopGlyphPainter).color,
          const BiliPalette(Brightness.dark).icon,
        );

        await tester.tap(moon);
        await tester.pumpAndSettle();
        expect(harness.services.appearance.isDark, isFalse);
        expect(
          Theme.of(tester.element(find.byType(MePage))).brightness,
          Brightness.light,
        );
        expect(tester.state(find.byType(MePage)), same(page));
        expect(tester.getSemantics(moon).label, '夜间模式');
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'dark My uses charcoal surfaces and soft text while retaining white badge ink',
    (tester) async {
      final shots = Platform.environment['BILIFAST_SHOTS'];
      final saved = BiliFonts.family;
      addTearDown(() => BiliFonts.family = saved);
      if (shots != null) {
        await tester.runAsync(loadSystemFontStandIns);
        await tester.runAsync(loadIconFonts);
      }
      final harness = await showMe(
        tester,
        pixelRatio: shots == null ? 1 : 3,
        fonts: shots == null
            ? null
            : (FontStore.memory()..select(FontChoice.system)),
        bottomBar: shots == null
            ? null
            : HomeTabBar(selected: HomeTab.mine, onTap: (_) {}),
      );
      harness.services.appearance.toggle();
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(MePage));
      final surface = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MePage),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(surface.color, BiliPalette.of(context).surface);
      final title = tester.renderObject<RenderParagraph>(find.text('更多服务'));
      expect(title.text.style!.color, BiliPalette.of(context).text);
      final badge = tester.widget<Text>(find.text('年度大会员'));
      expect(badge.style!.color, BiliColors.onPink);
      expect(
        SystemChrome.latestStyle!.statusBarIconBrightness,
        Brightness.light,
      );
      if (shots != null) {
        await saveShot(
          tester,
          find.byKey(const ValueKey('screen')),
          '$shots/my-dark.png',
        );
      }
    },
  );
}
