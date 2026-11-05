import 'dart:io';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/app_auth.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/feed_dislike.dart';
import 'package:bilifast/home/feed_divider.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';
import '../video/mixed_lines.dart' show appTheme;
import 'fake_login_gate.dart';
import 'feed_fakes.dart';

const _screen = ValueKey('screen');

final _divider = find.byKey(const ValueKey('feed-divider'));

/// 推荐's batches on the official feed (122): 不感兴趣 on a card kept from before, and 刚刚看到这里 against the
/// recording's frame at 2.25 s. With BILIFAST_SHOTS naming a folder outside the repo, the 3× shot is saved there.
void main() {
  late FeedHttp http;
  late ValueNotifier<int> reloads;

  setUp(() {
    HomePage.feedMinimumRefresh = Duration.zero;
    addTearDown(() => HomePage.feedMinimumRefresh = FeedModel.minimumRefresh);
    reloads = ValueNotifier(0);
    addTearDown(reloads.dispose);
    http = FeedHttp();
    http.officialPages[0] = [
      officialItem('BV1aaa', title: '真别选错！差距很大！'),
      officialItem('BV1bbb', title: '睡了一觉，我又变强了！？'),
      officialItem('BV1ccc', title: '一起感受下Fate的极致魅力吧'),
      officialItem('BV1ddd', title: '吾王'),
    ];
  });

  /// 首页 at 3× as KaiC's iPhone on the official feed, its first load in.
  Future<void> show(WidgetTester tester, {bool systemFont = false}) async {
    if (systemFont) {
      final saved = BiliFonts.family;
      addTearDown(() => BiliFonts.family = saved);
      await tester.runAsync(loadSystemFontStandIns);
    }
    showAsPhone(tester);
    final logger = Logger(session: 'test');
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(StoredCookies(Canned.cookies)),
      http: http,
      logger: logger,
    );
    environment.client.appToken = fakeAppToken;
    await environment.refreshAccount();
    final playback = AppPlayback(() => throw StateError('no playback here'));
    addTearDown(playback.dispose);
    final services = AppServices(
      environment: environment,
      playback: playback,
      recents: await RecentStore.load(null, logger: logger),
      fonts: systemFont ? (FontStore.memory()..select(FontChoice.system)) : null,
      loginGate: FakeLoginGate(),
      searchApi: FakeSearchApi(defaultWord: '菲欧妮'),
      appAuth: FakeAppAuth(),
    );
    if (systemFont) BiliFonts.family = BiliFonts.system;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => RepaintBoundary(
          key: _screen,
          child: AppScope(services: services, child: child!),
        ),
        home: HomePage(reloads: reloads),
      ),
    );
    await settle(tester, 40);
  }

  /// A refresh by the bar's 首页 bringing [fresh], let settle.
  Future<void> refresh(WidgetTester tester, List<Map<String, Object?>> fresh) async {
    http.officialPages[0] = fresh;
    reloads.value++;
    await settle(tester, 30);
  }

  Finder card(String bvid) => find.byKey(ValueKey('feed-card-$bvid'));

  Finder turnedOver(String bvid) => find.descendant(of: card(bvid), matching: find.byType(FeedDislikedCard));

  Future<void> dislike(WidgetTester tester, String bvid) async {
    await Scrollable.ensureVisible(tester.element(card(bvid)));
    await settle(tester);
    await tester.tap(find.descendant(of: card(bvid), matching: find.byKey(const ValueKey('big-card-more'))));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
  }

  testWidgets('不感兴趣 on a card from before turns it over where it stands, and 撤销 brings it back', (tester) async {
    await show(tester);
    await refresh(tester, [officialItem('BV1new0'), officialItem('BV1new1')]);
    final below = tester.getRect(_divider).bottom;
    expect(tester.getTopLeft(card('BV1aaa')).dy, moreOrLessEquals(below));

    await dislike(tester, 'BV1aaa');
    expect(turnedOver('BV1aaa'), findsOneWidget);
    expect(http.dislikes.single['id'], '${'BV1aaa'.hashCode.abs()}');
    expect(
      tester.getTopLeft(card('BV1aaa')).dy,
      moreOrLessEquals(tester.getRect(find.byKey(const ValueKey('feed'))).top),
      reason: 'in its scrolled place',
    );
    expect(turnedOver('BV1new0'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('feed-disliked-undo')));
    await settle(tester);
    expect(turnedOver('BV1aaa'), findsNothing);
    expect(http.cancels, hasLength(1));
  });

  testWidgets('the next refresh drops a card turned over: its user asked not to see it', (tester) async {
    await show(tester);
    await refresh(tester, [officialItem('BV1new0'), officialItem('BV1new1')]);
    await dislike(tester, 'BV1aaa');
    await refresh(tester, [officialItem('BV1top0'), officialItem('BV1top1')]);
    expect(find.byKey(const ValueKey('feed-card-BV1aaa'), skipOffstage: false), findsNothing);
    expect(find.byType(FeedDislikedCard), findsNothing);
    await tester.scrollUntilVisible(_divider, 200);
    await settle(tester);
    expect(tester.getTopLeft(card('BV1new0')).dy, moreOrLessEquals(tester.getRect(_divider).bottom));
    expect(
      tester.getTopLeft(card('BV1bbb')).dy,
      moreOrLessEquals(tester.getRect(card('BV1new1')).bottom + FeedBigCardTheme.topGap * 2 + 0.5),
      reason: 'the cards before run on without it',
    );
  });

  testWidgets("look-alike: 122's divider under the system font, the cards above ending where 2.25 s has them", (
    tester,
  ) async {
    http.officialPages[0] = [for (var i = 0; i < 8; i++) officialItem('BV1old$i', title: '银狼战舰出炉！全程输出+无缝衔接')];
    await show(tester, systemFont: true);
    await refresh(tester, [for (var i = 0; i < 8; i++) officialItem('BV1new$i', title: '我接受钢铁侠以任何形式复活')]);
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: find.byKey(const ValueKey('feed')), matching: find.byType(Scrollable)),
        )
        .position;
    // 122's cards above end at 709.33 pt.
    const above = 2128 / 3;
    // Twice: the first scroll folds the header (121), which moves the feed up by the fold.
    for (var i = 0; i < 2; i++) {
      final top = tester.getRect(find.byKey(const ValueKey('feed-divider'), skipOffstage: false)).top;
      position.jumpTo(position.pixels + top - above);
      await settle(tester, 8);
    }

    final line = tester.getRect(_divider);
    expect(line.top, moreOrLessEquals(above));
    expect(line.height, FeedBatchTheme.dividerGap);
    final words = tester.getRect(find.descendant(of: _divider, matching: find.text(FeedDivider.label)));
    final icon = tester.getRect(find.descendant(of: _divider, matching: find.byType(Image)));
    expect(words.width, moreOrLessEquals(11 * FeedBatchTheme.text), reason: '11 glyphs, an em each');
    expect(icon.width, moreOrLessEquals(FeedBatchTheme.icon));
    expect(icon.height, moreOrLessEquals(FeedBatchTheme.icon));
    expect(icon.left - words.right, moreOrLessEquals(FeedBatchTheme.iconGap));
    expect(icon.center.dy, moreOrLessEquals(line.center.dy + FeedBatchTheme.drop));
    expect(words.center.dy, moreOrLessEquals(line.center.dy + FeedBatchTheme.drop));
    expect((words.left + icon.right) / 2, moreOrLessEquals(220 + FeedBatchTheme.right), reason: 'together');

    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/122-feed-divider-ours.png');
  });
}

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
