import 'dart:ui' as ui;

import 'package:bili_core/api.dart' show SkinColors, SkinEquip;
import 'package:bilifast/offline/pages/offline_bar.dart';
import 'package:bilifast/settings/settings_page.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:bilifast/shared/cover_placeholder.dart';
import 'package:bilifast/shared/menu.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/skin/skin.dart';
import 'package:bilifast/watch_later/watch_later_glyphs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(ValueNotifier<ThemeMode> mode, Widget child) => ValueListenableBuilder<ThemeMode>(
  valueListenable: mode,
  builder: (context, value, _) => MaterialApp(
    theme: biliTheme(Brightness.light),
    darkTheme: biliTheme(Brightness.dark),
    themeMode: value,
    themeAnimationDuration: Duration.zero,
    home: child,
  ),
);

void main() {
  testWidgets('the retained empty-state illustration repaints both body and shade in dark mode', (tester) async {
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);
    await tester.pumpWidget(_host(mode, const Center(child: EmptyTvArt())));
    Future<int> brightest() async {
      final painter = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(EmptyTvArt), matching: find.byType(CustomPaint)),
      ).painter!;
      return (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(120, 100));
        final picture = recorder.endRecording();
        final image = await picture.toImage(120, 100);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        image.dispose();
        picture.dispose();
        var maximum = 0;
        final rgba = bytes!.buffer.asUint8List();
        for (var i = 0; i < rgba.length; i += 4) {
          if (rgba[i + 3] > 128 && rgba[i] > maximum) maximum = rgba[i];
        }
        return maximum;
      }))!;
    }
    expect(await brightest(), greaterThan(220));
    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(await brightest(), lessThan(80));
  });

  testWidgets('a retained cover placeholder changes its fill and tint without changing its size', (tester) async {
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);
    const placeholder = Center(child: SizedBox(width: 211, height: 158.25, child: CoverPlaceholder()));
    await tester.pumpWidget(_host(mode, placeholder));
    final finder = find.byType(CoverPlaceholder);
    final size = tester.getSize(finder);
    final element = finder.evaluate().single;
    Color fill() => tester.widget<ColoredBox>(find.descendant(of: finder, matching: find.byType(ColoredBox))).color;
    Color? tint() => tester.widget<Image>(find.descendant(of: finder, matching: find.byType(Image))).color;
    expect(fill(), CoverPlaceholderTheme.fill);
    final lightTint = tint();
    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(fill(), const BiliPalette(Brightness.dark).raised);
    expect(tint(), isNot(lightTint));
    expect(tester.getSize(finder), size);
    expect(finder.evaluate().single, same(element));
  });

  testWidgets('a held menu row switches its foreground and press feedback with the theme', (tester) async {
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);
    await tester.pumpWidget(_host(mode, Material(child: Center(
      child: MenuRow(title: '稍后再看', icon: Icons.schedule, onTap: () {}),
    ))));
    final row = find.byType(MenuRow);
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 100));
    final box = find.descendant(of: find.byType(PressHighlight), matching: find.byType(DecoratedBox));
    Color? pressed() => (tester.widget<DecoratedBox>(box).decoration as BoxDecoration).color;
    expect(pressed(), BiliColors.pressedFill);
    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(pressed(), const BiliPalette(Brightness.dark).pressed);
    expect(tester.widget<Text>(find.text('稍后再看')).style?.color, const BiliPalette(Brightness.dark).text);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pressed(), isNull);
  });

  testWidgets('settings rows and their own status region follow dark mode', (tester) async {
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);
    await tester.pumpWidget(_host(mode, const SettingsScaffold(title: '设置', children: [
      SettingsSection(children: [SettingsRow(title: '字体', value: '系统字体')]),
    ])));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, SettingsTheme.page);
    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    const dark = BiliPalette(Brightness.dark);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, dark.page);
    expect(tester.widget<Text>(find.text('字体')).style?.color, dark.text);
    final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byWidgetPredicate((widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(regions.any((region) => region.value.statusBarIconBrightness == Brightness.light), isTrue);
  });

  testWidgets('offline stock bar and keyboard adapt while a skin keeps its supplied colors', (tester) async {
    final mode = ValueNotifier(ThemeMode.light);
    final field = TextEditingController(text: '视频');
    final focus = FocusNode();
    addTearDown(() { mode.dispose(); field.dispose(); focus.dispose(); });
    OfflineBarLook? stock;
    OfflineBarLook? dressed;
    const skin = Skin(equip: SkinEquip(
      id: 1, name: '测试', ver: 1, packageUrl: '', packageMd5: '',
      colors: SkinColors(colorSecondPage: 0xFFE1E8DC, color: 0xFF333333),
    ));
    await tester.pumpWidget(_host(mode, Builder(builder: (context) {
      stock = OfflineBarLook.of(null, context: context);
      dressed = OfflineBarLook.of(skin, context: context);
      return Material(child: OfflineSearchBar(
        look: stock!, field: field, focus: focus,
        onChanged: (_) {}, onClear: field.clear, onCancel: () {},
      ));
    })));
    expect(stock!.fill, OfflineListTheme.bar);
    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    const dark = BiliPalette(Brightness.dark);
    expect(stock!.fill, dark.surface);
    expect(stock!.ink, dark.text);
    expect(stock!.lightStatus, isTrue);
    expect(dressed!.fill, const Color(0xFFE1E8DC));
    expect(dressed!.ink, const Color(0xFF333333));
    expect(dressed!.lightStatus, isFalse);
    final input = tester.widget<TextField>(find.byKey(const ValueKey('offline-search-field')));
    expect(input.keyboardAppearance, Brightness.dark);
    expect(input.controller!.text, '视频');
  });
}


