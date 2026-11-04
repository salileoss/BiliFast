import 'dart:async';
import 'dart:convert';

import 'package:bili_core/api.dart';
import 'package:bilifast/account/account_vault.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fake_web_cookies.dart';
import 'fake_keychain.dart';

SavedAccount profile(int mid, {bool token = true}) => SavedAccount(
  mid: mid, name: '账号$mid', cookies: {
    'SESSDATA': 'session-$mid', 'bili_jct': 'csrf-$mid', 'buvid3': 'b3', 'buvid4': 'b4',
    'only-$mid': 'own',
  },
  appToken: token ? AppToken(accessToken: 'access-$mid', refreshToken: 'refresh-$mid', mid: mid,
      expiresAt: DateTime.now().add(const Duration(days: 180))) : null,
);

class _Vault extends MemoryAccountVaultStore {
  _Vault([super.vault]);
  bool saveOk = true;
  bool unreadable = false;
  Completer<void>? saving;
  int writes = 0;
  @override
  Future<AccountVaultLoad> load() async => unreadable ? const AccountVaultLoadFailed(-1) : super.load();
  @override
  Future<bool> save(AccountVault vault) async {
    writes++;
    await saving?.future;
    return saveOk && await super.save(vault);
  }
}

class _Legacy extends FakeKeychain {
  _Legacy(super.next);
  int deletes = 0;
  @override
  Future<void> deleteCookies() async { deletes++; }
}

class _Http implements HTTPTransport {
  final requests = <HTTPRequest>[];
  final expired = <int>{};
  final failed = <int>{};
  final gates = <int, Completer<void>>{};
  @override
  Future<HTTPResponse> send(HTTPRequest request) async {
    requests.add(request);
    final session = CookieJar.parse(request.headers['Cookie'] ?? '')['SESSDATA'] ?? '';
    final mid = int.tryParse(session.split('-').last) ?? 0;
    await gates[mid]?.future;
    if (failed.contains(mid)) throw const BiliNetworkError('offline');
    final data = request.url.path == '/x/frontend/finger/spi'
        ? <String, Object?>{'b_3': 'b3', 'b_4': 'b4'}
        : <String, Object?>{'isLogin': mid > 0 && !expired.contains(mid), 'mid': mid,
            'uname': '账号$mid', 'vipStatus': mid == 1 ? 1 : 0};
    return HTTPResponse(status: 200, headers: const {}, body: utf8.encode(jsonEncode({'code': 0, 'data': data})),
        finalURL: request.url);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Vault vault;
  late _Http http;
  late _Legacy legacy;
  late AppEnvironment environment;

  Future<void> load({AccountVault? initial, bool absent = false, bool unreadable = false,
      CookieLoad legacyCookies = const NoStoredCookies(), bool declined = false}) async {
    vault = _Vault(absent ? null : initial ?? AccountVault(activeMid: 1, accounts: {1: profile(1), 2: profile(2)}))
      ..unreadable = unreadable;
    http = _Http();
    legacy = _Legacy(legacyCookies);
    environment = await AppEnvironment.load(keychain: legacy, accountStore: vault, http: http,
        webCookies: FakeWebCookies(), legacyAuthDeclined: declined);
    addTearDown(environment.dispose);
  }

  test('restores one selected session and lists saved accounts without network calls', () async {
    await load();
    expect(environment.activeAccountMid, 1);
    expect(environment.savedAccounts.map((account) => account.mid), [1, 2]);
    expect(environment.client.appToken?.mid, 1);
    expect(http.requests, isEmpty);
    await environment.refreshAccount();
    expect(environment.mid, 1);
  });

  test('A to B to A replaces whole cookies and restores each account token without login/logout', () async {
    await load();
    await environment.refreshAccount();
    final first = environment.sessionGeneration;
    await environment.switchAccount(2);
    expect(environment.mid, 2);
    expect(environment.cookies.all, profile(2).cookies);
    expect(environment.cookies.value('only-1'), isNull);
    expect(environment.client.appToken?.mid, 2);
    expect(vault.vault?.accounts[1]?.appToken?.mid, 1);
    await environment.switchAccount(1);
    expect(environment.mid, 1);
    expect(environment.client.appToken?.mid, 1);
    expect(environment.sessionGeneration, first + 2);
    expect(http.requests.every((request) => request.url.path == '/x/web-interface/nav'), isTrue);
  });

  test('an expired or offline target leaves the working identity and token intact', () async {
    await load();
    await environment.refreshAccount();
    http.expired.add(2);
    await expectLater(environment.switchAccount(2), throwsA(isA<AccountSwitchFailure>()));
    expect(environment.activeAccountMid, 1);
    expect(environment.client.appToken?.mid, 1);
    expect(environment.savedAccounts.last.expired, isTrue);
    http.expired.clear();
    http.failed.add(2);
    await expectLater(environment.switchAccount(2), throwsA(isA<AccountSwitchFailure>()));
    expect(vault.vault?.activeMid, 1);
    expect(environment.mid, 1);
  });

  test('refused durable selection never publishes a new session', () async {
    await load();
    await environment.refreshAccount();
    final generation = environment.sessionGeneration;
    vault.saveOk = false;
    await expectLater(environment.switchAccount(2), throwsA(isA<AccountSwitchFailure>()));
    expect(environment.mid, 1);
    expect(environment.sessionGeneration, generation);
    expect(vault.vault?.activeMid, 1);
    expect(environment.accountTransitioning, isFalse);
  });

  test('adding and reauthenticating deduplicates verified uid and preserves other accounts', () async {
    await load();
    await environment.refreshAccount();
    expect(await environment.didLogin(profile(2).cookies), isTrue);
    expect(environment.savedAccounts.length, 2);
    expect(environment.mid, 2);
    expect(vault.vault?.accounts[1]?.cookies, profile(1).cookies);
    await expectLater(environment.didLogin(profile(1).cookies, expectedMid: 2),
        throwsA(isA<AccountSwitchFailure>().having((error) => error.requiresLogin, 'fresh login', isTrue)));
    expect(environment.mid, 2);
  });

  test('closing a pending login discards its late validation without changing storage', () async {
    await load();
    await environment.refreshAccount();
    final held = Completer<void>();
    http.gates[2] = held;
    var current = true;
    final login = environment.didLogin(profile(2).cookies, isCurrent: () => current);
    await pumpEventQueue();
    current = false;
    held.complete();
    expect(await login, isFalse);
    expect(environment.mid, 1);
    expect(vault.vault?.activeMid, 1);
  });

  test('a duplicate transition is refused while target validation is pending', () async {
    await load();
    await environment.refreshAccount();
    http.gates[2] = Completer<void>();
    final switching = environment.switchAccount(2);
    await pumpEventQueue();
    await expectLater(environment.switchAccount(2), throwsA(isA<AccountSwitchFailure>()));
    http.gates[2]!.complete();
    await switching;
    expect(environment.mid, 2);
  });

  test('logout removes only the active credentials and leaves an authoritative guest vault', () async {
    await load();
    await environment.refreshAccount();
    await environment.logout();
    expect(environment.account, isA<LoggedOut>());
    expect(environment.activeAccountMid, isNull);
    expect(environment.client.appToken, isNull);
    expect(vault.vault?.activeMid, isNull);
    expect(vault.vault?.accounts.keys, [2]);
    await environment.switchAccount(2);
    expect(environment.mid, 2);
  });

  test('removing an inactive account preserves selected identity', () async {
    await load();
    await environment.refreshAccount();
    await environment.removeAccount(2);
    expect(environment.mid, 1);
    expect(vault.vault?.accounts.keys, [1]);
    expect(vault.vault?.activeMid, 1);
  });

  test('a stale token writer cannot overwrite the newly selected account', () async {
    await load();
    await environment.refreshAccount();
    final generation = environment.sessionGeneration;
    await environment.switchAccount(2);
    expect(await environment.saveAppToken(profile(1).appToken!, generation: generation), isFalse);
    await environment.deleteAppToken(generation: generation);
    expect(vault.vault?.accounts[2]?.appToken?.mid, 2);
    expect(vault.vault?.accounts[1]?.appToken?.mid, 1);
  });

  test('legacy migration verifies uid and reads back before deleting the original', () async {
    await load(absent: true, legacyCookies: StoredCookies(profile(1).cookies));
    await environment.refreshAccount();
    expect(environment.mid, 1);
    expect(vault.vault?.activeMid, 1);
    expect(vault.vault?.accounts[1]?.cookies, profile(1).cookies);
    expect(legacy.deletes, 1);
  });

  test('failed migration keeps legacy credentials usable without requesting login', () async {
    await load(absent: true, legacyCookies: StoredCookies(profile(1).cookies));
    vault.saveOk = false;
    await environment.refreshAccount();
    expect(environment.mid, 1);
    expect(vault.vault, isNull);
    expect(legacy.deletes, 0);
  });

  test('empty or unreadable new vault never resurrects a legacy login', () async {
    await load(initial: AccountVault(), legacyCookies: StoredCookies(profile(1).cookies));
    expect(environment.cookies.value('SESSDATA'), isNull);
    await environment.refreshAccount();
    expect(environment.account, isA<LoggedOut>());
    await load(unreadable: true, legacyCookies: StoredCookies(profile(1).cookies));
    await environment.refreshAccount();
    expect(environment.account, isA<AccountUnknown>());
    expect(environment.loginUnreadable, isTrue);
    await expectLater(environment.didLogin(profile(2).cookies), throwsA(isA<AccountSwitchFailure>()));
    expect(vault.writes, 0);
    expect(legacy.deletes, 0);
  });

  test('a later successful vault read restores the selected account without another login', () async {
    await load(unreadable: true, legacyCookies: StoredCookies(profile(2).cookies));
    await environment.refreshAccount();
    expect(environment.account, isA<AccountUnknown>());
    vault.unreadable = false;
    await environment.refreshAccount();
    expect(environment.account, isA<LoggedIn>());
    expect(environment.mid, 1);
    expect(environment.client.appToken?.mid, 1);
    expect(environment.cookies.value('SESSDATA'), 'session-1');
    expect(legacy.deletes, 0);
  });

  test('migration preserves the existing declined authorization preference', () async {
    await load(absent: true, legacyCookies: StoredCookies(profile(1).cookies), declined: true);
    expect(environment.appAuthDeclined, isTrue);
    await environment.refreshAccount();
    expect(vault.vault?.accounts[1]?.authDeclined, isTrue);
    expect(environment.appAuthDeclined, isTrue);
    await environment.didLogin(profile(2).cookies);
    expect(environment.appAuthDeclined, isFalse);
  });

  test('credential updates accepted before publication remain bound to the outgoing owner', () async {
    await load();
    await environment.refreshAccount();
    await pumpEventQueue();
    final generation = environment.sessionGeneration;
    vault.saving = Completer<void>();
    final switching = environment.switchAccount(2);
    await pumpEventQueue();
    final renewed = AppToken(accessToken: 'renewed-1', refreshToken: 'renewed-refresh-1', mid: 1,
        expiresAt: DateTime.now().add(const Duration(days: 180)));
    environment.client.appToken = renewed;
    final saving = environment.saveAppToken(renewed, generation: generation);
    environment.cookies.set('bili_ticket', 'rotated-1');
    vault.saving!.complete();
    await switching;
    expect(await saving, isTrue);
    await pumpEventQueue();
    expect(vault.vault?.accounts[1]?.appToken?.accessToken, 'renewed-1');
    expect(vault.vault?.accounts[1]?.cookies['bili_ticket'], 'rotated-1');
    expect(environment.client.appToken?.mid, 2);
    expect(environment.cookies.value('bili_ticket'), isNull);
  });

  test('an expired active session is marked for reauthentication in the account list', () async {
    await load();
    http.expired.add(1);
    await environment.refreshAccount();
    expect(environment.account, isA<LoginExpired>());
    expect(environment.savedAccounts.first.expired, isTrue);
    expect(environment.activeAccountMid, 1);
  });

  test('a saved identity whose cookies identify another uid cannot send authenticated web calls', () async {
    await load(initial: AccountVault(activeMid: 1, accounts: {
      1: SavedAccount(mid: 1, name: '账号1', cookies: profile(2).cookies),
    }));
    await environment.refreshAccount();
    expect(environment.account, isA<LoginExpired>());
    expect(environment.activeAccountMid, 1);
    expect(environment.mid, isNull);
    expect(environment.cookies.value('SESSDATA'), isNull);
    expect(environment.client.appToken, isNull);
    expect(environment.savedAccounts.first.expired, isTrue);
  });
}
