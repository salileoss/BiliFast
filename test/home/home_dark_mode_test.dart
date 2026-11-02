import 'package:bilifast/home/home_tab_bar.dart';
import 'package:bilifast/home/tab_bar_icons.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the bottom bar updates its canvas, selected and inactive glyphs in place',
    (tester) async {
      final mode = ValueNotifier(ThemeMode.light);
      final selected = ValueNotifier(HomeTab.mine);
      var taps = 0;
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: Listenable.merge([mode, selected]),
          builder: (context, _) => MaterialApp(
            theme: biliTheme(Brightness.light),
            darkTheme: biliTheme(Brightness.dark),
            themeMode: mode.value,
            themeAnimationDuration: Duration.zero,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: HomeTabBar(
                  selected: selected.value,
                  onTap: (tab) {
                    taps++;
                    selected.value = tab;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final bar = find.byType(HomeTabBar);
      final element = tester.element(bar);
      final before = tester.getRect(bar);
      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(tester.element(bar), same(element));
      expect(tester.getRect(bar), before);
      expect(taps, 0);
      final palette = BiliPalette.of(tester.element(bar));
      final paints = tester.widgetList<CustomPaint>(
        find.descendant(of: bar, matching: find.byType(CustomPaint)),
      );
      final glyphs = paints
          .map((paint) => paint.painter)
          .whereType<HomeTabGlyphPainter>()
          .toList();
      expect(
        glyphs.singleWhere((glyph) => glyph.tab == HomeTab.mine).color,
        palette.accent,
      );
      expect(
        glyphs.singleWhere((glyph) => glyph.tab == HomeTab.home).color,
        palette.icon,
      );
      final post = paints
          .map((paint) => paint.painter)
          .whereType<PostButtonPainter>()
          .single;
      expect(post.palette.brightness, Brightness.dark);
      await tester.tap(find.byKey(const ValueKey('home-tab-home')));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(selected.value, HomeTab.home);
      await tester.pumpWidget(const SizedBox());
      mode.dispose();
      selected.dispose();
    },
  );
}
