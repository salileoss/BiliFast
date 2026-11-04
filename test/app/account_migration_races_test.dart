import 'dart:async';
import 'dart:convert';

import 'package:bili_core/api.dart';
import 'package:bilifast/account/account_vault.dart';
import 'package:bilifast/account/app_auth.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/account/web_cookies.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

AppToken token(String access, {int days = 10}) => AppToken(accessToken: access, refreshToken: '$access-refresh', mid: 1,
    expiresAt: DateTime.now().add(Duration(days: days)));

SavedAccount account(int mid, {AppToken? appToken}) => SavedAccount(mid: mid, name: 'test-$mid',
    cookies: {'SESSDATA': 'session-$mid', 'bili_jct': 'csrf-$mid', 'buvid3': 'b3', 'buvid4': 'b4'}, appToken: appToken);

class Vault extends MemoryAccountVaultStore {
  Vault([super.vault]);
  Completer<void>? saving;
  bool wrote = false;
  @override
  Future<bool> save(AccountVault vault) async {
    wrote = true;
    await saving?.future;
    return super.save(vault);
  }
}

class Legacy implements KeychainStore {
  Legacy(this.cookies);
  Map<String, String> cookies;
  String? appToken;
  @override
  Future<CookieLoad> loadCookies() async => StoredCookies(cookies);
  @override
  Future<bool> saveCookies(Map<String, String> cookies) async { this.cookies = cookies; return true; }
  @override
  Future<void> deleteCookies() async { cookies = {}; }
  @override
  Future<String?> loadAppToken() async => appToken;
  @override
  Future<bool> saveAppToken(String token) async { appToken = token; return true; }
  @override
  Future<void> deleteAppToken() async { appToken = null; }
}

class Http implements HTTPTransport {
  Completer<void>? renewal;
  Completer<void>? candidate;
  @override
  Future<HTTPResponse> send(HTTPRequest request) async {
    Map<String, Object?> data;
    if (request.url.path == '/x/passport-login/oauth2/refresh_token') {
      await renewal?.future;
      data = {'mid': 1, 'access_token': 'renewed', 'refresh_token': 'new-refresh', 'expires_in': 15552000};
    } else {
      final cookie = CookieJar.parse(request.headers['Cookie'] ?? '')['SESSDATA'];
      final mid = cookie == 'session-2' ? 2 : 1;
      if (mid == 2) {
        await candidate?.future;
        throw const BiliNetworkError('offline');
      }
      data = {'isLogin': true, 'mid': mid, 'uname': 'test-$mid'};
    }
    return HTTPResponse(status: 200, headers: {}, body: utf8.encode(jsonEncode({'code': 0, 'data': data})), finalURL: request.url);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migration captures a cookie/token rotation while its first vault save waits', () async {
    final legacy = Legacy(account(1).cookies)..appToken = jsonEncode(token('old').toJson());
    final vault = Vault()..saving = Completer<void>();
    final env = await AppEnvironment.load(keychain: legacy, accountStore: vault, http: Http(), webCookies: const NoWebCookies());
    addTearDown(env.dispose);
    final check = env.refreshAccount();
    await pumpEventQueue();
    expect(vault.wrote, isTrue);
    env.cookies.set('bili_ticket', 'rotated');
    env.client.appToken = token('renewed');
    expect(await env.saveAppToken(env.client.appToken!, generation: env.sessionGeneration), isTrue);
    vault.saving!.complete();
    await check;
    expect(vault.vault!.accounts[1]!.cookies['bili_ticket'], 'rotated');
    expect(vault.vault!.accounts[1]!.appToken?.accessToken, 'renewed');
  });

  test('an A renewal survives a pending B switch that later fails', () async {
    final vault = Vault(AccountVault(activeMid: 1, accounts: {1: account(1, appToken: token('old')), 2: account(2)}));
    final http = Http()..renewal = Completer<void>()..candidate = Completer<void>();
    final env = await AppEnvironment.load(keychain: Legacy({}), accountStore: vault, http: http, webCookies: const NoWebCookies());
    addTearDown(env.dispose);
    final auth = TokenAppAuth(environment: env, navigator: GlobalKey<NavigatorState>(), devicePath: () => null);
    addTearDown(auth.dispose);
    await auth.start();
    await env.refreshAccount();
    final change = env.switchAccount(2);
    final failed = expectLater(change, throwsA(isA<AccountSwitchFailure>()));
    await pumpEventQueue();
    expect(env.accountTransitioning, isTrue);
    http.renewal!.complete();
    await pumpEventQueue();
    http.candidate!.complete();
    await failed;
    expect(env.activeAccountMid, 1);
    expect(env.client.appToken?.accessToken, 'renewed');
    expect(vault.vault!.accounts[1]!.appToken?.accessToken, 'renewed');
  });
}
