import 'dart:math' as math;

// Not `Axis`: Flutter's widgets library exports one, and the app imports both.
enum GestureAxis { horizontal, vertical }

abstract final class GestureMath {
  static const double seekSecondsPerWidth = 90;
  static const double axisLockDistance = 10;
  static const double edgeInset = 25;

  /// null until the finger has travelled far enough to tell a seek from a brightness/volume drag.
  static GestureAxis? axis({required double dx, required double dy}) {
    if (math.sqrt(dx * dx + dy * dy) < axisLockDistance) return null;
    return dx.abs() >= dy.abs() ? GestureAxis.horizontal : GestureAxis.vertical;
  }

  static double seekTarget({
    required double start,
    required double dx,
    required double width,
    required double duration,
    bool limitToDuration = false,
  }) {
    final upper = _max(0, duration);
    if (!(width > 0)) return _min(_max(start, 0), upper);
    final span = limitToDuration ? _min(upper, seekSecondsPerWidth) : seekSecondsPerWidth;
    return _min(_max(start + dx / width * span, 0), upper);
  }

  /// Brightness or volume after a vertical drag; dragging up raises it, a full height drag spans 0 to 1.
  static double level({required double start, required double dy, required double height}) {
    if (!(height > 0)) return _min(_max(start, 0), 1);
    return _min(_max(start - dy / height, 0), 1);
  }

  // Swift's min/max: a NaN in the second argument loses instead of spreading, so a NaN duration clamps to 0.
  static double _max(double x, double y) => y >= x ? y : x;
  static double _min(double x, double y) => y < x ? y : x;
}
