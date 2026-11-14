import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/feed_big_card.dart';
import 'package:bilifast/home/feed_card.dart';
import 'package:bilifast/home/feed_more_sheet.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import 'feed_fakes.dart';

void main() {
  const title = '【战地6】欢乐日常：只要...到达二楼';
  late CannedHttp http;
  late List<String> copied;
  bool clipboardFails = false;

  setUp(() {
    http = Canned.http(loggedIn: false);
    copied = [];
    clipboardFails = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardFails) {
              throw PlatformException(code: 'clipboard-unavailable');
            }
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  Future<void> show(
    WidgetTester tester, {
    bool big = true,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view
      ..physicalSize = const Size(440, 956)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final logger = Logger(session: 'test');
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(const NoStoredCookies()),
      http: http,
      logger: logger,
    );
    final playback = AppPlayback(() => throw StateError('no playback here'));
    addTearDown(playback.dispose);
    final services = AppServices(
      environment: environment,
      playback: playback,
      recents: await RecentStore.load(null, logger: logger),
    );
    final card = bigCard('BV1GJ411x7h7', fullTitle: title);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) =>
            AppScope(services: services, child: child!),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: big ? 408 : 200,
              child: big
                  ? FeedBigCardView(
                      card: card,
                      onOpen: (_, _) async {},
                      onWatchLater: () {},
                    )
                  : FeedCardView(
                      card: card,
                      onOpen: (_) {},
                      onWatchLater: () {},
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(big ? 'big-card-more' : 'card-more')));
    await tester.pumpAndSettle();
  }

  for (final big in [false, true]) {
    testWidgets(
      '${big ? 'big' : 'small'} card copies its full title and video URL and closes the menu',
      (tester) async {
        await show(
          tester,
          big: big,
          brightness: big ? Brightness.dark : Brightness.light,
        );
        expect(copied, isEmpty);
        final requestsBeforeCopy = http.requests.length;
        await tester.tap(find.text('复制链接'));
        await tester.pumpAndSettle();
        expect(copied, [
          '【$title-哔哩哔哩】 https://www.bilibili.com/video/BV1GJ411x7h7',
        ]);
        expect(find.byType(FeedSheetRow), findsNothing);
        expect(find.text('已复制链接'), findsOneWidget);
        expect(http.requests, hasLength(requestsBeforeCopy));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'dismissing the menu leaves the clipboard alone and requests no link',
    (tester) async {
      await show(tester);
      final requestsBeforeDismiss = http.requests.length;
      await tester.tapAt(const Offset(220, 300));
      await tester.pumpAndSettle();
      expect(find.byType(FeedSheetRow), findsNothing);
      expect(copied, isEmpty);
      expect(http.requests, hasLength(requestsBeforeDismiss));
    },
  );

  testWidgets('clipboard failure shows a failure instead of a success toast', (
    tester,
  ) async {
    clipboardFails = true;
    await show(tester);
    await tester.tap(find.text('复制链接'));
    await tester.pumpAndSettle();
    expect(copied, isEmpty);
    expect(find.text('复制失败，请重试'), findsOneWidget);
    expect(find.text('已复制链接'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
