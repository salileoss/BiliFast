import 'package:bili_core/engine.dart';
import 'package:bili_core/shared.dart';
import 'package:test/test.dart';

void main() {
  late ManualClock manual;
  late AutoConcurrency auto;

  setUp(() {
    manual = ManualClock(100000);
    auto = AutoConcurrency(clock: manual.clock);
  });

  test('a new session starts at 16 and comes back when ahead', () {
    expect(auto.threads, 8);
    auto.newSession();
    expect(auto.threads, 16);
    expect(auto.status().inStartup, isTrue);
    manual.advance(3000);
    auto.buffer(ahead: 20, playing: true);
    expect(auto.threads, 12);
    manual.advance(3000);
    auto.buffer(ahead: 20, playing: true);
    expect(auto.threads, 8);
    expect(auto.status().inStartup, isFalse);
  });

  test('a stall climbs and respects the cooldown', () {
    auto.newSession();
    expect(auto.stall(), isFalse);
    manual.advance(3000);
    expect(auto.stall(), isTrue);
    expect(auto.threads, 24);
  });

  test('pushback steps down and blocks that level', () {
    auto.newSession();
    manual.advance(3000);
    auto.stall();
    expect(auto.threads, 24);
    expect(auto.pushback(status: 429), isTrue);
    expect(auto.threads, 16);
    manual.advance(3000);
    expect(auto.stall(), isFalse);
    expect(auto.threads, 16);
    manual.advance(180001);
    expect(auto.stall(), isTrue);
    expect(auto.threads, 24);
  });

  test('a fruitless trial is taken back', () {
    auto.demand(active: 8, limit: 8, queued: 4);
    for (var piece = 0; piece < 10; piece++) {
      auto.delivered(1000000);
      manual.advance(500);
    }
    expect(auto.stall(), isTrue);
    expect(auto.threads, 12);
    for (var piece = 0; piece < 21; piece++) {
      auto.delivered(200000);
      manual.advance(500);
    }
    expect(auto.threads, 8);
  });

  void deliveries(int count, int bytes, {double? ahead}) {
    for (var piece = 0; piece < count; piece++) {
      manual.advance(250);
      auto.delivered(bytes);
      if (ahead != null) auto.buffer(ahead: ahead, playing: true);
    }
  }

  void beginLowerTrial() {
    auto.newSession();
    manual.advance(31000);
    auto.buffer(ahead: 0, playing: false); // Expire startup without its automatic step-down.
    auto.demand(active: 16, limit: 16, queued: 4);
    deliveries(24, 250000);
    auto.buffer(ahead: 25, playing: true);
    deliveries(120, 250000, ahead: 25);
    expect(auto.threads, 12);
  }

  test('a five-percent gain is too small to keep extra connections under sustained demand', () {
    auto.demand(active: 8, limit: 8, queued: 4);
    deliveries(24, 250000);
    auto.stall();
    expect(auto.threads, 12);
    deliveries(40, 262500);
    expect(auto.threads, 8);
  });

  test('a useful throughput gain keeps the extra connections', () {
    auto.demand(active: 8, limit: 8, queued: 4);
    deliveries(24, 250000);
    auto.stall();
    deliveries(40, 300000);
    expect(auto.threads, 12);
  });

  test('an idle tail cannot disprove an upward trial', () {
    auto.demand(active: 8, limit: 8, queued: 4);
    deliveries(24, 250000);
    auto.stall();
    auto.demand(active: 0, limit: 12, queued: 0);
    manual.advance(10000);
    auto.delivered(1);
    expect(auto.threads, 12);
  });

  test('a comfortable buffer tries fewer connections and keeps them when speed holds', () {
    beginLowerTrial();
    deliveries(40, 250000, ahead: 25);
    expect(auto.threads, 12);
  });

  test('a lower trial restores immediately if the wall-clock buffer falls below ten seconds', () {
    beginLowerTrial();
    expect(auto.buffer(ahead: 9, playing: true), isTrue);
    expect(auto.threads, 16);
  });

  test('a lower trial restores on a stall even inside the change cooldown', () {
    beginLowerTrial();
    expect(auto.stall(), isTrue);
    expect(auto.threads, 16);
  });

  test('a lower trial restores sustained throughput lost despite a comfortable buffer', () {
    beginLowerTrial();
    deliveries(40, 100000, ahead: 25);
    expect(auto.threads, 16);
  });

  test('a lower trial does not mistake a full-buffer idle tail for throughput loss', () {
    beginLowerTrial();
    auto.demand(active: 0, limit: 12, queued: 0);
    manual.advance(10000);
    auto.buffer(ahead: 25, playing: true);
    expect(auto.threads, 12);
  });

  test('pausing and a brief comfortable buffer do not begin a lower trial', () {
    auto.newSession();
    manual.advance(31000);
    auto.buffer(ahead: 25, playing: false);
    manual.advance(60000);
    auto.buffer(ahead: 25, playing: false);
    expect(auto.threads, 16);
    auto.buffer(ahead: 25, playing: true);
    manual.advance(29000);
    auto.buffer(ahead: 25, playing: true);
    expect(auto.threads, 16);
    auto.buffer(ahead: 19, playing: true);
    manual.advance(30000);
    auto.buffer(ahead: 25, playing: true);
    expect(auto.threads, 16);
  });

  test('pushback cancels a lower trial and cannot restore the refused level', () {
    beginLowerTrial();
    auto.pushback(status: 429);
    expect(auto.threads, 8);
    expect(auto.stall(), isFalse);
    manual.advance(3000);
    expect(auto.stall(), isFalse);
    expect(auto.threads, 8);
  });

  test('a new session discards its predecessor lower trial', () {
    beginLowerTrial();
    auto.newSession();
    expect(auto.threads, 16);
    expect(auto.stall(), isFalse);
    manual.advance(3000);
    auto.stall();
    expect(auto.threads, 24);
  });

  test('low-buffer pressure climbs', () {
    for (final step in <double>[0, 600, 600, 1100]) {
      manual.advance(step);
      auto
        ..activity()
        ..buffer(ahead: 3, playing: true);
    }
    expect(auto.threads, 12);
  });

  test('onChange reports steps', () {
    final seen = <int>[];
    auto.onChange = (threads, _, _) => seen.add(threads);
    auto.newSession();
    expect(seen, [16]);
  });

  test('onChange runs after the state changed', () {
    final seen = <int>[];
    auto.onChange = (threads, _, _) => seen.add(auto.threads * 100 + threads);
    auto.newSession();
    expect(seen, [1616]);
  });
}
