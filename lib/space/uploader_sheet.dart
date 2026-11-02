import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart' show SpaceProfile;
import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../app/app_environment.dart' show LoggedIn;
import '../app/app_scope.dart';
import '../comments/comments_tab.dart' show NearEndPaging;
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/actions/unfollow_confirm.dart';
import '../video/video_route.dart';
import 'space_follow.dart';
import 'space_route.dart';
import 'uploader_sheet_grid.dart';
import 'uploader_sheet_model.dart';
import 'uploader_tap.dart';

typedef SheetVideoOpener = Future<void> Function(BuildContext context, VideoRoute route);

/// Which uploader the page's sheet shows, and whether its unfollow confirm is up, so the page's back closes them
/// first.
class UploaderSheetController extends ChangeNotifier {
  UploaderRef? _uploader;
  int _opening = 0;
  bool _confirming = false;

  UploaderRef? get uploader => _uploader;
  bool get isOpen => _uploader != null;
  bool get confirming => _confirming;

  /// Bumped for every opening, keying its sheet.
  int get opening => _opening;

  void open(UploaderRef uploader) {
    _uploader = uploader;
    _opening++;
    _confirming = false;
    notifyListeners();
  }

  void close() {
    if (_uploader == null && !_confirming) return;
    _uploader = null;
    _confirming = false;
    notifyListeners();
  }

  void confirmUnfollow() {
    if (_uploader == null || _confirming) return;
    _confirming = true;
    notifyListeners();
  }

  void closeConfirm() {
    if (!_confirming) return;
    _confirming = false;
    notifyListeners();
  }

  /// Back: the confirm first, then the sheet. False when neither is up.
  bool back() {
    if (_confirming) {
      closeConfirm();
      return true;
    }
    if (_uploader == null) return false;
    close();
    return true;
  }
}

/// The video page's uploader sheet in its Stack (62, 68, 76): it rises from the bottom to [top], the player box's
/// bottom, leaving the player above it playing and usable, and the unfollow confirm goes over the whole page. An edge
/// swipe lowers it with the finger and closes it, since the page's held PopScope turns the route's own swipe off.
/// Lets touches through where nothing is up.
class UploaderSheetLayer extends StatefulWidget {
  const UploaderSheetLayer({
    super.key,
    required this.controller,
    required this.top,
    required this.playingBvid,
    this.followingOf,
    this.requestLogin,
    this.logins,
    this.openPage = openVideoPage,
  });

  final UploaderSheetController controller;
  final double top;
  final String? playingBvid;

  /// The page's own 关注 for its uploader, so the sheet starts from it instead of asking; null for anyone else, and
  /// while the page doesn't know.
  final bool? Function(int mid)? followingOf;
  final VoidCallback? requestLogin;

  /// Fires for each login made from the page.
  final Listenable? logins;
  final SheetVideoOpener openPage;

  @override
  State<UploaderSheetLayer> createState() => _UploaderSheetLayerState();
}

class _UploaderSheetLayerState extends State<UploaderSheetLayer> with TickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this);
  late final CurvedAnimation _slide = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final AnimationController _confirmMotion = AnimationController(vsync: this);
  late final CurvedAnimation _confirmCurve = CurvedAnimation(
    parent: _confirmMotion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// How far an edge swipe has lowered the sheet, and its spring back when let go short of closing.
  final _edge = ValueNotifier<double>(0);
  late final AnimationController _edgeBack = AnimationController(vsync: this);
  double _edgeFrom = 0;
  late final HorizontalDragGestureRecognizer _swipe = HorizontalDragGestureRecognizer(debugOwner: this)
    ..onStart = _swipeStarted
    ..onUpdate = _swipeMoved
    ..onEnd = _swipeEnded
    ..onCancel = _swipeCancelled;
  bool _swiping = false;

  /// The sheet on screen: the controller's, or the last one while it slides away.
  UploaderRef? _shown;
  int _shownOpening = 0;
  bool _confirmShown = false;
  VoidCallback? _unfollow;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _edgeBack.addListener(() => _edge.value = _edgeFrom * (1 - Curves.easeOutCubic.transform(_edgeBack.value)));
    widget.controller.addListener(_changed);
    if (widget.controller.uploader case final uploader?) {
      _shown = uploader;
      _shownOpening = widget.controller.opening;
      _motion.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _motion
      ..duration = _still ? Duration.zero : UploaderSheetTheme.rise
      ..reverseDuration = _still ? Duration.zero : UploaderSheetTheme.fall;
    _confirmMotion
      ..duration = _still ? Duration.zero : UploaderSheetTheme.rise
      ..reverseDuration = _still ? Duration.zero : UploaderSheetTheme.fall;
    _edgeBack.duration = _still ? Duration.zero : UploaderSheetTheme.dragBack;
  }

  @override
  void didUpdateWidget(UploaderSheetLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _swipe.dispose();
    _edgeBack.dispose();
    _edge.dispose();
    _slide.dispose();
    _motion.dispose();
    _confirmCurve.dispose();
    _confirmMotion.dispose();
    super.dispose();
  }

  void _changed() {
    final controller = widget.controller;
    _syncConfirm(controller.confirming);
    final next = controller.uploader;
    if (next == null) {
      if (_shown == null) return;
      _swiping = false;
      setState(() {});
      _motion.reverse().whenCompleteOrCancel(() {
        if (!mounted || !_motion.isDismissed || widget.controller.uploader != null) return;
        setState(() => _shown = null);
      });
      return;
    }
    if (controller.opening == _shownOpening && _shown != null && _motion.status != AnimationStatus.reverse) return;
    final wasShown = _shown != null;
    setState(() {
      _shown = next;
      _shownOpening = controller.opening;
    });
    _edgeBack.stop();
    _edge.value = 0;
    // Opened again while sliding away: it turns around where it is.
    unawaited(_motion.forward(from: wasShown ? null : 0));
  }

  void _syncConfirm(bool up) {
    if (up && !_confirmShown) {
      setState(() => _confirmShown = true);
      unawaited(_confirmMotion.forward(from: 0));
    } else if (!up && _confirmShown && _confirmMotion.status != AnimationStatus.reverse) {
      setState(() {});
      _confirmMotion.reverse().whenCompleteOrCancel(() {
        if (!mounted || !_confirmMotion.isDismissed || widget.controller.confirming) return;
        setState(() {
          _confirmShown = false;
          _unfollow = null;
        });
      });
    }
  }

  void _askUnfollow(VoidCallback unfollow) {
    _unfollow = unfollow;
    widget.controller.confirmUnfollow();
  }

  void _edgeDown(PointerDownEvent event) {
    if (widget.controller.isOpen && !widget.controller.confirming) _swipe.addPointer(event);
  }

  void _swipeStarted(DragStartDetails details) {
    if (!widget.controller.isOpen) return;
    _edgeBack.stop();
    _swiping = true;
  }

  /// The finger's travel to the right lowers the sheet by as much.
  void _swipeMoved(DragUpdateDetails details) {
    if (!_swiping) return;
    _edge.value = math.max(0, _edge.value + details.primaryDelta!);
  }

  void _swipeEnded(DragEndDetails details) {
    if (!_swiping) return;
    _swiping = false;
    final width = context.size?.width ?? 0;
    final speed = width > 0 ? details.velocity.pixelsPerSecond.dx / width : 0.0;
    final height = _sheetHeight;
    final close = speed.abs() >= UploaderSheetTheme.edgeFlingWidths
        ? speed > 0
        : height > 0 && _edge.value / height > UploaderSheetTheme.edgeCloseShare;
    if (close) {
      widget.controller.close();
    } else {
      _springBack();
    }
  }

  void _swipeCancelled() {
    if (!_swiping) return;
    _swiping = false;
    _springBack();
  }

  void _springBack() {
    _edgeFrom = _edge.value;
    if (_edgeFrom > 0) unawaited(_edgeBack.forward(from: 0));
  }

  double get _sheetHeight => math.max(0, (context.size?.height ?? 0) - widget.top);

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final open = widget.controller.isOpen;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.max(0.0, constraints.maxHeight - widget.top);
        return Stack(
          children: [
            if (shown != null) ...[
              Positioned(
                key: const ValueKey('uploader-sheet'),
                left: 0,
                right: 0,
                top: widget.top,
                height: height,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_slide, _edge]),
                  builder: (context, child) =>
                      Transform.translate(offset: Offset(0, (1 - _slide.value) * height + _edge.value), child: child),
                  child: IgnorePointer(
                    ignoring: !open,
                    child: ExcludeSemantics(
                      excluding: !open,
                      child: UploaderSheet(
                        key: ValueKey(_shownOpening),
                        uploader: shown,
                        playingBvid: widget.playingBvid,
                        onClose: widget.controller.close,
                        confirmUnfollow: _askUnfollow,
                        following: widget.followingOf?.call(shown.mid),
                        requestLogin: widget.requestLogin,
                        logins: widget.logins,
                        openPage: widget.openPage,
                      ),
                    ),
                  ),
                ),
              ),
              if (open)
                // The whole left edge, the player's included: with the sheet up the edge swipe closes it first.
                Positioned(
                  key: const ValueKey('uploader-sheet-edge'),
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: math.max(BiliMetrics.swipeBackEdge, MediaQuery.paddingOf(context).left),
                  child: Listener(behavior: HitTestBehavior.translucent, onPointerDown: _edgeDown),
                ),
            ],
            if (_confirmShown)
              Positioned.fill(
                key: const ValueKey('uploader-sheet-confirm'),
                child: IgnorePointer(
                  ignoring: !widget.controller.confirming,
                  child: BlockSemantics(
                    blocking: widget.controller.confirming,
                    child: UnfollowConfirm(
                      motion: _confirmCurve,
                      onConfirm: () {
                        final unfollow = _unfollow;
                        widget.controller.closeConfirm();
                        unfollow?.call();
                      },
                      onCancel: widget.controller.closeConfirm,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One uploader's sheet (62, 68, 76): the grabber, the face, name, 关注 and counts with 进入空间 ›, and a two-column
/// grid of their videos, newest first, under it. Dragged down by its header, or pulled down with the grid at its top,
/// it follows the finger and closes through [onClose] once let go far or fast enough.
class UploaderSheet extends StatefulWidget {
  const UploaderSheet({
    super.key,
    required this.uploader,
    required this.playingBvid,
    required this.onClose,
    required this.confirmUnfollow,
    this.following,
    this.requestLogin,
    this.logins,
    this.openPage = openVideoPage,
  });

  final UploaderRef uploader;

  /// The page's video, whose card draws its title pink.
  final String? playingBvid;
  final VoidCallback onClose;

  /// Puts 确定不再关注？ up; its 确定 runs the given unfollow.
  final void Function(VoidCallback unfollow) confirmUnfollow;

  /// What the page already knows of 关注 for this uploader; null asks the web card.
  final bool? following;

  /// Null takes the app's login gate.
  final VoidCallback? requestLogin;
  final Listenable? logins;
  final SheetVideoOpener openPage;

  @override
  State<UploaderSheet> createState() => _UploaderSheetState();
}

class _UploaderSheetState extends State<UploaderSheet> with SingleTickerProviderStateMixin {
  UploaderSheetModel? _model;
  SpaceFollow? _follow;
  late final _paging = NearEndPaging(canAsk: () => _model?.canLoadMore ?? false, ask: () => _model!.loadMore());
  final _scroll = ScrollController();

  /// How far a drag has pulled the sheet down, and its spring back when let go short of closing.
  final _drag = ValueNotifier<double>(0);
  late final AnimationController _dragBack = AnimationController(vsync: this);
  double _dragFrom = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _dragBack.addListener(() => _drag.value = _dragFrom * (1 - Curves.easeOutCubic.transform(_dragBack.value)));
    widget.logins?.addListener(_loggedIn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dragBack.duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : UploaderSheetTheme.dragBack;
    if (_model != null) return;
    final services = AppScope.of(context);
    final mid = widget.uploader.mid;
    final model = UploaderSheetModel(mid: mid, api: services.spaceApi)..addListener(_rebuild);
    _model = model;
    unawaited(model.start());
    final follow = SpaceFollow(
      mid: mid,
      api: services.pageApi,
      book: services.follows,
      isLoggedIn: () => services.environment.account is LoggedIn,
      requestLogin: widget.requestLogin ?? () => unawaited(services.loginGate.request(context)),
      toast: _toast,
      following: widget.following,
    )..addListener(_rebuild);
    _follow = follow;
    if (widget.following == null) unawaited(follow.load());
  }

  @override
  void didUpdateWidget(UploaderSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.logins, widget.logins)) {
      oldWidget.logins?.removeListener(_loggedIn);
      widget.logins?.addListener(_loggedIn);
    }
  }

  @override
  void dispose() {
    widget.logins?.removeListener(_loggedIn);
    _paging.dispose();
    _model
      ?..removeListener(_rebuild)
      ..dispose();
    _follow
      ?..removeListener(_rebuild)
      ..dispose();
    _scroll.dispose();
    _dragBack.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Any login, the space's above included: this account's 关注.
  void _loggedIn() => unawaited(_follow?.reload());

  void _toast(String message) {
    if (mounted) showToast(context, message);
  }

  void _tapFollow() {
    final follow = _follow;
    if (follow == null) return;
    if (follow.following ?? false) {
      widget.confirmUnfollow(() => unawaited(follow.toggle()));
    } else {
      unawaited(follow.toggle());
    }
  }

  UploaderRef get _ref {
    final profile = _model?.profile;
    final ref = widget.uploader;
    if (profile == null) return ref;
    return UploaderRef(
      mid: ref.mid,
      name: profile.name.isEmpty ? ref.name : profile.name,
      face: profile.face.isEmpty ? ref.face : profile.face,
    );
  }

  void _openSpace() => unawaited(openSpace(context, _ref));

  /// The page's own video opens nothing, as a link to it in 简介 doesn't.
  void _openVideo(String bvid, String title, String cover) {
    if (bvid == widget.playingBvid) return;
    unawaited(widget.openPage(context, VideoRoute(bvid: bvid, title: title, cover: cover)));
  }

  void _dragBy(double dy) {
    if (_closing) return;
    _dragBack.stop();
    _drag.value = math.max(0, _drag.value + dy);
  }

  void _dragEnded(double velocity) {
    if (_closing || _drag.value <= 0) return;
    final height = context.size?.height ?? 0;
    if (velocity > UploaderSheetTheme.flingClose ||
        (height > 0 && _drag.value / height > UploaderSheetTheme.dragClose)) {
      _closing = true;
      widget.onClose();
      return;
    }
    _dragFrom = _drag.value;
    unawaited(_dragBack.forward(from: 0));
  }

  /// A pull down past the grid's top drags the sheet; its release lets it go.
  bool _scrolled(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    switch (notification) {
      case OverscrollNotification(:final overscroll, dragDetails: _?) when overscroll < 0:
        _dragBy(-overscroll);
      case ScrollUpdateNotification(:final scrollDelta?, dragDetails: _?) when _drag.value > 0 && scrollDelta > 0:
        _dragBy(-scrollDelta);
      case ScrollEndNotification(:final dragDetails):
        _dragEnded(dragDetails?.primaryVelocity ?? 0);
      default:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final model = _model!;
    return AnimatedBuilder(
      animation: _drag,
      builder: (context, child) => Transform.translate(offset: Offset(0, _drag.value), child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: UploaderSheetTheme.colorsOf(context).fill,
          borderRadius: BorderRadius.vertical(top: Radius.circular(UploaderSheetTheme.radius)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: UploaderSheetTheme.gridTop,
              child: GestureDetector(
                key: const ValueKey('uploader-sheet-header'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => _dragBack.stop(),
                onVerticalDragUpdate: (details) => _dragBy(details.delta.dy),
                onVerticalDragEnd: (details) => _dragEnded(details.primaryVelocity ?? 0),
                child: _Header(
                  uploader: _ref,
                  profile: model.profile,
                  following: _follow?.following ?? false,
                  onFollow: _tapFollow,
                  onOpenSpace: _openSpace,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: UploaderSheetTheme.gridTop,
              bottom: 0,
              child: model.hasLoaded
                  ? NotificationListener<ScrollNotification>(onNotification: _scrolled, child: _grid(context, model))
                  : UploaderSheetFirstLoad(error: model.loading ? null : model.error, onRetry: _retry),
            ),
          ],
        ),
      ),
    );
  }

  void _retry() => unawaited(_model?.retry());

  Widget _grid(BuildContext context, UploaderSheetModel model) {
    final videos = model.videos;
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = (constraints.maxWidth - UploaderSheetTheme.gridSide * 2 - UploaderSheetTheme.gridGap) / 2;
        return _paging.listen(
          CustomScrollView(
            key: const ValueKey('uploader-sheet-grid'),
            controller: _scroll,
            physics: const SheetGridPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: UploaderSheetTheme.gridSide),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: UploaderSheetTheme.gridGap,
                    mainAxisExtent: column / UploaderSheetTheme.coverAspect + UploaderSheetTheme.belowCover,
                  ),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return UploaderVideoCard(
                      key: ValueKey(video.bvid),
                      video: video,
                      playing: video.bvid == widget.playingBvid,
                      onOpen: () => _openVideo(video.bvid, video.title, video.cover),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: UploaderSheetFooter(
                  loading: model.loading,
                  error: model.error,
                  isEnd: model.isEnd,
                  onRetry: _retry,
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        );
      },
    );
  }
}

/// The grabber, then the face, the name with its 关注 pill and the counts under them, and 进入空间 › on the right.
class _Header extends StatelessWidget {
  const _Header({
    required this.uploader,
    required this.profile,
    required this.following,
    required this.onFollow,
    required this.onOpenSpace,
  });

  final UploaderRef uploader;
  final SpaceProfile? profile;
  final bool following;
  final VoidCallback onFollow;
  final VoidCallback onOpenSpace;

  static const _textLeft = UploaderSheetTheme.side + UploaderSheetTheme.face + UploaderSheetTheme.textGap;

  @override
  Widget build(BuildContext context) {
    const pad = UploaderSheetTheme.targetPad;
    final name = sheetStyle(
      UploaderSheetTheme.nameText,
      UploaderSheetTheme.colorsOf(context).nameInk,
      line: UploaderSheetTheme.nameLine,
      weight: UploaderSheetTheme.nameWeight,
    );
    final enter = sheetStyle(
      UploaderSheetTheme.enterText,
      UploaderSheetTheme.colorsOf(context).enterInk,
      line: UploaderSheetTheme.enterLine,
    );
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: UploaderSheetTheme.grabberTop,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: UploaderSheetTheme.grabberWidth,
              height: UploaderSheetTheme.grabberHeight,
              decoration: BoxDecoration(
                color: UploaderSheetTheme.colorsOf(context).grabber,
                borderRadius: BorderRadius.circular(UploaderSheetTheme.grabberHeight / 2),
              ),
            ),
          ),
        ),
        Positioned(
          left: UploaderSheetTheme.side - pad,
          top: UploaderSheetTheme.faceTop - pad,
          child: Semantics(
            button: true,
            label: '${uploader.name ?? ''}的空间',
            onTap: onOpenSpace,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('uploader-sheet-face'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpenSpace,
              child: Padding(
                padding: const EdgeInsets.all(pad),
                child: SizedBox.square(
                  dimension: UploaderSheetTheme.face,
                  child: ClipOval(child: RemoteImage.avatar(uploader.face)),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: _textLeft,
          right: UploaderSheetTheme.nameRight,
          top: UploaderSheetTheme.nameCentre - UploaderSheetTheme.followHeight / 2,
          height: UploaderSheetTheme.followHeight,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  uploader.name ?? '',
                  key: const ValueKey('uploader-sheet-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: name,
                  strutStyle: BiliFonts.strut(name),
                ),
              ),
              const SizedBox(width: UploaderSheetTheme.followGap),
              _FollowButton(following: following, onTap: onFollow),
            ],
          ),
        ),
        Positioned(
          left: _textLeft,
          right: UploaderSheetTheme.side,
          top: UploaderSheetTheme.countsCentre - UploaderSheetTheme.countsLine / 2,
          height: UploaderSheetTheme.countsLine,
          child: AnimatedOpacity(
            opacity: profile == null ? 0 : 1,
            duration: animate ? UploaderSheetTheme.countsFade : Duration.zero,
            curve: Curves.easeOut,
            child: _Counts(profile: profile),
          ),
        ),
        Positioned(
          right: UploaderSheetTheme.enterRight - pad,
          top: UploaderSheetTheme.enterCentre - UploaderSheetTheme.enterLine / 2 - pad,
          child: Semantics(
            button: true,
            label: '进入空间',
            onTap: onOpenSpace,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('uploader-sheet-enter'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpenSpace,
              child: Padding(
                padding: const EdgeInsets.all(pad),
                child: SizedBox(
                  height: UploaderSheetTheme.enterLine,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -UploaderSheetTheme.enterTextLift),
                        child: Text('进入空间', style: enter, strutStyle: BiliFonts.strut(enter)),
                      ),
                      const SizedBox(width: UploaderSheetTheme.chevronGap),
                      CustomPaint(
                        size: Size(UploaderSheetTheme.chevronWidth, UploaderSheetTheme.chevronHeight),
                        painter: _ChevronPainter(palette: BiliPalette.of(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 3万粉丝 71投稿 96.9万获赞, each count's digits set apart from its Chinese as PingFang does under the system font.
class _Counts extends StatelessWidget {
  const _Counts({required this.profile});

  final SpaceProfile? profile;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    final style = sheetStyle(
      UploaderSheetTheme.countsText,
      UploaderSheetTheme.colorsOf(context).countsInk,
      line: UploaderSheetTheme.countsLine,
    );
    final parts = profile == null
        ? const <String>[]
        : [
            '${CountFormat.short(profile.fans)}粉丝',
            '${CountFormat.short(profile.videoCount)}投稿',
            '${CountFormat.short(profile.likes)}获赞',
          ];
    final hanGap = BiliFonts.nudged ? 0.0 : UploaderSheetTheme.countsHanGap;
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, part) in parts.indexed)
            _spaced(part, hanGap, i == parts.length - 1 ? 0 : UploaderSheetTheme.countsGap),
        ],
      ),
      key: const ValueKey('uploader-sheet-counts'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
      strutStyle: BiliFonts.strut(style),
    );
  }

  /// [text] with [hanGap] after each digit that meets Chinese, and [after] after its last glyph.
  static TextSpan _spaced(String text, double hanGap, double after) {
    bool han(int unit) => unit >= 0x4E00 && unit <= 0x9FFF;
    bool digit(int unit) => (unit >= 0x30 && unit <= 0x39) || unit == 0x2E;
    final spans = <TextSpan>[];
    var start = 0;
    void cut(int end, double spacing) {
      if (end - 1 > start) spans.add(TextSpan(text: text.substring(start, end - 1)));
      spans.add(
        TextSpan(
          text: text[end - 1],
          style: TextStyle(letterSpacing: spacing),
        ),
      );
      start = end;
    }

    for (var i = 0; i + 1 < text.length; i++) {
      if (hanGap > 0 && digit(text.codeUnitAt(i)) && han(text.codeUnitAt(i + 1))) cut(i + 1, hanGap);
    }
    if (start < text.length) cut(text.length, after);
    return TextSpan(children: spans);
  }
}

/// + 关注 in pink, or 03's grey 已关注 once followed; the change cross-fades and the pill gives under the finger.
class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final following = widget.following;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final duration = animate ? UploaderSheetTheme.followMotion : Duration.zero;
    final ink = following ? UploaderSheetTheme.colorsOf(context).followedInk : BiliColors.onPink;
    final label = Text(
      following ? '已关注' : '关注',
      style: sheetStyle(UploaderSheetTheme.followText, ink).copyWith(height: 1),
    );
    return Semantics(
      button: true,
      label: following ? '已关注' : '关注',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('uploader-sheet-follow'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? UploaderSheetTheme.followPressedScale : 1,
          duration: animate ? UploaderSheetTheme.followPressMotion : Duration.zero,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            width: UploaderSheetTheme.followWidth,
            height: UploaderSheetTheme.followHeight,
            decoration: BoxDecoration(
              color: following ? UploaderSheetTheme.colorsOf(context).followedFill : BiliColors.colorsOf(context).pink,
              borderRadius: BorderRadius.circular(UploaderSheetTheme.followHeight / 2),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: duration,
              child: following
                  ? KeyedSubtree(key: const ValueKey('followed'), child: label)
                  : Row(
                      key: const ValueKey('follow'),
                      mainAxisSize: MainAxisSize.min,
                      spacing: UploaderSheetTheme.followPlusGap,
                      children: [
                        CustomPaint(size: const Size.square(UploaderSheetTheme.followPlus), painter: _PlusPainter(ink)),
                        label,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = UploaderSheetTheme.followPlusStroke;
    final centre = size.center(Offset.zero);
    canvas
      ..drawLine(Offset(0, centre.dy), Offset(size.width, centre.dy), line)
      ..drawLine(Offset(centre.dx, 0), Offset(centre.dx, size.height), line);
  }

  @override
  bool shouldRepaint(_PlusPainter oldDelegate) => oldDelegate.color != color;
}

class _ChevronPainter extends CustomPainter {
  final BiliPalette palette;

  const _ChevronPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = UploaderSheetTheme.chevronStroke / 2;
    final path = Path()
      ..moveTo(inset, inset)
      ..lineTo(size.width - inset, size.height / 2)
      ..lineTo(inset, size.height - inset);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = UploaderSheetTheme.chevronStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = UploaderSheetThemeColors(palette).chevronInk,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
