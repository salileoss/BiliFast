import 'dart:io';

import 'package:bilifast/shared/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String? saved;
  setUp(() => saved = BiliFonts.family);
  tearDown(() => BiliFonts.family = saved);

  test('in tests the system font falls back to the PingFang stand-in; MiSans needs no fallback', () {
    BiliFonts.family = BiliFonts.system;
    expect(BiliFonts.fallback, ['PingFang SC']);
    BiliFonts.family = BiliFonts.miSans;
    expect(BiliFonts.fallback, isNull);
  });

  // iOS's engine registers no CupertinoSystemText, so a family the phone has in a fallback list draws every run of the
  // system font: 1.0.0 (15) listed Apple Color Emoji and drew digits and spaces emoji-wide and low.
  test('only the launch check sets the system font\'s fallback, and every style takes it through BiliFonts.fallback', () {
    final setter = RegExp(r'systemFallback\s*=[^=]');
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final isFontTheme = file.uri.pathSegments.last == 'theme.dart';
      expect(setter.allMatches(source).length, isFontTheme ? 1 : 0, reason: file.path);
      for (final line in source.split('\n').where((line) => line.contains('fontFamilyFallback:'))) {
        // The launch check's own measuring style.
        if (isFontTheme && line.contains('fontFamilyFallback: fallback,')) continue;
        expect(line, contains('BiliFonts.fallback'), reason: '${file.path}: $line');
      }
    }
  });

  // Tests register the SF stand-in under BiliFonts.system, so the phone's case, where it matches nothing, can't be
  // drawn here; the choice is checked on the widths the launch check would measure.
  test('the launch check names SF, then PingFang SC, only when SF\'s own name draws Latin as the default does', () {
    expect(BiliFonts.chooseSystemFallback((fallback) => 120), [BiliFonts.appleSystem, 'PingFang SC']);
    expect(BiliFonts.chooseSystemFallback((fallback) => fallback == null ? 120 : 131), isNull);
  });

  test('sizes measured off the official app under the system font (font-check 02, 04); MiSans keeps its own', () {
    BiliFonts.family = BiliFonts.system;
    expect(PageTheme.tabLabelText, 12.75);
    expect(PageTheme.danmakuFieldText, 12.75);
    expect(IntroTheme.titleText, 15.25);
    expect(CommentListTheme.threadTitleText, 13.75);
    BiliFonts.family = BiliFonts.miSans;
    expect(PageTheme.tabLabelText, 13.5);
    expect(PageTheme.danmakuFieldText, 13.5);
    expect(IntroTheme.titleText, 16);
    expect(CommentListTheme.threadTitleText, 15);
  });
}
