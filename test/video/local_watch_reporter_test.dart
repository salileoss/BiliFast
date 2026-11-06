import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bili_core/shared.dart';
import 'package:bilifast/home/feed_preferences.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/player/bili_player.dart';
import 'package:bilifast/video/local_watch_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../playback/fakes.dart';
import '../support/fake_player.dart';

class _Signals extends FeedPreferences {
  _Signals() : super.memory();

  final batches = <({int? account, String bvid, int uploader, double seconds, bool completed})>[];

  @override
  void recordWatch({required int? accountMid, required String bvid, required int ownerMid,
      required double seconds, bool completed = false}) {
    batches.add((account: accountMid, bvid: bvid, uploader: ownerMid, seconds: seconds, completed: completed));
  }
}

void main() {
  late FakePlayer player;
  late PlaybackController controller;
  late CannedHttp http;
  late ManualClock time;
  late _Signals signals;
  late LocalWatchReporter reporter;
  var active = true;
  var current = true;

  setUp(() async {
    player = FakePlayer();
    http = Canned.http();
    time = ManualClock(10000);
    active = true;
    current = true;
    signals = _Signals();
    final now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 1000) * 1000);
    final client = BiliClient(transport: http, cookies: CookieJar(Canned.cookies), now: () => now,
      logger: Logger(session: 'test'));
    controller = PlaybackController(client: client, engine: FakeEngine(), player: player, clock: time.clock,
      now: () => now, startTimer: FakeTimers().start, logger: Logger(session: 'test'));
    await controller.openVideo('BV1GJ411x7h7', cid: 137649199, start: 0);
    reporter = LocalWatchReporter(controller: controller, preferences: signals, accountMid: 101,
      ownerMid: 77, isCurrent: () => current, canCount: () => active);
    player.emit(const StatusChanged(PlayerStatus.playing));
    addTearDown(() {
      reporter.dispose();
      controller.dispose();
      signals.dispose();
    });
  });

  void position(double seconds) {
    time.advance(1000);
    player.emit(PositionChanged(seconds: seconds, hostMs: time.clock.nowMs(), rate: 1));
  }

  test('real inline viewing is local, batched, and remains owned by its initiating account', () async {
    position(0);
    for (var second = 1; second <= 35; second++) {
      position(second.toDouble());
    }
    expect(signals.batches.map((batch) => batch.seconds), [15, 15]);
    player.emit(const StatusChanged(PlayerStatus.paused));
    expect(signals.batches.map((batch) => batch.seconds), [15, 15, 5]);
    expect(signals.batches.map((batch) => batch.account).toSet(), {101});
    expect(signals.batches.map((batch) => batch.bvid).toSet(), {'BV1GJ411x7h7'});
    expect(http.to('/x/click-interface/web/heartbeat'), isEmpty);
    await signals.flush();
  });

  test('stale account callbacks cannot save or accumulate into the next account', () {
    position(0);
    position(1);
    current = false;
    for (var second = 2; second <= 35; second++) {
      position(second.toDouble());
    }
    reporter.dispose();
    expect(signals.batches, isEmpty);
  });

  test('hidden time and native status lag after pause do not become watch time', () {
    position(0);
    position(1);
    active = false;
    reporter.suspend();
    for (var second = 2; second <= 20; second++) {
      position(second.toDouble());
    }
    active = true;
    position(21);
    position(22);
    reporter.dispose();
    expect(signals.batches.map((batch) => batch.seconds), [1, 1]);
  });

  test('buffering and seeks flush actual viewing without manufacturing progress', () {
    position(0);
    position(1);
    player.emit(const StatusChanged(PlayerStatus.buffering));
    position(2);
    position(3);
    player.emit(const StatusChanged(PlayerStatus.playing));
    reporter.suspend();
    position(300);
    position(301);
    reporter.dispose();
    expect(signals.batches.map((batch) => batch.seconds), [1, 1]);
    expect(signals.batches.every((batch) => !batch.completed), isTrue);
  });
}
