import 'dart:async';
import 'dart:io' show Platform;

import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoButton;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../shared/theme.dart';
import 'qr_login.dart';
import 'web_cookies.dart';

/// 登录: Bilibili's own login page in a web view (BiliNative `LoginView.swift`); on the PC, which has no web view, the
/// website's QR login (`qr_login.dart`) in a `--real-account` run, else a note to log in on the phone. Pops true once
/// the account is logged in.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LoginTheme.colorsOf(context).page,
    appBar: AppBar(
      backgroundColor: LoginTheme.colorsOf(context).bar,
      surfaceTintColor: LoginTheme.colorsOf(context).bar,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: _CloseButton(onTap: () => Navigator.of(context).pop(false)),
      title: Text('登录', style: LoginTheme.titleStyle.copyWith(color: LoginTheme.colorsOf(context).title)),
    ),
    body: Platform.isIOS
        ? _WebLogin(
            environment: AppScope.of(context).environment,
            onLoggedIn: () => Navigator.of(context).pop(true),
          )
        : AppScope.of(context).environment.pcLogin
        ? QrLogin(
            environment: AppScope.of(context).environment,
            onLoggedIn: () => Navigator.of(context).pop(true),
          )
        : Center(
            child: Text('请在手机上登录', key: const ValueKey('login-on-phone'),
                style: LoginTheme.messageStyle.copyWith(color: LoginTheme.colorsOf(context).message)),
          ),
  );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '关闭',
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('login-close'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: LoginTheme.closeTarget,
        child: Icon(Icons.close, size: LoginTheme.closeIcon, color: LoginTheme.colorsOf(context).close),
      ),
    ),
  );
}

/// Bilibili's page, with the account taken from its cookies once it logs in.
class _WebLogin extends StatefulWidget {
  const _WebLogin({required this.environment, required this.onLoggedIn});

  final AppEnvironment environment;
  final VoidCallback onLoggedIn;

  @override
  State<_WebLogin> createState() => _WebLoginState();
}

class _WebLoginState extends State<_WebLogin> {
  static final _loginPage = Uri.parse('https://passport.bilibili.com/login');

  /// NSURLErrorCancelled (a load another one replaced) and WebKit's 102 (a load handed elsewhere).
  static const _ignoredErrors = {-999, 102};

  final _web = WebViewController();
  late final _flow = LoginFlow(environment: widget.environment, load: _load, onLoggedIn: widget.onLoggedIn);
  var _loading = true;
  Color? _background;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final background = LoginTheme.colorsOf(context).page;
    if (_background == background) return;
    _background = background;
    unawaited(_web.setBackgroundColor(background).catchError((Object error) {
      Logger.shared.warn(LogCategory.ui, 'login background not updated', {'error': '${error.runtimeType}'});
    }));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      await _web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _allow,
          onPageStarted: (_) => _setLoading(true),
          onPageFinished: _finished,
          onUrlChange: (_) => unawaited(_flow.watcher.check()),
          onWebResourceError: _failed,
        ),
      );
    } catch (error) {
      Logger.shared.error(LogCategory.ui, 'login web view setup failed', {'error': '$error'});
    }
    await _flow.start();
  }

  Future<void> _load() async {
    _setLoading(true);
    try {
      await _web.loadRequest(_loginPage);
    } catch (_) {
      _setLoading(false);
      rethrow;
    }
  }

  /// Pages that try to open the Bilibili app (bilibili://) would only fail with an unsupported URL.
  NavigationDecision _allow(NavigationRequest request) {
    if (!request.isMainFrame) return NavigationDecision.navigate;
    final scheme = Uri.tryParse(request.url)?.scheme;
    return scheme == 'https' || scheme == 'http' || scheme == 'about'
        ? NavigationDecision.navigate
        : NavigationDecision.prevent;
  }

  void _setLoading(bool loading) {
    if (mounted && _loading != loading) setState(() => _loading = loading);
  }

  void _finished(String url) {
    // The query of Bilibili's cross-domain hops carries the session, so only the host and path are logged.
    final page = Uri.tryParse(url);
    Logger.shared.info(LogCategory.ui, 'login page', {'host': page?.host ?? '', 'path': page?.path ?? ''});
    _setLoading(false);
    unawaited(_flow.watcher.check());
  }

  void _failed(WebResourceError error) {
    if (error.isForMainFrame == false || _ignoredErrors.contains(error.errorCode)) return;
    _setLoading(false);
    _flow.pageFailed(error.errorCode, error.description);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _flow,
    builder: (context, _) {
      final problem = _flow.problem;
      final Widget? cover = _flow.signingIn
          ? const CupertinoActivityIndicator(key: ValueKey('login-signing-in'), radius: LoginTheme.spinnerRadius)
          : problem != null
          ? _Retry(message: problem.message, onRetry: problem.retry)
          : null;
      return Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _web),
          if (cover != null)
            ColoredBox(color: LoginTheme.colorsOf(context).page, child: Center(child: cover))
          else if (_loading)
            const Center(child: CupertinoActivityIndicator(radius: LoginTheme.spinnerRadius)),
        ],
      );
    },
  );
}

/// What covers Bilibili's page when the login can't go on, and what its 重试 does.
class LoginProblem {
  const LoginProblem(this.message, this.retry);

  final String message;
  final VoidCallback retry;
}

/// The login page's steps, kept apart from the web view so the PC can test them: clear the old bilibili.com
/// cookies, load Bilibili's page through [load], watch for its login and hand that to the account.
class LoginFlow extends ChangeNotifier {
  LoginFlow({
    required this.environment,
    required this.load,
    required this.onLoggedIn,
    Duration interval = const Duration(seconds: 1),
  }) {
    watcher = LoginWatcher(
      cookies: environment.webCookies,
      interval: interval,
      onSession: (cookies) => unawaited(_signIn(cookies)),
      onUnreadable: () => _show(LoginProblem('无法读取登录状态', _watchAgain)),
    );
  }

  final AppEnvironment environment;

  /// Loads Bilibili's login page; throws when it couldn't.
  final Future<void> Function() load;
  final VoidCallback onLoggedIn;
  late final LoginWatcher watcher;
  bool _signingIn = false;
  LoginProblem? _problem;
  bool _disposed = false;

  bool get signingIn => _signingIn;
  LoginProblem? get problem => _problem;

  /// A SESSDATA left from an expired login would count as a fresh login at once (LoginView.swift :65-84), so the
  /// page loads only after the old bilibili.com cookies are gone, and not while they can't be removed.
  Future<void> start() async {
    _show(null);
    try {
      await environment.webCookies.clearBilibili();
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'login cookies not cleared', {'error': '$error'});
      _show(LoginProblem('无法清除旧的登录状态', () => unawaited(start())));
      return;
    }
    if (_disposed) return;
    watcher.start();
    await reload();
  }

  Future<void> reload() async {
    _show(null);
    try {
      await load();
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'login page load failed', {'error': '$error'});
      _show(LoginProblem('页面加载失败', () => unawaited(reload())));
    }
  }

  /// WebKit's description can be English, so it goes to the log and the page says 页面加载失败.
  void pageFailed(int code, String description) {
    Logger.shared.warn(LogCategory.ui, 'login page failed', {'code': code, 'description': description});
    _show(LoginProblem('页面加载失败', () => unawaited(reload())));
  }

  void _watchAgain() {
    _show(null);
    watcher.start();
  }

  /// A check that couldn't reach Bilibili asks again with the same cookies; cookies Bilibili turned down need a
  /// fresh login on a cleared page.
  Future<void> _signIn(Map<String, String> cookies) async {
    if (_disposed) return;
    _signingIn = true;
    _problem = null;
    notifyListeners();
    final loggedIn = await environment.didLogin(cookies);
    if (_disposed) return;
    if (loggedIn) {
      onLoggedIn();
      return;
    }
    _signingIn = false;
    _show(
      environment.accountCheckFailed
          ? LoginProblem('网络错误，请重试', () => unawaited(_signIn(cookies)))
          : LoginProblem('登录失败', () => unawaited(start())),
    );
  }

  void _show(LoginProblem? problem) {
    if (_disposed) return;
    _problem = problem;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    watcher.dispose();
    super.dispose();
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(LoginTheme.inset),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: LoginTheme.messageStyle.copyWith(color: LoginTheme.colorsOf(context).message),
          strutStyle: BiliFonts.strutOf(context, LoginTheme.messageStyle),
        ),
        const SizedBox(height: LoginTheme.gap),
        CupertinoButton(
          onPressed: onRetry,
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(LoginTheme.retryHeight),
          child: Container(
            height: LoginTheme.retryHeight,
            padding: const EdgeInsets.symmetric(horizontal: LoginTheme.retryPadX),
            alignment: Alignment.center,
            decoration: ShapeDecoration(shape: StadiumBorder(side: BorderSide(color: LoginTheme.colorsOf(context).retry))),
            child: Text('重试', style: LoginTheme.retryStyle),
          ),
        ),
      ],
    ),
  );
}

/// Watches the web view's cookie store for Bilibili's SESSDATA and hands over every bilibili.com cookie the first
/// time a non-empty one is there. BiliNative observed `WKHTTPCookieStore`; webview_flutter has no such hook, so this
/// reads on every page finish and URL change and once a second in between. After [failureLimit] failed reads in a
/// row it stops and calls [onUnreadable].
class LoginWatcher {
  LoginWatcher({
    required this.cookies,
    required this.onSession,
    this.onUnreadable,
    this.interval = const Duration(seconds: 1),
  });

  static const failureLimit = 3;

  final WebCookies cookies;
  final void Function(Map<String, String> cookies) onSession;
  final VoidCallback? onUnreadable;
  final Duration interval;
  Timer? _timer;
  bool _watching = false;
  bool _reading = false;
  int _failures = 0;

  /// Also after a login Bilibili turned down, once the page is cleared again, and after [onUnreadable].
  void start() {
    _watching = true;
    _failures = 0;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(check()));
  }

  Future<void> check() async {
    if (!_watching || _reading) return;
    _reading = true;
    final Map<String, String> found;
    try {
      found = await cookies.bilibili();
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'login cookies unreadable', {'error': '$error'});
      if (_watching && ++_failures >= failureLimit) {
        _stop();
        onUnreadable?.call();
      }
      return;
    } finally {
      _reading = false;
    }
    _failures = 0;
    final session = found['SESSDATA'];
    if (!_watching || session == null || session.isEmpty) return;
    _stop();
    Logger.shared.info(LogCategory.ui, 'login cookies', {'count': found.length});
    onSession(found);
  }

  void dispose() => _stop();

  void _stop() {
    _watching = false;
    _timer?.cancel();
    _timer = null;
  }
}
