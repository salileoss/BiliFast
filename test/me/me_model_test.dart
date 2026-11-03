import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/home/feed_model.dart' show requestFailureMessage;
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/me/me_model.dart';
import 'package:bilifast/me/me_profile_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The account half [MeModel] follows: the test sets the account and counts the logins.
class _Environment extends ChangeNotifier implements AppEnvironment {
  _Environment(this._account);

  Account _account;

  @override
  Account get account => _account;

  set account(Account value) {
    _account = value;
    notifyListeners();
  }

  @override
  final ValueNotifier<int> logins = ValueNotifier(0);

  @override
  final ValueNotifier<int> sessions = ValueNotifier(0);
  @override
  int get sessionGeneration => sessions.value;
  @override
  bool hasAccountVault = false;
  @override
  int? get activeAccountMid => savedMid ?? mid;
  int? savedMid;

  @override
  bool accountCheckFailed = false;

  @override
  int? mid;

  @override
  final CookieJar cookies = CookieJar();

  @override
  ({NavInfo nav, DateTime at})? accountNav;

  /// How often the account was asked to be checked again.
  int checks = 0;

  @override
  Future<bool> refreshAccount() async {
    checks++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A transport error whose words end with the request's URL, as package:http's do.
class _TransportError implements Exception {
  @override
  String toString() => 'ClientException: Connection reset, uri=https://api.bilibili.com/x/web-interface/nav';
}

class _QueuedMeApi extends FakeMeApi {
  _QueuedMeApi() : super(navInfo: const NavInfo(isLogin: true), counts: const NavStat(following: 0, follower: 0, dynamicCount: 0));
  final answers = <Completer<NavInfo>>[];
  @override
  Future<NavInfo> nav() {
    final answer = Completer<NavInfo>();
    answers.add(answer);
    return answer.future;
  }
}

void main() {
  const loggedIn = LoggedIn(name: '测试账号', vip: true);
  const renamed = NavInfo(isLogin: true, mid: 1, uname: '改了名字', level: 5);
  const demoCounts = MeCounts(dynamics: 0, following: 13, followers: 0);

  late FakeMeApi api;
  late _Environment environment;
  late DateTime clock;
  late MemorySink sink;
  late Logger logger;

  setUp(() {
    api = FakeMeApi.demo();
    clock = DateTime(2026, 10, 22, 12);
    sink = MemorySink();
    logger = Logger(session: 'test')..add(sink);
  });

  MeModel make({Account account = loggedIn, MeProfileStore? store, int? mid, String? cookieMid}) {
    environment = _Environment(account)..mid = mid;
    if (cookieMid != null) environment.cookies.set('DedeUserID', cookieMid);
    final model = MeModel(api: api, environment: environment, store: store, now: () => clock, logger: logger);
    addTearDown(model.dispose);
    return model;
  }

  Future<void> idle() => pumpEventQueue();

  MeShown shownView(MeModel model) {
    expect(model.view, isA<MeShown>());
    return model.view as MeShown;
  }

  test('held profile replies cannot cross A to B to A session boundaries', () async {
    final queued = _QueuedMeApi();
    api = queued;
    final model = make(mid: 1);
    environment.hasAccountVault = true;
    final old = model.refresh();
    await idle();
    environment.mid = 2;
    environment.sessions.value++;
    await idle();
    environment.mid = 1;
    environment.sessions.value++;
    await idle();
    expect(queued.answers, hasLength(3));
    queued.answers[2].complete(const NavInfo(isLogin: true, mid: 1, uname: 'fresh A'));
    await idle();
    expect(shownView(model).profile.name, 'fresh A');
    queued.answers[1].complete(const NavInfo(isLogin: true, mid: 2, uname: 'B'));
    queued.answers[0].complete(const NavInfo(isLogin: true, mid: 1, uname: 'stale A'));
    await old;
    await idle();
    expect(shownView(model).profile.name, 'fresh A');
  });

  test('logged in, it waits for the tab, then asks nav and stat side by side and shows the account', () async {
    final model = make();
    expect(model.view, isA<MeLoading>());
    await idle();
    expect(api.calls, isEmpty, reason: 'nothing is asked before the tab shows');

    final nav = api.holds['nav'] = Completer<void>();
    final stat = api.holds['stat'] = Completer<void>();
    model.shown();
    await idle();
    expect(api.calls, unorderedEquals(['nav', 'stat']), reason: 'both are out before either answers');
    expect(model.view, isA<MeLoading>());

    nav.complete();
    stat.complete();
    await idle();
    final view = shownView(model);
    expect(view.profile, MeProfile.fromNav(api.navInfo));
    expect(view.counts, demoCounts);
  });

  test('the demo is --fake-account\'s 测试账号: a level 5 年度大会员 with 879 硬币 and 2.3 B币', () async {
    final model = make();
    model.shown();
    await idle();
    final profile = shownView(model).profile;
    expect(profile.mid, 1);
    expect(profile.name, '测试账号');
    expect(profile.level, 5);
    expect(profile.coins, 879);
    expect(profile.bcoin, 2.3);
    expect(profile.vip, isTrue);
    expect(profile.vipLabel, '年度大会员');
    expect(profile.vipBadge, isTrue);
    expect(profile.face, startsWith('https://'));
    expect(profile.pendant, startsWith('https://'));
  });

  for (final account in const [LoggedOut(), LoginExpired()]) {
    test('${account.runtimeType}, it shows 点击登录 and calls nothing', () async {
      final model = make(account: account);
      expect(model.view, isA<MeLoggedOut>());
      model.shown();
      expect(await model.refresh(), isNull);
      await idle();
      expect(api.calls, isEmpty);
      expect(model.view, isA<MeLoggedOut>());
    });
  }

  test('before the launch\'s check answers a showing loads, and the check settling asks nothing more', () async {
    final model = make(account: const AccountUnknown());
    expect(model.view, isA<MeLoading>());
    model.shown();
    await idle();
    expect(api.calls.length, 2);
    environment.account = loggedIn;
    await idle();
    expect(api.calls.length, 2);
    expect(model.view, isA<MeShown>());
  });

  test('showing again reloads quietly, at most once per 30 s, and an unchanged answer redraws nothing', () async {
    final model = make();
    model.shown();
    await idle();
    expect(api.calls.length, 2);

    clock = clock.add(const Duration(seconds: 29));
    model.shown();
    await idle();
    expect(api.calls.length, 2, reason: 'within the gap');

    clock = clock.add(const Duration(seconds: 1));
    var notified = 0;
    model.addListener(() => notified++);
    final hold = api.holds['nav'] = Completer<void>();
    model.shown();
    await idle();
    expect(api.calls.length, 4);
    expect(model.view, isA<MeShown>(), reason: 'the page stays while it reloads');
    expect(notified, 0);
    hold.complete();
    await idle();
    expect(notified, 0, reason: 'the same account and counts');

    clock = clock.add(const Duration(seconds: 30));
    api.navInfo = renamed;
    model.shown();
    await idle();
    expect(api.calls.length, 6);
    expect(notified, 1);
    expect(shownView(model).profile.name, '改了名字');
  });

  test('a pull counts toward the gap', () async {
    final model = make();
    await model.refresh();
    clock = clock.add(const Duration(seconds: 10));
    model.shown();
    await idle();
    expect(api.calls.length, 2);
  });

  test('a showing or a pull while a load is out joins it', () async {
    final model = make();
    final hold = api.holds['nav'] = Completer<void>();
    model.shown();
    final pulled = model.refresh();
    model.shown();
    final pulledAgain = model.refresh();
    await idle();
    expect(api.calls, unorderedEquals(['nav', 'stat']));

    var done = false;
    unawaited(pulled.then((_) => done = true));
    await idle();
    expect(done, isFalse, reason: 'the pull completes only when the answer is in');

    hold.complete();
    expect(await pulled, isNull);
    expect(await pulledAgain, isNull);
    expect(model.view, isA<MeShown>());

    await model.refresh();
    expect(api.calls.length, 4, reason: 'the next pull asks again');
  });

  for (final account in const [LoggedOut(), LoginExpired()]) {
    test('turning ${account.runtimeType} shows 点击登录 at once and drops the answer still out', () async {
      final model = make();
      model.shown();
      await idle();
      expect(model.view, isA<MeShown>());

      final hold = api.holds['nav'] = Completer<void>();
      final pulled = model.refresh();
      await idle();
      environment.account = account;
      expect(model.view, isA<MeLoggedOut>(), reason: 'the old profile goes at once');

      hold.complete();
      expect(await pulled, isNull);
      await idle();
      expect(model.view, isA<MeLoggedOut>());

      model.shown();
      expect(await model.refresh(), isNull);
      expect(api.calls.length, 4, reason: 'logged out, nothing more is asked');
    });
  }

  test('a login loads at once, without waiting for the tab', () async {
    final model = make(account: const LoggedOut());
    environment.account = const AccountUnknown();
    expect(model.view, isA<MeLoggedOut>(), reason: 'didLogin passes through unknown');

    environment.account = loggedIn;
    expect(model.view, isA<MeLoading>());
    await idle();
    expect(api.calls, unorderedEquals(['nav', 'stat']));
    expect(shownView(model).profile.name, '测试账号');

    environment.logins.value += 1;
    model.shown();
    await idle();
    expect(api.calls.length, 2, reason: 'the login count after it and a showing within the gap ask nothing more');
  });

  test('a login over an account that read logged in loads afresh, as it may be another account', () async {
    final model = make();
    model.shown();
    await idle();

    api.navInfo = const NavInfo(isLogin: true, mid: 2, uname: '另一个账号');
    environment.account = const AccountUnknown();
    environment.account = const LoggedIn(name: '另一个账号', vip: false);
    expect(shownView(model).profile.name, '测试账号');

    environment.logins.value += 1;
    expect(model.view, isA<MeLoading>(), reason: 'the old account isn\'t shown as the new one');
    await idle();
    expect(api.calls.length, 4);
    expect(shownView(model).profile.name, '另一个账号');
  });

  test('the first load failing shows the reason; showing the page again tries again, gap or not', () async {
    const error = BiliError.network('SocketException');
    api.failures['nav'] = error;
    final model = make();
    model.shown();
    await idle();
    expect(model.view, MeFailed(requestFailureMessage(error)));
    expect((model.view as MeFailed).message, '网络连接失败，请检查网络后重试');

    api.failures.clear();
    clock = clock.add(const Duration(seconds: 1));
    final hold = api.holds['nav'] = Completer<void>();
    model.shown();
    expect(model.view, isA<MeLoading>());
    hold.complete();
    await idle();
    expect(model.view, isA<MeShown>());
  });

  test('a pull on the failed page returns the reason to toast, and the page stays failed', () async {
    api.failures['nav'] = const BiliError.http(503);
    final model = make();
    expect(await model.refresh(), '网络请求失败（HTTP 503）');
    expect(model.view, const MeFailed('网络请求失败（HTTP 503）'));
    expect(await model.refresh(), '网络请求失败（HTTP 503）');
    expect(model.view, isA<MeFailed>());

    api.failures.clear();
    expect(await model.refresh(), isNull);
    expect(model.view, isA<MeShown>());
  });

  test('with the page shown, a failed nav keeps it and the pull returns the reason to toast', () async {
    final model = make();
    expect(await model.refresh(), isNull);
    final shown = model.view;

    api.failures['nav'] = const BiliError.api(code: -352, message: '');
    expect(await model.refresh(), '请求过于频繁，请稍后再试');
    expect(model.view, same(shown));

    clock = clock.add(const Duration(seconds: 30));
    model.shown();
    await idle();
    expect(model.view, same(shown), reason: 'a quiet reload failing keeps the page too');

    api.failures.clear();
    expect(await model.refresh(), isNull);
  });

  test('a stat failure still shows the profile, keeps the counts it had and returns the reason', () async {
    api.failures['stat'] = const BiliError.network('TimeoutException');
    final model = make();
    expect(await model.refresh(), '网络连接失败，请检查网络后重试');
    var view = shownView(model);
    expect(view.profile.name, '测试账号');
    expect(view.counts, isNull, reason: 'none yet');

    api.failures.clear();
    await model.refresh();
    expect(shownView(model).counts, demoCounts);

    api.failures['stat'] = const BiliError.http(500);
    api.navInfo = renamed;
    expect(await model.refresh(), requestFailureMessage(const BiliError.http(500)));
    view = shownView(model);
    expect(view.profile.name, '改了名字');
    expect(view.counts, demoCounts);
  });

  test('nav with no mid gives a profile with none, not 0', () {
    expect(MeProfile.fromNav(const NavInfo(isLogin: true, uname: '无号')).mid, isNull);
    expect(MeProfile.fromNav(api.navInfo).mid, 1);
  });

  test('nav answering while the launch\'s check failed asks the environment to check again', () async {
    final model = make(account: const AccountUnknown());
    environment.accountCheckFailed = true;
    await model.refresh();
    expect(model.view, isA<MeShown>());
    expect(environment.checks, 1);

    api.failures['nav'] = const BiliError.network('SocketException');
    clock = clock.add(const Duration(seconds: 30));
    await model.refresh();
    expect(environment.checks, 1, reason: 'a failed nav says nothing of the network');
  });

  test('nav saying logged out while the account was unknown gives way when the check then finds the login', () async {
    final account = api.navInfo;
    final model = make(account: const AccountUnknown());
    environment.accountCheckFailed = true;
    api.navInfo = const NavInfo(isLogin: false);
    model.shown();
    await idle();
    expect(model.view, isA<MeLoggedOut>());

    api.navInfo = account;
    environment
      ..accountCheckFailed = false
      ..mid = 1
      ..account = loggedIn;
    expect(model.view, isA<MeLoading>(), reason: '点击登录 goes at once');
    await idle();
    expect(shownView(model).profile.name, '测试账号');
    expect(api.calls.where((call) => call == 'nav'), hasLength(2));

    environment.account = loggedIn;
    await idle();
    expect(api.calls.where((call) => call == 'nav'), hasLength(2), reason: 'only the turn to logged in loads');
  });

  test('a check still running or one that never failed is left be', () async {
    final unknown = make(account: const AccountUnknown());
    await unknown.refresh();
    expect(environment.checks, 0, reason: 'the launch\'s check is still out');

    final loggedInModel = make();
    environment.accountCheckFailed = true;
    await loggedInModel.refresh();
    expect(environment.checks, 0, reason: 'the account is known');
  });

  test('nav answering not logged in shows 点击登录 and leaves the environment be', () async {
    final model = make();
    model.shown();
    await idle();
    expect(model.view, isA<MeShown>());

    api.navInfo = const NavInfo(isLogin: false);
    expect(await model.refresh(), isNull);
    expect(model.view, isA<MeLoggedOut>());
    expect(environment.account, loggedIn);

    api.navInfo = const NavInfo(isLogin: true, mid: 1, uname: '测试账号');
    api.failures['nav'] = const BiliError.api(code: -101, message: '账号未登录');
    final fresh = make();
    expect(await fresh.refresh(), isNull);
    expect(fresh.view, isA<MeLoggedOut>(), reason: 'a -101 is the same answer');
  });

  test('a failure logs the error\'s kind, never a transport\'s words with the URL', () async {
    api.failures['nav'] = _TransportError();
    api.failures['stat'] = _TransportError();
    final model = make();
    model.shown();
    await idle();
    expect(model.view, const MeFailed('网络连接失败，请检查网络后重试'));

    final warnings = [
      for (final event in sink.events)
        if (event.level == LogLevel.warn) event,
    ];
    expect(warnings.map((event) => event.msg), unorderedEquals(['me nav failed', 'me stat failed']));
    for (final event in warnings) {
      expect(event.f['error']?.toJson(), '_TransportError');
    }
    expect(sink.events.map((event) => '${event.toJson()}').join(), isNot(contains('bilibili.com')));

    api.failures['nav'] = const BiliError.api(code: -500, message: '服务器错误');
    await model.refresh();
    expect(sink.events.last.f['error']?.toJson(), 'BiliError.api(-500, 服务器错误)');
  });

  test('dispose stops following the account', () async {
    environment = _Environment(const LoggedOut());
    MeModel(api: api, environment: environment, now: () => clock, logger: logger).dispose();
    environment.account = loggedIn;
    environment.logins.value += 1;
    await idle();
    expect(api.calls, isEmpty);
  });

  group('the kept account', () {
    const keptProfile = MeProfile(
      mid: 1,
      name: '上次的名字',
      face: 'https://i0.hdslb.com/bfs/face/kept.jpg',
      level: 4,
      coins: 12,
      bcoin: 0,
    );
    const kept = MeShown(keptProfile, MeCounts(dynamics: 1, following: 2, followers: 3));

    MeProfileStore keeping({int mid = 1}) => MeProfileStore.memory(logger: logger)..save(mid, kept);

    test('an offline vault restore uses the saved active uid before nav answers', () {
      environment = _Environment(const AccountUnknown())
        ..hasAccountVault = true
        ..savedMid = 1;
      final model = MeModel(api: api, environment: environment, store: keeping(), logger: logger);
      addTearDown(model.dispose);
      expect(environment.mid, isNull);
      expect(model.view, kept);
    });

    test(
      'at launch, before the check answers, the login cookie\'s account shows at once; the load replaces it',
      () async {
        final store = keeping();
        final model = make(account: const AccountUnknown(), store: store, cookieMid: '1');
        expect(model.view, kept, reason: 'not MeLoading');

        final hold = api.holds['nav'] = Completer<void>();
        var notified = 0;
        model.addListener(() => notified++);
        model.shown();
        await idle();
        expect(model.view, kept, reason: 'it stays while the load is out');
        expect(notified, 0);

        hold.complete();
        await idle();
        expect(shownView(model).profile.name, '测试账号');
        expect(store.kept?.view, model.view, reason: 'every answer is kept');
        expect(store.kept?.mid, 1);
      },
    );

    test('logged in, the check\'s mid decides', () {
      expect(make(store: keeping(), mid: 1).view, kept);
      expect(
        make(store: keeping(), mid: 1, cookieMid: '2').view,
        kept,
        reason: 'the check wins over the cookie',
      );
    });

    test('a failed load keeps it, as a failed pull keeps the page', () async {
      api.failures['nav'] = const BiliError.network('SocketException');
      final model = make(store: keeping(), mid: 1);
      model.shown();
      await idle();
      expect(model.view, kept);
      expect(await model.refresh(), '网络连接失败，请检查网络后重试');
      expect(model.view, kept);
    });

    test('another account\'s is never shown, and is deleted', () async {
      final store = keeping(mid: 2);
      final model = make(account: const AccountUnknown(), store: store, cookieMid: '1');
      expect(model.view, isA<MeLoading>());
      expect(store.kept, isNull);

      final other = keeping(mid: 2);
      expect(make(store: other, mid: 1).view, isA<MeLoading>());
      expect(other.kept, isNull);
    });

    test('with no mid known it isn\'t shown, nor deleted', () {
      final store = keeping();
      expect(make(account: const AccountUnknown(), store: store).view, isA<MeLoading>());
      expect(store.kept, isNotNull);
    });

    for (final account in const [LoggedOut(), LoginExpired()]) {
      test('a launch ${account.runtimeType} never shows it and deletes it', () {
        final store = keeping();
        expect(make(account: account, store: store, cookieMid: '1').view, isA<MeLoggedOut>());
        expect(store.kept, isNull);
      });

      test('turning ${account.runtimeType} deletes it', () {
        final store = keeping();
        final model = make(store: store, mid: 1);
        expect(model.view, kept);
        environment.account = account;
        expect(model.view, isA<MeLoggedOut>());
        expect(store.kept, isNull);
      });
    }

    test('nav saying logged out deletes it', () async {
      final store = keeping();
      api.navInfo = const NavInfo(isLogin: false);
      final model = make(store: store, mid: 1);
      await model.refresh();
      expect(model.view, isA<MeLoggedOut>());
      expect(store.kept, isNull);
    });

    test('a login deletes it and loads afresh', () async {
      final store = keeping();
      final model = make(account: const LoggedOut(), store: store);
      expect(store.kept, isNull);
      store.save(1, kept);

      api.navInfo = const NavInfo(isLogin: true, mid: 2, uname: '另一个账号');
      environment.account = const AccountUnknown();
      environment
        ..mid = 2
        ..account = const LoggedIn(name: '另一个账号', vip: false);
      expect(model.view, isA<MeLoading>());
      expect(store.kept, isNull);
      await idle();
      expect(store.kept?.mid, 2);
      expect(store.kept?.view.profile.name, '另一个账号');
    });

    test('the check finding another account than the one shown drops it at once and loads that one', () async {
      final store = keeping();
      api.navInfo = const NavInfo(isLogin: true, mid: 2, uname: '另一个账号');
      final model = make(account: const AccountUnknown(), store: store, cookieMid: '1');
      expect(model.view, kept);

      environment
        ..mid = 2
        ..account = const LoggedIn(name: '另一个账号', vip: false);
      expect(model.view, isA<MeLoading>());
      expect(store.kept, isNull);
      await idle();
      expect(shownView(model).profile.name, '另一个账号');
      environment.logins.value += 1;
      await idle();
      expect(api.calls, hasLength(2), reason: 'one load');
    });

    test('the check finding the same account leaves it be', () async {
      final model = make(account: const AccountUnknown(), store: keeping(), cookieMid: '1');
      environment
        ..mid = 1
        ..account = loggedIn;
      await idle();
      expect(model.view, kept);
      expect(api.calls, isEmpty);
    });
  });

  group('the background load', () {
    test('once, logged in or unknown, and it counts toward the gap', () async {
      final model = make(account: const AccountUnknown());
      model.preload();
      await idle();
      expect(api.calls, unorderedEquals(['nav', 'stat']));
      expect(model.view, isA<MeShown>());

      model.preload();
      clock = clock.add(const Duration(seconds: 29));
      model.shown();
      await idle();
      expect(api.calls, hasLength(2), reason: 'opening within 30 s asks nothing');

      clock = clock.add(const Duration(seconds: 1));
      model.shown();
      await idle();
      expect(api.calls, hasLength(4), reason: 'later, the quiet reload as before');
      model.preload();
      await idle();
      expect(api.calls, hasLength(4), reason: 'never twice');
    });

    test('not after another load', () async {
      final model = make();
      await model.refresh();
      model.preload();
      await idle();
      expect(api.calls, hasLength(2));
    });

    for (final account in const [LoggedOut(), LoginExpired()]) {
      test('${account.runtimeType}, it asks nothing', () async {
        make(account: account).preload();
        await idle();
        expect(api.calls, isEmpty);
      });
    }

    test('unknown after a failed check (the keychain may be unread), it asks nothing', () async {
      final model = make(account: const AccountUnknown());
      environment.accountCheckFailed = true;
      model.preload();
      await idle();
      expect(api.calls, isEmpty);
      expect(model.view, isA<MeLoading>(), reason: 'not 点击登录, which would invite a second login');
    });

    test('a failed one leaves opening the page to try again; it keeps the kept account meanwhile', () async {
      const keptView = MeShown(MeProfile(mid: 1, name: '上次的名字', face: '', level: 4, coins: 0, bcoin: 0), null);
      api.failures['nav'] = const BiliError.network('SocketException');
      final model = make(store: MeProfileStore.memory()..save(1, keptView), mid: 1);
      model.preload();
      await idle();
      expect(model.view, keptView);

      api.failures.clear();
      clock = clock.add(const Duration(seconds: 1));
      model.shown();
      await idle();
      expect(api.calls.where((call) => call == 'nav'), hasLength(2));
      expect(shownView(model).profile.name, '测试账号');
    });

    test('the account check\'s nav, when fresh, stands in for its own: it asks stat only', () async {
      final model = make(mid: 1);
      environment.accountNav = (nav: renamed, at: clock.subtract(const Duration(seconds: 3)));
      model.preload();
      await idle();
      expect(api.calls, ['stat']);
      final view = shownView(model);
      expect(view.profile, MeProfile.fromNav(renamed));
      expect(view.counts, demoCounts);

      clock = clock.add(const Duration(seconds: 30));
      await model.refresh();
      expect(api.calls, ['stat', 'stat', 'nav'], reason: 'a pull asks both');
    });

    test('an account check\'s nav 30 s old or more is asked again', () async {
      final model = make(mid: 1);
      environment.accountNav = (nav: renamed, at: clock.subtract(const Duration(seconds: 30)));
      model.preload();
      await idle();
      expect(api.calls, unorderedEquals(['nav', 'stat']));
      expect(shownView(model).profile.name, '测试账号');
    });

    test('a showing and a pull ask nav themselves, fresh check or not', () async {
      final model = make(mid: 1);
      environment.accountNav = (nav: renamed, at: clock);
      model.shown();
      await idle();
      expect(api.calls, unorderedEquals(['nav', 'stat']));
      expect(shownView(model).profile.name, '测试账号');
    });
  });

  test('nothing of the account reaches the log', () async {
    const mid = 31415926;
    final demo = api.navInfo;
    api.navInfo = NavInfo(isLogin: true, mid: mid, uname: demo.uname, face: demo.face, pendant: demo.pendant);
    final store = MeProfileStore.memory(logger: logger);
    final model = make(account: const AccountUnknown(), store: store, cookieMid: '$mid');
    environment.accountNav = (nav: api.navInfo, at: clock);
    model.preload();
    await idle();
    clock = clock.add(const Duration(seconds: 30));
    api.failures['stat'] = const BiliError.http(500);
    await model.refresh();
    api.navInfo = const NavInfo(isLogin: false);
    await model.refresh();
    environment.account = const LoggedOut();
    expect(sink.events.map((event) => event.msg), containsAll(['me stat failed', 'me logged out by nav']));
    // Encoded as the log file writes them; a Map's toString would quote no key.
    final logged = sink.events.map((event) => event.encode()).join();
    for (final secret in ['测试账号', 'noface', 'hdslb', '"mid"', '$mid']) {
      expect(logged, isNot(contains(secret)));
    }
  });
}
