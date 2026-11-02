import 'package:bilifast/shared/app_theme.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('constant children depend on the palette and rebuild when appearance changes', (tester) async {
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    await tester.pumpWidget(ValueListenableBuilder(
      valueListenable: brightness,
      builder: (context, value, child) => MaterialApp(theme: biliTheme(value), home: child),
      child: const _Surface(),
    ));
    expect(tester.widget<ColoredBox>(find.byKey(const ValueKey('surface'))).color, MeTheme.background);
    brightness.value = Brightness.dark;
    await tester.pumpAndSettle();
    expect(tester.widget<ColoredBox>(find.byKey(const ValueKey('surface'))).color, const Color(0xFF18191B));
    expect(tester.widget<Text>(find.text('content')).style!.color, const Color(0xFFE3E5E7));
  });

  testWidgets('light measurements and fixed media colors are preserved', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: biliTheme(Brightness.light),
      home: Builder(builder: (context) {
        expect(MeTheme.colorsOf(context).card, MeTheme.card);
        expect(MeTheme.colorsOf(context).topGlyph, MeTheme.topGlyph);
        expect(MeTheme.colorsOf(context).skinFadeColors, MeTheme.skinFadeColors);
        expect(BiliColors.colorsOf(context).pink, BiliColors.pink);
        return const SizedBox.shrink();
      }),
    ));
    await tester.pumpWidget(MaterialApp(
      theme: biliTheme(Brightness.dark),
      home: Builder(builder: (context) {
        expect(BiliColors.onCover, const Color(0xFFFFFFFF));
        expect(BiliColors.onPink, const Color(0xFFFFFFFF));
        expect(BiliColors.videoBackground, const Color(0xFF000000));
        expect(BiliColors.danmakuOutline, const Color(0xFF000000));
        final fade = MeTheme.colorsOf(context).skinFadeColors;
        expect(fade.first.a, 0);
        expect(fade.last, MeTheme.colorsOf(context).background);
        expect(fade.map((color) => color.a), MeTheme.skinFadeColors.map((color) => color.a));
        return const SizedBox.shrink();
      }),
    ));
  });

  test('primary and secondary dark text retain readable contrast', () {
    const palette = BiliPalette(Brightness.dark);
    double contrast(Color foreground, Color background) =>
        (foreground.computeLuminance() + 0.05) / (background.computeLuminance() + 0.05);
    expect(contrast(palette.text, palette.surface), greaterThan(7));
    expect(contrast(palette.secondary, palette.surface), greaterThan(4.5));
    expect(contrast(palette.text, palette.raised), greaterThan(7));
  });
}

class _Surface extends StatelessWidget {
  const _Surface();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('surface'),
    color: MeTheme.colorsOf(context).background,
    child: Text('content', style: TextStyle(color: BiliColors.colorsOf(context).text)),
  );
}
