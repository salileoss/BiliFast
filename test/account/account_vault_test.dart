import 'dart:convert';

import 'package:bili_core/api.dart';
import 'package:bilifast/account/account_vault.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final token = AppToken(
    accessToken: 'fixture-access', refreshToken: 'fixture-refresh', mid: 101,
    expiresAt: DateTime.utc(2030),
  );
  SavedAccount account([int mid = 101]) => SavedAccount(
    mid: mid, name: '测试账号$mid', face: 'https://example.invalid/face.png', vip: true,
    cookies: {'SESSDATA': 'fixture-session-$mid', 'bili_jct': 'fixture-csrf'},
    appToken: mid == 101 ? token : null, authDeclined: true, expired: true,
  );

  test('versioned codec retains each owner and the selected account', () {
    final source = AccountVault(activeMid: 101, accounts: {101: account(), 202: account(202)});
    final restored = decodeAccountVault(encodeAccountVault(source));
    expect(restored.toJson(), source.toJson());
    expect(restored.accounts[101]!.appToken, token);
    expect(restored.accounts[202]!.appToken, isNull);
    expect(restored.accounts[101]!.authDeclined, isTrue);
    expect(restored.accounts[101]!.expired, isTrue);
  });

  test('an empty authoritative vault survives a round trip', () {
    final restored = decodeAccountVault(encodeAccountVault(AccountVault()));
    expect(restored.activeMid, isNull);
    expect(restored.accounts, isEmpty);
  });

  test('a future version has a distinct failure', () {
    expect(() => decodeAccountVault('{"version":2,"active_mid":null,"accounts":{}}'),
        throwsA(isA<UnsupportedAccountVaultVersion>()));
  });

  test('malformed vaults and unmatched active ids are rejected', () {
    for (final json in <Object?>[
      null, [], {}, {'version': '1'},
      {'version': 1, 'active_mid': 101, 'accounts': <String, Object?>{}},
      {'version': 1, 'active_mid': '101', 'accounts': <String, Object?>{}},
      {'version': 1, 'active_mid': null, 'accounts': <Object?>[]},
    ]) {
      expect(() => AccountVault.fromJson(json), throwsA(isA<FormatException>()));
    }
  });

  test('an account key must be its canonical positive uid', () {
    for (final key in ['202', '0101', '-101']) {
      expect(() => AccountVault.fromJson({
        'version': 1, 'active_mid': null, 'accounts': {key: account().toJson()},
      }), throwsA(isA<FormatException>()));
    }
    expect(() => encodeAccountVault(AccountVault(accounts: {202: account()})),
        throwsA(isA<FormatException>()));
  });

  test('invalid fields and another account\'s app token cannot decode', () {
    for (final patch in <Map<String, Object?>>[
      {'mid': 0}, {'mid': '101'}, {'name': null}, {'face': 5},
      {'cookies': []}, {'cookies': {'SESSDATA': 8}}, {'cookies': {'': 'value'}},
      {'vip': 'true'}, {'expired': null}, {'auth_declined': 0},
      {'app_token': {...token.toJson(), 'mid': 202}},
    ]) {
      expect(() => SavedAccount.fromJson({...account().toJson(), ...patch}), throwsA(isA<Exception>()));
    }
    expect(() => account(202).copyWith(appToken: token).toJson(), throwsA(isA<FormatException>()));
  });

  test('collection and credential maps do not alias mutable caller maps', () {
    final cookies = {'SESSDATA': 'fixture-session'};
    final saved = SavedAccount(mid: 1, name: '测试', cookies: cookies);
    final entries = {1: saved};
    final vault = AccountVault(activeMid: 1, accounts: entries);
    cookies.clear();
    entries.clear();
    expect(vault.accounts[1]!.cookies, {'SESSDATA': 'fixture-session'});
    expect(() => saved.cookies.clear(), throwsUnsupportedError);
    expect(() => vault.accounts.clear(), throwsUnsupportedError);
  });

  test('copyWith can clear a token without changing the original', () {
    final original = account();
    final updated = original.copyWith(clearToken: true, authDeclined: false, expired: false);
    expect(updated.appToken, isNull);
    expect(updated.authDeclined, isFalse);
    expect(updated.expired, isFalse);
    expect(original.appToken, token);
  });

  test('models never print credentials in error reports', () {
    final vault = AccountVault(activeMid: 101, accounts: {101: account()});
    final descriptions = '${vault.accounts.values} $vault';
    expect(descriptions, isNot(contains('fixture')));
    final decoded = jsonDecode(encodeAccountVault(vault));
    expect(decoded, isA<Map<String, Object?>>());
    try {
      decodeAccountVault('fixture-secret-json');
      fail('malformed document must fail');
    } on FormatException catch (error) {
      expect('$error', isNot(contains('fixture-secret-json')));
      expect(error.source, isNull);
    }
  });

  test('memory store distinguishes absence from a saved empty collection', () async {
    final store = MemoryAccountVaultStore();
    expect(await store.load(), isA<NoAccountVault>());
    expect(await store.save(AccountVault()), isTrue);
    expect(await store.load(), isA<StoredAccountVault>());
  });
}
