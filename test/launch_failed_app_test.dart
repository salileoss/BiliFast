import 'package:bilifast/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shared/text_lines.dart';

void main() {
  testWidgets('a failed launch retains the restored dark appearance', (tester) async {
    await tester.pumpWidget(const LaunchFailedApp(error: 'startup failed', mode: ThemeMode.dark));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, const Color(0xFF18191B));
    expect(tester.widget<Text>(find.text('BiliFast 启动失败，请重启应用')).style?.color, const Color(0xFFE3E5E7));
    expect(find.text('startup failed'), findsOneWidget);
  });

  testWidgets('under the system font, an error mixing Latin and Chinese sits on a Chinese one\'s lines', (tester) async {
    await useSystemFont(tester);
    tester.view
      ..physicalSize = const Size(440, 956)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final error = find.byKey(const ValueKey('launch-error'));
    Future<(TextLines, TextLines)> show(String message) async {
      await tester.pumpWidget(LaunchFailedApp(error: message));
      return (linesOf(tester, find.text('BiliFast 启动失败，请重启应用')), linesOf(tester, error));
    }

    final (titleOverChinese, chinese) = await show('数据目录无法读取数据目录无法读取数据目录无法读取数据目录无法读取数据目录无法读取');
    final (titleOverMixed, mixed) = await show('FileSystemException 数据目录 errno 13 无法读取 FileSystemException 数据目录');
    expect(chinese.lines.length, 2);
    expect(mixed.lines.length, 2);
    expect(mixed.pitch, closeTo(chinese.pitch, 0.01));
    for (var line = 0; line < 2; line++) {
      expect(mixed.han[line], closeTo(chinese.han[line], 0.01));
    }
    expect(titleOverMixed.han.single, closeTo(titleOverChinese.han.single, 0.01));
  });
}
