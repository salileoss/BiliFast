import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bilifast/account/login_page.dart';
import 'package:bilifast/account/qr_login.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../settings/settings_fakes.dart';
import 'fake_web_cookies.dart';

class _StagedEnvironment extends FakeEnvironment {
  _StagedEnvironment() : super(const LoggedIn(name: '原账号', vip: false));

  @override
  FakeWebCookies get webCookies => _web;
  final _web = FakeWebCookies();
  final answer = Completer<bool>();
  int? expected;
  bool Function()? current;
  Object? loginError;

  @override
  Future<bool> didLogin(
    Map<String, String> cookies, {
    int? expectedMid,
    bool Function()? isCurrent,
  }) async {
    expected = expectedMid;
    current = isCurrent;
    if (loginError case final error?) throw error;
    return answer.future;
  }
}

class _QrApi implements QrLoginApi {
  int generations = 0;
  @override
  Future<WebLoginQr> generate() async {
    generations++;
    return const WebLoginQr(url: 'https://example.invalid/qr', key: 'test-key');
  }

  @override
  Future<WebLoginPoll> poll(String key) async =>
      const WebLoginDone({'SESSDATA': 'made-up', 'bili_jct': 'made-up'});
}

void main() {
  test('web login passes the expected uid and closing the flow invalidates pending validation', () async {
    final environment = _StagedEnvironment();
    var loggedIn = 0;
    final flow = LoginFlow(
      environment: environment,
      expectedMid: 2,
      load: () async {},
      onLoggedIn: () => loggedIn++,
    );
    await flow.start();
    environment.webCookies.jar.addAll({
      'SESSDATA': 'made-up',
      'bili_jct': 'made-up',
    });
    await flow.watcher.check();
    expect(environment.expected, 2);
    expect(environment.current!(), isTrue);
    flow.dispose();
    expect(environment.current!(), isFalse);
    environment.answer.complete(true);
    await pumpEventQueue();
    expect(loggedIn, 0);
  });

  test(
    'staged login failures expose a retry and preserve the active account',
    () async {
      final environment = _StagedEnvironment()
        ..loginError = const AccountSwitchFailure('请登录所选账号');
      final flow = LoginFlow(
        environment: environment,
        expectedMid: 2,
        load: () async {},
        onLoggedIn: () {},
      );
      await flow.start();
      environment.webCookies.jar['SESSDATA'] = 'made-up';
      await flow.watcher.check();
      await pumpEventQueue();
      expect(flow.signingIn, isFalse);
      expect(flow.problem?.message, '请登录所选账号');
      expect(environment.accountLabel, '原账号');
      environment.loginError = null;
      flow.problem!.retry();
      expect(flow.signingIn, isTrue);
      environment.answer.complete(false);
      await pumpEventQueue();
      flow.dispose();
    },
  );

  testWidgets(
    'closing QR login invalidates validation and does not invoke its success callback',
    (tester) async {
      final environment = _StagedEnvironment();
      var loggedIn = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: QrLogin(
            environment: environment,
            expectedMid: 2,
            api: _QrApi(),
            onLoggedIn: () => loggedIn++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(environment.expected, 2);
      expect(environment.current!(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(environment.current!(), isFalse);
      environment.answer.complete(true);
      await tester.pump();
      expect(loggedIn, 0);
    },
  );

  testWidgets('QR account mismatch shows the backend reason and offers retry', (
    tester,
  ) async {
    final environment = _StagedEnvironment()
      ..loginError = const AccountSwitchFailure('请登录所选账号', requiresLogin: true);
    final api = _QrApi();
    await tester.pumpWidget(
      MaterialApp(
        home: QrLogin(
          environment: environment,
          expectedMid: 2,
          api: api,
          onLoggedIn: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('请登录所选账号'), findsOneWidget);
    expect(find.byKey(const ValueKey('qr-login-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qr-login-retry')));
    await tester.pump();
    expect(api.generations, 2, reason: 'a different account needs a fresh QR');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('wrong-account web retry clears the page before another login', () async {
    final environment = _StagedEnvironment()
      ..loginError = const AccountSwitchFailure('请登录所选账号', requiresLogin: true);
    var loads = 0;
    final flow = LoginFlow(environment: environment, expectedMid: 2,
      load: () async { loads++; }, onLoggedIn: () {});
    await flow.start();
    environment.webCookies.jar['SESSDATA'] = 'made-up';
    await flow.watcher.check();
    await pumpEventQueue();
    flow.problem!.retry();
    await pumpEventQueue();
    expect(environment.webCookies.bilibiliClears, 2);
    expect(loads, 2);
    expect(environment.webCookies.jar, isEmpty);
    flow.dispose();
  });
}
