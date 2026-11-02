import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../comments/comment_badges.dart' show SegmentGlyph;
import '../../shared/theme.dart';

/// 👕 at the banner's foot (108), traced in a 52 × 46 grid of the 3× screenshot: collar, sleeves and body in one line.
class OwnSkinGlyph extends StatelessWidget {
  const OwnSkinGlyph({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(OwnSpaceTheme.skinWidth, OwnSpaceTheme.skinHeight),
      painter: _SkinPainter(color),
    ),
  );
}

class _SkinPainter extends CustomPainter {
  const _SkinPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 52, y = size.height / 46;
    final path = Path()..moveTo(11 * x, 20.5 * y);
    void line(double gx, double gy) => path.lineTo(gx * x, gy * y);
    void curve(double cx, double cy, double gx, double gy) => path.quadraticBezierTo(cx * x, cy * y, gx * x, gy * y);
    line(2.2, 17);
    line(11, 2.2);
    line(17, 2.2);
    curve(21, 11, 26, 11);
    curve(31, 11, 35, 2.2);
    line(41, 2.2);
    line(49.8, 17);
    line(41, 20.5);
    line(41, 40.5);
    curve(41, 43.8, 37.7, 43.8);
    line(14.3, 43.8);
    curve(11, 43.8, 11, 40.5);
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = OwnSpaceTheme.skinStroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SkinPainter oldDelegate) => oldDelegate.color != color;
}

/// The banner label's number ("NO.000067", 108) in the block letters of 评论's fan card, ending at the box's right.
class OwnLabelNumber extends StatelessWidget {
  const OwnLabelNumber({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  /// Whether every character of [text] has a block letter; anything else is set as type.
  static bool draws(String text) => text.isNotEmpty && text.split('').every(_blocks.contains);

  static const _blocks = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'N', 'O', 'C', 'L', '.'};

  static double widthOf(String text) {
    var width = 0.0;
    for (final character in text.split('')) {
      width += SegmentGlyph.advance(
        character,
        width: OwnSpaceTheme.labelNumberWidth,
        weight: OwnSpaceTheme.labelNumberWeight,
        gap: OwnSpaceTheme.labelNumberGap,
      );
    }
    return text.isEmpty ? 0 : width - OwnSpaceTheme.labelNumberGap;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    child: CustomPaint(
      size: Size(widthOf(text), OwnSpaceTheme.labelNumberHeight),
      painter: _NumberPainter(text, color),
    ),
  );
}

class _NumberPainter extends CustomPainter {
  const _NumberPainter(this.text, this.color);

  final String text;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = color;
    var left = 0.0;
    for (final character in text.split('')) {
      final width = SegmentGlyph.glyphWidth(
        character,
        width: OwnSpaceTheme.labelNumberWidth,
        weight: OwnSpaceTheme.labelNumberWeight,
      );
      SegmentGlyph.draw(
        canvas,
        character,
        Rect.fromLTWH(left, 0, width, size.height),
        OwnSpaceTheme.labelNumberWeight,
        ink,
      );
      left += width + OwnSpaceTheme.labelNumberGap;
    }
  }

  @override
  bool shouldRepaint(_NumberPainter oldDelegate) => oldDelegate.text != text || oldDelegate.color != color;
}

/// The 勋章 pills' rim: a stadium of dashes drawn inside its box.
class OwnDashedPillPainter extends CustomPainter {
  final BiliPalette palette;

  const OwnDashedPillPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = OwnSpaceTheme.pillBorder / 2;
    final box = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    final outline = Path()..addRRect(RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)));
    final paint = Paint()
      ..color = OwnSpaceThemeColors(palette).pillRim
      ..style = PaintingStyle.stroke
      ..strokeWidth = OwnSpaceTheme.pillBorder;
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += OwnSpaceTheme.pillDash + OwnSpaceTheme.pillDashGap) {
        canvas.drawPath(metric.extractPath(at, at + OwnSpaceTheme.pillDash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(OwnDashedPillPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
