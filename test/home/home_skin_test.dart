import 'dart:async';
import 'dart:io';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/app/route_observer.dart';
import 'package:bilifast/dynamic/follow_tab/follow_tab_page.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/home_tab_bar.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/home/tab_bar_icons.dart';
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/me/me_page.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/skin/skin.dart';
import 'package:bilifast/skin/skin_video.dart';
import 'package:bilifast/skin/svga/svga_loader.dart';
import 'package:bilifast/skin/svga/svga_painter.dart';
import 'package:bilifast/skin/svga_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../me/me_page_support.dart' show FixedSkinModel;
import '../playback/fakes.dart';
import '../skin/svga_fixtures.dart' show frame2, movie2, png, sprite2;
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';
import '../video/mixed_lines.dart';
import 'fake_login_gate.dart';
import 'feed_fakes.dart';
import 'skin_fixtures.dart';

late SkinPictures _pictures;

const _screen = ValueKey('screen');

/// 110's default word.
const _word = '曜荣耀典藏';

void main() {
  setUpAll(() async => _pictures = await SkinPictures.draw());
  tearDownAll(() => _pictures.dispose());

  late FeedHttp http;

  setUp(() {
    http = FeedHttp()..pages[1] = [for (var i = 0; i < 20; i++) feedItem('BV1s$i')];
  });

  /// The shell on KaiC's iPhone (62 pt status bar, 34 pt home indicator), its 装扮 [skin] held in the returned
  /// model; [phone] draws it at 3× under the system font, [load] decodes the skin's pictures first.
  Future<FixedSkinModel> show(WidgetTester tester, Skin? skin, {bool phone = false, bool load = true}) async {
    await tester.pumpWidget(const SizedBox.shrink());
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
    if (skin != null && load) await SkinPictures.load(tester, skin);
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
        navigatorObservers: [pageRoutes],
        builder: (context, child) => RepaintBoundary(
          key: _screen,
          child: AppScope(services: services, child: child!),
        ),
        home: MainShell(skin: skins),
      ),
    );
    return skins;
  }

  Future<void> settle(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder headArt() => find.byKey(const ValueKey('home-head-art'));
  Finder tabArt() => find.byKey(const ValueKey('home-head-tab-art'));
  Rect divider(WidgetTester tester) => tester.getRect(find.byType(Divider).first);

  Image imageIn(WidgetTester tester, Finder finder) =>
      tester.widget<Image>(find.descendant(of: finder, matching: find.byType(Image)));

  Color? recommendColour(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('home-tab-recommend'))).style?.color;

  Color? indicatorColour(WidgetTester tester) =>
      (tester.widget<Container>(find.byKey(const ValueKey('home-tab-indicator'))).decoration! as BoxDecoration).color;

  Container field(WidgetTester tester) => tester.widget<Container>(find.byKey(const ValueKey('home-search-field')));

  ScrollPosition feedScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: find.byKey(const ValueKey('feed')), matching: find.byType(Scrollable)).first,
      )
      .position;

  double bottomInset(WidgetTester tester, Type page) =>
      MediaQuery.paddingOf(tester.element(find.byType(page, skipOffstage: false))).bottom;

  group('首页 dressed by head_bg', () {
    testWidgets(
      'to the top row\'s bottom with head_tab_bg behind the tab row, both centre-cropped; the hairline grey',
      (tester) async {
        await show(tester, _pictures.skin());
        await settle(tester);
        expect(tester.getRect(headArt()), const Rect.fromLTRB(0, 0, 440, 106));
        expect(tester.getRect(tabArt()), Rect.fromLTRB(0, 106, 440, divider(tester).top));
        for (final (art, name) in [(headArt(), 'head_bg.png'), (tabArt(), 'head_tab_bg.png')]) {
          final image = imageIn(tester, art);
          expect((image.image as FileImage).file.path, _pictures[name].path);
          expect(image.fit, BoxFit.cover);
          expect(image.alignment, Alignment.center);
        }
        expect(tester.widget<Divider>(find.byType(Divider).first).color, HomeTabBarTheme.headDivider);
      },
    );

    testWidgets('behind the whole top when the package has no tab picture', (tester) async {
      await show(tester, _pictures.skin(tab: false));
      await settle(tester);
      expect(tester.getRect(headArt()), Rect.fromLTRB(0, 0, 440, divider(tester).top));
      expect(tabArt(), findsNothing);
    });

    testWidgets("推荐 and its indicator in the skin's colour, the field white without its rim, the avatar and field "
        'where they were, the status bar light', (tester) async {
      await show(tester, null);
      await settle(tester);
      final avatar = tester.getRect(find.byKey(const ValueKey('home-avatar')));
      final entry = tester.getRect(find.byKey(const ValueKey('home-search')));
      final recommend = tester.getRect(find.byKey(const ValueKey('home-tab-recommend')));
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);

      await show(tester, _pictures.skin());
      await settle(tester);
      expect(recommendColour(tester), const Color(0xFFFFFFFF));
      expect(indicatorColour(tester), const Color(0xFFFFFFFF));
      final decoration = field(tester).decoration! as ShapeDecoration;
      expect(decoration.color, HomeTabBarTheme.headField);
      expect((field(tester).foregroundDecoration! as ShapeDecoration).shape, const StadiumBorder());
      expect(tester.getRect(find.byKey(const ValueKey('home-avatar'))), avatar);
      expect(tester.getRect(find.byKey(const ValueKey('home-search'))), entry);
      expect(tester.getRect(find.byKey(const ValueKey('home-tab-recommend'))), recommend);
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    });

    testWidgets('a dark-text skin keeps the status bar dark', (tester) async {
      await show(
        tester,
        _pictures.skin(
          colors: const SkinColors(color: 0xFF222222, tailColor: 0xFFFAF0E4, tailColorSelected: 0xFFFFDA76),
        ),
      );
      await settle(tester);
      expect(recommendColour(tester), const Color(0xFF222222));
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('a skin without head_bg leaves the top stock, whatever its colours', (tester) async {
      await show(tester, _pictures.skin(head: false));
      await settle(tester);
      expect(headArt(), findsNothing);
      expect(tabArt(), findsNothing);
      expect(recommendColour(tester), BiliColors.pink);
      expect(indicatorColour(tester), BiliColors.pink);
      expect(field(tester).decoration, isNull);
      expect(tester.widget<Divider>(find.byType(Divider).first).color, BiliColors.divider);
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
      expect(find.byType(SkinTabIcon), findsNWidgets(4), reason: 'the bar still takes it');
    });
  });

  testWidgets('under a dressed bar the pages run to the bottom inset by the stock bar: the feed ends where the stock '
      "bar's feed does, 我的 gets the same inset", (tester) async {
    /// The lowest card's bottom with 推荐 scrolled to its end.
    Future<double> end() async {
      final scroll = feedScroll(tester);
      for (var i = 0; i < 2; i++) {
        scroll.jumpTo(scroll.maxScrollExtent);
        await settle(tester);
      }
      return find
          .byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'feed-card-"))
          .evaluate()
          .map((card) => tester.getRect(find.byWidget(card.widget)).bottom)
          .reduce((a, b) => a > b ? a : b);
    }

    await show(tester, null);
    await settle(tester);
    final stockEnd = await end();

    await show(tester, _pictures.skin());
    await settle(tester);
    expect(
      tester.getRect(find.byType(HomeTabBar)),
      const Rect.fromLTRB(0, 873 - HomeTabBarTheme.skinIconOverhang, 440, 956),
      reason: "grown by the icons' rise",
    );
    final row = tester.getRect(find.byKey(const ValueKey('home-tab-home'))).top;
    expect(row, 873);
    expect(tester.getRect(find.byType(HomePage)).bottom, 956);
    expect(tester.getRect(find.byKey(const ValueKey('feed'))).bottom, 956);
    expect(bottomInset(tester, HomePage), HomeTabBarTheme.height + 34);
    expect(bottomInset(tester, MePage), HomeTabBarTheme.height + 34);
    expect(await end(), stockEnd);
    expect(stockEnd, lessThan(row));

    await tester.tap(find.byKey(const ValueKey('home-tab-mine')));
    await settle(tester);
    expect(tester.getRect(find.byType(MePage)), const Rect.fromLTRB(0, 0, 440, 956));
    expect(bottomInset(tester, MePage), HomeTabBarTheme.height + 34);
  });

  testWidgets('a skin coming and going: the stock layout back exactly, both pages and 推荐\'s place kept', (
    tester,
  ) async {
    final skin = await show(tester, null);
    await settle(tester);
    final stockFeed = tester.getRect(find.byKey(const ValueKey('feed')));
    expect(stockFeed.bottom, 873);
    expect(bottomInset(tester, HomePage), 0);
    expect(bottomInset(tester, MePage), 0);
    final home = tester.state(find.byType(HomePage));
    final me = tester.state(find.byType(MePage, skipOffstage: false));
    await tester.drag(find.byKey(const ValueKey('feed')), const Offset(0, -600));
    await settle(tester);
    final at = feedScroll(tester).pixels;
    expect(at, greaterThan(300));
    // Scrolled, the header has folded its top row away (121).
    final scrolledFeed = tester.getRect(find.byKey(const ValueKey('feed')));

    final dressed = _pictures.skin();
    await SkinPictures.load(tester, dressed);
    skin.skin = dressed;
    await settle(tester);
    expect(find.byKey(const ValueKey('home-tab-art')), findsOneWidget);
    expect(headArt(), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('feed'))).bottom, 956);
    expect(feedScroll(tester).pixels, at);
    expect(tester.state(find.byType(HomePage)), same(home));
    expect(tester.state(find.byType(MePage, skipOffstage: false)), same(me));

    skin.skin = null;
    await settle(tester);
    expect(find.byKey(const ValueKey('home-tab-art')), findsNothing);
    expect(headArt(), findsNothing);
    expect(find.byType(HomeTabIcon), findsNWidgets(HomeTab.values.length));
    expect(tester.getRect(find.byKey(const ValueKey('feed'))), scrolledFeed);
    expect(bottomInset(tester, HomePage), 0);
    expect(feedScroll(tester).pixels, at);
    expect(tester.state(find.byType(HomePage)), same(home));
  });

  testWidgets('every place answers its press under a dressed bar, over its icon\'s rise too', (tester) async {
    await show(tester, _pictures.skin());
    await settle(tester);
    expect(tester.getRect(find.byKey(const ValueKey('feed'))).bottom, 956, reason: '推荐 runs under the icons');
    await tester.tapAt(const Offset(44 + 88.0 * 4, 873 - 8));
    await settle(tester);
    expect(tester.widget<MePage>(find.byType(MePage)).active, isTrue);
    await tester.tap(find.byKey(const ValueKey('home-tab-home')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-tab-mine')));
    await settle(tester);
    expect(tester.widget<MePage>(find.byType(MePage)).active, isTrue);
    await tester.tap(find.byKey(const ValueKey('home-tab-follow')));
    await settle(tester);
    expect(find.byType(FollowTabPage), findsOneWidget);
    for (final tab in [HomeTab.post, HomeTab.messages]) {
      await tester.tap(find.byKey(ValueKey('home-tab-${tab.name}')));
      await tester.pump();
      expect(find.text('暂未开放'), findsOneWidget, reason: tab.label);
      await settle(tester, 60);
    }
    final asked = List.of(http.asked);
    await tester.tap(find.byKey(const ValueKey('home-tab-home')));
    await settle(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(http.asked, asked, reason: 'returning to 首页 only shows it again');
    await tester.tap(find.byKey(const ValueKey('home-tab-home')));
    await settle(tester, 40);
    expect(http.asked, [...asked, 1, 2],
        reason: '首页 on 首页 refreshes once, with lookahead for repeated visible videos');
  });

  for (final (name, failing) in [('failure', true), ('empty page', false)]) {
    testWidgets("推荐's $name message and 重试 centred above the bar's row, under the dressed bar as under the stock", (
      tester,
    ) async {
      http.pages.clear();
      if (failing) http.failing.add(1);
      Future<(Rect, Rect)> measure() async {
        await settle(tester);
        final message = find.byKey(const ValueKey('feed-error'));
        if (!failing) expect(tester.widget<Text>(message).data, FeedModel.emptyMessage);
        return (tester.getRect(message), tester.getRect(find.byKey(const ValueKey('feed-retry'))));
      }

      await show(tester, null);
      final (message, retry) = await measure();
      expect((message.top + retry.bottom) / 2, moreOrLessEquals((divider(tester).bottom + 873) / 2, epsilon: 0.5));

      await show(tester, _pictures.skin());
      final (dressedMessage, dressedRetry) = await measure();
      expect(find.byKey(const ValueKey('home-tab-art')), findsOneWidget);
      expect(headArt(), findsOneWidget);
      expect(dressedMessage, message);
      expect(dressedRetry, retry);
    });
  }

  group('the decode gate', () {
    void expectStockTop(WidgetTester tester) {
      expect(headArt(), findsNothing);
      expect(tabArt(), findsNothing);
      expect(recommendColour(tester), BiliColors.pink);
      expect(indicatorColour(tester), BiliColors.pink);
      expect(field(tester).decoration, isNull);
      expect(tester.widget<Divider>(find.byType(Divider).first).color, BiliColors.divider);
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    }

    Finder barArt() => find.byKey(const ValueKey('home-tab-art'));

    testWidgets('at launch the top and the bar stay stock until their pictures have decoded', (tester) async {
      imageCache
        ..clear()
        ..clearLiveImages();
      await show(tester, _pictures.skin(), load: false);
      await tester.pump();
      expectStockTop(tester);
      expect(barArt(), findsNothing);
      expect(find.byType(HomeTabIcon), findsNWidgets(HomeTab.values.length));
      for (var i = 0; i < 100 && (headArt().evaluate().isEmpty || barArt().evaluate().isEmpty); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(headArt(), findsOneWidget);
      expect(recommendColour(tester), const Color(0xFFFFFFFF));
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
      expect(barArt(), findsOneWidget);
    });

    for (final (name, skin) in [
      ('head_bg', () => _pictures.skin(headPicture: 'broken.png')),
      ('head_tab_bg', () => _pictures.skin(tabPicture: 'broken.png')),
    ]) {
      testWidgets("a $name that won't decode keeps the top stock, logged; the bar still dresses", (tester) async {
        final logs = MemorySink();
        Logger.shared.add(logs);
        addTearDown(() => Logger.shared.remove(logs));
        await show(tester, skin());
        await settle(tester);
        expectStockTop(tester);
        expect(barArt(), findsOneWidget);
        expect(
          logs.events.where((event) => event.msg == 'skin picture failed' && event.f['file']?.toJson() == 'broken.png'),
          isNotEmpty,
        );
      });
    }

    testWidgets("a tail_bg that won't decode keeps the bar stock under the dressed top", (tester) async {
      await show(tester, _pictures.skin(tail: 'broken.png'));
      await settle(tester);
      expect(headArt(), findsOneWidget);
      expect(barArt(), findsNothing);
      expect(find.byType(HomeTabIcon), findsNWidgets(HomeTab.values.length));
    });

    testWidgets('a picture failing as it draws drops the top back to stock, the bar dressed still', (tester) async {
      await show(tester, _pictures.skin());
      await settle(tester);
      final image = find.descendant(of: tabArt(), matching: find.byType(Image));
      tester.widget<Image>(image).errorBuilder!(tester.element(image), Exception('gone'), null);
      await tester.pump();
      await tester.pump();
      expectStockTop(tester);
      expect(barArt(), findsOneWidget);
    });
  });

  testWidgets('a looping svga in the bar plays, holds with no frame asked for while a page covers the shell, and goes '
      'on from there after the pop', (tester) async {
    final folder = Directory.systemTemp.createTempSync('bar_svga');
    addTearDown(() => folder.deleteSync(recursive: true));
    final movie = File('${folder.path}/tail_icon_selected_0.svga')
      ..writeAsBytesSync(
        movie2(
          width: 60,
          height: 45,
          frames: 5,
          images: {'pic': png(2, 2, 0xFFFF0000)},
          sprites: [
            sprite2('pic', [
              for (var i = 0; i < 5; i++) frame2(alpha: 1, layout: [i * 10.0, 0, 10, 10]),
            ]),
          ],
        ),
      );
    await tester.runAsync(() async => SvgaLoader.shared.load(movie));
    await show(
      tester,
      _pictures.skin(
        animated: {0},
        svga: movie,
        colors: SkinColors(
          color: standInColors.color,
          lightText: true,
          tailColor: standInColors.tailColor,
          tailColorSelected: standInColors.tailColorSelected,
          tailIconCycle: true,
        ),
      ),
    );
    await settle(tester);
    final view = find.descendant(
      of: find.byKey(const ValueKey('home-tab-home-skin'), skipOffstage: false),
      matching: find.byType(SvgaView, skipOffstage: false),
    );
    expect(tester.widget<SvgaView>(view).loop, isTrue);
    final paint = find.descendant(of: view, matching: find.byType(CustomPaint, skipOffstage: false));
    int frame() => (tester.widget<CustomPaint>(paint).painter! as SvgaPainter).frame.value;
    final playing = frame();
    await tester.pump(const Duration(milliseconds: 100));
    expect(frame(), (playing + 1) % 5);

    final navigator = Navigator.of(tester.element(find.byType(HomePage)));
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const ColoredBox(color: Color(0xFFFFFFFF)))));
    await settle(tester);
    final held = frame();
    await tester.pump(const Duration(seconds: 1));
    expect(frame(), held);
    expect(tester.binding.hasScheduledFrame, isFalse);

    navigator.pop();
    await tester.pump();
    expect(frame(), held);
    await settle(tester);
    final again = frame();
    await tester.pump(const Duration(milliseconds: 100));
    expect(frame(), (again + 1) % 5);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  group('on iOS', () {
    late Map<int, List<String>> sent;

    setUp(() {
      sent = {};
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        final arguments = call.arguments;
        if (call.method == 'create' && arguments is Map<Object?, Object?>) {
          if (arguments['viewType'] != SkinVideo.viewType) return null;
          final id = arguments['id']! as int;
          sent[id] = [];
          messenger.setMockMethodCallHandler(MethodChannel('${SkinVideo.viewType}/$id'), (call) async {
            sent[id]!.add(call.method);
            return null;
          });
        }
        return null;
      });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );

    testWidgets("我的's header video plays only while 我的 shows uncovered, and its header's controls take taps over it", (
      tester,
    ) async {
      await show(tester, _pictures.skin(video: File('/support/skin/head_myself_mp4_bg.mp4')));
      await settle(tester);
      expect(find.byType(SkinVideo, skipOffstage: false), findsOneWidget, reason: '我的 dressed behind 首页');
      final id = sent.keys.single;
      expect(sent[id], isEmpty, reason: 'behind 首页 a new view waits paused');

      Future<void> select(HomeTab tab) async {
        await tester.tap(find.byKey(ValueKey('home-tab-${tab.name}')));
        await settle(tester);
      }

      await select(HomeTab.mine);
      expect(sent[id], ['play']);
      await select(HomeTab.home);
      expect(sent[id], ['play', 'pause']);
      await select(HomeTab.mine);
      expect(sent[id], ['play', 'pause', 'play']);

      final navigator = Navigator.of(tester.element(find.byType(MePage)));
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const ColoredBox(color: Color(0xFFFFFFFF)))));
      await settle(tester);
      expect(sent[id], ['play', 'pause', 'play', 'pause']);
      navigator.pop();
      await settle(tester);
      expect(sent[id], ['play', 'pause', 'play', 'pause', 'play']);

      final cast = find.byKey(const ValueKey('me-cast'));
      expect(tester.getRect(find.byType(SkinVideo)).contains(tester.getCenter(cast)), isTrue);
      await tester.tap(cast);
      await tester.pump();
      expect(find.text('即将推出'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  /// The dressed screens as KaiC's iPhone draws them under the system font, against 110 (首页) and 109 (我的). With
  /// BILIFAST_SHOTS naming a folder outside the repo, the 3× shots are saved there for tools/screen_diff.py.
  for (final (selected, shot) in [(HomeTab.home, '110-home'), (HomeTab.mine, '109-me')]) {
    testWidgets('under the system font with a stand-in skin, ${selected.label} where $shot has it', (tester) async {
      await show(tester, _pictures.skin(), phone: true);
      await settle(tester, 40);
      if (selected == HomeTab.mine) {
        await tester.tap(find.byKey(const ValueKey('home-tab-mine')));
        await settle(tester);
        expect(
          tester.getRect(find.byKey(const ValueKey('me-skin-picture'))),
          const Rect.fromLTRB(0, 0, 440, 328),
          reason: "the shell's skin reaches 我的",
        );
      } else {
        expect(tester.getRect(headArt()), const Rect.fromLTRB(0, 0, 440, 106));
        expect(tester.getRect(find.byKey(const ValueKey('home-search'))), const Rect.fromLTRB(64, 67, 364, 101));
        expect(tester.getRect(find.byKey(const ValueKey('home-avatar'))).center.dy, 84);
      }
      expect(
        tester.getRect(find.byType(HomeTabBar)),
        const Rect.fromLTRB(0, 873 - HomeTabBarTheme.skinIconOverhang, 440, 956),
      );
      expect(tester.getRect(find.byKey(const ValueKey('home-tab-art'))), const Rect.fromLTRB(0, 873, 440, 956));
      for (final (i, tab) in HomeTab.values.indexed) {
        final box = tester.getRect(find.byKey(ValueKey('home-tab-${tab.name}-skin')));
        expect(box.center.dx, 44 + 88.0 * i, reason: tab.label);
        expect(
          box.center.dy,
          moreOrLessEquals(tab == HomeTab.post ? 873 + 88 / 3 : 873 + 19 / 3, epsilon: 0.01),
          reason: tab.label,
        );
      }

      final shots = Platform.environment['BILIFAST_SHOTS'];
      if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/$shot-skin-ours.png');
    });
  }
}
