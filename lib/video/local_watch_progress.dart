import 'dart:math' as math;

/// Unique media intervals watched during one playback's lifetime. Position jumps,
/// paused time and repeated intervals contribute no interest signal.
class LocalWatchProgress {
  final _intervals = <({double start, double end})>[];
  double? _position;
  double? _hostMs;
  double _pending = 0;
  double _watched = 0;
  double _covered = 0;
  bool _completionSent = false;

  double get watched => _watched;

  /// The next reading becomes a baseline rather than bridging a seek or pause.
  void discontinuity() {
    _position = null;
    _hostMs = null;
  }

  ({double seconds, bool completed})? sample({
    required double position,
    required double hostMs,
    required double rate,
    required double duration,
    required bool active,
  }) {
    if (!active || !position.isFinite || position < 0 || !hostMs.isFinite || !rate.isFinite || rate <= 0) {
      discontinuity();
      return null;
    }
    final previous = _position;
    final before = _hostMs;
    _position = position;
    _hostMs = hostMs;
    if (previous == null || before == null) return null;
    final elapsed = (hostMs - before) / 1000;
    final advanced = position - previous;
    // The player reports at about 10 Hz. Long gaps and implausible advances are
    // discontinuities, even if the platform did not report a seek or suspension.
    if (elapsed <= 0 || elapsed > 5 || advanced <= 0 || advanced > elapsed * rate + 0.35) return null;
    final end = duration > 0 ? math.min(position, duration) : position;
    final newlyCovered = _add(previous, end);
    _covered += newlyCovered;
    final realSeconds = math.min(elapsed, newlyCovered / rate);
    _pending += realSeconds;
    _watched += realSeconds;
    final completed = duration > 0 && _covered >= duration * 0.9;
    if (completed && !_completionSent) {
      _completionSent = true;
      return flush(completed: true);
    }
    return _pending >= 15 ? flush() : null;
  }

  /// Batches writes, with a final partial batch on pause, background or close.
  ({double seconds, bool completed})? flush({bool completed = false}) {
    if (_pending <= 0 && !completed) return null;
    final result = (seconds: _pending, completed: completed);
    _pending = 0;
    return result;
  }

  double _add(double start, double end) {
    if (end <= start) return 0;
    var unique = end - start;
    for (final interval in _intervals) {
      unique -= math.max(0, math.min(end, interval.end) - math.max(start, interval.start));
    }
    var from = start;
    var to = end;
    final merged = <({double start, double end})>[];
    var inserted = false;
    for (final interval in _intervals) {
      if (interval.end < from) {
        merged.add(interval);
      } else if (interval.start > to) {
        if (!inserted) {
          merged.add((start: from, end: to));
          inserted = true;
        }
        merged.add(interval);
      } else {
        from = math.min(from, interval.start);
        to = math.max(to, interval.end);
      }
    }
    if (!inserted) merged.add((start: from, end: to));
    // Hundreds of separate seeks need not grow an unbounded session record.
    // Stop adding new intervals once full, rather than treating forgotten ones as new.
    if (merged.length > 128) return 0;
    _intervals
      ..clear()
      ..addAll(merged);
    return math.max(0, unique);
  }
}
