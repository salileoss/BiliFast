import 'package:bilifast/video/local_watch_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalWatchProgress progress;
  var hostMs = 0.0;

  setUp(() {
    progress = LocalWatchProgress();
    hostMs = 0;
  });

  ({double seconds, bool completed})? at(double position, {
    double after = 1,
    double rate = 1,
    double duration = 100,
    bool active = true,
  }) {
    hostMs += after * 1000;
    return progress.sample(position: position, hostMs: hostMs, rate: rate, duration: duration, active: active);
  }

  test('batches actual viewing every 15 seconds, retaining the last partial batch', () {
    at(0);
    for (var second = 1; second < 15; second++) {
      expect(at(second.toDouble()), isNull);
    }
    expect(at(15), (seconds: 15.0, completed: false));
    at(16);
    expect(progress.flush(), (seconds: 1.0, completed: false));
    expect(progress.flush(), isNull);
  });

  test('2x playback counts real time while coverage counts watched content', () {
    at(0, rate: 2, duration: 20);
    ({double seconds, bool completed})? completed;
    for (var second = 1; second <= 9; second++) {
      completed = at(second * 2.0, rate: 2, duration: 20);
    }
    expect(completed, (seconds: 9.0, completed: true));
    expect(progress.watched, 9);
  });

  test('seeking to the end does not fabricate viewing or completion', () {
    at(0);
    at(1);
    progress.discontinuity();
    at(95);
    at(96);
    expect(progress.flush(), (seconds: 2.0, completed: false));
  });

  test('unannounced large position jumps and long event gaps do not count', () {
    at(0);
    at(90);
    expect(progress.watched, 0);
    at(91);
    at(100, after: 20);
    expect(progress.watched, 1);
  });

  test('rewinding and autoplay loops never count watched intervals twice', () {
    at(0);
    for (var second = 1; second <= 10; second++) {
      at(second.toDouble());
    }
    at(0);
    for (var second = 1; second <= 10; second++) {
      at(second.toDouble());
    }
    expect(progress.watched, 10);
    expect(progress.flush(), (seconds: 10.0, completed: false));
  });

  test('watching a gap after a seek counts it, but overlapping intervals only once', () {
    at(0);
    at(1);
    at(2);
    progress.discontinuity();
    at(5);
    at(6);
    progress.discontinuity();
    at(1);
    for (var second = 2; second <= 6; second++) {
      at(second.toDouble());
    }
    expect(progress.watched, 6);
  });

  test('paused, buffered, hidden and background samples cannot bridge into resumed viewing', () {
    at(0);
    at(1);
    at(20, after: 19, active: false);
    at(21);
    at(22);
    expect(progress.flush(), (seconds: 2.0, completed: false));
  });

  test('completion needs 90 percent unique coverage and is sent once', () {
    at(0, duration: 10);
    ({double seconds, bool completed})? completed;
    for (var second = 1; second <= 9; second++) {
      completed = at(second.toDouble(), duration: 10);
    }
    expect(completed, (seconds: 9.0, completed: true));
    expect(at(10, duration: 10), isNull);
    expect(progress.flush(), (seconds: 1.0, completed: false));
  });
}
