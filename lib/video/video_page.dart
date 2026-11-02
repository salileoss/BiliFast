import 'dart:async';
import 'dart:math' show pi;

import 'package:bili_core/api.dart' as bili
    show AidLink, BvidLink, LinkParser, VideoCard, VideoView;
import 'package:bili_core/devlog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../app/form_factor.dart';
import '../app/route_observer.dart';
import '../comments/comment_callbacks.dart';
import '../comments/comment_overlays.dart';
import '../danmaku/danmaku_overlays.dart';
import '../danmaku/danmaku_session.dart';
import '../comments/comments_model.dart';
import '../comments/comments_tab.dart';
import '../device/orientation.dart';
import '../device/orientation_host.dart' show TurnStart;
import '../device/status_bar.dart' show StatusNetwork;
import '../home/feed_model.dart' show requestFailureMessage;
import '../offline/offline_models.dart';
import '../offline/page/offline_page_body.dart';
import '../offline/page/offline_row_sheet.dart';
import '../offline/pages/offline_selector.dart';
import '../playback/playback_controller.dart';
import '../player/bili_player.dart' show PlayerStatus;
import '../player_ui/chrome_state.dart';
import '../player_ui/panels/panel_controller.dart';
import '../player_ui/panels/panel_layer.dart';
import '../player_ui/player_loading.dart';
import '../player_ui/player_ui.dart';
import '../shared/cover_preset.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../space/space_route.dart';
import '../space/uploader_sheet.dart';
import '../space/uploader_tap.dart';
import 'actions/action_overlays.dart';
import 'collapsing_player.dart';
import 'intro/intro_tab.dart';
import 'page_details.dart';
import 'page_details_model.dart';
import 'pad/pad_body.dart';
import 'pad/pad_page_layout.dart';
import 'page_playback.dart';
import 'page_session.dart';
import 'page_tabs.dart';
import 'player_prefs.dart';
import 'player_session.dart';
import 'turn_recorder.dart';
import 'video_player_area.dart';
import 'video_route.dart';

typedef PageDetailsFactory = PageDetails Function({
  required PlayerSession session,
  required AppServices services,
  required void Function(String message) toast,
  required VoidCallback requestLogin,
  required Listenable logins,
});

/// The app's page details. An action that needs the account goes to [requestLogin], and [logins] fires for each login
/// made from the page.
PageDetails pageDetails({
  required PlayerSession session,
  required AppServices services,
  required void Function(String message) toast,
  required VoidCallback requestLogin,
  required Listenable logins,
}) {
  final environment = services.environment;
  return VideoPageDetailsModel(
    session: session,
    api: services.pageApi,
    isLoggedIn: () => environment.account is LoggedIn,
    accountMid: () => environment.mid,
    requestLogin: requestLogin,
    toast: toast,
    appAuthorized: () => services.appAuth.authorized,
    // The factory has no page context, so the token's confirm goes up on the app's navigator, as the launch's does.
    requestAppAuth: () async {
      final context = services.navigator.currentContext;
      return context != null && await services.appAuth.request(context);
    },
    follows: services.follows,
    accountChanges: environment,
    logins: logins,
  );
}

typedef VideoPageOpener = Future<void> Function(BuildContext context, VideoRoute route);

/// The video page: the player at 16:9 under a black status bar with the tab row and 简介 | 评论 below it, or the
/// player alone over the whole screen in full screen, which is this page laid out again rather than a route of its
/// own. Paused, the small player shrinks to the 继续播放 bar as the shown tab scrolls, the tab row riding under it.
/// It plays the route's video on a controller of its own ([PagePlayback]), reports watch progress while logged in, and
/// hands the playback to the [PipKeeper] when popped or replaced, which frees it unless the small window plays it. A
/// video opened from the page replaces it ([replaceVideoPage]). Covered by another page (a video from a space opened on
/// it) it pauses, and shown again it resumes where it was, without a reload. An offline route's page (158) plays a
/// 离线缓存 part from the phone with the cached videos under the player in place of the tabs, and has no details or
/// comments.
class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.route,
    this.createSession = pageSession,
    this.createDetails = pageDetails,
    this.openPage = replaceVideoPage,
  });

  final VideoRoute route;
  final PageSessionFactory createSession;
  final PageDetailsFactory createDetails;

  /// A related video, a video id in the description or a comment, or the uploader sheet's video, opens through this:
  /// in this page's place.
  final VideoPageOpener openPage;

  /// Asks for [cover] as the page's own does (the player box's size, [CoverPreset.player]) the moment a page is
  /// opened: the card's smaller (for 推荐, 4:3) picture flies in under it and would otherwise sit stretched in the box
  /// until the page's own arrives.
  static void precacheCover(BuildContext context, String cover) => unawaited(
    RemoteImage.precache(
      context,
      cover,
      size: _VideoPageState._coverSize(context),
      cover: true,
      preset: CoverPreset.player,
    ),
  );

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with RouteAware, TickerProviderStateMixin {
  AppServices? _services;

  /// What the page plays: the route's, or the one the small window's restore button brought back.
  PagePlayback? _playback;

  PlaybackController? get _controller => _playback?.controller;

  /// Popped, replaced, or disposed without either: the playback went to the keeper, and the page acts on it no more.
  bool _left = false;

  /// Replaced by a video opened on it: the body's Heroes stay up for the cover's flight into the new page.
  bool _replaced = false;

  /// This page's video has played, so a fallback, reload or replay shows the player rather than the cover again.
  bool _played = false;

  /// The playback's session, once the page has built its player around it.
  PlayerSession? _session;
  PageDetails? _details;
  PlayerUi? _ui;

  /// 简介's video, taken from the session until the page leaves.
  IntroContent _intro = const IntroContent();

  /// The native view: built once, so no layout switch or chrome change recreates it.
  Widget? _videoView;
  Listenable? _autoHideInputs;

  /// Mid-play waits for data past the grace, for the loading TV.
  PlayerWait? _dataWait;
  final _chrome = ChromeState();
  final _panels = PanelController();
  PlayerPanel? _openPanel;
  final _overlays = ActionOverlayController();
  final _tabs = PageTabsController();

  /// The page's danmaku, made with the session.
  DanmakuSession? _danmaku;

  /// Attached to nothing: the status bar's tap scrolls nothing while 评论详情 is up.
  final _noScroll = ScrollController();
  final _areaKey = GlobalKey();
  late final _collapse = CollapsingPlayer(tabs: _tabs, vsync: this);

  /// What the page last laid out, which follows the screen's shape rather than the presentation: iOS hands Flutter
  /// the turned size only halfway through the rotation, so until then the upright page turns as one piece. The
  /// player's panels and gestures follow it too.
  final _laidOut = ValueNotifier<Presentation>(Presentation.inline);

  /// From the upright end of the turn (0) to landscape full screen (1). It runs over the whole turn, from the
  /// presentation's change, while the layout waits for the screen's new shape.
  late final _grow = AnimationController(vsync: this, duration: RotationTheme.grow);
  bool _turnedFull = false;

  /// The upright end of a turn to or from landscape full screen: the small player, or 竖屏.
  Presentation _upright = Presentation.inline;

  /// While the page draws the turns itself (旋转动画, iOS): the screen's shape a change of presentation was made on.
  /// The player waits for the system's turn to start, or for [RotationTheme.takeoverWait] to run out.
  bool? _turnFrom;
  Timer? _turnTimeout;
  StreamSubscription<TurnStart>? _turns;

  /// The last change of presentation's wait ran out with no turn started: the screen never turned for it.
  bool _turnMissed = false;

  /// The turn being waited for, started by the system and waiting for a build at its new shape [wide]: iOS hands
  /// over the size first, but the order isn't relied on.
  ({TurnStart start, bool wide})? _pendingTurn;

  /// The page turns from [_spinFrom] back to upright as it runs.
  late final _spin = AnimationController(vsync: this);
  double _spinFrom = 0;

  bool get _spinning => _spin.isAnimating;

  /// From [_beginTurn] until its spin is over and no other turn is waited for: only a turn the page draws has the
  /// official app's turning window.
  bool _drawing = false;

  final _recorder = TurnRecorder();

  /// The iPad's player growing from its place in the page to the whole screen and back (22). The iPad never turns
  /// for full screen, so none of the turn's machinery runs there.
  late final _padFull = AnimationController(vsync: this, duration: PadPageTheme.fullScreenGrow);
  bool _padFullTarget = false;

  /// Whether the page lays out as the iPad's, from the last build.
  bool _pad = false;

  /// The sideways column's 简介 head, measured for the pinned strip.
  final _padHeadKey = GlobalKey();
  final _padHeadHeight = ValueNotifier<double?>(null);

  /// Whether the iPad's page was last laid out in two columns; null before its first layout.
  bool? _padSidewaysLaidOut;

  /// Turns the host hasn't heard were drawn: its still picture covers the screen until it does.
  final _drawnOwed = <int>[];

  /// The screen's shape at the last build.
  bool? _drawnWide;

  /// Whether the player's chrome is put away for a turn, a grow or a shrink.
  final _turningPlayer = ValueNotifier<bool>(false);

  /// How far a turn between 竖屏 and landscape full screen has got, for the player's video band; null otherwise.
  final _verticalTurn = ValueNotifier<double?>(null);

  /// The page's size and top inset when last laid out upright: the body keeps them while the player grows over it.
  ({Size size, double top})? _uprightFrame;

  /// What the player area lays out at while its box grows or shrinks: its size at rest in the current layout, below
  /// the box's top inset.
  final _pin = ValueNotifier<Size?>(null);

  /// The small player has shrunk from its full height, and [_barred] once it is the bar.
  bool _shrunk = false;
  bool _barred = false;

  /// Whether the controls showed when the player began to shrink, for when it is full again.
  bool _chromeBeforeShrink = false;

  /// The comments of the video the page shows, replaced when another video opens on it; the drafts stay with the page.
  CommentsModel? _comments;
  final _drafts = CommentDrafts();
  final _commentOverlays = CommentOverlayController();
  bool _threadOpen = false;

  /// The uploader sheet the uploader row and staff open (62).
  final _uploaderSheet = UploaderSheetController();

  /// 评论详情 and the uploader sheet hold the left edge, over the small player too, so the player's drag leaves it
  /// alone.
  final _threadEdge = ValueNotifier<bool>(false);

  /// The list's count once its first page is in, for 评论 N to follow a post or a delete; null before.
  final _listCount = ValueNotifier<int?>(null);
  late final _commentCallbacks = CommentCallbacks(
    reply: (target, emotes) {
      if (_comments?.requireLogin() ?? false) _commentOverlays.compose(target, emotes: emotes);
    },
    openThread: (root) => unawaited(_comments?.openThread(root)),
    viewPictures: _commentOverlays.viewPictures,
    confirmDelete: _commentOverlays.confirmDelete,
    seek: (seconds) => unawaited(_session?.seekAndPlay(seconds.toDouble())),
    openVideo: (id) => unawaited(_openVideoId(id)),
  );

  /// This page's begin is the orientation's latest, so the presentation is this page's.
  bool _owning = false;

  /// Whether this page's video is vertical; null until the video is known.
  bool? _vertical;

  /// Another page is on top of this one; a menu, sheet or dialog doesn't count.
  bool _covered = false;
  PageRoute<dynamic>? _route;
  bool? _immersive;

  /// An av id from the description is being looked up.
  bool _resolvingId = false;

  /// An action overlay is up in full screen, and whether the chrome showed when it went up.
  bool _overlayAside = false;
  bool _chromeShownBefore = false;

  /// The login page is being asked for or is up; another ask meanwhile is the same one.
  bool _askingLogin = false;

  /// Counts the logins made from this page, for what holds the account's state to ask again.
  final _logins = ValueNotifier<int>(0);
  Timer? _turnWait;

  /// The offline page's row whose ⋮ sheet is up (159).
  final _offlineSheet = ValueNotifier<OfflineItem?>(null);

  /// The offline page watches the phone's network, for 查看详情页 offline (161).
  bool _watchingNetwork = false;

  bool get _offline => widget.route.offline;

  OrientationController get _orientation => _services!.device.orientation;

  Presentation get _presentation => _owning && !_left ? _orientation.presentation : Presentation.inline;

  /// Landscape full screen is laid out once the screen is landscape, and stays until it is upright again; 竖屏 stays
  /// until the screen is landscape.
  Presentation _layoutFor(Size size) {
    // The iPad lays out what was asked for at once, whatever the screen's shape: it has no 竖屏, and full screen covers
    // it either way.
    if (_pad) return _presentation == Presentation.landscape ? Presentation.landscape : Presentation.inline;
    final wide = size.width > size.height;
    final was = _laidOut.value;
    return switch (_presentation) {
      Presentation.vertical => wide && was == Presentation.landscape ? Presentation.landscape : Presentation.vertical,
      Presentation.landscape => wide
          ? Presentation.landscape
          : (was == Presentation.vertical ? Presentation.vertical : Presentation.inline),
      Presentation.inline => wide && was == Presentation.landscape ? Presentation.landscape : Presentation.inline,
    };
  }

  /// A turn between an upright layout (the small player or 竖屏) and landscape full screen grows the player box, or
  /// shrinks it back, from wherever it is; a turn reversed midway goes back from there. While the page draws the
  /// turns, the box holds still until the system's turn starts, made on the screen's shape [wide]. Turned by the
  /// system, 竖屏 doesn't grow: the whole page turns.
  void _followTurn(Presentation presentation, bool wide) {
    final full = presentation == Presentation.landscape;
    final from = _turnedFull ? Presentation.landscape : _upright;
    if (!full) _upright = presentation;
    if (full == _turnedFull) return;
    _turnedFull = full;
    // A turn this change overtook is not drawn, but leaves the screen its shape, and stays owed: the next drawn turn
    // covers its picture.
    final overtaken = _pendingTurn;
    _pendingTurn = null;
    // Back before its turn started (a refusal), or after the last change's turn never came: the screen is already
    // where this one goes, and no turn will come. The box goes back from where it is.
    final settled = overtaken == null &&
        !_spinning &&
        ((_turnMissed && wide == full) || (!_grow.isAnimating && _grow.value == (full ? 1 : 0)));
    _turnMissed = false;
    _turnTimeout?.cancel();
    _turnTimeout = null;
    // Under Reduce Motion the turn jumps, so there is nothing to wait for.
    final still = MediaQuery.disableAnimationsOf(context);
    _turnFrom = _orientation.turnTakeover && _owning && !_left && !settled && !still ? overtaken?.wide ?? wide : null;
    _recorder.presentation(
      from,
      presentation,
      wide: wide,
      waiting: _turnFrom != null,
      drawn: _orientation.turnTakeoverChosen,
    );
    if (_turnFrom != null) {
      _turnTimeout = Timer(RotationTheme.takeoverWait, _turnLate);
    } else if (overtaken != null) {
      _reportDrawn();
    }
    if (still || (_turnFrom == null && _upright == Presentation.vertical)) {
      _grow.value = full ? 1 : 0;
    } else if (_turnFrom != null) {
      _grow.stop();
    } else if (full) {
      _grow.forward();
    } else {
      _grow.reverse();
    }
    _settleDrawing();
  }

  /// The iPad's full screen: the player grows from its place to the whole screen, or back, from wherever it is.
  void _followPadFull(bool full) {
    if (full == _padFullTarget) return;
    _padFullTarget = full;
    if (MediaQuery.disableAnimationsOf(context)) {
      _padFull.value = full ? 1 : 0;
    } else if (full) {
      unawaited(_padFull.forward());
    } else {
      unawaited(_padFull.reverse());
    }
  }

  /// The turned size is already in (or about to be). The turn being waited for is drawn from the first build at its
  /// new shape, whichever comes first; any other, one the page didn't ask for or a stale one the other way, is only
  /// reported drawn, at once.
  void _turnStarted(TurnStart start) {
    if (!mounted || !_owning || _left || _covered) return;
    if (_pad) {
      _drawnOwed.add(start.id);
      _reportDrawn();
      return;
    }
    // Asked for with iOS's animations off, the screen turns inside the request, so its turn can come before the build
    // that follows the change of presentation: follow it here, at the shape last drawn, so this is the turn waited for.
    if (_drawnWide case final wide? when (_presentation == Presentation.landscape) != _turnedFull) {
      _followTurn(_presentation, wide);
    }
    _drawnOwed.add(start.id);
    _turnMissed = false;
    final from = _turnFrom;
    final quarter = (start.angle.abs() % pi - pi / 2).abs() < pi / 4;
    final target = _presentation == Presentation.landscape;
    _turnTimeout?.cancel();
    _turnTimeout = null;
    if (from != null && quarter && from != target) {
      _recorder.started(start, outcome: 'pending');
      _pendingTurn = (start: start, wide: target);
      _turnTimeout = Timer(RotationTheme.takeoverWait, _turnLate);
    } else {
      _recorder.started(start, outcome: from != null ? 'stale' : 'unasked');
      if (from != null) {
        // A stale turn leaves the screen the other shape, which the one being waited for will start from.
        if (quarter) _turnFrom = !from;
        _turnTimeout = Timer(RotationTheme.takeoverWait, _turnLate);
      }
      _reportDrawn();
    }
    setState(() {});
  }

  /// From the build that has the turn's new shape: the page drawn turned by −angle, so it sits where it was before
  /// the turn, and back to upright as the box grows or shrinks, both over the official turn's [RotationTheme.grow]:
  /// iOS reports no length for a turn it makes with its animations off. A turn that reverses one under way starts from
  /// the angle the page is drawn at.
  void _beginTurn(({TurnStart start, bool wide}) turn) {
    _pendingTurn = null;
    _turnFrom = null;
    _turnTimeout?.cancel();
    _turnTimeout = null;
    final start = turn.start;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _drawing = true;
      _spinFrom = _rotation - start.angle;
      _recorder.began(start.id, spinFrom: _spinFrom, duration: RotationTheme.grow, grow: _grow.value);
      _runTurn();
    }
    _settleDrawing();
    _reportDrawn();
  }

  /// A grow the page neither turns through nor waits on a turn for is the system's.
  void _settleDrawing() {
    if (!_spinning && _turnFrom == null && _pendingTurn == null) _drawing = false;
  }

  void _runTurn() {
    const duration = RotationTheme.grow;
    _spin
      ..duration = duration
      ..forward(from: 0);
    if (_turnedFull && _grow.value != 1) {
      _grow.animateTo(1, duration: duration);
    } else if (!_turnedFull && _grow.value != 0) {
      _grow.animateBack(0, duration: duration);
    }
  }

  /// No turn came, or not its new shape: the player grows as it does when the system turns the screen itself.
  void _turnLate() {
    _turnTimeout = null;
    if (!mounted) return;
    _turnMissed = _pendingTurn == null;
    _recorder.late(missed: _turnMissed);
    _turnFrom = null;
    _pendingTurn = null;
    _settleDrawing();
    if (!_grow.isAnimating) {
      if (_upright == Presentation.vertical) {
        _grow.value = _turnedFull ? 1 : 0;
      } else if (_turnedFull) {
        _grow.forward();
      } else {
        _grow.reverse();
      }
    }
    _flushDrawn();
    setState(() {});
  }

  /// Rebuilds the PopScope, which holds the page while it turns.
  void _spinStatus(AnimationStatus status) {
    if (!status.isCompleted || !mounted) return;
    _settleDrawing();
    setState(() {});
  }

  double get _rotation => _spinFrom * (1 - RotationTheme.curve.transform(_spin.value));

  /// The host's still picture goes once the turn's first frame, the one being built, is on the screen: after it and
  /// the next.
  void _reportDrawn() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => _flushDrawn())
        ..scheduleFrame();
    });
  }

  void _flushDrawn() {
    for (final turn in _drawnOwed) {
      _services?.device.orientation.turnDrawn(turn);
      _recorder.drawnSent(turn);
    }
    _drawnOwed.clear();
  }

  /// Mid-turn, the player box with its top inset, where the upright body sits (竖屏 has none), the window it shows
  /// through and how far the turn has got, or null at rest. As the official app's UIKit window, measured frame by frame
  /// (01 in local/differences): the window goes from the upright screen to the landscape one about the centre, the box
  /// spans the window's width from the window's top-left corner, from the small player or 竖屏's whole screen to the
  /// whole landscape screen, and the body hangs from the box's bottom-left corner, cut off by the window's bottom. Only
  /// a turn the page draws, laid out at the turned size from its start, has that window. Any other grow (系统, which
  /// has the turned size only halfway, Windows, a late turn) has none, its body centred under the box. It is all
  /// placed about the centre of the screen as it is now: iOS keeps the view's centre as it hands over the turned size
  /// halfway through, so nothing moves then. Before that the box grows past the upright page's sides.
  ({Rect box, double inset, Offset? body, Rect? window, double t})? _turning(
    Size screen,
    Presentation layout,
    double uprightTop,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return null;
    final value = _grow.value;
    final vertical = _upright == Presentation.vertical;
    if (vertical) {
      // The system's 竖屏 turns jump; only one the page draws moves the box, from the change of presentation.
      if (!_grow.isAnimating && !_spinning && _turnFrom == null && _pendingTurn == null) return null;
    } else if (layout == Presentation.vertical ||
        !_grow.isAnimating && value == (layout == Presentation.landscape ? 1 : 0)) {
      return null;
    }
    final short = screen.shortestSide;
    final long = screen.longestSide;
    final small = uprightTop + _collapse.height;
    final t = RotationTheme.curve.transform(value);
    final centre = screen.center(Offset.zero);
    final box = Rect.lerp(
      vertical
          ? Rect.fromCenter(center: Offset.zero, width: short, height: long)
          : Rect.fromLTWH(-short / 2, -long / 2, short, small),
      Rect.fromCenter(center: Offset.zero, width: long, height: short),
      t,
    )!.shift(centre);
    if (vertical) return (box: box, inset: 0, body: null, window: null, t: t);
    final window = _drawing
        ? Rect.fromCenter(center: centre, width: short + (long - short) * t, height: long - (long - short) * t)
        : null;
    return (
      box: box,
      inset: uprightTop * (1 - t),
      body: Offset(window == null ? centre.dx - short / 2 : box.left, box.bottom - small),
      window: window,
      t: t,
    );
  }

  @override
  void initState() {
    super.initState();
    _panels.addListener(_panelChanged);
    _overlays
      ..addListener(_panelChanged)
      ..addListener(_standAside);
    _commentOverlays.addListener(_panelChanged);
    _offlineSheet.addListener(_panelChanged);
    _uploaderSheet.addListener(_sheetChanged);
    _collapse.addListener(_collapseChanged);
    _spin.addStatusListener(_spinStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _orientation.addListener(_presentationChanged);
      _turns = _orientation.turns.listen(_turnStarted);
      if (_offline) {
        _watchingNetwork = true;
        _services!.device.status.watch(true);
      }
      _takePlayback();
    }
    // Only another page covers this one. A popup on top (the ⋮ menu, a dialog) makes the route not current as well,
    // so ModalRoute.isCurrentOf would stop the end rules and the background pause under a menu.
    if (ModalRoute.of(context) case final PageRoute<dynamic> route when route != _route) {
      pageRoutes.unsubscribe(this);
      _route = route;
      pageRoutes.subscribe(this, route);
      unawaited(route.popped.then((_) => _routeDone(route)));
    }
  }

  @override
  void didPushNext() {
    if (_covered) return;
    _covered = true;
    _dataWait?.active = false;
    _owning = false;
    // The page above claims the orientation only once its video is known; until then a turn must not be taken over
    // with no page to draw it. A newer begin first makes this a no-op.
    final orientation = _orientation;
    scheduleMicrotask(() => orientation.end(this));
    if (!_left) {
      _playback?.cover();
      _details?.active = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void didPopNext() {
    if (!_covered) return;
    _covered = false;
    if (!_left) _dataWait?.active = true;
    // The loading TV comes back if this page's load is still running.
    if (mounted) setState(() {});
    // Shown again after the page above popped: this page takes the orientation back after the frame, once the pop
    // and the page above's leaving are done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _left || _covered) return;
      _claimOrientation();
      final playback = _playback;
      if (playback == null) return;
      playback.show(resuming: _services!.pipKeeper.pageShown(playback, opened: false));
      _details?.active = true;
    });
  }

  /// The route's playback, or the one the restore button brought back (started over if it was released meanwhile).
  /// Its first show releases any other playback the small window kept, before this page's video loads.
  void _takePlayback() {
    final services = _services!;
    final route = widget.route;
    final createSession = widget.createSession;
    final createDetails = widget.createDetails;
    final openPage = widget.openPage;
    final brought = route.playback;
    final playback = brought != null && !brought.closed
        ? brought
        : PagePlayback(
            services: services,
            route: brought?.restartRoute ?? route,
            createSession: createSession,
            restorePage: (restored) => VideoPage(
              route: restored,
              createSession: createSession,
              createDetails: createDetails,
              openPage: openPage,
            ),
          );
    _playback = playback;
    playback
      ..attach(this, requestLogin: _askLogin)
      ..addListener(_playbackChanged);
    final starting = playback.session == null;
    // Not in this build: the release reports the kept video's progress, and 最近打开 notifies its listeners. The
    // controller is asked for only after it, so the small window closes before this video loads.
    scheduleMicrotask(() {
      services.pipKeeper.pageShown(playback, opened: true);
      if (starting) playback.start();
    });
    if (!starting) {
      // Built in this first frame, so the small window has the player view to fly into; what notifies other pages
      // (the orientation) waits until the frame is done.
      _attachSession(playback, follow: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_left) _sessionChanged();
      });
    }
  }

  void _playbackChanged() {
    final playback = _playback;
    if (!mounted || _left || playback == null) return;
    if (_session == null && playback.session != null) _attachSession(playback);
    setState(() {});
  }

  /// The page's player, panels, details and danmaku, around the playback's session. [follow] reads the session at
  /// once.
  void _attachSession(PagePlayback playback, {bool follow = true}) {
    final services = _services!;
    final controller = playback.controller!;
    final session = playback.session!;
    _session = session;
    session.loopsAtEnd = _presentation == Presentation.vertical;
    _collapse.session = session;
    controller.addListener(_follow);
    // An offline page asks Bilibili for nothing about its video: no actions, counts or uploader card.
    final details = _offline
        ? null
        : widget.createDetails(
            session: session,
            services: services,
            toast: _toast,
            requestLogin: _askLogin,
            logins: _logins,
          );
    _details = details;
    if (_covered) details?.active = false;
    final environment = services.environment;
    final danmaku = DanmakuSession(
      feed: controller.danmaku,
      settings: services.danmakuSettings,
      rules: services.blockRules,
      api: services.pageApi,
      target: () {
        final video = controller.video;
        final part = controller.page;
        if (_left || video == null || part == null) return null;
        return (bvid: video.bvid, cid: part.cid);
      },
      position: () => session.position,
      isLoggedIn: () => environment.account is LoggedIn,
      isVip: () => switch (environment.account) {
        LoggedIn(:final vip) => vip,
        _ => false,
      },
      accountMid: () => environment.mid ?? 0,
      accountChanges: environment,
      requestLogin: _askLogin,
    );
    _danmaku = danmaku;
    danmaku.sendOpen.addListener(_panelChanged);
    _ui = PlayerUi(
      session: session,
      chrome: _chrome,
      panels: _panels,
      orientation: _orientation,
      device: services.device.controls,
      onBack: _back,
      details: details,
      onComments: _offline ? null : _showComments,
      overlay: _overlays,
      edgeTaken: _threadEdge,
      danmaku: danmaku,
      layout: _laidOut,
      statusBar: services.device.status,
      replyCount: _listCount,
    );
    _videoView = session.player.buildView();
    session.addListener(_sessionChanged);
    session.readout.status.addListener(_syncCollapse);
    _dataWait = PlayerWait(session.readout.status)..active = !_covered;
    _autoHideInputs = Listenable.merge([
      session.readout.status,
      session.scrubbing,
      _panels,
      _overlays,
      danmaku.sendOpen,
      _laidOut,
    ])..addListener(_syncAutoHide);
    _syncAutoHide();
    if (follow) _sessionChanged();
  }

  bool get _attached => !_left && _session != null;

  void _follow() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      if (!_attached) return;
      if (_session case final session?) _intro = IntroContent.of(session);
      if (controller.phase == PlaybackPhase.playing) _played = true;
    });
    _syncComments();
    _syncAutoHide();
    _syncCollapse();
  }

  void _sessionChanged() {
    _syncCollapse();
    final session = _session;
    if (session == null || !_attached) return;
    final intro = IntroContent.of(session);
    if (intro != _intro && mounted) setState(() => _intro = intro);
    _syncComments();
    if (session.video == null) return;
    final vertical = session.layoutVertical;
    final changed = vertical != _vertical;
    _vertical = vertical;
    if (!_owning) {
      _claimOrientation();
    } else if (changed) {
      _orientation.setVideoIsVertical(vertical, owner: this);
    }
  }

  /// A new model for each video the page shows, once its aid is known: from the detail, or from the view for a video
  /// opened without a signed detail (an av id, an unsigned link), whose uploader mark waits for the detail. On the
  /// iPhone nothing loads until 评论 first shows; the iPad loads at once, so a turn finds the sideways column as long as
  /// the place it carries.
  void _syncComments() {
    if (_left || !mounted || _offline) return;
    final detail = _intro.detail;
    final view = _attached ? _controller?.video : null;
    final aid = detail?.aid ?? (view?.bvid == _playback?.bvid ? view?.aid : null);
    if (aid == null) return;
    if (_comments case final comments? when comments.aid == aid) {
      if (detail != null) comments.upMid = detail.owner.mid;
      return;
    }
    // A post still out keeps its composer and model until it lands, so a failure is still shown.
    if (_drafts.anyPosting) {
      _drafts
        ..removeListener(_postLanded)
        ..addListener(_postLanded);
      return;
    }
    final services = _services!;
    final environment = services.environment;
    final old = _comments;
    _commentOverlays.close();
    final comments = CommentsModel(
      aid: aid,
      upMid: detail?.owner.mid ?? 0,
      api: services.pageApi,
      drafts: _drafts,
      isLoggedIn: () => environment.account is LoggedIn,
      accountMid: () => environment.mid,
      requestLogin: _askLogin,
      toast: _toast,
    )..addListener(_commentsChanged);
    // The iPad's 评论 kept its place across a turn for the list it had, not this one.
    if (_pad) _tabs.carry(PageTab.comments, 0);
    setState(() {
      _comments = comments;
      _setThreadOpen(false);
    });
    _listCount.value = null;
    if (_pad) unawaited(comments.ensureLoaded());
    old
      ?..removeListener(_commentsChanged)
      ..dispose();
  }

  void _postLanded() {
    if (_drafts.anyPosting) return;
    _drafts.removeListener(_postLanded);
    if (mounted && !_left) _syncComments();
  }

  /// Rebuilds the PopScope when the thread opens or closes, which back then closes first.
  void _commentsChanged() {
    final open = _comments?.thread != null;
    if (open != _threadOpen && mounted) setState(() => _setThreadOpen(open));
    _syncListCount();
  }

  void _syncListCount() {
    final comments = _comments;
    final loaded = comments != null && (comments.comments.isNotEmpty || comments.pinned != null || comments.isEnd);
    // A reload (another sort) keeps the last count until its first page is in; a new video's model starts at null.
    if (!loaded) return;
    final count = comments.total;
    if (count == _listCount.value || !mounted) return;
    // The tab asks for its first page while it builds, where the row can't rebuild yet.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _syncListCount());
    } else {
      _listCount.value = count;
    }
  }

  void _setThreadOpen(bool open) {
    _threadOpen = open;
    _threadEdge.value = open || _uploaderSheet.isOpen;
  }

  /// Rebuilds the PopScope, which back then closes first.
  void _sheetChanged() {
    _threadEdge.value = _threadOpen || _uploaderSheet.isOpen;
    _panelChanged();
  }

  /// The uploader row's and staff's tap: the sheet on the small player; full screen has no room for it.
  void _openUploader(UploaderRef uploader) {
    if (_left || !mounted) return;
    if (_presentation.fullScreen || _laidOut.value.fullScreen) {
      unawaited(openSpace(context, uploader));
    } else {
      _uploaderSheet.open(uploader);
    }
  }

  /// The page's own 关注 for its uploader once known. Null for anyone else, and for the page's own before the relation
  /// or card has said: the sheet then asks the card rather than show + 关注 for someone followed.
  bool? _followingOf(int mid) {
    final actions = _details?.actions;
    if (mid != _intro.detail?.owner.mid || actions == null || !actions.followingKnown) return null;
    return actions.following;
  }

  /// Closes the composer, the picture viewer or the delete confirm, else 评论详情. False when none is up. A composer
  /// that is posting stays: closed, a failed post would never show and its text would be lost with the page.
  bool _closeComments() {
    if (_commentOverlays.value case final overlay?) {
      if (overlay is! ComposeOverlay || !_drafts.anyPosting) _commentOverlays.close();
      return true;
    }
    if (_comments case final comments? when comments.thread != null) {
      comments.closeThread();
      return true;
    }
    return false;
  }

  /// Once the video is known, and again each time the page is shown after one above it: the latest begin wins.
  void _claimOrientation() {
    final vertical = _vertical;
    if (_left || vertical == null || _covered) return;
    _owning = true;
    _orientation.begin(this, videoIsVertical: vertical);
  }

  void _presentationChanged() {
    if (!mounted) return;
    // As BiliNative's page: full screen puts the composer away (its draft is kept), or the keyboard would cover the
    // video and type into a field out of sight.
    if (_presentation.fullScreen && _commentOverlays.value is ComposeOverlay && !_drafts.anyPosting) {
      _commentOverlays.close();
    }
    if (_presentation.fullScreen) {
      _uploaderSheet.close();
      _offlineSheet.value = null;
    }
    _session?.loopsAtEnd = _presentation == Presentation.vertical;
    setState(() {});
    _applySystemUi();
    _standAside();
  }

  /// In full screen an action overlay puts the chrome away, as an open panel does, and gives it back as it was once
  /// the overlay closes: the dark favourites sheet would otherwise show the chrome's action row through it.
  void _standAside() {
    final aside = _overlays.value != null && _presentation.fullScreen;
    if (aside == _overlayAside) return;
    _overlayAside = aside;
    if (aside) {
      _chromeShownBefore = _chrome.visible;
      _chrome.hide();
    } else if (_chromeShownBefore) {
      _chrome.show();
    }
  }

  /// Full screen keeps the status bar, light on black as in 04 and 09, and hides the home indicator.
  void _applySystemUi() {
    final immersive = _presentation.fullScreen;
    if (immersive == (_immersive ?? false)) return;
    _immersive = immersive;
    unawaited(
      immersive
          ? SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: const [SystemUiOverlay.top])
          : SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    );
  }

  void _syncAutoHide() {
    final session = _session;
    final controller = _controller;
    if (session == null || controller == null) return;
    // Another part opening on the page keeps the last one's status until its own load starts, so the phase counts.
    // 竖屏's controls never hide by themselves.
    _chrome.autoHide = _attached &&
        _laidOut.value != Presentation.vertical &&
        controller.phase == PlaybackPhase.playing &&
        session.readout.wantsPlay &&
        session.scrubbing.value == null &&
        _panels.value == null &&
        _overlays.value == null &&
        !(_danmaku?.sendOpen.value ?? false);
  }

  /// Only the page's own video, loaded, paused and not at its end, lets the tabs' scrolling shrink the player: the end
  /// screen (26) is in the player and must stay seen.
  void _syncCollapse() {
    final controller = _controller;
    final session = _session;
    _collapse.paused =
        controller != null &&
        session != null &&
        _attached &&
        controller.phase == PlaybackPhase.playing &&
        session.readout.status.value == PlayerStatus.paused &&
        !session.ended;
  }

  /// The controls go as the player starts to shrink, leaving the thin line as on 11, and come back as they were once
  /// it is full again.
  void _collapseChanged() {
    final progress = _collapse.progress;
    final shrunk = progress > 0;
    final barred = progress >= 1;
    if (shrunk == _shrunk && barred == _barred) return;
    if (shrunk && !_shrunk) {
      _chromeBeforeShrink = _chrome.visible;
      _chrome.hide();
    } else if (!shrunk && _shrunk && _chromeBeforeShrink) {
      _chrome.show();
    }
    _shrunk = shrunk;
    _barred = barred;
    if (mounted) setState(() {});
  }

  /// 继续播放: the shown tab back to its top, where the player has its full height again, and play.
  void _resume() {
    _tabs.scrollToTop(animate: !MediaQuery.disableAnimationsOf(context), tab: _collapse.only);
    final session = _session;
    if (session == null || session.readout.status.value != PlayerStatus.paused) return;
    _playback?.willPlay();
    session.togglePlay();
  }

  /// Rebuilds the PopScope, which lets a pop through only with no overlay or panel open.
  void _panelChanged() {
    final closed = _openPanel;
    _openPanel = _panels.value;
    // A panel closed, by a pick, a tap outside or back, goes back to the bare video, as the official app does (KaiC);
    // in 竖屏, where the controls stay up, back to them.
    if (_openPanel == null && closed != null && _laidOut.value != Presentation.vertical) _chrome.hide();
    if (mounted) setState(() {});
  }

  /// Back closes the comments' overlays and thread first on the small player, then an action overlay, then a panel,
  /// then the uploader sheet's confirm and the sheet.
  void _back() {
    if (_closeOfflineSheet()) return;
    if (_closeDanmakuSend()) return;
    if (!_presentation.fullScreen && _closeComments()) return;
    if (_overlays.value != null) {
      _overlays.close();
    } else if (_panels.value != null) {
      _panels.close();
    } else if (_uploaderSheet.back()) {
      return;
    } else if (_presentation.fullScreen) {
      _orientation.exitToInline();
    } else if (!_laidOut.value.fullScreen) {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  void _toast(String message) {
    if (mounted) showToast(context, message);
  }

  void _askLogin() => unawaited(_requestLogin());

  /// Every logged-out action and every answer of Bilibili's that wants a login comes here (BiliNative's presentLogin
  /// and InlineFirst): the send bar, the composer and the action overlays go, full screen turns back to the upright
  /// small player, and the login page goes up once the turn is over, with the phone's turning off until it closes.
  /// Nothing pressed is sent afterwards; a login made there has what holds the account's state ask again.
  Future<void> _requestLogin() async {
    final services = _services;
    if (_askingLogin || services == null || _left || _covered || !mounted) return;
    _askingLogin = true;
    try {
      // A model can ask while a widget builds, and what closes here rebuilds the page.
      await Future<void>.value();
      if (!mounted || _left) return;
      // An account still being checked (or whose check failed) may well be logged in: the login page would invite a
      // second login, so it is asked again first and the page shows only for a verdict of logged out.
      final environment = services.environment;
      if (environment.account is AccountUnknown) {
        await environment.refreshAccount();
        if (!mounted || _left) return;
        switch (environment.account) {
          case LoggedIn():
            return;
          case AccountUnknown():
            _toast('账号确认失败，请稍后重试');
            return;
          case LoggedOut() || LoginExpired():
            break;
        }
      }
      _danmaku?.closeSend();
      if (_commentOverlays.value is ComposeOverlay && !_drafts.anyPosting) _commentOverlays.close();
      _overlays.close();
      await _inlineFirst();
      if (!mounted || _left || _covered) return;
      _owning = false;
      _orientation.end(this);
      final before = environment.account;
      final bool answer;
      try {
        answer = await services.loginGate.request(context);
      } finally {
        if (mounted) _claimOrientation();
      }
      if (!mounted || _left) return;
      // Closing the login page while it signs in still logs in, after the page has answered false. A -101 asked
      // from a stale login and closed leaves that same LoggedIn, which isn't a new login.
      final account = environment.account;
      if (account is AccountUnknown) {
        _followSignIn(environment);
      } else if (account is LoggedIn && (answer || !identical(account, before))) {
        _loggedIn();
      }
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'login failed', {'error': '$error'});
      _toast('无法打开登录');
    } finally {
      _askingLogin = false;
    }
  }

  void _loggedIn() {
    _logins.value += 1;
    _comments?.refreshAccount();
    _danmaku?.refreshAccount();
  }

  VoidCallback? _signInWatch;

  /// Waits out the account check of a sign-in the login page left running.
  void _followSignIn(AppEnvironment environment) {
    _stopFollowingSignIn();
    void check() {
      final account = environment.account;
      if (account is AccountUnknown) return;
      _stopFollowingSignIn();
      if (account is LoggedIn && mounted && !_left) _loggedIn();
    }

    environment.addListener(check);
    _signInWatch = () => environment.removeListener(check);
  }

  void _stopFollowingSignIn() {
    _signInWatch?.call();
    _signInWatch = null;
  }

  /// How long the turn back upright may take before the login page goes up anyway, as in BiliNative's InlineFirst.
  static const _turnLimit = Duration(seconds: 3);
  static const _turnPoll = Duration(milliseconds: 20);

  /// The rotation's animation, which runs on after the screen has its upright size.
  static const _turnSettle = Duration(milliseconds: 400);

  /// Back to the small player from full screen. From landscape it waits for the screen to turn upright and the turn
  /// to end: a page pushed mid-turn would be laid out sideways. That holds for a turn back already under way, whose
  /// landscape layout stays until the screen is upright. 竖屏 is upright already.
  Future<void> _inlineFirst() async {
    // The iPad doesn't turn: the page is back once the frame is.
    if (_pad) {
      if (_presentation.fullScreen) _orientation.exitToInline();
      if (mounted) await SchedulerBinding.instance.endOfFrame;
      return;
    }
    if (_presentation.fullScreen) {
      _orientation.exitToInline();
    } else if (_laidOutUpright) {
      return;
    }
    final turning = !_laidOutUpright;
    var waited = Duration.zero;
    while (mounted && !_laidOutUpright && waited < _turnLimit) {
      await _wait(_turnPoll);
      waited += _turnPoll;
    }
    if (turning && mounted) await _wait(_turnSettle);
    if (mounted) await SchedulerBinding.instance.endOfFrame;
  }

  bool get _laidOutUpright {
    if (_pad) return !_laidOut.value.fullScreen;
    final size = MediaQuery.sizeOf(context);
    return size.width <= size.height && _laidOut.value != Presentation.landscape;
  }

  Future<void> _wait(Duration duration) {
    final done = Completer<void>();
    _turnWait = Timer(duration, done.complete);
    return done.future;
  }

  /// On back, the offline row's sheet closes before anything else: it covers the whole page.
  bool _closeOfflineSheet() {
    if (_offlineSheet.value == null) return false;
    _offlineSheet.value = null;
    return true;
  }

  /// A cached row's tap: that part on this page, from where it stopped. The one playing goes on, unless it failed.
  void _playOffline(OfflineItem item) {
    final playback = _playback;
    if (playback == null || _left) return;
    if (item.cid == playback.cid) {
      if (_controller?.phase == PlaybackPhase.failed) playback.retry();
      return;
    }
    playback.openOnPage(item.request.bvid, cid: item.cid);
  }

  /// 查看详情页: the video's own page, which needs the network (161).
  void _offlineDetails(OfflineItem item) {
    _offlineSheet.value = null;
    if (_services!.device.status.status.value.network == StatusNetwork.none) {
      _toast('似乎已断开与互联网的连接');
      return;
    }
    unawaited(openVideoPage(context, VideoRoute(bvid: item.request.bvid, cid: item.cid, title: item.request.title)));
  }

  /// The offline page's band under the player, in the tab row's place.
  Widget _offlineHeader() {
    final session = _session;
    final danmaku = _danmaku;
    return LibrarySelector<int>(
      library: _services!.offline,
      select: (library) => offlinePageItems(library).length,
      builder: (context, count) => ListenableBuilder(
        listenable: Listenable.merge([session ?? _tabs, ?danmaku, ?danmaku?.sendOpen]),
        builder: (context, _) => OfflinePageHeader(
          count: count,
          danmakuOn: session?.danmakuOn ?? PlayerPrefs.shared.danmakuOn,
          onToggleDanmaku: session == null ? null : () => session.setDanmakuOn(!session.danmakuOn),
          onSendDanmaku: () => danmaku?.openSend(),
          danmakuInputOpen: danmaku?.sendOpen.value ?? false,
          danmakuClosed: danmaku?.closed ?? false,
        ),
      ),
    );
  }

  /// The cached videos, in the tabs' place.
  Widget _offlineList() => OfflinePageList(
    library: _services!.offline,
    playing: _playback?.cid,
    status: _session?.readout.status,
    onPlay: _playOffline,
    onMore: (item) => _offlineSheet.value = item,
  );

  /// On back, the send bar closes before anything under it.
  bool _closeDanmakuSend() {
    final danmaku = _danmaku;
    if (danmaku == null || !danmaku.sendOpen.value) return false;
    danmaku.closeSend();
    return true;
  }

  /// 评论 in full screen: back to the small player on the 评论 tab.
  void _showComments() {
    _tabs.select(PageTab.comments, animate: false);
    _orientation.exitToInline();
  }

  /// 查看N条评论 sideways: the column scrolled so 热门评论 sits under the bar and the strip, or under the player while it
  /// plays, which then doesn't shrink.
  void _seeAllComments() {
    if (!mounted || _collapse.only == null) return;
    final scroll = _tabs.scrollOf(PageTab.intro);
    final head = _padHeadKey.currentContext?.findRenderObject();
    if (!scroll.hasClients || head is! RenderBox || !head.hasSize) return;
    final height = head.size.height;
    final target = (_collapse.paused ? _collapse.reserve + height - PadPageTheme.stripHeight : height)
        .clamp(0.0, scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(target);
    } else {
      unawaited(scroll.animateTo(target, duration: CollapseTheme.resume, curve: Curves.easeOutCubic));
    }
  }

  void _openRelated(bili.VideoCard card) =>
      unawaited(widget.openPage(context, VideoRoute(bvid: card.bvid, title: card.title, cover: card.cover)));

  Future<void> _watchLater(bili.VideoCard card) async {
    final details = _details;
    if (details == null) return;
    final result = await details.watchLater(card);
    if (result.message.isNotEmpty) _toast(result.message);
  }

  /// A BV id opens at once; an av id asks Bilibili for its video first. The page's own video opens nothing.
  Future<void> _openVideoId(String id) async {
    switch (bili.LinkParser.parse(id)) {
      case bili.BvidLink(id: final bvid):
        if (bvid == _playback?.bvid) return;
        await widget.openPage(context, VideoRoute(bvid: bvid));
      case final bili.AidLink link:
        if (_resolvingId || link.id == _intro.detail?.aid) return;
        _resolvingId = true;
        final bili.VideoView view;
        try {
          view = (await resolveVideoLink(_services!.environment.client, link)).$1;
        } catch (error) {
          Logger.shared.warn(LogCategory.ui, 'open video id failed', {'error': '$error'});
          _toast(requestFailureMessage(error, fallback: '打开视频失败，请稍后重试'));
          return;
        } finally {
          _resolvingId = false;
        }
        // The lookup may answer after a related page or a menu went up over this one.
        if (!mounted || _left || !(ModalRoute.isCurrentOf(context) ?? false) || view.bvid == _playback?.bvid) return;
        await widget.openPage(context, VideoRoute(bvid: view.bvid, title: view.title, view: view));
      default:
        break;
    }
  }

  VoidCallback? get _retry {
    final playback = _playback;
    if (playback == null || (playback.startError == null && playback.controller == null)) return null;
    return playback.retry;
  }

  /// The route completes on a pop, which has already left, and on a pushReplacement, which reports nothing else: the
  /// observer hears a replace, not a push, and the route is disposed only after the new page's slide.
  void _routeDone(PageRoute<dynamic> route) {
    if (!mounted || _left || !identical(route, _route)) return;
    setState(() {
      _replaced = true;
      _leave();
    });
  }

  /// Runs at the pop, not at dispose 500 ms later: the sound stops with the swipe, and the page below, shown at once,
  /// finds the small window kept.
  void _leave({bool fromDispose = false}) {
    if (_left) return;
    _left = true;
    _owning = false;
    _details?.active = false;
    _controller?.removeListener(_follow);
    // The session outlives the page when the small window keeps it.
    final session = _session;
    session?.removeListener(_sessionChanged);
    session?.readout.status.removeListener(_syncCollapse);
    _dataWait?.active = false;
    _autoHideInputs?.removeListener(_syncAutoHide);
    final playback = _playback;
    if (playback != null) {
      playback
        ..removeListener(_playbackChanged)
        ..detach(this);
      _services!.pipKeeper.pageRemoved(playback);
    }
    if (_watchingNetwork) {
      _watchingNetwork = false;
      _services?.device.status.watch(false);
    }
    if (_services != null) {
      _applySystemUi();
      // A newer page's begin makes this a no-op. Disposal runs while the tree is locked, and end() notifies the
      // newer page.
      if (fromDispose) {
        final orientation = _orientation;
        scheduleMicrotask(() => orientation.end(this));
      } else {
        _orientation.end(this);
      }
    }
  }

  @override
  void dispose() {
    _leave(fromDispose: true);
    _playback?.letGo(this);
    _stopFollowingSignIn();
    pageRoutes.unsubscribe(this);
    _services?.device.orientation.removeListener(_presentationChanged);
    _panels.removeListener(_panelChanged);
    _overlays
      ..removeListener(_panelChanged)
      ..removeListener(_standAside);
    _commentOverlays
      ..removeListener(_panelChanged)
      ..dispose();
    _offlineSheet
      ..removeListener(_panelChanged)
      ..dispose();
    _uploaderSheet
      ..removeListener(_sheetChanged)
      ..dispose();
    _threadEdge.dispose();
    _listCount.dispose();
    _comments
      ?..removeListener(_commentsChanged)
      ..dispose();
    _autoHideInputs?.removeListener(_syncAutoHide);
    _dataWait?.dispose();
    _collapse
      ..removeListener(_collapseChanged)
      ..dispose();
    _grow.dispose();
    _padFull.dispose();
    _padHeadHeight.dispose();
    unawaited(_turns?.cancel());
    _turnTimeout?.cancel();
    _flushDrawn();
    _spin.dispose();
    _turningPlayer.dispose();
    _verticalTurn.dispose();
    _pin.dispose();
    _laidOut.dispose();
    _details?.dispose();
    _turnWait?.cancel();
    _logins.dispose();
    _danmaku
      ?..sendOpen.removeListener(_panelChanged)
      ..dispose();
    _chrome.dispose();
    _panels.dispose();
    _overlays.dispose();
    _tabs.dispose();
    _noScroll.dispose();
    _drafts.removeListener(_postLanded);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height;
    final pad = FormFactor.of(context).isPad;
    _pad = pad;
    final layout = _layoutFor(size);
    if (pad) {
      _followPadFull(layout.fullScreen);
    } else {
      _followTurn(presentation, _drawnWide ?? wide);
      if (_pendingTurn case final turn? when turn.wide == wide) _beginTurn(turn);
      if (_drawnWide != null && _drawnWide != wide) _recorder.sized(size, layout: layout);
    }
    _drawnWide = wide;
    // The iPad's two columns: the player's column scrolls 简介's controller. The offline page keeps one column.
    final sideways = pad && wide && !_offline;
    _laidOut.value = layout;
    final fullScreen = layout.fullScreen;
    final controller = _controller;
    final mine = controller != null && _attached;
    final ui = mine ? _ui : null;
    _collapse.still = MediaQuery.disableAnimationsOf(context);
    return PopScope<Object?>(
      canPop:
          !presentation.fullScreen &&
          // Turning back, the landscape chrome is still drawn; its 〈 must not take the page with it.
          !fullScreen &&
          // Nor a swipe back while the page draws the turn: the upright size is in from its start.
          _turnFrom == null &&
          _pendingTurn == null &&
          !_spinning &&
          !(_danmaku?.sendOpen.value ?? false) &&
          _panels.value == null &&
          _overlays.value == null &&
          _commentOverlays.value == null &&
          !_threadOpen &&
          !_uploaderSheet.isOpen &&
          _offlineSheet.value == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          setState(_leave);
        } else if (_closeOfflineSheet()) {
          return;
        } else if (_closeDanmakuSend()) {
          return;
        } else if (!presentation.fullScreen && _closeComments()) {
          return;
        } else if (_overlays.value != null) {
          _overlays.close();
        } else if (_panels.value != null) {
          _panels.close();
        } else if (_uploaderSheet.back()) {
          return;
        } else if (_presentation.fullScreen) {
          _orientation.exitToInline();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        // A tap on the status bar scrolls the Scaffold's primary controller to the top: the shown tab's. Each tab hands
        // its list its own, and nothing else in the body takes one, so the composer's lists and the panels stay off it.
        child: ListenableBuilder(
          listenable: _tabs,
          // 评论详情 and the uploader sheet cover the tabs: a tap then reaches nothing rather than the list under them,
          // which would grow a shrunk player and move the sheet with it.
          builder: (context, scaffold) => PrimaryScrollController(
            controller: _threadOpen || _uploaderSheet.isOpen
                ? _noScroll
                : _tabs.scrollOf(sideways ? PageTab.intro : _tabs.selected),
            child: scaffold!,
          ),
          child: Scaffold(
            backgroundColor: fullScreen ? BiliColors.videoBackground : BiliColors.colorsOf(context).card,
            // The comment composer rides on the keyboard by itself, and the full-screen player keeps its size under it.
            resizeToAvoidBottomInset: false,
            body: PrimaryScrollController.none(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final media = MediaQuery.of(context);
                  final top = pad ? padPageTop(media.padding.top) : media.padding.top;
                  final columnWidth = sideways ? padPlayerColumnWidth(constraints.maxWidth) : constraints.maxWidth;
                  if (pad) {
                    // Each layout builds its own lists: their places go with the turn, read before the old ones go.
                    if (_padSidewaysLaidOut case final was? when was != sideways) {
                      _collapse
                        ..uprightLimit = PadPageTheme.uprightLimit
                        ..barHeight = PadPageTheme.barHeight
                        ..turn(columnWidth, sideways: sideways);
                    }
                    _padSidewaysLaidOut = sideways;
                  }
                  if (!fullScreen) {
                    _collapse
                      ..uprightLimit = pad ? PadPageTheme.uprightLimit : CollapseTheme.uprightLimit
                      ..width = columnWidth
                      ..barHeight = pad ? PadPageTheme.barHeight : CollapseTheme.barHeight
                      ..only = sideways ? PageTab.intro : null;
                    _uprightFrame = (size: constraints.biggest, top: top);
                  }
                  // The iPad lays out its page at the screen's own size, full screen or not: it never turns for it.
                  final upright = pad
                      ? (size: constraints.biggest, top: top)
                      : _uprightFrame ?? (size: constraints.biggest, top: top);
                  // 评论详情 and the uploader sheet cover the tab row and the list, for VoiceOver too.
                  Widget belowPlayer(Widget child) => ExcludeSemantics(
                    excluding: _threadOpen || _uploaderSheet.isOpen,
                    child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
                  );
                  // Out of sight in full screen, except while the player grows over it or shrinks back.
                  Widget hideable(bool hidden, Widget child) =>
                      Offstage(offstage: hidden, child: TickerMode(enabled: !hidden, child: child));
                  // Laid out as if the player were already the bar; each tab leaves the rest of the full height free.
                  // The offline list scrolls on its own, under the band, and never shrinks the player.
                  final pager = belowPlayer(
                    _offline ? _offlineList() : CollapseReserve(collapse: _collapse, child: _pager(context)),
                  );
                  final tabRow = belowPlayer(_offline ? _offlineHeader() : _tabRow(context));
                  // Full screen runs under the notch and the home indicator, so its chrome keeps clear of them itself;
                  // the small player sits below the status bar with no insets of its own.
                  final area = MediaQuery(
                    data: media.removePadding(removeTop: !fullScreen, removeBottom: !fullScreen),
                    // An open panel covers the player for VoiceOver too, as landscape's panel does.
                    child: ExcludeSemantics(
                      excluding: _panels.value != null,
                      // The danmaku's height follows where an upright video's box is heading, once per reshape.
                      child: ValueListenableBuilder<double>(
                        valueListenable: _collapse.shape,
                        builder: (context, shape, _) => VideoPlayerArea(
                          key: _areaKey,
                          presentation: layout,
                          onBack: _back,
                          ui: ui,
                          video: mine ? _videoView : null,
                          danmaku: mine ? controller.danmaku : null,
                          cover: _cover(context),
                          loading: _loading(controller, mine),
                          waiting: mine ? _dataWait : null,
                          failure: _failure(controller, mine),
                          onRetry: _retry,
                          endScreenAside: _overlayAside,
                          shrunk: _shrunk && !fullScreen,
                          barred: _barred && !fullScreen,
                          danmakuHeight: fullScreen ? null : shape,
                          pin: _pin,
                          turning: _turningPlayer,
                          verticalTurn: _verticalTurn,
                        ),
                      ),
                    ),
                  );
                  Widget? actionOverlaysFor(PadSheetFrame? padFrame) => switch ((ui, _details)) {
                    (final ui?, final details?) => ListenableBuilder(
                      listenable: details,
                      builder: (context, _) => ActionOverlays(
                        actions: details.actions,
                        controller: _overlays,
                        landscape: layout == Presentation.landscape,
                        shareLink: ui.session.shareLink,
                        padFrame: padFrame,
                      ),
                    ),
                    _ => null,
                  };
                  final actionOverlays = pad ? null : actionOverlaysFor(null);
                  // Built once per page build, so scrolling and the shrink rebuild none of it.
                  final padBody = pad
                      ? _padBody(
                          context,
                          sideways: sideways,
                          fullScreen: fullScreen,
                          top: top,
                          pager: pager,
                          tabRow: tabRow,
                          belowPlayer: belowPlayer,
                        )
                      : null;
                  // Only the player's box follows the scrolling, the grow and the turn; everything else is built once
                  // per page build.
                  return ListenableBuilder(
                    listenable: Listenable.merge([_collapse, _grow, _spin, _padFull]),
                    builder: (context, _) {
                      if (padBody != null) {
                        return _turned(
                          spinning: false,
                          _padPage(
                            constraints: constraints,
                            top: top,
                            columnWidth: columnWidth,
                            fullScreen: fullScreen,
                            area: area,
                            ui: ui,
                            controller: controller,
                            actionOverlays: actionOverlaysFor,
                            layout: layout,
                            body: padBody,
                          ),
                        );
                      }
                      final height = fullScreen ? constraints.maxHeight : _collapse.height;
                      final box = fullScreen ? height : top + height;
                      final progress = fullScreen ? 0.0 : _collapse.progress;
                      final turn = _turning(constraints.biggest, layout, upright.top);
                      final spinning = _spinning;
                      final waiting = _turnFrom != null || _pendingTurn != null;
                      final hidden = fullScreen && turn?.body == null;
                      final player = turn?.box ?? Rect.fromLTWH(0, 0, constraints.maxWidth, box);
                      _pin.value = turn == null ? null : Size(constraints.maxWidth, height);
                      _verticalTurn.value = turn != null && _upright == Presentation.vertical ? turn.t : null;
                      // The chrome goes from the change of presentation, so the host's still picture has none either.
                      _turningPlayer.value = turn != null || spinning || waiting;
                      // The tab row and the list ride on the player's bottom edge, at their upright size.
                      final body = turn?.body ?? Offset.zero;
                      final window = turn?.window;
                      // Only while the page draws a turn: a clipper bounds hit testing too.
                      Widget windowed(Offset origin, Widget child) => ClipRect(
                        clipper: window == null ? null : _WindowClip(window.shift(-origin)),
                        clipBehavior: window == null ? Clip.none : Clip.hardEdge,
                        child: child,
                      );
                      final uprightBox = upright.top + _collapse.height;
                      final tabRowHeight = _offline ? OfflinePageTheme.headerHeight : PageTheme.tabRowHeight;
                      final tabsTop = _offline
                          ? uprightBox + tabRowHeight
                          : upright.top + _collapse.barHeight + tabRowHeight;
                      final screen = Offset.zero & constraints.biggest;
                      // Turned, a backdrop the screen's size would bare its corners.
                      final reach = constraints.biggest.bottomRight(Offset.zero).distance;
                      final backdrop = spinning
                          ? Rect.fromCenter(center: screen.center, width: reach, height: reach)
                          : screen;
                      final page = Stack(
                        // The growing box overflows the upright page; a clip here would also mask the native view.
                        clipBehavior: Clip.none,
                        children: [
                          if (turn != null || spinning)
                            Positioned.fromRect(
                              key: const ValueKey('page-turn-backdrop'),
                              rect: backdrop,
                              child: const ColoredBox(color: BiliColors.videoBackground),
                            ),
                          Positioned(
                            key: const ValueKey('page-tabs-area'),
                            left: body.dx,
                            top: body.dy + tabsTop,
                            width: upright.size.width,
                            height: upright.size.height - tabsTop,
                            child: windowed(body.translate(0, tabsTop), hideable(hidden, pager)),
                          ),
                          Positioned(
                            key: const ValueKey('page-tab-row'),
                            left: body.dx,
                            top: body.dy + uprightBox,
                            width: upright.size.width,
                            height: tabRowHeight,
                            child: windowed(body.translate(0, uprightBox), hideable(hidden, tabRow)),
                          ),
                          Positioned(
                            key: const ValueKey('page-player'),
                            left: player.left,
                            top: player.top,
                            width: player.width,
                            height: player.height,
                            child: ColoredBox(
                              color: BiliColors.videoBackground,
                              child: Padding(
                                padding: EdgeInsets.only(top: turn?.inset ?? (fullScreen ? 0 : top)),
                                child: area,
                              ),
                            ),
                          ),
                          if (progress > 0 && turn == null)
                            Positioned(
                              key: const ValueKey('collapse-bar'),
                              left: 0,
                              right: 0,
                              top: top,
                              height: height,
                              child: ExcludeSemantics(
                                excluding: _panels.value != null,
                                child: CollapsedPlayerBar(
                                  progress: progress,
                                  onResume: _resume,
                                  onBack: _back,
                                  onMore: () => _panels.open(PlayerPanel.more),
                                ),
                              ),
                            ),
                          Positioned(
                            key: const ValueKey('comment-overlays'),
                            left: body.dx,
                            top: body.dy,
                            width: upright.size.width,
                            height: upright.size.height,
                            child: windowed(
                              body,
                              Offstage(
                                offstage: hidden,
                                child: TickerMode(
                                  enabled: !hidden,
                                  child: ExcludeFocus(
                                    excluding: hidden,
                                    child: CommentOverlays(
                                      model: _comments,
                                      controller: _commentOverlays,
                                      callbacks: _commentCallbacks,
                                      threadTop: uprightBox,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            key: const ValueKey('uploader-sheet-layer'),
                            left: body.dx,
                            top: body.dy,
                            width: upright.size.width,
                            height: upright.size.height,
                            child: windowed(
                              body,
                              hideable(
                                hidden,
                                UploaderSheetLayer(
                                  controller: _uploaderSheet,
                                  top: uprightBox,
                                  playingBvid: (_attached ? controller?.video?.bvid : null) ?? _playback?.bvid,
                                  followingOf: _followingOf,
                                  requestLogin: _askLogin,
                                  // The app's, not the page's: a login from a space pushed over the sheet counts too.
                                  logins: _services!.environment.logins,
                                  openPage: widget.openPage,
                                ),
                              ),
                            ),
                          ),
                          if (ui != null)
                            Positioned.fill(
                              key: const ValueKey('video-panels'),
                              child: PanelLayer(ui: ui, playerBottom: fullScreen ? null : box),
                            ),
                          if (actionOverlays != null)
                            Positioned.fill(key: const ValueKey('video-overlays'), child: actionOverlays),
                          if (ui != null && _danmaku != null)
                            Positioned.fill(
                              key: const ValueKey('danmaku-overlays'),
                              child: DanmakuOverlays(
                                session: _danmaku!,
                                presentation: layout,
                                playerBottom: box,
                                toast: _toast,
                              ),
                            ),
                          if (_offline)
                            Positioned.fill(
                              key: const ValueKey('offline-sheet-layer'),
                              child: hideable(
                                hidden,
                                OfflineRowSheet(item: _offlineSheet, onDetails: _offlineDetails),
                              ),
                            ),
                        ],
                      );
                      return _turned(page, spinning: spinning);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The tab row under the small player. Before the session exists it shows the saved danmaku switch.
  Widget _tabRow(BuildContext context) {
    final session = _session;
    final danmaku = _danmaku;
    return ListenableBuilder(
      listenable: Listenable.merge([session ?? _tabs, _listCount, ?danmaku, ?danmaku?.sendOpen]),
      builder: (context, _) => _pad
          ? PadPageTabRow(
              controller: _tabs,
              replyCount: _listCount.value ?? _intro.detail?.stat.reply,
              danmakuOn: session?.danmakuOn ?? PlayerPrefs.shared.danmakuOn,
              onToggleDanmaku: session == null ? null : () => session.setDanmakuOn(!session.danmakuOn),
              onSendDanmaku: () => danmaku?.openSend(),
              danmakuInputOpen: danmaku?.sendOpen.value ?? false,
              danmakuClosed: danmaku?.closed ?? false,
            )
          : PageTabRow(
              controller: _tabs,
              replyCount: _listCount.value ?? _intro.detail?.stat.reply,
              danmakuOn: session?.danmakuOn ?? PlayerPrefs.shared.danmakuOn,
              onToggleDanmaku: session == null ? null : () => session.setDanmakuOn(!session.danmakuOn),
              onSendDanmaku: () => danmaku?.openSend(),
              danmakuInputOpen: danmaku?.sendOpen.value ?? false,
              danmakuClosed: danmaku?.closed ?? false,
            ),
    );
  }

  /// The iPad's 点我发弹幕 and 弹 toggle on the pinned strip.
  Widget _padCapsule() {
    final session = _session;
    final danmaku = _danmaku;
    return ListenableBuilder(
      listenable: Listenable.merge([session ?? _tabs, ?danmaku, ?danmaku?.sendOpen]),
      builder: (context, _) {
        final closed = danmaku?.closed ?? false;
        return PadDanmakuCapsule(
          on: session?.danmakuOn ?? PlayerPrefs.shared.danmakuOn,
          onToggle: session == null ? null : () => session.setDanmakuOn(!session.danmakuOn),
          onSend: closed ? null : () => danmaku?.openSend(),
          text: closed ? 'UP主已关闭弹幕' : ((danmaku?.sendOpen.value ?? false) ? '弹幕输入中' : '点我发弹幕'),
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
        );
      },
    );
  }

  /// The one chain every layout's page sits in, the iPad's too, so a turn or a change of layout remounts none of the
  /// page's layers. The whole page turns about the screen's centre; nothing clips it but the screen.
  Widget _turned(Widget page, {required bool spinning}) => IgnorePointer(
    ignoring: spinning,
    child: Transform.rotate(
      key: const ValueKey('page-turn'),
      angle: _rotation,
      child: UploaderTap(open: _openUploader, child: page),
    ),
  );

  /// The iPad's player box shrinks over the video rather than shrinking it while paused: the video keeps the height the
  /// shrink started from, its top going under the status bar's band as the page scrolls (20). Playing, it follows the
  /// box.
  Widget _padArea(Widget area, {required bool fullScreen, required bool growing}) {
    final kept = !fullScreen && !growing && (_collapse.paused || _collapse.progress > 0);
    final height = _collapse.shrinkStart;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.bottomCenter,
        minHeight: kept ? height : null,
        maxHeight: kept ? height : null,
        child: area,
      ),
    );
  }

  /// What the iPad's page shows under and beside its player: sideways (03, 05) the column of 简介 and 热门评论 with the
  /// related videos on the right and the strip and 发条评论 bar pinned once paused and scrolled; upright (06) the tab
  /// row over 简介 | 评论.
  _PadBody _padBody(
    BuildContext context, {
    required bool sideways,
    required bool fullScreen,
    required double top,
    required Widget pager,
    required Widget tabRow,
    required Widget Function(Widget child) belowPlayer,
  }) {
    if (!sideways) return (tabs: pager, tabRow: tabRow, related: null, strip: null);
    final details = _details;
    final detail = _intro.detail;
    final session = _session;
    final comments = _comments;
    final intro = _tabs.scrollOf(PageTab.intro);
    final column = PadPlayerColumn(
      controller: intro,
      headKey: _padHeadKey,
      headHeight: _padHeadHeight,
      head: session == null || details == null || detail == null
          ? null
          : PadIntroHead(
              content: _intro,
              details: details,
              onSeek: (seconds) => unawaited(session.seekAndPlay(seconds)),
              onOpenVideo: (id) => unawaited(_openVideoId(id)),
              onPlayEpisode: session.playEpisode,
              onOpenEpisodes: () => _panels.open(PlayerPanel.episodes),
              player: session,
              danmaku: _danmaku,
            ),
      comments: comments == null
          ? null
          : PadCommentsSection(
              key: ObjectKey(comments),
              model: comments,
              callbacks: _commentCallbacks,
              onSeeAll: _seeAllComments,
            ),
      bottom: PadCommentWriteBar.height,
    );
    final related = DecoratedBox(
      decoration: BoxDecoration(
        color: BiliColors.colorsOf(context).card,
        border: Border(
          left: BorderSide(color: PadPageTheme.colorsOf(context).ruleColour, width: PadPageTheme.rule),
          top: BorderSide(color: PadPageTheme.colorsOf(context).ruleColour, width: PadPageTheme.rule),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: PadPageTheme.rule, top: PadPageTheme.rule),
        // Leaving, a related row's cover would otherwise fly back to a feed card showing the same video.
        child: HeroMode(
          enabled: !_left || _replaced,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: PadRelatedColumn(
              cards: _intro.related,
              onOpen: _openRelated,
              onWatchLater: (card) => unawaited(_watchLater(card)),
            ),
          ),
        ),
      ),
    );
    final pinned = detail == null || details == null
        ? null
        : belowPlayer(
            PadPinnedStrip(
              detail: detail,
              details: details,
              capsule: _padCapsule(),
              onFace: () =>
                  _openUploader(UploaderRef(mid: detail.owner.mid, name: detail.owner.name, face: detail.owner.face)),
            ),
          );
    final writeBar = comments == null || comments.closedMessage != null
        ? null
        : belowPlayer(
            PadCommentWriteBar(
              prompt: comments.rootPrompt,
              onWrite: (emotes) => _commentCallbacks.reply(const ReplyToVideo(), emotes),
              onTop: () => _tabs.scrollToTop(tab: PageTab.intro, animate: !MediaQuery.disableAnimationsOf(context)),
            ),
          );
    // The strip and the 发条评论 bar come once the player is the bar and 简介's actions are under it; only they follow
    // the column's scrolling.
    final strip = ListenableBuilder(
      listenable: Listenable.merge([_collapse, intro, _padHeadHeight]),
      builder: (context, _) {
        final head = _padHeadHeight.value;
        final shown =
            pinned != null &&
            !fullScreen &&
            _collapse.progress >= 1 &&
            head != null &&
            _collapse.reserve - _tabs.offsetOf(PageTab.intro) + head <= PadPageTheme.stripHeight;
        return Stack(
          children: [
            if (shown)
              Positioned(
                left: 0,
                right: 0,
                top: top + _collapse.barHeight,
                height: PadPageTheme.stripHeight,
                child: pinned,
              ),
            if (shown && writeBar != null)
              Positioned(key: const ValueKey('pad-comment-bar'), left: 0, right: 0, bottom: 0, child: writeBar),
          ],
        );
      },
    );
    return (
      tabs: belowPlayer(CollapseReserve(collapse: _collapse, child: column)),
      tabRow: null,
      related: related,
      strip: strip,
    );
  }

  /// The iPad's page (03, 05, 06, 22): the player in its column, growing over everything for full screen, and the
  /// page's layers under the same keys whichever way the iPad is held.
  Widget _padPage({
    required BoxConstraints constraints,
    required double top,
    required double columnWidth,
    required bool fullScreen,
    required Widget area,
    required PlayerUi? ui,
    required PlaybackController? controller,
    required Widget? Function(PadSheetFrame? padFrame) actionOverlays,
    required Presentation layout,
    required _PadBody body,
  }) {
    final screen = Offset.zero & constraints.biggest;
    final t = PadPageTheme.fullScreenCurve.transform(_padFull.value);
    final growing = _padFull.isAnimating;
    _pin.value = null;
    _verticalTurn.value = null;
    _turningPlayer.value = growing;
    final hidden = fullScreen && !growing;
    final height = _collapse.height;
    final progress = fullScreen ? 0.0 : _collapse.progress;
    final box = fullScreen ? constraints.maxHeight : top + height;
    final tabRow = body.tabRow;
    final rowHeight = _offline ? OfflinePageTheme.headerHeight : PadPageTheme.tabRowHeight;
    final tabsTop = _offline
        ? top + height + rowHeight
        : top + _collapse.barHeight + (tabRow == null ? 0 : PadPageTheme.tabRowHeight);
    final player = Rect.lerp(Rect.fromLTWH(0, 0, columnWidth, top + height), screen, t)!;
    final padFrame = fullScreen
        ? null
        : PadSheetFrame(
            player: Rect.fromLTRB(player.left, player.top + top * (1 - t), player.right, player.bottom),
            column: columnWidth,
          );
    final overlays = actionOverlays(padFrame);
    Widget hideable(Widget child) => Offstage(offstage: hidden, child: TickerMode(enabled: !hidden, child: child));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (body.related case final related?) ...[
          Positioned(
            key: const ValueKey('pad-status-band'),
            left: 0,
            right: 0,
            top: 0,
            height: top,
            child: const ColoredBox(color: BiliColors.videoBackground),
          ),
          Positioned(
            key: const ValueKey('pad-related-column'),
            left: columnWidth,
            top: top,
            right: 0,
            bottom: 0,
            child: hideable(related),
          ),
        ],
        Positioned(
          key: const ValueKey('page-tabs-area'),
          left: 0,
          top: tabsTop,
          width: columnWidth,
          bottom: 0,
          child: hideable(body.tabs),
        ),
        if (tabRow != null)
          Positioned(
            key: const ValueKey('page-tab-row'),
            left: 0,
            top: top + height,
            width: columnWidth,
            height: rowHeight,
            child: hideable(tabRow),
          ),
        if (body.strip case final strip?)
          Positioned(
            key: const ValueKey('pad-strip-layer'),
            left: 0,
            top: 0,
            width: columnWidth,
            bottom: 0,
            child: strip,
          ),
        Positioned(
          key: const ValueKey('page-player'),
          left: player.left,
          top: player.top,
          width: player.width,
          height: player.height,
          child: ColoredBox(
            color: BiliColors.videoBackground,
            child: Padding(
              padding: EdgeInsets.only(top: top * (1 - t)),
              child: _padArea(area, fullScreen: fullScreen, growing: growing),
            ),
          ),
        ),
        if (progress > 0 && !growing)
          Positioned(
            key: const ValueKey('collapse-bar'),
            left: 0,
            top: top,
            width: columnWidth,
            height: height,
            child: ExcludeSemantics(
              excluding: _panels.value != null,
              child: PadPlayerBar(
                progress: progress,
                onResume: _resume,
                onBack: _back,
                onMore: () => _panels.open(PlayerPanel.more),
              ),
            ),
          ),
        Positioned(
          key: const ValueKey('comment-overlays'),
          left: 0,
          top: 0,
          width: columnWidth,
          height: constraints.maxHeight,
          child: Offstage(
            offstage: hidden,
            child: TickerMode(
              enabled: !hidden,
              child: ExcludeFocus(
                excluding: hidden,
                child: CommentOverlays(
                  model: _comments,
                  controller: _commentOverlays,
                  callbacks: _commentCallbacks,
                  threadTop: top + height,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          key: const ValueKey('uploader-sheet-layer'),
          left: 0,
          top: 0,
          width: columnWidth,
          height: constraints.maxHeight,
          child: hideable(
            UploaderSheetLayer(
              controller: _uploaderSheet,
              top: top + height,
              playingBvid: (_attached ? controller?.video?.bvid : null) ?? _playback?.bvid,
              followingOf: _followingOf,
              requestLogin: _askLogin,
              logins: _services!.environment.logins,
              openPage: widget.openPage,
            ),
          ),
        ),
        if (ui != null)
          Positioned.fill(
            key: const ValueKey('video-panels'),
            child: PanelLayer(ui: ui, playerBottom: fullScreen ? null : box, padFrame: padFrame),
          ),
        if (overlays != null) Positioned.fill(key: const ValueKey('video-overlays'), child: overlays),
        if (ui != null && _danmaku != null)
          Positioned.fill(
            key: const ValueKey('danmaku-overlays'),
            child: DanmakuOverlays(
              session: _danmaku!,
              presentation: layout,
              playerBottom: box,
              toast: _toast,
              padFrame: padFrame,
            ),
          ),
        if (_offline)
          Positioned.fill(
            key: const ValueKey('offline-sheet-layer'),
            child: hideable(OfflineRowSheet(item: _offlineSheet, onDetails: _offlineDetails)),
          ),
      ],
    );
  }

  /// 简介 | 评论. Before the session exists 简介 stays empty.
  Widget _pager(BuildContext context) {
    final session = _session;
    final details = _details;
    // Leaving, a related row's cover would otherwise fly back to a feed card showing the same video.
    return HeroMode(
      enabled: !_left || _replaced,
      child: PageTabs(
        controller: _tabs,
        intro: session == null || details == null
            ? const SizedBox.expand()
            : IntroTab(
                content: _intro,
                details: details,
                onSeek: (seconds) => unawaited(session.seekAndPlay(seconds)),
                onOpenVideo: (id) => unawaited(_openVideoId(id)),
                onPlayEpisode: session.playEpisode,
                onOpenEpisodes: () => _panels.open(PlayerPanel.episodes),
                onOpenRelated: _openRelated,
                onWatchLater: (card) => unawaited(_watchLater(card)),
              ),
        comments: switch (_comments) {
          final comments? => CommentsTab(
            key: ObjectKey(comments),
            model: comments,
            callbacks: _commentCallbacks,
          ),
          null => const CommentsSlot(),
        },
      ),
    );
  }

  /// The first load and a reload (quality, codec, replay); [_dataWait] covers waits mid-play.
  bool _loading(PlaybackController? controller, bool mine) {
    if (_playback?.startError != null || _covered) return false;
    if (mine) return controller!.phase == PlaybackPhase.loading;
    return !_left;
  }

  String? _failure(PlaybackController? controller, bool mine) {
    if (_playback?.startError case final error?) return '播放器启动失败：$error';
    if (mine && controller!.phase == PlaybackPhase.failed) return controller.error ?? '播放失败';
    return null;
  }

  /// The card's cover flies in and stays until this page's video first plays, then goes for good, as the official
  /// app's page opens.
  Widget? _cover(BuildContext context) {
    final route = widget.route;
    final cover = route.cover;
    if (cover == null) return null;
    // Two Heroes with one tag in a page throw at the next push or pop, and after another video opened on the page its
    // related videos can hold this one. HeroMode rather than no Hero, so the cover keeps its element.
    final flies = !_played && !_intro.related.any((card) => card.bvid == route.bvid);
    return IgnorePointer(
      key: const ValueKey('video-cover'),
      child: AnimatedOpacity(
        opacity: _played ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: HeroMode(
          enabled: flies,
          child: Hero(
            tag: route.heroTag,
            flightShuttleBuilder: _coverInFlight,
            child: RemoteImage(cover, size: _coverSize(context), cover: true, preset: CoverPreset.player),
          ),
        ),
      ),
    );
  }

  /// The player box's final size: the cover is asked for once at it, however the box grows during the flight.
  static Size _coverSize(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    final width = padSideways(context) ? padPlayerColumnWidth(screen) : screen;
    return Size(width, width / BiliMetrics.videoAspect);
  }

  /// The card's image, already loaded as the card asked for it (its size, its CDN suffix, or its cover size and
  /// preset), flies; the page's cover, the same download as the page's own, fades in over it once it arrives.
  Widget _coverInFlight(
    BuildContext flight,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final cover = widget.route.cover;
    final cardHero = direction == HeroFlightDirection.push ? from : to;
    final card = cardHero.findRenderObject();
    final cardSize = card is RenderBox && card.hasSize ? card.size : null;
    final (cardSuffix, cardCover, cardPreset) = switch (cardHero.widget) {
      Hero(child: RemoteImage(:final cdnSuffix, cover: final cardCover, :final preset)) => (
        cdnSuffix,
        cardCover,
        preset,
      ),
      _ => (null, false, null),
    };
    return RemoteImage(
      cover,
      size: _coverSize(flight),
      cover: true,
      preset: CoverPreset.player,
      placeholder: cardSize == null
          ? null
          : RemoteImage(cover, size: cardSize, cdnSuffix: cardSuffix, cover: cardCover, preset: cardPreset),
    );
  }
}

/// The iPad page's pieces below and beside the player, built once per page build: [tabs] under the player (the
/// sideways column, or the upright pager), [tabRow] upright, [related] and the pinned [strip] sideways.
typedef _PadBody = ({Widget tabs, Widget? tabRow, Widget? related, Widget? strip});

/// The turning window, in the clipped child's coordinates.
class _WindowClip extends CustomClipper<Rect> {
  const _WindowClip(this.window);

  final Rect window;

  @override
  Rect getClip(Size size) => window;

  @override
  bool shouldReclip(_WindowClip oldClipper) => oldClipper.window != window;
}
