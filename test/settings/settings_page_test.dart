import 'dart:async';
import 'dart:io';

import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/settings/font_page.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/settings/node_page.dart';
import 'package:bilifast/settings/settings_page.dart';
import 'package:bilifast/shared/image_disk_cache.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/video/player_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video/mixed_lines.dart';
import 'settings_fakes.dart';

void main() {
  late SettingsWorld world;
  late PlayerPrefs prefs;

  setUp(() => prefs = PlayerPrefs.memory());

  Future<void> show(
    WidgetTester tester, {
    Account account = const LoggedOut(),
    WidgetBuilder? developerPage,
    Completer<void>? startGate,
    bool reduceMotion = false,
    ThemeData? theme,
    ImageDiskCache? imageCache,
  }) async {
    tester.view
      ..physicalSize = const Size(440, 956) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    world = await SettingsWorld.create(account: account, startGate: startGate, imageCache: imageCache);
    addTearDown(world.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => AppScope(
          services: world.services,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Center(
            child: GestureDetector(
              key: const ValueKey('open-settings'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(developerPage: developerPage, prefs: prefs, version: '1.0.0 (10)'),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
  }

  Finder row(String key) => find.byKey(ValueKey(key));
  Finder confirmButton(String label) => find.byKey(ValueKey('settings-confirm-$label'));
  final confirm = find.byKey(const ValueKey('settings-confirm'));

  Future<void> tapRow(WidgetTester tester, String key) async {
    await tester.ensureVisible(row(key));
    await tester.pumpAndSettle();
    await tester.tap(row(key));
    await tester.pumpAndSettle();
  }

  testWidgets('under the system font mixed titles, the account\'s name, the licence line and the bar\'s title sit on '
      'the Chinese line', (tester) async {
    await useSystemFont(tester);
    await show(tester, account: const LoggedIn(name: mixedLine, vip: false), theme: appTheme());
    // The world's own font store starts on this platform's MiSans.
    world.services.fonts.select(FontChoice.system);
    await tester.pumpAndSettle();
    expectOnChineseLine(tester, find.text(mixedLine));
    expectOnChineseLine(tester, find.text('CDN 节点'));
    expectOnChineseLine(tester, find.text('BTR 加速（默认）'));
    const licence = '下载加速移植自 Bilibili 线程撕裂者（BTR），MIT 许可。';
    await tester.ensureVisible(find.text(licence));
    await tester.pumpAndSettle();
    expectOnChineseLine(tester, find.text(licence));

    await tapRow(tester, 'settings-node');
    expectOnChineseLine(tester, find.text('CDN 节点'));
  });

  testWidgets('under the system font the system row\'s sample on 字体 sits on the Chinese line', (tester) async {
    await useSystemFont(tester);
    await show(tester, theme: appTheme());
    world.services.fonts.select(FontChoice.system);
    await tapRow(tester, 'settings-font');
    expectOnChineseLine(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('font-system')),
        matching: find.text('推荐 关注 热门 · 1.2万播放 03:45'),
      ),
    );
  });

  group('the account row', () {
    testWidgets('logged out: 登录 opens the login page, and there is no 退出登录', (tester) async {
      await show(tester);
      expect(find.descendant(of: row('settings-login'), matching: find.text('登录')), findsOneWidget);
      expect(row('settings-relogin'), findsNothing);
      expect(row('settings-account'), findsNothing);
      await tapRow(tester, 'settings-login');
      expect(world.gate.requests, 1);
      expect(row('settings-logout'), findsNothing);
    });

    testWidgets('login expired: 重新登录 opens the login page', (tester) async {
      await show(tester, account: const LoginExpired());
      expect(row('settings-login'), findsNothing);
      await tapRow(tester, 'settings-relogin');
      expect(world.gate.requests, 1);
      expect(row('settings-logout'), findsNothing);
    });

    testWidgets('logged in: 账号 shows the name and does nothing, and 退出登录 is last', (tester) async {
      await show(tester, account: const LoggedIn(name: '小明', vip: false));
      expect(find.descendant(of: row('settings-account'), matching: find.text('小明')), findsOneWidget);
      await tapRow(tester, 'settings-account');
      expect(world.gate.requests, 0);
      expect(confirm, findsNothing);
      expect(row('settings-logout'), findsOneWidget);
      final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow)).toList();
      expect(rows.last.title, '退出登录');
    });

    testWidgets('大会员: the name is pink with the pink 大会员 pill after it; anyone else\'s is grey without one', (
      tester,
    ) async {
      await show(tester, account: const LoggedIn(name: '小明', vip: true));
      final name = tester.widget<Text>(find.descendant(of: row('settings-account'), matching: find.text('小明')));
      expect(name.style?.color, SettingsTheme.vipName);
      final badge = find.descendant(of: row('settings-account'), matching: find.byKey(const ValueKey('settings-vip')));
      expect(find.descendant(of: badge, matching: find.text('大会员')), findsOneWidget);
      expect(tester.getRect(badge).left, greaterThan(tester.getRect(find.text('小明')).right));
      expect(tester.getRect(badge).right, lessThanOrEqualTo(440 - SettingsTheme.chevronRight));

      world.environment.account = const LoggedIn(name: '小明', vip: false);
      await tester.pump();
      expect(tester.widget<Text>(find.text('小明')).style?.color, SettingsTheme.value);
      expect(find.byKey(const ValueKey('settings-vip')), findsNothing);
    });

    testWidgets('a failed account check offers a retry that asks Bilibili again', (tester) async {
      await show(tester, account: const AccountUnknown());
      world.environment
        ..accountCheckFailed = true
        ..account = const AccountUnknown();
      await tester.pump();
      expect(find.descendant(of: row('settings-account'), matching: find.text('无法获取账号信息，点按重试')), findsOneWidget);
      expect(find.text('账号确认失败'), findsNothing);
      await tapRow(tester, 'settings-account');
      expect(world.environment.refreshes, 1);
      expect(world.gate.requests, 0);
    });

    testWidgets('unknown: 账号 says it is checking', (tester) async {
      await show(tester, account: const AccountUnknown());
      expect(find.descendant(of: row('settings-account'), matching: find.text('正在确认账号…')), findsOneWidget);
      expect(row('settings-logout'), findsNothing);
    });

    testWidgets('a login while 设置 is open turns 登录 into 账号 and brings 退出登录', (tester) async {
      await show(tester);
      world.environment.account = const LoggedIn(name: '小明', vip: false);
      await tester.pump();
      expect(row('settings-login'), findsNothing);
      expect(find.text('小明'), findsOneWidget);
      expect(row('settings-logout'), findsOneWidget);
    });
  });

  testWidgets('字体 opens the font page', (tester) async {
    await show(tester);
    await tapRow(tester, 'settings-font');
    expect(find.byType(FontPage), findsOneWidget);
  });

  group('加速', () {
    testWidgets('CDN 节点 starts on 自动优选; each mode reaches the engine for the next video', (tester) async {
      await show(tester);
      expect(find.descendant(of: row('settings-node'), matching: find.text('自动优选')), findsOneWidget);
      await tapRow(tester, 'settings-node');
      expect(find.byType(NodePage), findsOneWidget);
      await tester.tap(row('node-mainland'));
      await tester.pumpAndSettle();
      expect(prefs.node, NodeChoice.mainland);
      expect(world.engine.nodeModes.last, isA<MainlandNodes>());
      expect(find.descendant(of: row('node-mainland'), matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: row('node-overseas'), matching: find.byIcon(Icons.check)), findsNothing);

      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: row('settings-node'), matching: find.text('大陆节点')), findsOneWidget);

      await tapRow(tester, 'settings-node');
      await tester.tap(row('node-overseas'));
      await tester.pumpAndSettle();
      expect(prefs.node, NodeChoice.overseas);
      expect(world.engine.nodeModes.last, isA<OverseasNodes>());
      await tester.tap(row('node-auto'));
      await tester.pumpAndSettle();
      expect(prefs.node, NodeChoice.auto);
      expect(world.engine.nodeModes.last, isA<AutoNodes>());
      expect(find.descendant(of: row('node-auto'), matching: find.byIcon(Icons.check)), findsOneWidget);
    });

    testWidgets('a change while the engine is still starting reaches it once it has started, with no player made', (
      tester,
    ) async {
      final gate = Completer<void>();
      await show(tester, startGate: gate);
      expect(world.shared.running, isNull);
      await tapRow(tester, 'settings-node');
      await tester.tap(row('node-mainland'));
      await tester.pumpAndSettle();
      expect(prefs.node, NodeChoice.mainland);
      expect(world.engine.nodeModes, isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      expect(world.shared.running, same(world.engine));
      expect(world.engine.nodeModes.single, isA<MainlandNodes>());
      expect(world.services.playback.live, 0);
    });

    testWidgets('picking the node already in use changes nothing', (tester) async {
      await show(tester);
      await tapRow(tester, 'settings-node');
      await tester.tap(row('node-auto'));
      await tester.pumpAndSettle();
      expect(world.engine.nodeModes, isEmpty);
    });

    testWidgets('BTR 加速 flips the saved setting both ways', (tester) async {
      await show(tester);
      expect(prefs.btr, isTrue);
      await tapRow(tester, 'settings-btr');
      expect(prefs.btr, isFalse);
      await tapRow(tester, 'settings-btr');
      expect(prefs.btr, isTrue);
    });
  });

  group('数据', () {
    testWidgets('重置编码记忆 asks first, then forgets the codecs that failed', (tester) async {
      await show(tester);
      world.memory.markFailed('av1');
      await tapRow(tester, 'settings-codec-memory');
      expect(find.descendant(of: confirm, matching: find.text('重置编码记忆？')), findsOneWidget);
      expect(find.descendant(of: confirm, matching: find.text('本机播放失败过的编码会重新参与尝试。')), findsOneWidget);
      await tester.tap(confirmButton('重置'));
      await tester.pumpAndSettle();
      expect(world.memory.failedKinds, isEmpty);
      expect(confirm, findsNothing);
    });

    testWidgets('重置编码记忆 needs neither a page open nor the engine started', (tester) async {
      final gate = Completer<void>();
      await show(tester, startGate: gate);
      world.memory.markFailed('av1');
      await tapRow(tester, 'settings-codec-memory');
      await tester.tap(confirmButton('重置'));
      await tester.pumpAndSettle();
      expect(confirm, findsNothing);
      expect(world.memory.failedKinds, isEmpty);
      expect(world.services.playback.live, 0);
      gate.complete();
    });

    testWidgets('清除最近观看 is off while 最近打开 is empty', (tester) async {
      await show(tester);
      expect(tester.widget<SettingsRow>(row('settings-recents')).enabled, isFalse);
      await tapRow(tester, 'settings-recents');
      expect(confirm, findsNothing);
    });

    testWidgets('清除最近观看 asks first, then empties 最近打开 and turns itself off', (tester) async {
      await show(tester);
      world.services.recents.add(sampleRecent);
      await tester.pump();
      await tapRow(tester, 'settings-recents');
      expect(find.descendant(of: confirm, matching: find.text('清除最近观看？')), findsOneWidget);
      expect(find.descendant(of: confirm, matching: find.text('「最近在看的视频」列表会被清空。')), findsOneWidget);
      await tester.tap(confirmButton('清除'));
      await tester.pumpAndSettle();
      expect(world.services.recents.items, isEmpty);
      expect(tester.widget<SettingsRow>(row('settings-recents')).enabled, isFalse);
    });

    testWidgets('清除日志 asks first, then clears the log files', (tester) async {
      await show(tester);
      await tapRow(tester, 'settings-logs');
      expect(find.descendant(of: confirm, matching: find.text('清除日志？')), findsOneWidget);
      expect(find.descendant(of: confirm, matching: find.text('手机上保存的调试日志会被删除，已发送到电脑的不受影响。')), findsOneWidget);
      await tester.tap(confirmButton('清除'));
      await tester.pumpAndSettle();
      expect(world.logFiles.clears, 1);
    });

    testWidgets('清除图片缓存 follows 清除日志 and shows what the stored pictures take', (tester) async {
      final pictures = FakeImageDiskCache(12345678);
      await show(tester, imageCache: pictures);
      final titles = [for (final row in tester.widgetList<SettingsRow>(find.byType(SettingsRow))) row.title];
      expect(titles.indexOf('清除图片缓存'), titles.indexOf('清除日志') + 1);
      expect(find.descendant(of: row('settings-images'), matching: find.text('11.8 MB')), findsOneWidget);
    });

    testWidgets('清除图片缓存 asks first, then clears the pictures and shows the new size', (tester) async {
      final pictures = FakeImageDiskCache(3 * 1024 * 1024);
      await show(tester, imageCache: pictures);
      expect(find.descendant(of: row('settings-images'), matching: find.text('3.0 MB')), findsOneWidget);
      await tapRow(tester, 'settings-images');
      expect(find.descendant(of: confirm, matching: find.text('清除图片缓存？')), findsOneWidget);
      expect(find.descendant(of: confirm, matching: find.text('保存在手机上的图片会被删除，再看到时会重新下载。')), findsOneWidget);
      expect(pictures.clears, 0);
      await tester.tap(confirmButton('清除'));
      await tester.pumpAndSettle();
      expect(pictures.clears, 1);
      expect(confirm, findsNothing);
      expect(find.descendant(of: row('settings-images'), matching: find.text('0.0 MB')), findsOneWidget);
    });

    testWidgets('清除图片缓存 and its 清除 press through accessibility', (tester) async {
      final semantics = tester.ensureSemantics();
      final pictures = FakeImageDiskCache(1024);
      await show(tester, imageCache: pictures);
      await tester.ensureVisible(row('settings-images'));
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel(RegExp('^清除图片缓存')));
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('清除'));
      await tester.pumpAndSettle();
      expect(pictures.clears, 1);
      semantics.dispose();
    });

    testWidgets('清除图片缓存 that fails is logged, not thrown', (tester) async {
      final logs = MemorySink();
      Logger.shared.add(logs);
      addTearDown(() => Logger.shared.remove(logs));
      final pictures = FakeImageDiskCache(1024)..clearError = const FileSystemException('Deletion failed');
      await show(tester, imageCache: pictures);
      await tapRow(tester, 'settings-images');
      await tester.tap(confirmButton('清除'));
      await tester.pumpAndSettle();
      expect(pictures.clears, 1);
      expect(confirm, findsNothing);
      final warning = logs.events.where((event) => event.msg == 'image cache not cleared').single;
      expect(warning.f['error']?.toJson(), 'FileSystemException');
    });

    testWidgets('取消 on 清除图片缓存 keeps the pictures', (tester) async {
      final pictures = FakeImageDiskCache(1024);
      await show(tester, imageCache: pictures);
      await tapRow(tester, 'settings-images');
      await tester.tap(confirmButton('取消'));
      await tester.pumpAndSettle();
      expect(pictures.clears, 0);
      expect(find.descendant(of: row('settings-images'), matching: find.text('0.0 MB')), findsOneWidget);
    });

    testWidgets('without pictures kept on the phone there is no 清除图片缓存', (tester) async {
      await show(tester);
      expect(row('settings-images'), findsNothing);
    });

    test('a size reads in MB with one decimal', () {
      expect(megabytesLabel(0), '0.0 MB');
      expect(megabytesLabel(12900000), '12.3 MB');
      expect(megabytesLabel(500 * 1024 * 1024), '500.0 MB');
    });

    testWidgets('取消, the dim and back each close a confirm with nothing done', (tester) async {
      await show(tester, account: const LoggedIn(name: '小明', vip: false));
      world.memory.markFailed('av1');
      world.services.recents.add(sampleRecent);
      await tester.pump();

      await tapRow(tester, 'settings-codec-memory');
      await tester.tap(confirmButton('取消'));
      await tester.pumpAndSettle();
      expect(confirm, findsNothing);

      await tapRow(tester, 'settings-recents');
      await tester.tapAt(const Offset(20, 900));
      await tester.pumpAndSettle();
      expect(confirm, findsNothing);

      await tapRow(tester, 'settings-logs');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(confirm, findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget, reason: 'back closed the confirm, not the page');

      await tapRow(tester, 'settings-logout');
      await tester.tap(confirmButton('取消'));
      await tester.pumpAndSettle();

      expect(world.memory.failedKinds, {'av1'});
      expect(world.services.recents.items, hasLength(1));
      expect(world.logFiles.clears, 0);
      expect(world.environment.logouts, 0);
      expect(world.environment.account, isA<LoggedIn>());
    });
  });

  group('开发者', () {
    testWidgets('has no row without a page', (tester) async {
      await show(tester);
      expect(row('settings-developer'), findsNothing);
    });

    testWidgets('pushes the page it is given', (tester) async {
      await show(tester, developerPage: (_) => const Scaffold(body: Text('开发者页面')));
      await tapRow(tester, 'settings-developer');
      expect(find.text('开发者页面'), findsOneWidget);
    });
  });

  testWidgets('the version and the BTR licence note', (tester) async {
    await show(tester);
    expect(find.descendant(of: row('settings-version'), matching: find.text('1.0.0 (10)')), findsOneWidget);
    expect(find.text('下载加速移植自 Bilibili 线程撕裂者（BTR），MIT 许可。'), findsOneWidget);
  });

  test('the build version reads as name (number)', () {
    expect(buildVersionLabel(), isNotEmpty);
  });

  group('退出登录', () {
    testWidgets('asks with 51\'s alert, then logs out and goes back home', (tester) async {
      await show(tester, account: const LoggedIn(name: '小明', vip: false));
      await tapRow(tester, 'settings-logout');
      expect(find.descendant(of: confirm, matching: find.text('退出登录')), findsOneWidget);
      expect(find.descendant(of: confirm, matching: find.byType(Checkbox)), findsNothing);
      expect(confirmButton('取消'), findsOneWidget);
      await tester.tap(confirmButton('确定'));
      await tester.pumpAndSettle();
      expect(world.environment.logouts, 1);
      expect(world.environment.account, isA<LoggedOut>());
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a logout that left the login in the keychain stays on 设置, says so and offers 退出登录 again',
        (tester) async {
      await show(tester, account: const LoggedIn(name: '小明', vip: false));
      world.environment.logoutError = const LogoutIncomplete();
      await tapRow(tester, 'settings-logout');
      await tester.tap(confirmButton('确定'));
      await tester.pump();
      expect(find.text('退出登录失败，请重试'), findsOneWidget);
      // The toast runs out.
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(world.environment.account, isA<LoggedOut>());
      expect(find.byKey(const ValueKey('settings-logout')), findsOneWidget);

      await tapRow(tester, 'settings-logout');
      await tester.tap(confirmButton('确定'));
      await tester.pumpAndSettle();
      expect(world.environment.logouts, 2);
      expect(find.byType(SettingsPage), findsNothing);
    });
  });

  testWidgets('an open confirm hides the rows behind it from accessibility', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    expect(find.semantics.byLabel('重置编码记忆'), findsOne);
    await tapRow(tester, 'settings-logs');
    expect(find.semantics.byLabel('重置编码记忆'), findsNothing);
    expect(find.semantics.byLabel('清除'), findsOne);
    await tester.tap(confirmButton('取消'));
    await tester.pumpAndSettle();
    expect(find.semantics.byLabel('重置编码记忆'), findsOne);
    semantics.dispose();
  });

  testWidgets('Reduce Motion: the confirm and the switch change at once', (tester) async {
    await show(tester, reduceMotion: true);
    await tester.tap(row('settings-logs'));
    await tester.pump();
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    final opacity = tester.widget<Opacity>(find.ancestor(of: confirm, matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 1);
    await tester.tap(confirmButton('取消'));
    await tester.pump();
    await tester.pump();
    expect(confirm, findsNothing);

    await tester.tap(row('settings-btr'));
    await tester.pump();
    expect(tester.widget<AnimatedContainer>(find.byKey(const ValueKey('settings-switch'))).duration, Duration.zero);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('every row presses through accessibility, as the Windows test driver does', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    tester.semantics.tap(find.semantics.byLabel('BTR 加速（默认）'));
    await tester.pumpAndSettle();
    expect(prefs.btr, isFalse);
    tester.semantics.tap(find.semantics.byLabel('清除日志'));
    await tester.pumpAndSettle();
    tester.semantics.tap(find.semantics.byLabel('清除'));
    await tester.pumpAndSettle();
    expect(world.logFiles.clears, 1);
    semantics.dispose();
  });

  test('the node choice is saved to player_prefs.json and read back', () async {
    final folder = await Directory.systemTemp.createTemp('settings_prefs');
    addTearDown(() => folder.delete(recursive: true));
    final path = '${folder.path}${Platform.pathSeparator}player_prefs.json';
    final saved = await PlayerPrefs.load(path);
    expect(saved.node, NodeChoice.auto);
    saved.node = NodeChoice.mainland;
    await saved.settle();
    expect(await File(path).readAsString(), contains('"node":"mainland"'));
    final read = await PlayerPrefs.load(path);
    expect(read.node, NodeChoice.mainland);
    expect(read.node.mode, isA<MainlandNodes>());
  });
}
