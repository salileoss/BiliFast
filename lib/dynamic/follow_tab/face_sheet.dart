import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:bili_core/api.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../home/feed_inline_player.dart';
import '../../shared/loading_tv.dart';
import '../../shared/theme.dart';
import 'follow_feed_model.dart';
import 'follow_parts.dart';
import 'follow_top.dart';

/// Which 最常访问 face the face sheet shows, if any (139). The 关注 tab opens it; `MainShell` draws it over the whole
/// screen, its bar included.
class FaceSheetController extends ChangeNotifier {
  FollowTabModel? _model;
  DynamicUp? _up;

  /// Where the page's row was scrolled sideways, and where its faces' tops were on screen, when it opened.
  double _rowOffset = 0;
  double? _originTop;

  FollowTabModel? get model => _model;
  DynamicUp? get up => _up;
  bool get isOpen => _up != null;
  double get rowOffset => _rowOffset;
  double? get originTop => _originTop;

  /// Shows [up]'s posts; their dot goes.
  void open(DynamicUp up, {required FollowTabModel model, double rowOffset = 0, double? originTop}) {
    _model = model;
    _rowOffset = rowOffset;
    _originTop = originTop;
    _up = up;
    model.markSeen(up.mid);
    notifyListeners();
  }

  /// Another face, the sheet staying up.
  void select(DynamicUp up) {
    if (up.mid == _up?.mid) return;
    _up = up;
    _model?.markSeen(up.mid);
    notifyListeners();
  }

  void close() {
    if (_up == null) return;
    _up = null;
    notifyListeners();
  }
}

/// The face sheet (139): the screen frosted behind the faces row, raised to the top, a pointer under the chosen face,
/// and the sheet titled `<name>的动态` with that person's posts, paged. ✕, back or a tap on the frost closes it.
class FaceSheetLayer extends StatefulWidget {
  const FaceSheetLayer({super.key, required this.controller});

  final FaceSheetController controller;

  @override
  State<FaceSheetLayer> createState() => _FaceSheetLayerState();
}

class _FaceSheetLayerState extends State<FaceSheetLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: DynamicFeedTheme.sheetIn,
    reverseDuration: DynamicFeedTheme.sheetOut,
  )..addStatusListener(_motionChanged);
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _motion,
    curve: DynamicFeedTheme.sheetCurve,
    reverseCurve: DynamicFeedTheme.sheetCurve.flipped,
  );

  /// What the sheet shows: the chosen face and its posts, kept while it closes.
  DynamicUp? _up;
  List<DynamicUp> _ups = const [];
  FollowFeed? _feed;
  ScrollController? _faces;
  final _list = GlobalKey();
  final _scroll = ScrollController();
  late final _paging = FollowPaging(canAsk: () => _feed?.canLoadMore ?? false, ask: () => _feed!.loadMore());
  FeedInlineHost? _inline;

  /// Reduce Motion and the home indicator's inset, as the last build saw them.
  bool _still = false;
  double _inset = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(FaceSheetLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _paging.dispose();
    _inline?.dispose();
    _feed?.dispose();
    _faces?.dispose();
    _scroll.dispose();
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _changed() {
    final controller = widget.controller;
    final up = controller.up;
    if (up == null) {
      if (_still) {
        _motion.value = 0;
      } else {
        unawaited(_motion.reverse());
      }
      setState(() {});
      return;
    }
    final opening = _up == null || _motion.isDismissed || _motion.status == AnimationStatus.reverse;
    if (opening) {
      _faces?.dispose();
      _faces = ScrollController(initialScrollOffset: controller.rowOffset);
      if (_still) {
        _motion.value = 1;
      } else {
        unawaited(_motion.forward());
      }
    }
    if (up.mid != _up?.mid || _feed == null) _show(up);
    setState(() {});
  }

  void _show(DynamicUp up) {
    final api = AppScope.of(context).dynamicApi;
    _up = up;
    _feed?.dispose();
    final feed = _feed = FollowFeed(
      name: 'space',
      load: (offset) => api.spacePosts(up.mid, offset: offset),
    )..addListener(_feedChanged);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(feed.start());
  }

  void _feedChanged() {
    if (!mounted) return;
    setState(() {});
    _inline?.settleSoon();
  }

  void _motionChanged(AnimationStatus status) {
    if (!mounted) return;
    if (status.isDismissed) {
      _feed?.dispose();
      _feed = null;
      _up = null;
    }
    setState(() {});
  }

  Rect? _listArea() {
    final box = _list.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final area = box.localToGlobal(Offset.zero) & box.size;
    return Rect.fromLTRB(area.left, area.top, area.right, math.max(area.top, area.bottom - _inset));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final open = controller.isOpen;
    _still = MediaQuery.disableAnimationsOf(context);
    _inset = MediaQuery.paddingOf(context).bottom;
    final inline = _inline ??= FeedInlineHost(viewport: _listArea, pip: AppScope.of(context).pipKeeper);
    inline.shown =
        open &&
        _motion.isCompleted &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final up = _up;
    final model = controller.model;
    return PopScope<Object?>(
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.close();
      },
      child: up == null || model == null || _motion.isDismissed
          ? const SizedBox.shrink()
          : ListenableBuilder(listenable: model, builder: (context, _) => _layer(context, up, model)),
    );
  }

  Widget _layer(BuildContext context, DynamicUp up, FollowTabModel model) {
    if (model.ups.isNotEmpty) _ups = model.ups;
    final padding = MediaQuery.paddingOf(context);
    final rowTop = padding.top + DynamicFeedTheme.sheetFacesTop;
    final sheetTop = padding.top + DynamicFeedTheme.sheetTop;
    final origin = widget.controller.originTop ?? rowTop;
    final open = widget.controller.isOpen;
    final chosen = math.max(0, _ups.indexWhere((face) => face.mid == up.mid));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, sheet) {
          final t = _curve.value;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('face-sheet-frost'),
                  behavior: HitTestBehavior.opaque,
                  onTap: open ? widget.controller.close : null,
                  child: Opacity(
                    opacity: t,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: DynamicFeedTheme.sheetBlur,
                          sigmaY: DynamicFeedTheme.sheetBlur,
                        ),
                        child: ColoredBox(color: DynamicFeedTheme.colorsOf(context).sheetFrost),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                key: const ValueKey('face-sheet-faces'),
                left: 0,
                right: 0,
                top: lerpDouble(origin, rowTop, t),
                height: sheetTop - rowTop,
                child: IgnorePointer(
                  ignoring: !open,
                  child: FollowFacesRow(
                    ups: _ups,
                    dot: model.hasUpdate,
                    controller: _faces,
                    onOpen: widget.controller.select,
                    onNearEnd: () => unawaited(model.loadMoreUps()),
                    below: (context) => AnimatedPositioned(
                      key: const ValueKey('face-sheet-pointer'),
                      duration: _still ? Duration.zero : DynamicFeedTheme.pointerSlide,
                      curve: Curves.easeOut,
                      left: DynamicFeedTheme.facePitch * (chosen + 0.5) - DynamicFeedTheme.pointerWidth / 2,
                      top: sheetTop - rowTop - DynamicFeedTheme.pointerHeight + DynamicFeedTheme.sheetRule,
                      width: DynamicFeedTheme.pointerWidth,
                      height: DynamicFeedTheme.pointerHeight,
                      child: Opacity(
                        opacity: t,
                        child: Image.asset(
                          'assets/images/dynamic/follow_pointer.png',
                          fit: BoxFit.fill,
                          color: DynamicFeedTheme.colorsOf(context).sheetFill,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: sheetTop,
                bottom: 0,
                child: FractionalTranslation(translation: Offset(0, 1 - t), child: sheet),
              ),
            ],
          );
        },
        child: _sheet(context, up),
      ),
    );
  }

  Widget _sheet(BuildContext context, DynamicUp up) {
    final titleStyle = followStyle(
      DynamicFeedTheme.sheetTitleText,
      DynamicFeedTheme.colorsOf(context).sheetTitleInk,
      weight: DynamicFeedTheme.sheetTitleWeight,
    );
    return DecoratedBox(
      key: const ValueKey('face-sheet'),
      decoration: BoxDecoration(
        color: DynamicFeedTheme.colorsOf(context).sheetFill,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DynamicFeedTheme.sheetRadius)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: DynamicFeedTheme.sheetHead - DynamicFeedTheme.sheetRule,
            child: Stack(
              children: [
                Positioned(
                  left: DynamicFeedTheme.gutter,
                  right: DynamicFeedTheme.closeCentreRight + DynamicFeedTheme.closeTarget / 2,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      header: true,
                      child: Text(
                        '${up.name}的动态',
                        key: const ValueKey('face-sheet-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                        strutStyle: BiliFonts.strutOf(context, titleStyle),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: DynamicFeedTheme.closeCentreRight - DynamicFeedTheme.closeTarget / 2,
                  width: DynamicFeedTheme.closeTarget,
                  top: 0,
                  bottom: 0,
                  child: FollowTap(
                    key: const ValueKey('face-sheet-close'),
                    label: '关闭',
                    onTap: widget.controller.close,
                    child: Center(
                      child: FollowCross(
                        size: DynamicFeedTheme.closeSize,
                        stroke: DynamicFeedTheme.closeStroke,
                        color: DynamicFeedTheme.colorsOf(context).closeInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: DynamicFeedTheme.sheetRule,
            child: ColoredBox(color: DynamicFeedTheme.colorsOf(context).sheetRuleInk),
          ),
          Expanded(
            child: KeyedSubtree(key: _list, child: _posts(context)),
          ),
        ],
      ),
    );
  }

  Widget _posts(BuildContext context) {
    final feed = _feed;
    final inline = _inline!;
    if (feed == null) return const SizedBox.shrink();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = feed.items;
    if (items.isEmpty) {
      final error = feed.error;
      final Widget state;
      if (error != null && !feed.loading) {
        state = FollowStateMessage(
          key: const ValueKey('face-sheet-failed'),
          message: error,
          button: FollowPinkButton(
            key: const ValueKey('face-sheet-retry'),
            label: '重试',
            onTap: () => unawaited(feed.retry()),
            text: DynamicFeedTheme.retryText,
            height: DynamicFeedTheme.retryHeight,
            padX: DynamicFeedTheme.retryPadX,
          ),
        );
      } else if (feed.isEnd && !feed.loading) {
        state = const FollowStateMessage(key: ValueKey('face-sheet-empty'), message: '还没有动态');
      } else {
        state = const LoadingTvState(key: ValueKey('face-sheet-loading'));
      }
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: DynamicFeedTheme.stateTop),
          child: state,
        ),
      );
    }
    return _paging.listen(
      _scroll,
      NotificationListener<ScrollNotification>(
        onNotification: inline.onScroll,
        child: CustomScrollView(
          key: const ValueKey('face-sheet-list'),
          controller: _scroll,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => FollowPosts.row(context, items[index], inline, bandAbove: false),
            ),
            SliverToBoxAdapter(
              child: FollowFooter(
                keyPrefix: 'face-sheet',
                loading: feed.loading,
                error: feed.error,
                isEnd: feed.isEnd,
                onRetry: () => unawaited(feed.loadMore()),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottom)),
          ],
        ),
      ),
    );
  }
}
