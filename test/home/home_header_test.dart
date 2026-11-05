import 'dart:async';
import 'dart:io';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/avatar_page.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/home_header.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/search/search_glyphs.dart';
import 'package:bilifast/search/search_page.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/skin/skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../me/me_page_support.dart' show FixedSkinModel;
import '../playback/fakes.dart';
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';
import '../video/mixed_lines.dart' show appTheme;
import 'fake_login_gate.dart';
import 'feed_fakes.dart';
import 'skin_fixtures.dart';

late SkinPictures _pictures;

const _screen = ValueKey('screen');

/// 121's default word.
const _word = '黄泉v4';

const _fold = HomeHeaderTheme.fold;

/// 首页's header folding its top row away as 推荐 scrolls (121), on KaiC's iPhone: 440 × 956 with the 62 pt status bar.
void main() {
  setUpAll(() async => _pictures = await SkinPictures.draw());
  tearDownAll(() => _pictures.dispose());

  late FeedHttp http;

  setUp(() {
    http = FeedHttp()..pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1h$i')];
    HomePage.feedMinimumRefresh = Duration.zero;
    addTearDown(() => HomePage.feedMinimumRefresh = FeedModel.minimumRefresh);
  });

  /// The shell with 推荐 answered, dressed by [skin]; [phone] draws it at 3× under the system font, [still] asks for
  /// Reduce Motion.
  Future<void> show(WidgetTester tester, {Skin? skin, bool phone = false, bool still = false}) async {
    if (phone) {
      final saved = BiliFonts.family;
      addTearDown(() => BiliFonts.family = saved);
      await tester.runAsync(loadSystemFontStandIns);
      showAsPhone(tester);
    } else {
      tester.view
        ..physicalSize = const Size(440, 956)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 62, bottom: 34)
        ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.reset);
    }
    if (still) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    if (skin != null) await SkinPictures.load(tester, skin);
    final logger = Logger(session: 'test');
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(StoredCookies(Canned.cookies)),
      http: http,
      logger: logger,
    );
    await environment.refreshAccount();
    final playback = AppPlayback(() => throw StateError('no playback here'));
    addTearDown(playback.dispose);
    final services = AppServices(
      environment: environment,
      playback: playback,
      recents: await RecentStore.load(null, logger: logger),
      fonts: FontStore.memory()..select(FontChoice.system),
      searchApi: FakeSearchApi(defaultWord: _word),
      meApi: FakeMeApi.demo(),
      loginGate: FakeLoginGate(),
    );
    final skins = FixedSkinModel(skin, environment: environment);
    addTearDown(skins.dispose);
    if (phone) BiliFonts.family = BiliFonts.system;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        builder: (context, child) => RepaintBoundary(
          key: _screen,
          child: AppScope(services: services, child: child!),
        ),
        home: MainShell(skin: skins),
      ),
    );
    await settle(tester);
  }

  ScrollPosition feedScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: find.byKey(const ValueKey('feed')), matching: find.byType(Scrollable)).first,
      )
      .position;

  Rect header(WidgetTester tester) => tester.getRect(find.byType(HomeHeader));
  double cardTop(WidgetTester tester) => tester.getTopLeft(find.byKey(const ValueKey('feed-card-BV1h0'))).dy;
  double tabTop(WidgetTester tester) => tester.getTopLeft(find.byKey(const ValueKey('home-tab-recommend'))).dy;

  Finder magnifier() => find.byKey(const ValueKey('home-header-search'));
  Rect glyph(WidgetTester tester) =>
      tester.getRect(find.descendant(of: magnifier(), matching: find.byType(SearchGlyphIcon)));

  /// The top row's opacity, through the avatar it holds.
  double topRowOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.ancestor(of: find.byKey(const ValueKey('home-avatar')), matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  /// The fold's share [elapsed] into it.
  double eased(Duration elapsed) => HomeHeaderTheme.curve.transform(
    elapsed.inMicroseconds / HomeHeaderTheme.duration.inMicroseconds,
  );

  /// Where the magnifier's box sits folded: at the tab row's end, under the status bar.
  const foldedGlyph = Rect.fromLTWH(
    440 - HomeHeaderTheme.searchRight - HomeHeaderTheme.searchSize,
    62 + HomeHeaderTheme.searchTop,
    HomeHeaderTheme.searchSize,
    HomeHeaderTheme.searchSize,
  );

  /// Scrolls 推荐 to [offset] and lets the fold run its course.
  Future<void> scrollTo(WidgetTester tester, double offset) async {
    feedScroll(tester).jumpTo(offset);
    await settle(tester);
  }

  testWidgets('past the trigger the header folds its top row away over 0.3 s, eased, and the feed rises with it', (
    tester,
  ) async {
    await show(tester);
    final open = header(tester);
    final top = cardTop(tester);
    expectRect(open, const Rect.fromLTRB(0, 0, 440, 142));
    expect(top, open.bottom + FeedBigCardTheme.topGap);

    feedScroll(tester).jumpTo(HomeHeaderTheme.trigger - 1);
    await settle(tester);
    expect(header(tester), open, reason: 'short of the trigger');
    expect(cardTop(tester), top - (HomeHeaderTheme.trigger - 1));
    expect(magnifier(), findsNothing);

    const scrolled = 10.0;
    feedScroll(tester).jumpTo(scrolled);
    await tester.pump();
    for (final at in const [75, 150, 225]) {
      await tester.pump(const Duration(milliseconds: 75));
      final folded = _fold * eased(Duration(milliseconds: at));
      expect(header(tester).bottom, moreOrLessEquals(open.bottom - folded), reason: '$at ms');
      expect(cardTop(tester), moreOrLessEquals(top - scrolled - folded), reason: 'the cards move with it');
    }
    expect(eased(const Duration(milliseconds: 150)), 0.5);
    await tester.pump(const Duration(milliseconds: 75));
    expectRect(header(tester), const Rect.fromLTRB(0, 0, 440, 98));
    expect(cardTop(tester), moreOrLessEquals(top - scrolled - _fold));
    expect(tabTop(tester), moreOrLessEquals(62 + BiliMetrics.tabRowTop), reason: 'the tab row under the status bar');
    expect(tester.getTopLeft(find.byKey(const ValueKey('feed'))).dy, header(tester).bottom);

    await settle(tester);
    expect(header(tester).bottom, open.bottom - _fold, reason: 'it stays folded');
    expect(tester.binding.transientCallbackCount, 0, reason: 'nothing left ticking');
  });

  testWidgets('the top row fades as it folds and then takes no taps; the magnifier rides in at the tab row\'s end, '
      'in the tabs\' grey, and opens 搜索', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    expect(topRowOpacity(tester), 1);
    expect(find.semantics.byLabel('搜索'), findsOneWidget, reason: 'the field');

    feedScroll(tester).jumpTo(40);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(topRowOpacity(tester), moreOrLessEquals(0.5));
    expectRect(
      glyph(tester),
      foldedGlyph.shift(const Offset(HomeHeaderTheme.searchSlide * 0.5, _fold * 0.5)),
      reason: 'half way in, with the tab row half way up',
    );
    await settle(tester);
    expect(topRowOpacity(tester), 0);
    expectRect(glyph(tester), foldedGlyph);
    expect(tester.widget<SearchGlyphIcon>(find.byType(SearchGlyphIcon).last).color, HomeHeaderTheme.searchInk);
    expect(tester.getRect(magnifier()), const Rect.fromLTRB(440 - HomeHeaderTheme.searchTarget, 62, 440, 98 - 1 / 3));

    await tester.tap(find.byKey(const ValueKey('home-search')), warnIfMissed: false);
    await tester.tap(find.byKey(const ValueKey('home-avatar')), warnIfMissed: false);
    await settle(tester, 20);
    expect(find.byType(SearchPage), findsNothing, reason: 'the faded field takes no taps');
    expect(find.byType(AvatarPage), findsNothing, reason: 'nor the avatar');
    expect(find.semantics.byLabel('搜索'), findsOneWidget, reason: 'only the magnifier is read out');
    expect(tester.getSemantics(magnifier()), isSemantics(label: '搜索', isButton: true, hasTapAction: true));

    await tester.tap(magnifier());
    await settle(tester, 20);
    expect(tester.widget<SearchPage>(find.byType(SearchPage)).placeholder, _word);
    await tester.binding.handlePopRoute();
    await settle(tester, 20);
    expect(find.byType(SearchPage), findsNothing);
    semantics.dispose();
  });

  testWidgets('the magnifier answers VoiceOver\'s press', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    await scrollTo(tester, 40);
    tester.semantics.tap(find.semantics.byLabel('搜索'));
    await settle(tester, 20);
    expect(find.byType(SearchPage), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('it opens again only back under the trigger, animated the same way; a pull past the top keeps it open', (
    tester,
  ) async {
    await show(tester);
    final open = header(tester);
    await scrollTo(tester, 400);
    expect(header(tester).bottom, open.bottom - _fold);
    await scrollTo(tester, HomeHeaderTheme.trigger);
    expect(header(tester).bottom, open.bottom - _fold, reason: 'still at the trigger');

    feedScroll(tester).jumpTo(HomeHeaderTheme.trigger - 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final opened = eased(const Duration(milliseconds: 75));
    expect(header(tester).bottom, moreOrLessEquals(open.bottom - _fold * (1 - opened)));
    expect(topRowOpacity(tester), moreOrLessEquals(opened));
    await settle(tester);
    expect(header(tester), open);
    expect(magnifier(), findsNothing);
    expect(topRowOpacity(tester), 1);
    await tester.tap(find.byKey(const ValueKey('home-search')));
    await settle(tester, 20);
    expect(find.byType(SearchPage), findsOneWidget, reason: 'the field takes taps again');
    await tester.binding.handlePopRoute();
    await settle(tester, 20);

    await scrollTo(tester, 0);
    final pull = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('feed'))));
    for (var i = 0; i < 4; i++) {
      await pull.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(feedScroll(tester).pixels, lessThan(0));
    await settle(tester, 4);
    expect(header(tester), open);
    expect(magnifier(), findsNothing);
    await pull.up();
    await settle(tester, 40);
    expect(header(tester), open);
  });

  testWidgets("首页's tap opens it at once, alongside the scroll to the top, and refreshes", (tester) async {
    await show(tester);
    final open = header(tester);
    await scrollTo(tester, 1200);
    expect(header(tester).bottom, open.bottom - _fold);
    final asked = http.asked.length;
    http.gates[1] = Completer<void>();

    await tester.tap(find.byKey(const ValueKey('home-tab-home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(header(tester).bottom, moreOrLessEquals(open.bottom - _fold * 0.5),
        reason: 'half open half way, as the official app (differences/23), not after the scroll');
    expect(feedScroll(tester).pixels, greaterThan(HomeHeaderTheme.trigger), reason: 'the scroll is still on its way');
    await tester.pump(const Duration(milliseconds: 75));
    expect(header(tester).bottom, greaterThan(open.bottom - _fold * 0.5), reason: 'it keeps opening; no fold back');
    await settle(tester, 20);
    expect(feedScroll(tester).pixels, 0);
    expect(header(tester), open);
    expect(magnifier(), findsNothing);
    expect(http.asked.sublist(asked), [1]);
    http.gates[1]!.complete();
    await settle(tester, 20);
    expect(header(tester), open);
  });

  testWidgets('with Reduce Motion it folds and opens at once', (tester) async {
    await show(tester, still: true);
    final open = header(tester);
    feedScroll(tester).jumpTo(40);
    await tester.pump();
    expect(header(tester).bottom, open.bottom - _fold);
    expect(topRowOpacity(tester), 0);
    expectRect(glyph(tester), foldedGlyph);
    feedScroll(tester).jumpTo(0);
    await tester.pump();
    expect(header(tester), open);
    expect(magnifier(), findsNothing);
    await settle(tester);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets("a 装扮's header folds too: its pictures move up with it, cut at the screen's top, the magnifier in the "
      "skin's colour at the other tabs' 72%", (tester) async {
    Finder headArt() => find.byKey(const ValueKey('home-head-art'));
    Finder tabArt() => find.byKey(const ValueKey('home-head-tab-art'));
    await show(tester, skin: _pictures.skin());
    final open = header(tester);
    expect(tester.getRect(headArt()), const Rect.fromLTRB(0, 0, 440, 106));
    final tab = tester.getRect(tabArt());
    expect(tab.top, 106);

    await scrollTo(tester, 40);
    expect(header(tester), Rect.fromLTRB(0, 0, 440, open.bottom - _fold));
    expect(tester.getRect(headArt()), const Rect.fromLTRB(0, -_fold, 440, 106 - _fold));
    expect(tester.getRect(tabArt()), tab.shift(const Offset(0, -_fold)));
    expectRect(glyph(tester), foldedGlyph);
    expect(
      tester.widget<SearchGlyphIcon>(find.descendant(of: magnifier(), matching: find.byType(SearchGlyphIcon))).color,
      const Color(0xFFFFFFFF).withValues(alpha: HomeHeaderTheme.skinSearchOpacity),
    );

    await scrollTo(tester, 0);
    expect(header(tester), open);
    expect(tester.getRect(headArt()), const Rect.fromLTRB(0, 0, 440, 106));
  });

  group('look-alike under the system font, against 121 (f001 open, f075 folded)', () {
    /// With BILIFAST_SHOTS naming a folder outside the repo, the 3× shots are saved there for tools/screen_diff.py.
    Future<void> shoot(WidgetTester tester, String name) async {
      final shots = Platform.environment['BILIFAST_SHOTS'];
      if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/$name');
    }

    for (final dressed in [false, true]) {
      testWidgets(dressed ? 'dressed by a stand-in 装扮' : 'on white', (tester) async {
        await show(tester, phone: true, skin: dressed ? _pictures.skin() : null);
        final open = header(tester);
        expect(open.bottom, moreOrLessEquals(142, epsilon: 0.34), reason: "121's header ends at 142");
        final tabOpen = tester.getRect(find.byKey(const ValueKey('home-tab-recommend')));
        await shoot(tester, '121-home-${dressed ? 'dressed' : 'white'}-open-ours.png');

        await scrollTo(tester, 40);
        expect(header(tester).bottom, moreOrLessEquals(98, epsilon: 0.34), reason: '98 folded');
        expectRect(
          tester.getRect(find.byKey(const ValueKey('home-tab-recommend'))),
          tabOpen.shift(const Offset(0, -_fold)),
        );
        expectRect(glyph(tester), foldedGlyph);
        await shoot(tester, '121-home-${dressed ? 'dressed' : 'white'}-folded-ours.png');
      });
    }
  });

  testWidgets('a list too short to scroll folds nothing when dragged up past the trigger, held or let go', (
    tester,
  ) async {
    http.pages[1] = [feedItem('BV1h0')];
    await show(tester);
    final open = header(tester);
    final drag = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('feed'))));
    for (var i = 0; i < 5; i++) {
      await drag.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester);
    expectRect(header(tester), open);
    await drag.up();
    await settle(tester);
    expectRect(header(tester), open);
  });

  testWidgets("the fold lays the feed out again each frame without building its cards again", (tester) async {
    await show(tester);
    final before = tester.element(find.byKey(const ValueKey('feed-card-BV1h2')));
    final built = <Widget>{before.widget};
    feedScroll(tester).jumpTo(HomeHeaderTheme.trigger);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      built.add(tester.element(find.byKey(const ValueKey('feed-card-BV1h2'))).widget);
    }
    expect(header(tester).height, moreOrLessEquals(142 - _fold));
    expect(built, hasLength(1), reason: 'the same card widget throughout');
  });
}

void expectRect(Rect actual, Rect expected, {String? reason}) {
  for (final (edge, got, want) in [
    ('left', actual.left, expected.left),
    ('top', actual.top, expected.top),
    ('right', actual.right, expected.right),
    ('bottom', actual.bottom, expected.bottom),
  ]) {
    expect(got, moreOrLessEquals(want), reason: '${reason ?? ''} ($edge)');
  }
}

/// Lets requests answer and frames run.
Future<void> settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
