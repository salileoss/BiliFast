import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bilifast/account/account_switch_page.dart';
import 'package:bilifast/account/account_vault.dart';
import 'package:bilifast/account/app_auth.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/account/web_cookies.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../playback/fakes.dart';

void main() {
  testWidgets('the new account authorization prompt survives returning from the switcher', (tester) async {
    SavedAccount account(int mid, {AppToken? token}) => SavedAccount(mid: mid, name: '账号$mid', cookies: {
      ...Canned.cookies, 'SESSDATA': 'session-$mid',
    }, appToken: token);
    final first = account(12345, token: AppToken(accessToken: 'made-up-access', refreshToken: 'made-up-refresh',
        mid: 12345, expiresAt: DateTime.now().add(const Duration(days: 180))));
    final vault = MemoryAccountVaultStore(AccountVault(activeMid: 12345,
        accounts: {12345: first, 67890: account(67890)}));
    final http = Canned.http();
    final environment = await AppEnvironment.load(keychain: const NoKeychainStore(), accountStore: vault,
        http: http, webCookies: const NoWebCookies());
    await environment.refreshAccount();
    final navigator = GlobalKey<NavigatorState>();
    final auth = TokenAppAuth(environment: environment, navigator: navigator, devicePath: () => null);
    final services = AppServices(environment: environment, navigator: navigator, appAuth: auth,
        playback: AppPlayback(() => Completer<PlaybackController>().future),
        recents: await RecentStore.load(null), pageApi: FakePageApi());
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator,
        builder: (context, child) => AppScope(services: services, child: child!),
        home: const Scaffold(body: Text('root'))));
    await auth.start();
    navigator.currentState!.push<void>(MaterialPageRoute(builder: (_) => const AccountSwitchPage()));
    await tester.pumpAndSettle();
    http.routes[Canned.navPath] = (200, Canned.navLoggedIn.replaceAll('12345', '67890'));
    await tester.tap(find.byKey(const ValueKey('switch-account-67890')));
    await tester.pumpAndSettle();
    expect(environment.mid, 67890);
    expect(find.byType(AccountSwitchPage), findsNothing);
    expect(find.byKey(const ValueKey('app-auth-prompt')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-confirm-取消')));
    await tester.pumpAndSettle();
    expect(vault.vault?.accounts[67890]?.authDeclined, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    services.dispose();
    services.playback.dispose();
    environment.dispose();
  });
}
