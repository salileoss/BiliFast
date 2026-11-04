import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bilifast/keychain');
  late MemorySink memory;
  late ChannelKeychainStore store;
  Object? Function(MethodCall call) answer = (_) => null;

  setUp(() {
    final logger = Logger(session: 'test');
    memory = MemorySink();
    logger.add(memory);
    store = ChannelKeychainStore(null, logger);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => answer(call));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'a delete the keychain refused throws, for the cookies and the app token',
    () async {
      answer = (_) => throw PlatformException(
        code: 'keychain',
        message: 'delete failed',
        details: -25308,
      );
      await expectLater(
        store.deleteCookies(),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        store.deleteAppToken(),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test('a delete that went through completes', () async {
    answer = (_) => null;
    await store.deleteCookies();
    await store.deleteAppToken();
  });

  test('an unreadable token differs from an absent token, so migration cannot delete an unknown credential', () async {
    answer = (_) => {'code': -25308};
    await expectLater(store.loadAppToken(), throwsA(isA<PlatformException>()
        .having((error) => error.details, 'status', -25308)));
    answer = (_) => <String, Object?>{};
    expect(await store.loadAppToken(), isNull);
    expect(memory.events, isEmpty);
  });

  test(
    'a refused cookie write answers false and logs its status, no values',
    () async {
      answer = (_) => {'ok': false, 'code': -25308};
      expect(await store.saveCookies({'SESSDATA': 'secret-sess'}), isFalse);
      final event = memory.events.single;
      expect(event.level, LogLevel.error);
      expect(event.f['status']?.toJson(), -25308);
      expect(event.encode(), isNot(contains('secret-sess')));
    },
  );

  test('the PC stores nothing, and that is no failed write', () async {
    expect(await const NoKeychainStore().saveCookies({'a': '1'}), isTrue);
  });
}
