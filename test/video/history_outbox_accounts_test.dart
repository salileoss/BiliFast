import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bili_core/api.dart';
import 'package:bilifast/video/history_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> queue(HistoryOutbox outbox, int owner, int played, {String bvid = 'BV1a'}) async {
    try {
      await outbox.send(bvid, 1, played, () async => throw const BiliNetworkError('fixture-offline'), ownerMid: owner);
    } on BiliNetworkError {
      // The report is intentionally left pending.
    }
  }
  Future<HistoryPage> recent() async => const HistoryPage(items: [], next: null);

  test('the same video has a separate pending place for each owner', () async {
    final outbox = HistoryOutbox.memory();
    await queue(outbox, 101, 12);
    await queue(outbox, 202, 38);
    expect(outbox.reports.map((report) => (report.ownerMid, report.played)), [(101, 12), (202, 38)]);
    expect(outbox.holds('BV1a', 1, ownerMid: 101), isTrue);
    expect(outbox.holds('BV1a', 1, ownerMid: 202), isTrue);
    expect(outbox.holds('BV1a', 1), isFalse);
    final sent = <int>[];
    await outbox.flush(({required bvid, required cid, required playedTime}) async => sent.add(playedTime),
        recent: recent, ownerMid: 202);
    expect(sent, [38]);
    expect(outbox.reports.single.ownerMid, 101);
  });

  test('a queued report retains its original owner without sending after a session boundary', () async {
    final outbox = HistoryOutbox.memory();
    final gate = Completer<void>();
    final first = outbox.send('BV1blocker', 2, 1, () => gate.future, ownerMid: 101);
    var generation = 0;
    final captured = generation;
    var sent = false;
    final queued = outbox.send('BV1a', 1, 12, () async => sent = true,
        ownerMid: 101, isCurrent: () => generation == captured);
    generation = 2; // A -> B -> A still invalidates work from the first A session.
    gate.complete();
    await Future.wait([first, queued]);
    expect(sent, isFalse);
    expect(outbox.reports.single.ownerMid, 101);
    expect(outbox.reports.single.played, 12);
  });

  test('late A success cannot remove the same video queued for B', () async {
    final outbox = HistoryOutbox.memory();
    await queue(outbox, 101, 12);
    await queue(outbox, 202, 38);
    final gate = Completer<void>();
    var current = true;
    final sending = outbox.send('BV1a', 1, 15, () => gate.future,
        ownerMid: 101, isCurrent: () => current);
    current = false;
    gate.complete();
    await sending;
    expect(outbox.reports.map((report) => (report.ownerMid, report.played)), [(101, 12), (202, 38)]);
  });

  test('forgetting A suppresses its late network failure but preserves B', () async {
    final outbox = HistoryOutbox.memory();
    await queue(outbox, 202, 38);
    final gate = Completer<void>();
    final sending = outbox.send('BV1a', 1, 15, () => gate.future, ownerMid: 101);
    final checked = expectLater(sending, throwsA(isA<BiliNetworkError>()));
    outbox.removeOwner(101);
    gate.completeError(const BiliNetworkError('fixture-offline'));
    await checked;
    expect(outbox.reports.single.ownerMid, 202);
  });

  test('B can request a flush while A is out, without borrowing A\'s sender', () async {
    final outbox = HistoryOutbox.memory();
    await queue(outbox, 101, 12);
    await queue(outbox, 202, 38);
    final gate = Completer<void>();
    var aCurrent = true;
    final ownersSent = <int>[];
    final a = outbox.flush(({required bvid, required cid, required playedTime}) async {
      ownersSent.add(101);
      await gate.future;
    }, recent: recent, ownerMid: 101, isCurrent: () => aCurrent);
    await pumpEventQueue();
    aCurrent = false;
    final b = outbox.flush(({required bvid, required cid, required playedTime}) async => ownersSent.add(202),
        recent: recent, ownerMid: 202, isCurrent: () => true);
    gate.complete();
    await Future.wait([a, b]);
    expect(ownersSent, [101, 202]);
    expect(outbox.reports.single.ownerMid, 101);
  });

  test('owned queues survive restart and legacy unowned data is removed on disk', () async {
    final folder = Directory.systemTemp.createTempSync('owned-history-test');
    addTearDown(() => folder.deleteSync(recursive: true));
    final path = '${folder.path}/outbox.json';
    final now = DateTime.now();
    File(path).writeAsStringSync(jsonEncode([
      PendingReport(bvid: 'BV1a', cid: 1, played: 12, at: now, ownerMid: 101).toJson(),
      PendingReport(bvid: 'BV1a', cid: 1, played: 38, at: now, ownerMid: 202).toJson(),
      PendingReport(bvid: 'BV1legacy', cid: 2, played: 52, at: now).toJson(),
    ]));
    final restored = await HistoryOutbox.load(path);
    await restored.settle();
    expect(restored.reports.map((report) => report.ownerMid), [101, 202]);
    final again = await HistoryOutbox.load(path);
    expect(again.reports.map((report) => report.ownerMid), [101, 202]);
    expect(File(path).readAsStringSync(), isNot(contains('BV1legacy')));
  });
}
