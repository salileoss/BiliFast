import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';

/// Bilibili's TV in place of a missing folder cover (114, 116): the rounded frame, two antennae, two feet, the closed
/// eyes and the ω mouth, all in [color], stretched to [size].
class CoverTv extends StatelessWidget {
  const CoverTv({super.key, required this.size, required this.color});

  final Size size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: size, painter: _TvPainter(color)),
  );
}

class _TvPainter extends CustomPainter {
  const _TvPainter(this.color);

  final Color color;

  // Traced on 114 at 3 px per point, in px from the ink's top left; mirrored about its middle.
  static const _width = 245.0;
  static const _height = 229.0;
  static const _middle = 122.5;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..save()
      ..scale(size.width / _width, size.height / _height);
    for (final side in const [-1.0, 1.0]) {
      double x(double fromMiddle) => _middle + side * fromMiddle;
      canvas
        ..drawLine(Offset(x(55.25), 7), Offset(x(19), 36), line..strokeWidth = 14)
        ..drawRRect(
          RRect.fromLTRBR(math.min(x(75), x(48)), 200, math.max(x(75), x(48)), 228.5, const Radius.circular(13.5)),
          fill,
        );
      canvas
        ..save()
        ..translate(x(51.1), 105.9)
        ..rotate(side * 9.9 * math.pi / 180)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 52.3, height: 19),
            const Radius.circular(2),
          ),
          fill,
        )
        ..restore();
    }
    final frame = RRect.fromLTRBR(0, 32, _width, 215.5, const Radius.circular(28));
    final screen = RRect.fromLTRBR(28.5, 57.5, 216.5, 189.5, const Radius.circular(11));
    canvas
      ..drawDRRect(frame, screen, fill)
      ..drawPath(_mouth, line..strokeWidth = 9)
      ..restore();
  }

  static final _mouth = Path()
    ..moveTo(94.5, 147)
    ..cubicTo(95, 158, 101, 160, 108.25, 160)
    ..cubicTo(115.5, 160, 121.5, 158, 122, 147)
    ..cubicTo(122.5, 158, 128.5, 160, 135.75, 160)
    ..cubicTo(143, 160, 149, 158, 149.5, 147);

  @override
  bool shouldRepaint(_TvPainter oldDelegate) => oldDelegate.color != color;
}

/// The folder badge on a cover (114, 116): a dark rounded square with two bars over a card holding a ▶.
class FolderStackBadge extends StatelessWidget {
  const FolderStackBadge({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(OwnSpaceTabsTheme.stackSize), painter: _StackPainter()),
  );
}

class _StackPainter extends CustomPainter {
  const _StackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Traced on 114's 20 pt badge.
    final scale = size.width / 20;
    canvas
      ..save()
      ..scale(scale)
      ..drawRRect(
        RRect.fromLTRBR(0, 0, 20, 20, const Radius.circular(OwnSpaceTabsTheme.stackRadius)),
        Paint()..color = OwnSpaceTabsTheme.stackFill,
      );
    final ink = Paint()..color = OwnSpaceTabsTheme.stackInk;
    final card = Path()..addRRect(RRect.fromLTRBR(2.3, 7.6, 17.6, 17.7, const Radius.circular(2)));
    final play = Path()
      ..moveTo(8.4, 10.5)
      ..lineTo(12.5, 12.7)
      ..lineTo(8.4, 14.9)
      ..close();
    canvas
      ..drawRRect(RRect.fromLTRBR(5, 2.7, 15, 3.97, const Radius.circular(0.64)), ink)
      ..drawRRect(RRect.fromLTRBR(4, 5.2, 16, 6.58, const Radius.circular(0.69)), ink)
      ..drawPath(Path.combine(PathOperation.difference, card, play), ink)
      ..restore();
  }

  @override
  bool shouldRepaint(_StackPainter oldDelegate) => false;
}

/// The eye-slash after a section hidden from others (114, 115): an eye and its pupil, broken where the slash crosses.
class HiddenEye extends StatelessWidget {
  const HiddenEye({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size(OwnSpaceTabsTheme.eyeWidth, OwnSpaceTabsTheme.eyeHeight), painter: _EyePainter(palette: BiliPalette.of(context))),
  );
}

class _EyePainter extends CustomPainter {
  final BiliPalette palette;

  const _EyePainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    // Traced on 114 at 3 px per point, in px from the ink's top left.
    final scale = size.width / 46;
    final line = Paint()
      ..color = OwnSpaceTabsThemeColors(palette).eyeInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = OwnSpaceTabsTheme.eyeStroke * 3
      ..strokeCap = StrokeCap.round;
    const from = Offset(6.8, 31.2), to = Offset(36.5, 2.1);
    final eye = Path()
      ..moveTo(2, 17.2)
      ..cubicTo(5, 9, 13, 3, 23, 3)
      ..cubicTo(33, 3, 41, 9, 44, 17.2)
      ..cubicTo(41, 25.5, 33, 31.3, 23, 31.3)
      ..cubicTo(13, 31.3, 5, 25.5, 2, 17.2);
    canvas
      ..save()
      ..scale(scale)
      ..saveLayer(Offset.zero & size / scale, Paint())
      ..drawPath(eye, line)
      ..drawCircle(const Offset(23, 17.6), 7.9, line)
      // The slash's gap: a band wider than its line, cleared from the eye under it.
      ..drawLine(
        from,
        to,
        Paint()
          ..blendMode = BlendMode.clear
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      )
      ..restore()
      ..drawLine(from, to, line)
      ..restore();
  }

  @override
  bool shouldRepaint(_EyePainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// 投稿's upload glyph (108): an arrow up out of an open tray.
class UploadGlyph extends StatelessWidget {
  const UploadGlyph({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(OwnSpaceTabsTheme.uploadSize), painter: _UploadPainter(palette: BiliPalette.of(context))),
  );
}

class _UploadPainter extends CustomPainter {
  final BiliPalette palette;

  const _UploadPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = OwnSpaceTabsThemeColors(palette).uploadInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = OwnSpaceTabsTheme.uploadStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Traced on 108 in points from the disc's middle.
    final tray = Path()
      ..moveTo(-4.2, -0.6)
      ..lineTo(-5.4, -0.6)
      ..arcToPoint(const Offset(-8.4, 2.4), radius: const Radius.circular(3), clockwise: false)
      ..lineTo(-8.4, 6.2)
      ..arcToPoint(const Offset(-5.4, 9.2), radius: const Radius.circular(3), clockwise: false)
      ..lineTo(5.75, 9.2)
      ..arcToPoint(const Offset(8.75, 6.2), radius: const Radius.circular(3), clockwise: false)
      ..lineTo(8.75, 2.4)
      ..arcToPoint(const Offset(5.75, -0.6), radius: const Radius.circular(3), clockwise: false)
      ..lineTo(4.8, -0.6);
    final arrow = Path()
      ..moveTo(0.2, 3.5)
      ..lineTo(0.2, -8.3)
      ..moveTo(-4.5, -3.7)
      ..lineTo(0.2, -8.3)
      ..lineTo(4.9, -3.7);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..drawPath(tray, line)
      ..drawPath(arrow, line)
      ..restore();
  }

  @override
  bool shouldRepaint(_UploadPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
