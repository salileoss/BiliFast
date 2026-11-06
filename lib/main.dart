import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File;

import 'package:bili_core/devlog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'account/app_auth.dart';
import 'account/dpapi_keychain_store.dart';
import 'account/keychain_store.dart';
import 'app/app_environment.dart';
import 'app/form_factor.dart';
import 'app/app_scope.dart';
import 'app/phone_frame.dart';
import 'app/reduce_motion.dart';
import 'app/route_observer.dart';
import 'comments/emote_store.dart';
import 'danmaku/danmaku_settings_store.dart';
import 'device/launch_form_factor.dart';
import 'device/orientation.dart';
import 'device/player_device.dart';
import 'devtools/crash_log.dart';
import 'devtools/log_files.dart';
import 'devtools/log_forwarder.dart';
import 'dynamic/fake_dynamic_api.dart';
import 'favourites/fake_favourites_api.dart';
import 'home/main_shell.dart';
import 'home/recent_store.dart';
import 'home/feed_preferences.dart';
import 'me/fake_me_api.dart';
import 'me/me_profile_store.dart';
import 'offline/fake_offline_library.dart';
import 'offline/ios/ios_offline_host.dart';
import 'offline/offline_host.dart';
import 'offline/offline_library.dart';
import 'playback/codec_memory.dart';
import 'playback/playback_setup.dart';
import 'playback/shared_engine.dart';
import 'screens/player_test_page.dart';
import 'search/fake_search_api.dart';
import 'skin/fake_skin_api.dart';
import 'search/search_history_store.dart';
import 'settings/follow_font.dart';
import 'settings/font_store.dart';
import 'settings/appearance_store.dart';
import 'shared/app_theme.dart';
import 'space/fake_space_api.dart';
import 'shared/image_disk_cache.dart';
import 'shared/theme.dart';
import 'video/fake_page_api.dart';
import 'video/history_outbox.dart';
import 'video/player_prefs.dart';
import 'watch_later/fake_watch_later_api.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashLog.install();
  final formFactor = await launchFormFactor(args);
  FormFactor.device = formFactor.kind;
  if (formFactor.kind.isPad) PhoneFrame.usePad();
  await resolveSupportFolder();
  final logs = devToolsEnabled ? await LogForwarder.load(supportFilePath('log_server.json')) : null;
  final logFiles = LogFiles.platform();
  Logger.shared.info(LogCategory.app, 'launch', {
    'platform': Platform.operatingSystem,
    'os': Platform.operatingSystemVersion,
    'devTools': devToolsEnabled,
  });
  Logger.shared.info(LogCategory.app, 'form factor', formFactor.logFields);
  if (Platform.isIOS) {
    Logger.shared.info(LogCategory.ui, 'system font fallback', {'pingFang': BiliFonts.settleSystemFallback()});
  }
  final AppEnvironment environment;
  final RecentStore recents;
  final FeedPreferences feedPreferences;
  final FontStore fonts;
  final AppearanceStore appearance;
  final SearchHistoryStore searchHistory;
  final DanmakuSettingsStore danmakuSettings;
  final CodecMemory codecMemory;
  final MeProfileStore meProfile;
  final HistoryOutbox historyOutbox;
  var launchMode = ThemeMode.light;
  try {
    appearance = await AppearanceStore.load(supportFilePath('appearance.json'));
    launchMode = appearance.mode;
    environment = await (Platform.isWindows
        ? loadWindowsEnvironment(
            realAccount: args.contains('--real-account') && !args.contains('--fake-account'))
        : AppEnvironment.load(legacyAuthDeclined: await readLegacyAuthDeclined(appDevicePath())));
    recents = await RecentStore.load(supportFilePath('recents.json'));
    feedPreferences = await FeedPreferences.load(
      args.contains('--fake-account') ? null : supportFilePath('feed_preferences.json'),
    );
    PlayerPrefs.shared = await PlayerPrefs.load(supportFilePath('player_prefs.json'));
    fonts = await FontStore.load(supportFilePath('font.json'));
    searchHistory = await SearchHistoryStore.load(supportFilePath('search_history.json'));
    danmakuSettings = await DanmakuSettingsStore.load(supportFilePath('danmaku_settings.json'));
    RecentEmotes.shared = await RecentEmotes.load(supportFilePath('emotes_recent.json'));
    codecMemory = await CodecMemory.load(codecMemoryPath());
    meProfile = await MeProfileStore.load(supportFilePath('me.json'));
    historyOutbox = await HistoryOutbox.load(supportFilePath('history_outbox.json'));
  } catch (error, stack) {
    // Without this the launch screen would stay up with nothing to say why.
    CrashLog.report(error, stack, source: 'launch');
    runApp(LaunchFailedApp(error: '$error', mode: launchMode));
    return;
  }
  // PC checks only: the page's actions, 搜索, UP主空间, 我的收藏 and 稍后再看 answer from memory, and the app token
  // reads authorized, so every button can be pressed with no account traffic.
  final fakeAccount = !Platform.isIOS && args.contains('--fake-account');
  if (fakeAccount) environment.useFakeAccount();
  unawaited(environment.refreshAccount());
  final engine = SharedEngine(startPlatformEngine);
  final playback = AppPlayback(
    () => startPlaybackController(environment.client, engine: engine, codecMemory: codecMemory),
    engine: engine,
    codecMemory: codecMemory,
    muted: args.contains('--mute'),
    onResumed: () => recheckUnknownAccount(environment),
  );
  final navigator = GlobalKey<NavigatorState>();
  // The official app token stays on the phone: the PC holds only the web login.
  final AppAuth appAuth = fakeAccount
      ? FakeAppAuth()
      : Platform.isWindows
          ? NoAppAuth()
          : TokenAppAuth(environment: environment, navigator: navigator);
  final device = PlayerDevice.platform();
  applyTurnTakeover(device.orientation, PlayerPrefs.shared);
  PhoneFrame.follow(device.orientation);
  await appAuth.start();
  ImageDiskCache? imageCache;
  try {
    final caches = await getApplicationCacheDirectory();
    imageCache = ImageDiskCache(folder: '${caches.path}${Platform.pathSeparator}images');
    ImageDiskCache.shared = imageCache;
    unawaited(imageCache.start());
  } catch (error, stack) {
    // Without the cache, pictures come from the network every time.
    CrashLog.report(error, stack, source: 'image cache');
  }
  final offlineFolder = supportFilePath('offline');
  final OfflineLibrary offline = fakeAccount
      ? FakeOfflineLibrary.demo()
      : offlineFolder == null
          ? FakeOfflineLibrary()
          : DiskOfflineLibrary(
              folder: offlineFolder,
              client: () => environment.client,
              accountMid: () => environment.activeAccountMid,
              accountGeneration: () => environment.sessionGeneration,
              engine: engine.lease,
              host: Platform.isIOS ? IosOfflineHost() : const NoOfflineHost(),
              codecMemory: codecMemory,
            );
  final services = AppServices(
    environment: environment,
    playback: playback,
    recents: recents,
    feedPreferences: feedPreferences,
    device: device,
    fonts: fonts,
    appearance: appearance,
    pageApi: fakeAccount ? FakePageApi.demo() : null,
    searchApi: fakeAccount ? FakeSearchApi.demo() : null,
    spaceApi: fakeAccount ? FakeSpaceApi.demo() : null,
    favouritesApi: fakeAccount ? FakeFavouritesApi.demo() : null,
    watchLaterApi: fakeAccount ? FakeWatchLaterApi.demo() : null,
    meApi: fakeAccount ? FakeMeApi.demo() : null,
    dynamicApi: fakeAccount ? FakeDynamicApi.demo() : null,
    meProfile: meProfile,
    skinApi: fakeAccount ? FakeSkinApi.demo() : null,
    // The demo skin keeps a folder of its own, so a later run never starts from it.
    skinFolder: supportFilePath(fakeAccount ? 'skins_fake' : 'skins'),
    appAuth: appAuth,
    navigator: navigator,
    searchHistory: searchHistory,
    danmakuSettings: danmakuSettings,
    imageCache: imageCache,
    offline: offline,
    historyOutbox: historyOutbox,
    logFiles: logFiles,
    logs: logs,
  );
  // Only the cache read is awaited, so the first frame has the theme; the check runs on.
  await services.skin.start();
  unawaited(offline.start());
  runApp(BiliFastApp(services: services, initialLink: _argument(args, '--play=')));
}

/// Every PC run goes through the guard (reads only, paced and capped per run). KaiC's real login (2026-10-22) is
/// loaded and offered only with [realAccount] (`--real-account`): his last fallback for checking APIs, never for
/// everyday development or tests, and launched only with his OK each time. It is kept DPAPI-encrypted in the
/// support folder, and 退出登录 ends the session on Bilibili's side too.
Future<AppEnvironment> loadWindowsEnvironment({bool realAccount = false}) {
  final loginFile = realAccount ? supportFilePath('login.bin') : null;
  return AppEnvironment.load(
      keychain: loginFile == null ? const NoKeychainStore() : DpapiKeychainStore(loginFile),
      guarded: true,
      serverLogout: true,
      pcLogin: loginFile != null);
}

/// Read before the first account check so migration cannot outrun the existing authorization preference.
Future<bool> readLegacyAuthDeclined(String? path) async {
  if (path == null) return false;
  try {
    final json = jsonDecode(await File(path).readAsString());
    return json is Map<String, Object?> && json['authDeclined'] == true;
  } catch (_) {
    return false;
  }
}

/// The launch's account check fails without a network; as Swift's RootView did on becoming active, coming back to
/// the foreground asks again while the account is still unknown.
void recheckUnknownAccount(AppEnvironment environment) {
  if (environment.account is AccountUnknown) unawaited(environment.refreshAccount());
}

/// 开发者's 旋转动画 as last chosen, from the first turn. Not awaited, so the first frame doesn't wait on the host;
/// the controller logs a host that fails.
void applyTurnTakeover(OrientationController orientation, PlayerPrefs prefs) =>
    unawaited(orientation.setTurnTakeover(prefs.turnTakeover));

/// What the app shows when it could not start.
class LaunchFailedApp extends StatelessWidget {
  const LaunchFailedApp({super.key, required this.error, this.mode = ThemeMode.light});

  final String error;
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BiliFast',
        debugShowCheckedModeBanner: false,
        locale: BiliFonts.locale,
        supportedLocales: const [BiliFonts.locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: biliTheme(Brightness.light),
        darkTheme: biliTheme(Brightness.dark),
        themeMode: mode,
        builder: (context, child) => DefaultStatusBar(child: child!),
        home: Builder(builder: (context) => Scaffold(
          backgroundColor: BiliColors.colorsOf(context).pageGrey,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(BiliMetrics.gutter),
                child: Builder(builder: (context) {
                  final title = TextStyle(
                    fontSize: BiliMetrics.titleText,
                    color: BiliColors.colorsOf(context).text,
                    fontWeight: FontWeight.w600,
                  );
                  const detail = TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.failure);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('BiliFast 启动失败，请重启应用',
                          textAlign: TextAlign.center,
                          style: title,
                          strutStyle: BiliFonts.strutOf(context, title)),
                      const SizedBox(height: BiliMetrics.rowGap),
                      Text(error,
                          key: const ValueKey('launch-error'),
                          textAlign: TextAlign.center,
                          style: detail,
                          strutStyle: BiliFonts.strutOf(context, detail)),
                    ],
                  );
                }),
              ),
            ),
          ),
        )),
      );
}

String? _argument(List<String> args, String prefix) =>
    args.where((arg) => arg.startsWith(prefix)).map((arg) => arg.substring(prefix.length)).firstOrNull;

/// A fallback for pages without their own status style. Artwork and video regions can override it.
class DefaultStatusBar extends StatelessWidget {
  const DefaultStatusBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: child,
      );
}

class BiliFastApp extends StatelessWidget {
  const BiliFastApp({super.key, required this.services, this.initialLink});

  final AppServices services;
  final String? initialLink;

  @override
  Widget build(BuildContext context) {
    return FollowFont(
      fonts: services.fonts,
      builder: (context) => ListenableBuilder(
        listenable: services.appearance,
        builder: (context, _) => MaterialApp(
          title: 'BiliFast',
          debugShowCheckedModeBanner: false,
          locale: BiliFonts.locale,
          supportedLocales: const [BiliFonts.locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: biliTheme(Brightness.light),
          darkTheme: biliTheme(Brightness.dark),
          themeMode: services.appearance.mode,
          themeAnimationDuration: Duration.zero,
          navigatorKey: services.navigator,
          navigatorObservers: [pageRoutes],
          // The official app keeps its sizes whatever iOS Text Size says, and every size here is measured off it.
          builder: (context, child) => AppScope(
            services: services,
            child: PhoneFrame.wrap(
                context, ReduceMotion(child: MediaQuery.withNoTextScaling(child: DefaultStatusBar(child: child!)))),
          ),
          home: MainShell(
            initialLink: initialLink,
            developerPage: services.logs == null
                ? null
                : (context) => PlayerTestPage(
                      environment: services.environment,
                      startPlayback: services.playback.create,
                      releasePlayback: services.playback.release,
                      logs: services.logs,
                      speedTestHooks: appSpeedTestHooksOn(services.playback.engine),
                      appAuth: services.appAuth,
                    ),
          ),
        ),
      ),
    );
  }
}
