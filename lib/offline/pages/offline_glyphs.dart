import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';

// The APK's own 离线缓存 icons (ic_download_search, ic_download_edit) are drawn differently from the iPhone's (143,
// 145), so these are drawn from the screenshots.

typedef _T = OfflineListTheme;

Paint _line(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color color) => Paint()..color = color;

/// The bar's ‹, at its place in a box whose left edge is the screen's.
class OfflineBackPainter extends CustomPainter {
  const OfflineBackPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    canvas.drawPath(
      Path()
        ..moveTo(_T.backEndX, middle - _T.backHalfHeight)
        ..lineTo(_T.backTipX, middle)
        ..lineTo(_T.backEndX, middle + _T.backHalfHeight),
      _line(color, _T.backStroke),
    );
  }

  @override
  bool shouldRepaint(OfflineBackPainter oldDelegate) => oldDelegate.color != color;
}

/// The bar's 🔍, centred in its box.
class OfflineSearchPainter extends CustomPainter {
  const OfflineSearchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = size.center(Offset.zero) - const Offset(_T.searchBox / 2, _T.searchBox / 2 + _T.searchLift);
    const centre = Offset(_T.searchRingCentre, _T.searchRingCentre);
    final paint = _line(color, _T.searchStroke);
    final along = _T.searchRingRadius / math.sqrt2;
    canvas
      ..drawCircle(origin + centre, _T.searchRingRadius, paint)
      ..drawLine(
        origin + centre + Offset(along, along),
        origin + const Offset(_T.searchHandleEnd, _T.searchHandleEnd),
        paint,
      );
  }

  @override
  bool shouldRepaint(OfflineSearchPainter oldDelegate) => oldDelegate.color != color;
}

/// The bar's ☰: three bars with ✓, ○ and ✓ before them, centred in its box.
class OfflineEditPainter extends CustomPainter {
  const OfflineEditPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = size.center(Offset.zero) - const Offset(_T.editWidth / 2, _T.editHeight / 2 + _T.editLift);
    final paint = _line(color, _T.editStroke);
    final middle = _T.editHeight / 2;
    for (final step in const [-1, 0, 1]) {
      final y = middle + step * _T.editPitch;
      canvas.drawLine(origin + Offset(_T.editBarLeft, y), origin + Offset(_T.editBarRight, y), paint);
      if (step == 0) {
        canvas.drawCircle(origin + Offset(_T.editMarkCentre, y), _T.editRingRadius, _line(color, _T.editRingStroke));
      } else {
        canvas.drawPath(
          Path()
            ..moveTo(origin.dx + 0.75, origin.dy + y - 0.2)
            ..lineTo(origin.dx + 2.35, origin.dy + y + 1.25)
            ..lineTo(origin.dx + 4.95, origin.dy + y - 1.25),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(OfflineEditPainter oldDelegate) => oldDelegate.color != color;
}

/// 全部暂停's ❚❚ or 全部开始's ▶ (146, 148).
class AllGlyph extends StatelessWidget {
  const AllGlyph({super.key, required this.paused});

  /// ▶: everything is stopped, so the pill starts it all.
  final bool paused;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(_T.allGlyphWidth, _T.allHeight), painter: _AllPainter(paused, colors: _T.colorsOf(context)));
}

class _AllPainter extends CustomPainter {
  const _AllPainter(this.play, {this.colors});

  final bool play;

  final OfflineListThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    if (play) {
      // A triangle inset by the corner's radius, filled and stroked twice as wide with round joins, has round corners.
      const r = _T.playRound;
      const half = _T.playHeight / 2;
      final path = Path()
        ..moveTo(r, middle - half + r)
        ..lineTo(size.width - r * 1.2, middle)
        ..lineTo(r, middle + half - r)
        ..close();
      canvas
        ..drawPath(path, _fill((colors?.allGlyph ?? _T.allGlyph)))
        ..drawPath(path, _line((colors?.allGlyph ?? _T.allGlyph), r * 2));
      return;
    }
    final paint = _fill((colors?.allGlyph ?? _T.allGlyph));
    const radius = Radius.circular(_T.pauseBar / 2);
    for (final left in const [0.0, _T.allGlyphWidth - _T.pauseBar]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, middle - _T.pauseHeight / 2, _T.pauseBar, _T.pauseHeight), radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AllPainter oldDelegate) => oldDelegate.colors != colors || oldDelegate.play != play;
}

/// 同时缓存数量's ⌄.
class ChevronGlyph extends StatelessWidget {
  const ChevronGlyph({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(_T.chevronWidth, _T.chevronHeight), painter: _ChevronPainter(colors: _T.colorsOf(context)));
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({this.colors});

  final OfflineListThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _T.chevronStroke / 2;
    canvas.drawPath(
      Path()
        ..moveTo(inset, inset)
        ..lineTo(size.width / 2, size.height - inset)
        ..lineTo(size.width - inset, inset),
      _line((colors?.countInk ?? _T.countInk), _T.chevronStroke),
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.colors != colors;
}

/// A 合集's stack on its cover (155): a filled rhombus over two open ones.
class StackGlyph extends StatelessWidget {
  const StackGlyph({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(_T.stackWidth, _T.stackHeight), painter: _StackPainter());
}

class _StackPainter extends CustomPainter {
  const _StackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const half = 2.4;
    final top = Path()
      ..moveTo(w / 2, 0.4)
      ..lineTo(w - 0.4, half + 0.4)
      ..lineTo(w / 2, half * 2 + 0.4)
      ..lineTo(0.4, half + 0.4)
      ..close();
    canvas
      ..drawPath(top, _fill(_T.pillInk))
      ..drawPath(top, _line(_T.pillInk, 0.8));
    final paint = _line(_T.pillInk, 1.1);
    for (final drop in const [2.0, 4.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(0.6, half + 0.4 + drop)
          ..lineTo(w / 2, half * 2 + 0.4 + drop)
          ..lineTo(w - 0.6, half + 0.4 + drop),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StackPainter oldDelegate) => false;
}

/// The edit mode's circle (149, 150): a #61666D ring, or pink with a white ✓ when [chosen].
class OfflineChoiceCircle extends StatelessWidget {
  const OfflineChoiceCircle({super.key, required this.chosen});

  final bool chosen;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(_T.circle), painter: _CirclePainter(chosen, colors: _T.colorsOf(context)));
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.chosen, {this.colors});

  final bool chosen;

  final OfflineListThemeColors? colors;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    if (!chosen) {
      canvas.drawCircle(centre, radius - _T.circleStroke / 2, _line((colors?.circleRing ?? _T.circleRing), _T.circleStroke));
      return;
    }
    canvas
      ..drawCircle(centre, radius, _fill((colors?.circleChosen ?? _T.circleChosen)))
      ..drawPath(
        Path()
          ..moveTo(centre.dx - 5.0, centre.dy + 0.2)
          ..lineTo(centre.dx - 1.8, centre.dy + 2.9)
          ..lineTo(centre.dx + 4.8, centre.dy - 3.3),
        _line(_T.checkInk, _T.checkStroke),
      );
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) => oldDelegate.colors != colors || oldDelegate.chosen != chosen;
}
