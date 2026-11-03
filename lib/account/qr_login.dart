import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/app_environment.dart';
import '../shared/loading_tv.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';

/// The website's QR login calls, apart from the client so the model is tested without HTTP.
abstract interface class QrLoginApi {
  Future<WebLoginQr> generate();

  Future<WebLoginPoll> poll(String key);
}

final class ClientQrLoginApi implements QrLoginApi {
  const ClientQrLoginApi(this._client);

  final BiliClient _client;

  @override
  Future<WebLoginQr> generate() => _client.webLoginQr();

  @override
  Future<WebLoginPoll> poll(String key) => _client.webLoginPoll(key);
}

enum QrLoginPhase {
  /// The code is being asked for.
  loading,

  /// The code is up and not scanned yet.
  waiting,

  /// Scanned: 确认 is waited for on the phone.
  scanned,

  /// The code ran out (Bilibili's 86038, or [QrLoginModel.pollLimit] polls); 刷新 asks for a new one.
  expired,

  /// No code could be had, or [QrLoginModel.failureLimit] polls in a row failed; 重试 asks for a new code.
  failed,

  /// Confirmed on the phone: the account is checked with the new session.
  signingIn,

  /// Bilibili couldn't be asked whether the session logs in; 重试 asks again with the same session.
  checkFailed,

  /// The session didn't log in; 重试 asks for a new code.
  rejected,

  /// Logged in.
  done,
}

/// The Windows build's login: the website's QR code, scanned and confirmed in the official app. It can never loop
/// against the account: one code per open or tap, at most [pollLimit] polls of it one at a time, [interval] apart,
/// only while the page is up, and a new code only when the user asks.
class QrLoginModel extends ChangeNotifier {
  QrLoginModel({
    required this.api,
    required this.didLogin,
    required this.onLoggedIn,
    bool Function()? checkFailed,
    this.interval = const Duration(seconds: 2),
    Logger? logger,
  }) : _checkFailed = checkFailed ?? (() => false),
       _logger = logger ?? Logger.shared;

  /// 180 s at 2 s apart: the life Bilibili gives a code.
  static const pollLimit = 90;
  static const failureLimit = 3;

  final QrLoginApi api;

  /// The account's login with the session (`AppEnvironment.didLogin`): whether it is now logged in.
  final Future<bool> Function(Map<String, String> cookies) didLogin;
  final VoidCallback onLoggedIn;

  /// Whether a [didLogin] that answered false only couldn't reach Bilibili (`AppEnvironment.accountCheckFailed`).
  final bool Function() _checkFailed;
  final Duration interval;
  final Logger _logger;

  QrLoginPhase _phase = QrLoginPhase.loading;
  WebLoginQr? _code;
  Timer? _timer;
  bool _polling = false;
  int _polls = 0;
  int _failures = 0;

  /// Bumped by every new code, so an answer about an older one is dropped.
  int _round = 0;

  /// Kept only while [QrLoginPhase.checkFailed] offers to ask again with it.
  Map<String, String>? _session;
  bool _started = false;
  bool _disposed = false;
  String? _problemMessage;
  bool _retrySession = false;
  String? get problemMessage => _problemMessage;

  QrLoginPhase get phase => _phase;

  /// What the QR draws, while the code is up.
  String? get url => _phase == QrLoginPhase.waiting || _phase == QrLoginPhase.scanned ? _code?.url : null;

  /// Polls sent about the current code.
  int get polls => _polls;

  /// The first code; later ones come only from [retry].
  void start() {
    if (_started) return;
    _started = true;
    unawaited(_generate());
  }

  /// 刷新 and 重试. Does nothing where the page shows neither, so a second tap can't ask twice.
  void retry() {
    switch (_phase) {
      case QrLoginPhase.expired || QrLoginPhase.failed || QrLoginPhase.rejected:
        unawaited(_generate());
      case QrLoginPhase.checkFailed:
        if (_session case final session?) unawaited(_signIn(session));
      case QrLoginPhase.loading || QrLoginPhase.waiting || QrLoginPhase.scanned:
      case QrLoginPhase.signingIn || QrLoginPhase.done:
        break;
    }
  }

  Future<void> _generate() async {
    final round = ++_round;
    _stopPolling();
    _code = null;
    _session = null;
    _polls = 0;
    _failures = 0;
    _set(QrLoginPhase.loading);
    final WebLoginQr code;
    try {
      code = await api.generate();
    } catch (error) {
      if (_disposed || round != _round) return;
      _logger.warn(LogCategory.ui, 'qr login code failed', {'error': _describe(error)});
      _set(QrLoginPhase.failed);
      return;
    }
    if (_disposed || round != _round) return;
    _code = code;
    _set(QrLoginPhase.waiting);
    _timer = Timer.periodic(interval, (_) => unawaited(_poll(round)));
  }

  Future<void> _poll(int round) async {
    final code = _code;
    if (_polling || _disposed || code == null || round != _round) return;
    _polling = true;
    _polls += 1;
    final WebLoginPoll answer;
    try {
      answer = await api.poll(code.key);
    } catch (error) {
      if (_disposed || round != _round) return;
      _failures += 1;
      _logger.warn(LogCategory.ui, 'qr login poll failed', {'error': _describe(error), 'failures': _failures});
      if (_failures >= failureLimit) {
        _stopPolling();
        _set(QrLoginPhase.failed);
      } else if (_polls >= pollLimit) {
        _expire();
      }
      return;
    } finally {
      _polling = false;
    }
    if (_disposed || round != _round) return;
    _failures = 0;
    switch (answer) {
      case WebLoginDone(:final cookies):
        _stopPolling();
        unawaited(_signIn(cookies));
      case WebLoginExpired():
        _expire();
      case WebLoginWaiting(:final scanned):
        if (_polls >= pollLimit) {
          _expire();
        } else {
          _set(scanned ? QrLoginPhase.scanned : QrLoginPhase.waiting);
        }
    }
  }

  void _expire() {
    _stopPolling();
    _set(QrLoginPhase.expired);
  }

  Future<void> _signIn(Map<String, String> cookies) async {
    _session = null;
    _problemMessage = null;
    _retrySession = false;
    _set(QrLoginPhase.signingIn);
    bool loggedIn;
    try {
      loggedIn = await didLogin(cookies);
    } catch (error) {
      _logger.warn(LogCategory.ui, 'qr login sign in failed', {'error': _describe(error)});
      if (error is AccountSwitchFailure) {
        _problemMessage = error.message;
        _retrySession = !error.requiresLogin;
      }
      loggedIn = false;
    }
    if (_disposed) return;
    if (loggedIn) {
      _set(QrLoginPhase.done);
      onLoggedIn();
    } else if (_retrySession || (_problemMessage == null && _checkFailed())) {
      _session = cookies;
      _set(QrLoginPhase.checkFailed);
    } else {
      _set(QrLoginPhase.rejected);
    }
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void _set(QrLoginPhase phase) {
    if (_disposed) return;
    if (_phase != phase) _logger.info(LogCategory.ui, 'qr login', {'phase': phase.name, 'polls': _polls});
    _phase = phase;
    notifyListeners();
  }

  /// A [BiliError] says only its kind and Bilibili's code; anything else could quote a request.
  static String _describe(Object error) => error is BiliError ? '$error' : '${error.runtimeType}';

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    super.dispose();
  }
}

/// The QR login page's body: the code over what to do with it, or what went wrong with 刷新 or 重试.
class QrLogin extends StatefulWidget {
  const QrLogin({super.key, required this.environment, required this.onLoggedIn, this.api, this.expectedMid});

  final AppEnvironment environment;
  final VoidCallback onLoggedIn;
  final int? expectedMid;

  /// The client's calls unless a test brings its own.
  final QrLoginApi? api;

  @override
  State<QrLogin> createState() => _QrLoginState();
}

class _QrLoginState extends State<QrLogin> {
  late final _model = QrLoginModel(
    api: widget.api ?? ClientQrLoginApi(widget.environment.client),
    didLogin: (cookies) => widget.environment.didLogin(cookies,
      expectedMid: widget.expectedMid, isCurrent: () => mounted),
    checkFailed: () => widget.environment.accountCheckFailed,
    onLoggedIn: () {
      if (!widget.environment.loginSaved) showToast(context, '登录未能保存，下次启动需重新扫码');
      widget.onLoggedIn();
    },
  );

  @override
  void initState() {
    super.initState();
    _model.start();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: LoginTheme.colorsOf(context).page,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(LoginTheme.inset),
        child: ListenableBuilder(listenable: _model, builder: (context, _) => _body(context)),
      ),
    ),
  );

  Widget _body(BuildContext context) => switch (_model.phase) {
    QrLoginPhase.loading => const LoadingTvState(key: ValueKey('qr-login-loading')),
    QrLoginPhase.signingIn || QrLoginPhase.done => const LoadingTv(key: ValueKey('qr-login-signing-in')),
    QrLoginPhase.waiting => _code(context, scanned: false),
    QrLoginPhase.scanned => _code(context, scanned: true),
    QrLoginPhase.expired => _problem(context, '二维码已失效', '刷新', const ValueKey('qr-login-refresh')),
    QrLoginPhase.failed => _problem(context, '加载失败', '重试', const ValueKey('qr-login-retry')),
    QrLoginPhase.checkFailed => _problem(context, _model.problemMessage ?? '网络错误，请重试', '重试', const ValueKey('qr-login-retry')),
    QrLoginPhase.rejected => _problem(context, _model.problemMessage ?? '登录失败', '重试', const ValueKey('qr-login-retry')),
  };

  Widget _code(BuildContext context, {required bool scanned}) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedOpacity(
        opacity: scanned ? LoginTheme.qrScannedOpacity : 1,
        duration: LoginTheme.qrFade,
        child: QrImageView(
          key: const ValueKey('qr-login-code'),
          data: _model.url ?? '',
          size: LoginTheme.qrSize,
          padding: const EdgeInsets.all(LoginTheme.qrQuietZone),
          // Keep standard dark modules on a light quiet zone for scanning.
          backgroundColor: LoginTheme.qrBackground,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: LoginTheme.qrModule),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: LoginTheme.qrModule,
          ),
          semanticsLabel: '登录二维码',
        ),
      ),
      const SizedBox(height: LoginTheme.qrGap),
      _message(context, scanned ? '已扫码，请在手机上确认' : '请使用哔哩哔哩客户端扫码登录'),
    ],
  );

  Widget _problem(BuildContext context, String message, String action, Key key) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _message(context, message),
      const SizedBox(height: LoginTheme.gap),
      _Button(key: key, label: action, onTap: _model.retry),
    ],
  );

  Widget _message(BuildContext context, String text) => Semantics(
    liveRegion: true,
    child: Text(
      text,
      key: const ValueKey('qr-login-message'),
      textAlign: TextAlign.center,
      style: LoginTheme.messageStyle.copyWith(color: LoginTheme.colorsOf(context).message),
      strutStyle: BiliFonts.strutOf(context, LoginTheme.messageStyle),
    ),
  );
}

/// The login page's 重试 look, for 刷新 too.
class _Button extends StatelessWidget {
  const _Button({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  // excludeSemantics drops the button's own tap action, so the node carries it for VoiceOver and ghosthand.
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(LoginTheme.retryHeight),
      child: Container(
        height: LoginTheme.retryHeight,
        padding: const EdgeInsets.symmetric(horizontal: LoginTheme.retryPadX),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: StadiumBorder(side: BorderSide(color: LoginTheme.colorsOf(context).retry)),
        ),
        child: Text(label, style: LoginTheme.retryStyle.copyWith(color: LoginTheme.colorsOf(context).retry)),
      ),
    ),
  );
}
