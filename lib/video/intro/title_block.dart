import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart' show VideoDetail, VideoTag, VideoTagKind;
import 'package:bili_core/devlog.dart';
import 'package:bili_core/logic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../player_ui/end_screen_portrait.dart' show CountGlyph, CountPainter;
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import 'desc_text.dart';

/// The title with its 活动 tag and ⌄, the meta line with N人正在看 (03) and any notice under it. Expanded (18): the BV
/// id, the reprint notice, the description with seeking timestamps, links and video ids, and the plain tags.
class TitleBlock extends StatefulWidget {
  const TitleBlock({
    super.key,
    required this.detail,
    required this.online,
    required this.tags,
    required this.onSeek,
    required this.onOpenVideo,
    this.openLink = _openInBrowser,
  });

  final VideoDetail detail;
  final ValueListenable<String?> online;
  final List<VideoTag> tags;

  /// A timestamp in the description, in seconds.
  final ValueChanged<double> onSeek;

  /// A BV or av id in the description.
  final ValueChanged<String> onOpenVideo;

  /// A web address in the description; the browser by default. False when nothing could open it.
  final Future<bool> Function(Uri link) openLink;

  static Future<bool> _openInBrowser(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  State<TitleBlock> createState() => _TitleBlockState();
}

class _TitleBlockState extends State<TitleBlock> with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(vsync: this, duration: IntroTheme.expandDuration);
  late final _curve = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Collapsed, the details leave the tree once they have slid away.
    _reveal.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(TitleBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new video starts collapsed, as the official page does.
    if (oldWidget.detail.bvid != widget.detail.bvid && _expanded) {
      _expanded = false;
      _reveal.value = 0;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = _expanded ? 1 : 0;
    } else if (_expanded) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  Future<void> _openLink(Uri link) async {
    var opened = false;
    try {
      opened = await widget.openLink(link);
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'description link failed', {'error': '$error'});
    }
    if (!opened && mounted) showToast(context, '无法打开链接');
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: Padding(
        padding: const EdgeInsets.only(left: BiliMetrics.gutter, right: BiliMetrics.gutter, top: IntroTheme.titleTop),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: detail.honor == null ? detail.title : '活动，${detail.title}',
              hint: _expanded ? '收起简介' : '展开简介',
              expanded: _expanded,
              onTap: _toggle,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: animate
                    // A long title gains or loses its extra lines smoothly; a zero-length AnimatedSize would throw.
                    ? AnimatedSize(
                        duration: IntroTheme.expandDuration,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _TitleRow(detail: detail, expanded: _expanded, animate: animate),
                      )
                    : _TitleRow(detail: detail, expanded: _expanded, animate: animate),
              ),
            ),
            const SizedBox(height: IntroTheme.metaGap),
            _MetaLine(detail: detail, online: widget.online),
            if (detail.argueMessage case final notice?) _NoticeLine(text: notice),
            SizeTransition(
              sizeFactor: _curve,
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _curve,
                child: _reveal.isDismissed && !_expanded
                    ? const SizedBox(width: double.infinity)
                    : _Details(
                        detail: detail,
                        tags: widget.tags,
                        onSeek: widget.onSeek,
                        onOpenVideo: widget.onOpenVideo,
                        openLink: (link) => unawaited(_openLink(link)),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _style(double size, Color color, {double? line, FontWeight? weight, double spacing = 0}) => TextStyle(
  fontFamily: BiliFonts.family,
  // The description's spans take no fallback from the page's style.
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  height: (line ?? size) / size,
  leadingDistribution: TextLeadingDistribution.even,
  letterSpacing: spacing,
  fontWeight: weight,
  color: color,
);

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.detail, required this.expanded, required this.animate});

  final VideoDetail detail;
  final bool expanded;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final style = _style(IntroTheme.titleText, BiliColors.colorsOf(context).text, line: IntroTheme.titleLine, weight: FontWeight.w600);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.honor != null) ...[const _HonorTag(), const SizedBox(width: IntroTheme.honorGap)],
        Expanded(
          child: Text(
            detail.title,
            maxLines: expanded ? null : 1,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: style,
            strutStyle: BiliFonts.strut(style),
          ),
        ),
        const SizedBox(width: IntroTheme.chevronGap),
        Padding(
          padding: const EdgeInsets.only(
            right: IntroTheme.chevronTrailing - BiliMetrics.gutter - IntroTheme.chevronWidth / 2,
          ),
          child: SizedBox(
            width: IntroTheme.chevronWidth,
            height: IntroTheme.titleRow,
            child: Center(
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: animate ? IntroTheme.expandDuration : Duration.zero,
                curve: Curves.easeOutCubic,
                child: CustomPaint(
                  size: Size(IntroTheme.chevronWidth, IntroTheme.chevronHeight),
                  painter: _ChevronPainter(palette: BiliPalette.of(context)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HonorTag extends StatelessWidget {
  const _HonorTag();

  @override
  Widget build(BuildContext context) => Container(
    height: IntroTheme.titleRow,
    padding: const EdgeInsets.symmetric(horizontal: IntroTheme.honorPadding),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: BiliColors.colorsOf(context).softGrey, borderRadius: BorderRadius.circular(IntroTheme.titleRow / 2)),
    child: Text('活动', style: _style(IntroTheme.honorText, BiliColors.colorsOf(context).pink, line: IntroTheme.titleRow)),
  );
}

class _ChevronPainter extends CustomPainter {
  final BiliPalette palette;
  const _ChevronPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = IntroTheme.chevronStroke / 2;
    final path = Path()
      ..moveTo(inset, inset)
      ..lineTo(size.width / 2, size.height - inset)
      ..lineTo(size.width - inset, inset);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = IntroTheme.chevronStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = BiliColorsColors(palette).secondaryText,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// ▶ 3.7万  ☰ 337  2026年10月11日 21:05, then the viewers mark and 53人正在看. Only N人正在看 rebuilds when the count
/// changes; a line too long for the width shrinks a little rather than cut, as Swift's did.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.detail, required this.online});

  final VideoDetail detail;
  final ValueListenable<String?> online;

  @override
  Widget build(BuildContext context) {
    final text = _style(
      IntroTheme.metaText,
      BiliColors.colorsOf(context).secondaryText,
      line: IntroTheme.metaLine,
      spacing: IntroTheme.metaSpacing,
    );
    final strut = BiliFonts.strut(text);
    const icon = Size(IntroTheme.metaIconWidth, IntroTheme.metaIconHeight);
    return SizedBox(
      height: IntroTheme.metaLine,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const SizedBox(width: IntroTheme.metaLead),
            CustomPaint(
              size: icon,
              painter: CountPainter(CountGlyph.views, color: BiliColors.colorsOf(context).secondaryText),
            ),
            const SizedBox(width: IntroTheme.metaIconGap),
            Text(CountFormat.short(detail.stat.view), style: text, strutStyle: strut),
            const SizedBox(width: IntroTheme.metaGroupGap),
            CustomPaint(
              size: icon,
              painter: CountPainter(CountGlyph.danmaku, color: BiliColors.colorsOf(context).secondaryText),
            ),
            const SizedBox(width: IntroTheme.metaIconGap),
            Text(CountFormat.short(detail.stat.danmaku), style: text, strutStyle: strut),
            const SizedBox(width: IntroTheme.metaGroupGap),
            Text(TimeFormat.publish(detail.pubdate), style: text, strutStyle: strut),
            ValueListenableBuilder(
              valueListenable: online,
              builder: (context, count, _) {
                if (count == null || count.isEmpty) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: IntroTheme.metaGroupGap),
                    CustomPaint(
                      size: Size(IntroTheme.metaIconWidth, IntroTheme.onlineIconHeight),
                      painter: OnlinePainter(palette: BiliPalette.of(context)),
                    ),
                    const SizedBox(width: IntroTheme.metaIconGap),
                    Text('$count人正在看', style: text, strutStyle: strut),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The site's notice on the video, such as ⓘ 个人观点，仅供参考, collapsed and expanded alike.
class _NoticeLine extends StatelessWidget {
  const _NoticeLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = _style(
      IntroTheme.noticeText,
      BiliColors.colorsOf(context).secondaryText,
      line: IntroTheme.noticeLine,
      spacing: IntroTheme.proseSpacing,
    );
    return Padding(
      padding: const EdgeInsets.only(top: IntroTheme.noticeGap),
      child: SizedBox(
        height: IntroTheme.noticeLine - IntroTheme.noticeHang,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: IntroTheme.noticeLine,
          maxHeight: IntroTheme.noticeLine,
          child: Row(
            children: [
              const SizedBox(width: IntroTheme.metaLead),
              CustomPaint(size: Size.square(IntroTheme.noticeIcon), painter: _NoticePainter(palette: BiliPalette.of(context))),
              const SizedBox(width: IntroTheme.noticeIconGap),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                  strutStyle: BiliFonts.strut(style),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The notice's ⓘ: a ring with a round-ended bar and a dot inside, traced on font-check 03 at 12×.
class _NoticePainter extends CustomPainter {
  final BiliPalette palette;
  const _NoticePainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = IntroTheme.metaStroke
      ..strokeCap = StrokeCap.round
      ..color = BiliColorsColors(palette).secondaryText;
    canvas
      ..drawCircle(centre, (size.shortestSide - IntroTheme.metaStroke) / 2, line)
      ..drawLine(centre.translate(0, -2.63), centre.translate(0, 0.5), line)
      ..drawCircle(centre.translate(0, 2.43), 0.55, Paint()..color = BiliColorsColors(palette).secondaryText);
  }

  @override
  bool shouldRepaint(_NoticePainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// 03's N人正在看 mark: a head and shoulders like an Ω, and the edge of a second one behind it on the right.
class OnlinePainter extends CustomPainter {
  final BiliPalette palette;
  const OnlinePainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    // Traced on 03 at 10×, in points inside its 13.3 × 11.7 box.
    final sx = size.width / IntroTheme.metaIconWidth, sy = size.height / IntroTheme.onlineIconHeight;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = IntroTheme.metaStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = BiliColorsColors(palette).secondaryText;
    const start = 128 * math.pi / 180;
    const sweep = 284 * math.pi / 180;
    final head = Path()
      ..moveTo(p(0.6, 11.2).dx, p(0.6, 11.2).dy)
      ..lineTo(p(3.0, 8.6).dx, p(3.0, 8.6).dy)
      ..arcTo(Rect.fromCircle(center: p(4.83, 4.83), radius: 4.17 * sx), start, sweep, false)
      ..lineTo(p(6.67, 8.6).dx, p(6.67, 8.6).dy)
      ..lineTo(p(9.1, 11.2).dx, p(9.1, 11.2).dy);
    final behind = Path()
      ..moveTo(p(10.5, 2.4).dx, p(10.5, 2.4).dy)
      ..quadraticBezierTo(p(15.4, 5.9).dx, p(15.4, 5.9).dy, p(10.9, 8.6).dx, p(10.9, 8.6).dy)
      ..lineTo(p(12.9, 11.1).dx, p(12.9, 11.1).dy);
    canvas
      ..drawPath(head, line)
      ..drawPath(behind, line);
  }

  @override
  bool shouldRepaint(OnlinePainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

class _Details extends StatelessWidget {
  const _Details({
    required this.detail,
    required this.tags,
    required this.onSeek,
    required this.onOpenVideo,
    required this.openLink,
  });

  final VideoDetail detail;
  final List<VideoTag> tags;
  final ValueChanged<double> onSeek;
  final ValueChanged<String> onOpenVideo;
  final ValueChanged<Uri> openLink;

  @override
  Widget build(BuildContext context) {
    final meta = _style(IntroTheme.metaText, BiliColors.colorsOf(context).secondaryText, line: IntroTheme.metaLine);
    final runs = descriptionRuns(detail.descParts);
    final plain = [
      for (final tag in tags)
        if (tag.kind == VideoTagKind.normal) tag,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: IntroTheme.bvGap + (detail.argueMessage == null ? 0 : IntroTheme.noticeHang)),
        SizedBox(
          height: IntroTheme.metaLine,
          child: Row(
            children: [
              Text(detail.bvid, style: meta),
              if (detail.copyright == 1) ...[
                const SizedBox(width: IntroTheme.forbiddenGap),
                const CustomPaint(size: Size.square(IntroTheme.forbiddenIcon), painter: _ForbiddenPainter()),
                const SizedBox(width: IntroTheme.forbiddenTextGap),
                Flexible(
                  child: Text(
                    '未经作者授权禁止转载',
                    style: meta.copyWith(letterSpacing: IntroTheme.proseSpacing),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (runs.isNotEmpty) ...[
          const SizedBox(height: IntroTheme.descGap),
          DescriptionText(
            runs: runs,
            style: _style(
              IntroTheme.descText,
              BiliColors.colorsOf(context).secondaryText,
              line: IntroTheme.descLine,
              spacing: IntroTheme.proseSpacing,
            ),
            onSeek: onSeek,
            onOpenVideo: onOpenVideo,
            onOpenLink: openLink,
          ),
        ],
        if (plain.isNotEmpty) ...[
          const SizedBox(height: IntroTheme.tagsGap),
          Wrap(
            spacing: IntroTheme.tagSpacing,
            runSpacing: IntroTheme.tagSpacing,
            children: [for (final tag in plain) _PlainTag(name: tag.name)],
          ),
          const SizedBox(height: IntroTheme.tagsBottom),
        ],
      ],
    );
  }
}

/// A plain tag leads nowhere until there is a search page, so it is not a button (as in Swift).
class _PlainTag extends StatelessWidget {
  const _PlainTag({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final style = _style(
      IntroTheme.tagText,
      IntroTheme.colorsOf(context).tagInk,
      line: IntroTheme.tagHeight,
      spacing: IntroTheme.proseSpacing,
    );
    return Container(
      height: IntroTheme.tagHeight,
      padding: const EdgeInsets.symmetric(horizontal: IntroTheme.tagPadding),
      decoration: BoxDecoration(
        color: BiliColors.colorsOf(context).softGrey,
        borderRadius: BorderRadius.circular(IntroTheme.tagHeight / 2),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
          strutStyle: BiliFonts.strut(style),
        ),
      ),
    );
  }
}

/// ⊘ before 未经作者授权禁止转载 (18).
class _ForbiddenPainter extends CustomPainter {
  const _ForbiddenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = IntroTheme.metaStroke
      ..color = IntroTheme.forbidden;
    final radius = (size.shortestSide - IntroTheme.metaStroke) / 2;
    final centre = size.center(Offset.zero);
    final reach = Offset(radius, radius) * math.sqrt1_2;
    canvas
      ..drawCircle(centre, radius, line)
      ..drawLine(centre - reach, centre + reach, line);
  }

  @override
  bool shouldRepaint(_ForbiddenPainter oldDelegate) => false;
}
