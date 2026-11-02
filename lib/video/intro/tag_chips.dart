import 'dart:math' as math;

import 'package:bili_core/api.dart' show VideoTag, VideoTagKind;
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import 'collection_row.dart' show Chevron;

/// The topic and BGM chips in a sideways row (03); plain tags are the title block's. There are no topic or music
/// pages yet, so they lead nowhere and aren't buttons. Only the first name too long for its chip scrolls; a later one
/// ends in …, as 03's topic does after its scrolling BGM.
class TagChips extends StatelessWidget {
  const TagChips({super.key, required this.tags});

  final List<VideoTag> tags;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final tag in tags)
        if (tag.kind != VideoTagKind.normal) tag,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: IntroListTheme.sectionTop, bottom: IntroListTheme.sectionBottom),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1,
        child: SizedBox(
          height: IntroListTheme.chipHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final row = constraints.maxWidth - BiliMetrics.gutter * 2;
              // A fourth chip onwards keeps 03's width and the row scrolls, rather than squeezing every name.
              final sharing = math.min(shown.length, 3);
              final widest = math.min(row / 2, (row - IntroListTheme.chipGap * (sharing - 1)) / sharing);
              final rooms = [for (final tag in shown) math.max(0.0, widest - _chrome(tag.kind))];
              final scaler = MediaQuery.textScalerOf(context);
              var scrolling = -1;
              for (var index = 0; index < shown.length && scrolling < 0; index++) {
                if (_shownWidth(context, shown[index].name, scaler) > rooms[index]) scrolling = index;
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.gutter),
                itemCount: shown.length,
                separatorBuilder: (context, index) => const SizedBox(width: IntroListTheme.chipGap),
                itemBuilder: (context, index) => _Chip(shown[index], room: rooms[index], scrolls: index == scrolling),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A chip's width less its name's.
double _chrome(VideoTagKind kind) =>
    IntroListTheme.chipLead +
    (kind == VideoTagKind.bgm ? IntroListTheme.musicGlyphWidth : IntroListTheme.topicGlyphWidth) +
    IntroListTheme.chipIconGap +
    IntroListTheme.chipChevronGap +
    IntroListTheme.chipChevronWidth +
    IntroListTheme.chipTrailing;

double _nameWidth(BuildContext context, String text, TextScaler scaler) {
  final style = ChipName.style(context);
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    strutStyle: BiliFonts.strut(style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Full-width closing punctuation whose ink sits in the left half of its em.
const _closing = '》〉」』】〕〗〙〛）］｝、。，．';

/// The official chip ends a name on the ink of its last closing mark: font-check 02's › is 4.4 after 》, closer than
/// 03's is after 子. So that mark's blank half em stays out of the chip.
double _trailingTrim(String text, TextScaler scaler) =>
    text.isNotEmpty && _closing.contains(text[text.length - 1]) ? scaler.scale(IntroListTheme.chipText) / 2 : 0;

double _shownWidth(BuildContext context, String text, TextScaler scaler) => _nameWidth(context, text, scaler) - _trailingTrim(text, scaler);

class _Chip extends StatelessWidget {
  const _Chip(this.tag, {required this.room, required this.scrolls});

  final VideoTag tag;
  final double room;
  final bool scrolls;

  @override
  Widget build(BuildContext context) => Semantics(
    label: tag.name,
    excludeSemantics: true,
    child: Container(
      height: IntroListTheme.chipHeight,
      padding: const EdgeInsets.only(left: IntroListTheme.chipLead, right: IntroListTheme.chipTrailing),
      decoration: BoxDecoration(
        color: BiliColors.colorsOf(context).softGrey,
        borderRadius: BorderRadius.circular(IntroListTheme.chipHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.kind == VideoTagKind.bgm)
            CustomPaint(
              size: Size(IntroListTheme.musicGlyphWidth, IntroListTheme.musicGlyphHeight),
              painter: _MusicPainter(palette: BiliPalette.of(context)),
            )
          else
            CustomPaint(
              size: Size(IntroListTheme.topicGlyphWidth, IntroListTheme.topicGlyphHeight),
              painter: _TopicPainter(palette: BiliPalette.of(context)),
            ),
          const SizedBox(width: IntroListTheme.chipIconGap),
          ChipName(tag.name, room: room, scrolls: scrolls),
          const SizedBox(width: IntroListTheme.chipChevronGap),
          Chevron(
            size: Size(IntroListTheme.chipChevronWidth, IntroListTheme.chipChevronHeight),
            stroke: IntroListTheme.chipChevronStroke,
            color: IntroListTheme.colorsOf(context).chipGlyphColor,
          ),
        ],
      ),
    ),
  );
}

/// A chip's name. One wider than [room] ends in …, or, when it [scrolls], fades out at the right edge and, after a
/// rest, scrolls round once so the whole of it has been seen, as 18's does; with reduced motion it only fades.
class ChipName extends StatefulWidget {
  const ChipName(this.text, {super.key, required this.room, this.scrolls = true});

  final String text;
  final double room;
  final bool scrolls;

  /// The style a name is drawn and measured in. It names the fallback itself because a [TextPainter] inherits
  /// nothing from the page, and a name measured in another font than it is drawn in can ellipsise or scroll wrongly.
  static TextStyle style([BuildContext? context]) => TextStyle(
    fontFamily: BiliFonts.family,
    fontFamilyFallback: BiliFonts.fallback,
    fontSize: IntroListTheme.chipText,
    color: context == null ? IntroListTheme.chipTextColor : IntroListTheme.colorsOf(context).chipTextColor,
    height: 1,
  );

  @override
  State<ChipName> createState() => _ChipNameState();
}

class _ChipNameState extends State<ChipName> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this);
  double? _started;

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  /// Runs once per text width: the rest, then one lap of the name and the gap behind it.
  void _schedule(double width, bool still) {
    if (still) {
      _run.stop();
      return;
    }
    if (_started == width) return;
    _started = width;
    final travel = width + IntroListTheme.marqueeGap;
    _run
      ..duration =
          IntroListTheme.marqueeRest + Duration(milliseconds: (travel / IntroListTheme.marqueeSpeed * 1000).round())
      ..value = 0;
    _run.forward().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final width = _nameWidth(context, widget.text, scaler);
    final style = ChipName.style(context);
    final strut = BiliFonts.strut(style);
    final text = Text(widget.text, maxLines: 1, softWrap: false, style: style, strutStyle: strut);
    final shown = width - _trailingTrim(widget.text, scaler);
    if (shown <= widget.room) {
      if (shown == width) return text;
      return SizedBox(
        width: shown,
        child: Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: style,
          strutStyle: strut,
        ),
      );
    }
    if (!widget.scrolls) {
      return SizedBox(
        width: widget.room,
        child: Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: style,
          strutStyle: strut,
        ),
      );
    }
    final still = MediaQuery.disableAnimationsOf(context);
    if (still ? _run.isAnimating : _started != width) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedule(width, still);
      });
    }
    final travel = width + IntroListTheme.marqueeGap;
    return SizedBox(
      width: widget.room,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _run,
          builder: (context, child) {
            final total = _run.duration?.inMicroseconds;
            final rest = total == null ? 1.0 : IntroListTheme.marqueeRest.inMicroseconds / total;
            final t = still || _run.value <= rest ? 0.0 : (_run.value - rest) / (1 - rest);
            final offset = Curves.easeInOut.transform(t) * travel;
            final moving = offset > 0 && offset < travel;
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  moving ? const Color(0x00000000) : const Color(0xFF000000),
                  const Color(0xFF000000),
                  const Color(0xFF000000),
                  const Color(0x00000000),
                ],
                stops: [0, IntroListTheme.chipFade / bounds.width, 1 - IntroListTheme.chipFade / bounds.width, 1],
              ).createShader(bounds),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Transform.translate(offset: Offset(-offset, 0), child: child),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              text,
              const SizedBox(width: IntroListTheme.marqueeGap),
              text,
            ],
          ),
        ),
      ),
    );
  }
}

/// Two beamed quavers, drawn from 03 at 3 px per point.
class _MusicPainter extends CustomPainter {
  final BiliPalette palette;
  const _MusicPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = IntroListThemeColors(palette).chipGlyphColor;
    const head = 1.94;
    canvas
      ..drawCircle(const Offset(1.95, 10.84), head, paint)
      ..drawCircle(const Offset(10.0, 9.17), head, paint)
      ..drawRect(const Rect.fromLTRB(2.77, 1.6, 4.02, 10.84), paint)
      ..drawRect(const Rect.fromLTRB(10.82, 0.7, 11.97, 9.17), paint)
      ..drawPath(
        Path()
          ..moveTo(2.77, 1.9)
          ..quadraticBezierTo(2.77, 1.12, 3.6, 1.04)
          ..lineTo(11.4, 0.14)
          ..quadraticBezierTo(11.97, 0.1, 11.97, 0.7)
          ..lineTo(11.97, 2.5)
          ..lineTo(2.77, 3.47)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(_MusicPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// Bilibili's topic mark: a # on a little television with its two antennae, drawn from 03 at 3 px per point.
class _TopicPainter extends CustomPainter {
  final BiliPalette palette;
  const _TopicPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = IntroListTheme.topicGlyphStroke;
    final paint = Paint()
      ..color = IntroListThemeColors(palette).chipGlyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(
          stroke / 2,
          2.08 + stroke / 2,
          size.width - stroke / 2,
          size.height - stroke / 2,
          const Radius.circular(2.25),
        ),
        paint,
      )
      ..drawLine(const Offset(3.89, 0.55), const Offset(5.28, 2.08), paint)
      ..drawLine(const Offset(9.17, 0.55), const Offset(7.78, 2.08), paint)
      ..drawLine(const Offset(5.42, 4.6), const Offset(4.85, 10.2), paint)
      ..drawLine(const Offset(7.92, 4.6), const Offset(7.35, 10.2), paint)
      ..drawLine(const Offset(3.4, 5.97), const Offset(9.7, 5.97), paint)
      ..drawLine(const Offset(3.3, 8.61), const Offset(9.6, 8.61), paint);
  }

  @override
  bool shouldRepaint(_TopicPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
