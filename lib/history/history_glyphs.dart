import 'package:bili_core/api.dart' show HistoryDeviceKind;
import 'package:flutter/widgets.dart';

import '../shared/theme.dart';

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// The title bar's ‹, centred in its touch box.
class HistoryBackPainter extends CustomPainter {
  const HistoryBackPainter({this.colors});

  final HistoryThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(const Offset(0, HistoryTheme.backDrop));
    const half = HistoryTheme.backWidth / 2;
    final path = Path()
      ..moveTo(centre.dx + half, centre.dy - HistoryTheme.backHalfHeight)
      ..lineTo(centre.dx - half, centre.dy)
      ..lineTo(centre.dx + half, centre.dy + HistoryTheme.backHalfHeight);
    canvas.drawPath(path, _stroke((colors?.back ?? HistoryTheme.back), HistoryTheme.backStroke));
  }

  @override
  bool shouldRepaint(HistoryBackPainter oldDelegate) => oldDelegate.colors != colors;
}

/// A row's ⋮, centred in its touch box.
class HistoryMorePainter extends CustomPainter {
  const HistoryMorePainter({this.colors});

  final HistoryThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final paint = Paint()..color = (colors?.more ?? HistoryTheme.more);
    for (final step in const [-1, 0, 1]) {
      canvas.drawCircle(centre.translate(0, step * HistoryTheme.morePitch), HistoryTheme.moreDot / 2, paint);
    }
  }

  @override
  bool shouldRepaint(HistoryMorePainter oldDelegate) => oldDelegate.colors != colors;
}

/// The outlined UP before the uploader's name (45).
class HistoryUpGlyph extends StatelessWidget {
  const HistoryUpGlyph({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _UpPainter(colors: HistoryTheme.colorsOf(context)));
}

class _UpPainter extends CustomPainter {
  const _UpPainter({this.colors});

  final HistoryThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = HistoryTheme.glyphStroke;
    final paint = _stroke((colors?.meta ?? HistoryTheme.meta), stroke);
    final frame = Rect.fromCenter(
      center: size.center(const Offset(0, HistoryTheme.upDrop)),
      width: HistoryTheme.upWidth - stroke,
      height: HistoryTheme.upHeight - stroke,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(HistoryTheme.upRadius - stroke / 2)), paint);
    final ink = frame.inflate(stroke / 2);
    // The letters sit 2.2 and 7 in from the frame's ink, a little below its middle.
    const letterWidth = HistoryTheme.upLetterWidth - stroke;
    const letterHeight = HistoryTheme.upLetterHeight - stroke;
    final top = ink.center.dy - letterHeight / 2 + 0.25;
    final bottom = top + letterHeight;
    final uLeft = ink.left + 2.2 + stroke / 2;
    const uRadius = letterWidth / 2;
    canvas.drawPath(
      Path()
        ..moveTo(uLeft, top)
        ..lineTo(uLeft, bottom - uRadius)
        ..arcToPoint(
          Offset(uLeft + letterWidth, bottom - uRadius),
          radius: const Radius.circular(uRadius),
          clockwise: false,
        )
        ..lineTo(uLeft + letterWidth, top),
      paint,
    );
    final pLeft = ink.left + 7 + stroke / 2;
    const bowl = letterHeight * 0.55;
    const pWidth = letterWidth + 0.5;
    canvas.drawPath(
      Path()
        ..moveTo(pLeft, bottom)
        ..lineTo(pLeft, top)
        ..lineTo(pLeft + pWidth - bowl / 2, top)
        ..arcToPoint(Offset(pLeft + pWidth - bowl / 2, top + bowl), radius: const Radius.circular(bowl / 2))
        ..lineTo(pLeft, top + bowl),
      paint,
    );
  }

  @override
  bool shouldRepaint(_UpPainter oldDelegate) => oldDelegate.colors != colors;
}

/// Where the video was watched: a phone, or a PC's screen on its stand for everything else (45, 47).
class HistoryDeviceGlyph extends StatelessWidget {
  const HistoryDeviceGlyph(this.kind, {super.key});

  final HistoryDeviceKind kind;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: ValueKey('history-device-${kind == HistoryDeviceKind.phone ? 'phone' : 'pc'}'),
    painter: _DevicePainter(phone: kind == HistoryDeviceKind.phone, colors: HistoryTheme.colorsOf(context)),
  );
}

class _DevicePainter extends CustomPainter {
  const _DevicePainter({required this.phone, this.colors});

  final bool phone;

  final HistoryThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = HistoryTheme.glyphStroke;
    final paint = _stroke((colors?.meta ?? HistoryTheme.meta), stroke);
    final fill = Paint()..color = (colors?.meta ?? HistoryTheme.meta);
    final centre = size.center(Offset.zero);
    if (phone) {
      final body = Rect.fromCenter(
        center: centre,
        width: HistoryTheme.phoneWidth - stroke,
        height: HistoryTheme.phoneHeight - stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(HistoryTheme.phoneRadius - stroke / 2)),
        paint,
      );
      final inner = body.deflate(stroke / 2);
      canvas
        ..drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              centre.dx - HistoryTheme.phoneNotch / 2,
              inner.top,
              HistoryTheme.phoneNotch,
              HistoryTheme.phoneMark,
            ),
            bottomLeft: const Radius.circular(HistoryTheme.phoneMark / 2),
            bottomRight: const Radius.circular(HistoryTheme.phoneMark / 2),
          ),
          fill,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centre.dx - HistoryTheme.phoneBar / 2,
              inner.bottom - 0.85 - HistoryTheme.phoneMark,
              HistoryTheme.phoneBar,
              HistoryTheme.phoneMark,
            ),
            const Radius.circular(HistoryTheme.phoneMark / 2),
          ),
          fill,
        );
      return;
    }
    const height = HistoryTheme.pcHeight + HistoryTheme.pcStand;
    final top = centre.dy - height / 2;
    final screen = Rect.fromLTWH(
      centre.dx - HistoryTheme.pcWidth / 2,
      top,
      HistoryTheme.pcWidth,
      HistoryTheme.pcHeight,
    ).deflate(stroke / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(screen, const Radius.circular(HistoryTheme.pcRadius - stroke / 2)), paint);
    final base = top + height - stroke / 2;
    canvas
      ..drawLine(Offset(centre.dx, screen.bottom), Offset(centre.dx, base), _stroke((colors?.meta ?? HistoryTheme.meta), HistoryTheme.pcStandStroke))
      ..drawLine(
        Offset(centre.dx - (HistoryTheme.pcBaseWidth - stroke) / 2, base),
        Offset(centre.dx + (HistoryTheme.pcBaseWidth - stroke) / 2, base),
        paint,
      );
  }

  @override
  bool shouldRepaint(_DevicePainter oldDelegate) => oldDelegate.colors != colors || oldDelegate.phone != phone;
}

/// 48's 删除: a bin with its lid and handle, two lines inside.
class HistoryTrashPainter extends CustomPainter {
  const HistoryTrashPainter({this.colors});

  final HistoryThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 29.4 × 28 grid measured off 48, centred in [size].
    canvas.save();
    canvas.translate((size.width - 29.4) / 2, (size.height - 28) / 2);
    final paint = _stroke((colors?.sheetDeleteInk ?? HistoryTheme.sheetDeleteInk), HistoryTheme.sheetTrashStroke);
    canvas
      ..drawLine(const Offset(2.4, 6.6), const Offset(27, 6.6), paint)
      ..drawPath(
        Path()
          ..moveTo(9.6, 6.6)
          ..lineTo(9.6, 4.7)
          ..arcToPoint(const Offset(11.6, 2.7), radius: const Radius.circular(2))
          ..lineTo(17.6, 2.7)
          ..arcToPoint(const Offset(19.6, 4.7), radius: const Radius.circular(2))
          ..lineTo(19.6, 6.6),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(5, 10.4)
          ..lineTo(5, 21.8)
          ..arcToPoint(const Offset(9, 25.8), radius: const Radius.circular(4), clockwise: false)
          ..lineTo(20.3, 25.8)
          ..arcToPoint(const Offset(24.3, 21.8), radius: const Radius.circular(4), clockwise: false)
          ..lineTo(24.3, 10.4),
        paint,
      )
      ..drawLine(const Offset(11.25, 13.3), const Offset(11.25, 17.7), paint)
      ..drawLine(const Offset(18, 13.3), const Offset(18, 17.7), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(HistoryTrashPainter oldDelegate) => oldDelegate.colors != colors;
}

/// The share button's glyph: an arrow rising out of an open box, as iOS draws share.
class HistorySharePainter extends CustomPainter {
  const HistorySharePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const width = HistoryTheme.sheetShareGlyphWidth;
    const height = HistoryTheme.sheetShareGlyphHeight;
    canvas.save();
    canvas.translate((size.width - width) / 2, (size.height - height) / 2);
    final paint = _stroke(HistoryTheme.sheetCircleGlyph, HistoryTheme.sheetShareStroke);
    const boxTop = height * 0.4;
    const mid = width / 2;
    canvas
      ..drawPath(
        Path()
          ..moveTo(mid - 3, boxTop)
          ..lineTo(1.5, boxTop)
          ..lineTo(1.5, height - 1)
          ..lineTo(width - 1.5, height - 1)
          ..lineTo(width - 1.5, boxTop)
          ..lineTo(mid + 3, boxTop),
        paint,
      )
      ..drawLine(const Offset(mid, 1), const Offset(mid, height * 0.66), paint)
      ..drawPath(
        Path()
          ..moveTo(mid - 4, 5)
          ..lineTo(mid, 1)
          ..lineTo(mid + 4, 5),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(HistorySharePainter oldDelegate) => false;
}
