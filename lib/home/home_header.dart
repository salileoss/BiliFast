import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../app/form_factor.dart';
import '../search/search_glyphs.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../skin/skin.dart';
import 'tab_bar_icons.dart' show SkinDecodeGate;

/// 首页's top (01, 110): the avatar and the search entry over the 推荐 tab, on white or the 装扮's pictures, and the
/// hairline under it. Once [feedOffset], how far 推荐 is scrolled, passes [HomeHeaderTheme.trigger], it folds the top
/// row away (121): everything moves up under the status bar, the top row fading out and a magnifier riding in at
/// the tab row's end, which opens 搜索 in its place. Back under the trigger it opens again.
class HomeHeader extends StatefulWidget {
  const HomeHeader({
    super.key,
    required this.skin,
    required this.face,
    required this.searchWord,
    required this.feedOffset,
    required this.onAvatar,
    required this.onSearch,
    this.onHistory,
  });

  /// A skin with a `head_bg`, its pictures decoded, or null.
  final Skin? skin;
  final String? face;
  final String? searchWord;
  final ValueListenable<double> feedOffset;
  final VoidCallback onAvatar;
  final VoidCallback onSearch;

  /// The iPad's clock at the top's right end.
  final VoidCallback? onHistory;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader>
    with SingleTickerProviderStateMixin {
  late bool _folded = _shouldFold;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HomeHeaderTheme.duration,
    value: _folded ? 1 : 0,
  )..addStatusListener(_statusChanged);
  late final CurvedAnimation _fold = CurvedAnimation(
    parent: _controller,
    curve: HomeHeaderTheme.curve,
  );
  late final Animation<double> _shown = ReverseAnimation(_fold);
  bool _still = false;

  bool get _shouldFold => widget.feedOffset.value >= HomeHeaderTheme.trigger;

  @override
  void initState() {
    super.initState();
    widget.feedOffset.addListener(_offsetChanged);
  }

  @override
  void didUpdateWidget(HomeHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feedOffset, widget.feedOffset)) {
      oldWidget.feedOffset.removeListener(_offsetChanged);
      widget.feedOffset.addListener(_offsetChanged);
      _offsetChanged();
    }
  }

  @override
  void dispose() {
    widget.feedOffset.removeListener(_offsetChanged);
    _fold.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _offsetChanged() {
    final fold = _shouldFold;
    if (fold == _folded) return;
    // The feed's notifications can come mid-layout, and the fold itself resizes the feed.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _offsetChanged();
      });
      return;
    }
    setState(() => _folded = fold);
    if (_still) {
      _controller.value = fold ? 1 : 0;
    } else if (fold) {
      unawaited(_controller.forward());
    } else {
      unawaited(_controller.reverse());
    }
  }

  /// The magnifier is built only while the header is folded or folding.
  void _statusChanged(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _still = MediaQuery.disableAnimationsOf(context);
    final head = widget.skin;
    final colour = head?.color;
    // The iPad's one row holds the tabs too, so nothing folds away (no screenshot shows it scrolled).
    if (FormFactor.of(context).isPad) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Head(
            skin: head,
            whole: true,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: PadHomeTheme.rowHeight,
                child: _PadRow(
                  face: widget.face,
                  searchWord: widget.searchWord,
                  skin: head,
                  onAvatar: widget.onAvatar,
                  onSearch: widget.onSearch,
                  onHistory: widget.onHistory,
                ),
              ),
            ),
          ),
          Divider(
            height: PadHomeTheme.hairline,
            thickness: PadHomeTheme.hairline,
            color: head != null ? HomeTabBarTheme.colorsOf(context).headDivider : BiliColors.colorsOf(context).divider,
          ),
        ],
      );
    }
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Head(
          skin: head,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                FadeTransition(
                  opacity: _shown,
                  child: IgnorePointer(
                    ignoring: _folded,
                    child: ExcludeSemantics(
                      excluding: _folded,
                      child: _TopRow(
                        face: widget.face,
                        searchWord: widget.searchWord,
                        filled: head != null,
                        onAvatar: widget.onAvatar,
                        onSearch: widget.onSearch,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      _RecommendTab(colour: colour ?? BiliColors.colorsOf(context).pink),
                      if (!_controller.isDismissed)
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: _TabSearch(
                            fold: _fold,
                            enabled: _folded,
                            colour:
                                colour?.withValues(
                                  alpha: HomeHeaderTheme.skinSearchOpacity,
                                ) ??
                                HomeHeaderTheme.colorsOf(context).searchInk,
                            onTap: widget.onSearch,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: HomeTabBarTheme.hairlineWidth,
          thickness: HomeTabBarTheme.hairlineWidth,
          color: head != null
              ? HomeTabBarTheme.colorsOf(context).headDivider
              : BiliColors.colorsOf(context).divider,
        ),
      ],
    );
    return AnimatedBuilder(
      animation: _fold,
      builder: (context, child) =>
          _Fold(by: HomeHeaderTheme.fold * _fold.value, child: child),
      child: content,
    );
  }
}

/// The tab row's magnifier (121), riding in from the right as the header folds; it takes taps only while folded.
class _TabSearch extends StatelessWidget {
  const _TabSearch({
    required this.fold,
    required this.enabled,
    required this.colour,
    required this.onTap,
  });

  final Animation<double> fold;
  final bool enabled;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const lead =
        HomeHeaderTheme.searchTarget -
        HomeHeaderTheme.searchSize -
        HomeHeaderTheme.searchRight;
    return AnimatedBuilder(
      animation: fold,
      builder: (context, child) => Transform.translate(
        offset: Offset(HomeHeaderTheme.searchSlide * (1 - fold.value), 0),
        child: child,
      ),
      child: IgnorePointer(
        ignoring: !enabled,
        child: ExcludeSemantics(
          excluding: !enabled,
          child: Semantics(
            button: true,
            label: '搜索',
            child: GestureDetector(
              key: const ValueKey('home-header-search'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: HomeHeaderTheme.searchTarget,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: lead,
                      top: HomeHeaderTheme.searchTop,
                    ),
                    child: SearchGlyphIcon(
                      SearchGlyph.magnifier,
                      size: HomeHeaderTheme.searchSize,
                      color: colour,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Its child [by] pt shorter: laid out whole, drawn moved up by [by] and cut at its own top, so what is below
/// follows the child's bottom.
class _Fold extends SingleChildRenderObjectWidget {
  const _Fold({required this.by, super.child});

  final double by;

  @override
  _RenderFold createRenderObject(BuildContext context) => _RenderFold(by);

  @override
  void updateRenderObject(BuildContext context, _RenderFold renderObject) =>
      renderObject.by = by;
}

class _RenderFold extends RenderShiftedBox {
  _RenderFold(this._by) : super(null);

  double _by;

  set by(double value) {
    if (value == _by) return;
    _by = value;
    markNeedsLayout();
  }

  final _clip = LayerHandle<ClipRectLayer>();

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(super.computeMinIntrinsicHeight(width) - _by, 0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(super.computeMaxIntrinsicHeight(width) - _by, 0);

  Size _sizeFor(BoxConstraints constraints, Size child) =>
      constraints.constrain(Size(child.width, math.max(child.height - _by, 0)));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _sizeFor(
      constraints,
      child.getDryLayout(_childConstraints(constraints)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      size.height - child.size.height,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      size.contains(position) &&
      super.hitTestChildren(result, position: position);

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// The account's avatar; a grey head until the account has a face.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.face, required this.size});

  final String? face;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = face;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url != null && url.isNotEmpty
            ? RemoteImage.avatar(url)
            : ColoredBox(
                color: BiliColors.colorsOf(context).pageGrey,
                child: Icon(
                  Icons.person,
                  size: size * 0.55,
                  color: BiliColors.colorsOf(context).divider,
                ),
              ),
      ),
    );
  }
}

/// The status bar, the top row and the tab row on white (01), or over the 装扮's pictures (110): [skin]'s `head_bg`
/// down to the top row's bottom and `head_tab_bg` behind the tab row, or `head_bg` behind all of it when the package
/// has no tab picture. Both are cropped to their boxes about the centre.
class _Head extends StatelessWidget {
  const _Head({required this.skin, required this.child, this.whole = false});

  /// A skin with a `head_bg`, its pictures decoded, or null.
  final Skin? skin;
  final Widget child;

  /// `head_bg` behind all of it, as the iPad's one row has no tab strip of its own.
  final bool whole;

  @override
  Widget build(BuildContext context) {
    final head = skin?.headBg;
    if (head == null) return ColoredBox(color: BiliColors.colorsOf(context).card, child: child);
    final tab = whole ? null : skin?.headTabBg;
    final rowBottom =
        MediaQuery.paddingOf(context).top + BiliMetrics.topRowHeight;
    return Stack(
      children: [
        Positioned(
          key: const ValueKey('home-head-art'),
          top: 0,
          left: 0,
          right: 0,
          height: tab == null ? null : rowBottom,
          bottom: tab == null ? 0 : null,
          child: _picture(head),
        ),
        if (tab != null)
          Positioned(
            key: const ValueKey('home-head-tab-art'),
            top: rowBottom,
            left: 0,
            right: 0,
            bottom: 0,
            child: _picture(tab),
          ),
        child,
      ],
    );
  }

  static Widget _picture(File file) => SkinDecodeGate.image(file);
}

/// The avatar and the search entry (01): a rounded bar with the magnifier and the default word, which opens 搜索.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.face,
    required this.searchWord,
    required this.filled,
    required this.onAvatar,
    required this.onSearch,
  });

  final String? face;
  final String? searchWord;

  /// The entry filled white without its rim, over the 装扮's picture (110).
  final bool filled;
  final VoidCallback onAvatar;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: BiliMetrics.topRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BiliMetrics.topRowMargin,
        ),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: '账号',
              child: GestureDetector(
                key: const ValueKey('home-avatar'),
                onTap: onAvatar,
                child: _AccountAvatar(face: face, size: BiliMetrics.homeAvatar),
              ),
            ),
            const SizedBox(width: HomeTabBarTheme.fieldGap),
            _SearchField(word: searchWord, filled: filled, onTap: onSearch),
          ],
        ),
      ),
    );
  }
}

/// The search entry: the magnifier and the grey word in a stadium, greyed while pressed.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.word,
    required this.filled,
    required this.onTap,
  });

  final String? word;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final word = TextStyle(
      fontSize: HomeTabBarTheme.fieldText,
      color: HomeTabBarTheme.colorsOf(context).fieldInk,
    );
    const glyphLead =
        HomeTabBarTheme.fieldGlyphCentre - HomeTabBarTheme.fieldGlyph / 2;
    return Semantics(
      button: true,
      label: '搜索',
      value: widget.word,
      child: GestureDetector(
        key: const ValueKey('home-search'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: ExcludeSemantics(
          // The rim is drawn over the contents: as the decoration, its width would inset them (01 measures from the
          // rim's outer edge).
          child: Container(
            key: const ValueKey('home-search-field'),
            width: HomeTabBarTheme.fieldWidth,
            height: BiliMetrics.linkFieldHeight,
            decoration: widget.filled
                ? ShapeDecoration(
                    color: HomeTabBarTheme.colorsOf(context).headField,
                    shape: StadiumBorder(),
                  )
                : null,
            foregroundDecoration: ShapeDecoration(
              color: _pressed ? BiliColors.colorsOf(context).pressedFill : null,
              shape: widget.filled
                  ? const StadiumBorder()
                  : const StadiumBorder(
                      side: BorderSide(
                        color: HomeTabBarTheme.fieldOutline,
                        width: HomeTabBarTheme.fieldOutlineWidth,
                      ),
                    ),
            ),
            child: Row(
              children: [
                const SizedBox(width: glyphLead),
                Transform.translate(
                  offset: const Offset(0, -HomeTabBarTheme.fieldGlyphRise),
                  child: SearchGlyphIcon(
                    SearchGlyph.magnifier,
                    size: HomeTabBarTheme.fieldGlyph,
                    color: HomeTabBarTheme.colorsOf(context).fieldInk,
                  ),
                ),
                const SizedBox(
                  width:
                      HomeTabBarTheme.fieldTextStart -
                      glyphLead -
                      HomeTabBarTheme.fieldGlyph,
                ),
                Expanded(
                  child: Text(
                    widget.word ?? '',
                    key: const ValueKey('home-search-word'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: word,
                    strutStyle: BiliFonts.strutOf(context, word),
                  ),
                ),
                const SizedBox(width: HomeTabBarTheme.fieldTextEnd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 01's tab row, with only 推荐 and that one selected: pink, or the 装扮's colour over its picture (110).
class _RecommendTab extends StatelessWidget {
  const _RecommendTab({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    selected: true,
    child: Padding(
      padding: const EdgeInsets.only(
        top: BiliMetrics.tabRowTop,
        bottom: BiliMetrics.tabRowBottom,
      ),
      child: Column(
        children: [
          Text(
            '推荐',
            key: const ValueKey('home-tab-recommend'),
            style: TextStyle(
              fontSize: BiliMetrics.tabText,
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
          const SizedBox(height: BiliMetrics.tabIndicatorGap),
          Container(
            key: const ValueKey('home-tab-indicator'),
            width: BiliMetrics.tabIndicatorWidth,
            height: BiliMetrics.tabIndicatorHeight,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The iPad's top (ipad/01, 02): the avatar and the search entry at the left, 直播 推荐 热门 追番 影视 centred on the
/// screen, scan, 历史记录 and 消息 at the right, all on one row. Only 推荐 answers; the other tabs are drawn, not built.
class _PadRow extends StatelessWidget {
  const _PadRow({
    required this.face,
    required this.searchWord,
    required this.skin,
    required this.onAvatar,
    required this.onSearch,
    required this.onHistory,
  });

  final String? face;
  final String? searchWord;
  final Skin? skin;
  final VoidCallback onAvatar;
  final VoidCallback onSearch;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    const centre = PadHomeTheme.rowCentre;
    const tabsWidth = PadHomeTheme.tabPitch * 5;
    final colour = skin?.color;
    final ink = colour?.withValues(alpha: HomeHeaderTheme.skinSearchOpacity) ?? PadHomeTheme.colorsOf(context).iconInk;
    final tabInk = colour?.withValues(alpha: HomeHeaderTheme.skinSearchOpacity) ?? PadHomeTheme.colorsOf(context).tabInk;
    Widget icon(double right, String key, String label, Widget glyph, VoidCallback onTap) => Positioned(
      right: right - PadHomeTheme.icon,
      top: centre - PadHomeTheme.icon,
      width: PadHomeTheme.icon * 2,
      height: PadHomeTheme.icon * 2,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(child: SizedBox.square(dimension: PadHomeTheme.icon, child: glyph)),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final tabsLeft = (box.maxWidth - tabsWidth) / 2;
        return Stack(
          children: [
            Positioned(
              left: PadHomeTheme.avatarLeft,
              top: centre - PadHomeTheme.avatar / 2,
              child: Semantics(
                button: true,
                label: '账号',
                child: GestureDetector(
                  key: const ValueKey('home-avatar'),
                  onTap: onAvatar,
                  child: _AccountAvatar(face: face, size: PadHomeTheme.avatar),
                ),
              ),
            ),
            Positioned(
              left: PadHomeTheme.fieldLeft,
              top: centre - PadHomeTheme.fieldHeight / 2,
              height: PadHomeTheme.fieldHeight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.max(0, tabsLeft - PadHomeTheme.fieldTabGap - PadHomeTheme.fieldLeft),
                ),
                child: _PadSearchField(word: searchWord, filled: skin != null, onTap: onSearch),
              ),
            ),
            Positioned(
              left: tabsLeft,
              top: 0,
              width: tabsWidth,
              height: centre * 2,
              child: Row(
                children: [
                  for (final tab in PadHomeTheme.tabs)
                    SizedBox(
                      width: PadHomeTheme.tabPitch,
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, -PadHomeTheme.tabRise),
                          child: _PadTab(tab, colour: tab == '推荐' ? colour ?? PadHomeTheme.colorsOf(context).pink : tabInk),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            icon(
              PadHomeTheme.scanRight,
              'home-scan',
              '扫一扫',
              CustomPaint(painter: _PadGlyphPainter(_PadGlyph.scan, ink)),
              () => showToast(context, '暂未开放'),
            ),
            icon(
              PadHomeTheme.historyRight,
              'home-history',
              '历史记录',
              CustomPaint(painter: _PadGlyphPainter(_PadGlyph.history, ink)),
              onHistory ?? () {},
            ),
            icon(
              PadHomeTheme.messagesRight,
              'home-messages',
              '消息',
              CustomPaint(painter: _PadGlyphPainter(_PadGlyph.messages, ink)),
              () => showToast(context, '暂未开放'),
            ),
          ],
        );
      },
    );
  }
}

class _PadTab extends StatelessWidget {
  const _PadTab(this.text, {required this.colour});

  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final selected = text == '推荐';
    final style = TextStyle(
      fontSize: PadHomeTheme.tabText,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      color: colour,
    );
    return Semantics(
      header: selected,
      selected: selected,
      child: Text(
        text,
        key: selected ? const ValueKey('home-tab-recommend') : ValueKey('home-pad-tab-$text'),
        maxLines: 1,
        style: style,
        strutStyle: BiliFonts.strutOf(context, style),
      ),
    );
  }
}

/// The iPad's search entry: a grey stadium as wide as its word needs, up to what the row leaves it.
class _PadSearchField extends StatefulWidget {
  const _PadSearchField({required this.word, required this.filled, required this.onTap});

  final String? word;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_PadSearchField> createState() => _PadSearchFieldState();
}

class _PadSearchFieldState extends State<_PadSearchField> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final word = TextStyle(fontSize: PadHomeTheme.fieldText, color: PadHomeTheme.colorsOf(context).fieldInk);
    return Semantics(
      button: true,
      label: '搜索',
      value: widget.word,
      child: GestureDetector(
        key: const ValueKey('home-search'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: Container(
            key: const ValueKey('home-search-field'),
            height: PadHomeTheme.fieldHeight,
            decoration: ShapeDecoration(
              color: widget.filled ? HomeTabBarTheme.colorsOf(context).headField : PadHomeTheme.colorsOf(context).fieldFill,
              shape: const StadiumBorder(),
            ),
            foregroundDecoration: ShapeDecoration(
              color: _pressed ? BiliColors.colorsOf(context).pressedFill : null,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: PadHomeTheme.fieldGlyphLead),
                SearchGlyphIcon(
                  SearchGlyph.magnifier,
                  size: PadHomeTheme.fieldGlyph,
                  color: PadHomeTheme.colorsOf(context).fieldGlyphInk,
                ),
                const SizedBox(
                  width: PadHomeTheme.fieldTextStart - PadHomeTheme.fieldGlyphLead - PadHomeTheme.fieldGlyph,
                ),
                Flexible(
                  child: Text(
                    widget.word ?? '',
                    key: const ValueKey('home-search-word'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: word,
                    strutStyle: BiliFonts.strutOf(context, word),
                  ),
                ),
                const SizedBox(width: PadHomeTheme.fieldTextEnd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PadGlyph { scan, history, messages }

/// The iPad's scan, its clock with the turning arrow and its round bubble with three dots (ipad/01), drawn in a 20 pt
/// square: the APK has no clock or bubble, and its scans (`ic_scan_cast`, `ic_mine_scan`) draw heavier strokes and a
/// bar that stops inside the brackets.
class _PadGlyphPainter extends CustomPainter {
  _PadGlyphPainter(this.glyph, this.color);

  final _PadGlyph glyph;
  final Color color;

  static const _design = 20.0;
  static const _degree = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _design);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = PadHomeTheme.iconLine
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (glyph) {
      case _PadGlyph.scan:
        _scan(canvas, line);
      case _PadGlyph.history:
        _clock(canvas, line);
      case _PadGlyph.messages:
        _bubble(canvas, line);
    }
    canvas.restore();
  }

  /// Four rounded corners 15.6 apart and a bar running 0.7 past them on either side, square-ended (01, measured).
  void _scan(Canvas canvas, Paint line) {
    const near = 2.2;
    const far = 20 - near;
    const radius = 2.0;
    const armEnd = 3.025;
    const legEnd = 4.0;
    for (final (x, y) in const [(near, near), (far, near), (near, far), (far, far)]) {
      final sx = x < 10 ? 1.0 : -1.0;
      final sy = y < 10 ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, 10 - sy * legEnd)
          ..lineTo(x, y + sy * radius)
          ..arcToPoint(
            Offset(x + sx * radius, y),
            radius: const Radius.circular(radius),
            clockwise: sx * sy > 0,
          )
          ..lineTo(10 - sx * armEnd, y),
        line,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(1.085, 10 - PadHomeTheme.iconLine / 2, 18.915, 10 + PadHomeTheme.iconLine / 2),
      Paint()..color = color,
    );
  }

  /// The ring opens between the arrow's tip at the upper right and its other end at the right.
  void _clock(Canvas canvas, Paint line) {
    const tip = Offset(17.9, 5.6);
    canvas
      ..drawArc(Rect.fromCircle(center: const Offset(10, 10), radius: 9.25), -4 * _degree, 324 * _degree, false, line)
      ..drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy - 3.6)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - 3.6, tip.dy),
        line,
      )
      ..drawPath(
        Path()
          ..moveTo(9.25, 5.6)
          ..lineTo(9.25, 10.9)
          ..lineTo(14.25, 10.9),
        line,
      );
  }

  /// A round bubble whose tail flicks out at the lower left.
  void _bubble(Canvas canvas, Paint line) {
    const centre = Offset(9.9, 9.9);
    const radius = 9.05;
    final outline = Path()
      ..addArc(Rect.fromCircle(center: centre, radius: radius), 147 * _degree, 327 * _degree)
      ..lineTo(1.6, 17.7)
      ..lineTo(5.3, 16.2)
      ..lineTo(centre.dx + radius * math.cos(147 * _degree), centre.dy + radius * math.sin(147 * _degree));
    canvas.drawPath(outline, line);
    final dot = Paint()..color = color;
    for (final x in const [6.1, 10.5, 14.9]) {
      canvas.drawCircle(Offset(x, 9.5), 1.25, dot);
    }
  }

  @override
  bool shouldRepaint(_PadGlyphPainter oldDelegate) => oldDelegate.color != color || oldDelegate.glyph != glyph;
}
