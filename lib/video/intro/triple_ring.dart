import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';

/// 长按三连: the ring waits a moment so a tap stays a tap, then fills.
abstract final class TripleTiming {
  static const delay = Duration(milliseconds: 200);
  static const fill = Duration(milliseconds: 1200);
  static const release = Duration(milliseconds: 150);
  static const burst = Duration(milliseconds: 500);
}

/// A pink ring that fills clockwise from the top around an action's icon while 点赞 is held, and a burst when 三连
/// fires: the full ring flashes and spreads with eight dots.
class TripleRing extends StatelessWidget {
  const TripleRing({super.key, required this.progress, required this.burst, this.size = ActionTheme.ring});

  /// 0 to 1.
  final Animation<double> progress;

  /// 0 at rest, running to 1 once per burst.
  final Animation<double> burst;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RingPainter(progress, burst, palette: BiliPalette.of(context))),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final BiliPalette palette;
  _RingPainter(this.progress, this.burst, {this.palette = const BiliPalette(Brightness.light)}) : super(repaint: Listenable.merge([progress, burst]));

  final Animation<double> progress;
  final Animation<double> burst;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = (size.shortestSide - ActionTheme.ringWidth) / 2;
    final stroke = Paint()
      ..color = BiliColorsColors(palette).pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = ActionTheme.ringWidth
      ..strokeCap = StrokeCap.round;
    final filled = progress.value;
    if (filled > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2,
        2 * math.pi * filled.clamp(0.0, 1.0),
        false,
        stroke,
      );
    }
    final t = burst.value;
    if (t <= 0 || t >= 1) return;
    final spread = 1 + (ActionTheme.burstSpread - 1) * Curves.easeOut.transform(t);
    final opacity = 1 - Curves.easeIn.transform(t);
    final faded = BiliColorsColors(palette).pink.withValues(alpha: opacity);
    canvas.drawCircle(centre, radius * spread, stroke..color = faded);
    final dot = Paint()..color = faded;
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * (size.shortestSide / 2) * spread,
        ActionTheme.burstDot / 2,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => (old.progress != progress || old.burst != burst) || old.palette.brightness != palette.brightness;
}
