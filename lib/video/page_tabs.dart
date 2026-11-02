import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/material.dart';

import '../shared/custom_icons.dart';
import '../shared/theme.dart';
import 'pad/pad_body.dart' show PadDanmakuCapsule;
import 'page_details.dart';

/// Which tab the page shows, the pager both tabs live in, and each tab's own scroll controller, which [PageTabs]
/// hands the tab as its primary one. The row reads [position] through a swipe, so the underline and the colours
/// follow the finger; the page reads each tab's offset to shrink the paused player.
class PageTabsController extends ChangeNotifier {
  final PageController pager = PageController();
  late final _introScroll = _TabScrollController(this, PageTab.intro);
  late final _commentsScroll = _TabScrollController(this, PageTab.comments);
  PageTab _selected = PageTab.intro;

  /// Where each tab's next list starts, for a list rebuilt in another layout (the iPad turning); until it is built, the
  /// tab's offset.
  final _carried = <PageTab, double>{};

  static const _slide = Duration(milliseconds: 300);

  /// Fires on a tab change, a sideways swipe and either tab's scrolling.
  late final Listenable motion = Listenable.merge([this, pager, _introScroll, _commentsScroll]);

  PageTab get selected => _selected;

  ScrollController scrollOf(PageTab tab) => switch (tab) {
    PageTab.intro => _introScroll,
    PageTab.comments => _commentsScroll,
  };

  /// How far [tab]'s list has scrolled; 0 before it is laid out.
  double offsetOf(PageTab tab) {
    final positions = scrollOf(tab).positions;
    if (positions.isEmpty) return _carried[tab] ?? 0;
    // A list replaced for another video attaches its position before the old one detaches.
    final position = positions.last;
    return position.hasPixels ? position.pixels : 0;
  }

  /// The next list [tab]'s controller attaches starts at [offset]: the iPad's layouts each build their own.
  void carry(PageTab tab, double offset) => _carried[tab] = offset;

  /// Back to the top of the shown tab, or of [tab]; [animate] false jumps.
  void scrollToTop({bool animate = true, PageTab? tab}) {
    final scroll = scrollOf(tab ?? _selected);
    if (!scroll.hasClients) return;
    if (animate) {
      unawaited(scroll.animateTo(0, duration: CollapseTheme.resume, curve: Curves.easeOutCubic));
    } else {
      scroll.jumpTo(0);
    }
  }

  /// 0 on 简介, 1 on 评论, in between during a swipe.
  double get position {
    if (pager.hasClients && pager.position.hasContentDimensions) return pager.page ?? _selected.index.toDouble();
    return _selected.index.toDouble();
  }

  /// [animate] false jumps, as for a pager out of sight in full screen or with reduced motion.
  void select(PageTab tab, {bool animate = true}) {
    _set(tab);
    if (!pager.hasClients) return;
    if (animate) {
      pager.animateToPage(tab.index, duration: _slide, curve: Curves.easeOutCubic);
    } else {
      pager.jumpToPage(tab.index);
    }
  }

  void _set(PageTab tab) {
    if (tab == _selected) return;
    _selected = tab;
    notifyListeners();
  }

  @override
  void dispose() {
    pager.dispose();
    _introScroll.dispose();
    _commentsScroll.dispose();
    super.dispose();
  }
}

class _TabScrollController extends ScrollController {
  _TabScrollController(this._tabs, this._tab);

  final PageTabsController _tabs;
  final PageTab _tab;

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) =>
      ScrollPositionWithSingleContext(
        physics: physics,
        context: context,
        initialPixels: _tabs._carried.remove(_tab) ?? initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        oldPosition: oldPosition,
        debugLabel: debugLabel,
      );
}

/// 简介 and 评论 side by side in a pager; a sideways swipe switches, and each keeps its scroll position. Each tab's
/// list takes its scroll controller as the primary one. The route's edge swipe stays the route's: its detector sits
/// over the page and wins the drag before the pager sees it.
class PageTabs extends StatefulWidget {
  const PageTabs({super.key, required this.controller, required this.intro, required this.comments});

  final PageTabsController controller;
  final Widget intro;
  final Widget comments;

  @override
  State<PageTabs> createState() => _PageTabsState();
}

class _PageTabsState extends State<PageTabs> {
  @override
  void initState() {
    super.initState();
    // A tab chosen before the pager existed: the pager starts on 简介 and catches up once laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = widget.controller;
      if (!mounted || !controller.pager.hasClients) return;
      if (controller.pager.page?.round() != controller.selected.index) {
        controller.pager.jumpToPage(controller.selected.index);
      }
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: BiliColors.colorsOf(context).card,
    child: PageView(
      key: const ValueKey('page-tabs'),
      controller: widget.controller.pager,
      // No bounce past either tab: the official pager stops at its ends.
      physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
      onPageChanged: (index) => widget.controller._set(PageTab.values[index]),
      children: [
        _KeepAlive(child: _onScreen(PageTab.intro, _primary(PageTab.intro, widget.intro))),
        _KeepAlive(child: _onScreen(PageTab.comments, _primary(PageTab.comments, widget.comments))),
      ],
    ),
  );

  /// A kept tab out of sight stops its tickers, so a spinner there doesn't keep a core busy.
  Widget _onScreen(PageTab tab, Widget child) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.pager]),
      builder: (context, child) => TickerMode(enabled: (controller.position - tab.index).abs() < 1, child: child!),
      child: child,
    );
  }

  // Every platform, so a list that doesn't say `primary` takes it on Windows as it does on the phone.
  Widget _primary(PageTab tab, Widget child) => PrimaryScrollController(
    controller: widget.controller.scrollOf(tab),
    automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
    child: child,
  );
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// The row under the player (03, 10, 18): 简介 and 评论 N with the pink underline that slides between them, and at
/// the right 点我发弹幕 joined to the 弹 toggle, or the toggle alone while danmaku is off.
class PageTabRow extends StatelessWidget {
  const PageTabRow({
    super.key,
    required this.controller,
    required this.replyCount,
    required this.danmakuOn,
    required this.onToggleDanmaku,
    required this.onSendDanmaku,
    this.danmakuInputOpen = false,
    this.danmakuClosed = false,
  });

  final PageTabsController controller;

  /// Null until the video's detail arrives.
  final int? replyCount;
  final bool danmakuOn;

  /// Null before the page has its session.
  final VoidCallback? onToggleDanmaku;
  final VoidCallback onSendDanmaku;

  /// The send bar is up: the field reads 弹幕输入中 (39).
  final bool danmakuInputOpen;

  /// The uploader closed danmaku: the field reads UP主已关闭弹幕.
  final bool danmakuClosed;

  static const _fade = Duration(milliseconds: 250);

  TextStyle _labelStyle(Color color) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: PageTheme.tabLabelText,
    color: color,
    height: 1.2,
    letterSpacing: 0,
  );

  TextStyle _countStyle(Color color) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: PageTheme.tabCountText,
    color: color,
    height: 1.2,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final still = MediaQuery.disableAnimationsOf(context);
    // Measured as the labels render: over whatever the surrounding text style leaves in place.
    final base = DefaultTextStyle.of(context).style;
    final count = replyCount == null ? null : CountFormat.short(replyCount!);
    final introWidth = _measure('简介', base.merge(_labelStyle(PageTheme.colorsOf(context).tabText)), scaler);
    final commentsWidth =
        _measure('评论', base.merge(_labelStyle(PageTheme.colorsOf(context).tabText)), scaler) +
        (count == null
            ? 0
            : PageTheme.tabCountGap + _measure(count, base.merge(_countStyle(PageTheme.colorsOf(context).tabText)), scaler));
    const pad = PageTheme.tabSpacing / 2;
    const introLeft = PageTheme.tabFirstLabel;
    final commentsLeft = introLeft + introWidth + PageTheme.tabSpacing;
    return SizedBox(
      height: PageTheme.tabRowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BiliColors.colorsOf(context).card,
          border: Border(
            bottom: BorderSide(color: BiliColors.colorsOf(context).divider, width: PageTheme.hairline),
          ),
        ),
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, controller.pager]),
          builder: (context, _) {
            final position = controller.position.clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned(
                  left: introLeft - pad,
                  top: 0,
                  bottom: 0,
                  child: _tab(context,
                    key: const ValueKey('tab-intro'),
                    tab: PageTab.intro,
                    label: '简介',
                    count: null,
                    emphasis: 1 - position,
                    still: still,
                  ),
                ),
                Positioned(
                  left: commentsLeft - pad,
                  top: 0,
                  bottom: 0,
                  child: _tab(context,
                    key: const ValueKey('tab-comments'),
                    tab: PageTab.comments,
                    label: '评论',
                    count: count,
                    emphasis: position,
                    still: still,
                  ),
                ),
                _underline(context, position: position, from: (introLeft, introWidth), to: (commentsLeft, commentsWidth)),
                Positioned(
                  right: BiliMetrics.gutter,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: DanmakuCapsule(
                      on: danmakuOn,
                      onToggle: onToggleDanmaku,
                      onSend: danmakuClosed ? null : onSendDanmaku,
                      text: danmakuClosed ? 'UP主已关闭弹幕' : (danmakuInputOpen ? '弹幕输入中' : '点我发弹幕'),
                      duration: still ? Duration.zero : _fade,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static double _measure(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _tab(BuildContext context, {
    required Key key,
    required PageTab tab,
    required String label,
    required String? count,
    required double emphasis,
    required bool still,
  }) {
    final color = Color.lerp(PageTheme.colorsOf(context).tabText, BiliColors.colorsOf(context).pink, emphasis.clamp(0.0, 1.0))!;
    final selected = controller.selected == tab;
    void select() => controller.select(tab, animate: !still);
    return Semantics(
      key: key,
      button: true,
      selected: selected,
      label: count == null ? label : '$label $count',
      onTap: select,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PageTheme.tabSpacing / 2),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(label, style: _labelStyle(color)),
                if (count != null) ...[
                  const SizedBox(width: PageTheme.tabCountGap),
                  Transform.translate(
                    key: const ValueKey('tab-count'),
                    offset: const Offset(0, -PageTheme.tabCountRise),
                    child: Text(count, style: _countStyle(color)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The leading end runs ahead and the trailing end catches up, so the bar stretches as it travels.
  Widget _underline(BuildContext context, {required double position, required (double, double) from, required (double, double) to}) {
    final (fromLeft, fromWidth) = from;
    final (toLeft, toWidth) = to;
    final lead = Curves.easeOut.transform(position);
    final trail = Curves.easeIn.transform(position);
    final left = lerpDouble(fromLeft, toLeft, trail)!;
    final right = lerpDouble(fromLeft + fromWidth, toLeft + toWidth, lead)!;
    return Positioned(
      key: const ValueKey('tab-underline'),
      left: left,
      width: math.max(0, right - left),
      bottom: 0,
      height: PageTheme.underlineHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BiliColors.colorsOf(context).pink,
          borderRadius: BorderRadius.all(Radius.circular(PageTheme.underlineRadius)),
        ),
      ),
    );
  }
}

/// The toggle alone in a small grey capsule, or grown leftwards into 点我发弹幕 with the toggle on white. The offline
/// page's (158) is [height] 28.
class DanmakuCapsule extends StatelessWidget {
  const DanmakuCapsule({
    super.key,
    required this.on,
    required this.onToggle,
    required this.onSend,
    required this.text,
    required this.duration,
    this.height = PageTheme.capsuleHeight,
    this.border = PageTheme.capsuleBorder,
  });

  final bool on;
  final VoidCallback? onToggle;

  /// Null while the uploader has danmaku closed.
  final VoidCallback? onSend;
  final String text;
  final Duration duration;
  final double height;
  final double border;

  static const _curve = Curves.easeOutCubic;

  static TextStyle _fieldStyle(BuildContext context) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: PageTheme.danmakuFieldText,
    color: BiliColors.colorsOf(context).secondaryText,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final toggleWidth = on ? PageTheme.danmakuToggleOn : PageTheme.danmakuToggleOff;
    return AnimatedContainer(
      key: const ValueKey('danmaku-capsule'),
      duration: duration,
      curve: _curve,
      width: on ? PageTheme.danmakuFieldWidth + PageTheme.danmakuToggleOn : PageTheme.danmakuToggleOff,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(color: BiliColors.colorsOf(context).softGrey, shape: StadiumBorder()),
      foregroundDecoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: BiliColors.colorsOf(context).divider, width: border),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _field(context)),
          AnimatedContainer(
            duration: duration,
            curve: _curve,
            width: toggleWidth,
            color: on ? BiliColors.colorsOf(context).card : BiliColors.colorsOf(context).softGrey,
            child: _toggle(),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context) => ClipRect(
    child: OverflowBox(
      minWidth: PageTheme.danmakuFieldWidth,
      maxWidth: PageTheme.danmakuFieldWidth,
      alignment: Alignment.centerRight,
      child: AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: duration,
        child: ExcludeSemantics(
          excluding: !on,
          child: Semantics(
            key: const ValueKey('danmaku-send'),
            button: onSend != null,
            label: text,
            onTap: on ? onSend : null,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: on ? onSend : null,
              child: Center(
                child: AnimatedSwitcher(
                  duration: duration,
                  child: Text(
                    text,
                    key: ValueKey(text),
                    maxLines: 1,
                    softWrap: false,
                    style: _fieldStyle(context),
                    strutStyle: BiliFonts.strutOf(context, _fieldStyle(context)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _toggle() => Semantics(
    key: const ValueKey('danmaku-toggle'),
    button: true,
    toggled: on,
    label: on ? '关闭弹幕' : '开启弹幕',
    onTap: onToggle,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: OverflowBox(
        minWidth: PageTheme.danmakuMarkBox,
        maxWidth: PageTheme.danmakuMarkBox,
        alignment: Alignment.centerRight,
        child: Center(
          child: AnimatedSwitcher(
            duration: duration,
            child: DanmakuMark(key: ValueKey(on), on: on),
          ),
        ),
      ),
    ),
  );
}

/// The borrowed 弹 glyph in the tab grey, its on tick pink as the official app draws it.
class DanmakuMark extends StatelessWidget {
  const DanmakuMark({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    if (!on) {
      return Icon(CustomIcons.danmakuOff, size: PageTheme.danmakuMark, color: PageTheme.colorsOf(context).tabText);
    }
    return SizedBox.square(
      dimension: PageTheme.danmakuMark,
      child: Stack(
        children: [
          ClipPath(
            clipper: _TickClip(tick: false),
            child: Icon(CustomIcons.danmakuOn, size: PageTheme.danmakuMark, color: PageTheme.colorsOf(context).tabText),
          ),
          ClipPath(
            clipper: _TickClip(tick: true),
            child: Icon(CustomIcons.danmakuOn, size: PageTheme.danmakuMark, color: BiliColors.colorsOf(context).pink),
          ),
        ],
      ),
    );
  }
}

/// The font's tick is its own contour below and right of the box's strokes, so a rectangle separates it.
class _TickClip extends CustomClipper<Path> {
  const _TickClip({required this.tick});

  final bool tick;

  @override
  Path getClip(Size size) {
    final corner = Rect.fromLTRB(
      size.width * PageTheme.danmakuTickLeft,
      size.height * PageTheme.danmakuTickTop,
      size.width * 2,
      size.height * 2,
    );
    if (tick) return Path()..addRect(corner);
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRect(corner));
  }

  @override
  bool shouldReclip(_TickClip oldClipper) => oldClipper.tick != tick;
}

/// The iPad's upright tab row (06): 简介 and 评论 (N) in pink or grey with no underline, and 点我发弹幕 at the right.
class PadPageTabRow extends StatelessWidget {
  const PadPageTabRow({
    super.key,
    required this.controller,
    required this.replyCount,
    required this.danmakuOn,
    required this.onToggleDanmaku,
    required this.onSendDanmaku,
    this.danmakuInputOpen = false,
    this.danmakuClosed = false,
  });

  final PageTabsController controller;
  final int? replyCount;
  final bool danmakuOn;
  final VoidCallback? onToggleDanmaku;
  final VoidCallback onSendDanmaku;
  final bool danmakuInputOpen;
  final bool danmakuClosed;

  static const _fade = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final count = replyCount == null ? null : CountFormat.short(replyCount!);
    return SizedBox(
      height: PadPageTheme.tabRowHeight,
      child: ColoredBox(
        color: BiliColors.colorsOf(context).card,
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, controller.pager]),
          builder: (context, _) {
            final position = controller.position.clamp(0.0, 1.0);
            return Row(
              children: [
                const SizedBox(width: PadPageTheme.tabFirstLabel - PadPageTheme.tabSpacing / 2),
                _tab(context, PageTab.intro, '简介', 1 - position, still, const ValueKey('tab-intro')),
                _tab(context,
                  PageTab.comments,
                  count == null ? '评论' : '评论 ($count)',
                  position,
                  still,
                  const ValueKey('tab-comments'),
                ),
                const Spacer(),
                PadDanmakuCapsule(
                  on: danmakuOn,
                  onToggle: onToggleDanmaku,
                  onSend: danmakuClosed ? null : onSendDanmaku,
                  text: danmakuClosed ? 'UP主已关闭弹幕' : (danmakuInputOpen ? '弹幕输入中' : '点我发弹幕'),
                  duration: still ? Duration.zero : _fade,
                ),
                const SizedBox(width: PadPageTheme.capsuleRight),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, PageTab tab, String label, double emphasis, bool still, Key key) {
    final color = Color.lerp(PadPageTheme.colorsOf(context).tabInk, BiliColors.colorsOf(context).pink, emphasis.clamp(0.0, 1.0))!;
    void select() => controller.select(tab, animate: !still);
    return Semantics(
      key: key,
      button: true,
      selected: controller.selected == tab,
      label: label,
      onTap: select,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PadPageTheme.tabSpacing / 2),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: BiliFonts.family,
                fontSize: PadPageTheme.tabText,
                color: color,
                height: 1.2,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
