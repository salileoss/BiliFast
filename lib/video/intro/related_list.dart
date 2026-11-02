import 'dart:async';

import 'package:bili_core/api.dart' show VideoCard;
import 'package:bili_core/logic.dart' show CountFormat, TimeFormat;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart' show Icons, Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../app/form_factor.dart';
import '../../player_ui/end_screen_portrait.dart' show CountGlyph, CountPainter;
import '../../shared/cover_preset.dart';
import '../../shared/menu.dart';
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../video_route.dart';

/// The related videos under 简介 (03, 18), as a sliver: cover with duration, title, UP and counts, and ⋮ 稍后再看.
/// The web list carries no recommendation reason (03's orange tags come from the app's own feed), so every row shows
/// the UP badge, as 18 does. On the iPad the rows are larger and undivided (ipad/03, 06): upright the list opens
/// with a hairline under 简介's head, sideways ([column]) it fills the right column at that column's gutter.
class RelatedSliver extends StatefulWidget {
  const RelatedSliver({
    super.key,
    required this.cards,
    required this.onOpen,
    required this.onWatchLater,
    this.column = false,
  });

  final List<VideoCard> cards;
  final ValueChanged<VideoCard> onOpen;
  final ValueChanged<VideoCard> onWatchLater;

  /// The iPad's right column sideways.
  final bool column;

  /// The iPhone's covers say 2:55, not 02:55; the iPad's keep the zero.
  static String duration(int seconds, {bool pad = false}) {
    final clock = TimeFormat.clock(seconds.toDouble());
    if (pad) return clock;
    return clock.length == 5 && clock.startsWith('0') ? clock.substring(1) : clock;
  }

  @override
  State<RelatedSliver> createState() => _RelatedSliverState();
}

class _RelatedSliverState extends State<RelatedSliver> {
  /// Bumped for each new list, so its rows come in again; rows built later, while scrolling, just appear.
  int _generation = 0;
  bool _revealing = false;

  @override
  void initState() {
    super.initState();
    _revealing = widget.cards.isNotEmpty;
  }

  @override
  void didUpdateWidget(RelatedSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.cards.firstOrNull?.bvid;
    final now = widget.cards.firstOrNull?.bvid;
    if (now != null && now != before) {
      _generation++;
      _revealing = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    if (_revealing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealing = false);
    }
    final revealing = _revealing && !MediaQuery.disableAnimationsOf(context);
    final seen = <String>{};
    final heroes = [for (final card in cards) seen.add(card.bvid)];
    final pad = FormFactor.of(context).isPad;
    final metrics = pad
        ? _RowMetrics.pad(widget.column ? PadBodyTheme.relatedColumnGutter : PadBodyTheme.gutter)
        : _RowMetrics.phone;
    final list = SliverFixedExtentList.builder(
      itemExtent: metrics.rowHeight,
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final row = _RelatedRow(
          card: card,
          metrics: metrics,
          first: index == 0,
          hero: heroes[index],
          onOpen: () => widget.onOpen(card),
          onWatchLater: () => widget.onWatchLater(card),
        );
        return KeyedSubtree(
          key: ValueKey((_generation, card.bvid)),
          child: revealing && index < IntroListTheme.revealRows
              ? _Reveal(delay: IntroListTheme.revealStagger * index, child: row)
              : row,
        );
      },
    );
    if (!pad) {
      return SliverPadding(
        padding: const EdgeInsets.only(top: IntroListTheme.sectionTop),
        sliver: list,
      );
    }
    final top = SliverPadding(
      padding: const EdgeInsets.only(top: PadBodyTheme.relatedListTop),
      sliver: list,
    );
    if (widget.column) return top;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            key: ValueKey('related-hairline'),
            padding: EdgeInsets.only(
              top: PadBodyTheme.relatedHairlineGap,
              left: PadBodyTheme.relatedHairlineInset,
              right: PadBodyTheme.relatedHairlineInset,
            ),
            child: SizedBox(
              height: PageTheme.hairline,
              child: ColoredBox(color: BiliColors.colorsOf(context).divider),
            ),
          ),
        ),
        top,
      ],
    );
  }
}

/// A related row's sizes, the iPhone's or the iPad's.
@immutable
final class _RowMetrics {
  const _RowMetrics({
    required this.pad,
    required this.gutter,
    required this.rowHeight,
    required this.coverTop,
    required this.coverWidth,
    required this.coverHeight,
    required this.textGap,
    required this.titleLift,
    required this.uploaderCentre,
    required this.countsCentre,
    required this.metaLead,
    required this.metaGap,
    required this.countSpacing,
    required this.iconWidth,
    required this.iconHeight,
    required this.upFont,
    required this.upRadius,
    required this.moreCentreFromRight,
    required this.moreDot,
    required this.moreDotGap,
    required this.durationInset,
    required this.durationHeight,
    required this.durationPad,
    required this.durationRadius,
    required this.durationFill,
    required this.titleWeight,
  });

  static const phone = _RowMetrics(
    pad: false,
    gutter: BiliMetrics.gutter,
    rowHeight: IntroListTheme.relatedRowHeight,
    coverTop: IntroListTheme.relatedCoverTop,
    coverWidth: IntroListTheme.relatedCoverWidth,
    coverHeight: IntroListTheme.relatedCoverHeight,
    textGap: IntroListTheme.relatedTextGap,
    titleLift: IntroListTheme.relatedTitleLift,
    uploaderCentre: IntroListTheme.relatedUploaderCentre,
    countsCentre: IntroListTheme.relatedCountsCentre,
    metaLead: IntroListTheme.relatedMetaLead,
    metaGap: IntroListTheme.relatedMetaGap,
    countSpacing: IntroListTheme.relatedCountSpacing,
    iconWidth: BiliMetrics.endCountIconWidth,
    iconHeight: BiliMetrics.endCountIconHeight,
    upFont: BiliMetrics.endUpFont,
    upRadius: BiliMetrics.endUpRadius,
    moreCentreFromRight: IntroListTheme.moreCentreFromRight,
    moreDot: IntroListTheme.moreDot,
    moreDotGap: IntroListTheme.moreDotGap,
    durationInset: IntroListTheme.durationInset,
    durationHeight: IntroListTheme.durationHeight,
    durationPad: IntroListTheme.durationPad,
    durationRadius: IntroListTheme.durationRadius,
    durationFill: IntroListTheme.durationFill,
    titleWeight: null,
  );

  const _RowMetrics.pad(double gutter)
    : this(
        pad: true,
        gutter: gutter,
        rowHeight: PadBodyTheme.relatedRowHeight,
        coverTop: PadBodyTheme.relatedCoverTop,
        coverWidth: PadBodyTheme.relatedCoverWidth,
        coverHeight: PadBodyTheme.relatedCoverHeight,
        textGap: PadBodyTheme.relatedTextGap,
        titleLift: PadBodyTheme.relatedTitleLift,
        uploaderCentre: PadBodyTheme.relatedUploaderCentre,
        countsCentre: PadBodyTheme.relatedCountsCentre,
        metaLead: PadBodyTheme.relatedMetaLead,
        metaGap: PadBodyTheme.relatedMetaGap,
        countSpacing: PadBodyTheme.relatedCountSpacing,
        iconWidth: PadBodyTheme.relatedIconWidth,
        iconHeight: PadBodyTheme.relatedIconHeight,
        upFont: PadBodyTheme.relatedUpFont,
        upRadius: PadBodyTheme.relatedUpRadius,
        moreCentreFromRight: gutter + PadBodyTheme.moreInset,
        moreDot: PadBodyTheme.moreDot,
        moreDotGap: PadBodyTheme.moreDotGap,
        durationInset: PadBodyTheme.durationInset,
        durationHeight: PadBodyTheme.durationHeight,
        durationPad: PadBodyTheme.durationPad,
        durationRadius: PadBodyTheme.durationRadius,
        durationFill: PadBodyTheme.durationFill,
        titleWeight: PadBodyTheme.relatedTitleWeight,
      );

  final bool pad;
  final double gutter;
  final double rowHeight;
  final double coverTop;
  final double coverWidth;
  final double coverHeight;
  final double textGap;
  final double titleLift;
  final double uploaderCentre;
  final double countsCentre;
  final double metaLead;
  final double metaGap;
  final double countSpacing;
  final double iconWidth;
  final double iconHeight;
  final double upFont;
  final double upRadius;
  final double moreCentreFromRight;
  final double moreDot;
  final double moreDotGap;
  final double durationInset;
  final double durationHeight;
  final double durationPad;
  final double durationRadius;
  final Color durationFill;
  final FontWeight? titleWeight;

  double get textLeft => gutter + coverWidth + textGap;
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({
    required this.card,
    required this.metrics,
    required this.first,
    required this.hero,
    required this.onOpen,
    required this.onWatchLater,
  });

  final VideoCard card;
  final _RowMetrics metrics;
  final bool first;
  final bool hero;
  final VoidCallback onOpen;
  final VoidCallback onWatchLater;

  TextStyle _meta(BuildContext context) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: IntroListTheme.relatedMetaText,
    height: 1,
    color: BiliColors.colorsOf(context).secondaryText,
  );

  TextStyle _count(BuildContext context) => _meta(context).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final coverTop = m.coverTop;
    final cover = RemoteImage(
      card.cover,
      size: Size(m.coverWidth, m.coverHeight),
      cover: true,
      preset: CoverPreset.related,
    );
    final title = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: IntroListTheme.relatedTitleText,
      height: IntroListTheme.relatedTitleLine / IntroListTheme.relatedTitleText,
      fontWeight: m.titleWeight,
      color: BiliColors.colorsOf(context).text,
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: card.title,
              onTap: onOpen,
              excludeSemantics: true,
              child: PressHighlight(
                onTap: onOpen,
                child: Stack(
                  children: [
                    if (!m.pad)
                      Positioned(
                        top: 0,
                        left: first ? 0 : IntroListTheme.relatedDividerInset,
                        right: 0,
                        height: BiliMetrics.panelHairline,
                        child: ColoredBox(color: BiliColors.colorsOf(context).divider),
                      ),
                    Positioned(
                      left: m.gutter,
                      top: coverTop,
                      width: m.coverWidth,
                      height: m.coverHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(IntroListTheme.relatedCoverRadius),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hero) Hero(tag: VideoRoute.coverTag(card.bvid), child: cover) else cover,
                            if (card.duration > 0)
                              Positioned(
                                right: m.durationInset,
                                bottom: m.durationInset,
                                height: m.durationHeight,
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.symmetric(horizontal: m.durationPad),
                                  decoration: BoxDecoration(
                                    color: m.durationFill,
                                    borderRadius: BorderRadius.circular(m.durationRadius),
                                  ),
                                  child: Text(
                                    RelatedSliver.duration(card.duration, pad: m.pad),
                                    style: TextStyle(
                                      fontFamily: BiliFonts.family,
                                      fontSize: IntroListTheme.durationText,
                                      height: 1,
                                      color: BiliColors.onCover,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: m.textLeft,
                      right: m.gutter,
                      top: coverTop - m.titleLift,
                      child: Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: title,
                        strutStyle: BiliFonts.strut(title),
                      ),
                    ),
                    _line(
                      m.uploaderCentre,
                      right: m.gutter,
                      Row(
                        children: [
                          _UpBadge(metrics: m),
                          SizedBox(width: m.metaGap),
                          Flexible(
                            child: Text(
                              card.ownerName,
                              style: _meta(context),
                              strutStyle: BiliFonts.strut(_meta(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _line(
                      m.countsCentre,
                      right: m.moreCentreFromRight + IntroListTheme.moreTarget / 2,
                      Row(
                        children: [
                          _CountIcon(CountGlyph.views, metrics: m),
                          SizedBox(width: m.metaGap),
                          Text(CountFormat.short(card.views), style: _count(context), strutStyle: BiliFonts.strut(_count(context))),
                          SizedBox(width: m.countSpacing),
                          _CountIcon(CountGlyph.danmaku, metrics: m),
                          SizedBox(width: m.metaGap),
                          Text(CountFormat.short(card.danmaku), style: _count(context), strutStyle: BiliFonts.strut(_count(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: m.moreCentreFromRight - IntroListTheme.moreTarget / 2,
            top: coverTop + m.countsCentre - IntroListTheme.moreTarget / 2,
            width: IntroListTheme.moreTarget,
            height: IntroListTheme.moreTarget,
            child: _More(onWatchLater: onWatchLater, dot: m.moreDot, dotGap: m.moreDotGap),
          ),
        ],
      ),
    );
  }

  /// A line of meta text centred [centre] below the cover's top.
  Widget _line(double centre, Widget child, {required double right}) => Positioned(
    left: metrics.textLeft + metrics.metaLead,
    right: right,
    top: metrics.coverTop + centre - IntroListTheme.relatedMetaLine / 2,
    height: IntroListTheme.relatedMetaLine,
    child: child,
  );
}

class _UpBadge extends StatelessWidget {
  const _UpBadge({required this.metrics});

  final _RowMetrics metrics;

  @override
  Widget build(BuildContext context) => Container(
    width: metrics.iconWidth,
    height: metrics.iconHeight,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: BiliColors.colorsOf(context).secondaryText, width: BiliMetrics.endUpBorder),
      borderRadius: BorderRadius.circular(metrics.upRadius),
    ),
    child: Text(
      'UP',
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: BiliFonts.family,
        color: BiliColors.colorsOf(context).secondaryText,
        fontSize: metrics.upFont,
        fontWeight: FontWeight.bold,
        height: 1,
      ),
    ),
  );
}

class _CountIcon extends StatelessWidget {
  const _CountIcon(this.glyph, {required this.metrics});

  final CountGlyph glyph;
  final _RowMetrics metrics;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(metrics.iconWidth, metrics.iconHeight),
    painter: CountPainter(glyph, color: BiliColors.colorsOf(context).secondaryText),
  );
}

class _More extends StatelessWidget {
  const _More({required this.onWatchLater, required this.dot, required this.dotGap});

  final VoidCallback onWatchLater;
  final double dot;
  final double dotGap;

  void _open(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    unawaited(
      Navigator.of(context).push(
        _RelatedMenuRoute(
          anchor: anchor,
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          onWatchLater: onWatchLater,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '更多',
    onTap: () => _open(context),
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('related-more'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Center(
        child: CustomPaint(
          size: Size(dot, dot * 3 + dotGap * 2),
          painter: _DotsPainter(dot: dot, gap: dotGap, palette: BiliPalette.of(context)),
        ),
      ),
    ),
  );
}

class _DotsPainter extends CustomPainter {
  final BiliPalette palette;
  const _DotsPainter({this.palette = const BiliPalette(Brightness.light), required this.dot, required this.gap});

  final double dot;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = BiliColorsColors(palette).secondaryText;
    final radius = dot / 2;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(radius, radius + i * (dot + gap)), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => (oldDelegate.dot != dot || oldDelegate.gap != gap) || oldDelegate.palette.brightness != palette.brightness;
}

/// ⋮'s menu, as the feed card's: frosted glass growing out of the dots, below them or, near the bottom, above.
class _RelatedMenuRoute extends PopupRoute<void> {
  _RelatedMenuRoute({required this.anchor, required this.reduceMotion, required this.onWatchLater});

  final Rect anchor;
  final bool reduceMotion;
  final VoidCallback onWatchLater;

  static const _height = BiliMetrics.menuRowHeight;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => '关闭菜单';

  @override
  Duration get transitionDuration => reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => reduceMotion ? Duration.zero : const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final below =
        anchor.bottom + BiliMetrics.cardMenuGap + _height <= screen.height - padding.bottom - BiliMetrics.gutter;
    final left = clampDouble(
      anchor.right - BiliMetrics.cardMenuWidth,
      BiliMetrics.gutter,
      screen.width - BiliMetrics.gutter - BiliMetrics.cardMenuWidth,
    );
    return Stack(
      children: [
        Positioned(
          left: left,
          top: below ? anchor.bottom + BiliMetrics.cardMenuGap : anchor.top - BiliMetrics.cardMenuGap - _height,
          child: ScaleTransition(
            alignment: below ? Alignment.topRight : Alignment.bottomRight,
            scale: Tween(begin: 0.8, end: 1.0).animate(animation),
            child: FadeTransition(
              opacity: animation,
              child: Material(
                type: MaterialType.transparency,
                child: GlassPanel(
                  width: BiliMetrics.cardMenuWidth,
                  child: MenuRow(
                    key: const ValueKey('related-watch-later'),
                    title: '稍后再看',
                    icon: Icons.schedule,
                    onTap: () {
                      Navigator.of(context).pop();
                      onWatchLater();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;

  CurvedAnimation? _curve;

  @override
  Animation<double> createAnimation() =>
      _curve = CurvedAnimation(parent: super.createAnimation(), curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }
}

/// Fades a row in while it rises into place, after [delay].
class _Reveal extends StatefulWidget {
  const _Reveal({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: widget.delay + IntroListTheme.revealDuration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _in,
    curve: Interval(widget.delay.inMicroseconds / _in.duration!.inMicroseconds, 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _in.forward().ignore();
  }

  @override
  void dispose() {
    _curve.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _curve.value,
      child: Transform.translate(offset: Offset(0, (1 - _curve.value) * IntroListTheme.revealRise), child: child),
    ),
  );
}
