import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import '../shared/theme.dart';
import 'swipe_back_route.dart';

/// The global rect of the card a page was opened from, or null while that card is off screen or gone.
typedef ZoomSource = Rect? Function();

enum _Phase { idle, dragging, settling, flying }

/// A video page opened from a 推荐 card (03, 04 in local/differences): a swipe from the left edge shrinks the page
/// into a floating card that follows the finger over the dimmed home; let go and it springs back, or flies into
/// [source]. Opening is the plain push. The 〈 button and system back fly into the card too, as iOS's zoom
/// transitions do; with the card gone or off screen they fall back to the plain slide, and under Reduce Motion they
/// fade.
class ZoomBackPageRoute<T> extends SwipeBackPageRoute<T> {
  ZoomBackPageRoute({required super.builder, required this.source, super.settings});

  final ZoomSource source;

  final _zoom = _Zoom();
  final _frameKey = GlobalKey();
  AnimationController? _settle;
  Offset _settleFrom = Offset.zero;

  /// Whether this route has told the navigator a user gesture is in progress and not yet that it stopped.
  bool _holdsGesture = false;

  /// The page's scale for a drag [travel] points to the right on a screen [width] wide.
  @visibleForTesting
  static double scaleFor(double travel, double width) {
    final share = travel / width;
    if (share <= 0) return 1;
    if (share <= ZoomBackTheme.kneeTravel) {
      return 1 - (1 - ZoomBackTheme.kneeScale) * share / ZoomBackTheme.kneeTravel;
    }
    if (share >= ZoomBackTheme.minScaleTravel) return ZoomBackTheme.minScale;
    final along = (share - ZoomBackTheme.kneeTravel) / (ZoomBackTheme.minScaleTravel - ZoomBackTheme.kneeTravel);
    return ZoomBackTheme.kneeScale - (ZoomBackTheme.kneeScale - ZoomBackTheme.minScale) * along;
  }

  /// Where the page is drawn for a drag of [drag]: its left edge with the finger, shrunk about its middle, moved up
  /// and down with the finger.
  @visibleForTesting
  static Rect rectFor(Offset drag, Size screen) {
    final travel = math.max(0.0, drag.dx);
    final scale = scaleFor(travel, screen.width);
    final height = screen.height * scale;
    return Rect.fromLTWH(travel, (screen.height - height) / 2 + drag.dy, screen.width * scale, height);
  }

  static Color _dimFor(double scale) => Color.lerp(
    ZoomBackTheme.dim,
    ZoomBackTheme.dimShrunk,
    ((1 - scale) / (1 - ZoomBackTheme.minScale)).clamp(0.0, 1.0),
  )!;

  _ZoomSourceBoxState? get _card => _ZoomSourceBoxState._lookup(source);

  RenderBox? get _frame => _frameKey.currentContext?.findRenderObject() as RenderBox?;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(navigator!.context) ?? false;

  /// [source]'s rect in the page's own coordinates, which differ from global ones in the Windows phone frame.
  Rect? _sourceRect() {
    final rect = source();
    final frame = _frame;
    if (rect == null || frame == null || !frame.attached) return null;
    return Rect.fromPoints(frame.globalToLocal(rect.topLeft), frame.globalToLocal(rect.bottomRight));
  }

  @override
  Color? get barrierColor => _zoom.phase == _Phase.idle ? super.barrierColor : null;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _homeTransition;

  /// Home keeps the plain slide aside, except while the page is shrunk over it: then home is where it was, so the
  /// card's rect is where the page lands.
  Widget? _homeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => ListenableBuilder(
    listenable: _zoom,
    builder: (context, child) => CupertinoPageTransition.delegatedTransition(
      context,
      animation,
      _zoom.phase == _Phase.idle ? secondaryAnimation : kAlwaysDismissedAnimation,
      allowSnapshotting,
      child,
    )!,
    child: child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => CupertinoPageTransition(
    primaryRouteAnimation: _zoom.phase == _Phase.idle ? animation : kAlwaysCompleteAnimation,
    secondaryRouteAnimation: secondaryAnimation,
    linearTransition: false,
    child: _EdgeDrag(
      route: this,
      child: _ZoomFrame(key: _frameKey, route: this, child: child),
    ),
  );

  void _setPhase(_Phase phase) {
    final wasIdle = _zoom.phase == _Phase.idle;
    _zoom.phase = phase;
    if (wasIdle != (phase == _Phase.idle)) changedInternalState();
    _zoom.changed();
  }

  void _startGesture() {
    if (_holdsGesture) return;
    _holdsGesture = true;
    navigator!.didStartUserGesture();
  }

  void _stopGesture() {
    if (!_holdsGesture) return;
    _holdsGesture = false;
    if (navigator?.mounted ?? false) navigator!.didStopUserGesture();
  }

  bool get _canStartDrag => _zoom.phase == _Phase.idle && isCurrent && popGestureEnabled;

  void _dragStart() {
    _startGesture();
    _zoom.drag = Offset.zero;
    // The page stops covering home, which draws behind it from the next frame on.
    overlayEntries.first.opaque = false;
    _setPhase(_Phase.dragging);
    _card?._lend(onPicture: _zoom.setPicture);
  }

  void _dragUpdate(Offset drag) {
    if (_zoom.phase != _Phase.dragging) return;
    _zoom.drag = drag;
    _zoom.changed();
  }

  void _dragEnd(double velocity, Size screen) {
    if (_zoom.phase != _Phase.dragging) return;
    final travel = _zoom.drag.dx;
    final fling = ZoomBackTheme.flingSpeed * screen.width;
    final complete = velocity >= fling || (velocity > -fling && travel >= ZoomBackTheme.completeTravel * screen.width);
    // A turn mid-drag can close the page to pops (full screen), which the drag's start couldn't know.
    if (!complete || !isCurrent || popDisposition == RoutePopDisposition.doNotPop) {
      _springBack();
      return;
    }
    _flyFromDrag(screen);
    navigator!.pop();
    _runFly(_reduceMotion ? ZoomBackTheme.fade : ZoomBackTheme.fly);
  }

  void _springBack() {
    _settleFrom = _zoom.drag;
    final settle = _settle ??= AnimationController(vsync: navigator!, duration: ZoomBackTheme.settle)
      ..addListener(_settleTick)
      ..addStatusListener(_settleStatus);
    _setPhase(_Phase.settling);
    settle.forward(from: 0);
  }

  void _settleTick() {
    if (_zoom.phase != _Phase.settling) return;
    _zoom.drag = _settleFrom * (1 - Curves.easeOutCubic.transform(_settle!.value));
    _zoom.changed();
  }

  void _settleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _zoom.phase != _Phase.settling) return;
    _zoom.drag = Offset.zero;
    if (overlayEntries.isNotEmpty && animation!.isCompleted) overlayEntries.first.opaque = opaque;
    _setPhase(_Phase.idle);
    _card?._giveBack();
    _zoom.setPicture(null);
    _stopGesture();
  }

  /// Turns the shrunk page, wherever it is now, into the start of the fly.
  void _flyFromDrag(Size screen) {
    _settle?.stop();
    final drag = _zoom.drag;
    final scale = scaleFor(math.max(0.0, drag.dx), screen.width);
    _zoom
      ..from = rectFor(drag, screen)
      ..fromScale = scale
      ..fromDim = _dimFor(scale)
      ..fade = _reduceMotion
      ..to = _sourceRect()
      ..landing = true;
    _setPhase(_Phase.flying);
  }

  /// Drives the popped route's own animation from where it is to gone, which is also the fly's progress.
  void _runFly(Duration duration) {
    final controller = this.controller!;
    controller.animateBack(0, duration: duration * controller.value);
    if (controller.isAnimating) {
      late final AnimationStatusListener done;
      done = (status) {
        if (!status.isDismissed) return;
        controller.removeStatusListener(done);
        _landed();
      };
      controller.addStatusListener(done);
    } else {
      _landed();
    }
  }

  void _landed() {
    _card?._giveBack();
    _stopGesture();
  }

  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    if (!popped) return popped;
    switch (_zoom.phase) {
      case _Phase.flying:
        break;
      case _Phase.dragging || _Phase.settling:
        // Popped by other means mid-drag: carry on from where the page is.
        final screen = _frame?.size;
        if (screen != null) {
          _flyFromDrag(screen);
          _runFly(_reduceMotion ? ZoomBackTheme.fade : ZoomBackTheme.fly);
        }
      case _Phase.idle:
        _flyFromFull();
    }
    return popped;
  }

  /// The 〈 button and system back. With the card gone or off screen, the plain slide; under Reduce Motion, a fade.
  void _flyFromFull() {
    final card = _card;
    final screen = _frame?.size;
    if (card == null || !card.mounted || screen == null || source() == null) return;
    final reduce = _reduceMotion;
    _zoom
      ..from = Offset.zero & screen
      ..fromScale = 1
      ..fromDim = reduce ? const Color(0x00000000) : ZoomBackTheme.dim
      ..fade = reduce
      ..to = null
      ..landing = false;
    overlayEntries.first.opaque = false;
    _setPhase(_Phase.flying);
    // Reduce Motion fades the page over the card as it is, so the card neither hides nor lends its picture.
    card._lend(
      onPicture: reduce
          ? null
          : (picture) {
              // Home has drawn once without its slide aside, so the card is where it rests.
              _zoom
                ..to = _sourceRect()
                ..landing = true;
              _zoom.setPicture(picture);
            },
    );
    _runFly(reduce ? ZoomBackTheme.fade : ZoomBackTheme.flyFromFull);
  }

  @override
  void dispose() {
    // A route goes while the tree is locked; the card shows again once the frame is done.
    final card = _card;
    if (card != null) WidgetsBinding.instance.addPostFrameCallback((_) => card._giveBack());
    if (_holdsGesture) {
      final navigator = this.navigator;
      _holdsGesture = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator?.mounted ?? false) navigator!.didStopUserGesture();
      });
    }
    _settle?.dispose();
    _zoom.picture?.dispose();
    _zoom
      ..picture = null
      ..dispose();
    super.dispose();
  }
}

class _Zoom extends ChangeNotifier {
  _Phase phase = _Phase.idle;

  /// How far the finger has moved since it touched down.
  Offset drag = Offset.zero;

  Rect from = Rect.zero;
  double fromScale = 1;
  Color fromDim = const Color(0x00000000);

  /// The card's rect in the page's coordinates; null flies towards the middle.
  Rect? to;

  /// False while the card's rect is still being found, when the page keeps to [from].
  bool landing = false;

  /// Reduce Motion: no fly, a fade where the page is.
  bool fade = false;

  /// The card as it looks, which the page turns into on the way.
  ui.Image? picture;

  void setPicture(ui.Image? image) {
    if (identical(image, picture)) return;
    picture?.dispose();
    picture = image;
    changed();
  }

  void changed() => notifyListeners();
}

/// The left-edge swipe, as wide as the Cupertino route's. Once it has the drag it follows the finger up and down as
/// well as sideways.
class _EdgeDrag extends StatefulWidget {
  const _EdgeDrag({required this.route, required this.child});

  final ZoomBackPageRoute<dynamic> route;
  final Widget child;

  @override
  State<_EdgeDrag> createState() => _EdgeDragState();
}

class _EdgeDragState extends State<_EdgeDrag> {
  static const _edgeWidth = 20.0;

  late final HorizontalDragGestureRecognizer _recognizer;
  Offset? _down;

  @override
  void initState() {
    super.initState();
    // From the touch down, so the page stays under the finger rather than lagging it by the slop.
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..dragStartBehavior = DragStartBehavior.down
      ..onStart = _start
      ..onUpdate = _update
      ..onEnd = _end
      ..onCancel = _cancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent event) {
    if (widget.route._canStartDrag) _recognizer.addPointer(event);
  }

  void _start(DragStartDetails details) {
    if (!widget.route._canStartDrag) return;
    _down = details.globalPosition;
    widget.route._dragStart();
  }

  void _update(DragUpdateDetails details) {
    final down = _down;
    if (down != null) widget.route._dragUpdate(details.globalPosition - down);
  }

  void _end(DragEndDetails details) {
    if (_down == null) return;
    _down = null;
    widget.route._dragEnd(details.velocity.pixelsPerSecond.dx, context.size!);
  }

  void _cancel() {
    if (_down == null) return;
    _down = null;
    widget.route._dragEnd(0, context.size!);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.child,
      PositionedDirectional(
        start: 0,
        width: math.max(MediaQuery.paddingOf(context).left, _edgeWidth),
        top: 0,
        bottom: 0,
        child: Listener(onPointerDown: _pointerDown, behavior: HitTestBehavior.translucent),
      ),
    ],
  );
}

/// Draws the page where the drag or the fly has it, over the dim. At rest it is the page as it is, and the tree
/// keeps one shape throughout so the page (and its player) is never rebuilt from scratch.
class _ZoomFrame extends StatelessWidget {
  const _ZoomFrame({super.key, required this.route, required this.child});

  final ZoomBackPageRoute<dynamic> route;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: Listenable.merge([route._zoom, route.animation]),
      builder: (context, child) => _frame(context, constraints.biggest, child!),
      child: child,
    ),
  );

  Widget _frame(BuildContext context, Size screen, Widget page) {
    final zoom = route._zoom;
    const clear = Color(0x00000000);
    var rect = Offset.zero & screen;
    var radius = 0.0;
    var dim = clear;
    var backing = clear;
    var pageOpacity = 1.0;
    var pictureOpacity = 0.0;
    switch (zoom.phase) {
      case _Phase.idle:
        break;
      case _Phase.dragging || _Phase.settling:
        rect = ZoomBackPageRoute.rectFor(zoom.drag, screen);
        radius = ZoomBackTheme.cornerRadius * rect.width / screen.width;
        dim = ZoomBackPageRoute._dimFor(rect.width / screen.width);
      case _Phase.flying:
        final t = (1 - route.animation!.value).clamp(0.0, 1.0);
        final fromRadius = ZoomBackTheme.cornerRadius * zoom.fromScale;
        if (zoom.fade) {
          rect = zoom.from;
          radius = fromRadius;
          pageOpacity = 1 - t;
          dim = Color.lerp(zoom.fromDim, clear, t)!;
          break;
        }
        final eased = ZoomBackTheme.flyCurve.transform(t);
        final to = zoom.to;
        dim = Color.lerp(zoom.fromDim, clear, eased)!;
        if (!zoom.landing) {
          rect = zoom.from;
          radius = fromRadius;
        } else if (to == null) {
          final lost = Rect.fromCenter(
            center: screen.center(Offset.zero),
            width: zoom.from.width * ZoomBackTheme.lostScale,
            height: zoom.from.height * ZoomBackTheme.lostScale,
          );
          rect = Rect.lerp(zoom.from, lost, eased)!;
          radius = fromRadius * rect.width / zoom.from.width;
          pageOpacity = 1 - eased;
        } else {
          rect = Rect.lerp(zoom.from, to, eased)!;
          radius = ui.lerpDouble(fromRadius, BiliMetrics.cardRadius, eased)!;
          if (zoom.picture != null) {
            backing = BiliColors.colorsOf(context).card;
            pictureOpacity = const Interval(0, ZoomBackTheme.pictureIn).transform(t);
            pageOpacity = ZoomBackTheme.pageUnder * (1 - const Interval(0, ZoomBackTheme.pageOut).transform(t));
          } else {
            // No picture to turn into: the page lands on the card, which shows through as it fades.
            pageOpacity = 1 - const Interval(ZoomBackTheme.fadeOntoCard, 1).transform(t);
          }
        }
    }
    final scale = rect.width / screen.width;
    final picture = zoom.picture;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: dim.a == 0 ? const SizedBox.expand() : ColoredBox(color: dim)),
        Transform(
          transform: Matrix4.identity()
            ..translateByDouble(rect.left, rect.top, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1),
          child: ClipRRect(
            clipper: _PageClip(height: rect.height / scale, radius: radius / scale),
            clipBehavior: zoom.phase == _Phase.idle ? Clip.none : Clip.antiAlias,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(child: backing.a == 0 ? const SizedBox.shrink() : ColoredBox(color: backing)),
                Opacity(opacity: pageOpacity, child: page),
                if (picture != null && pictureOpacity > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: screen.width,
                    height: screen.width * picture.height / picture.width,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: pictureOpacity,
                        child: RawImage(image: picture, fit: BoxFit.fill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The page's top [height] points, in its own points: the whole page while dragged, the card's shape as it lands.
class _PageClip extends CustomClipper<RRect> {
  const _PageClip({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  RRect getClip(Size size) => RRect.fromLTRBR(0, 0, size.width, math.min(height, size.height), Radius.circular(radius));

  @override
  bool shouldReclip(_PageClip oldClipper) => oldClipper.height != height || oldClipper.radius != radius;
}

/// Wraps what a [ZoomBackPageRoute] page was opened from, and hands [builder] the [ZoomSource] to open it with. From
/// the swipe's start (or the 〈 fly) until the page lands, the box stays empty as the official card's spot does, and
/// its picture is what the page turns into as it lands. Its Hero is off meanwhile, so the cover doesn't fly back on
/// its own.
class ZoomSourceBox extends StatefulWidget {
  const ZoomSourceBox({super.key, required this.builder});

  final Widget Function(BuildContext context, ZoomSource source) builder;

  @override
  State<ZoomSourceBox> createState() => _ZoomSourceBoxState();
}

class _ZoomSourceBoxState extends State<ZoomSourceBox> {
  static final _boxes = Expando<_ZoomSourceBoxState>('ZoomSourceBox');

  static _ZoomSourceBoxState? _lookup(ZoomSource source) {
    final box = _boxes[source];
    return box != null && box.mounted ? box : null;
  }

  late final ZoomSource _source = _rect;
  final _boundary = GlobalKey();
  bool _lent = false;
  bool _hidden = false;

  /// Bumped to build the card afresh when lent. A Hero the push flew from keeps an empty placeholder until a pop
  /// flight ends it, and with the Hero off no pop flight comes.
  int _builds = 0;

  @override
  void initState() {
    super.initState();
    _boxes[_source] = this;
  }

  @override
  void dispose() {
    _boxes[_source] = null;
    super.dispose();
  }

  Rect? _rect() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    final Rect visible;
    if (viewport is RenderBox && viewport.attached && viewport.hasSize) {
      visible = MatrixUtils.transformRect(viewport.getTransformTo(null), Offset.zero & viewport.size);
    } else {
      final view = View.of(context);
      visible = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    }
    return rect.overlaps(visible) ? rect : null;
  }

  /// Hero off and the card built afresh at once; with [onPicture], after home's next frame, the picture taken and the
  /// box emptied.
  void _lend({required ValueChanged<ui.Image?>? onPicture}) {
    if (_lent) return;
    setState(() {
      _lent = true;
      _builds++;
    });
    if (onPicture == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_lent) return;
      final picture = _picture();
      if (picture != null) setState(() => _hidden = true);
      onPicture(picture);
    });
  }

  void _giveBack() {
    if (!mounted || (!_lent && !_hidden)) return;
    setState(() {
      _lent = false;
      _hidden = false;
    });
  }

  /// Null when home hasn't drawn the card since it was covered: the page then lands without turning into the card.
  ui.Image? _picture() {
    final boundary = _boundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.attached) return null;
    try {
      return boundary.toImageSync(pixelRatio: View.of(context).devicePixelRatio);
    } catch (error) {
      // Unpainted, debug builds trip toImageSync's assert and release builds its null layer; anything else is news.
      if (error is! AssertionError && error is! TypeError) {
        Logger.shared.warn(LogCategory.ui, 'zoom picture failed', {'error': '$error'});
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: !_lent,
    child: Opacity(
      opacity: _hidden ? 0 : 1,
      child: RepaintBoundary(
        key: _boundary,
        child: KeyedSubtree(key: ValueKey(_builds), child: widget.builder(context, _source)),
      ),
    ),
  );
}
