import 'dart:async';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/account/login_page.dart';
import 'package:bilifast/account/qr_login.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import '../settings/settings_fakes.dart';
import 'fake_web_cookies.dart';

class _CommittingEnvironment extends FakeEnvironment {
  _CommittingEnvironment() : super(const LoggedIn(name: '测试账号', vip: false));
  bool committing = false;
  @override
  bool get accountCommitting => committing;
  @override
  bool get pcLogin => false;
}

void main() {
  testWidgets('the login can close during validation but stays open during the durable commit', (tester) async {
    final environment = _CommittingEnvironment();
    final services = AppServices(environment: environment,
        playback: AppPlayback(() => Completer<PlaybackController>().future),
        recents: await RecentStore.load(null), pageApi: FakePageApi());
    await tester.pumpWidget(MaterialApp(
      navigatorKey: services.navigator,
      builder: (context, child) => AppScope(services: services, child: child!),
      home: const Scaffold(body: Text('root')),
    ));
    services.navigator.currentState!.push<void>(MaterialPageRoute(builder: (_) => const LoginPage()));
    await tester.pumpAndSettle();
    environment.committing = true;
    environment.notifyListeners();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('login-close')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    environment.committing = false;
    environment.notifyListeners();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('login-close')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    services.dispose();
    services.playback.dispose();
    environment.dispose();
  });

  testWidgets('on the PC the page shows the QR login under a 登录 bar with a close control', (tester) async {
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(const NoStoredCookies()),
      webCookies: FakeWebCookies(),
      http: CannedHttp(),
      logger: Logger(session: 'test'),
    );
    final services = AppServices(
      environment: environment,
      playback: AppPlayback(() => Completer<PlaybackController>().future),
      recents: await RecentStore.load(null, logger: Logger(session: 'test')),
      pageApi: FakePageApi(),
    );
    addTearDown(services.playback.dispose);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppScope(services: services, child: child!),
      home: const LoginPage(),
    ));
    await tester.pump();
    expect(find.text('登录'), findsOneWidget);
    expect(find.byType(QrLogin), findsNothing, reason: 'the QR login is only for a --real-account run');
    expect(find.byKey(const ValueKey('login-on-phone')), findsOneWidget);
    expect(find.bySemanticsLabel('关闭'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
  });

  group('LoginWatcher', () {
    test('hands the bilibili.com cookies over once, the first time a non-empty SESSDATA is there', () {
      fakeAsync((async) {
        final web = FakeWebCookies()..jar['buvid3'] = 'b3';
        final sessions = <Map<String, String>>[];
        final watcher = LoginWatcher(cookies: web, onSession: sessions.add);
        unawaited(watcher.check());
        async.flushMicrotasks();
        expect(web.reads, 0, reason: 'nothing is read before the page is cleared and watched');

        watcher.start();
        async.elapse(const Duration(seconds: 1));
        expect(web.reads, 1);
        web.jar['SESSDATA'] = '';
        async.elapse(const Duration(seconds: 1));
        expect(sessions, isEmpty, reason: 'an empty SESSDATA is no login');

        web.jar.addAll({'SESSDATA': 'sess', 'bili_jct': 'jct'});
        // A page finish and a URL change together, with the timer still running.
        unawaited(watcher.check());
        unawaited(watcher.check());
        async.elapse(const Duration(seconds: 3));
        expect(sessions, [
          {'buvid3': 'b3', 'SESSDATA': 'sess', 'bili_jct': 'jct'},
        ]);
        final reads = web.reads;
        async.elapse(const Duration(seconds: 5));
        expect(web.reads, reads, reason: 'it stops once it has the login');
      });
    });

    test('a read that fails is tried again on the next tick', () {
      fakeAsync((async) {
        final web = FakeWebCookies()
          ..jar['SESSDATA'] = 'sess'
          ..readError = PlatformException(code: 'webkit');
        final sessions = <Map<String, String>>[];
        LoginWatcher(cookies: web, onSession: sessions.add).start();
        async.elapse(const Duration(seconds: 1));
        expect(sessions, isEmpty);
        web.readError = null;
        async.elapse(const Duration(seconds: 1));
        expect(sessions, hasLength(1));
      });
    });

    test('after 3 failed reads in a row it stops and says so once; started again it reads again', () {
      fakeAsync((async) {
        final web = FakeWebCookies()..readError = PlatformException(code: 'webkit');
        var unreadable = 0;
        final watcher = LoginWatcher(cookies: web, onSession: (_) {}, onUnreadable: () => unreadable += 1)..start();
        async.elapse(const Duration(seconds: 2));
        expect(unreadable, 0, reason: 'two failures are not yet a broken store');
        async.elapse(const Duration(seconds: 1));
        expect(unreadable, 1);
        async.elapse(const Duration(seconds: 5));
        expect(web.reads, 3, reason: 'no read every second forever');
        expect(unreadable, 1);

        watcher.start();
        async.elapse(const Duration(seconds: 1));
        expect(web.reads, 4);
        watcher.dispose();
      });
    });

    test('a read that works in between starts the count again', () {
      fakeAsync((async) {
        final web = FakeWebCookies()..readError = PlatformException(code: 'webkit');
        var unreadable = 0;
        final watcher = LoginWatcher(cookies: web, onSession: (_) {}, onUnreadable: () => unreadable += 1)..start();
        async.elapse(const Duration(seconds: 2));
        web.readError = null;
        async.elapse(const Duration(seconds: 1));
        web.readError = PlatformException(code: 'webkit');
        async.elapse(const Duration(seconds: 2));
        expect(unreadable, 0);
        watcher.dispose();
      });
    });

    test('once disposed it hands nothing over, even from a read already on its way', () {
      fakeAsync((async) {
        final web = FakeWebCookies()..jar['SESSDATA'] = 'sess';
        final sessions = <Map<String, String>>[];
        final watcher = LoginWatcher(cookies: web, onSession: sessions.add)..start();
        unawaited(watcher.check());
        watcher.dispose();
        async.elapse(const Duration(seconds: 3));
        expect(sessions, isEmpty);
        expect(web.reads, 1);
      });
    });

    test('started again after a login Bilibili turned down, it hands the next one over', () {
      fakeAsync((async) {
        final web = FakeWebCookies()..jar['SESSDATA'] = 'first';
        final sessions = <String?>[];
        final watcher = LoginWatcher(cookies: web, onSession: (cookies) => sessions.add(cookies['SESSDATA']))..start();
        async.elapse(const Duration(seconds: 2));
        web.jar['SESSDATA'] = 'second';
        watcher.start();
        async.elapse(const Duration(seconds: 2));
        expect(sessions, ['first', 'second']);
      });
    });

    test('wired to the account, a login is taken once and the account comes back logged in', () {
      fakeAsync((async) {
        final web = FakeWebCookies();
        final http = Canned.http();
        late AppEnvironment environment;
        unawaited(AppEnvironment.load(
          keychain: FakeKeychain(const NoStoredCookies()),
          webCookies: web,
          http: http,
          logger: Logger(session: 'test'),
        ).then((loaded) => environment = loaded));
        async.flushMicrotasks();
        final answers = <bool>[];
        final watcher = LoginWatcher(
          cookies: web,
          onSession: (cookies) => unawaited(environment.didLogin(cookies).then(answers.add)),
        )..start();
        web.jar.addAll({'SESSDATA': 'sess', 'bili_jct': 'jct', 'buvid3': 'b3', 'buvid4': 'b4'});
        unawaited(watcher.check());
        async.elapse(const Duration(seconds: 5));
        expect(answers, [true]);
        expect(http.to(Canned.navPath), hasLength(1));
        expect(environment.account, isA<LoggedIn>());
        expect(environment.cookies.value('SESSDATA'), 'sess');
      });
    });
  });

  group('LoginFlow', () {
    /// The flow over a fresh account, run inside [body] with fake time; [loads] counts the page loads.
    void run(
      void Function(FakeAsync async, LoginFlow flow, FakeWebCookies web, CannedHttp http, List<int> loads) body, {
      FakeWebCookies? web,
      CannedHttp? http,
      Object? Function()? loadError,
      void Function()? onLoggedIn,
    }) {
      fakeAsync((async) {
        final cookies = web ?? FakeWebCookies();
        final canned = http ?? Canned.http();
        late AppEnvironment environment;
        unawaited(
          AppEnvironment.load(
            keychain: FakeKeychain(const NoStoredCookies()),
            webCookies: cookies,
            http: canned,
            logger: Logger(session: 'test'),
          ).then((loaded) => environment = loaded),
        );
        async.flushMicrotasks();
        final loads = <int>[];
        final flow = LoginFlow(
          environment: environment,
          load: () async {
            loads.add(loads.length + 1);
            final error = loadError?.call();
            if (error != null) throw error;
          },
          onLoggedIn: onLoggedIn ?? () {},
        );
        body(async, flow, cookies, canned, loads);
        flow.dispose();
        async.flushTimers();
      });
    }

    const login = {'SESSDATA': 'sess', 'bili_jct': 'jct', 'buvid3': 'b3', 'buvid4': 'b4'};

    test('old cookies that can\'t be cleared keep the page from loading, and 重试 clears again', () {
      final web = FakeWebCookies()..clearBilibiliError = PlatformException(code: 'webkit');
      run(web: web, (async, flow, web, http, loads) {
        unawaited(flow.start());
        async.flushMicrotasks();
        expect(flow.problem?.message, '无法清除旧的登录状态');
        expect(loads, isEmpty);
        async.elapse(const Duration(seconds: 3));
        expect(web.reads, 0, reason: 'nothing is watched over stale cookies');

        web.clearBilibiliError = null;
        flow.problem!.retry();
        async.flushMicrotasks();
        expect(flow.problem, isNull);
        expect(web.bilibiliClears, 2);
        expect(loads, [1]);
      });
    });

    test('a load that throws reads 页面加载失败, and 重试 loads again', () {
      Object? error = PlatformException(code: 'webkit');
      run(loadError: () => error, (async, flow, web, http, loads) {
        unawaited(flow.start());
        async.flushMicrotasks();
        expect(flow.problem?.message, '页面加载失败');
        error = null;
        flow.problem!.retry();
        async.flushMicrotasks();
        expect(flow.problem, isNull);
        expect(loads, [1, 2]);
      });
    });

    test('WebKit\'s own (English) description never reaches the page', () {
      run((async, flow, web, http, loads) {
        unawaited(flow.start());
        async.flushMicrotasks();
        flow.pageFailed(-1009, 'The Internet connection appears to be offline.');
        expect(flow.problem?.message, '页面加载失败');
        flow.problem!.retry();
        async.flushMicrotasks();
        expect(loads, [1, 2]);
      });
    });

    test('a cookie store that can\'t be read reads 无法读取登录状态, and 重试 watches again', () {
      final web = FakeWebCookies()..readError = PlatformException(code: 'webkit');
      run(web: web, (async, flow, web, http, loads) {
        unawaited(flow.start());
        async.elapse(const Duration(seconds: 3));
        expect(flow.problem?.message, '无法读取登录状态');
        expect(web.reads, 3);

        web
          ..readError = null
          ..jar.addAll(login);
        flow.problem!.retry();
        expect(flow.problem, isNull);
        async.elapse(const Duration(seconds: 1));
        expect(web.reads, 4);
      });
    });

    test('a login whose check couldn\'t reach Bilibili reads 网络错误，请重试, and 重试 asks again', () {
      final http = Canned.http()..routes[Canned.navPath] = (502, '');
      var loggedIn = 0;
      run(http: http, onLoggedIn: () => loggedIn += 1, (async, flow, web, http, loads) {
        unawaited(flow.start());
        async.flushMicrotasks();
        web.jar.addAll(login);
        async.elapse(const Duration(seconds: 1));
        expect(flow.signingIn, isTrue);
        async.elapse(const Duration(seconds: 4));
        expect(flow.signingIn, isFalse);
        expect(flow.problem?.message, '网络错误，请重试');

        http.routes[Canned.navPath] = (200, Canned.navLoggedIn);
        flow.problem!.retry();
        async.flushMicrotasks();
        expect(loggedIn, 1);
        expect(web.bilibiliClears, 1, reason: 'the same cookies are tried again, the page isn\'t cleared');
      });
    });

    test('a login Bilibili turned down reads 登录失败, and 重试 starts over on a cleared page', () {
      run(http: Canned.http(loggedIn: false), (async, flow, web, http, loads) {
        unawaited(flow.start());
        async.flushMicrotasks();
        web.jar.addAll(login);
        async.elapse(const Duration(seconds: 5));
        expect(flow.problem?.message, '登录失败');

        flow.problem!.retry();
        async.flushMicrotasks();
        expect(flow.problem, isNull);
        expect(web.bilibiliClears, 2);
        expect(loads, [1, 2]);
      });
    });
  });
}
