import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' show Random;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/widgets.dart';

import '../app/app_environment.dart';
import '../home/feed_model.dart' show requestFailureMessage;
import '../playback/playback_setup.dart' show supportFilePath;
import '../shared/toast.dart';
import 'app_auth_client.dart';
import 'app_auth_prompt.dart';

/// The official API's login, the app token (PiliPlus's `access_key`): loaded at launch, got by one confirm in the
/// official app, renewed once near its end, dropped on 退出登录 or when Bilibili rejects it. What needs it
/// calls [request] rather than failing.
abstract interface class AppAuth implements Listenable {
  bool get authorized;

  /// When the token runs out; null without one.
  DateTime? get expiresAt;

  /// Launch: the stored token (renewed if due, one call), and the confirm asked once when logged in without one,
  /// unless it was turned down before.
  Future<void> start();

  /// Asks for the confirm, completing with whether a token is held now. One already up answers every caller.
  Future<bool> request(BuildContext context);

  /// 开发者's 重新授权: drops the token and asks again.
  Future<bool> reauthorize(BuildContext context);

  void dispose();
}

/// Tests' default: never authorized, and asking gets nothing.
class NoAppAuth extends ChangeNotifier implements AppAuth {
  @override
  bool get authorized => false;

  @override
  DateTime? get expiresAt => null;

  @override
  Future<void> start() async {}

  @override
  Future<bool> request(BuildContext context) async => false;

  @override
  Future<bool> reauthorize(BuildContext context) async => false;
}

/// `--fake-account`: authorized from the start, so 不喜欢 can be pressed against `FakePageApi`.
class FakeAppAuth extends ChangeNotifier implements AppAuth {
  FakeAppAuth({this.authorized = true});

  @override
  bool authorized;

  @override
  DateTime? get expiresAt => authorized ? DateTime.now().add(const Duration(days: 180)) : null;

  @override
  Future<void> start() async {}

  @override
  Future<bool> request(BuildContext context) async {
    authorized = true;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> reauthorize(BuildContext context) => request(context);
}

/// Where the official calls' device id is kept.
String? appDevicePath() => supportFilePath('app_device.json');

/// The phone's: the token in the keychain's app-token item (its JSON, expiry included), set on
/// [AppEnvironment.client]. A launch only compares dates; the one renewal call goes out within
/// [AppToken.renewWithin] of the end. A token that is rejected or runs out is dropped and the confirm asked again.
class TokenAppAuth extends ChangeNotifier implements AppAuth {
  TokenAppAuth({
    required this.environment,
    required this.navigator,
    this.confirm = showAppAuthPrompt,
    this.confirmInClient = confirmInBilibili,
    this.devicePath = appDevicePath,
    DateTime Function()? now,
    this.pollInterval = const Duration(seconds: 1),
    Logger? logger,
  }) : _now = now ?? DateTime.now,
       _logger = logger ?? Logger.shared;

  final AppEnvironment environment;

  /// For the launch's confirm, which no page asks for.
  final GlobalKey<NavigatorState> navigator;

  /// Asks before anything is sent, completing with whether 授权 was pressed.
  final Future<bool> Function(BuildContext context) confirm;

  /// Opens Bilibili's confirm page in the official app and completes once the user is back: false when there was
  /// no app to open.
  final Future<bool> Function(Uri page) confirmInClient;

  /// Null keeps the device id for this launch only.
  final String? Function() devicePath;

  /// Between the polls once the user is back, the first of which should find the token.
  final Duration pollInterval;

  final DateTime Function() _now;
  final Logger _logger;

  /// Polls once the user is back: under 10, so a confirm the poll never sees can't loop.
  static const quickPolls = 5;

  static final _buvidShape = RegExp(r'^XY[0-9A-F]{35}$');

  /// PiliPlus's buvid: XY, three of the digits again, then 16 random bytes in upper-case hex.
  static String newBuvid([Random? random]) {
    final source = random ?? Random.secure();
    final hex = [
      for (var i = 0; i < 16; i++) source.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join().toUpperCase();
    return 'XY${hex[2]}${hex[12]}${hex[22]}$hex';
  }

  bool _started = false;
  bool _disposed = false;
  bool _launchAsked = false;
  bool _rejectionAsked = false;
  bool _loginUnderway = false;

  /// The keychain threw on the read, so a token may well be stored: the launch doesn't ask for another.
  bool _storeUnreadable = false;

  /// The confirm was turned down. Kept in the device file, so the app doesn't ask by itself again, at this launch or
  /// the next, until a confirm goes through or the account logs out; what needs the token, and 开发者, still ask.
  bool _declined = false;
  Future<bool>? _request;

  BiliClient get _client => environment.client;

  @override
  bool get authorized => _client.appToken != null;

  @override
  DateTime? get expiresAt => _client.appToken?.expiresAt;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final generation = environment.sessionGeneration;
    environment.sessions.addListener(_sessionChanged);
    _client.onAppTokenRejected = _rejected;
    _client.appBuvid = await _deviceId();
    if (environment.hasAccountVault) _declined = environment.appAuthDeclined;
    var token = await _stored(generation);
    if (_disposed) return;
    if (generation != environment.sessionGeneration) {
      environment.addListener(_accountChanged);
      environment.logins.addListener(_loggedIn);
      _sessionChanged();
      return;
    }
    final now = _now();
    if (token != null && token.expired(now)) {
      _logger.info(LogCategory.app, 'app token dropped', {'reason': 'expired'});
      await _deleteStored(generation);
      token = null;
    }
    if (_disposed || generation != environment.sessionGeneration) return;
    if (token != null) {
      _client.appToken = token;
      notifyListeners();
      _logger.info(LogCategory.app, 'app token', {'days': _daysLeft(token, now)});
      // Off the launch's path, which waits for this load so 推荐's first page already knows the token.
      if (token.dueForRenewal(now)) unawaited(_renew());
    }
    if (_disposed) return;
    environment.addListener(_accountChanged);
    environment.logins.addListener(_loggedIn);
    if (environment.account is! AccountUnknown) _accountChanged();
  }

  @override
  Future<bool> request(BuildContext context) {
    if (_request case final running?) return running;
    late final Future<bool> asked;
    asked = _ask(context).whenComplete(() {
      if (identical(_request, asked)) _request = null;
    });
    return _request = asked;
  }

  @override
  Future<bool> reauthorize(BuildContext context) {
    if (_request case final running?) return running;
    if (authorized) unawaited(_drop('reauthorize'));
    return request(context);
  }

  Future<bool> _ask(BuildContext context) async {
    final generation = environment.sessionGeneration;
    if (environment.account is! LoggedIn || environment.accountTransitioning) return false;
    final accepted = await confirm(context);
    if (!_current(generation)) return false;
    if (!accepted) {
      _logger.info(LogCategory.app, 'app auth declined');
      _setDeclined(true, generation: generation);
      return authorized;
    }
    _logger.info(LogCategory.app, 'app auth asked');
    try {
      final token = await _client.runInSession(_client.sessionGeneration, () => _fetch(generation));
      // A logout, or another account, while the confirm was out: the token isn't this login's to keep.
      if (!_current(generation) || environment.account is! LoggedIn || environment.mid != token.mid) {
        _logger.info(LogCategory.app, 'app auth discarded', {'reason': 'account changed'});
        if (_current(generation) && environment.mid != token.mid) _toast(context.mounted ? context : null, '授权账号与当前账号不一致');
        return false;
      }
      await _hold(token, generation: generation);
      if (!_current(generation)) return false;
      _setDeclined(false, generation: generation);
      _logger.info(LogCategory.app, 'app auth done', {'days': _daysLeft(token, _now())});
      _toast(context.mounted ? context : null, '授权成功');
      return true;
    } catch (error) {
      if (!_current(generation) || error is BiliSessionChangedError) return false;
      _logger.warn(LogCategory.app, 'app auth failed', _failure(error));
      final reason = error is _AuthFailure ? error.message : requestFailureMessage(error, fallback: '请稍后重试');
      _toast(context.mounted ? context : null, '授权失败：$reason');
      return authorized;
    }
  }

  /// The code, its confirm page in the official app, then a few polls once the user is back.
  Future<AppToken> _fetch(int generation) async {
    final code = await _client.tvAuthCode();
    if (!_current(generation)) throw const BiliSessionChangedError();
    final page = Uri.tryParse(code.url);
    if (page == null || page.scheme != 'https') throw const _AuthFailure('bad page', '请稍后重试');
    final opened = await confirmInClient(page);
    if (!_current(generation)) throw const BiliSessionChangedError();
    _logger.info(LogCategory.app, 'app auth client', {'opened': opened});
    if (!opened) throw const _AuthFailure('no client', '请先安装哔哩哔哩客户端');
    for (var poll = 0; poll < quickPolls; poll++) {
      if (poll > 0) await Future<void>.delayed(pollInterval);
      if (!_current(generation)) throw const BiliSessionChangedError();
      switch (await _client.tvPoll(code.authCode)) {
        case TVLoginConfirmed(:final token):
          return token;
        case TVLoginExpired():
          throw const _AuthFailure('expired', '确认已超时，请重试');
        case TVLoginWaiting():
          break;
      }
    }
    throw const _AuthFailure('unconfirmed', '未在哔哩哔哩中确认');
  }

  /// One call; a failure keeps the token, which is good until its date. A rejection drops it through [_rejected].
  Future<void> _renew() async {
    final generation = environment.sessionGeneration;
    final original = _client.appToken;
    if (original == null || !_current(generation)) return;
    try {
      final renewed = await _client.renewAppToken();
      if (!_current(generation) || _client.appToken != original) return;
      await _hold(renewed, generation: generation);
      _logger.info(LogCategory.app, 'app token renewed', {'days': _daysLeft(renewed, _now())});
    } catch (error) {
      _logger.warn(LogCategory.app, 'app token renewal failed', _failure(error));
    }
  }

  /// [accessToken] signed the call Bilibili turned down; a rejection that arrives after the token changed is old news.
  void _rejected(String accessToken) {
    if (_client.appToken?.accessToken != accessToken) return;
    unawaited(_drop('rejected'));
    if (_rejectionAsked) return;
    _rejectionAsked = true;
    _askLater();
  }

  void _accountChanged() {
    switch (environment.account) {
      case AccountUnknown():
        // Only a login passes through unknown without a failed check. It reads logged in while the login page is
        // still up, and that page pops whatever is on top when it closes, so its end ([_loggedIn]) asks instead.
        if (!environment.accountCheckFailed) _loginUnderway = true;
      case LoggedOut():
        _loginUnderway = false;
        if (authorized) unawaited(_drop('logout'));
        _setDeclined(false);
      case LoginExpired():
        _loginUnderway = false;
      case LoggedIn():
        // Before the early return: a login whose own checks failed is first known here.
        _dropOtherAccount();
        if (_loginUnderway || _launchAsked) return;
        _launchAsked = true;
        if (!authorized && !_storeUnreadable) _askLater();
    }
  }

  void _loggedIn() {
    _loginUnderway = false;
    _launchAsked = true;
    _dropOtherAccount();
    if (!authorized) _askLater();
  }

  bool _current(int generation) => !_disposed && generation == environment.sessionGeneration && !environment.accountTransitioning;

  /// The environment has already restored the selected account's own token.
  void _sessionChanged() {
    if (_disposed) return;
    _request = null;
    _launchAsked = false;
    _rejectionAsked = false;
    _loginUnderway = false;
    _storeUnreadable = false;
    _declined = environment.hasAccountVault ? environment.appAuthDeclined : false;
    notifyListeners();
    final token = _client.appToken;
    if (token != null && token.dueForRenewal(_now())) unawaited(_renew());
    if (environment.account is LoggedIn) {
      _launchAsked = true;
      if (!authorized) _askLater();
    }
  }

  /// The token belongs to the account it was confirmed with; another account logging in can't use it.
  void _dropOtherAccount() {
    final token = _client.appToken;
    final mid = environment.mid;
    if (token != null && mid != null && token.mid != mid) {
      if (environment.hasAccountVault) {
        _client.appToken = null;
        notifyListeners();
      } else {
        unawaited(_drop('other account'));
      }
    }
  }

  /// After the current turn, so a login page popping as it hands over its login closes itself, not the confirm.
  void _askLater() {
    final generation = environment.sessionGeneration;
    Timer.run(() {
      if (!_current(generation) || authorized || _declined || environment.account is! LoggedIn) return;
      final context = navigator.currentContext;
      if (context == null) {
        _logger.warn(LogCategory.app, 'app auth not asked', {'reason': 'no navigator'});
        return;
      }
      unawaited(request(context));
    });
  }

  Future<void> _hold(AppToken token, {required int generation}) async {
    if (!_current(generation)) return;
    _client.appToken = token;
    if (!_disposed) notifyListeners();
    var saved = false;
    try {
      saved = await environment.saveAppToken(token, generation: generation);
    } catch (_) {
      saved = false;
    }
    if (!saved) _logger.warn(LogCategory.app, 'app token not saved');
  }

  Future<void> _drop(String reason) async {
    final generation = environment.sessionGeneration;
    _client.appToken = null;
    _logger.info(LogCategory.app, 'app token dropped', {'reason': reason});
    if (!_disposed) notifyListeners();
    await _deleteStored(generation);
  }

  Future<AppToken?> _stored(int generation) async {
    final String? stored;
    try {
      stored = await environment.loadAppToken();
    } catch (error) {
      if (generation == environment.sessionGeneration) _storeUnreadable = true;
      _logger.warn(LogCategory.app, 'app token unreadable', {'error': '${error.runtimeType}'});
      return null;
    }
    if (stored == null || generation != environment.sessionGeneration) return null;
    AppToken? token;
    try {
      token = AppToken.fromJson(jsonDecode(stored));
    } on FormatException {
      token = null;
    } on DecodeError {
      token = null;
    }
    if (token != null) return token;
    // The Swift app kept a bare access token here, with no refresh token or expiry to go on.
    _logger.info(LogCategory.app, 'app token dropped', {'reason': 'not json'});
    await _deleteStored(generation);
    return null;
  }

  Future<void> _deleteStored(int generation) async {
    try {
      await environment.deleteAppToken(generation: generation);
    } catch (error) {
      _logger.warn(LogCategory.app, 'app token not deleted', {'error': '${error.runtimeType}'});
    }
  }

  /// The device id, and whether the confirm was turned down, from the device file.
  Future<String> _deviceId() async {
    final path = devicePath();
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final json = jsonDecode(await file.readAsString());
          final fields = json is Map<String, Object?> ? json : const <String, Object?>{};
          if (!environment.hasAccountVault && fields[_declinedField] == true) _declined = true;
          final id = fields['buvid'];
          if (id is String && _buvidShape.hasMatch(id)) return id;
        }
      } catch (error) {
        _logger.warn(LogCategory.app, 'app device id unreadable', {'error': '${error.runtimeType}'});
      }
    }
    final id = newBuvid();
    if (path != null) {
      try {
        await File(path).parent.create(recursive: true);
        await File(path).writeAsString(jsonEncode(_deviceFile(id)), flush: true);
      } catch (error) {
        _logger.warn(LogCategory.app, 'app device id not saved', {'error': '${error.runtimeType}'});
      }
    }
    return id;
  }

  static const _declinedField = 'authDeclined';

  Map<String, Object> _deviceFile(String id) => {'buvid': id, if (_declined && !environment.hasAccountVault) _declinedField: true};

  /// Written at once: it changes only on a confirm's answer or a logout, and the file is a few bytes.
  void _setDeclined(bool declined, {int? generation}) {
    final owner = generation ?? environment.sessionGeneration;
    if (!_current(owner)) return;
    if (_declined == declined) return;
    _declined = declined;
    if (environment.hasAccountVault) {
      unawaited(environment.setAppAuthDeclined(declined, generation: owner).catchError((Object error) {
        _logger.warn(LogCategory.app, 'app auth preference not saved', {'error': '${error.runtimeType}'});
      }));
      return;
    }
    final id = _client.appBuvid;
    final path = devicePath();
    if (id == null || path == null) return;
    try {
      File(path).writeAsStringSync(jsonEncode(_deviceFile(id)), flush: true);
    } catch (error) {
      _logger.warn(LogCategory.app, 'app device file not saved', {'error': '${error.runtimeType}'});
    }
  }

  /// A context under the app's overlay, for the toasts of a confirm no page asked for.
  BuildContext? _underOverlay() {
    BuildContext? child;
    navigator.currentState?.overlay?.context.visitChildElements((element) => child ??= element);
    return child;
  }

  void _toast(BuildContext? context, String message) {
    if (_disposed) return;
    final target = context != null && Overlay.maybeOf(context, rootOverlay: true) != null ? context : _underOverlay();
    if (target != null) showToast(target, message);
  }

  static int _daysLeft(AppToken token, DateTime now) => token.expiresAt.difference(now).inDays;

  /// Codes and states only: never a token, the auth code or its page's URL.
  static Map<String, Object> _failure(Object error) => switch (error) {
    BiliAPIError(:final code) => {'code': code},
    BiliHTTPError(:final status) => {'status': status},
    _AuthFailure(:final reason) => {'reason': reason},
    _ => {'error': '${error.runtimeType}'},
  };

  @override
  void dispose() {
    _disposed = true;
    environment.removeListener(_accountChanged);
    environment.logins.removeListener(_loggedIn);
    environment.sessions.removeListener(_sessionChanged);
    if (_client.onAppTokenRejected == _rejected) _client.onAppTokenRejected = null;
    super.dispose();
  }
}

/// The token didn't come: no official app to confirm in, the code ran out, or the poll never saw the confirm.
final class _AuthFailure implements Exception {
  const _AuthFailure(this.reason, this.message);

  /// For the log.
  final String reason;

  /// For the toast.
  final String message;

  @override
  String toString() => 'AppAuthFailure($reason)';
}
