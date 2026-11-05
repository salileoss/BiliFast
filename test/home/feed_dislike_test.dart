import 'dart:async';
import 'dart:io';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/app_auth.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/feed_dislike.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/feed_more_sheet.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/cover_preset.dart';
import 'package:bilifast/shared/remote_image.dart';
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

/// Not authorized; asking answers [grant] and is counted.
class _AskingAuth extends ChangeNotifier implements AppAuth {
  _AskingAuth({required this.grant});

  final bool grant;
  int requests = 0;

  @override
  bool authorized = false;

  @override
  DateTime? get expiresAt => null;

  @override
  Future<void> start() async {}

  @override
  Future<bool> request(BuildContext context) async {
    requests++;
    authorized = grant;
    return grant;
  }

  @override
  Future<bool> reauthorize(BuildContext context) => request(context);
}

/// Authorized while the client holds the token, until [drop]; asking is counted and gets nothing new. Like the app's,
/// it hears of the account before HomePage does, so 退出登录 drops the token just before the page hears of it.
class _HeldAuth extends ChangeNotifier implements AppAuth {
  _HeldAuth(this.environment) {
    environment.addListener(_accountChanged);
  }

  final AppEnvironment environment;
  int requests = 0;

  @override
  bool get authorized => environment.client.appToken != null;

  @override
  DateTime? get expiresAt => null;

  @override
  Future<void> start() async {}

  @override
  Future<bool> request(BuildContext context) async {
    requests++;
    return authorized;
  }

  @override
  Future<bool> reauthorize(BuildContext context) => request(context);

  void drop() {
    environment.client.appToken = null;
    notifyListeners();
  }

  void _accountChanged() {
    if (environment.account is LoggedOut && authorized) drop();
  }

  @override
  void dispose() {
    environment.removeListener(_accountChanged);
    super.dispose();
  }
}

/// 90, 91 and 92 against the official app: the official feed's cards, their ⋮ sheet, a card after 不感兴趣 and the
/// reasons sheet. With BILIFAST_SHOTS naming a folder outside the repo, the 3× shots are saved there.
void main() {
  late FeedHttp http;
  late AppEnvironment environment;

  setUp(() {
    // These follow the swap from the answer, as when it comes after FeedModel.minimumRefresh.
    HomePage.feedMinimumRefresh = Duration.zero;
    addTearDown(() => HomePage.feedMinimumRefresh = FeedModel.minimumRefresh);
    http = FeedHttp();
    http.officialPages[0] = [
      officialItem('BV1aaa', title: '真别选错！差距很大！'),
      officialItem('BV1bbb', title: '睡了一觉，我又变强了！？'),
      officialItem('BV1ccc', title: '一起感受下Fate的极致魅力吧'),
      officialItem('BV1ddd', title: '吾王', reasons: false),
    ];
    http.pages[1] = [feedItem('BV1web')];
  });

  /// 首页 at 3× as KaiC's iPhone, on the official feed unless [token] is false, with [auth] (or [authFor]'s, made once
  /// the environment is) as the app token's. [reloads] stands in for the bar's 首页 taps.
  Future<void> show(
    WidgetTester tester, {
    AppAuth? auth,
    AppAuth Function(AppEnvironment environment)? authFor,
    bool token = true,
    bool systemFont = false,
    Listenable? reloads,
  }) async {
    if (systemFont) {
      final saved = BiliFonts.family;
      addTearDown(() => BiliFonts.family = saved);
      await tester.runAsync(loadSystemFontStandIns);
    }
    showAsPhone(tester);
    final logger = Logger(session: 'test');
    environment = await AppEnvironment.load(
      keychain: FakeKeychain(StoredCookies(Canned.cookies)),
      http: http,
      logger: logger,
    );
    if (token) environment.client.appToken = fakeAppToken;
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
      appAuth: auth ?? authFor?.call(environment) ?? FakeAppAuth(),
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

  Finder card(String bvid) => find.byKey(ValueKey('feed-card-$bvid'));

  Finder more(String bvid) => find.descendant(of: card(bvid), matching: find.byKey(const ValueKey('big-card-more')));

  Future<void> openMore(WidgetTester tester, String bvid) async {
    final feed = tester.getRect(find.byKey(const ValueKey('feed')));
    if (!feed.contains(tester.getCenter(more(bvid)))) {
      await Scrollable.ensureVisible(tester.element(card(bvid)));
      await settle(tester);
    }
    await tester.tap(more(bvid));
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots == null) return;
    await saveShot(tester, find.byKey(_screen), '$shots/$name');
  }

  testWidgets("an official card's ⋮ offers 稍后再看 and both 不感兴趣; one without reasons only 稍后再看", (tester) async {
    await show(tester);
    await openMore(tester, 'BV1aaa');
    expect(find.text('添加至稍后再看'), findsOneWidget);
    expect(find.text('不感兴趣：当前视频'), findsOneWidget);
    expect(find.text('不感兴趣：UP'), findsOneWidget);
    await tester.tapAt(const Offset(220, 300));
    await settle(tester);
    expect(find.byType(FeedSheetRow), findsNothing);

    await tester.scrollUntilVisible(more('BV1ddd'), 100, scrollable: find.byType(Scrollable).first);
    await openMore(tester, 'BV1ddd');
    expect(find.byType(FeedSheetRow), findsOneWidget);
    expect(find.textContaining('不感兴趣'), findsNothing);
  });

  testWidgets('不感兴趣：当前视频 turns the card over, 撤销 brings it back, each sent once', (tester) async {
    StoredNetworkImage coverIn(Finder within) => tester
        .widgetList<Image>(find.descendant(of: within, matching: find.byType(Image)))
        .map((image) => image.image)
        .whereType<StoredNetworkImage>()
        .single;

    await show(tester);
    final live = coverIn(card('BV1aaa'));
    expect(live.url, 'https://i1.hdslb.com/bfs/archive/BV1aaa.jpg@1224w_689h_1c_90q.jpg');
    expect(live.box, const Size(1224, 689), reason: "211 pt's box at 3x");
    await openMore(tester, 'BV1aaa');
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
    expect(find.byType(FeedSheetRow), findsNothing);
    final turned = find.descendant(of: card('BV1aaa'), matching: find.byType(FeedDislikedCard));
    expect(turned, findsOneWidget);
    expect(coverIn(turned), live, reason: "the blurred cover is the card's own download");
    expect(find.text('已减少此类内容推荐'), findsOneWidget);
    expect(http.dislikes.single['reason_id'], '1');

    await tester.tap(find.byKey(const ValueKey('feed-disliked-undo')));
    await settle(tester);
    expect(find.byType(FeedDislikedCard), findsNothing);
    expect(http.cancels, hasLength(1));
  });

  group("while a refresh's call is out", () {
    late ValueNotifier<int> reloads;
    late Completer<void> answer;

    setUp(() => reloads = ValueNotifier(0));

    tearDown(() => reloads.dispose());

    Finder going(String bvid) => find.byKey(ValueKey('feed-card-going-$bvid'));

    Finder turnedOver(Finder slot) => find.descendant(of: slot, matching: find.byType(FeedDislikedCard));

    /// A refresh by the bar's 首页 whose call is out, its answer held. Not a pull: while the list springs back it
    /// takes no taps.
    Future<void> refreshHeld(WidgetTester tester) async {
      http.officialPages[0] = [for (var i = 0; i < 4; i++) officialItem('BV1new$i')];
      answer = http.officialGates[0] = Completer<void>();
      final asked = http.officialAsked.length;
      reloads.value++;
      for (var i = 0; i < 20 && http.officialAsked.length == asked; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(http.officialAsked, hasLength(asked + 1), reason: 'the refresh is out');
    }

    Future<void> frames(WidgetTester tester, int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
    }

    /// The answer in, then 1 ms frames until the old card [bvid] is fading out over the new one.
    Future<void> handOff(WidgetTester tester, String bvid) async {
      answer.complete();
      for (var i = 0; i < 20 && going(bvid).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(going(bvid), findsOneWidget, reason: 'the hand-off has begun');
    }

    testWidgets('a 不感兴趣 made meanwhile stays on the card as it fades out', (tester) async {
      await show(tester, reloads: reloads);
      await openMore(tester, 'BV1aaa');
      await refreshHeld(tester);
      await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
      await frames(tester, 3);
      expect(card('BV1new0'), findsNothing, reason: 'still waiting on the answer');
      expect(turnedOver(card('BV1aaa')), findsOneWidget);

      await handOff(tester, 'BV1aaa');
      await tester.pump(const Duration(milliseconds: 60));
      expect(going('BV1aaa'), findsOneWidget);
      expect(turnedOver(going('BV1aaa')), findsOneWidget, reason: 'it fades out as the user left it');
      expect(turnedOver(card('BV1new0')), findsOneWidget, reason: 'only the going card is turned over');
      await settle(tester, 10);
      expect(find.byType(FeedDislikedCard), findsNothing);
      expect(http.dislikes, hasLength(1));
    });

    testWidgets('a 撤销 made meanwhile brings the card back before it fades out', (tester) async {
      await show(tester, reloads: reloads);
      await openMore(tester, 'BV1aaa');
      await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
      await settle(tester);
      expect(turnedOver(card('BV1aaa')), findsOneWidget);

      await refreshHeld(tester);
      await tester.tap(find.byKey(const ValueKey('feed-disliked-undo')));
      await frames(tester, 3);
      expect(card('BV1new0'), findsNothing, reason: 'still waiting on the answer');
      expect(find.descendant(of: card('BV1aaa'), matching: find.byKey(const ValueKey('feed-card-live'))), findsOne);
      expect(http.cancels, hasLength(1));

      await handOff(tester, 'BV1aaa');
      await tester.pump(const Duration(milliseconds: 60));
      expect(going('BV1aaa'), findsOneWidget);
      expect(turnedOver(going('BV1aaa')), findsNothing, reason: 'the card fading out is the one taken back');
      expect(turnedOver(card('BV1new0')), findsNothing);
      await settle(tester, 10);
      expect(http.cancels, hasLength(1));
    });
  });

  testWidgets("不感兴趣：UP sends the uploader's reason", (tester) async {
    await show(tester);
    await openMore(tester, 'BV1bbb');
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-uploader')));
    await settle(tester);
    expect(http.dislikes.single['reason_id'], '4');
    expect(find.descendant(of: card('BV1bbb'), matching: find.byType(FeedDislikedCard)), findsOneWidget);
  });

  testWidgets('选择不感兴趣原因 opens the tiles and 该内容已推荐过; a pick sends its feedback id and the card stays', (tester) async {
    await show(tester);
    await openMore(tester, 'BV1aaa');
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('feed-disliked-reasons')));
    await settle(tester);
    expect(find.text('不感兴趣原因'), findsOneWidget);
    for (final (_, name) in officialFeedbacks.take(8)) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('feed-reason-repeated')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('feed-reason-13')));
    await settle(tester);
    expect(find.text('不感兴趣原因'), findsNothing);
    expect(http.dislikes.last['feedback_id'], '13');
    expect(find.byType(FeedDislikedCard), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('feed-disliked-reasons')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('feed-reason-repeated')));
    await settle(tester);
    expect(http.dislikes.last['feedback_id'], '19');
  });

  testWidgets('a refused 不感兴趣 turns the card back with a toast', (tester) async {
    http.dislikeCode = -400;
    await show(tester);
    await openMore(tester, 'BV1aaa');
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
    expect(find.byType(FeedDislikedCard), findsNothing);
    expect(find.text('B 站返回错误 -400：请求错误'), findsOneWidget);
    await settle(tester, 60);
  });

  for (final code in [-101, -2]) {
    testWidgets('a 不感兴趣 whose token is turned down ($code) turns the card back and asks for the confirm, no 需要登录', (
      tester,
    ) async {
      http.dislikeCode = code;
      late _HeldAuth auth;
      await show(tester, authFor: (environment) => auth = _HeldAuth(environment));
      await openMore(tester, 'BV1aaa');
      await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
      await settle(tester);
      expect(http.dislikes, hasLength(1));
      expect(find.byType(FeedDislikedCard), findsNothing);
      expect(card('BV1aaa'), findsOneWidget);
      expect(auth.requests, 1);
      expect(find.text('需要登录'), findsNothing);
      expect(find.textContaining('B 站返回错误'), findsNothing);
    });
  }

  testWidgets('撤销 whose token is turned down keeps the card over and asks for the confirm', (tester) async {
    late _HeldAuth auth;
    await show(tester, authFor: (environment) => auth = _HeldAuth(environment));
    await openMore(tester, 'BV1aaa');
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
    http.dislikeCode = -101;
    await tester.tap(find.byKey(const ValueKey('feed-disliked-undo')));
    await settle(tester);
    expect(http.cancels, hasLength(1));
    expect(find.byType(FeedDislikedCard), findsOneWidget);
    expect(auth.requests, 1);
    expect(find.text('需要登录'), findsNothing);
  });

  testWidgets('without the token 不感兴趣 asks for the confirm first, and sends nothing when it is refused', (
    tester,
  ) async {
    final refused = _AskingAuth(grant: false);
    await show(tester, auth: refused);
    await openMore(tester, 'BV1aaa');
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
    expect(refused.requests, 1);
    expect(http.dislikes, isEmpty);
    expect(find.byType(FeedDislikedCard), findsNothing);
  });

  testWidgets('a confirm given there goes on to send it', (tester) async {
    final granted = _AskingAuth(grant: true);
    await show(tester, auth: granted);
    await openMore(tester, 'BV1aaa');
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
    expect(granted.requests, 1);
    expect(http.dislikes, hasLength(1));
  });

  testWidgets('without the token 推荐 is the website’s, and its ⋮ has no 不感兴趣', (tester) async {
    await show(tester, token: false);
    expect(http.officialAsked, isEmpty);
    await openMore(tester, 'BV1web');
    expect(find.byType(FeedSheetRow), findsOneWidget);
  });

  testWidgets('a token that arrives later brings the official 推荐', (tester) async {
    final auth = FakeAppAuth(authorized: false);
    await show(tester, auth: auth, token: false);
    expect(card('BV1web'), findsOneWidget);
    environment.client.appToken = fakeAppToken;
    await auth.request(tester.element(find.byType(HomePage)));
    await settle(tester, 20);
    expect(http.officialAsked.first, 0, reason: 'a refresh, then the short page asks on');
    expect(card('BV1aaa'), findsOneWidget);
    expect(card('BV1web'), findsNothing);
  });

  testWidgets("a token lost under the official 推荐 brings the website's in its place", (tester) async {
    late _HeldAuth auth;
    await show(tester, authFor: (environment) => auth = _HeldAuth(environment));
    expect(card('BV1aaa'), findsOneWidget);
    expect(http.asked, isEmpty);
    final officialAsks = http.officialAsked.length;
    auth.drop();
    await settle(tester, 20);
    expect(http.asked.first, 1, reason: 'a refresh, then the short page asks on');
    expect(http.officialAsked, hasLength(officialAsks));
    expect(card('BV1web'), findsOneWidget);
    expect(card('BV1aaa'), findsNothing);
  });

  testWidgets("a token lost under the website's 推荐 changes nothing", (tester) async {
    http.officialCode = -101;
    late _HeldAuth auth;
    await show(tester, authFor: (environment) => auth = _HeldAuth(environment));
    expect(card('BV1web'), findsOneWidget, reason: 'the official feed refused the token');
    final asked = List.of(http.asked);
    auth.drop();
    await settle(tester, 20);
    expect(http.asked, asked);
    expect(card('BV1web'), findsOneWidget);
  });

  testWidgets('退出登录 under the official 推荐 refreshes it once, for the logout and the token both', (tester) async {
    // The logout empties the jar, so the fingerprint cookies are fetched again.
    http.canned.routes['/x/frontend/finger/spi'] = (200, '{"code":0,"message":"ok","data":{"b_3":"B3","b_4":"B4"}}');
    await show(tester, authFor: _HeldAuth.new);
    expect(card('BV1aaa'), findsOneWidget);
    await environment.logout();
    await settle(tester, 20);
    expect(environment.client.appToken, isNull);
    expect(http.asked.where((index) => index == 1), hasLength(1));
    expect(card('BV1web'), findsOneWidget);
    expect(card('BV1aaa'), findsNothing);
  });

  testWidgets('the sheet, the turned-over card and the reasons are buttons by name', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    await openMore(tester, 'BV1aaa');
    expect(find.bySemanticsLabel('不感兴趣：当前视频'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
    expect(find.bySemanticsLabel('撤销'), findsOneWidget);
    expect(find.bySemanticsLabel('选择不感兴趣原因'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets("the turned-over card's blurred cover names 推荐's preset, as the card's does", (tester) async {
    await show(tester);
    await openMore(tester, 'BV1aaa');
    await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
    await settle(tester);
    final cover = tester.widget<RemoteImage>(
      find.descendant(of: find.byType(FeedDislikedCard), matching: find.byType(RemoteImage)),
    );
    expect((cover.cover, cover.preset), (true, CoverPreset.player));
  });

  group('look-alike under the system font', () {
    testWidgets("90: the ⋮ sheet's cards, rows and words where the official app has them", (tester) async {
      await show(tester, systemFont: true);
      await openMore(tester, 'BV1aaa');
      final watchLater = tester.getRect(find.byKey(const ValueKey('feed-more-watch-later')));
      expect(watchLater, const Rect.fromLTRB(16, 734, 424, 786));
      expect(tester.getRect(find.byKey(const ValueKey('feed-more-dislike-video'))).top, 802);
      expect(tester.getRect(find.byKey(const ValueKey('feed-more-dislike-uploader'))).bottom, 906);
      expect(tester.getTopLeft(find.text('添加至稍后再看')).dx, 60);
      await shot(tester, '90-feed-more-menu-ours.png');
    });

    testWidgets('91: the card after 不感兴趣', (tester) async {
      await show(tester, systemFont: true);
      await openMore(tester, 'BV1aaa');
      await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
      await settle(tester);
      expect(find.byType(FeedDislikedCard), findsOneWidget);
      await shot(tester, '91-feed-dislike-card-ours.png');
    });

    testWidgets('92: the reasons sheet', (tester) async {
      await show(tester, systemFont: true);
      await openMore(tester, 'BV1aaa');
      await tester.tap(find.byKey(const ValueKey('feed-more-dislike-video')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('feed-disliked-reasons')));
      await settle(tester);
      final first = tester.getRect(find.byKey(const ValueKey('feed-reason-11')));
      expect(first, const Rect.fromLTRB(16, 696, 112, 763));
      expect(tester.getRect(find.byKey(const ValueKey('feed-reason-repeated'))).top, 854);
      await shot(tester, '92-feed-dislike-reasons-ours.png');
    });
  });
}

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
