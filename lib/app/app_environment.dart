import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';

import '../account/cookie_persistence.dart';
import '../account/account_vault.dart';
import '../account/account_vault_store.dart';
import '../account/dpapi_keychain_store.dart';
import '../account/keychain_store.dart';
import '../account/web_cookies.dart';

sealed class Account {
  const Account();
}

final class AccountUnknown extends Account {
  const AccountUnknown();
}

final class LoggedOut extends Account {
  const LoggedOut();
}

final class LoggedIn extends Account {
  const LoggedIn({required this.name, required this.vip});

  final String name;
  final bool vip;
}

/// Cookies exist but Bilibili no longer accepts them (nav answered isLogin false).
final class LoginExpired extends Account {
  const LoginExpired();
}

/// The keychain login, the cookie jar and the API client (port of AppEnvironment.swift's account half). On the
/// iPhone the jar starts from the Swift app's keychain item, so the app opens logged in with no login screen;
/// Windows keeps its own login in a DPAPI-encrypted file (`DpapiKeychainStore`).
class AppEnvironment extends ChangeNotifier {
  AppEnvironment._(
      {required this.cookies,
      required this.client,
      required this._persistence,
      required this._keychain,
      required this.webCookies,
      required this._serverLogout,
      required this.pcLogin,
      required this._logger,
      required this._transport,
      AccountVaultStore? accountStore,
      AccountVault? vault,
      this._vaultUnreadable = false})
      : _vaultStore = accountStore,
        _vault = vault ?? AccountVault(),
        _vaultPresent = vault != null,
        _selectedMid = vault?.activeMid;

  /// `http`, `httpFactory`, `keychain` and `webCookies` are for tests; the app passes none, except the Windows
  /// build's keychain. [guarded] (Windows, where KaiC's real login is read only) sends every call through
  /// [GuardedTransport], whose only allowed write is the website's logout; [serverLogout] has 退出登录 end the
  /// session on Bilibili's side first; [pcLogin] has the PC's 登录 page offer the QR login.
  static Future<AppEnvironment> load(
      {KeychainStore? keychain,
      AccountVaultStore? accountStore,
      WebCookies? webCookies,
      HTTPTransport? http,
      HTTPTransport Function() httpFactory = platformHttpTransport,
      bool guarded = false,
      bool serverLogout = false,
      bool pcLogin = false,
      Logger? logger}) async {
    final log = logger ?? Logger.shared;
    final rawStore = keychain ?? KeychainStore.platform();
    final store = _GuardedKeychain(rawStore, log);
    final vaultStore = accountStore ?? switch (rawStore) {
      ChannelKeychainStore() => ChannelAccountVaultStore(),
      DpapiKeychainStore(:final path) => DpapiAccountVaultStore('$path.accounts'),
      _ => null,
    };
    AccountVault? vault;
    var vaultUnreadable = false;
    if (vaultStore != null) {
      try {
        switch (await vaultStore.load()) {
          case StoredAccountVault(vault: final stored):
            vault = stored;
          case NoAccountVault():
            break;
          case AccountVaultLoadFailed():
            vaultUnreadable = true;
        }
      } catch (_) {
        vaultUnreadable = true;
      }
    }
    final persistence = CookiePersistence(store, logger: log);
    final jar = CookieJar(vault?.accounts[vault.activeMid]?.cookies ??
        (vault != null || vaultUnreadable ? const <String, String>{} : await persistence.load()));
    if (persistence.blocked) log.warn(LogCategory.app, 'keychain read failed, cookie writes held back');
    final transport = http ?? httpTransportOrFallback(httpFactory, log);
    final guardedHttp = guarded
            ? GuardedTransport(
                transport,
                writesAllowed: {'passport.bilibili.com/login/exit/v2'},
                uncounted: {'/x/passport-login/web/qrcode/generate', '/x/passport-login/web/qrcode/poll'},
                logger: log,
              )
            : transport;
    final client = BiliClient(
        transport: guardedHttp,
        cookies: jar,
        logger: log);
    final environment = AppEnvironment._(
        cookies: jar,
        client: client,
        persistence: persistence,
        keychain: store,
        webCookies: webCookies ?? WebCookies.platform(),
        serverLogout: serverLogout,
        pcLogin: pcLogin,
        logger: log,
        transport: guardedHttp,
        accountStore: vaultStore,
        vault: vault,
        vaultUnreadable: vaultUnreadable);
    final token = vault?.accounts[vault.activeMid]?.appToken;
    client.appToken = token != null && !token.expired(DateTime.now()) ? token : null;
    jar.onChange = environment._cookiesChanged;
    return environment;
  }

  final CookieJar cookies;
  final BiliClient client;
  final CookiePersistence _persistence;
  final KeychainStore _keychain;
  final HTTPTransport _transport;
  final AccountVaultStore? _vaultStore;
  AccountVault _vault;
  bool _vaultPresent;
  bool _vaultUnreadable;
  int? _selectedMid;
  bool _publishing = false;
  bool _transitioning = false;
  Future<void> _vaultWriting = Future.value();
  Future<void>? _migration;
  bool _demo = false;
  final Map<int, SavedAccount> _demoAccounts = {};
  bool _preparedChange = false;

  /// Services quiesce old playback and native downloads before credentials are committed.
  Future<void> Function()? beforeAccountChange;
  VoidCallback? accountChangeAborted;

  /// The keychain the login came from, for the app token's item beside it.
  KeychainStore get keychain => _keychain;

  /// The login web view's store, read by the login page and cleared on logout.
  final WebCookies webCookies;
  final bool _serverLogout;

  /// A `--real-account` run on the PC: its 登录 page offers the QR login (KaiC's last fallback for checking APIs,
  /// launched only with his OK each time). Every other PC run says 请在手机上登录.
  final bool pcLogin;
  final Logger _logger;
  Account _account = const AccountUnknown();
  int? _mid;
  String? _face;
  bool _accountCheckFailed = false;

  Account get account => _account;

  /// The logged-in account's uid.
  int? get mid => _mid;

  /// The logged-in account's avatar URL.
  String? get face => _face;

  /// The last nav call failed (network, not a verdict), so [account] is still unknown.
  bool get accountCheckFailed => _accountCheckFailed;

  /// The check's answer while it reads logged in, and when it came: 我的 takes the account from it rather than ask nav
  /// again just after launch.
  ({NavInfo nav, DateTime at})? get accountNav => _accountNav;
  ({NavInfo nav, DateTime at})? _accountNav;

  /// Counts the logins [didLogin] completed. A login over an account that already read logged in leaves [account]
  /// where it was, so what belongs to the account listens here rather than to its changes.
  ValueListenable<int> get logins => _logins;
  final _logins = ValueNotifier<int>(0);

  /// Identity boundaries, including reauthentication as the same account.
  ValueListenable<int> get sessions => _sessions;
  final _sessions = ValueNotifier<int>(0);
  int get sessionGeneration => _epoch;
  int? get activeAccountMid => _selectedMid ?? _mid;
  List<SavedAccount> get savedAccounts => List.unmodifiable((_demo ? _demoAccounts : _vault.accounts).values);
  bool get hasAccountVault => _vaultStore != null || _demo;
  bool get accountTransitioning => _transitioning;
  bool get appAuthDeclined => _vault.accounts[_selectedMid]?.authDeclined ?? false;

  Future<String?> loadAppToken() async {
    if (_vaultUnreadable) throw const AccountSwitchFailure('无法读取已保存账号，请重试');
    if (!_vaultPresent) return _keychain.loadAppToken();
    final token = _vault.accounts[_selectedMid]?.appToken;
    return token == null ? null : _encodeAppToken(token);
  }

  Future<bool> saveAppToken(AppToken token, {required int generation}) async {
    if (generation != _epoch) return false;
    if (!_vaultPresent) return _keychain.saveAppToken(_encodeAppToken(token));
    if (token.mid != activeAccountMid) return false;
    return _writeVault((vault) {
      final account = vault.accounts[token.mid];
      if (generation != _epoch || account == null) return null;
      return AccountVault(activeMid: vault.activeMid,
          accounts: {...vault.accounts, token.mid: account.copyWith(appToken: token)});
    });
  }

  Future<void> deleteAppToken({required int generation}) async {
    if (generation != _epoch) return;
    if (!_vaultPresent) return _keychain.deleteAppToken();
    final owner = _selectedMid;
    if (!await _writeVault((vault) {
      final account = vault.accounts[owner];
      if (generation != _epoch || account == null) return null;
      return AccountVault(activeMid: vault.activeMid,
          accounts: {...vault.accounts, owner!: account.copyWith(clearToken: true)});
    })) {
      throw const AccountSwitchFailure('授权状态未能保存');
    }
  }

  Future<void> setAppAuthDeclined(bool declined, {required int generation}) async {
    if (!_vaultPresent || generation != _epoch) return;
    final owner = _selectedMid;
    await _writeVault((vault) {
      final account = vault.accounts[owner];
      if (generation != _epoch || account == null) return null;
      return AccountVault(activeMid: vault.activeMid,
          accounts: {...vault.accounts, owner!: account.copyWith(authDeclined: declined)});
    });
  }

  String get accountLabel => switch (_account) {
        LoggedIn(:final name) => name.isEmpty ? '已登录' : name,
        LoggedOut() => '未登录',
        LoginExpired() => '登录已失效',
        AccountUnknown() => _accountCheckFailed ? '账号确认失败' : '正在确认账号…',
      };

  /// Returns false when Bilibili could not be asked (network error); [account] then keeps its last value. A check
  /// already running answers every caller (launch, coming back to the app, returning to home) with one request.
  Future<bool> refreshAccount() {
    if (_fake) return Future.value(true);
    if (_checking case final running?) return running;
    late final Future<bool> check;
    check = _checkAccount().whenComplete(() {
      if (identical(_checking, check)) _checking = null;
    });
    return _checking = check;
  }

  bool _fake = false;

  /// A `--fake-account` run on the PC: logged in as a made-up 测试账号 with mid 1, so the page's actions can be pressed
  /// against the in-memory `FakePageApi`. No call goes out as this account, and nothing reports watch progress.
  bool get fake => _fake;

  void useFakeAccount() {
    _demo = true;
    _demoAccounts.addAll({
      1: SavedAccount(mid: 1, name: '测试账号', cookies: const {}),
      2: SavedAccount(mid: 2, name: '测试账号二', cookies: const {}),
    });
    _selectedMid = 1;
    _fake = true;
    _account = const LoggedIn(name: '测试账号', vip: false);
    _mid = 1;
    _face = null;
    _accountNav = null;
    notifyListeners();
  }

  Future<bool>? _checking;

  /// Bumped by every login and logout, so a check already on its way answers for cookies that are gone.
  int _epoch = 0;

  /// The login page's cookies once Bilibili set SESSDATA (BiliNative `AppEnvironment.didLogin`): they join the jar
  /// and the keychain, and the account is checked again, up to 3 times. Completes with whether it is now logged in.
  Future<bool> didLogin(Map<String, String> cookies, {int? expectedMid, bool Function()? isCurrent}) async {
    if (_vaultStore != null) {
      return _transition(() async {
        await _readyForTransition();
        final epoch = _epoch;
        final candidate = _candidate(cookies);
        NavInfo? nav;
        for (var attempt = 0; attempt < 3; attempt++) {
          if (attempt > 0) await Future<void>.delayed(Duration(seconds: attempt));
          if (epoch != _epoch || isCurrent?.call() == false) return false;
          try {
            await candidate.ensureRiskCookies();
            nav = await candidate.nav();
            if (nav.isLogin) break;
          } catch (error) {
            _logger.warn(LogCategory.app, 'candidate check failed', {'error': '${error.runtimeType}'});
            _accountCheckFailed = true;
          }
        }
        if (epoch != _epoch || isCurrent?.call() == false) return false;
        if (nav == null) throw const AccountSwitchFailure('网络错误，请重试');
        if (!nav.isLogin || (nav.mid ?? 0) <= 0) {
          _accountCheckFailed = false;
          throw const AccountSwitchFailure('登录已失效，请重新登录', requiresLogin: true);
        }
        if (expectedMid != null && nav.mid != expectedMid) {
          throw const AccountSwitchFailure('登录的账号不一致，请使用所选账号重新登录', requiresLogin: true);
        }
        final account = _accountFromNav(nav, candidate.cookies.all);
        return _commitAccount(account, nav, isCurrent: isCurrent);
      });
    }
    if (isCurrent?.call() == false) return false;
    _beginSession();
    final epoch = _epoch;
    _fake = false;
    _logoutIncomplete = false;
    _persistence.unblock();
    this.cookies.replaceAll({...this.cookies.all, ...cookies});
    final saved = _persistence.flush();
    _account = const AccountUnknown();
    _accountCheckFailed = false;
    _accountNav = null;
    notifyListeners();
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future<void>.delayed(Duration(seconds: attempt));
      if (epoch != _epoch) break;
      await refreshAccount();
      if (_account is LoggedIn) break;
    }
    final loggedIn = _account is LoggedIn;
    _logger.info(LogCategory.app, 'login', {'count': cookies.length, 'loggedIn': loggedIn});
    // The session works from the jar either way; only the next launch would find itself logged out.
    _loginSaved = await saved;
    if (!_loginSaved) _logger.error(LogCategory.app, 'login not saved to the keychain', {'loggedIn': loggedIn});
    if (epoch == _epoch) {
      _sessions.value = _epoch;
      if (loggedIn) _logins.value += 1;
    }
    return loggedIn;
  }

  /// Validates a remembered session without replacing the working session first.
  Future<void> switchAccount(int mid) => _transition(() async {
    if (activeAccountMid == mid && _account is LoggedIn) return;
    if (_demo) {
      final target = _demoAccounts[mid];
      if (target == null) throw const AccountSwitchFailure('账号不可用');
      await _prepareAccountChange();
      _beginSession();
      _selectedMid = mid;
      _mid = mid;
      _face = target.face;
      _accountNav = null;
      _fake = true;
      _account = LoggedIn(name: target.name, vip: target.vip);
      _finishSession(loggedIn: true);
      return;
    }
    await _readyForTransition();
    final target = _vault.accounts[mid];
    if (target == null) throw const AccountSwitchFailure('账号不可用');
    final candidate = _candidate(target.cookies);
    final NavInfo nav;
    try {
      await candidate.ensureRiskCookies();
      nav = await candidate.nav();
    } catch (_) {
      throw const AccountSwitchFailure('网络错误，账号未切换，请重试');
    }
    if (!nav.isLogin || nav.mid != mid) {
      await _writeVault((vault) => AccountVault(activeMid: vault.activeMid,
          accounts: {...vault.accounts, mid: target.copyWith(expired: true)}));
      notifyListeners();
      throw const AccountSwitchFailure('登录已失效，请重新登录', requiresLogin: true);
    }
    await _commitAccount(_accountFromNav(nav, candidate.cookies.all), nav);
  });

  Future<void> removeAccount(int mid) async {
    if (mid == activeAccountMid) return logout();
    await _transition(() async {
      if (_demo) {
        _demoAccounts.remove(mid);
        notifyListeners();
        return;
      }
      await _readyForTransition();
      final target = _vault.accounts[mid];
      if (target == null) return;
      if (_serverLogout) await _endServerSession(_candidate(target.cookies));
      if (!await _writeVault((vault) => AccountVault(activeMid: vault.activeMid,
          accounts: Map.of(vault.accounts)..remove(mid)))) {
        throw const AccountSwitchFailure('账号未能移除，请重试');
      }
      notifyListeners();
    });
  }

  BiliClient _candidate(Map<String, String> cookies) =>
      BiliClient(transport: _transport, cookies: CookieJar(cookies), logger: _logger);

  SavedAccount _accountFromNav(NavInfo nav, Map<String, String> cookies) {
    final old = _vault.accounts[nav.mid];
    final token = old?.appToken;
    return SavedAccount(mid: nav.mid!, name: nav.uname ?? '', face: nav.face, vip: nav.isVip,
        cookies: cookies, appToken: token != null && !token.expired(DateTime.now()) ? token : null,
        authDeclined: old?.authDeclined ?? false);
  }

  Future<T> _transition<T>(Future<T> Function() run) async {
    if (_transitioning) throw const AccountSwitchFailure('正在切换账号，请稍后');
    _transitioning = true;
    notifyListeners();
    try {
      return await run();
    } finally {
      if (_preparedChange) {
        _preparedChange = false;
        accountChangeAborted?.call();
      }
      _transitioning = false;
      notifyListeners();
    }
  }

  Future<void> _readyForTransition() async {
    if (_vaultUnreadable) {
      final loaded = await _vaultStore?.load();
      if (loaded is! StoredAccountVault) throw const AccountSwitchFailure('无法读取已保存账号，请重试');
      _vaultUnreadable = false;
      _vault = loaded.vault;
      _vaultPresent = true;
      _selectedMid = _vault.activeMid;
    }
    await _migration;
    if (!_vaultPresent && cookies.value('SESSDATA') != null) {
      final nav = _accountNav?.nav;
      if (nav == null || !nav.isLogin || nav.mid == null) {
        throw const AccountSwitchFailure('请先确认当前账号后重试');
      }
      await _migrateLegacy(nav, _epoch);
      if (!_vaultPresent) throw const AccountSwitchFailure('当前账号未能保存，请重试');
    }
    await _vaultWriting;
  }

  Future<bool> _commitAccount(SavedAccount account, NavInfo nav, {bool Function()? isCurrent}) async {
    if (isCurrent?.call() == false) return false;
    await _prepareAccountChange();
    if (isCurrent?.call() == false) return false;
    final previous = _vault;
    // A single writer orders the outgoing session's latest cookie/token updates before this selection.
    final ok = await _writeVault((vault) {
      if (isCurrent?.call() == false) return null;
      return AccountVault(activeMid: account.mid, accounts: {...vault.accounts, account.mid: account});
    });
    _loginSaved = ok;
    if (!ok) throw const AccountSwitchFailure('账号未能保存，请重试');
    if (isCurrent?.call() == false) {
      await _writeVault((_) => previous);
      return false;
    }
    await _clearLegacy();
    if (isCurrent?.call() == false) {
      await _writeVault((_) => previous);
      return false;
    }
    _beginSession();
    _publishing = true;
    cookies.replaceAll(account.cookies);
    _publishing = false;
    client.appToken = account.appToken;
    _selectedMid = account.mid;
    _mid = account.mid;
    _face = account.face;
    _account = LoggedIn(name: account.name, vip: account.vip);
    _accountNav = (nav: nav, at: DateTime.now());
    _accountCheckFailed = false;
    _logoutIncomplete = false;
    _fake = false;
    _finishSession(loggedIn: true);
    return true;
  }

  void _beginSession() {
    _epoch++;
    _checking = null;
    client.invalidateSession();
  }

  Future<void> _prepareAccountChange() async {
    _preparedChange = true;
    await beforeAccountChange?.call();
  }

  void _finishSession({bool loggedIn = false}) {
    _preparedChange = false;
    _transitioning = false;
    notifyListeners();
    _sessions.value = _epoch;
    if (loggedIn) _logins.value++;
  }

  void _cookiesChanged(Map<String, String> snapshot) {
    if (_publishing || _vaultUnreadable) return;
    if (!_vaultPresent) {
      unawaited(_persistence.save(snapshot));
      return;
    }
    final owner = _selectedMid;
    final generation = _epoch;
    unawaited(_writeVault((vault) {
      final account = vault.accounts[owner];
      if (generation != _epoch || account == null) return null;
      return AccountVault(activeMid: vault.activeMid,
          accounts: {...vault.accounts, owner!: account.copyWith(cookies: snapshot)});
    }));
  }

  Future<bool> _writeVault(AccountVault? Function(AccountVault vault) change) {
    final store = _vaultStore;
    if (store == null || _vaultUnreadable) return Future.value(false);
    final result = _vaultWriting.then((_) async {
      final next = change(_vault);
      if (next == null) return true;
      try {
        if (!await store.save(next)) return false;
        _vault = next;
        _vaultPresent = true;
        return true;
      } catch (_) {
        _logger.warn(LogCategory.app, 'account vault not saved');
        return false;
      }
    });
    _vaultWriting = result.then<void>((_) {});
    return result;
  }

  Future<void> _migrateLegacy(NavInfo nav, int epoch) async {
    if (_vaultStore == null || _vaultPresent || _vaultUnreadable || (nav.mid ?? 0) <= 0) return;
    if (_migration case final running?) return running;
    final work = () async {
      AppToken? token = client.appToken;
      try {
        final stored = await _keychain.loadAppToken();
        if (token == null && stored != null) token = AppToken.fromJson(jsonDecode(stored));
      } catch (_) {
        // The cookie session is usable; retain the legacy token until storage can be read safely.
        return;
      }
      if (epoch != _epoch) return;
      final account = SavedAccount(mid: nav.mid!, name: nav.uname ?? '', face: nav.face, vip: nav.isVip,
          cookies: cookies.all, appToken: token?.mid == nav.mid ? token : null);
      await _persistence.flush();
      if (epoch != _epoch) return;
      if (!await _writeVault((_) => AccountVault(activeMid: account.mid, accounts: {account.mid: account}))) return;
      final readback = await _vaultStore.load();
      if (readback is! StoredAccountVault || readback.vault.activeMid != account.mid ||
          readback.vault.accounts[account.mid]?.cookies['SESSDATA'] != account.cookies['SESSDATA']) {
        _vaultUnreadable = true;
        return;
      }
      _selectedMid = account.mid;
      await _clearLegacy();
    }();
    _migration = work;
    try {
      await work;
    } finally {
      _migration = null;
    }
  }

  Future<void> _clearLegacy() async {
    if (!_vaultPresent) return;
    await _persistence.flush();
    await _logoutStep('legacy cookies', _keychain.deleteCookies);
    await _logoutStep('legacy token', _keychain.deleteAppToken);
  }

  Future<void> _endServerSession(BiliClient client) async {
    try {
      await client.webLogout();
    } catch (error) {
      if (error is! BiliAPIError || error.code != -101) throw const ServerLogoutFailed();
    }
  }

  /// 退出登录 (BiliNative `AppEnvironment.logout`): empties the jar, deletes the keychain cookies and app token, and
  /// clears the web view's data. A step that fails is logged and the rest still run. A `--fake-account` run, which
  /// stored nothing, just stops being fake.
  ///
  /// With `serverLogout` (Windows) the website's logout goes first, while the jar still holds the login. If it fails,
  /// nothing is touched and [ServerLogoutFailed] is thrown, so the session isn't left alive on Bilibili's side with
  /// no cookies here to end it; -101 means Bilibili had ended it already, and the logout goes on.
  ///
  /// Throws [LogoutIncomplete] when the jar or the keychain cookies couldn't be emptied. The account still reads
  /// logged out, which is true of this run (the jar sends no login), but the keychain may hold the login for the
  /// next launch, so the caller hears of it instead of a logout that only seemed to work.
  Future<void> logout() async {
    if (_vaultStore != null || _demo) {
      return _transition(() async {
        final demo = _demo;
        await _prepareAccountChange();
        if (_demo) {
          _demoAccounts.remove(activeAccountMid);
        } else {
          await _readyForTransition();
          if (_serverLogout && cookies.value('SESSDATA') != null) await _endServerSession(client);
          final owner = _selectedMid;
          if (!await _writeVault((vault) => AccountVault(accounts: Map.of(vault.accounts)..remove(owner)))) {
            _logoutIncomplete = true;
            throw const LogoutIncomplete();
          }
        }
        _beginSession();
        _publishing = true;
        cookies.removeAll();
        _publishing = false;
        client.appToken = null;
        _selectedMid = null;
        _fake = false;
        _logoutIncomplete = false;
        _signedOut();
        if (!demo) {
          await _clearLegacy();
          await _logoutStep('web data', webCookies.clearAll);
        }
      });
    }
    _beginSession();
    _logoutIncomplete = false;
    if (_fake) {
      _fake = false;
      _signedOut();
      return;
    }
    if (_serverLogout && cookies.value('SESSDATA') != null) {
      try {
        await client.webLogout();
      } catch (error) {
        if (error is! BiliAPIError || error.code != -101) {
          _logger.warn(LogCategory.app, 'logout step failed', {'step': 'server', 'error': '${error.runtimeType}'});
          throw const ServerLogoutFailed();
        }
      }
    }
    _persistence.unblock();
    final jarEmptied = await _logoutStep('jar', () async => cookies.removeAll());
    final keychainEmptied = await _logoutStep('keychain cookies', _keychain.deleteCookies);
    await _logoutStep('app token', _keychain.deleteAppToken);
    await _logoutStep('web data', webCookies.clearAll);
    _signedOut();
    // The fingerprint cookies went with the jar, and the web API answers 412 without them.
    unawaited(client.ensureRiskCookies().catchError((Object error) {
      _logger.warn(LogCategory.app, 'risk cookies failed', {'error': '$error'});
    }));
    if (!jarEmptied || !keychainEmptied) {
      _logoutIncomplete = true;
      notifyListeners();
      throw const LogoutIncomplete();
    }
  }

  bool _logoutIncomplete = false;
  bool _loginSaved = true;

  /// Whether the last [didLogin] reached the keychain (on Windows, `login.bin`). The PC's QR login warns when it
  /// didn't: the next launch would be logged out and ask for another scan, another new device on the account.
  bool get loginSaved => _loginSaved;

  /// The stored login couldn't be read (on Windows, a `login.bin` DPAPI can't open). 设置 offers 退出登录, which
  /// deletes it.
  bool get loginUnreadable => _keychainUnread;

  /// The last 退出登录 left the login in the keychain: 设置 keeps offering it so it can be tried again.
  bool get logoutIncomplete => _logoutIncomplete;

  Future<bool> _logoutStep(String step, Future<void> Function() run) async {
    try {
      await run();
      return true;
    } catch (error) {
      _logger.warn(LogCategory.app, 'logout step failed', {'step': step, 'error': '$error'});
      return false;
    }
  }

  void _signedOut() {
    _account = const LoggedOut();
    _accountCheckFailed = false;
    _mid = null;
    _face = null;
    _accountNav = null;
    _logger.info(LogCategory.app, 'logout');
    _finishSession();
  }

  Future<bool> _checkAccount() async {
    final epoch = _epoch;
    await _retryBlockedKeychainLoad(epoch);
    try {
      await client.ensureRiskCookies();
      final nav = await client.nav();
      if (epoch != _epoch) return true;
      _accountCheckFailed = false;
      if (nav.isLogin) {
        _account = LoggedIn(name: nav.uname ?? '', vip: nav.isVip);
        _mid = nav.mid;
        _face = nav.face;
        _accountNav = (nav: nav, at: DateTime.now());
        final mid = nav.mid;
        _logger.info(LogCategory.app, 'account', {'user': mid == null ? '?' : Redactor.mid(mid), 'vip': nav.isVip});
        await _migrateLegacy(nav, epoch);
        if (epoch != _epoch) return false;
        if (_vaultPresent && _selectedMid != null && nav.mid != _selectedMid) {
          _account = const LoginExpired();
          _mid = null;
          _face = null;
          _accountNav = null;
        } else if (_vaultPresent && nav.mid != null) {
          final account = _vault.accounts[nav.mid];
          if (account != null) {
            final snapshot = cookies.all;
            unawaited(_writeVault((vault) {
              final current = vault.accounts[nav.mid];
              if (current == null || epoch != _epoch) return null;
              return AccountVault(activeMid: vault.activeMid,
                  accounts: {...vault.accounts, nav.mid!: current.copyWith(name: nav.uname, face: nav.face,
                      vip: nav.isVip, cookies: snapshot, expired: false)});
            }));
          }
        }
      } else if (_keychainUnread) {
        _account = const AccountUnknown();
        _accountCheckFailed = true;
        _accountNav = null;
        _logger.warn(LogCategory.app, 'account unknown, keychain unread');
      } else {
        _account = cookies.value('SESSDATA') == null ? const LoggedOut() : const LoginExpired();
        _mid = null;
        _face = null;
        _accountNav = null;
        _logger.info(LogCategory.app, 'account', {'user': 'none', 'expired': _account is LoginExpired});
      }
      notifyListeners();
      return true;
    } catch (error) {
      _logger.warn(LogCategory.app, 'nav failed', {'error': '$error'});
      if (epoch != _epoch) return false;
      if (_account is AccountUnknown) {
        if (cookies.value('SESSDATA') == null && !_keychainUnread) {
          _account = const LoggedOut();
        } else {
          _accountCheckFailed = true;
        }
      }
      notifyListeners();
      return false;
    }
  }

  /// The keychain couldn't be read and the jar has no session: the login may well be stored, so this isn't 未登录 (that
  /// would invite a second login). The account stays unknown, which coming back to the app or to home asks again.
  bool get _keychainUnread => _vaultUnreadable || (_persistence.blocked && cookies.value('SESSDATA') == null);

  /// After a failed read the stored cookies may still be there; once a read works they join the jar.
  Future<void> _retryBlockedKeychainLoad(int epoch) async {
    if (!_persistence.blocked) return;
    final stored = await _persistence.reload();
    if (stored == null || _persistence.blocked || epoch != _epoch) return;
    cookies.replaceAll({...stored, ...cookies.all});
  }

  @override
  void dispose() {
    _logins.dispose();
    _sessions.dispose();
    super.dispose();
  }
}

String _encodeAppToken(AppToken token) => jsonEncode(token.toJson());

final class AccountSwitchFailure implements Exception {
  const AccountSwitchFailure(this.message, {this.requiresLogin = false});
  final String message;
  final bool requiresLogin;
  @override
  String toString() => 'AccountSwitchFailure';
}

/// [AppEnvironment.logout] couldn't empty the jar or delete the keychain's cookies.
final class LogoutIncomplete implements Exception {
  const LogoutIncomplete();

  @override
  String toString() => 'LogoutIncomplete';
}

/// Bilibili didn't confirm the website's logout; the login is kept so 退出登录 can be tried again.
final class ServerLogoutFailed implements Exception {
  const ServerLogoutFailed();

  @override
  String toString() => 'ServerLogoutFailed';
}

/// URLSession on the iPhone, as the Swift app's API client: ephemeral, with its own cookie store off, since
/// the jar sets the Cookie header. dart:io elsewhere.
HTTPTransport platformHttpTransport() {
  if (!Platform.isIOS) return ClientHTTPTransport();
  final configuration = URLSessionConfiguration.ephemeralSessionConfiguration()
    ..httpShouldSetCookies = false
    ..httpCookieAcceptPolicy = NSHTTPCookieAcceptPolicy.NSHTTPCookieAcceptPolicyNever
    ..timeoutIntervalForRequest = const Duration(seconds: 15);
  return ClientHTTPTransport(client: CupertinoClient.fromSessionConfiguration(configuration));
}

/// cupertino_http reaches URLSession through native bindings that can fail to load; the app then talks to
/// Bilibili over dart:io rather than not starting.
HTTPTransport httpTransportOrFallback(HTTPTransport Function() make, Logger logger) {
  try {
    return make();
  } catch (error) {
    logger.error(LogCategory.app, 'http transport failed, using dart:io', {'error': '$error'});
    return ClientHTTPTransport();
  }
}

/// A keychain channel that throws (no native side yet, a platform error) counts as a failed read, so the
/// write block keeps a login that may still be stored.
final class _GuardedKeychain implements KeychainStore {
  const _GuardedKeychain(this._inner, this._logger);

  final KeychainStore _inner;
  final Logger _logger;

  @override
  Future<CookieLoad> loadCookies() async {
    try {
      return await _inner.loadCookies();
    } catch (error) {
      _logger.error(LogCategory.app, 'keychain read threw', {'error': '$error'});
      return const CookieLoadFailed(-1);
    }
  }

  @override
  Future<bool> saveCookies(Map<String, String> cookies) => _inner.saveCookies(cookies);

  @override
  Future<void> deleteCookies() => _inner.deleteCookies();

  @override
  Future<String?> loadAppToken() => _inner.loadAppToken();

  @override
  Future<bool> saveAppToken(String token) => _inner.saveAppToken(token);

  @override
  Future<void> deleteAppToken() => _inner.deleteAppToken();
}
