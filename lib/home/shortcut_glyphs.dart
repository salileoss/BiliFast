import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../shared/theme.dart';

/// The four shortcuts both the avatar's page (49) and 我的 (87) show.
enum ShortcutGlyph { offline, history, star, later }

/// The shortcuts' line icons, traced on 49 on a 32 pt box, in [color].
class ShortcutPainter extends CustomPainter {
  final BiliPalette palette;

  // Keep the public color argument while resolving its default from the appearance snapshot.
  // ignore: prefer_initializing_formals
  const ShortcutPainter(this.glyph, {Color? color, this.palette = const BiliPalette(Brightness.light)}) : _color = color;

  final ShortcutGlyph glyph;
  final Color? _color;
  Color get color => _color ?? BiliColorsColors(palette).text;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / AvatarPageTheme.shortcutIconBox);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AvatarPageTheme.shortcutStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    switch (glyph) {
      case ShortcutGlyph.offline:
        const corner = Radius.circular(3);
        final folder = Path()
          ..moveTo(5.6, 10.3)
          ..arcToPoint(const Offset(8.6, 7.3), radius: corner)
          ..lineTo(13.2, 7.3)
          ..lineTo(15.8, 10.8)
          ..lineTo(23.3, 10.8)
          ..arcToPoint(const Offset(26.3, 13.8), radius: corner)
          ..lineTo(26.3, 21.6)
          ..arcToPoint(const Offset(23.3, 24.6), radius: corner)
          ..lineTo(8.6, 24.6)
          ..arcToPoint(const Offset(5.6, 21.6), radius: corner)
          ..close();
        final arrow = Path()
          ..moveTo(16, 14.6)
          ..lineTo(16, 20.2)
          ..moveTo(12.9, 17.3)
          ..lineTo(16, 20.4)
          ..lineTo(19.1, 17.3);
        canvas
          ..drawPath(folder, paint)
          ..drawLine(const Offset(19.2, 7.3), const Offset(24.2, 7.3), paint)
          ..drawPath(arrow, paint);
      case ShortcutGlyph.history:
        _circleArrow(canvas, paint, centre: const Offset(17.5, 16), onRight: false);
        canvas.drawPath(
          Path()
            ..moveTo(17.5, 10.8)
            ..lineTo(17.5, 15.8)
            ..lineTo(22.6, 15.8),
          paint,
        );
      case ShortcutGlyph.star:
        const centre = Offset(16, 16.6);
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? 11.2 : 6.3;
          final point = centre + Offset.fromDirection(-math.pi / 2 + i * math.pi / 5, radius);
          if (i == 0) {
            star.moveTo(point.dx, point.dy);
          } else {
            star.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(star..close(), paint);
      case ShortcutGlyph.later:
        _circleArrow(canvas, paint, centre: const Offset(15.2, 16), onRight: true);
        canvas.drawPath(
          Path()
            ..moveTo(13.2, 13.4)
            ..lineTo(17.5, 16.05)
            ..lineTo(13.2, 18.7)
            ..close(),
          paint..strokeWidth = AvatarPageTheme.shortcutStroke * 0.85,
        );
    }
  }

  /// A ring with a short gap beside its arrowhead, which points down: 历史记录's on the left, 稍后再看's on the right.
  void _circleArrow(Canvas canvas, Paint paint, {required Offset centre, required bool onRight}) {
    const radius = 10.2;
    const gap = 15 * math.pi / 180;
    const tip = 8 * math.pi / 180;
    final end = onRight ? tip : math.pi - tip;
    final start = onRight ? end + gap : end;
    canvas.drawArc(Rect.fromCircle(center: centre, radius: radius), start, 2 * math.pi - gap, false, paint);
    final head = centre + Offset.fromDirection(end, radius);
    const arm = 3.4;
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - arm, head.dy - arm)
        ..lineTo(head.dx, head.dy)
        ..lineTo(head.dx + arm, head.dy - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(ShortcutPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness || (oldDelegate.glyph != glyph || oldDelegate.color != color);
}
