import 'dart:async';
import 'dart:io';

import 'package:bili_core/danmaku.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/account/app_auth.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/skin/fake_skin_api.dart';
import 'package:bilifast/skin/skin_model.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fake_web_cookies.dart';
import '../playback/fakes.dart';
import 'fake_keychain.dart';

/// A login whose fingerprint cookies are already there, so no `spi` call is needed.
const _login = {
  'SESSDATA': 'page-sess',
  'bili_jct': 'page-jct',
  'buvid3': 'b3',
  'buvid4': 'b4',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePageApi api;

  Future<(AppEnvironment, AppServices)> build({
    CookieLoad stored = const NoStoredCookies(),
    CannedHttp? http,
    bool fake = false,
  }) async {
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(stored),
      http: http ?? Canned.http(),
      webCookies: FakeWebCookies(),
      logger: Logger(session: 'test'),
    );
    // As main.dart: a --fake-account run is set up before the services exist.
    if (fake) environment.useFakeAccount();
    api = FakePageApi()
      ..blockRules = [
        const BlockRule(id: 1, kind: BlockRuleKind.keyword, filter: 'spoiler'),
      ];
    final services = AppServices(
      environment: environment,
      playback: AppPlayback(() => Completer<PlaybackController>().future),
      recents: await RecentStore.load(null, logger: Logger(session: 'test')),
      pageApi: api,
    );
    addTearDown(services.playback.dispose);
    return (environment, services);
  }

  int fetches() =>
      api.calls.where((call) => call == 'danmakuBlockRules').length;

  test('legacy uid keeps feed preference ownership stable while launch nav resolves', () async {
    final (environment, services) = await build(
      stored: const StoredCookies({..._login, 'DedeUserID': '12345'}),
    );
    addTearDown(services.dispose);
    expect(environment.account, isA<AccountUnknown>());
    expect(environment.activeAccountMid, isNull);
    expect(services.feedAccountMid, 12345);
    services.feedPreferences.recordSeen(
      accountMid: services.feedAccountMid, bvid: 'BVlaunch', ownerMid: 7,
    );
    await environment.refreshAccount();
    expect(services.feedAccountMid, 12345);
    expect(services.feedPreferences.recentlySeen('BVlaunch', accountMid: services.feedAccountMid), isTrue);
    expect(services.feedPreferences.recentlySeen('BVlaunch', accountMid: null), isFalse);
  });

  test('the launch\'s check leaves the 屏蔽词 to the page', () async {
    final (environment, _) = await build(stored: const StoredCookies(_login));
    await environment.refreshAccount();
    await pumpEventQueue();
    expect(environment.account, isA<LoggedIn>());
    expect(fetches(), 0);
  });

  test('every login fetches the 屏蔽词 again, also one over an account that already read logged in', () async {
    final (environment, services) = await build();
    expect(await environment.didLogin(_login), isTrue);
    await pumpEventQueue();
    expect(fetches(), 1);
    expect(services.blockRules.rules.single.filter, 'spoiler');

    expect(await environment.didLogin(_login), isTrue);
    await pumpEventQueue();
    expect(
      fetches(),
      2,
      reason: 'LoggedIn → unknown → LoggedIn is still a login',
    );
  });

  test('a login Bilibili turns down fetches nothing', () async {
    final (environment, _) = await build(http: Canned.http(loggedIn: false));
    final login = environment.didLogin(_login);
    await pumpEventQueue();
    // The second and third checks wait 1 s and 2 s.
    await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
    expect(await login, isFalse);
    expect(fetches(), 0);
  });

  test('logging out of a --fake-account run drops its 屏蔽词', () async {
    final (environment, services) = await build(fake: true);
    await services.blockRules.refresh();
    expect(services.blockRules.rules, isNotEmpty);

    await environment.logout();
    await pumpEventQueue();
    expect(services.blockRules.rules, isEmpty);
  });

  test('once disposed it hears neither logins nor logouts', () async {
    final (environment, services) = await build();
    services.dispose();
    expect(await environment.didLogin(_login), isTrue);
    await pumpEventQueue();
    expect(fetches(), 0);
  });

  test("a token confirmed mid-session (授权) asks for the skin once; later notices that keep it don't ask again", () async {
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(const NoStoredCookies()),
      http: Canned.http(),
      webCookies: FakeWebCookies(),
      logger: Logger(session: 'test'),
    );
    final auth = FakeAppAuth(authorized: false);
    final skins = FakeSkinApi();
    // Without a folder the skin model unpacks into one of its own in the system temp, which nothing deletes.
    final skinFolder = await Directory.systemTemp.createTemp('app_services_skins');
    final services = AppServices(
      environment: environment,
      playback: AppPlayback(() => Completer<PlaybackController>().future),
      recents: await RecentStore.load(null, logger: Logger(session: 'test')),
      pageApi: FakePageApi(),
      skinApi: skins,
      skinFolder: skinFolder.path,
      appAuth: auth,
    );
    addTearDown(services.playback.dispose);
    addTearDown(() async {
      services.skin.dispose();
      await services.skin.settle();
      await skinFolder.delete(recursive: true);
    });

    auth.notifyListeners();
    await pumpEventQueue();
    expect(skins.calls, isEmpty, reason: 'still no token');

    auth.authorized = true;
    auth.notifyListeners();
    await pumpEventQueue();
    expect(skins.calls, ['equipped']);

    auth.notifyListeners();
    await pumpEventQueue();
    expect(skins.calls, ['equipped'], reason: 'only the change to authorized asks');
  });

  test('a skin model given is the one pages read, and a token confirmed refreshes it', () async {
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(const NoStoredCookies()),
      http: Canned.http(),
      webCookies: FakeWebCookies(),
      logger: Logger(session: 'test'),
    );
    final auth = FakeAppAuth(authorized: false);
    final skin = _CountingSkinModel(environment: environment);
    final services = AppServices(
      environment: environment,
      playback: AppPlayback(() => Completer<PlaybackController>().future),
      recents: await RecentStore.load(null, logger: Logger(session: 'test')),
      pageApi: FakePageApi(),
      skin: skin,
      appAuth: auth,
    );
    addTearDown(services.playback.dispose);
    expect(services.skin, same(skin));

    auth.authorized = true;
    auth.notifyListeners();
    await pumpEventQueue();
    expect(skin.refreshes, 1);
  });
}

class _CountingSkinModel extends SkinModel {
  _CountingSkinModel({required super.environment}) : super(api: FakeSkinApi(), folder: null);

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}
