import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';

import '../app/app_environment.dart';
import '../home/feed_model.dart' show requestFailureMessage;
import 'me_api.dart';
import 'me_profile_store.dart';

/// What 我的's header shows of the account.
@immutable
final class MeProfile {
  const MeProfile({
    this.mid,
    required this.name,
    required this.face,
    required this.level,
    required this.coins,
    required this.bcoin,
    this.pendant,
    this.vip = false,
    this.vipLabel = '',
    this.vipBadge = false,
  });

  factory MeProfile.fromNav(NavInfo nav) => MeProfile(
    mid: nav.mid,
    name: nav.uname ?? '',
    face: nav.face ?? '',
    pendant: nav.pendant,
    level: nav.level,
    coins: nav.coins,
    bcoin: nav.bcoin,
    vip: nav.isVip,
    vipLabel: nav.vipLabel,
    vipBadge: nav.vipBadge,
  );

  /// Null when nav left it out; the space then opens nothing.
  final int? mid;
  final String name;
  final String face;

  /// The avatar frame's picture, if the account wears one.
  final String? pendant;
  final int level;

  /// 硬币 and B币 as the nav answered them.
  final double coins;
  final double bcoin;

  /// A current 大会员: the 会员 card shows (hidden otherwise, no screenshot of it).
  final bool vip;

  /// The pink pill after the level, such as 年度大会员; empty hides it.
  final String vipLabel;

  /// The 大 badge on the avatar's corner.
  final bool vipBadge;

  @override
  bool operator ==(Object other) =>
      other is MeProfile &&
      other.mid == mid &&
      other.name == name &&
      other.face == face &&
      other.pendant == pendant &&
      other.level == level &&
      other.coins == coins &&
      other.bcoin == bcoin &&
      other.vip == vip &&
      other.vipLabel == vipLabel &&
      other.vipBadge == vipBadge;

  @override
  int get hashCode => Object.hash(mid, name, face, pendant, level, coins, bcoin, vip, vipLabel, vipBadge);
}

/// 动态, 关注 and 粉丝.
@immutable
final class MeCounts {
  const MeCounts({required this.dynamics, required this.following, required this.followers});

  factory MeCounts.fromStat(NavStat stat) =>
      MeCounts(dynamics: stat.dynamicCount, following: stat.following, followers: stat.follower);

  final int dynamics;
  final int following;
  final int followers;

  @override
  bool operator ==(Object other) =>
      other is MeCounts && other.dynamics == dynamics && other.following == following && other.followers == followers;

  @override
  int get hashCode => Object.hash(dynamics, following, followers);
}

/// What 我的 draws.
sealed class MeView {
  const MeView();
}

/// No account: the grey avatar and 点击登录, counts as -, no 会员 card.
final class MeLoggedOut extends MeView {
  const MeLoggedOut();
}

/// Logged in, nothing answered yet.
final class MeLoading extends MeView {
  const MeLoading();
}

/// The account, with [counts] null until stat first answers.
final class MeShown extends MeView {
  const MeShown(this.profile, this.counts);

  final MeProfile profile;
  final MeCounts? counts;

  @override
  bool operator ==(Object other) => other is MeShown && other.profile == profile && other.counts == counts;

  @override
  int get hashCode => Object.hash(profile, counts);
}

/// Logged in, and the first load failed with nothing to show; [message] is the user-facing reason.
final class MeFailed extends MeView {
  const MeFailed(this.message);

  final String message;

  @override
  bool operator ==(Object other) => other is MeFailed && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// 我的's account and counts, following the login.
///
/// One load is out at a time, nav and stat side by side; a showing or a pull meanwhile joins it. Every login and
/// logout drops what is still out, so an answer for the account before never shows. The last account shown is kept
/// in [MeProfileStore], so a launch as the same account starts from it rather than loading.
class MeModel extends ChangeNotifier {
  MeModel({
    required this._api,
    required AppEnvironment environment,
    MeProfileStore? store,
    this.quietGap = const Duration(seconds: 30),
    DateTime Function()? now,
    Logger? logger,
  }) : _environment = environment,
       _store = store ?? MeProfileStore.memory(),
       _now = now ?? DateTime.now,
       _logger = logger ?? Logger.shared,
       _account = environment.account {
    switch (_account) {
      case LoggedOut() || LoginExpired():
        _store.delete();
        _view = const MeLoggedOut();
      case LoggedIn() || AccountUnknown():
        _view = _keptView() ?? const MeLoading();
    }
    environment.addListener(_accountChanged);
    environment.logins.addListener(_loginCompleted);
    _sessionGeneration = environment.sessionGeneration;
    environment.sessions.addListener(_sessionChanged);
  }

  /// How long after launch the hidden page loads ([preload]): 推荐's first load and playback go first.
  static const preloadDelay = Duration(seconds: 3);

  final MeApi _api;
  final AppEnvironment _environment;
  final MeProfileStore _store;
  final DateTime Function() _now;
  final Logger _logger;

  /// How long after any load [shown] waits before loading again.
  final Duration quietGap;

  /// The account as it last settled. Unknown only until the launch's check answers, and counted as logged in then,
  /// as 历史记录 and 我的收藏 do.
  Account _account;
  MeView _view = const MeLoading();
  Future<String?>? _loading;
  DateTime? _lastLoad;

  /// Bumped by every login and logout.
  int _generation = 0;
  int _sessionGeneration = 0;

  /// The account's turn to logged in has loaded already, so the login count that follows asks nothing more.
  bool _loginLoaded = false;
  bool _preloaded = false;
  bool _disposed = false;

  MeView get view => _view;

  bool get _signedIn => _account is LoggedIn || _account is AccountUnknown;

  /// The tab came on screen: loads the first time, then again quietly (the page stays as it is) at most every
  /// [quietGap]; a failed page tries again whenever it shows. Logged out it calls nothing.
  void shown() {
    if (!_signedIn || _loading != null) return;
    final last = _lastLoad;
    final failed = _view is MeFailed;
    if (!failed && last != null && _now().difference(last) < quietGap) return;
    if (failed) _show(const MeLoading());
    unawaited(_load());
  }

  /// The hidden page's load a few seconds after launch ([preloadDelay]), so 我的 is drawn complete the first time it
  /// opens. Once per launch and only before any other load; it counts toward [quietGap] as any load does, unless nav
  /// failed, so opening the page then tries again. The account check's nav stands in for its own while it is fresh.
  /// Not while a failed check leaves the account unknown: the keychain may be unread, and nav would say logged out.
  void preload() {
    final checkable = switch (_account) {
      LoggedIn() => true,
      AccountUnknown() => !_environment.accountCheckFailed,
      LoggedOut() || LoginExpired() => false,
    };
    if (_preloaded || !checkable || _lastLoad != null) return;
    _preloaded = true;
    unawaited(_load(background: true));
  }

  /// The pull. Completes when the answer is in, with the message to toast when nav or stat failed (a failure keeps
  /// the page as it was). Null on success.
  Future<String?> refresh() => _signedIn ? _load() : Future<String?>.value();

  Future<String?> _load({bool background = false}) {
    if (_loading case final running?) return running;
    _lastLoad = _now();
    late final Future<String?> load;
    load = _fetch(_generation, background: background).whenComplete(() {
      if (identical(_loading, load)) _loading = null;
    });
    return _loading = load;
  }

  Future<String?> _fetch(int generation, {required bool background}) async {
    Object? statError;
    final stat = Future.sync(_api.stat).then<NavStat?>(
      (stat) => stat,
      onError: (Object error) {
        _logger.warn(LogCategory.ui, 'me stat failed', {'error': _describe(error)});
        statError = error;
        return null;
      },
    );
    final NavInfo nav;
    try {
      nav = (background ? _freshAccountNav() : null) ?? await Future.sync(_api.nav);
    } catch (error) {
      if (error is BiliError && error.needsLogin) {
        if (_current(generation)) _loggedOutByNav();
        return null;
      }
      _logger.warn(LogCategory.ui, 'me nav failed', {'error': _describe(error)});
      if (!_current(generation)) return null;
      if (background) _lastLoad = null;
      final message = requestFailureMessage(error);
      if (_view is! MeShown && _view is! MeLoggedOut) _show(MeFailed(message));
      return message;
    }
    final counts = await stat;
    if (!_current(generation)) return null;
    if (!nav.isLogin) {
      _loggedOutByNav();
      return null;
    }
    final kept = switch (_view) {
      MeShown(:final counts) => counts,
      _ => null,
    };
    final shown = MeShown(MeProfile.fromNav(nav), counts == null ? kept : MeCounts.fromStat(counts));
    _show(shown);
    _keep(shown);
    _recheckAccount();
    return switch (statError) {
      final error? => requestFailureMessage(error),
      null => null,
    };
  }

  /// The launch's account check answered nav for this login moments ago; the same call again would say the same.
  NavInfo? _freshAccountNav() {
    final answer = _environment.accountNav;
    if (answer == null || !answer.nav.isLogin) return null;
    final age = _now().difference(answer.at);
    return age.isNegative || age >= quietGap ? null : answer.nav;
  }

  /// The account's uid: the check's once it has answered, the login cookie's before that.
  int? get _accountMid =>
      _environment.activeAccountMid ?? _environment.mid ?? int.tryParse(_environment.cookies.value('DedeUserID') ?? '');

  /// The kept account, when it is this login's; another account's is deleted.
  MeShown? _keptView() {
    final kept = _store.kept;
    final mid = _accountMid;
    if (kept == null || mid == null) return null;
    if (kept.mid == mid) return kept.view;
    _store.delete();
    return null;
  }

  void _keep(MeShown view) {
    final mid = view.profile.mid ?? _accountMid;
    if (mid != null && mid > 0) _store.save(mid, view);
  }

  /// The page shows an account other than the one the check found.
  bool get _showsAnotherAccount {
    final mid = _environment.mid;
    return switch (_view) {
      MeShown(:final profile) => mid != null && profile.mid != null && profile.mid != mid,
      _ => false,
    };
  }

  /// Nav answered, so the network is back: a launch check that failed for want of it is asked again, as 首页 does on
  /// coming back to it.
  void _recheckAccount() {
    if (_environment.account is AccountUnknown && _environment.accountCheckFailed) {
      unawaited(_environment.refreshAccount());
    }
  }

  /// The environment has checks of its own, so it is left as it is.
  void _loggedOutByNav() {
    _logger.info(LogCategory.ui, 'me logged out by nav');
    _store.delete();
    _show(const MeLoggedOut());
  }

  void _accountChanged() {
    if (_environment.hasAccountVault && _sessionGeneration != _environment.sessionGeneration) return;
    final now = _environment.account;
    if (now is AccountUnknown) {
      // didLogin passes through here on its way to logged in; the login count after it then knows whether the
      // turn to logged in has loaded.
      _loginLoaded = false;
      return;
    }
    final was = _account;
    _account = now;
    if (now is! LoggedIn) {
      _signedOut();
    } else if (was is LoggedOut ||
        was is LoginExpired ||
        (was is AccountUnknown && _view is MeLoggedOut) ||
        _showsAnotherAccount) {
      // Unknown and 点击登录: nav said logged out while the check couldn't read the login (an unread keychain), and
      // now it has. Left as it was, 点击登录 would invite a second login on the account.
      _loginLoaded = true;
      _restart();
    }
  }

  /// A login over an account that already read logged in leaves the account where it was, and may be another one.
  void _loginCompleted() {
    if (_environment.hasAccountVault) return;
    if (_loginLoaded) {
      _loginLoaded = false;
    } else if (_account is LoggedIn) {
      _restart();
    }
  }

  void _sessionChanged() {
    if (!_environment.hasAccountVault) return;
    _sessionGeneration = _environment.sessionGeneration;
    _generation++;
    _loading = null;
    _lastLoad = null;
    _loginLoaded = false;
    _account = _environment.account;
    if (!_signedIn) {
      _show(const MeLoggedOut());
      return;
    }
    _show(_keptView() ?? const MeLoading());
    unawaited(_load());
  }

  /// The page may already be on screen when the login page closes, so a login loads at once.
  void _restart() {
    _generation++;
    _loading = null;
    _store.delete();
    _show(const MeLoading());
    unawaited(_load());
  }

  void _signedOut() {
    _generation++;
    _loading = null;
    _lastLoad = null;
    _loginLoaded = false;
    _store.delete();
    _show(const MeLoggedOut());
  }

  bool _current(int generation) => generation == _generation && !_disposed;

  void _show(MeView view) {
    if (_disposed || view == _view) return;
    _view = view;
    notifyListeners();
  }

  /// A transport's own words end with the request's URL; Bilibili's errors carry none.
  static String _describe(Object error) => error is BiliError ? '$error' : '${error.runtimeType}';

  @override
  void dispose() {
    _disposed = true;
    _environment.removeListener(_accountChanged);
    _environment.logins.removeListener(_loginCompleted);
    _environment.sessions.removeListener(_sessionChanged);
    super.dispose();
  }
}
