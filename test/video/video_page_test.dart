import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bili_core/api.dart'
    show
        Comment,
        CommentMember,
        CommentSort,
        CommentPicture,
        FeedCard,
        OfficialKind,
        RichRun,
        SpaceVideo,
        TextRun,
        UploaderCard,
        BiliError,
        VideoCard,
        VideoDetail,
        VideoOwner,
        VideoRelation,
        VideoStat;
import 'package:bili_core/api.dart' as core show VideoPage, VideoView;
import 'package:bili_core/danmaku.dart' show DisplayDanmaku;
import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart' show EngineSnapshot, PlaybackMode;
import 'package:bili_core/shared.dart';
import 'package:bilifast/account/app_auth.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/account/login_gate.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/app/route_observer.dart';
import 'package:bilifast/app/swipe_back_route.dart';
import 'package:bilifast/comments/comment_overlays.dart';
import 'package:bilifast/comments/comment_row.dart';
import 'package:bilifast/comments/comments_model.dart';
import 'package:bilifast/comments/comments_tab.dart';
import 'package:bilifast/comments/composer.dart';
import 'package:bilifast/comments/picture_viewer.dart';
import 'package:bilifast/comments/thread_view.dart';
import 'package:bilifast/danmaku/danmaku_overlays.dart';
import 'package:bilifast/danmaku/danmaku_layer.dart';
import 'package:bilifast/device/device_controls.dart';
import 'package:bilifast/device/orientation.dart';
import 'package:bilifast/device/player_device.dart';
import 'package:bilifast/home/feed_card.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/playback/overlay_stats.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/player/bili_player.dart';
import 'package:bilifast/player/playback_clock.dart';
import 'package:bilifast/player_ui/end_screen_landscape.dart';
import 'package:bilifast/player_ui/end_screen_portrait.dart';
import 'package:bilifast/player_ui/landscape_chrome.dart';
import 'package:bilifast/player_ui/panels/panel_controller.dart';
import 'package:bilifast/player_ui/panels/panel_layer.dart';
import 'package:bilifast/player_ui/player_loading.dart';
import 'package:bilifast/player_ui/player_ui.dart';
import 'package:bilifast/player_ui/portrait_controls.dart';
import 'package:bilifast/player_ui/vertical_chrome.dart';
import 'package:bilifast/shared/cover_preset.dart';
import 'package:bilifast/shared/image_disk_cache.dart';
import 'package:bilifast/shared/remote_image.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/space/fake_space_api.dart';
import 'package:bilifast/space/space_api.dart';
import 'package:bilifast/space/uploader_sheet.dart';
import 'package:bilifast/space/uploader_sheet_grid.dart';
import 'package:bilifast/space/uploader_tap.dart';
import 'package:bilifast/video/actions/action_overlays.dart';
import 'package:bilifast/video/actions/actions_model.dart';
import 'package:bilifast/video/actions/coin_dialog.dart';
import 'package:bilifast/video/actions/favourite_sheet.dart';
import 'package:bilifast/video/actions/video_actions.dart';
import 'package:bilifast/video/collapsing_player.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:bilifast/video/intro/intro_tab.dart';
import 'package:bilifast/video/intro/uploader_row.dart';
import 'package:bilifast/video/page_api.dart';
import 'package:bilifast/video/page_details.dart';
import 'package:bilifast/video/page_details_model.dart';
import 'package:bilifast/video/page_session.dart';
import 'package:bilifast/video/page_tabs.dart';
import 'package:bilifast/video/player_prefs.dart';
import 'package:bilifast/video/player_session.dart';
import 'package:bilifast/video/video_page.dart';
import 'package:bilifast/video/video_player_area.dart';
import 'package:bilifast/video/video_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../home/feed_fakes.dart' show feedItem;
import '../playback/fakes.dart';
import '../support/fake_player.dart';
import '../support/fake_player_session.dart';
import '../support/fake_video_actions.dart';
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';
import 'intro/intro_tab_test.dart' as intro_fixture show detail, card;

const heartbeatPath = '/x/click-interface/web/heartbeat';
const bv = 'BV1GJ411x7h7';
const p1 = 137649199;
const p2 = 137649200;
const cover = 'https://i0.hdslb.com/bfs/archive/cover.jpg';

/// iPhone 17 Pro Max in points, with its safe areas, as the official app's reference screenshots were taken.
const portrait = Size(440, 956);
const landscape = Size(956, 440);
const portraitInsets = FakeViewPadding(top: 62, bottom: 34);
const landscapeInsets = FakeViewPadding(left: 62, right: 62, bottom: 21);

/// Records each page's begin and end, naming pages in the order they first began.
class SpyOrientation extends OrientationController {
  final log = <String>[];
  final _names = <Object, String>{};

  String _name(Object owner) => _names.putIfAbsent(owner, () => 'page${_names.length + 1}');

  @override
  void begin(Object owner, {required bool videoIsVertical}) {
    log.add('begin ${_name(owner)}${videoIsVertical ? ' vertical' : ''}');
    super.begin(owner, videoIsVertical: videoIsVertical);
  }

  @override
  void end(Object owner) {
    log.add('end ${_name(owner)}');
    super.end(owner);
  }
}

/// The login page as the page asks for it: each ask with the presentation and the screen at that moment, answered when
/// the test says.
class FakeLoginGate implements LoginGate {
  FakeLoginGate(this.orientation);

  final OrientationController orientation;
  final asks = <({Presentation presentation, Size screen})>[];
  Completer<bool>? _open;

  /// Runs as the gate answers true, as the login page sets the account before it pops.
  VoidCallback? onLogin;

  /// Thrown by the next ask instead of showing the page.
  Object? failure;

  bool get open => _open != null;

  @override
  Future<bool> request(BuildContext context) {
    asks.add((presentation: orientation.presentation, screen: MediaQuery.sizeOf(context)));
    if (failure case final failure?) throw failure;
    return (_open = Completer<bool>()).future;
  }

  void answer(bool loggedIn) {
    if (loggedIn) onLogin?.call();
    final open = _open!;
    _open = null;
    open.complete(loggedIn);
  }
}

/// The app token's confirm, answered at once with [grants]; each ask notes whether it had a context to show in.
class _RecordingAppAuth extends ChangeNotifier implements AppAuth {
  _RecordingAppAuth({this.grants = true});

  @override
  bool authorized = false;
  bool grants;
  final asks = <bool>[];

  @override
  DateTime? get expiresAt => null;

  @override
  Future<void> start() async {}

  @override
  Future<bool> request(BuildContext context) async {
    asks.add(context.mounted);
    if (grants) authorized = true;
    return grants;
  }

  @override
  Future<bool> reauthorize(BuildContext context) => request(context);
}

void main() {
  late CannedHttp http;
  late ManualClock time;
  late AppEnvironment environment;

  /// Every controller started, each with a player of its own: the one a test's own start hands out, then each page's.
  late List<PlaybackController> controllers;

  /// The newest controller and its player: the top page's once its own has started.
  late PlaybackController controller;
  late FakePlayer player;
  late AppPlayback playback;
  late AppServices services;
  late GlobalKey<NavigatorState> nav;
  late SpyOrientation orientation;
  late FakeLoginGate gate;
  late RecentStore recents;

  /// Each page's session and the open it was handed, in the order the pages made them.
  late List<FakePlayerSession> sessions;
  late List<SessionOpen> sessionOpens;

  /// Each page's details, in the order the pages made them.
  late List<FakePageDetails> detailsMade;

  /// The newest page's login ask and its count of logins, as its session and details were handed them.
  VoidCallback? askLogin;
  Listenable? pageLogins;
  late FakePageDetails Function() makeDetails;

  setUp(() {
    http = Canned.http()..routes[heartbeatPath] = (200, '{"code":0,"message":"0"}');
    controllers = [];
    time = ManualClock(10000);
    nav = GlobalKey<NavigatorState>();
    orientation = SpyOrientation();
    gate = FakeLoginGate(orientation);
    sessions = [];
    sessionOpens = [];
    detailsMade = [];
    makeDetails = FakePageDetails.new;
    askLogin = null;
    pageLogins = null;
  });

  PlayerSession fakeSession({
    required PlaybackController controller,
    required AppServices services,
    required SessionOpen open,
    required void Function(double seconds) onSeeked,
    required VoidCallback requestLogin,
    required VoidCallback willPlay,
  }) {
    final session = FakePlayerSession(player: controller.player as FakePlayer);
    sessions.add(session);
    sessionOpens.add(open);
    askLogin = requestLogin;
    return session;
  }

  void screen(WidgetTester tester, Size size, FakeViewPadding insets) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = insets;
    tester.view.viewPadding = insets;
  }

  Future<void> host(
    WidgetTester tester, {
    Widget home = const SizedBox(),
    Future<PlaybackController> Function()? start,
    bool checkAccount = true,
    bool loggedIn = true,
    PageApi? pageApi,
    SpaceApi? spaceApi,
    AppAuth? appAuth,
    ValueNotifier<ThemeMode>? appearance,
    bool systemFont = false,
  }) async {
    screen(tester, portrait, portraitInsets);
    addTearDown(tester.view.reset);
    final logger = Logger(session: 'test');
    environment = await AppEnvironment.load(
      keychain: FakeKeychain(loggedIn ? const StoredCookies(Canned.cookies) : const NoStoredCookies()),
      http: http,
      logger: logger,
    );
    if (checkAccount) await environment.refreshAccount();
    final now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 1000) * 1000);
    PlaybackController make() {
      player = FakePlayer();
      controller = PlaybackController(
        client: environment.client,
        engine: FakeEngine(),
        player: player,
        clock: time.clock,
        now: () => now,
        startTimer: FakeTimers().start,
        logger: logger,
      );
      controllers.add(controller);
      return controller;
    }

    make();
    playback = AppPlayback(start ?? () async => make());
    addTearDown(playback.dispose);
    services = AppServices(
      environment: environment,
      playback: playback,
      recents: recents = await RecentStore.load(null, logger: logger),
      device: PlayerDevice(orientation: orientation, controls: NoDeviceControls()),
      pageApi: pageApi,
      spaceApi: spaceApi,
      appAuth: appAuth,
      loginGate: gate,
      fonts: systemFont ? (FontStore.memory()..select(FontChoice.system)) : null,
    );
    // The small window's restore button pushes on the app's navigator.
    nav = services.navigator;
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: appearance ?? const AlwaysStoppedAnimation(ThemeMode.light),
        builder: (context, _) => MaterialApp(
        theme: appearance == null ? null : biliTheme(Brightness.light),
        darkTheme: appearance == null ? null : biliTheme(Brightness.dark),
        themeMode: appearance?.value,
        themeAnimationDuration: Duration.zero,
        navigatorKey: nav,
        navigatorObservers: [pageRoutes],
        builder: (context, child) => AppScope(services: services,
          child: RepaintBoundary(key: const ValueKey('appearance-boundary'), child: child!)),
        home: home,
        ),
      ),
    );
  }

  Future<void> frames(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  PageDetails fakeDetails({
    required PlayerSession session,
    required AppServices services,
    required void Function(String message) toast,
    required VoidCallback requestLogin,
    required Listenable logins,
  }) {
    final details = makeDetails();
    detailsMade.add(details);
    pageLogins = logins;
    return details;
  }

  late VideoPageOpener openPage;

  Widget page(VideoRoute route) =>
      VideoPage(route: route, createSession: fakeSession, createDetails: fakeDetails, openPage: openPage);

  /// openVideoPage's push, with the test's session and details: a page stacked over another, as a space's video is.
  Future<void> pushing(BuildContext context, VideoRoute route) =>
      Navigator.of(context).push(SwipeBackPageRoute<void>(builder: (_) => page(route)));
  openPage = pushing;

  /// The page's own opener, replaceVideoPage, with the test's session and details, until the test ends.
  void replaceOnOpen() {
    openPage = (context, route) => replaceVideoPage(context, route, page: page);
    addTearDown(() => openPage = pushing);
  }

  void pushVideo(VideoRoute route) =>
      unawaited(nav.currentState!.push(SwipeBackPageRoute<void>(builder: (_) => page(route))));

  /// The top page's back, as the chrome's arrow and the system's back both pop it.
  Future<void> back(WidgetTester tester) async {
    unawaited(nav.currentState!.maybePop());
    await frames(tester, 20);
  }

  void position(double seconds) {
    time.advance(PlaybackClock.jumpSettleMs);
    player.emit(PositionChanged(seconds: seconds, hostMs: time.clock.nowMs(), rate: 1));
  }

  /// Each heartbeat as (cid, played_time).
  List<(int, String)> sent() => [
    for (final request in http.to(heartbeatPath))
      (
        int.parse(Uri.splitQueryString(utf8.decode(request.body!))['cid']!),
        Uri.splitQueryString(utf8.decode(request.body!))['played_time']!,
      ),
  ];

  List<String> heartbeats() => [for (final (_, played) in sent()) played];

  /// The player interface the top page handed its chrome and panels.
  PlayerUi ui(WidgetTester tester) => tester.widget<PanelLayer>(find.byType(PanelLayer).last).ui;

  Rect area(WidgetTester tester) => tester.getRect(find.byType(VideoPlayerArea).last);

  /// A page with its video loaded and known to the session, so it has taken the orientation.
  Future<void> opened(WidgetTester tester, {bool vertical = false, int page = 0}) async {
    await frames(tester, 20);
    sessions[page]
      ..video = controller.video
      ..isVertical = vertical
      ..changed();
    await tester.pump();
  }

  Future<void> rotate(WidgetTester tester, Presentation to) async {
    switch (to) {
      case Presentation.inline:
        screen(tester, portrait, portraitInsets);
        orientation.exitToInline();
      case Presentation.landscape:
        screen(tester, landscape, landscapeInsets);
        orientation.enterLandscape();
      case Presentation.vertical:
        screen(tester, portrait, portraitInsets);
        orientation.enterVertical();
    }
    await frames(tester, 2);
    // The player grows into its new place once the screen has turned.
    await tester.pump(RotationTheme.grow);
  }

  testWidgets('appearance updates an open video without recreating its player or session', (tester) async {
    final appearance = ValueNotifier(ThemeMode.light);
    addTearDown(appearance.dispose);
    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) {
      final previousFont = BiliFonts.family;
      BiliFonts.family = BiliFonts.system;
      addTearDown(() => BiliFonts.family = previousFont);
      await tester.runAsync(() async {
        await loadSystemFontStandIns();
        await loadIconFonts();
      });
    }
    await host(tester, appearance: appearance, systemFont: shots != null,
      pageApi: shots == null ? null : (FakePageApi.demo()..delay = Duration.zero));
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await opened(tester);
    final session = sessions.single;
    if (shots != null) {
      session
        ..detail = intro_fixture.detail()
        ..title = intro_fixture.detail().title
        ..related = [intro_fixture.card('BV1x'), intro_fixture.card('BV1y')]
        ..changed();
      detailsMade.single
        ..actions = FakeVideoActions()
        ..uploader = const UploaderCard(mid: 1, name: '星宇动漫社', face: '', fans: 475000, videos: 410,
          isVip: false, following: false, official: OfficialKind.person)
        ..changed();
      player.emit(const StatusChanged(PlayerStatus.paused));
      await frames(tester, 8);
    }
    final playingController = controller;
    final playingPlayer = player;
    final activeUi = ui(tester);
    final requests = sessionOpens.length;
    appearance.value = ThemeMode.dark;
    await frames(tester, 2);
    expect(BiliPalette.of(tester.element(find.byType(VideoPage))).isDark, isTrue);
    expect(sessions.single, same(session));
    expect(controller, same(playingController));
    expect(player, same(playingPlayer));
    expect(ui(tester), same(activeUi));
    expect(sessionOpens, hasLength(requests));
    expect(tester.takeException(), isNull);
    if (shots != null) {
      await frames(tester, 8);
      await saveShot(tester, find.byKey(const ValueKey('appearance-boundary')), '$shots/video-intro-dark.png');
      activeUi.panels.open(PlayerPanel.more);
      await frames(tester, 14);
      await saveShot(tester, find.byKey(const ValueKey('appearance-boundary')), '$shots/video-sheet-dark.png');
      activeUi.panels.close();
      await frames(tester, 14);
      await tester.tap(find.byKey(const ValueKey('tab-comments')));
      await frames(tester, 14);
      await saveShot(tester, find.byKey(const ValueKey('appearance-boundary')), '$shots/video-comments-dark.png');
    }
    await back(tester);
  });

  testWidgets('S7 重试 after a failed open plays, and back still gives the player back', (tester) async {
    http.routes[Canned.playUrlPath] = (500, '');
    await host(tester);
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await frames(tester, 20);
    expect(find.byKey(const ValueKey('video-retry')), findsOneWidget);
    http.routes[Canned.playUrlPath] = (200, Canned.playUrl());
    await tester.tap(find.byKey(const ValueKey('video-retry')));
    await frames(tester, 20);
    expect(controller.phase, isNot(PlaybackPhase.failed));
    expect(player.loaded, isNotNull);
    expect(sessions, hasLength(1), reason: 'one session per page, through 重试');
    await back(tester);
    expect(controller.video, isNull);
  });

  testWidgets('S8 back reports where playback stopped', (tester) async {
    await host(tester);
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await frames(tester, 20);
    player.emit(const StatusChanged(PlayerStatus.playing));
    position(10);
    await back(tester);
    expect(heartbeats(), ['0', '10'], reason: 'leave() runs before close() clears the video');
  });

  testWidgets('S8b a login Bilibili no longer accepts reports nothing', (tester) async {
    http = Canned.http(loggedIn: false)..routes[heartbeatPath] = (200, '{"code":0}');
    await host(tester);
    expect(environment.account, isA<LoginExpired>());
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await frames(tester, 20);
    player.emit(const StatusChanged(PlayerStatus.playing));
    await back(tester);
    expect(heartbeats(), isEmpty);
  });

  const recent = RecentVideo(bvid: bv, cid: p1, title: '测试视频', part: '第一集', page: 1, pageCount: 2, duration: 712);

  testWidgets('a login Bilibili no longer accepts still records 最近打开\'s progress, with no heartbeats',
      (tester) async {
    http = Canned.http(loggedIn: false)..routes[heartbeatPath] = (200, '{"code":0}');
    await host(tester);
    expect(environment.account, isA<LoginExpired>());
    recents.add(recent);
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await frames(tester, 20);
    player.emit(const StatusChanged(PlayerStatus.playing));
    position(30);
    await back(tester);
    expect(recents.items.single.progress, 30);
    expect(heartbeats(), isEmpty);
  });

  testWidgets('played to the end, 最近打开\'s progress is the part\'s length, and stays so after back', (tester) async {
    await host(tester);
    recents.add(recent);
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await frames(tester, 20);
    player.emit(const StatusChanged(PlayerStatus.playing));
    position(700);
    player.emit(const StatusChanged(PlayerStatus.ended));
    await frames(tester, 4);
    expect(recents.items.single.progress, 712);
    await back(tester);
    expect(recents.items.single.progress, 712);
    expect(heartbeats().last, '-1');
  });

  testWidgets('heartbeats go out while the launch account check failed with a session in the jar', (tester) async {
    http.routes[Canned.navPath] = (500, '');
    await host(tester);
    expect(environment.account, isA<AccountUnknown>());
    // Back for the WBI keys the view and playurl calls sign with; the account stays unknown.
    http.routes[Canned.navPath] = (200, Canned.navLoggedIn);
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await frames(tester, 20);
    player.emit(const StatusChanged(PlayerStatus.playing));
    position(10);
    await back(tester);
    expect(heartbeats(), ['0', '10']);
  });

  testWidgets('S15 a video page gone before the player started opens nothing', (tester) async {
    final ready = Completer<PlaybackController>();
    await host(tester, start: () => ready.future);
    pushVideo(const VideoRoute(bvid: bv));
    await frames(tester);
    expect(find.byKey(const ValueKey('video-back')), findsOneWidget, reason: 'no chrome yet, so the page has its own');
    await tester.tap(find.byKey(const ValueKey('video-back')));
    await frames(tester, 20);
    expect(find.byType(VideoPage), findsNothing);
    ready.complete(controller);
    await frames(tester);
    expect(controller.opens, 0);
    expect(sessions, isEmpty);
    expect(http.to(Canned.signedViewPath), isEmpty);
  });

  testWidgets('a page popped while its video opens plays nothing', (tester) async {
    http.gates[Canned.playUrlPath] = Completer<void>();
    await host(tester);
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await frames(tester);
    expect(controller.video?.bvid, bv, reason: 'the view is in; playurl is held');
    unawaited(nav.currentState!.maybePop());
    await tester.pump();
    expect(controller.video, isNull, reason: 'the player is given back at the pop, not after the transition');
    http.gates[Canned.playUrlPath]!.complete();
    await frames(tester, 20);
    expect(player.loaded, isNull);
    expect(controller.phase, PlaybackPhase.idle);
  });

  testWidgets('重试 starts the player again after a failed start, then plays', (tester) async {
    final failing = Completer<PlaybackController>();
    var attempts = 0;
    await host(tester, start: () => attempts++ == 0 ? failing.future : Future.value(controller));
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
    await frames(tester, 2);
    failing.completeError(StateError('no engine'));
    await frames(tester, 2);
    expect(find.textContaining('播放器启动失败'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('video-retry')));
    await frames(tester, 20);
    expect(attempts, 2);
    expect(find.byKey(const ValueKey('video-error')), findsNothing);
    expect(controller.video?.bvid, bv);
    expect(player.loaded, isNotNull);
    await back(tester);
    expect(controller.video, isNull);
  });

  testWidgets('once the video has played, the cover stays gone through a replay', (tester) async {
    await host(tester);
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0, cover: cover));
    await frames(tester, 20);
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.descendant(of: find.byKey(const ValueKey('video-cover')), matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(opacity(), 1);
    player.emit(const StatusChanged(PlayerStatus.playing));
    await frames(tester);
    expect(opacity(), 0);
    unawaited(controller.replay());
    await tester.pump();
    expect(controller.phase, PlaybackPhase.loading);
    expect(opacity(), 0);
    await frames(tester);
    expect(opacity(), 0);
    await back(tester);
  });

  testWidgets('the cover Hero keeps its element while the player starts and the video opens', (tester) async {
    final ready = Completer<PlaybackController>();
    await host(tester, start: () => ready.future);
    pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0, cover: cover));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    Element hero() => tester.element(find.descendant(of: find.byType(VideoPage), matching: find.byType(Hero)));
    final first = hero();
    ready.complete(controller);
    await frames(tester, 20);
    expect(find.byKey(const ValueKey('fake-video')), findsOneWidget, reason: 'the video is in, under the cover');
    expect(identical(hero(), first), isTrue);
    player.emit(const StatusChanged(PlayerStatus.playing));
    await frames(tester);
    expect(identical(hero(), first), isTrue);
    await back(tester);
  });

  final feedCard = FeedCard.fromJson({...feedItem(bv), 'pic': cover});
  for (final (name, Widget Function(VoidCallback open) card, address, CoverPreset? cardPreset) in [
    (
      'a card sized by its box',
      (open) => GestureDetector(
        onTap: open,
        child: SizedBox(
          width: 214,
          height: 160,
          child: Hero(tag: VideoRoute.coverTag(bv), child: const RemoteImage(cover)),
        ),
      ),
      sizedImageUrl(cover, width: 240, height: 180),
      null,
    ),
    (
      // The cover at 211 × 158.25 pt, its box's size rounded up to whole pixels.
      'a 推荐 card on a 211 pt column',
      (open) => SizedBox(
        width: 211,
        child: FeedCardView(card: feedCard, onOpen: (_) => open(), onWatchLater: () {}),
      ),
      coverImageUrl(cover, width: 211, height: 159),
      CoverPreset.feed,
    ),
  ]) {
    testWidgets('a push from $name asks for at most two pictures: the card flies on its own download, the player '
        'box loads once', (tester) async {
      final requested = <String>[];
      debugNetworkImageHttpClientProvider = () => _RecordingHttpClient(requested);
      try {
        const route = VideoRoute(bvid: bv, cid: p1, start: 0, cover: cover);
        await host(
          tester,
          home: Builder(
            builder: (context) => Center(
              child: KeyedSubtree(
                key: const ValueKey('card'),
                // openVideoPage's push, with the test's session.
                child: card(() => Navigator.of(context).push(SwipeBackPageRoute<void>(builder: (_) => page(route)))),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(requested, [address]);
        requested.clear();
        await tester.tap(find.byKey(const ValueKey('card')));
        // A 推荐 card's own picture has a placeholder too, the official grey.
        final shuttle = find.byWidgetPredicate((widget) => widget is RemoteImage && widget.placeholder is RemoteImage);
        RemoteImage? flew;
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (shuttle.evaluate().isNotEmpty) flew ??= tester.widget<RemoteImage>(shuttle);
        }
        expect(flew, isNotNull, reason: 'the card image flew under the player-sized cover');
        expect((flew!.cover, flew.preset), (true, CoverPreset.player));
        final under = flew.placeholder! as RemoteImage;
        expect(under.preset, cardPreset, reason: "the card's own provider, its preset included");
        expect(
          requested,
          [coverImageUrl(cover, width: 440, height: 248)],
          reason: "the card's picture is the one it already asked for; the player box's cover at its size, once",
        );
        await back(tester);
        // The recording client never answers; the downloads give up.
        await tester.pump(ImageDiskCache.downloadTimeout);
      } finally {
        debugNetworkImageHttpClientProvider = null;
        imageCache
          ..clear()
          ..clearLiveImages();
      }
    });
  }

  testWidgets("opening a page asks for the player box's cover at once, the address the page's own cover draws", (
    tester,
  ) async {
    final requested = <String>[];
    debugNetworkImageHttpClientProvider = () => _RecordingHttpClient(requested);
    try {
      await host(tester);
      VideoPage.precacheCover(nav.currentContext!, cover);
      await tester.pump();
      expect(requested, [coverImageUrl(cover, width: 440, height: 248)]);

      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0, cover: cover));
      await frames(tester);
      final drawn = tester.widget<RemoteImage>(
        find.descendant(of: find.byKey(const ValueKey('video-cover')), matching: find.byType(RemoteImage)),
      );
      expect((drawn.cover, drawn.preset), (true, CoverPreset.player));
      expect(requested, hasLength(1), reason: "the page's cover is the precached provider, still on its way");
      await back(tester);
      await tester.pump(ImageDiskCache.downloadTimeout);
    } finally {
      debugNetworkImageHttpClientProvider = null;
      imageCache
        ..clear()
        ..clearLiveImages();
    }
  });

  group('a card opened during the pop', () {
    testWidgets('another part: the page reports its own part at its last position, nothing of the newer one',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await frames(tester, 20);
      player.emit(const StatusChanged(PlayerStatus.playing));
      position(10);
      unawaited(nav.currentState!.maybePop());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      pushVideo(const VideoRoute(bvid: bv, cid: p2, start: 0));
      await frames(tester, 20);
      expect(controller.page?.cid, p2);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester);
      expect(sent(), [(p1, '0'), (p1, '10'), (p2, '0')]);
      await back(tester);
    });

    testWidgets('the same card: the newer page\'s start never overwrites the position with 0', (tester) async {
      await host(tester);
      const route = VideoRoute(bvid: bv, cid: p1, start: 0);
      pushVideo(route);
      await frames(tester, 20);
      player.emit(const StatusChanged(PlayerStatus.playing));
      position(10);
      unawaited(nav.currentState!.maybePop());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      pushVideo(route);
      await frames(tester, 20);
      expect(controller.video?.bvid, bv);
      expect(heartbeats(), ['0', '10']);
      await back(tester);
      expect(heartbeats(), ['0', '10'], reason: 'the newer page never played');
    });
  });

  group('full screen is the same page laid out again', () {
    testWidgets('inline: black under the status bar, the 16:9 player, the tab row right under it and the tabs below '
        '(screen 03 without its ad card)', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      expect(area(tester), const Rect.fromLTWH(0, 62, 440, 440 / BiliMetrics.videoAspect));
      expect(tester.getRect(find.byType(PageTabRow)), const Rect.fromLTWH(0, 62 + 247.5, 440, PageTheme.tabRowHeight));
      expect(
        tester.getRect(find.byType(PageTabs)),
        const Rect.fromLTRB(0, 62 + CollapseTheme.barHeight + PageTheme.tabRowHeight, 440, 956),
        reason: 'laid out as if the player were the bar',
      );
      expect(
        PlayerReserve.of(tester.element(find.byType(IntroTab))),
        247.5 - CollapseTheme.barHeight,
        reason: 'so each tab\'s content starts right under the tab row',
      );
      expect(find.byType(PortraitControls), findsOneWidget);
      expect(
        MediaQuery.paddingOf(tester.element(find.byType(PortraitControls))),
        EdgeInsets.zero,
        reason: 'the small player sits below the status bar with no insets of its own',
      );
      final black = tester.widget<ColoredBox>(
        find.ancestor(of: find.byType(VideoPlayerArea), matching: find.byType(ColoredBox)).first,
      );
      expect(black.color, BiliColors.videoBackground);
      expect(
        tester.getRect(find.ancestor(of: find.byType(VideoPlayerArea), matching: find.byType(ColoredBox)).first),
        const Rect.fromLTWH(0, 0, 440, 62 + 440 / BiliMetrics.videoAspect),
      );
      await back(tester);
    });

    testWidgets('landscape: the player fills the screen around the notch, the details out of sight (screen 04)',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await rotate(tester, Presentation.landscape);
      expect(area(tester), const Rect.fromLTWH(0, 0, 956, 440));
      expect(find.byType(LandscapeChrome), findsOneWidget);
      expect(find.byType(PortraitControls), findsNothing);
      expect(find.byType(PageTabRow), findsNothing, reason: 'offstage');
      expect(
        MediaQuery.paddingOf(tester.element(find.byType(LandscapeChrome))),
        const EdgeInsets.fromLTRB(62, 0, 62, 21),
        reason: 'the chrome keeps clear of the notch and the home indicator itself',
      );
      expect(tester.getRect(find.byKey(const ValueKey('fake-video'))), const Rect.fromLTWH(0, 0, 956, 440));

      await rotate(tester, Presentation.inline);
      expect(area(tester), const Rect.fromLTWH(0, 62, 440, 440 / BiliMetrics.videoAspect));
      expect(find.byType(PageTabRow), findsOneWidget);
      await back(tester);
    });

    testWidgets('竖屏: the player fills the upright screen, a landscape video above the middle (screen 09)',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await rotate(tester, Presentation.vertical);
      expect(area(tester), const Rect.fromLTWH(0, 0, 440, 956));
      expect(find.byType(VerticalChrome), findsOneWidget);
      expect(MediaQuery.paddingOf(tester.element(find.byType(VerticalChrome))), const EdgeInsets.only(top: 62, bottom: 34));
      // The surface runs to 83% of the screen, so a fitted 16:9 picture centres at 41.5% as on 09.
      final surface = tester.getRect(find.byKey(const ValueKey('fake-video')));
      expect(surface, Rect.fromLTWH(0, 0, 440, 956 * BiliMetrics.verticalVideoCentre * 2));
      expect(surface.center.dy, closeTo(397, 1));

      sessions.single
        ..isVertical = true
        ..changed();
      await tester.pump();
      expect(tester.getRect(find.byKey(const ValueKey('fake-video'))).center.dy, closeTo(463, 0.01), reason: '16');
      expect(orientation.videoIsVertical, isTrue, reason: 'the page passes the video\'s shape on');
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets('the native view is built once and keeps its element through every layout and chrome change',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final first = tester.element(find.byKey(const ValueKey('fake-video')));
      void same() => expect(identical(tester.element(find.byKey(const ValueKey('fake-video'))), first), isTrue);
      await rotate(tester, Presentation.landscape);
      same();
      await rotate(tester, Presentation.inline);
      same();
      await rotate(tester, Presentation.vertical);
      same();
      sessions.single
        ..ended = true
        ..changed();
      await tester.pump();
      same();
      await rotate(tester, Presentation.landscape);
      same();
      ui(tester).panels.open(PlayerPanel.more);
      ui(tester).chrome.hide();
      await tester.pump();
      same();
      await rotate(tester, Presentation.inline);
      same();
      await back(tester);
    });

    testWidgets('the right chrome and end screen for each presentation', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      sessions.single
        ..ended = true
        ..changed();
      await tester.pump();
      expect(find.byType(EndScreenPortrait), findsOneWidget);
      expect(find.byType(PortraitControls), findsNothing);
      await rotate(tester, Presentation.landscape);
      expect(find.byType(EndScreenLandscape), findsOneWidget);
      expect(find.byType(EndScreenPortrait), findsNothing);
      expect(tester.getRect(find.byType(EndScreenLandscape)), const Rect.fromLTWH(0, 0, 956, 440));
      sessions.single
        ..ended = false
        ..changed();
      await tester.pump();
      expect(find.byType(LandscapeChrome), findsOneWidget);
      expect(find.byType(EndScreenLandscape), findsNothing);
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets('panels go over the whole page, inline and full screen', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      expect(tester.getRect(find.byType(PanelLayer)), const Rect.fromLTWH(0, 0, 440, 956));
      await rotate(tester, Presentation.landscape);
      expect(tester.getRect(find.byType(PanelLayer)), const Rect.fromLTWH(0, 0, 956, 440));
      final stack = tester.widget<Stack>(
        find.ancestor(of: find.byType(PanelLayer), matching: find.byType(Stack)).first,
      );
      expect(
        [for (final child in stack.children.skip(stack.children.length - 3)) child.key],
        const [ValueKey('video-panels'), ValueKey('video-overlays'), ValueKey('danmaku-overlays')],
        reason: 'above the player and the tabs, with the action overlays over the panels and the send bar on top',
      );
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets('the chrome hides by itself only while playing, not scrubbing and with no panel open', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final chrome = ui(tester).chrome;
      final session = sessions.single;
      expect(chrome.autoHide, isFalse);
      player.emit(const StatusChanged(PlayerStatus.playing));
      expect(chrome.autoHide, isTrue);
      session.scrub(30);
      expect(chrome.autoHide, isFalse);
      session.cancelScrub();
      expect(chrome.autoHide, isTrue);
      ui(tester).panels.open(PlayerPanel.speed);
      expect(chrome.autoHide, isFalse);
      ui(tester).panels.close();
      expect(chrome.autoHide, isTrue);
      player.emit(const StatusChanged(PlayerStatus.paused));
      expect(chrome.autoHide, isFalse);
      await back(tester);
    });

    testWidgets('with a panel open, the back arrow and a pop close it first; the next back leaves the page',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final panels = ui(tester).panels;
      bool canPop() => tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>).last).canPop;

      panels.open(PlayerPanel.more);
      await tester.pump();
      ui(tester).onBack();
      await frames(tester, 2);
      expect(panels.value, isNull);
      expect(find.byType(VideoPage), findsOneWidget);

      panels.open(PlayerPanel.speed);
      await tester.pump();
      expect(canPop(), isFalse);
      unawaited(nav.currentState!.maybePop());
      await frames(tester, 2);
      expect(panels.value, isNull);
      expect(find.byType(VideoPage), findsOneWidget);
      expect(controller.video, isNotNull, reason: 'the page kept the player');
      expect(canPop(), isTrue);

      ui(tester).onBack();
      await frames(tester, 20);
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets('in full screen with a panel open, back closes it first; the next back goes to the small player',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final panels = ui(tester).panels;
      for (final full in [Presentation.landscape, Presentation.vertical]) {
        await rotate(tester, full);
        panels.open(PlayerPanel.more);
        await tester.pump();
        ui(tester).onBack();
        await frames(tester, 2);
        expect(panels.value, isNull, reason: '$full');
        expect(orientation.presentation, full);

        panels.open(PlayerPanel.quality);
        await tester.pump();
        unawaited(nav.currentState!.maybePop());
        await frames(tester, 2);
        expect(panels.value, isNull, reason: '$full');
        expect(orientation.presentation, full);

        unawaited(nav.currentState!.maybePop());
        await frames(tester, 2);
        expect(orientation.presentation, Presentation.inline);
        expect(find.byType(VideoPage), findsOneWidget);
        screen(tester, portrait, portraitInsets);
      }
      await back(tester);
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets('every panel closed, by a pick, a tap outside or back, leaves the controls hidden', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await rotate(tester, Presentation.landscape);
      final chrome = ui(tester).chrome;
      final panels = ui(tester).panels;

      for (final panel in PlayerPanel.values) {
        chrome.show();
        panels.open(panel);
        await tester.pump();
        panels.close();
        await tester.pump();
        expect(chrome.visible, isFalse, reason: '$panel');
      }

      // Moving between panels keeps them up; only the last close goes back to the video.
      chrome.show();
      panels
        ..open(PlayerPanel.more)
        ..open(PlayerPanel.danmakuSettings)
        ..open(PlayerPanel.danmakuList);
      await tester.pump();
      expect(chrome.visible, isTrue);
      ui(tester).onBack();
      await frames(tester, 2);
      expect(panels.value, isNull);
      expect(chrome.visible, isFalse);

      unawaited(nav.currentState!.maybePop());
      await frames(tester, 2);
      await back(tester);
    });

    testWidgets('in 竖屏 the controls never hide by themselves, and a closed panel leaves them up (118)', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester, vertical: true);
      await rotate(tester, Presentation.vertical);
      final chrome = ui(tester).chrome;
      final panels = ui(tester).panels;
      player.emit(const StatusChanged(PlayerStatus.playing));
      await tester.pump();
      expect(chrome.autoHide, isFalse);
      await tester.pump(chrome.hideDelay * 2);
      expect(chrome.visible, isTrue);

      for (final panel in PlayerPanel.values) {
        panels.open(panel);
        await tester.pump();
        panels.close();
        await tester.pump();
        expect(chrome.visible, isTrue, reason: '$panel');
      }

      await rotate(tester, Presentation.landscape);
      expect(chrome.autoHide, isTrue, reason: 'landscape hides them again');
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets('two stacked pages: the latest begin wins and the page below takes the orientation back',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await frames(tester, 20);
      expect(orientation.log, isEmpty, reason: 'not before the video is known');
      await opened(tester);
      expect(orientation.log, ['begin page1']);

      pushVideo(const VideoRoute(bvid: bv, cid: p2, start: 0));
      await opened(tester, page: 1, vertical: true);
      expect(orientation.log, ['begin page1', 'end page1', 'begin page2 vertical'],
          reason: 'covered, the page gives the orientation up before the page above has its video');
      sessions.first
        ..isVertical = true
        ..video = null
        ..changed();
      await tester.pump();
      expect(orientation.log, hasLength(3), reason: 'the covered page leaves the orientation alone');

      await back(tester);
      expect(orientation.log, ['begin page1', 'end page1', 'begin page2 vertical', 'end page2', 'begin page1']);
      expect(orientation.videoIsVertical, isFalse, reason: 'the page below begins with its own video\'s shape');
      await back(tester);
      expect(orientation.log.last, 'end page1');
    });

    testWidgets('the chrome stops hiding by itself while the next part loads, then hides again once it plays',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final chrome = ui(tester).chrome;
      player.emit(const StatusChanged(PlayerStatus.playing));
      expect(chrome.autoHide, isTrue);
      http.gates[Canned.playUrlPath] = Completer<void>();
      // As 自动连播 or 选集 opens the next part: the player still reports P1 playing until P2's load starts.
      sessionOpens.single(bv, cid: p2);
      await tester.pump();
      expect(controller.phase, PlaybackPhase.loading);
      expect(sessions.single.readout.wantsPlay, isTrue);
      expect(chrome.autoHide, isFalse);
      http.gates[Canned.playUrlPath]!.complete();
      await frames(tester, 20);
      expect(chrome.autoHide, isFalse);
      player.emit(const StatusChanged(PlayerStatus.playing));
      expect(chrome.autoHide, isTrue);
      await back(tester);
    });

    testWidgets('in full screen the edge swipe and a pop go back to the small player, not off the page',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await rotate(tester, Presentation.landscape);
      expect(tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>).last).canPop, isFalse);
      await tester.dragFrom(const Offset(2, 220), const Offset(600, 0));
      await frames(tester, 20);
      expect(find.byType(VideoPage), findsOneWidget, reason: 'no swipe back in full screen');

      unawaited(nav.currentState!.maybePop());
      await frames(tester, 2);
      expect(find.byType(VideoPage), findsOneWidget);
      expect(orientation.presentation, Presentation.inline);
      expect(controller.video, isNotNull, reason: 'the page kept the player');
      expect(tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>).last).canPop, isFalse,
          reason: 'still laid out landscape until the screen is upright');
      screen(tester, portrait, portraitInsets);
      await tester.pump();
      expect(tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>).last).canPop, isTrue);
      await back(tester);
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets('the back arrow: off the page inline, to the small player from full screen', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      for (final full in [Presentation.landscape, Presentation.vertical]) {
        await rotate(tester, full);
        ui(tester).onBack();
        await frames(tester, 2);
        expect(orientation.presentation, Presentation.inline);
        expect(find.byType(VideoPage), findsOneWidget);
        screen(tester, portrait, portraitInsets);
      }
      ui(tester).onBack();
      await frames(tester, 20);
      expect(find.byType(VideoPage), findsNothing);
      expect(controller.video, isNull);
    });

    testWidgets('full screen keeps the status bar and hides the home indicator; inline gives both back',
        (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) calls.add(call);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      expect(calls, isEmpty);
      await rotate(tester, Presentation.landscape);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect(calls.single.arguments, ['SystemUiOverlay.top']);
      await rotate(tester, Presentation.inline);
      expect(calls.last.method, 'SystemChrome.setEnabledSystemUIMode');
      expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
      expect(calls, hasLength(2));
      await back(tester);
    });
  });

  group('the session', () {
    testWidgets('its open plays another part on the same page, with its own watch reports', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0, title: '卡片标题'));
      await opened(tester);
      player.emit(const StatusChanged(PlayerStatus.playing));
      position(10);
      sessionOpens.single(bv, cid: p2);
      await frames(tester, 20);
      expect(controller.page?.cid, p2);
      expect(find.byType(VideoPage), findsOneWidget);
      expect(sessions, hasLength(1));
      expect(detailsMade, hasLength(1), reason: 'one details per page, through its parts');
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester);
      expect(sent(), [(p1, '0'), (p1, '10'), (p2, '0')]);
      expect(find.byKey(const ValueKey('fake-video')), findsOneWidget);

      await back(tester);
      final opens = controller.opens;
      sessionOpens.single(bv, cid: p1);
      await frames(tester);
      expect(controller.opens, opens, reason: 'a page that left opens nothing');
    });

    testWidgets('简介 follows the page\'s own session, and a newer page\'s video never reaches it', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      IntroContent intro() => tester.widget<IntroTab>(find.byType(IntroTab, skipOffstage: false).first).content;
      expect(intro().detail, isNull);
      sessions.single
        ..detail = detail(bv, reply: 213)
        ..episodes = const [
          Episode(bvid: bv, cid: p1, title: 'P1 第一集', current: true),
          Episode(bvid: bv, cid: p2, title: 'P2 第二集', current: false),
        ]
        ..changed();
      await tester.pump();
      expect(intro().detail?.bvid, bv);
      expect(intro().episodes, hasLength(2));
      expect(find.bySemanticsLabel('评论 213'), findsOneWidget);

      pushVideo(const VideoRoute(bvid: 'BV1xx411c7mD', start: 0));
      await opened(tester, page: 1);
      sessions.last
        ..detail = detail('BV1xx411c7mD')
        ..changed();
      await tester.pump();
      expect(intro().detail?.bvid, bv);
      expect(sessions.first.player, isNot(same(sessions.last.player)), reason: 'each page plays on its own player');
      await back(tester);
      await back(tester);
    });

    testWidgets('is inactive while another page covers the page, and active again once shown with its own open',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final session = sessions.single;
      expect(session.active, isTrue);
      unawaited(nav.currentState!.push(SwipeBackPageRoute<void>(builder: (_) => const SizedBox())));
      await frames(tester, 20);
      expect(session.active, isFalse);
      await back(tester);
      expect(session.active, isTrue, reason: 'the player is still this page\'s open');
      await back(tester);
      expect(session.active, isFalse, reason: 'the page left');
    });

    testWidgets('paused and inactive under a newer video page, then resumes where it was, with no reload',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final first = controller;
      final firstPlayer = player;
      firstPlayer.emit(const StatusChanged(PlayerStatus.playing));
      position(42);
      final opens = first.opens;
      firstPlayer.calls.clear();
      pushVideo(const VideoRoute(bvid: 'BV1xx411c7mD', start: 0));
      await opened(tester, page: 1);
      expect(controller, isNot(same(first)), reason: 'the newer page plays on a controller of its own');
      expect(sessions.first.active, isFalse);
      expect(detailsMade.first.activeSet, isFalse);
      expect(sessions.last.active, isTrue);
      expect(firstPlayer.calls, ['pause', 'pip auto false']);
      expect(playback.live, 2);

      firstPlayer.calls.clear();
      await back(tester);
      expect(sessions.last.active, isFalse, reason: 'the page on top left');
      expect(playback.live, 1, reason: 'its controller went with it');
      expect(first.opens, opens, reason: 'nothing opened again');
      expect(first.video?.bvid, bv);
      expect(first.page?.cid, p1);
      expect(firstPlayer.calls, ['pip auto true', 'play']);
      expect(firstPlayer.calls.where((call) => call.startsWith('load')), isEmpty);
      expect(first.currentSeconds, closeTo(42, 0.5));
      expect(sessions.first.active, isTrue);
      expect(detailsMade.first.activeSet, isTrue);
      firstPlayer.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester);
      expect(find.byKey(const ValueKey('video-loading')), findsNothing, reason: 'it plays rather than spinning');
      expect(find.byType(PortraitControls), findsOneWidget);
      await back(tester);
      expect(first.video, isNull);
      expect(playback.live, 0);
    });

    testWidgets('a page the user paused stays paused when shown again', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final firstPlayer = player;
      firstPlayer
        ..emit(const StatusChanged(PlayerStatus.playing))
        ..emit(const StatusChanged(PlayerStatus.paused));
      pushVideo(const VideoRoute(bvid: 'BV1xx411c7mD', start: 0));
      await opened(tester, page: 1);
      firstPlayer.calls.clear();
      await back(tester);
      expect(firstPlayer.calls, ['pip auto true'], reason: 'no play');
      await back(tester);
    });

    testWidgets('a page covered while its video loads comes back playing, and doesn\'t play while covered',
        (tester) async {
      http.gates[Canned.playUrlPath] = Completer<void>();
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await frames(tester, 20);
      final first = controller;
      final firstPlayer = player;
      expect(first.phase, PlaybackPhase.loading);
      unawaited(nav.currentState!.push(SwipeBackPageRoute<void>(builder: (_) => const SizedBox())));
      await frames(tester, 20);
      expect(firstPlayer.calls, contains('pause'));
      http.gates[Canned.playUrlPath]!.complete();
      await frames(tester, 5);
      expect(firstPlayer.loaded?.autoplay, isFalse, reason: 'covered, it loads paused');
      expect(firstPlayer.calls, isNot(contains('play')));
      firstPlayer.calls.clear();
      // A player that starts anyway is paused again at once, and gets no auto picture in picture while covered.
      firstPlayer.emit(const StatusChanged(PlayerStatus.playing));
      expect(firstPlayer.calls, ['pause']);
      firstPlayer.calls.clear();
      await back(tester);
      expect(firstPlayer.calls, ['play']);
      firstPlayer.emit(const StatusChanged(PlayerStatus.playing));
      expect(firstPlayer.calls, ['play', 'pip auto true'], reason: 'its first play shown turns it on');
      await back(tester);
    });

    testWidgets('the app\'s own session across a part change: P2 plays on the page after P1, then the end screen',
        (tester) async {
      final prefs = PlayerPrefs.shared;
      PlayerPrefs.shared = PlayerPrefs.memory();
      addTearDown(() => PlayerPrefs.shared = prefs);
      await host(tester);
      unawaited(
        nav.currentState!.push(
          SwipeBackPageRoute<void>(
            builder: (_) => VideoPage(route: const VideoRoute(bvid: bv, cid: p1, start: 0), createDetails: fakeDetails),
          ),
        ),
      );
      await frames(tester, 20);
      expect(ui(tester).session, isA<PagePlayerSession>());
      expect(controller.page?.cid, p1);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester);

      player.emit(const StatusChanged(PlayerStatus.ended));
      await frames(tester, 20);
      expect(controller.page?.cid, p2, reason: '自动连播 opened P2');
      expect(find.byType(VideoPage), findsOneWidget);
      expect(ui(tester).session.title, '第二集');
      expect(
        tester.widget<IntroTab>(find.byType(IntroTab)).content.episodes.where((e) => e.current).single.cid,
        p2,
        reason: '简介 follows the app\'s session',
      );
      expect(find.byType(EndScreenPortrait), findsNothing);
      final opens = controller.opens;
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester);

      player.emit(const StatusChanged(PlayerStatus.ended));
      await frames(tester, 20);
      expect(find.byType(EndScreenPortrait), findsOneWidget);
      expect(controller.opens, opens, reason: 'nothing plays after the last part');
      expect(controller.page?.cid, p2);
      expect(sent(), [(p1, '0'), (p1, '-1'), (p2, '0'), (p2, '-1')]);
      await back(tester);
      expect(controller.video, isNull);
    });

    testWidgets('a menu or dialog over the page leaves it active and owning the orientation; a page on top covers it',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final session = sessions.single
        ..detail = detail(bv)
        ..related = [card('BV1xx411c7mD')]
        ..changed();
      await tester.pump();
      final details = detailsMade.single;
      final opens = controller.opens;
      final log = [...orientation.log];
      void stillActive(String what) {
        expect(session.active, isTrue, reason: what);
        expect(details.activeSet, isNot(isFalse), reason: what);
        expect(controller.opens, opens, reason: '$what: nothing opened again');
        expect(orientation.log, log, reason: '$what: the orientation stays the page\'s');
      }

      await tester.ensureVisible(find.byKey(const ValueKey('related-more')));
      await tester.tap(find.byKey(const ValueKey('related-more')));
      await frames(tester);
      expect(find.byKey(const ValueKey('related-watch-later')), findsOneWidget);
      stillActive('the related ⋮ menu');
      nav.currentState!.pop();
      await frames(tester);
      stillActive('the menu closed');

      unawaited(showDialog<void>(context: nav.currentContext!, builder: (_) => const SizedBox()));
      await frames(tester);
      stillActive('a dialog');
      nav.currentState!.pop();
      await frames(tester);
      stillActive('the dialog closed');

      unawaited(nav.currentState!.push(SwipeBackPageRoute<void>(builder: (_) => const SizedBox())));
      await frames(tester, 20);
      expect(session.active, isFalse);
      expect(details.activeSet, isFalse);
      await back(tester);
      expect(session.active, isTrue);
      expect(details.activeSet, isTrue);
      expect(orientation.log, [...log, 'end page1', 'begin page1'],
          reason: 'covered it gives the orientation up, and shown again it takes it back');
      await back(tester);
    });

    testWidgets('a newer video page and back with the real details: the same actions, no second uploader, relation '
        'or tags ask, and one fresh N人正在看', (tester) async {
      final prefs = PlayerPrefs.shared;
      PlayerPrefs.shared = PlayerPrefs.memory();
      addTearDown(() => PlayerPrefs.shared = prefs);
      final api = FakePageApi(
        uploader: const UploaderCard(
          mid: 1,
          name: 'UP主',
          face: '',
          fans: 10,
          videos: 2,
          isVip: false,
          following: false,
          official: OfficialKind.none,
        ),
      );
      VideoPageDetailsModel? model;
      await host(tester);
      unawaited(
        nav.currentState!.push(
          SwipeBackPageRoute<void>(
            builder: (_) => VideoPage(
              route: const VideoRoute(bvid: bv, cid: p1, start: 0),
              createDetails:
                  ({required session, required services, required toast, required requestLogin, required logins}) =>
                      model = VideoPageDetailsModel(
                        session: session,
                        api: api,
                        isLoggedIn: () => true,
                        accountMid: () => 12345,
                        requestLogin: () {},
                        toast: toast,
                        periodic: FakeTimers().start,
                      ),
              openPage: openPage,
            ),
          ),
        ),
      );
      await frames(tester, 20);
      final first = controller;
      final firstPlayer = player;
      player.emit(const StatusChanged(PlayerStatus.playing));
      position(42);
      await frames(tester);
      final actions = model!.actions;
      expect(actions, isNotNull);
      expect(api.calls, ['uploaderCard mid=1', 'relation', 'tags cid=$p1', 'onlineCount cid=$p1']);

      const other = 'BV1xx411c7mD';
      http.routes[Canned.signedViewPath] = (
        200,
        Canned.view
            .replaceAll(bv, other)
            .replaceAll('80433022', '80433023')
            .replaceAll('$p1', '237649199')
            .replaceAll('$p2', '237649200'),
      );
      pushVideo(const VideoRoute(bvid: other, start: 0));
      await frames(tester, 20);
      expect(controller.video?.bvid, other);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester);
      expect(api.calls, hasLength(4), reason: 'the covered page asks nothing for the newer video');

      http.routes[Canned.signedViewPath] = (200, Canned.view);
      await back(tester);
      firstPlayer.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 20);
      expect(first.video?.bvid, bv);
      expect(first.page?.cid, p1);
      expect(model!.actions, same(actions));
      expect(api.calls.skip(4), ['onlineCount cid=$p1']);
      await back(tester);
      expect(first.video, isNull);
    });

    testWidgets('is made once the player is the page\'s and disposed when the page leaves', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await frames(tester, 20);
      expect(sessions, hasLength(1));
      await back(tester);
      expect(() => sessions.single.addListener(() {}), throwsFlutterError);
    });
  });

  group('the page body', () {
    IntroTab intro(WidgetTester tester) => tester.widget<IntroTab>(find.byType(IntroTab));
    ActionOverlayController overlays(WidgetTester tester) =>
        tester.widget<ActionOverlays>(find.byType(ActionOverlays).last).controller;
    PageController pager(WidgetTester tester) =>
        tester.widget<PageView>(find.byKey(const ValueKey('page-tabs')).last).controller!;

    testWidgets('the details are made once with the session, handed to the player, follow its active, and go with '
        'the page', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final details = detailsMade.single;
      expect(ui(tester).details, same(details));
      expect(intro(tester).details, same(details));
      expect(ui(tester).onComments, isNotNull);
      unawaited(nav.currentState!.push(SwipeBackPageRoute<void>(builder: (_) => const SizedBox())));
      await frames(tester, 20);
      expect(details.activeSet, isFalse);
      await back(tester);
      expect(details.activeSet, isTrue);
      await back(tester);
      expect(details.activeSet, isFalse);
      expect(() => details.addListener(() {}), throwsFlutterError, reason: 'disposed with the page');
      expect(detailsMade, hasLength(1));
    });

    testWidgets('the row: 评论 shows the reply count, the 弹 toggle switches danmaku, 点我发弹幕 opens the send bar, which back closes first',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final session = sessions.single
        ..detail = detail(bv, reply: 12345)
        ..changed();
      await tester.pump();
      expect(find.bySemanticsLabel('评论 1.2万'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('danmaku-toggle')));
      await tester.pump();
      expect(session.calls, contains('setDanmakuOn false'));
      expect(find.byKey(const ValueKey('danmaku-send')), findsOneWidget);
      session
        ..danmakuOn = true
        ..changed();
      await frames(tester, 8);
      await tester.tap(find.byKey(const ValueKey('danmaku-send')));
      await tester.pump();
      final overlays = tester.widget<DanmakuOverlays>(find.byType(DanmakuOverlays));
      expect(overlays.session.sendOpen.value, isTrue);
      await back(tester);
      expect(overlays.session.sendOpen.value, isFalse);
      await back(tester);
    });

    testWidgets('back closes an open overlay first, then a panel, then full screen, then leaves', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final panels = ui(tester).panels;
      bool canPop() => tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>).last).canPop;

      overlays(tester).value = ActionPrompt.coin;
      await tester.pump();
      expect(canPop(), isFalse);
      unawaited(nav.currentState!.maybePop());
      await frames(tester, 2);
      expect(overlays(tester).value, isNull);
      expect(find.byType(VideoPage), findsOneWidget);

      await rotate(tester, Presentation.landscape);
      panels.open(PlayerPanel.more);
      overlays(tester).value = ActionPrompt.favourites;
      await tester.pump();
      expect(
        tester.widget<ActionOverlays>(find.byType(ActionOverlays)).landscape,
        isTrue,
        reason: 'the overlays lay out for landscape',
      );
      ui(tester).onBack();
      await frames(tester, 2);
      expect(overlays(tester).value, isNull);
      expect(panels.value, PlayerPanel.more, reason: 'the overlay went first');
      ui(tester).onBack();
      await frames(tester, 2);
      expect(panels.value, isNull);
      expect(orientation.presentation, Presentation.landscape);
      ui(tester).onBack();
      await frames(tester, 2);
      expect(orientation.presentation, Presentation.inline);
      expect(canPop(), isFalse, reason: 'the landscape layout is still drawn until the screen is upright');
      ui(tester).onBack();
      await frames(tester, 2);
      expect(find.byType(VideoPage), findsOneWidget, reason: "the landscape 〈 doesn't take the page mid-turn");
      screen(tester, portrait, portraitInsets);
      await tester.pump();
      expect(canPop(), isTrue);
      ui(tester).onBack();
      await frames(tester, 20);
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets('评论 in full screen goes back to the small player on the 评论 tab', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await rotate(tester, Presentation.landscape);
      ui(tester).onComments!();
      screen(tester, portrait, portraitInsets);
      await frames(tester, 4);
      expect(orientation.presentation, Presentation.inline);
      expect(pager(tester).page, 1);
      expect(find.byWidgetPredicate((widget) => widget is CommentsTab || widget is CommentsSlot), findsOneWidget);
      await back(tester);
    });

    testWidgets('简介\'s parts, 选集, timestamps, video ids and 稍后再看 reach the session, the panel and the details',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final session = sessions.single;
      intro(tester).onPlayEpisode(const Episode(bvid: bv, cid: p2, title: 'P2 第二集', current: false));
      expect(session.calls, contains('playEpisode $bv $p2'));
      intro(tester).onOpenEpisodes();
      expect(ui(tester).panels.value, PlayerPanel.episodes);
      ui(tester).panels.close();
      sessions.single.duration.value = 200;
      intro(tester).onSeek(83);
      expect(session.calls, contains('commitSeek 83.0'));

      intro(tester).onWatchLater(card('BV1xx411c7mD'));
      await tester.pump();
      expect(detailsMade.single.watchLaterCalls, ['BV1xx411c7mD']);
      expect(find.text('已添加至稍后再看'), findsOneWidget);
      await frames(tester, 70);

      intro(tester).onOpenVideo('BV1xx411c7mD');
      await frames(tester, 20);
      expect(find.byType(VideoPage, skipOffstage: false), findsNWidgets(2));
      expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.bvid, 'BV1xx411c7mD');
      await back(tester);
      await back(tester);
    });

    testWidgets('in full screen an action overlay puts the chrome and the end screen away as a panel does, and gives '
        'them back as they were; inline the small controls stay', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final chrome = ui(tester).chrome;
      player.emit(const StatusChanged(PlayerStatus.playing));
      expect(chrome.autoHide, isTrue);
      overlays(tester).value = ActionPrompt.coin;
      await tester.pump();
      expect(chrome.autoHide, isFalse, reason: 'no hide timer while it is up');
      expect(chrome.visible, isTrue);
      overlays(tester).close();
      await tester.pump();
      expect(chrome.autoHide, isTrue);

      await rotate(tester, Presentation.landscape);
      chrome.show();
      await tester.pump();
      bool shown() => !tester.widget<IgnorePointer>(find.byKey(const ValueKey('landscape-chrome'))).ignoring;
      expect(shown(), isTrue);
      overlays(tester).value = ActionPrompt.favourites;
      await tester.pump();
      expect(shown(), isFalse);
      expect(chrome.autoHide, isFalse);
      await tester.pump(const Duration(seconds: 5));
      overlays(tester).close();
      await tester.pump();
      expect(shown(), isTrue, reason: 'back as it was');
      expect(chrome.autoHide, isTrue);
      await tester.pump(chrome.hideDelay + const Duration(milliseconds: 50));
      expect(shown(), isFalse, reason: 'the hide timer runs again');
      overlays(tester).value = ActionPrompt.coin;
      await tester.pump();
      overlays(tester).close();
      await tester.pump();
      expect(shown(), isFalse, reason: 'hidden when the overlay went up, it stays hidden');

      sessions.single
        ..ended = true
        ..changed();
      await tester.pump();
      bool endShown() => !tester.widget<IgnorePointer>(find.byKey(const ValueKey('video-end'))).ignoring;
      expect(find.byType(EndScreenLandscape), findsOneWidget);
      expect(endShown(), isTrue);
      overlays(tester).value = ActionPrompt.favourites;
      await tester.pump();
      expect(endShown(), isFalse);
      overlays(tester).close();
      await tester.pump();
      expect(endShown(), isTrue);
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets('the danmaku keep below the status bar, and in 竖屏 below the top row down to the video bottom (118)',
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester, vertical: true);
      double top() => tester.getRect(find.byType(DanmakuLayer)).top;
      double bottom() => tester.getRect(find.byType(DanmakuLayer)).bottom;
      expect(top(), 62, reason: 'inline: under the status bar band, at the top of the player');
      await rotate(tester, Presentation.vertical);
      expect(tester.getRect(find.byKey(const ValueKey('fake-video'))).top, 0, reason: 'the video runs under it');
      // 62 for the island, less the top row's 8 pt lift, then its 44 pt row and the 1 pt 118 leaves under it.
      expect(top(), 99);
      expect(bottom(), closeTo(956 * BiliMetrics.verticalUprightCentre * 2, 0.01), reason: "an upright video's band");
      sessions.single
        ..isVertical = false
        ..changed();
      await tester.pump();
      expect(top(), 99, reason: 'a landscape video in 竖屏 too: over the black above it, as on 118');
      expect(bottom(), closeTo(956 * BiliMetrics.verticalVideoCentre + 440 / BiliMetrics.videoAspect / 2, 0.01));
      await rotate(tester, Presentation.landscape);
      expect(top(), 0);
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets('a description timestamp seeks and plays a paused video; a playing one just seeks', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final session = sessions.single;
      player.emit(const StatusChanged(PlayerStatus.paused));
      player.calls.clear();
      sessions.single.duration.value = 200;
      intro(tester).onSeek(83);
      await tester.pump();
      expect(session.calls, contains('commitSeek 83.0'));
      expect(player.calls, ['play']);
      expect(session.calls, isNot(contains('togglePlay')));

      player.emit(const StatusChanged(PlayerStatus.playing));
      player.calls.clear();
      intro(tester).onSeek(90);
      await tester.pump();
      expect(session.calls, contains('commitSeek 90.0'));
      expect(player.calls, isEmpty);
      await back(tester);
    });

    testWidgets('a timestamp tapped before the duration is known neither seeks nor plays', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      player.emit(const StatusChanged(PlayerStatus.paused));
      player.calls.clear();
      intro(tester).onSeek(83);
      await tester.pump();
      expect(sessions.single.calls, isNot(contains('commitSeek 83.0')));
      expect(player.calls, isEmpty);
      await back(tester);
    });

    testWidgets('the video\'s own id in its description opens nothing', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      sessions.single
        ..detail = detail(bv)
        ..changed();
      await tester.pump();
      final views = http.to(Canned.viewPath).length;
      intro(tester).onOpenVideo(bv);
      intro(tester).onOpenVideo('av1');
      await frames(tester, 20);
      expect(find.byType(VideoPage, skipOffstage: false), findsOneWidget);
      expect(http.to(Canned.viewPath), hasLength(views), reason: 'its own av id is not looked up');
      await back(tester);
    });

    testWidgets('an av id is looked up once however often it is tapped, and a failed lookup is logged and toasted',
        (tester) async {
      final logs = MemorySink();
      Logger.shared.add(logs);
      addTearDown(() => Logger.shared.remove(logs));
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      final views = http.to(Canned.viewPath).length;
      final lookup = http.gates[Canned.viewPath] = Completer<void>();
      http.errors[Canned.viewPath] = const SocketException('lost');
      intro(tester).onOpenVideo('av170001');
      await tester.pump();
      intro(tester).onOpenVideo('av170001');
      await tester.pump();
      expect(http.to(Canned.viewPath), hasLength(views + 1));
      lookup.complete();
      await frames(tester, 2);
      expect(find.byType(VideoPage, skipOffstage: false), findsOneWidget);
      expect(
        logs.events.where((event) => event.msg == 'open video id failed').map((event) => event.cat),
        [LogCategory.ui],
      );
      expect(find.text('网络连接失败，请检查网络后重试'), findsOneWidget);
      await frames(tester, 70);

      http.gates.remove(Canned.viewPath);
      intro(tester).onOpenVideo('av170001');
      await frames(tester, 2);
      expect(http.to(Canned.viewPath), hasLength(views + 2), reason: 'a tap after the failure asks again');
      await frames(tester, 70);
      await back(tester);
    });

    testWidgets('稍后再看 with nothing to say shows no toast', (tester) async {
      makeDetails = _QuietDetails.new;
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      intro(tester).onWatchLater(card('BV1xx411c7mD'));
      await tester.pump();
      expect(detailsMade.single.watchLaterCalls, ['BV1xx411c7mD']);
      expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_Toast'), findsNothing);
      await back(tester);
    });

    testWidgets('the cover\'s Hero stands down once the video played or while 简介 lists the same video, so no two '
        'Heroes share a tag', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0, cover: cover));
      await opened(tester);
      Element hero() =>
          tester.element(find.descendant(of: find.byKey(const ValueKey('video-cover')), matching: find.byType(Hero)));
      final first = hero();
      bool flies() => tester
          .widget<HeroMode>(
            find.descendant(of: find.byKey(const ValueKey('video-cover')), matching: find.byType(HeroMode)),
          )
          .enabled;
      expect(flies(), isTrue);
      sessions.single
        ..detail = detail(bv)
        ..related = [card(bv)]
        ..changed();
      await tester.pump();
      expect(flies(), isFalse, reason: 'a related row has the same tag');
      sessions.single
        ..related = [card('BV1xx411c7mD')]
        ..changed();
      await tester.pump();
      expect(flies(), isTrue);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester);
      expect(flies(), isFalse, reason: 'played');
      expect(identical(hero(), first), isTrue, reason: 'the cover keeps its element');

      // As after 自动连播 to a video whose related videos hold this one: the next push gathers the page's Heroes.
      sessions.single
        ..related = [card(bv)]
        ..changed();
      await tester.pump();
      pushVideo(const VideoRoute(bvid: 'BV1xx411c7mD', start: 0, cover: cover));
      await frames(tester, 20);
      expect(tester.takeException(), isNull);
      await back(tester);
      expect(tester.takeException(), isNull);
      await back(tester);
    });

    testWidgets("leaving, the body's Heroes stand down so a related cover never flies back to a feed card",
        (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      sessions.single
        ..detail = detail(bv)
        ..related = [card('BV1xx411c7mD')]
        ..changed();
      await tester.pump();
      bool bodyFlies() => tester
          .widget<HeroMode>(find.ancestor(of: find.byType(PageTabs), matching: find.byType(HeroMode)).first)
          .enabled;
      expect(bodyFlies(), isTrue);
      unawaited(nav.currentState!.maybePop());
      await tester.pump();
      expect(bodyFlies(), isFalse);
      await frames(tester, 20);
    });

    testWidgets('item 38: a video page stacked on another (a space\'s video, opened from the page) pauses the first; '
        'back resumes it with no reload', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p2, start: 0));
      await opened(tester);
      final first = controller;
      final firstPlayer = player;
      player.emit(const StatusChanged(PlayerStatus.playing));
      position(30);
      final opens = first.opens;
      intro(tester).onOpenRelated(card('BV1xx411c7mD'));
      await frames(tester, 20);
      expect(find.byType(VideoPage, skipOffstage: false), findsNWidgets(2));
      expect(sessions, hasLength(2));
      expect(firstPlayer.calls.last, 'pip auto false');
      expect(firstPlayer.calls, contains('pause'));
      final top = tester.widget<VideoPage>(find.byType(VideoPage).last).route;
      expect((top.bvid, top.title, top.cover), ('BV1xx411c7mD', '相关视频', cover));

      await back(tester);
      expect(find.byType(VideoPage), findsOneWidget);
      expect(first.opens, opens, reason: 'nothing opened again');
      expect(sessions.first.active, isTrue);
      expect(first.page?.cid, p2, reason: 'the part it was on');
      expect(firstPlayer.calls.last, 'play');
      firstPlayer.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester);
      expect(first.phase, PlaybackPhase.playing);
      expect(find.byKey(const ValueKey('fake-video')), findsOneWidget);
      await back(tester);
      expect(first.video, isNull);
    });

    testWidgets('a related video takes the page\'s place, its cover flying in; three in a row still leave one page, '
        'and back goes straight to the page the first was opened from', (tester) async {
      replaceOnOpen();
      await host(tester, home: const Center(child: Text('首页')));
      pushVideo(const VideoRoute(bvid: bv, cid: p2, start: 0));
      await opened(tester);
      sessions.single
        ..detail = detail(bv)
        ..related = [card('BV1xx411c7mD')]
        ..changed();
      await tester.pump();
      final first = controller;
      intro(tester).onOpenRelated(card('BV1xx411c7mD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate((widget) => widget is RemoteImage && widget.placeholder != null),
        findsOneWidget,
        reason: 'the related row\'s cover flies into the new page\'s player',
      );
      expect(first.video, isNull, reason: 'the page replaced let its player go at once, as a popped one does');
      await frames(tester, 20);
      expect(find.byType(VideoPage, skipOffstage: false), findsOneWidget);
      final top = tester.widget<VideoPage>(find.byType(VideoPage)).route;
      expect((top.bvid, top.title, top.cover), ('BV1xx411c7mD', '相关视频', cover));
      expect(ModalRoute.of(tester.element(find.byType(VideoPage))), isA<SwipeBackPageRoute<void>>());

      for (final next in ['BV1aa411c7mD', 'BV1bb411c7mD']) {
        await opened(tester, page: sessions.length - 1);
        intro(tester).onOpenRelated(card(next));
        await frames(tester, 20);
        expect(find.byType(VideoPage, skipOffstage: false), findsOneWidget);
        expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.bvid, next);
      }
      expect(tester.takeException(), isNull);

      await back(tester);
      expect(find.byType(VideoPage, skipOffstage: false), findsNothing);
      expect(find.text('首页'), findsOneWidget);
      expect(nav.currentState!.canPop(), isFalse);
      expect(controllers.where((made) => made.video != null), isEmpty);
    });

    testWidgets('a video id in 简介 takes the page\'s place too', (tester) async {
      replaceOnOpen();
      await host(tester, home: const Center(child: Text('首页')));
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      intro(tester).onOpenVideo('BV1xx411c7mD');
      await frames(tester, 20);
      expect(find.byType(VideoPage, skipOffstage: false), findsOneWidget);
      expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.bvid, 'BV1xx411c7mD');
      await back(tester);
      expect(find.text('首页'), findsOneWidget);
      expect(nav.currentState!.canPop(), isFalse);
    });

    testWidgets('a sideways swipe over the tabs switches them; only the left edge goes back', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await tester.timedDragFrom(const Offset(300, 700), const Offset(-250, 0), const Duration(milliseconds: 200));
      await frames(tester, 20);
      expect(find.byType(VideoPage), findsOneWidget);
      expect(pager(tester).page, 1);
      await tester.timedDragFrom(const Offset(100, 700), const Offset(250, 0), const Duration(milliseconds: 200));
      await frames(tester, 20);
      expect(find.byType(VideoPage), findsOneWidget);
      expect(pager(tester).page, 0);
      await tester.timedDragFrom(const Offset(5, 700), const Offset(300, 0), const Duration(milliseconds: 200));
      await frames(tester, 20);
      expect(find.byType(VideoPage), findsNothing, reason: 'the edge swipe went back, not to the other tab');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('the page doesn\'t resize for the keyboard: the composer rides on it by itself', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      expect(tester.widget<Scaffold>(find.byType(Scaffold).last).resizeToAvoidBottomInset, isFalse);
      final tabs = tester.getRect(find.byType(PageTabs));
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await frames(tester, 2);
      expect(area(tester), const Rect.fromLTWH(0, 62, 440, 247.5));
      expect(tester.getRect(find.byType(PageTabs)), tabs);
      await back(tester);
    });
  });

  group('the paused player shrinking to the 继续播放 bar (11, 12)', () {
    const full = 440 / BiliMetrics.videoAspect;
    const bar = CollapseTheme.barHeight;

    /// A page with a long 简介 and its video loaded and playing.
    Future<void> longPage(WidgetTester tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      sessions[0]
        ..detail = detail(bv)
        ..related = [for (var i = 0; i < 20; i++) quietCard('BV1r$i')]
        ..changed();
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 10);
    }

    Future<void> pause(WidgetTester tester) async {
      player.emit(const StatusChanged(PlayerStatus.paused));
      await frames(tester, 2);
    }

    ScrollPosition intro(WidgetTester tester) => tester
        .state<ScrollableState>(find.descendant(of: find.byType(IntroTab), matching: find.byType(Scrollable)).first)
        .position;

    Rect row(WidgetTester tester) => tester.getRect(find.byType(PageTabRow));

    double threadTop(WidgetTester tester) => tester.widget<CommentOverlays>(find.byType(CommentOverlays)).threadTop;

    double cornerOpacity(WidgetTester tester, String key) => tester
        .widget<AnimatedOpacity>(find.ancestor(of: find.byKey(ValueKey(key)), matching: find.byType(AnimatedOpacity)).first)
        .opacity;

    void press(WidgetTester tester, String key) {
      final node = tester.getSemantics(find.byKey(ValueKey(key)));
      node.owner!.performAction(node.id, SemanticsAction.tap);
    }

    Future<void> collapse(WidgetTester tester) async {
      await tester.timedDragFrom(const Offset(220, 800), const Offset(0, -500), const Duration(milliseconds: 300));
      await frames(tester, 10);
    }

    testWidgets('paused, a drag up shrinks the player finger for finger to the bar with 继续播放, the tab row and the '
        'content riding under it', (tester) async {
      await longPage(tester);
      await pause(tester);
      final gesture = await tester.startGesture(const Offset(220, 800));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      final scrolled = intro(tester).pixels;
      expect(scrolled, inExclusiveRange(30, 90));
      expect(area(tester), Rect.fromLTWH(0, 62, 440, full - scrolled));
      expect(row(tester).top, closeTo(62 + full - scrolled, 0.01), reason: 'attached under the player (11)');
      expect(tester.getTopLeft(find.byType(UploaderRow)).dy, closeTo(row(tester).bottom, 0.01));
      expect(threadTop(tester), closeTo(62 + full - scrolled, 0.01), reason: '评论详情 rises to the live height');
      expect(find.text('继续播放'), findsOneWidget);
      expect(cornerOpacity(tester, 'collapse-back'), 0, reason: '‹ and ⋮ only once it is the bar');

      await gesture.moveBy(const Offset(0, -400));
      await tester.pump();
      await gesture.up();
      await frames(tester, 10);
      expect(area(tester).top, 62);
      expect(area(tester).height, closeTo(bar, 1e-9));
      expect(row(tester).top, closeTo(62 + bar, 0.01));
      expect(threadTop(tester), closeTo(62 + bar, 0.01));
      expect(cornerOpacity(tester, 'collapse-back'), 1);
      expect(cornerOpacity(tester, 'collapse-more'), 1);
      expect(find.byType(PortraitControls), findsNothing, reason: 'the small player\'s own controls are away');
      expect(ui(tester).chrome.visible, isFalse);
      expect(find.byType(VideoPage), findsOneWidget);
      await back(tester);
    });

    testWidgets('playing, the player never shrinks: the page scrolls under it', (tester) async {
      await longPage(tester);
      await collapse(tester);
      expect(intro(tester).pixels, greaterThan(300));
      expect(area(tester), const Rect.fromLTWH(0, 62, 440, full));
      expect(row(tester).top, 62 + full);
      expect(threadTop(tester), 62 + full);
      expect(find.text('继续播放'), findsNothing);
      await back(tester);
    });

    testWidgets('at the end the player keeps its height, so the end screen stays seen', (tester) async {
      await longPage(tester);
      await pause(tester);
      sessions[0]
        ..ended = true
        ..changed();
      await frames(tester, 2);
      await collapse(tester);
      expect(intro(tester).pixels, greaterThan(300));
      expect(area(tester).height, full);
      expect(find.byType(EndScreenPortrait), findsOneWidget);
      expect(find.text('继续播放'), findsNothing);
      await back(tester);
    });

    testWidgets('a 3:4 video makes the small player 440 × 586.67 under the status bar (17); playing, a scroll takes it '
        'to 16:9 (21), and the end screen takes 16:9 (18)', (tester) async {
      const tall = 440 * 4 / 3;
      await longPage(tester);
      sessions[0]
        ..videoShape = (width: 1080, height: 1440)
        ..changed();
      await tester.pump();
      await tester.pump(CollapseTheme.reshape);
      expect(area(tester).top, 62);
      expect(area(tester).width, 440);
      expect(area(tester).height, closeTo(586.67, 0.005));
      expect(row(tester).top, closeTo(62 + tall, 0.01), reason: 'the tab row under it');

      await collapse(tester);
      expect(intro(tester).pixels, greaterThan(tall - full));
      expect(area(tester).height, closeTo(full, 1e-9));
      expect(row(tester).top, closeTo(62 + full, 0.01));
      expect(find.text('继续播放'), findsNothing);

      intro(tester).jumpTo(0);
      await tester.pump();
      expect(area(tester).height, closeTo(tall, 1e-9));
      sessions[0]
        ..ended = true
        ..changed();
      await tester.pump();
      await tester.pump(CollapseTheme.reshape);
      expect(area(tester).height, closeTo(full, 1e-9));
      expect(find.byType(EndScreenPortrait), findsOneWidget);
      await back(tester);
    });

    testWidgets('paused halfway down the page, it shrinks only by what is scrolled after', (tester) async {
      await longPage(tester);
      intro(tester).jumpTo(400);
      await pause(tester);
      expect(area(tester).height, full);
      intro(tester).jumpTo(450);
      await tester.pump();
      expect(area(tester).height, full - 50);
      expect(threadTop(tester), 62 + full - 50);
      await back(tester);
    });

    testWidgets('a tap on the bar scrolls the tab back to its top and plays; the player grows back with it', (
      tester,
    ) async {
      await longPage(tester);
      await pause(tester);
      await collapse(tester);
      expect(area(tester).height, closeTo(bar, 1e-9));
      final calls = sessions[0].calls.length;
      await tester.tap(find.byKey(const ValueKey('collapse-resume')));
      await tester.pump();
      expect(sessions[0].calls.sublist(calls), ['togglePlay']);
      await tester.pump(CollapseTheme.resume ~/ 2);
      final halfway = intro(tester).pixels;
      expect(halfway, greaterThan(0), reason: 'on its way up');
      expect(area(tester).height, greaterThan(bar));
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 10);
      expect(intro(tester).pixels, 0);
      expect(area(tester), const Rect.fromLTWH(0, 62, 440, full));
      expect(row(tester).top, 62 + full);
      expect(find.text('继续播放'), findsNothing);
      expect(ui(tester).chrome.visible, isTrue, reason: 'the controls come back as they were when it shrank');
      await back(tester);
    });

    testWidgets('with Reduce Motion 继续播放 goes back to the top at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await longPage(tester);
      await pause(tester);
      await collapse(tester);
      await tester.tap(find.byKey(const ValueKey('collapse-resume')));
      await tester.pump();
      expect(intro(tester).pixels, 0);
      expect(area(tester).height, full);
      await back(tester);
    });

    testWidgets('on the bar ⋮ opens the small player\'s ⋮ panel and ‹ leaves the page; each answers an accessibility '
        'press', (tester) async {
      final handle = tester.ensureSemantics();
      await longPage(tester);
      await pause(tester);
      await collapse(tester);
      await tester.tap(find.byKey(const ValueKey('collapse-more')));
      await frames(tester, 4);
      expect(ui(tester).panels.value, PlayerPanel.more);
      ui(tester).panels.close();
      await frames(tester, 10);

      final calls = sessions[0].calls.length;
      press(tester, 'collapse-resume');
      await tester.pump();
      expect(sessions[0].calls.sublist(calls), ['togglePlay']);
      await frames(tester, 10);
      expect(intro(tester).pixels, 0);

      await collapse(tester);
      press(tester, 'collapse-more');
      await frames(tester, 4);
      expect(ui(tester).panels.value, PlayerPanel.more);
      ui(tester).panels.close();
      await frames(tester, 10);
      press(tester, 'collapse-back');
      await frames(tester, 20);
      expect(find.byType(VideoPage), findsNothing);
      handle.dispose();
    });

    testWidgets('full screen is unchanged: the player fills it with no bar, and is the bar again back inline', (
      tester,
    ) async {
      await longPage(tester);
      await pause(tester);
      await collapse(tester);
      await rotate(tester, Presentation.landscape);
      expect(area(tester), const Rect.fromLTWH(0, 0, 956, 440));
      expect(find.text('继续播放'), findsNothing);
      expect(find.byType(LandscapeChrome), findsOneWidget);
      await rotate(tester, Presentation.inline);
      await frames(tester, 2);
      expect(area(tester).height, closeTo(bar, 1e-9));
      expect(find.text('继续播放'), findsOneWidget);
      await back(tester);
    });
  });

  group('评论 in the page', () {
    late FakePageApi api;

    setUp(() {
      final reply1 = comment(201, root: 100, parent: 100);
      final reply2 = comment(202, root: 100, parent: 100);
      api = FakePageApi()
        ..commentList = [
          comment(100, replyCount: 2, preview: [reply1, reply2]),
          for (var i = 1; i <= 25; i++) comment(300 + i),
        ]
        ..threadReplies = {
          100: [reply1, reply2],
        };
    });

    Future<void> showComments(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('tab-comments')));
      await frames(tester, 20);
    }

    /// A page with its detail in, shown on 评论 with the first page loaded.
    Future<void> onComments(WidgetTester tester, {bool loggedIn = true}) async {
      await host(tester, loggedIn: loggedIn, pageApi: api);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      sessions.first
        ..detail = detail(bv, reply: 27)
        ..changed();
      await tester.pump();
      await showComments(tester);
    }

    CommentsModel model(WidgetTester tester) =>
        tester.widget<CommentsTab>(find.byType(CommentsTab, skipOffstage: false)).model;
    Finder row(int rpid) => find.byKey(ValueKey(rpid));
    Finder inRow(int rpid, String key) => find.descendant(of: row(rpid), matching: find.byKey(ValueKey(key)));
    PageController pager(WidgetTester tester) =>
        tester.widget<PageView>(find.byKey(const ValueKey('page-tabs')).last).controller!;

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const ValueKey('composer-field')), text);
      await tester.pump();
    }

    Future<void> publish(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('发布'));
      await frames(tester, 20);
    }

    Future<void> openBar(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('comment-bar')).first);
      await frames(tester);
    }

    Future<void> openThread(WidgetTester tester) async {
      await tester.tap(inRow(100, 'comment-replies'));
      await frames(tester, 20);
      expect(find.byType(ThreadView), findsOneWidget);
    }

    Future<void> deleteRow(WidgetTester tester, int rpid) async {
      await tester.tap(inRow(rpid, 'comment-more'));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('comment-delete')));
      await frames(tester);
      expect(find.text('确定删除这条评论吗？'), findsOneWidget);
      expect(row(rpid), findsOneWidget, reason: 'nothing goes before the answer');
      await tester.tap(find.byKey(const ValueKey('comment-delete-删除')));
      await frames(tester);
    }

    bool disposed(ChangeNotifier notifier) {
      try {
        ChangeNotifier.debugAssertNotDisposed(notifier);
        return false;
      } catch (_) {
        return true;
      }
    }

    testWidgets('回复 on a row opens the composer for it; the reply posts with root and parent the row', (tester) async {
      await onComments(tester);
      await tester.tap(inRow(100, 'comment-reply').first);
      await frames(tester);
      expect(find.byType(Composer), findsOneWidget);
      expect(find.text('回复 测试用户100 :'), findsOneWidget);
      await type(tester, '你好');
      await publish(tester);
      expect((api.posts.single.root, api.posts.single.parent), (100, 100));
      expect(find.byType(Composer), findsNothing);
      expect(model(tester).comments.first.replyCount, 3);
      await back(tester);
    });

    testWidgets('the 发条评论 bar posts to the video and the comment lands first', (tester) async {
      await onComments(tester);
      await openBar(tester);
      await type(tester, '第一');
      await publish(tester);
      expect(api.posts.single.root, 0);
      final first = model(tester).comments.first;
      expect(first.message, '第一');
      expect(tester.widgetList<CommentRow>(find.byType(CommentRow)).first.comment.rpid, first.rpid);
      await back(tester);
    });

    testWidgets('共N条回复 opens 评论详情; a reply there says 回复 @name : and lands in the thread', (tester) async {
      await onComments(tester);
      await openThread(tester);
      final inThread = find.descendant(of: find.byType(ThreadView), matching: row(202));
      await tester.tap(find.descendant(of: inThread, matching: find.byKey(const ValueKey('comment-reply'))));
      await frames(tester);
      expect(find.text('回复 测试用户202 :'), findsOneWidget);
      await type(tester, '同意');
      await publish(tester);
      expect(
        (api.posts.single.message, api.posts.single.root, api.posts.single.parent),
        ('回复 @测试用户202 :同意', 100, 202),
      );
      expect(model(tester).thread!.replies.first.message, '回复 @测试用户202 :同意');
      expect(find.byType(ThreadView), findsOneWidget, reason: 'the thread stays open');

      await tester.tap(
        find.descendant(of: find.byType(ThreadView), matching: find.byKey(const ValueKey('comment-bar'))),
      );
      await frames(tester);
      expect(find.text('回复 测试用户100 :'), findsOneWidget);
      await type(tester, '楼主好');
      await publish(tester);
      expect((api.posts.last.root, api.posts.last.parent, api.posts.last.message), (100, 100, '楼主好'));
      expect(model(tester).thread!.replies.first.message, '楼主好');
      await back(tester);
      await back(tester);
    });

    testWidgets('a draft survives a tap on the dim and back, and back closes the composer, not the page', (
      tester,
    ) async {
      await onComments(tester);
      await openBar(tester);
      await type(tester, '草稿');
      await tester.tap(find.byKey(const ValueKey('composer-dim')), warnIfMissed: false);
      await frames(tester);
      expect(find.byType(Composer), findsNothing);
      await openBar(tester);
      expect(find.text('草稿'), findsOneWidget);
      unawaited(nav.currentState!.maybePop());
      await frames(tester);
      expect(find.byType(Composer), findsNothing);
      expect(find.byType(VideoPage), findsOneWidget);
      await openBar(tester);
      expect(find.text('草稿'), findsOneWidget);
      await back(tester);
      await back(tester);
    });

    testWidgets('back while a post is out leaves the composer up; a failed post then shows with its text', (
      tester,
    ) async {
      await onComments(tester);
      await openBar(tester);
      final hold = api.holds['postComment'] = Completer<void>();
      api.failures['postComment'] = StateError('down');
      await type(tester, '你好');
      await tester.tap(find.bySemanticsLabel('发布'));
      await frames(tester, 2);
      expect(model(tester).drafts.anyPosting, isTrue);
      unawaited(nav.currentState!.maybePop());
      await frames(tester, 2);
      ui(tester).onBack();
      await frames(tester, 2);
      expect(find.byType(Composer), findsOneWidget);
      expect(find.byType(VideoPage), findsOneWidget);
      hold.complete();
      await frames(tester);
      expect(find.byType(Composer), findsOneWidget);
      expect(find.text('你好'), findsOneWidget, reason: 'the text stays for another try');
      await frames(tester, 60);
      await back(tester);
      expect(find.byType(Composer), findsNothing, reason: 'with nothing posting, back closes it');
      await back(tester);
    });

    testWidgets('turning sideways with the composer up puts it and the keyboard away; the draft is kept', (
      tester,
    ) async {
      await onComments(tester);
      await openBar(tester);
      expect(tester.testTextInput.isVisible, isTrue, reason: 'it opens with the keyboard');
      await type(tester, '横屏前');
      await rotate(tester, Presentation.landscape);
      await frames(tester);
      expect(orientation.presentation, Presentation.landscape);
      expect(tester.testTextInput.isVisible, isFalse, reason: 'no keyboard over the full-screen video');
      expect(find.byType(Composer, skipOffstage: false), findsNothing);
      await rotate(tester, Presentation.inline);
      await frames(tester);
      await openBar(tester);
      expect(find.text('横屏前'), findsOneWidget);
      await back(tester);
      await back(tester);
    });

    testWidgets('a picture opens the viewer, which pages at a thumb\'s speed and closes on a tap', (tester) async {
      api.commentList = [
        Comment(
          rpid: 100,
          member: const CommentMember(mid: 2001, name: '测试用户100', level: 5),
          message: '两张图',
          pictures: const [
            CommentPicture(url: '', width: 100, height: 100),
            CommentPicture(url: '', width: 100, height: 100),
          ],
        ),
      ];
      await onComments(tester);
      await tester.tap(find.byKey(const ValueKey('comment-picture-0')));
      await frames(tester);
      expect(find.byType(PictureViewer), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      await tester.timedDragFrom(const Offset(300, 478), const Offset(-300, 0), const Duration(milliseconds: 200));
      await frames(tester, 20);
      expect(find.text('2/2'), findsOneWidget);
      expect(pager(tester).page, 1, reason: 'the tabs behind it stayed');
      // The tap closes only once the double tap's window (~300 ms) and the fade (200 ms) have passed.
      await tester.tapAt(const Offset(220, 478));
      await frames(tester, 20);
      expect(find.byType(PictureViewer), findsNothing);
      expect(find.byType(VideoPage), findsOneWidget);
      await back(tester);
    });

    testWidgets('⋮ → 删除 on your own comment asks first, then removes it', (tester) async {
      await host(tester, pageApi: api);
      api.commentList = [comment(100, mid: environment.mid!), comment(101)];
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await showComments(tester);
      await deleteRow(tester, 100);
      expect(row(100), findsNothing);
      expect(api.calls, contains('deleteComment rpid=100'));
      await back(tester);
    });

    testWidgets('logged out, 回复 asks for the login and opens nothing', (tester) async {
      await onComments(tester, loggedIn: false);
      await tester.tap(inRow(100, 'comment-reply').first);
      await frames(tester, 5);
      expect(find.byType(Composer), findsNothing);
      expect(gate.asks, hasLength(1));
      expect(find.text('请先登录'), findsNothing);
      gate.answer(false);
      await frames(tester, 2);
      expect(find.byType(Composer), findsNothing, reason: 'nothing pressed is replayed');
      await back(tester);
    });

    testWidgets('a timestamp in a comment seeks the page\'s player; a BV id opens a page on top', (tester) async {
      api.commentList = [
        Comment(
          rpid: 100,
          member: const CommentMember(mid: 2001, name: '测试用户100', level: 5),
          message: '看 1:02 和 BV1xx411c7mD',
          runs: const [
            RichRun.text('看 '),
            RichRun.timestamp(label: '1:02', seconds: 62),
            RichRun.text(' 和 '),
            RichRun.video(id: 'BV1xx411c7mD'),
          ],
        ),
      ];
      await onComments(tester);
      sessions.first.duration.value = 712;
      await tester.tapOnText(find.textRange.ofSubstring('1:02'));
      await frames(tester, 5);
      expect(sessions.first.calls, contains('commitSeek 62.0'));
      await tester.tapOnText(find.textRange.ofSubstring('BV1xx411c7mD'));
      await frames(tester, 20);
      expect(find.byType(VideoPage, skipOffstage: false), findsNWidgets(2));
      await back(tester);
      await back(tester);
    });

    testWidgets('the model goes with the page when it is popped', (tester) async {
      await onComments(tester);
      final comments = model(tester);
      await back(tester);
      expect(find.byType(VideoPage), findsNothing);
      expect(disposed(comments), isTrue);
    });

    testWidgets('another video on the page frees the old model and closes its thread and composer; drafts stay', (
      tester,
    ) async {
      await onComments(tester);
      final first = model(tester);
      await openThread(tester);
      await tester.tap(find.byKey(const ValueKey('comment-bar')).last);
      await frames(tester);
      await type(tester, '给第一个视频');
      sessions.first
        ..detail = detail('BV1xx411c7mD', aid: 2)
        ..changed();
      await frames(tester);
      expect(disposed(first), isTrue);
      expect(model(tester).aid, 2);
      expect(find.byType(ThreadView), findsNothing);
      expect(find.byType(Composer), findsNothing);
      sessions.first
        ..detail = detail(bv)
        ..changed();
      await frames(tester);
      await openThread(tester);
      await tester.tap(find.byKey(const ValueKey('comment-bar')).last);
      await frames(tester);
      expect(find.text('给第一个视频'), findsOneWidget, reason: 'the thread bar\'s draft is kept by its root');
      await back(tester);
      await back(tester);
      await back(tester);
    });

    testWidgets('评论 N shows the video\'s count, then the list\'s once loaded, following a post and a delete', (
      tester,
    ) async {
      await host(tester, pageApi: api);
      api.commentList = [comment(100, mid: environment.mid!), comment(101)];
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      sessions.first
        ..detail = detail(bv, reply: 27)
        ..changed();
      await tester.pump();
      expect(find.bySemanticsLabel('评论 27'), findsOneWidget);
      expect(ui(tester).replies, 27, reason: "full screen's 评论 reads what the tab row does");
      await showComments(tester);
      expect(find.bySemanticsLabel('评论 2'), findsOneWidget);
      expect(ui(tester).replies, 2);
      await openBar(tester);
      await type(tester, '第三条');
      await publish(tester);
      expect(find.bySemanticsLabel('评论 3'), findsOneWidget);
      expect(ui(tester).replies, 3);
      await deleteRow(tester, 100);
      expect(find.bySemanticsLabel('评论 2'), findsOneWidget);
      expect(ui(tester).replies, 2);
      await back(tester);
    });

    testWidgets('another sort keeps 评论 N while its first page loads', (tester) async {
      await host(tester, pageApi: api);
      api.commentList = [comment(100), comment(101)];
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      sessions.first
        ..detail = detail(bv, reply: 27)
        ..changed();
      await tester.pump();
      await showComments(tester);
      expect(find.bySemanticsLabel('评论 2'), findsOneWidget);
      final hold = api.holds['comments'] = Completer<void>();
      unawaited(model(tester).setSort(CommentSort.time));
      await frames(tester);
      expect(find.bySemanticsLabel('评论 2'), findsOneWidget, reason: 'not back to the video\'s 27');
      hold.complete();
      await frames(tester, 10);
      await back(tester);
    });

    testWidgets('the status bar\'s tap leaves the list under 评论详情 where it is', (tester) async {
      await onComments(tester);
      await openThread(tester);
      final list = tester
          .state<ScrollableState>(
            find.descendant(of: find.byType(CommentsTab), matching: find.byType(Scrollable), skipOffstage: false).first,
          )
          .position
        ..jumpTo(200);
      await tester.pump();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.statusBar.name,
        SystemChannels.statusBar.codec.encodeMethodCall(const MethodCall('handleScrollToTop')),
        (_) {},
      );
      await frames(tester, 30);
      expect(list.pixels, 200);
      expect(find.byType(ThreadView), findsOneWidget);
      await back(tester);
      await back(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('with no detail, 评论 opens on the view\'s aid; the detail\'s uploader then marks the same model', (
      tester,
    ) async {
      await host(tester, pageApi: api);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      expect(sessions.first.detail, isNull);
      expect(controller.video?.aid, 80433022);
      await showComments(tester);
      expect(find.byType(CommentsSlot), findsNothing, reason: 'no endless spinner');
      final comments = model(tester);
      expect((comments.aid, comments.upMid), (80433022, 0));
      expect(row(100), findsOneWidget);
      sessions.first
        ..detail = detail(bv, aid: 80433022, ownerMid: 77)
        ..changed();
      await tester.pump();
      expect(model(tester), same(comments));
      expect(comments.upMid, 77);
      await back(tester);
    });

    testWidgets('the app\'s own session with a view and no signed detail (an av id, a pasted av link): 评论 loads', (
      tester,
    ) async {
      await host(tester, pageApi: api);
      const view = core.VideoView(
        bvid: bv,
        aid: 80433022,
        title: '测试视频',
        owner: 'UP主',
        pages: [core.VideoPage(cid: p1, page: 1, part: '第一集', duration: 712)],
      );
      unawaited(
        nav.currentState!.push(
          SwipeBackPageRoute<void>(
            builder: (_) => VideoPage(
              route: const VideoRoute(bvid: bv, cid: p1, start: 0, view: view),
              createDetails: fakeDetails,
            ),
          ),
        ),
      );
      await frames(tester, 30);
      await tester.tap(find.byKey(const ValueKey('tab-comments')));
      await frames(tester, 30);
      expect(find.byType(CommentsSlot), findsNothing);
      expect(model(tester).aid, 80433022);
      await back(tester);
    });

    group('gestures at a thumb\'s speed (about 1500 px/s)', () {
      testWidgets('item 74: on 评论 a swipe over a row pages to 简介 and back; item 76: only the left edge leaves', (
        tester,
      ) async {
        await onComments(tester);
        expect(pager(tester).page, 1);
        await tester.timedDragFrom(const Offset(150, 600), const Offset(300, 0), const Duration(milliseconds: 200));
        await frames(tester, 20);
        expect(find.byType(VideoPage), findsOneWidget);
        expect(pager(tester).page, 0);
        await tester.timedDragFrom(const Offset(250, 600), const Offset(-300, 0), const Duration(milliseconds: 200));
        await frames(tester, 20);
        expect(pager(tester).page, 1);
        await tester.timedDragFrom(const Offset(5, 600), const Offset(300, 0), const Duration(milliseconds: 200));
        await frames(tester, 20);
        expect(find.byType(VideoPage), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('评论详情: a swipe from the middle does nothing; from the edge it closes and the page stays', (
        tester,
      ) async {
        await onComments(tester);
        await openThread(tester);
        await tester.timedDragFrom(const Offset(150, 700), const Offset(300, 0), const Duration(milliseconds: 200));
        await frames(tester, 20);
        expect(model(tester).thread, isNotNull);
        expect(pager(tester).page, 1, reason: 'the tabs behind it did not page');
        await tester.timedDragFrom(const Offset(5, 700), const Offset(300, 0), const Duration(milliseconds: 200));
        await frames(tester, 20);
        expect(model(tester).thread, isNull);
        expect(find.byType(ThreadView), findsNothing);
        expect(find.byType(VideoPage), findsOneWidget);
        expect(pager(tester).page, 1);
        await back(tester);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('评论详情 open: a left-edge drag on the small player leaves the seek alone; one from inside seeks', (
        tester,
      ) async {
        await onComments(tester);
        sessions.first.duration.value = 712;
        await openThread(tester);
        Iterable<String> scrubs() => sessions.first.calls.where((call) => call.startsWith('scrub'));
        await tester.timedDragFrom(const Offset(5, 180), const Offset(300, 0), const Duration(milliseconds: 200));
        await frames(tester, 20);
        expect(scrubs(), isEmpty);
        expect(find.byType(VideoPage), findsOneWidget);
        await tester.timedDragFrom(const Offset(100, 180), const Offset(200, 0), const Duration(milliseconds: 200));
        await frames(tester, 20);
        expect(scrubs(), isNotEmpty);
        await back(tester);
        await back(tester);
      });
    });

    testWidgets('item 50: paused, scrolling 评论详情 leaves the player its height; scrolling 评论 shrinks it', (
      tester,
    ) async {
      api.threadReplies = {
        100: [for (var i = 0; i < 20; i++) comment(500 + i, root: 100, parent: 100)],
      };
      api.commentList = [
        comment(100, replyCount: 20, preview: api.threadReplies[100]!.take(2).toList()),
        for (var i = 1; i <= 25; i++) comment(300 + i),
      ];
      await onComments(tester);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 2);
      player.emit(const StatusChanged(PlayerStatus.paused));
      await frames(tester, 2);
      final full = area(tester).height;
      await openThread(tester);
      await tester.timedDragFrom(const Offset(220, 800), const Offset(0, -500), const Duration(milliseconds: 300));
      await frames(tester, 20);
      expect(area(tester).height, full, reason: 'the thread scrolls under a player of full height');
      await back(tester);
      expect(model(tester).thread, isNull);
      await tester.timedDragFrom(const Offset(220, 800), const Offset(0, -500), const Duration(milliseconds: 300));
      await frames(tester, 20);
      expect(area(tester).height, lessThan(full));
      expect(find.text('继续播放'), findsOneWidget);
      await back(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('the page around the tabs', () {
    Future<void> longIntro(WidgetTester tester) async {
      sessions.first
        ..detail = detail(bv)
        ..related = [for (var i = 0; i < 20; i++) quietCard('BV1r$i')]
        ..changed();
      await frames(tester, 2);
    }

    ScrollPosition scrollIn(WidgetTester tester, Type tab) => tester
        .state<ScrollableState>(find.descendant(of: find.byType(tab), matching: find.byType(Scrollable)).first)
        .position;

    Future<void> tapStatusBar(WidgetTester tester) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.statusBar.name,
        SystemChannels.statusBar.codec.encodeMethodCall(const MethodCall('handleScrollToTop')),
        (_) {},
      );
      await frames(tester, 30);
    }

    testWidgets('a tap on the status bar scrolls the shown tab back to its top', (tester) async {
      final api = FakePageApi()..commentList = [for (var i = 1; i <= 25; i++) comment(300 + i)];
      await host(tester, pageApi: api);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await longIntro(tester);
      final intro = scrollIn(tester, IntroTab)..jumpTo(400);
      await tester.pump();
      await tapStatusBar(tester);
      expect(intro.pixels, 0);

      await tester.tap(find.byKey(const ValueKey('tab-comments')));
      await frames(tester, 20);
      final comments = scrollIn(tester, CommentsTab)..jumpTo(300);
      intro.jumpTo(200);
      await tester.pump();
      await tapStatusBar(tester);
      expect(comments.pixels, 0);
      expect(intro.pixels, 200, reason: 'only the shown tab');
      await back(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the composer and the panels take no primary scroll controller', (tester) async {
      await host(tester, pageApi: FakePageApi());
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      ui(tester).panels.open(PlayerPanel.more);
      await frames(tester);
      expect(PrimaryScrollController.maybeOf(tester.element(find.byKey(const ValueKey('panel-frame')))), isNull);
      ui(tester).panels.close();
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('tab-comments')));
      await frames(tester, 20);
      await tester.tap(find.byKey(const ValueKey('comment-bar')).first);
      await frames(tester);
      expect(PrimaryScrollController.maybeOf(tester.element(find.byType(Composer))), isNull);
      expect(
        PrimaryScrollController.maybeOf(tester.element(find.byType(Scaffold).last)),
        same(tester.widget<PageTabs>(find.byType(PageTabs)).controller.scrollOf(PageTab.comments)),
      );
      await back(tester);
      await back(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the 合集 sheet starts at the shrunk player\'s bottom, so nothing undimmed shows between them', (
      tester,
    ) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await longIntro(tester);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 2);
      player.emit(const StatusChanged(PlayerStatus.paused));
      await frames(tester, 2);
      scrollIn(tester, IntroTab).jumpTo(100);
      await tester.pump();
      final bottom = area(tester).bottom;
      expect(bottom, closeTo(62 + 440 / BiliMetrics.videoAspect - 100, 0.01));
      ui(tester).panels.open(PlayerPanel.episodes);
      await frames(tester);
      expect(tester.getRect(find.byKey(const ValueKey('panel-sheet-dim'))).top, closeTo(bottom, 0.01));
      ui(tester).panels.close();
      await frames(tester);
      await back(tester);
    });
  });

  group('logging in from the page (BiliNative LoginGate, checklist item 59)', () {
    late FakePageApi api;
    VoidCallback? sessionLogin;
    final reduceMotion = ValueVariant<bool>({false, true});

    /// What went to Bilibili on the account's behalf, leaving out the page's own loads.
    const accountCalls = [
      'like',
      'dislike',
      'triple',
      'coin',
      'favourite',
      'updateFavourites',
      'createFolder',
      'follow',
      'favSeason',
      'addToWatchLater',
      'postComment',
      'likeComment',
      'hateComment',
      'deleteComment',
      'addBlockRule',
      'deleteBlockRule',
      'postDanmaku',
      'likeDanmaku',
    ];
    List<String> sent() => [
      for (final call in api.calls)
        if (accountCalls.any(call.startsWith)) call,
    ];
    int relations() => api.calls.where((call) => call == 'relation').length;

    setUp(() {
      api = FakePageApi()..commentList = [comment(100), comment(101)];
      sessionLogin = null;
    });

    PlayerSession recordingSession({
      required PlaybackController controller,
      required AppServices services,
      required SessionOpen open,
      required void Function(double seconds) onSeeked,
      required VoidCallback requestLogin,
      required VoidCallback willPlay,
    }) {
      sessionLogin = requestLogin;
      return fakeSession(
        controller: controller,
        services: services,
        open: open,
        onSeeked: onSeeked,
        requestLogin: requestLogin,
        willPlay: willPlay,
      );
    }

    /// The page with the app's own details, actions and comments over [api], its video's detail in, on 简介. Not
    /// logged in, the jar keeps cookies Bilibili no longer takes, so the video still opens and the page owns the
    /// orientation.
    Future<void> openReal(
      WidgetTester tester, {
      bool loggedIn = false,
      bool vertical = false,
      bool checkAccount = true,
      AppAuth? appAuth,
    }) async {
      if (!loggedIn) http.routes[Canned.navPath] = (200, Canned.navLoggedOut);
      await host(tester, pageApi: api, checkAccount: checkAccount, appAuth: appAuth);
      if (checkAccount) expect(environment.account, loggedIn ? isA<LoggedIn>() : isA<LoginExpired>());
      unawaited(
        nav.currentState!.push(
          SwipeBackPageRoute<void>(
            builder: (_) => VideoPage(
              route: const VideoRoute(bvid: bv, cid: p1, start: 0),
              createSession: recordingSession,
              openPage: openPage,
            ),
          ),
        ),
      );
      await opened(tester, vertical: vertical);
      sessions.first
        ..detail = detail(bv, aid: 7, ownerMid: 9, reply: 2)
        ..changed();
      await frames(tester, 4);
    }

    VideoActions actions(WidgetTester tester) => ui(tester).details!.actions!;
    Finder inRow(int rpid, String key) =>
        find.descendant(of: find.byKey(ValueKey(rpid)), matching: find.byKey(ValueKey(key)));

    testWidgets('logged out, each action asks the login page once, toasts nothing and sends nothing', (tester) async {
      await openReal(tester);
      var asked = 0;
      Future<void> press(String what, FutureOr<void> Function() action) async {
        await action();
        await frames(tester, 3);
        asked += 1;
        expect(gate.asks, hasLength(asked), reason: what);
        expect(gate.asks.last.presentation, Presentation.inline, reason: what);
        expect(find.text('请先登录'), findsNothing, reason: what);
        gate.answer(false);
        await frames(tester, 2);
      }

      await press('点赞', () => tester.tap(find.byKey(const ValueKey('action-like'))));
      await press('不喜欢', () => tester.tap(find.byKey(const ValueKey('action-dislike'))));
      await press('三连, the hold', () => actions(tester).triple());
      await press('投币', () => tester.tap(find.byKey(const ValueKey('action-coin'))));
      await press('收藏', () => tester.tap(find.byKey(const ValueKey('action-favourite'))));
      await press('关注', () => actions(tester).tapFollow());
      final intro = tester.widget<IntroTab>(find.byType(IntroTab));
      await press('a related row\'s 稍后再看', () => intro.onWatchLater(card('BV1xx')));
      await press('⋮\'s 稍后再看, through the session', () => sessionLogin!());
      await press('点我发弹幕', () => tester.tap(find.byKey(const ValueKey('danmaku-send'))));
      await press('当前弹幕列表\'s 👍 and 添加屏蔽词, through the danmaku', () => ui(tester).danmaku!.requestLogin());
      expect(find.byType(CoinDialog), findsNothing);
      expect(find.byType(FavouriteSheet), findsNothing);
      expect(ui(tester).danmaku!.sendOpen.value, isFalse);

      await tester.tap(find.byKey(const ValueKey('tab-comments')));
      await frames(tester, 20);
      await press('the composer', () => tester.tap(find.byKey(const ValueKey('comment-bar')).first));
      expect(find.byType(Composer), findsNothing);
      await press('a comment\'s 👍', () => tester.tap(inRow(100, 'comment-like').first));
      await press('a comment\'s 踩', () => tester.tap(inRow(100, 'comment-dislike').first));
      expect(sent(), isEmpty);
      expect(relations(), 0);
      await back(tester);
    });

    testWidgets('an account still unknown is asked again before the login page, which shows only for logged out',
        (tester) async {
      await openReal(tester, loggedIn: true, checkAccount: false);
      expect(environment.account, isA<AccountUnknown>());
      await tester.tap(find.byKey(const ValueKey('action-like')));
      await frames(tester, 3);
      expect(gate.asks, isEmpty, reason: 'the check found the login');
      expect(environment.account, isA<LoggedIn>());
      await back(tester);
    });

    testWidgets('an account check that still fails says so instead of offering a second login', (tester) async {
      await openReal(tester, loggedIn: true, checkAccount: false);
      http.routes.remove(Canned.navPath);
      await tester.tap(find.byKey(const ValueKey('action-like')));
      await frames(tester, 3);
      expect(gate.asks, isEmpty);
      expect(find.text('账号确认失败，请稍后重试'), findsOneWidget);
      expect(sent(), isEmpty);
      await frames(tester, 60);
      await back(tester);
    });

    testWidgets('logged in without the app token, 不喜欢 asks for it on the app\'s navigator, then goes out (88, 89)',
        (tester) async {
      final auth = _RecordingAppAuth();
      await openReal(tester, loggedIn: true, appAuth: auth);
      await tester.tap(find.byKey(const ValueKey('action-dislike')));
      await frames(tester, 3);
      expect(auth.asks, [true]);
      expect(gate.asks, isEmpty);
      expect(sent(), ['dislike on=true']);
      expect(actions(tester).disliked, isTrue);
      expect(find.text('感谢反馈'), findsOneWidget);
      await frames(tester, 60);

      await tester.tap(find.byKey(const ValueKey('action-dislike')));
      await frames(tester, 3);
      expect(auth.asks, hasLength(1), reason: 'the token is held now');
      expect(sent(), ['dislike on=true', 'dislike on=false']);
      expect(find.text('取消不喜欢'), findsOneWidget);
      await frames(tester, 60);
      await back(tester);
    });

    testWidgets('a confirm that gives no token leaves 不喜欢 off and sends nothing', (tester) async {
      final auth = _RecordingAppAuth(grants: false);
      await openReal(tester, loggedIn: true, appAuth: auth);
      await tester.tap(find.byKey(const ValueKey('action-dislike')));
      await frames(tester, 3);
      expect(auth.asks, [true]);
      expect(sent(), isEmpty);
      expect(actions(tester).disliked, isFalse);
      expect(gate.asks, isEmpty);
      await back(tester);
    });

    testWidgets('a second ask while the login page is up is the same ask', (tester) async {
      await openReal(tester);
      await tester.tap(find.byKey(const ValueKey('action-like')));
      await frames(tester, 3);
      await tester.tap(find.byKey(const ValueKey('danmaku-send')));
      await frames(tester, 3);
      expect(gate.asks, hasLength(1));
      gate.answer(false);
      await frames(tester, 2);
      await back(tester);
    });

    testWidgets('from landscape full screen the page turns upright first, then the login page shows', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
        disableAnimations: reduceMotion.currentValue!,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await openReal(tester);
      await rotate(tester, Presentation.landscape);
      expect(orientation.presentation, Presentation.landscape);
      orientation.log.clear();
      unawaited(actions(tester).toggleLike());
      await frames(tester, 4);
      expect(orientation.presentation, Presentation.inline);
      expect(gate.asks, isEmpty, reason: 'the screen is still sideways');

      screen(tester, portrait, portraitInsets);
      await tester.pump(const Duration(milliseconds: 100));
      expect(gate.asks, isEmpty, reason: 'the turn is still finishing');
      await frames(tester, 10);
      expect(gate.asks, [(presentation: Presentation.inline, screen: portrait)]);
      expect(orientation.log, ['end page1'], reason: 'the phone stays upright while the login page is up');

      gate.answer(false);
      await frames(tester, 2);
      expect(orientation.log, ['end page1', 'begin page1'], reason: 'turning works again once it closes');
      expect(orientation.presentation, Presentation.inline);
      expect(sent(), isEmpty);
      await back(tester);
    }, variant: reduceMotion);

    testWidgets('an action pressed while the screen is still turning back waits for upright before the login page', (
      tester,
    ) async {
      await openReal(tester);
      await rotate(tester, Presentation.landscape);
      orientation.exitToInline();
      await frames(tester, 2);
      expect(find.byType(LandscapeChrome), findsOneWidget, reason: 'laid out sideways until the screen turns');
      unawaited(actions(tester).toggleLike());
      await frames(tester, 4);
      expect(gate.asks, isEmpty, reason: 'the screen is still sideways');

      screen(tester, portrait, portraitInsets);
      await frames(tester, 12);
      expect(gate.asks, [(presentation: Presentation.inline, screen: portrait)]);
      gate.answer(false);
      await frames(tester, 2);
      expect(sent(), isEmpty);
      await back(tester);
    });

    testWidgets('a screen that never turns back still gets the login page, after 3 s', (tester) async {
      await openReal(tester);
      await rotate(tester, Presentation.landscape);
      unawaited(actions(tester).toggleLike());
      await frames(tester, 50);
      expect(gate.asks, isEmpty);
      await frames(tester, 20);
      expect(gate.asks, hasLength(1));
      gate.answer(false);
      screen(tester, portrait, portraitInsets);
      await frames(tester, 2);
      await back(tester);
    });

    testWidgets('from 竖屏 the page goes back to the small player and the login page shows at once', (tester) async {
      await openReal(tester, vertical: true);
      await rotate(tester, Presentation.vertical);
      expect(orientation.presentation, Presentation.vertical);
      unawaited(actions(tester).toggleLike());
      await frames(tester, 2);
      expect(gate.asks, [(presentation: Presentation.inline, screen: portrait)]);
      gate.answer(false);
      await frames(tester, 2);
      await back(tester);
    });

    testWidgets('Bilibili answering -101 asks the login page instead of a toast; the action goes back', (tester) async {
      await openReal(tester, loggedIn: true);
      const needsLogin = BiliError.api(code: -101, message: '账号未登录');
      api.failures
        ..['like'] = needsLogin
        ..['postDanmaku'] = needsLogin
        ..['likeComment'] = needsLogin;

      await tester.tap(find.byKey(const ValueKey('action-like')));
      await frames(tester, 3);
      expect(gate.asks, hasLength(1));
      expect(actions(tester).liked, isFalse);
      gate.answer(false);
      await frames(tester, 2);

      await tester.tap(find.byKey(const ValueKey('danmaku-send')));
      await frames(tester, 2);
      await tester.enterText(find.byKey(const ValueKey('danmaku-send-input')), '页面弹幕');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('danmaku-send-button')));
      await frames(tester, 4);
      expect(gate.asks, hasLength(2));
      expect(ui(tester).danmaku!.sendOpen.value, isFalse, reason: 'the send bar goes for the login page');
      expect(ui(tester).danmaku!.sender.text, '页面弹幕', reason: 'the draft stays');
      gate.answer(false);
      await frames(tester, 2);

      await tester.tap(find.byKey(const ValueKey('tab-comments')));
      await frames(tester, 20);
      await tester.tap(inRow(100, 'comment-like').first);
      await frames(tester, 3);
      expect(gate.asks, hasLength(3));
      gate.answer(false);
      await frames(tester, 2);
      expect(find.text('需要登录'), findsNothing);
      expect(find.text('账号未登录'), findsNothing);
      await back(tester);
    });

    testWidgets('a login after a -101 asks the relation again, and the pressed action is not sent again',
        (tester) async {
      await openReal(tester, loggedIn: true);
      expect(relations(), 1);
      api.failures['like'] = const BiliError.api(code: -101, message: '账号未登录');
      await tester.tap(find.byKey(const ValueKey('action-like')));
      await frames(tester, 3);
      expect(sent(), ['like on=true']);
      api.failures.remove('like');
      gate.answer(true);
      await frames(tester, 3);
      expect(relations(), 2);
      expect(sent(), ['like on=true'], reason: 'not replayed');
      await back(tester);
    });

    /// A page with the test's session and details, counting the logins it hands its details.
    Future<int Function()> countingLogins(WidgetTester tester) async {
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      var logins = 0;
      pageLogins!.addListener(() => logins += 1);
      return () => logins;
    }

    testWidgets('a -101 on a login the app still holds, its login page closed, is no new login', (tester) async {
      await host(tester);
      final logins = await countingLogins(tester);
      askLogin!();
      await frames(tester, 3);
      expect(gate.asks, hasLength(1), reason: 'the login page shows though the app thinks it is logged in');
      gate.answer(false);
      await frames(tester, 3);
      expect(environment.account, isA<LoggedIn>());
      expect(logins(), 0);

      askLogin!();
      await frames(tester, 3);
      gate.answer(true);
      await frames(tester, 3);
      expect(logins(), 1, reason: 'logging in again there is one');
      // The danmaku's block rules, asked again for the login, give up after 15 s with no route.
      await tester.pump(const Duration(seconds: 16));
      await back(tester);
    });

    testWidgets('the login page closed while it signs in: the login that lands still reaches the page',
        (tester) async {
      http = Canned.http(loggedIn: false)..routes[heartbeatPath] = (200, '{"code":0}');
      await host(tester);
      final logins = await countingLogins(tester);
      askLogin!();
      await frames(tester, 3);
      expect(gate.asks, hasLength(1));
      http.routes[Canned.navPath] = (200, Canned.navLoggedIn);
      final signingIn = environment.didLogin(Canned.cookies);
      expect(environment.account, isA<AccountUnknown>());
      gate.answer(false);
      await frames(tester, 2);
      expect(await signingIn, isTrue);
      await frames(tester, 3);
      expect(environment.account, isA<LoggedIn>());
      expect(logins(), 1);
      await tester.pump(const Duration(seconds: 16));
      await back(tester);
    });

    testWidgets('the login page closed with the sign-in turned down is no login', (tester) async {
      http = Canned.http(loggedIn: false)..routes[heartbeatPath] = (200, '{"code":0}');
      await host(tester);
      final logins = await countingLogins(tester);
      askLogin!();
      await frames(tester, 3);
      final signingIn = environment.didLogin(Canned.cookies);
      gate.answer(false);
      await frames(tester, 2);
      // didLogin's two retries wait 1 s and 2 s.
      await tester.pump(const Duration(seconds: 4));
      expect(await signingIn, isFalse);
      await frames(tester, 3);
      expect(logins(), 0);
      await back(tester);
    });

    testWidgets('a login page that can\'t open is logged and toasted', (tester) async {
      await openReal(tester);
      gate.failure = StateError('no navigator');
      await tester.tap(find.byKey(const ValueKey('action-like')));
      await frames(tester, 3);
      expect(gate.asks, hasLength(1));
      expect(find.text('无法打开登录'), findsOneWidget);
      gate.failure = null;
      await frames(tester, 60);
      await tester.tap(find.byKey(const ValueKey('action-like')));
      await frames(tester, 3);
      expect(gate.asks, hasLength(2), reason: 'the page can ask again');
      gate.answer(false);
      await frames(tester, 2);
      await back(tester);
    });

    testWidgets('logged out, a login asks the relation once for the new account', (tester) async {
      api.relationValue = const VideoRelation(like: true, dislike: false, favorite: false, attention: true, coins: 1);
      await openReal(tester);
      expect(relations(), 0);
      await tester.tap(find.byKey(const ValueKey('action-favourite')));
      await frames(tester, 3);
      expect(gate.asks, hasLength(1));
      // Bilibili answers slower than the login page pops.
      final answering = api.holds['relation'] = Completer<void>();
      gate.onLogin = environment.useFakeAccount;
      gate.answer(true);
      await frames(tester, 3);
      answering.complete();
      await frames(tester, 3);
      expect(relations(), 1, reason: 'the account changing and the page hearing the login make one ask');
      expect(actions(tester).liked, isTrue);
      expect(actions(tester).following, isTrue);
      expect(find.byType(FavouriteSheet), findsNothing, reason: 'nothing pressed is replayed');
      expect(sent(), isEmpty);
      await back(tester);
    });
  });

  group('danmaku through the page', () {
    /// Everything the page's feed holds, played from the start.
    List<DisplayDanmaku> feedItems() {
      final timeline = controller.danmaku.timeline;
      if (timeline == null) return const [];
      timeline.seek(-1);
      return [for (var ms = 999; ms < 20000; ms += 1000) ...timeline.advance(ms)];
    }

    Future<void> openPage(WidgetTester tester, {bool loggedIn = true, FakePageApi? api}) async {
      await host(tester, pageApi: api ?? FakePageApi(), loggedIn: loggedIn);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
    }

    testWidgets("点我发弹幕 sends to the page's video and part, and the danmaku shows boxed on the stage", (tester) async {
      final api = FakePageApi();
      await openPage(tester, api: api);
      await tester.tap(find.byKey(const ValueKey('danmaku-send')));
      await frames(tester, 2);
      final danmaku = ui(tester).danmaku!;
      expect(danmaku.sendOpen.value, isTrue);
      expect(find.text('弹幕输入中'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('danmaku-send-input')), '页面弹幕');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('danmaku-send-button')));
      await frames(tester, 4);
      final posted = api.postedDanmaku.single;
      expect((posted.text, posted.bvid, posted.cid), ('页面弹幕', bv, p1));
      expect(danmaku.sendOpen.value, isFalse);
      expect(feedItems().singleWhere((item) => item.text == '页面弹幕').isOwn, isTrue);
      final layer = tester.widget<DanmakuLayer>(find.byKey(const ValueKey('video-danmaku')));
      expect(layer.timeline, same(controller.danmaku.timeline));
      await back(tester);
    });

    testWidgets('logged out, 点我发弹幕 asks for the login and opens no bar', (tester) async {
      await openPage(tester, loggedIn: false);
      await tester.tap(find.byKey(const ValueKey('danmaku-send')));
      await frames(tester, 2);
      expect(gate.asks, hasLength(1));
      expect(find.text('请先登录'), findsNothing);
      expect(ui(tester).danmaku!.sendOpen.value, isFalse);
      expect(find.byKey(const ValueKey('danmaku-send-bar')), findsNothing);
      gate.answer(false);
      await frames(tester, 2);
      expect(ui(tester).danmaku!.sendOpen.value, isFalse);
      await back(tester);
    });

    testWidgets('⋮ has the 弹幕设置 row in portrait and 竖屏, not in landscape', (tester) async {
      await openPage(tester);
      final row = find.byKey(const ValueKey('more-danmaku-settings'));
      Future<void> more(Presentation presentation, Matcher rows) async {
        await rotate(tester, presentation);
        expect(orientation.presentation, presentation);
        ui(tester).panels.open(PlayerPanel.more);
        await frames(tester);
        expect(row, rows, reason: '$presentation');
        ui(tester).panels.close();
        await frames(tester);
      }

      await more(Presentation.inline, findsOneWidget);
      await more(Presentation.landscape, findsNothing);
      sessions.first
        ..isVertical = true
        ..changed();
      await more(Presentation.vertical, findsOneWidget);
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets("⋮'s 弹幕设置 row opens the panel, and its 滚动 square reaches the page's feed", (tester) async {
      await openPage(tester);
      ui(tester).panels.open(PlayerPanel.more);
      await frames(tester);
      final row = find.byKey(const ValueKey('more-danmaku-settings'));
      await tester.ensureVisible(row);
      await frames(tester, 4);
      await tester.tap(row);
      await frames(tester);
      expect(ui(tester).panels.value, PlayerPanel.danmakuSettings);

      final square = find.byKey(const ValueKey('danmaku-type-scroll'));
      await tester.ensureVisible(square);
      await frames(tester, 4);
      await tester.tap(square);
      await frames(tester, 2);
      expect(controller.danmaku.options.blockScroll, isTrue);
      ui(tester).panels.close();
      await frames(tester);
      await back(tester);
    });

    testWidgets('back closes the send bar, then 弹幕设置, then leaves the page', (tester) async {
      await openPage(tester);
      final panels = ui(tester).panels;
      final danmaku = ui(tester).danmaku!;
      panels.open(PlayerPanel.danmakuSettings);
      await frames(tester, 4);
      danmaku.openSend();
      await frames(tester, 2);

      await back(tester);
      expect(danmaku.sendOpen.value, isFalse);
      expect(panels.value, PlayerPanel.danmakuSettings);
      await back(tester);
      expect(panels.value, isNull);
      expect(find.byType(VideoPage), findsOneWidget);
      await back(tester);
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets("landscape's back arrow closes the send bar and stays in full screen", (tester) async {
      await openPage(tester);
      await rotate(tester, Presentation.landscape);
      final danmaku = ui(tester).danmaku!..openSend();
      await frames(tester, 2);
      ui(tester).onBack();
      await frames(tester, 2);
      expect(danmaku.sendOpen.value, isFalse);
      expect(orientation.presentation, Presentation.landscape);
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets('the open send bar keeps the chrome from hiding', (tester) async {
      await openPage(tester);
      final chrome = ui(tester).chrome;
      final danmaku = ui(tester).danmaku!;
      player.emit(const StatusChanged(PlayerStatus.playing));
      expect(chrome.autoHide, isTrue);
      danmaku.openSend();
      expect(chrome.autoHide, isFalse);
      danmaku.closeSend();
      expect(chrome.autoHide, isTrue);
      await back(tester);
    });
  });

  group('the loading TV (65, 66)', () {
    Finder loading({bool offstage = false}) => find.byType(PlayerLoading, skipOffstage: !offstage);

    Future<void> playing(WidgetTester tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 2);
      expect(loading(), findsNothing);
    }

    Future<void> waitPastGrace(WidgetTester tester) async {
      player.emit(const StatusChanged(PlayerStatus.buffering));
      await tester.pump(PlayerLoadingTheme.grace);
      await tester.pump();
    }

    testWidgets('shows through the first load in place of the spinner, and goes once it plays', (tester) async {
      await host(tester);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await frames(tester, 20);
      expect(controller.phase, PlaybackPhase.loading);
      expect(find.byKey(const ValueKey('video-loading')), findsOneWidget);
      expect(loading(), findsOneWidget);
      expect(find.text(PlayerLoading.message), findsOneWidget);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await frames(tester, 2);
      expect(loading(), findsNothing);
      await back(tester);
    });

    testWidgets('a wait for data mid-play shows it once past the grace, with the speed; a short blip shows nothing',
        (tester) async {
      await playing(tester);
      player.emit(const StatusChanged(PlayerStatus.buffering));
      await tester.pump(PlayerLoadingTheme.grace - const Duration(milliseconds: 100));
      expect(loading(), findsNothing);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await tester.pump(const Duration(seconds: 1));
      expect(loading(), findsNothing, reason: 'a quick seek or hiccup');

      await waitPastGrace(tester);
      expect(loading(), findsOneWidget);
      expect(find.text(PlayerLoading.message), findsOneWidget, reason: 'no speed until the engine reports');
      sessions.single.stats.value = const OverlayStats(
        mode: PlaybackMode.btr,
        downloadBps: 69.33 * 1024,
        engine: EngineSnapshot(),
      );
      await tester.pump();
      expect(find.text('正在缓冲... 69.33 KB/s'), findsOneWidget);
      player.emit(const StatusChanged(PlayerStatus.playing));
      await tester.pump();
      expect(loading(), findsNothing);
      await back(tester);
    });

    testWidgets('paused or ended takes it away', (tester) async {
      await playing(tester);
      for (final rest in [PlayerStatus.paused, PlayerStatus.ended]) {
        await waitPastGrace(tester);
        expect(loading(), findsOneWidget);
        player.emit(StatusChanged(rest));
        await tester.pump(PlayerLoadingTheme.grace);
        expect(loading(), findsNothing, reason: '$rest');
      }
      await back(tester);
    });

    testWidgets('a covered page shows none', (tester) async {
      await playing(tester);
      await waitPastGrace(tester);
      expect(loading(), findsOneWidget);
      unawaited(nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SizedBox())));
      await frames(tester, 20);
      expect(loading(offstage: true), findsNothing);
      await tester.pump(PlayerLoadingTheme.grace);
      expect(loading(offstage: true), findsNothing);
      await back(tester);
      await back(tester);
    });
  });

  group('the uploader sheet (62, 68, 76)', () {
    const owner = 7;
    late FakePageApi api;
    late FakeSpaceApi spaceApi;

    setUp(() {
      api = FakePageApi(
        uploader: const UploaderCard(mid: 0, name: '', face: '', fans: 0, videos: 0, isVip: false, following: false),
      );
      spaceApi = FakeSpaceApi(
        videoList: [
          for (var i = 1; i <= 6; i++)
            SpaceVideo(aid: i, bvid: 'BV1sheetpg0$i', title: '投稿 $i', cover: '', duration: 60),
        ],
      );
    });

    UploaderSheetController sheet(WidgetTester tester) =>
        tester.widget<UploaderSheetLayer>(find.byType(UploaderSheetLayer, skipOffstage: false).last).controller;
    bool canPop(WidgetTester tester) => tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>).last).canPop;

    /// The page with its video and detail in, its uploader [owner], and the sheet opened as the uploader row does.
    Future<void> openSheet(WidgetTester tester, {int mid = owner}) async {
      await host(tester, pageApi: api, spaceApi: spaceApi);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      sessions.single
        ..detail = detail(bv, ownerMid: owner)
        ..changed();
      await tester.pump();
      openUploader(tester.element(find.byType(PageTabs).last), UploaderRef(mid: mid, name: 'UP主'));
      await frames(tester);
    }

    testWidgets('the uploader row opens it from the player\'s bottom, over the tabs; back closes it first, then the '
        'page leaves', (tester) async {
      await openSheet(tester);
      expect(sheet(tester).uploader?.mid, owner);
      final box = tester.getRect(find.byKey(const ValueKey('uploader-sheet')));
      expect(box.top, area(tester).bottom);
      expect(box.bottom, portrait.height);
      expect(find.byType(UploaderVideoCard), findsWidgets);
      expect(canPop(tester), isFalse);

      unawaited(nav.currentState!.maybePop());
      await frames(tester, 20);
      expect(sheet(tester).isOpen, isFalse);
      expect(find.byType(UploaderSheet), findsNothing);
      expect(find.byType(VideoPage), findsOneWidget);
      expect(canPop(tester), isTrue);

      openUploader(tester.element(find.byType(PageTabs)), const UploaderRef(mid: owner));
      await frames(tester);
      ui(tester).onBack();
      await frames(tester, 20);
      expect(sheet(tester).isOpen, isFalse, reason: 'the player\'s 〈 closes it too');
      expect(find.byType(VideoPage), findsOneWidget);
      await back(tester);
      expect(find.byType(VideoPage), findsNothing);
    });

    testWidgets('the player above it keeps working: its controls still answer', (tester) async {
      await openSheet(tester);
      final chrome = ui(tester).chrome;
      final shown = chrome.visible;
      await tester.tapAt(area(tester).center);
      await tester.pump(const Duration(milliseconds: 400));
      expect(chrome.visible, isNot(shown));
      expect(sheet(tester).isOpen, isTrue);
      await back(tester);
      await back(tester);
    });

    testWidgets('going to full screen closes it', (tester) async {
      await openSheet(tester);
      await rotate(tester, Presentation.landscape);
      expect(sheet(tester).isOpen, isFalse);
      await rotate(tester, Presentation.inline);
      await frames(tester);
      expect(find.byType(UploaderSheet), findsNothing);
      await back(tester);
    });

    testWidgets('in full screen the uploader opens the space instead', (tester) async {
      await host(tester, pageApi: api, spaceApi: spaceApi);
      pushVideo(const VideoRoute(bvid: bv, cid: p1, start: 0));
      await opened(tester);
      await rotate(tester, Presentation.landscape);
      openUploader(tester.element(find.byType(PanelLayer).last), const UploaderRef(mid: owner));
      await frames(tester, 20);
      expect(sheet(tester).isOpen, isFalse);
      expect(find.byType(VideoPage), findsNothing, reason: 'the space covers it');
      nav.currentState!.pop();
      await frames(tester, 20);
      await rotate(tester, Presentation.inline);
      await back(tester);
    });

    testWidgets('关注 and 取消关注 in the sheet keep the page\'s 关注 in step, and the page\'s reaches the sheet', (
      tester,
    ) async {
      ActionsModel? actions;
      makeDetails = () => FakePageDetails(
        actions: actions = ActionsModel(
          api: api,
          detail: detail(bv, ownerMid: owner),
          relation: const VideoRelation(like: false, dislike: false, favorite: false, attention: false, coins: 0),
          isLoggedIn: () => true,
          accountMid: () => 1,
          requestLogin: () {},
          toast: (_) {},
          follows: services.follows,
        ),
      );
      await openSheet(tester);
      final model = actions!;
      addTearDown(model.dispose);
      expect(api.calls.where((call) => call.startsWith('uploaderCard')), isEmpty, reason: 'started from the page\'s');
      expect(model.following, isFalse);

      await tester.tap(find.byKey(const ValueKey('uploader-sheet-follow')));
      await frames(tester);
      expect(api.calls.last, 'follow on=true');
      expect(model.following, isTrue);
      await frames(tester, 50);

      await tester.tap(find.byKey(const ValueKey('uploader-sheet-follow')));
      await frames(tester);
      expect(find.text('确定不再关注？'), findsOneWidget);
      expect(canPop(tester), isFalse);
      unawaited(nav.currentState!.maybePop());
      await frames(tester);
      expect(find.text('确定不再关注？'), findsNothing, reason: 'back closes the confirm first');
      expect(sheet(tester).isOpen, isTrue);
      expect(model.following, isTrue);

      await tester.tap(find.byKey(const ValueKey('uploader-sheet-follow')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('unfollow-确定')));
      await frames(tester);
      expect(api.calls.last, 'follow on=false');
      expect(model.following, isFalse);
      await frames(tester, 50);

      await model.toggleFollow();
      await frames(tester);
      expect(
        find.descendant(of: find.byType(UploaderSheet), matching: find.text('已关注')),
        findsOneWidget,
        reason: 'the page\'s 关注 reached the sheet',
      );
      await frames(tester, 50);
      await back(tester);
      await back(tester);
    });

    testWidgets('opened before the page knows its 关注, the sheet asks the card and shows an uploader already followed',
        (tester) async {
      api.uploader = const UploaderCard(mid: 0, name: '', face: '', fans: 0, videos: 0, isVip: false, following: true);
      ActionsModel? actions;
      makeDetails = () => FakePageDetails(
        actions: actions = ActionsModel(
          api: api,
          detail: detail(bv, ownerMid: owner),
          isLoggedIn: () => true,
          accountMid: () => 1,
          requestLogin: () {},
          toast: (_) {},
          follows: services.follows,
        ),
      );
      await openSheet(tester);
      addTearDown(actions!.dispose);
      expect(api.calls, contains('uploaderCard mid=$owner'));
      expect(find.descendant(of: find.byType(UploaderSheet), matching: find.text('已关注')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('uploader-sheet-follow')));
      await frames(tester);
      expect(find.text('确定不再关注？'), findsOneWidget);
      expect(api.calls.where((call) => call.startsWith('follow')), isEmpty);
      unawaited(nav.currentState!.maybePop());
      await frames(tester);
      await back(tester);
      await back(tester);
    });

    testWidgets('the status bar\'s tap leaves the list under the sheet where it is', (tester) async {
      await openSheet(tester);
      sessions.single
        ..related = [for (var i = 0; i < 20; i++) quietCard('BV1r$i')]
        ..changed();
      await frames(tester, 2);
      final intro = tester
          .state<ScrollableState>(
            find.descendant(of: find.byType(IntroTab), matching: find.byType(Scrollable), skipOffstage: false).first,
          )
          .position
        ..jumpTo(200);
      await tester.pump();
      final top = tester.getRect(find.byKey(const ValueKey('uploader-sheet'))).top;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.statusBar.name,
        SystemChannels.statusBar.codec.encodeMethodCall(const MethodCall('handleScrollToTop')),
        (_) {},
      );
      await frames(tester, 30);
      expect(intro.pixels, 200);
      expect(sheet(tester).isOpen, isTrue);
      expect(tester.getRect(find.byKey(const ValueKey('uploader-sheet'))).top, top);
      await back(tester);
      await back(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('another uploader (a staff member) is asked about', (tester) async {
      await openSheet(tester, mid: 99);
      expect(api.calls, contains('uploaderCard mid=99'));
      expect(spaceApi.calls.first, 'profile mid=99');
      await back(tester);
      await back(tester);
    });

    testWidgets('a card opens its video in the page\'s place; back goes to what the page was opened from',
        (tester) async {
      replaceOnOpen();
      await openSheet(tester);
      await tester.tap(find.byType(UploaderVideoCard).first);
      await frames(tester, 20);
      expect(find.byType(VideoPage, skipOffstage: false), findsOneWidget);
      expect(tester.widget<VideoPage>(find.byType(VideoPage)).route.bvid, 'BV1sheetpg01');
      expect(find.byType(UploaderSheet), findsNothing);
      await back(tester);
      expect(find.byType(VideoPage), findsNothing);
      expect(nav.currentState!.canPop(), isFalse);
    });
  });
}

/// A related video without a cover to download.
VideoCard quietCard(String bvid) => VideoCard(
  aid: 2,
  bvid: bvid,
  cid: 3,
  title: '相关视频',
  cover: '',
  duration: 60,
  ownerMid: 4,
  ownerName: 'UP',
  views: 1,
  danmaku: 1,
  likes: 1,
);

VideoDetail detail(String bvid, {int aid = 1, int reply = 0, int ownerMid = 0}) => VideoDetail(
  bvid: bvid,
  aid: aid,
  title: '测试视频',
  cover: '',
  pubdate: 0,
  duration: 712,
  desc: '',
  descParts: const [],
  copyright: 1,
  owner: ownerMid == 0 ? VideoOwner.empty : VideoOwner(mid: ownerMid, name: 'UP主', face: ''),
  stat: VideoStat(view: 0, danmaku: 0, reply: reply, favorite: 0, coin: 0, share: 0, like: 0),
  pages: const [],
  season: null,
  staff: const [],
  width: 1920,
  height: 1080,
  honor: null,
  redirectURL: null,
);

VideoCard card(String bvid) => VideoCard(
  aid: 2,
  bvid: bvid,
  cid: 3,
  title: '相关视频',
  cover: cover,
  duration: 60,
  ownerMid: 4,
  ownerName: 'UP',
  views: 1,
  danmaku: 1,
  likes: 1,
);

/// As the logged-out 稍后再看: the model asked for a login itself, so there is nothing to toast.
final class _QuietDetails extends FakePageDetails {
  @override
  Future<ActionResult> watchLater(VideoCard card) async {
    watchLaterCalls.add(card.bvid);
    return const ActionResult('', ok: false);
  }
}

/// Records the image URLs asked for and never answers, as covers still downloading.
final class _RecordingHttpClient implements HttpClient {
  _RecordingHttpClient(this.requested);

  final List<String> requested;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    requested.add('$url');
    return Completer<HttpClientRequest>().future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Comment comment(
  int rpid, {
  int root = 0,
  int parent = 0,
  int replyCount = 0,
  int mid = 2001,
  List<Comment> preview = const [],
}) => Comment(
  rpid: rpid,
  oid: 1,
  mid: mid,
  root: root,
  parent: parent,
  ctime: rpid,
  likes: 10,
  replyCount: replyCount,
  member: CommentMember(mid: mid, name: '测试用户$rpid', level: 5),
  message: '第$rpid条评论',
  runs: [TextRun('第$rpid条评论')],
  previewReplies: preview,
);
