import 'dart:async';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/main.dart';
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/settings/appearance_store.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/skin/fake_skin_api.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/feed_fakes.dart';
import 'fake_keychain.dart';

class _DraftPage extends StatefulWidget {
  const _DraftPage({super.key});

  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage> {
  final draft = TextEditingController();
  final scroll = ScrollController();

  @override
  void dispose() {
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BiliColors.colorsOf(context).card,
    body: ListView(
      controller: scroll,
      children: [
        TextField(controller: draft),
        for (var i = 0; i < 40; i++) SizedBox(height: 50, child: Text('row $i')),
      ],
    ),
  );
}

void main() {
  testWidgets('appearance updates existing routes and overlays while preserving app and page state', (tester) async {
    tester.view
      ..physicalSize = const Size(440, 956)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final http = FeedHttp()..pages[1] = [];
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(const NoStoredCookies()),
      http: http,
      logger: Logger(session: 'appearance'),
    );
    final appearance = AppearanceStore.memory();
    final playback = AppPlayback(() => throw StateError('no player needed'));
    final services = AppServices(
      environment: environment,
      playback: playback,
      recents: await RecentStore.load(null),
      appearance: appearance,
      meApi: FakeMeApi.demo(),
      skinApi: FakeSkinApi(),
      pageApi: FakePageApi(),
    );
    addTearDown(services.dispose);
    addTearDown(playback.dispose);
    addTearDown(appearance.dispose);
    await tester.pumpWidget(BiliFastApp(services: services));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final navigator = services.navigator.currentState!;
    final pageKey = GlobalKey<_DraftPageState>();
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => _DraftPage(key: pageKey))));
    await tester.pumpAndSettle();
    final state = pageKey.currentState!;
    state.draft.text = 'draft before appearance change';
    state.scroll.jumpTo(250);
    await tester.pump();
    final callsBefore = http.canned.requests.length;
    unawaited(showDialog<void>(
      context: pageKey.currentContext!,
      builder: (context) => AlertDialog(
        content: Text('open dialog', style: TextStyle(color: BiliColors.colorsOf(context).text)),
      ),
    ));
    await tester.pumpAndSettle();
    final overlayContext = tester.element(find.text('open dialog'));
    expect(Theme.of(overlayContext).brightness, Brightness.light);

    appearance.toggle();
    await tester.pumpAndSettle();
    expect(identical(services.navigator.currentState, navigator), isTrue);
    expect(identical(pageKey.currentState, state), isTrue);
    expect(state.draft.text, 'draft before appearance change');
    expect(state.scroll.offset, 250);
    expect(identical(AppScope.of(pageKey.currentContext!).playback, playback), isTrue);
    expect(http.canned.requests.length, callsBefore);
    expect(Theme.of(tester.element(find.text('open dialog'))).brightness, Brightness.dark);
    expect(tester.widget<Text>(find.text('open dialog')).style!.color, const Color(0xFFE3E5E7));
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, const Color(0xFF18191B));
    appearance.toggle();
    await tester.pumpAndSettle();
    expect(identical(pageKey.currentState, state), isTrue);
    expect(state.scroll.offset, 250);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, BiliColors.card);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a saved dark choice is used on the first built frame', (tester) async {
    final appearance = AppearanceStore.memory(mode: ThemeMode.dark);
    addTearDown(appearance.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: biliTheme(Brightness.light),
      darkTheme: biliTheme(Brightness.dark),
      themeMode: appearance.mode,
      home: Builder(builder: (context) => ColoredBox(color: BiliColors.colorsOf(context).card)),
    ));
    expect(tester.widget<ColoredBox>(find.byType(ColoredBox).last).color, const Color(0xFF18191B));
  });
}
