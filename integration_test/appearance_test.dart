import 'dart:io';

import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/main.dart';
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/me/me_page.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/settings/appearance_store.dart';
import 'package:bilifast/settings/settings_page.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/skin/fake_skin_api.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/app/fake_keychain.dart';
import '../test/home/feed_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the moon changes the Windows UI, survives navigation, and restores in a new app', (tester) async {
    final folder = await Directory.systemTemp.createTemp('bilifast_appearance_integration');
    addTearDown(() => folder.delete(recursive: true));
    final path = '${folder.path}/appearance.json';

    Future<AppServices> services(AppearanceStore appearance) async {
      final http = FeedHttp(loggedIn: false)..pages[1] = [];
      final environment = await AppEnvironment.load(
        keychain: FakeKeychain(const NoStoredCookies()),
        http: http,
      );
      await environment.refreshAccount();
      final playback = AppPlayback(() => throw StateError('this appearance check opens no videos'));
      final app = AppServices(
        environment: environment,
        playback: playback,
        recents: await RecentStore.load(null),
        appearance: appearance,
        pageApi: FakePageApi(),
        meApi: FakeMeApi.demo(),
        searchApi: FakeSearchApi(defaultWord: 'BiliFast'),
        skinApi: FakeSkinApi(),
      );
      addTearDown(app.dispose);
      addTearDown(playback.dispose);
      addTearDown(appearance.dispose);
      return app;
    }

    Future<void> frames() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Finder key(String value) => find.byKey(ValueKey(value));
    final appearance = await AppearanceStore.load(path);
    final first = await services(appearance);
    await tester.pumpWidget(BiliFastApp(services: first));
    await frames();
    await tester.tap(key('home-tab-mine'));
    await frames();
    final shellState = tester.state(find.byType(MainShell));
    final myState = tester.state(find.byType(MePage));
    final navigator = first.navigator.currentState;
    expect(Theme.of(tester.element(find.byType(MePage))).brightness, Brightness.light);

    await tester.tap(key('me-night'));
    await frames();
    expect(appearance.isDark, isTrue);
    expect(Theme.of(tester.element(find.byType(MePage))).brightness, Brightness.dark);
    expect(tester.state(find.byType(MainShell)), same(shellState));
    expect(tester.state(find.byType(MePage)), same(myState));
    expect(first.navigator.currentState, same(navigator));

    await tester.ensureVisible(key('me-settings'));
    await tester.tap(key('me-settings'));
    await frames();
    final settings = tester.element(find.byType(SettingsPage));
    expect(BiliPalette.of(settings).isDark, isTrue);
    expect(tester.widget<Text>(find.text('字体')).style?.color, const BiliPalette(Brightness.dark).text);
    await tester.tap(key('settings-back'));
    await frames();
    expect(tester.state(find.byType(MePage)), same(myState));

    await tester.tap(key('me-night'));
    await frames();
    expect(Theme.of(tester.element(find.byType(MePage))).brightness, Brightness.light);
    await tester.tap(key('me-night'));
    await frames();
    await appearance.settle();
    await tester.pumpWidget(const SizedBox.shrink());
    await frames();

    final restored = await AppearanceStore.load(path);
    expect(restored.isDark, isTrue);
    final second = await services(restored);
    await tester.pumpWidget(BiliFastApp(services: second));
    await tester.pump();
    expect(Theme.of(tester.element(find.byType(MainShell))).brightness, Brightness.dark);
    await frames();
    await tester.tap(key('home-tab-mine'));
    await frames();
    expect(BiliPalette.of(tester.element(find.byType(MePage))).surface, const Color(0xFF18191B));
    await tester.pumpWidget(const SizedBox.shrink());
    await frames();
  });
}
