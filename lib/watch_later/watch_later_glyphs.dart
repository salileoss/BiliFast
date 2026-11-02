import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../shared/theme.dart';

Paint _line(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color color) => Paint()..color = color;

/// The bar's ‹, drawn at its place in a box whose left edge is the screen's.
class WatchLaterBackPainter extends CustomPainter {
  const WatchLaterBackPainter({this.colors});

  final WatchLaterThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    canvas.drawPath(
      Path()
        ..moveTo(WatchLaterTheme.backEndX, middle - WatchLaterTheme.backHalfHeight)
        ..lineTo(WatchLaterTheme.backTipX, middle)
        ..lineTo(WatchLaterTheme.backEndX, middle + WatchLaterTheme.backHalfHeight),
      _line((colors?.grey ?? WatchLaterTheme.grey), WatchLaterTheme.backStroke),
    );
  }

  @override
  bool shouldRepaint(WatchLaterBackPainter oldDelegate) => oldDelegate.colors != colors;
}

/// ≡↑ before 最近添加 (86): a long bar over two short ones, and an arrow with only its right barb.
class SortGlyph extends StatelessWidget {
  const SortGlyph({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(WatchLaterTheme.sortGlyphWidth, WatchLaterTheme.sortGlyphHeight),
    painter: _SortPainter(color),
  );
}

class _SortPainter extends CustomPainter {
  const _SortPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _line(color, WatchLaterTheme.sortGlyphStroke);
    canvas
      ..drawLine(const Offset(0.5, 0.5), const Offset(11.9, 0.5), paint)
      ..drawLine(const Offset(0.5, 4.8), const Offset(7.5, 4.8), paint)
      ..drawLine(const Offset(0.5, 8.6), const Offset(7.5, 8.6), paint)
      ..drawLine(const Offset(9.75, 3.5), const Offset(9.75, 9.17), paint)
      ..drawLine(const Offset(9.75, 3.5), const Offset(12.17, 5.0), paint);
  }

  @override
  bool shouldRepaint(_SortPainter oldDelegate) => oldDelegate.color != color;
}

/// 播放全部's ▶, a triangle with rounded corners.
class PlayGlyph extends StatelessWidget {
  const PlayGlyph({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(WatchLaterTheme.playGlyphWidth, WatchLaterTheme.playGlyphHeight),
    painter: _PlayPainter(color),
  );
}

class _PlayPainter extends CustomPainter {
  const _PlayPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // A triangle inset by the corner's radius, filled and stroked twice as wide with round joins, has round corners.
    const r = WatchLaterTheme.playGlyphRound;
    final path = Path()
      ..moveTo(r, r)
      ..lineTo(size.width - r * 1.2, size.height / 2)
      ..lineTo(r, size.height - r)
      ..close();
    canvas
      ..drawPath(path, _fill(color))
      ..drawPath(path, _line(color, r * 2));
  }

  @override
  bool shouldRepaint(_PlayPainter oldDelegate) => oldDelegate.color != color;
}

/// A row's ⋮, centred in its touch box.
class WatchLaterMorePainter extends CustomPainter {
  const WatchLaterMorePainter({this.colors});

  final WatchLaterThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final paint = _fill((colors?.moreInk ?? WatchLaterTheme.moreInk));
    for (final step in const [-1, 0, 1]) {
      canvas.drawCircle(centre.translate(0, step * WatchLaterTheme.morePitch), WatchLaterTheme.moreDot / 2, paint);
    }
  }

  @override
  bool shouldRepaint(WatchLaterMorePainter oldDelegate) => oldDelegate.colors != colors;
}

/// The edit mode's circle: a grey ring, or pink with a white ✓ when [chosen].
class ChoiceCircle extends StatelessWidget {
  const ChoiceCircle({super.key, required this.chosen});

  final bool chosen;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(WatchLaterTheme.circleSize), painter: _CirclePainter(chosen, colors: WatchLaterTheme.colorsOf(context)));
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.chosen, {this.colors});

  final bool chosen;

  final WatchLaterThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    if (!chosen) {
      canvas.drawCircle(
        centre,
        radius - WatchLaterTheme.circleStroke / 2,
        _line((colors?.circleInk ?? WatchLaterTheme.circleInk), WatchLaterTheme.circleStroke),
      );
      return;
    }
    canvas
      ..drawCircle(centre, radius, _fill((colors?.circleChosen ?? WatchLaterTheme.circleChosen)))
      ..drawPath(
        Path()
          ..moveTo(centre.dx - 5.6, centre.dy + 0.75)
          ..lineTo(centre.dx - 2.0, centre.dy + 3.66)
          ..lineTo(centre.dx + 5.83, centre.dy - 3.6),
        _line(WatchLaterTheme.checkInk, WatchLaterTheme.checkStroke),
      );
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) => oldDelegate.colors != colors || oldDelegate.chosen != chosen;
}

/// The sheets' row glyphs (93, 94), drawn about the middle of a 20 pt box.
enum SheetGlyph { clear, list, trash }

class SheetGlyphView extends StatelessWidget {
  const SheetGlyphView(this.glyph, {super.key});

  final SheetGlyph glyph;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(WatchLaterTheme.actionGlyphSize), painter: _SheetGlyphPainter(glyph, colors: WatchLaterTheme.colorsOf(context)));
}

class _SheetGlyphPainter extends CustomPainter {
  const _SheetGlyphPainter(this.glyph, {this.colors});

  final SheetGlyph glyph;

  final WatchLaterThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _line((colors?.ink ?? WatchLaterTheme.ink), WatchLaterTheme.actionGlyphStroke);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    switch (glyph) {
      case SheetGlyph.clear:
        canvas
          ..drawPath(
            Path()
              ..moveTo(-7.2, 0.35)
              ..lineTo(-7.2, -1.44)
              ..arcToPoint(const Offset(-5.6, -3.04), radius: const Radius.circular(1.6))
              ..lineTo(-2.97, -3.04)
              ..lineTo(-2.97, -4.54)
              ..arcToPoint(const Offset(2.97, -4.54), radius: const Radius.circular(2.97))
              ..lineTo(2.97, -3.04)
              ..lineTo(5.6, -3.04)
              ..arcToPoint(const Offset(7.2, -1.44), radius: const Radius.circular(1.6))
              ..lineTo(7.2, 0.35)
              ..close(),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(-6.5, 0.35)
              ..lineTo(-6.5, 5.74)
              ..arcToPoint(const Offset(-4.7, 7.54), radius: const Radius.circular(1.8), clockwise: false)
              ..lineTo(4.7, 7.54)
              ..arcToPoint(const Offset(6.5, 5.74), radius: const Radius.circular(1.8), clockwise: false)
              ..lineTo(6.5, 0.35),
            paint,
          )
          ..drawLine(const Offset(-2.1, 4.7), const Offset(-2.1, 7.54), paint)
          ..drawLine(const Offset(2.1, 4.0), const Offset(2.1, 7.54), paint);
      case SheetGlyph.list:
        final bars = _line((colors?.ink ?? WatchLaterTheme.ink), 1.15);
        for (final y in const [-5.04, 0.17, 5.38]) {
          canvas.drawLine(Offset(-1.58, y), Offset(7.38, y), bars);
        }
        for (final y in const [-5.45, 4.96]) {
          canvas.drawPath(
            Path()
              ..moveTo(-7.41, y)
              ..lineTo(-5.95, y + 1.46)
              ..lineTo(-3.66, y - 0.83),
            paint,
          );
        }
        canvas.drawCircle(const Offset(-5.54, 0.17), 1.4, paint);
      case SheetGlyph.trash:
        canvas
          ..drawLine(const Offset(-7.83, -4.8), const Offset(7.8, -4.8), paint)
          ..drawPath(
            Path()
              ..moveTo(-3.25, -4.8)
              ..lineTo(-3.25, -5.5)
              ..arcToPoint(const Offset(-1.25, -7.5), radius: const Radius.circular(2))
              ..lineTo(1.0, -7.5)
              ..arcToPoint(const Offset(3.0, -5.5), radius: const Radius.circular(2))
              ..lineTo(3.0, -4.8),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(-6.1, -2.3)
              ..lineTo(-6.1, 4.58)
              ..arcToPoint(const Offset(-3.6, 7.08), radius: const Radius.circular(2.5), clockwise: false)
              ..lineTo(3.6, 7.08)
              ..arcToPoint(const Offset(6.1, 4.58), radius: const Radius.circular(2.5), clockwise: false)
              ..lineTo(6.1, -2.3),
            paint,
          )
          ..drawLine(const Offset(-2.13, -0.6), const Offset(-2.13, 2.3), paint)
          ..drawLine(const Offset(2.07, -0.6), const Offset(2.07, 2.3), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheetGlyphPainter oldDelegate) => oldDelegate.colors != colors || oldDelegate.glyph != glyph;
}

/// 选择收藏夹's 📁 with a star at its tab (97).
class FolderStarGlyph extends StatelessWidget {
  const FolderStarGlyph({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(
    size: Size(WatchLaterTheme.folderIconWidth, WatchLaterTheme.folderIconHeight),
    painter: _FolderPainter(),
  );
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _fill(WatchLaterTheme.folderIconInk);
    const r = 2.0;
    canvas.drawPath(
      Path()
        ..moveTo(0, 2.25 + r)
        ..arcToPoint(const Offset(r, 2.25), radius: const Radius.circular(r))
        ..lineTo(5.29, 2.25)
        ..lineTo(9.25, 7.12)
        ..lineTo(15.29, 7.12)
        ..lineTo(15.29, 14.75 - r)
        ..arcToPoint(const Offset(15.29 - r, 14.75), radius: const Radius.circular(r))
        ..lineTo(r, 14.75)
        ..arcToPoint(const Offset(0, 14.75 - r), radius: const Radius.circular(r))
        ..close(),
      paint,
    );
    const centre = Offset(11.67, 3.5);
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? 3.1 : 1.45;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas
      ..drawPath(star, paint)
      ..drawPath(star, _line(WatchLaterTheme.folderIconInk, 0.8));
  }

  @override
  bool shouldRepaint(_FolderPainter oldDelegate) => false;
}

/// + before 新建收藏夹.
class PlusGlyph extends StatelessWidget {
  const PlusGlyph({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(WatchLaterTheme.plusSize), painter: _PlusPainter(colors: WatchLaterTheme.colorsOf(context)));
}

class _PlusPainter extends CustomPainter {
  const _PlusPainter({this.colors});

  final WatchLaterThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = WatchLaterTheme.plusStroke / 2;
    final paint = _line((colors?.ink ?? WatchLaterTheme.ink), WatchLaterTheme.plusStroke)..strokeCap = StrokeCap.butt;
    canvas
      ..drawLine(Offset(size.width / 2, inset), Offset(size.width / 2, size.height - inset), paint)
      ..drawLine(Offset(inset, size.height / 2), Offset(size.width - inset, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter oldDelegate) => oldDelegate.colors != colors;
}

/// 85's grey TV: a box tipped back 11.3°, its ledge sticking out at the bottom with a slot in it, the base under it,
/// and two strokes off its top right corner. Drawn in a 120 × 100 box whose top left is (160, 426) on 85.
class EmptyTvArt extends StatelessWidget {
  const EmptyTvArt({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(WatchLaterTheme.emptyArtWidth, WatchLaterTheme.emptyArtHeight),
    painter: _EmptyTvPainter(colors: WatchLaterTheme.colorsOf(context)),
  );
}

class _EmptyTvPainter extends CustomPainter {
  const _EmptyTvPainter({this.colors});

  final WatchLaterThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _fill((colors?.artBody ?? WatchLaterTheme.artBody));
    final shadeColor = colors?.artShade ?? WatchLaterTheme.artShade;
    final shade = _fill(shadeColor);
    // On 85 the box's top left is (160, 426); everything below is in 85's points less that.
    canvas
      ..save()
      ..translate(-160, -426)
      ..drawRRect(RRect.fromLTRBR(190.5, 488, 260.3, 525.7, const Radius.circular(10)), shade)
      ..drawRRect(RRect.fromLTRBR(200, 517, 280.3, 525.7, const Radius.circular(4.35)), shade)
      ..drawPath(_strokes, shade)
      ..drawPath(_strokes, _line(shadeColor, 0.6))
      ..translate(162.4, 449.9)
      ..rotate(-11.3 * math.pi / 180)
      ..drawRRect(RRect.fromLTRBR(0, 0, 97.7, 56, const Radius.circular(6)), body)
      ..drawRRect(RRect.fromLTRBR(-4.2, 52, 101.2, 73, const Radius.circular(3.5)), body)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(49, 60.3), width: 28, height: 5),
          const Radius.circular(2.5),
        ),
        shade,
      )
      ..restore();
  }

  static final _strokes = Path()
    ..addPolygon(const [Offset(263.8, 436.8), Offset(271.9, 427.5), Offset(276.3, 432.3)], true)
    ..addPolygon(const [Offset(266.9, 440.0), Offset(278.1, 437.6), Offset(278.8, 443.3), Offset(266.9, 442.8)], true);

  @override
  bool shouldRepaint(_EmptyTvPainter oldDelegate) => oldDelegate.colors != colors;
}
