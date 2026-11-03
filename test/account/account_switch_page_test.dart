import 'dart:async';

import 'package:bilifast/account/account_switch_page.dart';
import 'package:bilifast/account/account_switch_theme.dart';
import 'package:bilifast/account/account_vault.dart';
import 'package:bilifast/account/login_page.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/settings/settings_page.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:bilifast/shared/remote_image.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../settings/settings_fakes.dart';
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';

class _SwitchEnvironment extends FakeEnvironment {
  _SwitchEnvironment() : super(const LoggedIn(name: '测试账号一', vip: false));

  List<SavedAccount> profiles = [
    SavedAccount(mid: 1, name: '测试账号一', cookies: const {}),
    SavedAccount(mid: 2, name: '测试账号二', cookies: const {}),
  ];
  int? active = 1;
  final switches = <int>[];
  final removals = <int>[];
  Completer<void>? switchGate;
  Object? switchError;
  Object? removeError;

  @override
  bool get hasAccountVault => true;
  @override
  bool get accountTransitioning => false;
  @override
  List<SavedAccount> get savedAccounts => profiles;
  @override
  int? get activeAccountMid => active;
  @override
  bool get pcLogin => false;

  @override
  Future<void> switchAccount(int mid) async {
    switches.add(mid);
    await switchGate?.future;
    if (switchError case final error?) throw error;
    active = mid;
    notifyListeners();
  }

  @override
  Future<void> removeAccount(int mid) async {
    removals.add(mid);
    if (removeError case final error?) throw error;
    profiles = profiles.where((account) => account.mid != mid).toList();
    if (active == mid) active = null;
    notifyListeners();
  }
}

void main() {
  late _SwitchEnvironment environment;
  late AppServices services;

  Future<void> show(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool settings = false,
  }) async {
    environment = _SwitchEnvironment();
    final systemFont = BiliFonts.family == BiliFonts.system;
    services = AppServices(
      environment: environment,
      playback: AppPlayback(() => Completer<PlaybackController>().future),
      recents: await RecentStore.load(null),
      pageApi: FakePageApi(),
      fonts: FontStore.memory()..select(systemFont ? FontChoice.system : FontChoice.miSans),
    );
    addTearDown(services.playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: biliTheme(brightness),
        builder: (context, child) =>
            AppScope(services: services, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () => unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RepaintBoundary(
                      key: const ValueKey('switch-shot'),
                      child: settings
                          ? const SettingsPage()
                          : const AccountSwitchPage(),
                    ),
                  ),
                ),
              ),
              child: const Text('root'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  Finder row(int mid) => find.byKey(ValueKey('switch-account-$mid'));

  testWidgets(
    'opening lists saved accounts and the selected account without switching',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester);
      expect(find.text('账号切换'), findsOneWidget);
      expect(find.text('点击头像切换账号'), findsOneWidget);
      expect(find.byType(RemoteImage), findsNWidgets(2));
      expect(find.byKey(const ValueKey('switch-current-1')), findsOneWidget);
      expect(tester.getSize(row(1)).height, AccountSwitchTheme.rowHeight);
      expect(find.bySemanticsLabel('测试账号一，当前账号'), findsOneWidget);
      expect(environment.switches, isEmpty);
      await tester.tap(row(1));
      await tester.pumpAndSettle();
      expect(environment.switches, isEmpty);
      await tester.tap(find.byKey(const ValueKey('account-switch-back')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSwitchPage), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'switching is single flight and returns to root only after success',
    (tester) async {
      await show(tester);
      environment.switchGate = Completer<void>();
      await tester.tap(row(2));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('account-switch-progress')),
        findsOneWidget,
      );
      await tester.tap(row(1));
      await tester.tap(find.byKey(const ValueKey('account-switch-manage')));
      await tester.pump();
      expect(environment.switches, [2]);
      expect(find.text('完成'), findsNothing);
      environment.switchGate!.complete();
      await tester.pumpAndSettle();
      expect(environment.active, 2);
      expect(find.byType(AccountSwitchPage), findsNothing);
      expect(find.text('root'), findsOneWidget);
    },
  );

  testWidgets(
    'failed switch keeps current account, displays the reason and permits retry',
    (tester) async {
      await show(tester);
      environment.switchError = const AccountSwitchFailure('账号确认失败，请重试');
      await tester.tap(row(2));
      await tester.pumpAndSettle();
      expect(environment.active, 1);
      expect(find.text('账号确认失败，请重试'), findsOneWidget);
      expect(find.byType(AccountSwitchPage), findsOneWidget);
      environment.switchError = null;
      await tester.tap(row(2));
      await tester.pumpAndSettle();
      expect(environment.switches, [2, 2]);
      expect(environment.active, 2);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'add opens login and cancel leaves saved and active accounts intact',
    (tester) async {
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('account-switch-add')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        tester.widget<LoginPage>(find.byType(LoginPage)).expectedMid,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('login-close')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSwitchPage), findsOneWidget);
      expect(environment.active, 1);
      expect(environment.profiles.length, 2);
      expect(environment.switches, isEmpty);
    },
  );

  testWidgets(
    'expired account reauthenticates its uid rather than attempting a switch',
    (tester) async {
      await show(tester);
      environment.profiles[1] = environment.profiles[1].copyWith(expired: true);
      environment.notifyListeners();
      await tester.pump();
      expect(find.text('登录已失效，重新登录'), findsOneWidget);
      await tester.tap(row(2));
      await tester.pumpAndSettle();
      expect(tester.widget<LoginPage>(find.byType(LoginPage)).expectedMid, 2);
      expect(environment.switches, isEmpty);
      await tester.tap(find.byKey(const ValueKey('login-close')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'manage confirms removal, cancellation preserves it and inactive removal stays here',
    (tester) async {
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('account-switch-manage')));
      await tester.pumpAndSettle();
      expect(find.text('完成'), findsOneWidget);
      await tester.tap(row(2));
      await tester.pump();
      expect(find.text('移除此账号？'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-confirm-取消')));
      await tester.pumpAndSettle();
      expect(environment.removals, isEmpty);
      await tester.tap(row(2));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('settings-confirm-移除')));
      await tester.pumpAndSettle();
      expect(environment.removals, [2]);
      expect(environment.active, 1);
      expect(row(2), findsNothing);
      expect(find.byType(AccountSwitchPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-switch-manage')));
      await tester.pumpAndSettle();
      expect(find.text('管理'), findsOneWidget);
    },
  );

  testWidgets('removing the active account returns to guest root', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('account-switch-manage')));
    await tester.pump();
    await tester.tap(row(1));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-confirm-移除')));
    await tester.pumpAndSettle();
    expect(environment.active, isNull);
    expect(environment.profiles.single.mid, 2);
    expect(find.byType(AccountSwitchPage), findsNothing);
  });

  testWidgets(
    'settings keeps the switch entry for expired and logged-out accounts',
    (tester) async {
      await show(tester, settings: true);
      for (final state in [const LoginExpired(), const LoggedOut()]) {
        environment.account = state;
        await tester.pump();
        expect(
          find.byKey(const ValueKey('settings-switch-account')),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('settings-switch-account')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSwitchPage), findsOneWidget);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'reference layout renders in $brightness on phone and iPad without overflow',
      (tester) async {
        final previousFont = BiliFonts.family;
        addTearDown(() => BiliFonts.family = previousFont);
        BiliFonts.family = BiliFonts.system;
        await tester.runAsync(() async {
          await loadSystemFontStandIns();
          await loadIconFonts();
        });
        showAsPhone(tester);
        await show(tester, brightness: brightness);
      expect(BiliFonts.family, BiliFonts.system);
        await saveShot(
          tester,
          find.byKey(const ValueKey('switch-shot')),
          '.dart_tool/account-shots/switch-${brightness.name}-phone.png',
        );
        expect(tester.takeException(), isNull);
        showAsPad(tester);
        await tester.pumpAndSettle();
        await saveShot(
          tester,
          find.byKey(const ValueKey('switch-shot')),
          '.dart_tool/account-shots/switch-${brightness.name}-pad.png',
          pixelRatio: 2,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
