import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../shared/theme.dart';

/// 我的收藏's line glyphs, traced on 80-83 and 99.
enum FavGlyph {
  search,
  plus,

  /// The folders' layout toggle: two stacked boxes (80).
  layout,

  /// The toggle in the list layout (99): two rows of a box and two bars.
  layoutList,

  /// Multi-select: ✓, ○, ✓ before three bars (81, 83).
  select,
  chevron,
  lock,
  more,

  /// 播放's filled ▶ with rounded corners (99).
  play,

  /// 收藏 under a folder's title: a filled folder with a white + (81).
  folderAdd,

  /// 取消收藏's star, struck through (82).
  starOff,
}

/// [glyph] drawn to fill a [width] × [height] ink box in [color], its lines [stroke] thick.
class FavGlyphIcon extends StatelessWidget {
  const FavGlyphIcon(
    this.glyph, {
    super.key,
    required this.width,
    required this.height,
    required this.color,
    this.stroke = FavouritesTheme.toolStroke,
  });

  final FavGlyph glyph;
  final double width;
  final double height;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: FavGlyphPainter(glyph, color: color, stroke: stroke),
      ),
    ),
  );
}

class FavGlyphPainter extends CustomPainter {
  const FavGlyphPainter(this.glyph, {required this.color, required this.stroke});

  final FavGlyph glyph;
  final Color color;
  final double stroke;

  Paint get _line => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()..color = color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (glyph) {
      case FavGlyph.search:
        _search(canvas, size);
      case FavGlyph.plus:
        _plus(canvas, size);
      case FavGlyph.layout:
        _layout(canvas, size);
      case FavGlyph.layoutList:
        _layoutList(canvas, size);
      case FavGlyph.play:
        _play(canvas, size);
      case FavGlyph.select:
        _select(canvas, size);
      case FavGlyph.chevron:
        _chevron(canvas, size);
      case FavGlyph.lock:
        _lock(canvas, size);
      case FavGlyph.more:
        _more(canvas, size);
      case FavGlyph.folderAdd:
        _folderAdd(canvas, size);
      case FavGlyph.starOff:
        _starOff(canvas, size);
    }
  }

  /// The ring takes 0.88 of the width; the handle runs from it at 45° to the bottom right corner.
  void _search(Canvas canvas, Size size) {
    final half = stroke / 2;
    final radius = (size.width * 0.88 - stroke) / 2;
    final centre = Offset(half + radius, half + radius);
    canvas.drawCircle(centre, radius, _line);
    final edge = centre + Offset(radius * math.sqrt1_2, radius * math.sqrt1_2);
    canvas.drawLine(edge, Offset(size.width - half * 0.8, size.height - half * 0.8), _line);
  }

  void _plus(Canvas canvas, Size size) {
    final half = stroke / 2;
    final centre = size.center(Offset.zero);
    canvas
      ..drawLine(Offset(half, centre.dy), Offset(size.width - half, centre.dy), _line)
      ..drawLine(Offset(centre.dx, half), Offset(centre.dx, size.height - half), _line);
  }

  /// Two boxes 1.9 apart with a 2.3 corner.
  void _layout(Canvas canvas, Size size) {
    const gap = 1.9;
    final half = stroke / 2;
    final boxHeight = (size.height - gap) / 2;
    for (final top in [0.0, boxHeight + gap]) {
      final box = Rect.fromLTWH(half, top + half, size.width - stroke, boxHeight - stroke);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(2.3)), _line);
    }
  }

  /// Each half of the height a box over the left 0.44 with a 2.3 corner, and two bars from the middle: the upper to
  /// the edge, the lower to 0.875, at 0.32 and 0.68 of the half.
  void _layoutList(Canvas canvas, Size size) {
    const gap = 2 / 3;
    final half = stroke / 2;
    final rowHeight = (size.height - gap) / 2;
    final boxWidth = size.width * 0.4375;
    final barLeft = size.width / 2 + half;
    for (final top in [0.0, rowHeight + gap]) {
      final box = Rect.fromLTWH(half, top + half, boxWidth - stroke, rowHeight - stroke);
      canvas
        ..drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(2.3)), _line)
        ..drawLine(Offset(barLeft, top + rowHeight * 0.32), Offset(size.width - half, top + rowHeight * 0.32), _line)
        ..drawLine(
          Offset(barLeft, top + rowHeight * 0.68),
          Offset(size.width * 0.875 - half, top + rowHeight * 0.68),
          _line,
        );
    }
  }

  /// Filled, its corners rounded by stroking the inset outline with round joins.
  void _play(Canvas canvas, Size size) {
    final round = size.width * 0.13;
    final triangle = Path()
      ..moveTo(round, round)
      ..lineTo(size.width - round, size.height / 2)
      ..lineTo(round, size.height - round)
      ..close();
    canvas
      ..drawPath(triangle, _fill)
      ..drawPath(
        triangle,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = round * 2
          ..strokeJoin = StrokeJoin.round,
      );
  }

  /// Marks in the left 0.29 of the width, bars from 0.39; rows at the top, middle and bottom line.
  void _select(Canvas canvas, Size size) {
    final half = stroke / 2;
    final markWidth = size.width * 0.29;
    final barLeft = size.width * 0.39;
    final rows = [size.height * 0.16, size.height / 2, size.height * 0.84];
    for (final (index, y) in rows.indexed) {
      canvas.drawLine(Offset(barLeft + half, y), Offset(size.width - half, y), _line);
      if (index == 1) {
        canvas.drawCircle(Offset(markWidth / 2, y), markWidth / 2 - half * 0.9, _line);
      } else {
        final tick = Path()
          ..moveTo(half, y - markWidth * 0.12)
          ..lineTo(markWidth * 0.4, y + markWidth * 0.28)
          ..lineTo(markWidth - half, y - markWidth * 0.36);
        canvas.drawPath(tick, _line);
      }
    }
  }

  void _chevron(Canvas canvas, Size size) {
    final half = stroke / 2;
    canvas.drawPath(
      Path()
        ..moveTo(half, half)
        ..lineTo(size.width - half, size.height / 2)
        ..lineTo(half, size.height - half),
      _line,
    );
  }

  /// The body is the lower 0.62, the shackle 0.72 of the width over it, a short keyhole in the middle.
  void _lock(Canvas canvas, Size size) {
    final half = stroke / 2;
    final bodyTop = size.height * 0.38;
    final body = Rect.fromLTRB(half, bodyTop, size.width - half, size.height - half);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(2.3)), _line);
    final shackleHalf = size.width * 0.36 - half;
    final centreX = size.width / 2;
    final shackle = Path()
      ..moveTo(centreX - shackleHalf, bodyTop)
      ..lineTo(centreX - shackleHalf, half + shackleHalf)
      ..arcToPoint(Offset(centreX + shackleHalf, half + shackleHalf), radius: Radius.circular(shackleHalf))
      ..lineTo(centreX + shackleHalf, bodyTop);
    canvas
      ..drawPath(shackle, _line)
      ..drawLine(
        Offset(centreX, bodyTop + (size.height - bodyTop) * 0.36),
        Offset(centreX, bodyTop + (size.height - bodyTop) * 0.6),
        _line,
      );
  }

  /// Three dots as wide as the box, spread over its height.
  void _more(Canvas canvas, Size size) {
    final radius = size.width / 2;
    for (final y in [radius, size.height / 2, size.height - radius]) {
      canvas.drawCircle(Offset(size.width / 2, y), radius, _fill);
    }
  }

  /// A folder whose tab rises on the left, the edge of the sheet behind it on the right, and a white + in the body.
  void _folderAdd(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final step = h * 0.17;
    final tabEnd = w * 0.46;
    const corner = 2.6;
    final folder = Path()
      ..moveTo(0, corner)
      ..quadraticBezierTo(0, 0, corner, 0)
      ..lineTo(tabEnd - step * 0.6, 0)
      ..quadraticBezierTo(tabEnd - step * 0.2, 0, tabEnd, step * 0.5)
      ..lineTo(tabEnd + step * 0.4, step)
      ..lineTo(w - corner, step)
      ..quadraticBezierTo(w, step, w, step + corner)
      ..lineTo(w, h - corner)
      ..quadraticBezierTo(w, h, w - corner, h)
      ..lineTo(corner, h)
      ..quadraticBezierTo(0, h, 0, h - corner)
      ..close();
    canvas.drawPath(folder, _fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.6, 0, w * 0.91, h * 0.08), Radius.circular(h * 0.04)),
      _fill,
    );
    final plus = Paint()
      ..color = BiliColors.onPink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final centre = Offset(w * 0.5, h * 0.6);
    final arm = h * 0.2;
    canvas
      ..drawLine(centre.translate(-arm, 0), centre.translate(arm, 0), plus)
      ..drawLine(centre.translate(0, -arm), centre.translate(0, arm), plus);
  }

  /// A soft five-pointed star, the stroke from the bottom left to the top right over it; the outline stops a gap
  /// short of the stroke on its lower right side.
  void _starOff(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final half = stroke / 2;
    final centre = Offset(w * 0.53, h * 0.55);
    final outer = h * 0.55;
    final inner = outer * 0.5;
    final points = [
      for (var i = 0; i < 10; i++)
        centre + Offset.fromDirection(-math.pi / 2 + i * math.pi / 5, i.isEven ? outer : inner).scale(1, 0.97),
    ];
    final star = Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final before = points[(i - 1 + points.length) % points.length];
      final after = points[(i + 1) % points.length];
      final soften = i.isEven ? 0.2 : 0.12;
      final enter = Offset.lerp(point, before, soften)!;
      final leave = Offset.lerp(point, after, soften)!;
      if (i == 0) {
        star.moveTo(enter.dx, enter.dy);
      } else {
        star.lineTo(enter.dx, enter.dy);
      }
      star.quadraticBezierTo(point.dx, point.dy, leave.dx, leave.dy);
    }
    star.close();
    final from = Offset(half, h - half);
    final to = Offset(w * 0.79, h * 0.06 + half);
    final along = (to - from) / (to - from).distance;
    final across = Offset(-along.dy, along.dx);
    final gap = stroke * 2.3;
    final reach = w + h;
    final cut = Path()
      ..addPolygon([
        from - along * reach,
        to + along * reach,
        to + along * reach + across * gap,
        from - along * reach + across * gap,
      ], true);
    canvas
      ..save()
      ..clipPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), cut))
      ..drawPath(star, _line)
      ..restore()
      ..drawLine(from, to, _line);
  }

  @override
  bool shouldRepaint(FavGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color || oldDelegate.stroke != stroke;
}
