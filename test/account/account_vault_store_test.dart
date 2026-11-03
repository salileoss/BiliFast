import 'dart:convert';
import 'dart:io';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/account_vault.dart';
import 'package:bilifast/account/account_vault_store.dart';
import 'package:bilifast/account/dpapi_keychain_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AccountVault vault() => AccountVault(activeMid: 101, accounts: {
    101: SavedAccount(mid: 101, name: '测试', cookies: {'SESSDATA': 'fixture-session', 'bili_jct': 'fixture-csrf'}),
  });

  group('Keychain account vault', () {
    const channel = MethodChannel('bilifast/keychain');
    late MemorySink logs;
    late ChannelAccountVaultStore store;
    Object? Function(MethodCall call) answer = (_) => null;

    setUp(() {
      logs = MemorySink();
      final logger = Logger(session: 'test')..add(logs);
      store = ChannelAccountVaultStore(channel, logger);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => answer(call));
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('absence, refusal and a valid document remain distinct', () async {
      answer = (call) {
        expect(call.method, 'loadAccountVault');
        return {'status': 'notFound'};
      };
      expect(await store.load(), isA<NoAccountVault>());
      answer = (_) => {'status': 'failed', 'code': -25308};
      expect((await store.load() as AccountVaultLoadFailed).status, -25308);
      answer = (_) => {'status': 'vault', 'vault': encodeAccountVault(vault())};
      expect((await store.load() as StoredAccountVault).vault.toJson(), vault().toJson());
    });

    test('malformed data and a future schema do not read as empty', () async {
      for (final payload in [null, 4, 'fixture-secret-json', '{"version":1,"accounts":[]}']) {
        answer = (_) => {'status': 'vault', 'vault': payload};
        expect((await store.load() as AccountVaultLoadFailed).status, -2);
      }
      answer = (_) => {'status': 'vault', 'vault': '{"version":99}'};
      expect((await store.load() as AccountVaultLoadFailed).status, -3);
    });

    test('missing channel and thrown read errors remain failures without leaking their text', () async {
      answer = (_) => throw PlatformException(code: 'keychain', message: 'fixture-secret-json');
      expect((await store.load() as AccountVaultLoadFailed).status, -1);
      expect(logs.events.map((event) => event.encode()).join(), isNot(contains('fixture-secret-json')));
      answer = (_) => null;
      expect(await store.load(), isA<AccountVaultLoadFailed>());
    });

    test('save sends one complete versioned document, including an empty vault', () async {
      AccountVault? captured;
      answer = (call) {
        expect(call.method, 'saveAccountVault');
        final arguments = call.arguments! as Map<Object?, Object?>;
        captured = decodeAccountVault(arguments['vault']! as String);
        return {'ok': true};
      };
      expect(await store.save(vault()), isTrue);
      expect(captured!.toJson(), vault().toJson());
      expect(await store.save(AccountVault()), isTrue);
      expect(captured!.accounts, isEmpty);
      expect(captured!.activeMid, isNull);
    });

    test('failed saves report no account, cookie or channel exception text', () async {
      answer = (_) => {'ok': false, 'code': -25308};
      expect(await store.save(vault()), isFalse);
      answer = (_) => throw PlatformException(code: 'keychain', message: 'fixture-session');
      expect(await store.save(vault()), isFalse);
      final log = logs.events.map((event) => event.encode()).join();
      expect(log, isNot(contains('fixture')));
      expect(log, isNot(contains('测试')));
    });
  });

  group('DPAPI account vault', skip: !Platform.isWindows, () {
    late Directory directory;
    late String path;
    late DpapiAccountVaultStore store;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('account_vault_test_');
      path = '${directory.path}/support/accounts.bin';
      store = DpapiAccountVaultStore(path);
    });
    tearDown(() => directory.deleteSync(recursive: true));

    test('round trip encrypts and replaces the whole collection', () async {
      expect(await store.load(), isA<NoAccountVault>());
      expect(await store.save(vault()), isTrue);
      expect((await store.load() as StoredAccountVault).vault.toJson(), vault().toJson());
      final bytes = File(path).readAsBytesSync();
      expect(utf8.decode(bytes, allowMalformed: true), isNot(contains('fixture-session')));
      expect(File('$path.tmp').existsSync(), isFalse);
      expect(await store.save(AccountVault()), isTrue);
      expect(File(path).existsSync(), isTrue, reason: 'empty vault is authoritative');
      expect((await store.load() as StoredAccountVault).vault.accounts, isEmpty);
    });

    test('corrupt encrypted files are left intact and report failure', () async {
      expect(await store.save(vault()), isTrue);
      final bytes = File(path).readAsBytesSync();
      bytes[bytes.length ~/ 2] ^= 255;
      File(path).writeAsBytesSync(bytes);
      expect(await store.load(), isA<AccountVaultLoadFailed>());
      expect(File(path).readAsBytesSync(), bytes);
    });

    test('unsupported and malformed documents are distinct after decrypting', () async {
      final raw = DpapiKeychainStore(path);
      expect(await raw.saveCookies({'vault': '{"version":99}'}), isTrue);
      expect((await store.load() as AccountVaultLoadFailed).status, -3);
      expect(await raw.saveCookies({'vault': 'fixture-secret'}), isTrue);
      expect((await store.load() as AccountVaultLoadFailed).status, -2);
      expect(await raw.saveCookies({'SESSDATA': 'legacy-fixture'}), isTrue);
      expect((await store.load() as AccountVaultLoadFailed).status, -2);
    });

    test('failed replacement preserves the previous collection and removes its temporary file', () async {
      expect(await store.save(vault()), isTrue);
      final before = File(path).readAsBytesSync();
      final held = File(path).openSync(mode: FileMode.append);
      try {
        expect(await store.save(AccountVault()), isFalse);
      } finally {
        held.closeSync();
      }
      expect(File(path).readAsBytesSync(), before);
      expect(File('$path.tmp').existsSync(), isFalse);
    });

    test('a PC save refuses app tokens without changing the existing vault', () async {
      expect(await store.save(vault()), isTrue);
      final token = AppToken(accessToken: 'fixture-access', refreshToken: 'fixture-refresh', mid: 101,
          expiresAt: DateTime.utc(2030));
      final invalid = AccountVault(activeMid: 101, accounts: {
        101: vault().accounts[101]!.copyWith(appToken: token),
      });
      expect(await store.save(invalid), isFalse);
      expect((await store.load() as StoredAccountVault).vault.accounts[101]!.appToken, isNull);
      final raw = DpapiKeychainStore(path);
      expect(await raw.saveCookies({'vault': encodeAccountVault(invalid)}), isTrue);
      expect((await store.load() as AccountVaultLoadFailed).status, -2);
    });
  });
}
