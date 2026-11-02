import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../comments/comment_badges.dart' show SegmentGlyph;
import '../shared/theme.dart';

/// 我的's top row (87): 投屏, 扫一扫, 装扮 and 夜间模式.
enum MeTopGlyph { cast, scan, outfit, night }

/// 更多服务's rows (106): 联系客服, 听视频 and 设置.
enum MeServiceGlyph { support, listen, settings }

Paint _stroke(double width, Color color) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

/// The top row's line icons, traced on 87 at 16× in a box [MeTheme.topGlyphBox] square, its ink centred.
class MeTopGlyphPainter extends CustomPainter {
  final BiliPalette palette;

  const MeTopGlyphPainter(this.glyph, {this.color = MeTheme.topGlyph, this.palette = const BiliPalette(Brightness.light)});

  final MeTopGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(MeTheme.topGlyphStroke, color);
    // Each was traced around its own ink's middle; this puts that middle at the box's.
    final (Offset middle, Path path) = switch (glyph) {
      MeTopGlyph.cast => (const Offset(12.33, 11.5), _cast()),
      MeTopGlyph.scan => (const Offset(12, 12), _scan()),
      MeTopGlyph.outfit => (const Offset(12.9, 11.9), _outfit()),
      MeTopGlyph.night => (const Offset(12.4, 11.7), _night()),
    };
    canvas
      ..translate(size.width / 2 - middle.dx, size.height / 2 - middle.dy)
      ..drawPath(path, paint);
    if (glyph == MeTopGlyph.cast) {
      canvas.drawCircle(const Offset(20.9, 19.0), MeTheme.castDot, Paint()..color = color);
    }
  }

  /// A TV whose right side and bottom stop short of the corner the cast waves come out of.
  static Path _cast() {
    const left = 3.65, top = 6.05, right = 20.5, bottom = 19.7;
    const r = Radius.circular(3);
    return Path()
      ..moveTo(right, 9.8)
      ..lineTo(right, top + 3)
      ..arcToPoint(const Offset(right - 3, top), radius: r, clockwise: false)
      ..lineTo(left + 3, top)
      ..arcToPoint(const Offset(left, top + 3), radius: r, clockwise: false)
      ..lineTo(left, bottom - 3)
      ..arcToPoint(const Offset(left + 3, bottom), radius: r, clockwise: false)
      ..lineTo(11.6, bottom)
      ..moveTo(7.9, 3.1)
      ..lineTo(9.1, top)
      ..moveTo(16.15, 3.1)
      ..lineTo(14.6, top)
      ..moveTo(14.6, bottom)
      ..arcToPoint(const Offset(21.5, 12.8), radius: const Radius.circular(6.9))
      ..moveTo(17.6, bottom)
      ..arcToPoint(const Offset(21.5, 15.8), radius: const Radius.circular(3.9));
  }

  /// Four corner brackets and the line across the middle.
  static Path _scan() {
    const near = 4.0, far = 20.0, armEnd = 8.6, armStart = 15.4;
    const r = Radius.circular(2.5);
    return Path()
      ..moveTo(near, armEnd)
      ..lineTo(near, near + 2.5)
      ..arcToPoint(const Offset(near + 2.5, near), radius: r)
      ..lineTo(armEnd, near)
      ..moveTo(armStart, near)
      ..lineTo(far - 2.5, near)
      ..arcToPoint(const Offset(far, near + 2.5), radius: r)
      ..lineTo(far, armEnd)
      ..moveTo(far, armStart)
      ..lineTo(far, far - 2.5)
      ..arcToPoint(const Offset(far - 2.5, far), radius: r)
      ..lineTo(armStart, far)
      ..moveTo(armEnd, far)
      ..lineTo(near + 2.5, far)
      ..arcToPoint(const Offset(near, far - 2.5), radius: r)
      ..lineTo(near, armStart)
      ..moveTo(4.4, 12)
      ..lineTo(19.6, 12);
  }

  /// A T-shirt with a scooped neck, symmetric about x 12.9.
  static Path _outfit() {
    const axis = 25.8;
    Offset m(Offset p) => Offset(axis - p.dx, p.dy);
    const shoulder = Offset(7.6, 3.95);
    const tip = Offset(3.1, 7.9);
    const armpit = Offset(5.95, 10.35);
    const side = Offset(7.5, 10.1);
    const hem = 20.1;
    const corner = 1.8;
    final path = Path()
      ..moveTo(shoulder.dx + 1, shoulder.dy + 0.1)
      ..cubicTo(9.9, 5.9, 11.2, 6.15, 12.9, 6.15)
      ..cubicTo(axis - 11.2, 6.15, axis - 9.9, 5.9, axis - shoulder.dx - 1, shoulder.dy + 0.1)
      ..quadraticBezierTo(m(shoulder).dx, m(shoulder).dy - 0.3, m(shoulder).dx + 0.7, m(shoulder).dy + 0.5);
    for (final point in [m(tip), m(armpit), m(side)]) {
      path.lineTo(point.dx, point.dy);
    }
    path
      ..lineTo(axis - side.dx, hem - corner)
      ..arcToPoint(Offset(axis - side.dx - corner, hem), radius: const Radius.circular(corner))
      ..lineTo(side.dx + corner, hem)
      ..arcToPoint(Offset(side.dx, hem - corner), radius: const Radius.circular(corner))
      ..lineTo(side.dx, side.dy);
    for (final point in [armpit, tip]) {
      path.lineTo(point.dx, point.dy);
    }
    return path
      ..lineTo(shoulder.dx - 0.7, shoulder.dy + 0.5)
      ..quadraticBezierTo(shoulder.dx, shoulder.dy - 0.3, shoulder.dx + 1, shoulder.dy + 0.1);
  }

  /// A crescent: an arc of one circle out from its top tip round the left to its right tip, and back along another.
  static Path _night() {
    const top = Offset(10.7, 3.0);
    const right = Offset(21.2, 12.4);
    return Path()
      ..moveTo(top.dx, top.dy)
      ..arcToPoint(right, radius: const Radius.circular(8.85), clockwise: false, largeArc: true)
      ..arcToPoint(top, radius: const Radius.circular(8.13))
      ..close();
  }

  @override
  bool shouldRepaint(MeTopGlyphPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness || (oldDelegate.glyph != glyph || oldDelegate.color != color);
}

/// 更多服务's pink line icons, traced on 106 at 16× in a box [MeTheme.serviceGlyphBox] square, their middle at the
/// box's.
class MeServiceGlyphPainter extends CustomPainter {
  const MeServiceGlyphPainter(this.glyph, {this.color});

  final MeServiceGlyph glyph;

  /// Null draws each glyph in 106's own pink.
  final Color? color;

  Color get ink => color ?? (glyph == MeServiceGlyph.listen ? MeTheme.listenGlyph : MeTheme.serviceGlyph);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(MeTheme.serviceGlyphStroke, ink);
    // Each was traced around its own ink's middle; this puts that middle at the box's.
    final middle = glyph == MeServiceGlyph.support ? const Offset(15, 15.15) : const Offset(15, 14);
    canvas.translate(size.width / 2 - middle.dx, size.height / 2 - middle.dy);
    switch (glyph) {
      case MeServiceGlyph.support:
        _support(canvas, paint);
      case MeServiceGlyph.listen:
        _listen(canvas, paint);
      case MeServiceGlyph.settings:
        _settings(canvas, paint);
    }
  }

  /// A face in a speech bubble with a headset over it: the band, two pads and the smile.
  static void _support(Canvas canvas, Paint paint) {
    const band = Offset(14.9, 13.7);
    const bandRadius = 9.1;
    final bandStart = math.pi + math.asin((13.7 - 10.8) / bandRadius);
    canvas.drawArc(
      Rect.fromCircle(center: band, radius: bandRadius),
      bandStart,
      3 * math.pi - 2 * bandStart,
      false,
      paint,
    );
    const face = Offset(14.9, 15.4);
    const faceRadius = 7.1;
    const from = 97 * math.pi / 180;
    final bubble = Path()
      ..addArc(Rect.fromCircle(center: face, radius: faceRadius), from, 2 * math.pi - 22 * math.pi / 180)
      ..lineTo(14.2, 23.7)
      ..close();
    canvas.drawPath(bubble, paint);
    const pad = Radius.circular(1.6);
    canvas
      ..drawRRect(RRect.fromLTRBAndCorners(4.9, 12.2, 7.8, 19.0, topLeft: pad, bottomLeft: pad), paint)
      ..drawRRect(RRect.fromLTRBAndCorners(22.0, 12.2, 24.9, 19.0, topRight: pad, bottomRight: pad), paint)
      ..drawArc(Rect.fromCircle(center: const Offset(14.9, 16.1), radius: 2.8), 0, math.pi, false, paint);
  }

  /// Headphones over a heartbeat line.
  static void _listen(Canvas canvas, Paint paint) {
    const centre = Offset(15, 14.6);
    const radius = 9.3;
    const cupTop = 15.5, cupBottom = 22.7, cupInner = 10.3;
    const curve = Radius.circular(2.3);
    final left = Path()
      ..moveTo(centre.dx - radius, cupTop)
      ..lineTo(cupInner - 2.3, cupTop)
      ..arcToPoint(const Offset(cupInner, cupTop + 2.3), radius: curve)
      ..lineTo(cupInner, cupBottom - 2.3)
      ..arcToPoint(const Offset(cupInner - 2.3, cupBottom), radius: curve)
      ..lineTo(centre.dx - radius + 1.8, cupBottom)
      ..arcToPoint(Offset(centre.dx - radius, cupBottom - 1.8), radius: const Radius.circular(1.8));
    final band = Path()
      ..moveTo(centre.dx - radius, cupBottom - 1.8)
      ..lineTo(centre.dx - radius, centre.dy)
      ..arcToPoint(Offset(centre.dx + radius, centre.dy), radius: const Radius.circular(radius))
      ..lineTo(centre.dx + radius, cupBottom - 1.8);
    final mirror = Matrix4.identity()
      ..translateByDouble(centre.dx * 2, 0, 0, 1)
      ..scaleByDouble(-1, 1, 1, 1);
    final wave = Path()
      ..moveTo(11.6, 15.5)
      ..lineTo(13.2, 15.5)
      ..lineTo(14.0, 12.4)
      ..lineTo(16.0, 18.7)
      ..lineTo(16.9, 15.5)
      ..lineTo(18.4, 15.5);
    canvas
      ..drawPath(band, paint)
      ..drawPath(left, paint)
      ..drawPath(left.transform(mirror.storage), paint)
      ..drawPath(wave, paint);
  }

  /// A hexagon on its side round a small ring.
  static void _settings(Canvas canvas, Paint paint) {
    const centre = Offset(15, 14);
    final points = [
      const Offset(4.8, 14),
      const Offset(9.9, 4.8),
      const Offset(20.1, 4.8),
      const Offset(25.2, 14),
      const Offset(20.1, 23.2),
      const Offset(9.9, 23.2),
    ];
    final hexagon = Path();
    const corner = 1.2;
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final before = points[(i + points.length - 1) % points.length];
      final after = points[(i + 1) % points.length];
      final into = point + (before - point) / (before - point).distance * corner;
      final out = point + (after - point) / (after - point).distance * corner;
      if (i == 0) {
        hexagon.moveTo(into.dx, into.dy);
      } else {
        hexagon.lineTo(into.dx, into.dy);
      }
      hexagon.quadraticBezierTo(point.dx, point.dy, out.dx, out.dy);
    }
    canvas
      ..drawPath(hexagon..close(), paint)
      ..drawCircle(centre, 3.1, paint);
  }

  @override
  bool shouldRepaint(MeServiceGlyphPainter oldDelegate) => oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// The ✏️ after the name: a pencil pointing down-left over a short line.
class MePencilPainter extends CustomPainter {
  final BiliPalette palette;

  const MePencilPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(MeTheme.pencilStroke, MeThemeColors(palette).pencil);
    final pencil = Path()
      ..moveTo(4.3, 15.4)
      ..lineTo(4.3, 11.6)
      ..lineTo(12.3, 3.8)
      ..quadraticBezierTo(13.1, 3.0, 13.9, 3.8)
      ..lineTo(16.0, 5.8)
      ..quadraticBezierTo(16.8, 6.6, 16.0, 7.4)
      ..lineTo(8.0, 15.4)
      ..close();
    canvas
      ..translate(size.width / 2 - 10.4, size.height / 2 - 10.4)
      ..drawPath(pencil, paint)
      ..drawLine(const Offset(10.3, 17.1), const Offset(16.2, 17.1), paint);
  }

  @override
  bool shouldRepaint(MePencilPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// A chevron pointing right, filling its box.
class MeChevronPainter extends CustomPainter {
  const MeChevronPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = stroke / 2;
    canvas.drawPath(
      Path()
        ..moveTo(inset, inset)
        ..lineTo(size.width - inset, size.height / 2)
        ..lineTo(inset, size.height - inset),
      _stroke(stroke, color),
    );
  }

  @override
  bool shouldRepaint(MeChevronPainter oldDelegate) => oldDelegate.color != color || oldDelegate.stroke != stroke;
}

/// 大会员's pink disc with its 大 drawn in strokes, as on the avatar's corner and the 会员 card (87).
class MeVipDisc extends StatelessWidget {
  const MeVipDisc({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(MeTheme.vipDisc), painter: _VipDiscPainter(palette: BiliPalette.of(context)));
}

class _VipDiscPainter extends CustomPainter {
  final BiliPalette palette;

  const _VipDiscPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 16;
    canvas
      ..drawCircle(size.center(Offset.zero), size.width / 2, Paint()..color = MeThemeColors(palette).vipDiscFill)
      ..scale(unit);
    final paint = _stroke(MeTheme.vipDiscStroke, MeTheme.vipDiscInk);
    canvas.drawPath(
      Path()
        ..moveTo(4.4, 6.5)
        ..lineTo(11.6, 6.5)
        ..moveTo(8.0, 4.3)
        ..lineTo(8.0, 6.5)
        ..quadraticBezierTo(7.7, 9.2, 4.6, 11.1)
        ..moveTo(9.4, 8.9)
        ..lineTo(11.5, 11.1),
      paint,
    );
  }

  @override
  bool shouldRepaint(_VipDiscPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// The LV badge after the name (87): 评论's block shape and block letters, a little larger, in 我的's colours.
class MeLevelBadge extends StatelessWidget {
  const MeLevelBadge({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0, MeTheme.levels.length - 1);
    return Semantics(
      label: 'LV$clamped',
      child: CustomPaint(size: const Size(MeTheme.levelWidth, MeTheme.levelHeight), painter: _LevelPainter(clamped)),
    );
  }
}

class _LevelPainter extends CustomPainter {
  const _LevelPainter(this.level);

  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.height / 9;
    final corner = Radius.circular(unit);
    final block = Paint()..color = MeTheme.levels[level];
    canvas
      ..drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, unit, 12 * unit, 8 * unit), corner), block)
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(11 * unit, 0, size.width - 11 * unit, 9 * unit), corner),
        block,
      );
    final weight = 1.3 * unit;
    final ink = Paint()..color = MeTheme.levelInk;
    SegmentGlyph.draw(canvas, 'L', Rect.fromLTWH(1.3 * unit, 2.1 * unit, 3.5 * unit, 5.7 * unit), weight, ink);
    SegmentGlyph.draw(canvas, 'V', Rect.fromLTWH(5.9 * unit, 2.1 * unit, 4.4 * unit, 5.7 * unit), weight, ink);
    final digit = '$level';
    final width = SegmentGlyph.glyphWidth(digit, width: 4.5 * unit, weight: weight);
    final centre = (11 * unit + size.width) / 2 + 0.15 * unit;
    SegmentGlyph.draw(canvas, digit, Rect.fromLTWH(centre - width / 2, 1.35 * unit, width, 6.5 * unit), weight, ink);
  }

  @override
  bool shouldRepaint(_LevelPainter oldDelegate) => oldDelegate.level != level;
}
