import 'dart:convert';
import 'dart:io';

import 'package:bili_core/api.dart';
import 'package:bilifast/home/feed_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feed_fakes.dart';

FeedCard card(String bvid, int owner) => FeedCard.fromJson({
  ...feedItem(bvid),
  'owner': {'mid': owner, 'name': 'Uploader'},
});

List<String> selected(FeedPreferences store, List<FeedCard> cards, {int? mid = 1, int? limit}) =>
    store.select(cards, accountMid: mid, limit: limit ?? cards.length).map((card) => card.bvid).toList();

void main() {
  late DateTime now;
  late FeedPreferences store;

  setUp(() {
    now = DateTime.utc(2026, 11, 6, 12);
    store = FeedPreferences.memory(now: () => now);
  });
  tearDown(() => store.dispose());

  test('seen memory is per account and guest, and selecting never records exposure', () {
    final cards = [card('seen', 7), card('fresh', 8)];
    store.recordSeen(accountMid: 1, bvid: 'seen', ownerMid: 7);
    expect(selected(store, cards), ['fresh', 'seen']);
    expect(selected(store, cards, mid: 2), ['seen', 'fresh']);
    expect(selected(store, cards, mid: null), ['seen', 'fresh']);
    expect(store.unseenCount(cards, accountMid: 1), 1);
    expect(store.unseenCount(cards, accountMid: 2), 2);
    expect(store.unseenCount(cards, accountMid: null), 2);
    store.recordSeen(accountMid: null, bvid: 'fresh', ownerMid: 8);
    expect(selected(store, cards, mid: null), ['seen', 'fresh']);
    expect(store.recentlySeen('fresh', accountMid: 1), isFalse);
  });

  test('recently completed videos follow seen videos and expire after fourteen days', () {
    store.recordSeen(accountMid: 1, bvid: 'seen', ownerMid: 1);
    store.recordWatch(accountMid: 1, bvid: 'complete', ownerMid: 2, seconds: 8, completed: true);
    final cards = [card('complete', 2), card('seen', 1), card('fresh', 3)];
    expect(selected(store, cards), ['fresh', 'seen', 'complete']);
    now = now.add(FeedPreferences.seenFor);
    expect(store.recentlySeen('seen', accountMid: 1), isFalse);
    expect(store.recentlySeen('complete', accountMid: 1), isTrue);
    expect(store.unseenCount(cards, accountMid: 1), 2);
    now = now.add(FeedPreferences.completedFor - FeedPreferences.seenFor);
    expect(store.recentlySeen('complete', accountMid: 1), isFalse);
    expect(store.unseenCount(cards, accountMid: 1), 3);
  });

  test('deduplicates candidates and unseen count, retains useful narrow pools', () {
    final cards = [card('one', 1), card('one', 1), card('two', 1), card('three', 1)];
    expect(store.unseenCount(cards, accountMid: 1), 3);
    expect(selected(store, cards, limit: 20), ['one', 'two', 'three']);
    expect(selected(store, cards, limit: 0), isEmpty);
    for (final entry in cards) {
      store.recordSeen(accountMid: 1, bvid: entry.bvid, ownerMid: entry.ownerMid);
    }
    expect(selected(store, cards), ['one', 'two', 'three']);
  });

  test('spreads uploaders while unknown uploaders retain their server order', () {
    final cards = [
      for (var i = 0; i < 5; i++) card('a$i', 1),
      for (var i = 0; i < 3; i++) card('b$i', 2),
      for (var i = 0; i < 3; i++) card('c$i', 3),
    ];
    expect(selected(store, cards, limit: 6), ['a0', 'a1', 'b0', 'b1', 'c0', 'c1']);
    final unknown = [for (var i = 0; i < 4; i++) card('unknown$i', 0), card('known', 1)];
    expect(selected(store, unknown), unknown.map((card) => card.bvid));
  });

  test('novelty wins over creator variety when only seen alternatives remain', () {
    store.recordSeen(accountMid: 1, bvid: 'seen', ownerMid: 2);
    final cards = [card('a0', 1), card('a1', 1), card('a2', 1), card('seen', 2)];
    expect(selected(store, cards), ['a0', 'a1', 'a2', 'seen']);
  });

  test('brief autoplay adds no affinity, meaningful viewing nudges but cannot dominate', () {
    final cards = [card('first', 1), card('preferred', 2), card('last', 3)];
    store.recordWatch(accountMid: 1, bvid: 'seed', ownerMid: 2, seconds: 5);
    expect(selected(store, cards), ['first', 'preferred', 'last']);
    store.recordWatch(accountMid: 1, bvid: 'seed', ownerMid: 2, seconds: 25);
    expect(selected(store, cards), ['preferred', 'first', 'last']);
    expect(selected(store, cards, mid: 2), ['first', 'preferred', 'last']);
    store.recordSeen(accountMid: 1, bvid: 'preferred', ownerMid: 2);
    expect(selected(store, cards), ['first', 'last', 'preferred']);
    final many = [
      for (var i = 0; i < 4; i++) card('plain$i', i + 10),
      card('distant', 2),
    ];
    for (var i = 0; i < 10; i++) {
      store.recordWatch(accountMid: 1, bvid: 'seed$i', ownerMid: 2, seconds: 300);
    }
    expect(selected(store, many).indexOf('distant'), 2, reason: 'capped boost moves at most two places');
  });

  test('short completed viewing contributes affinity without a long-watch requirement', () {
    store.recordWatch(accountMid: 1, bvid: 'seed', ownerMid: 2, seconds: 5, completed: true);
    expect(selected(store, [card('first', 1), card('short-creator', 2)]), ['short-creator', 'first']);
  });

  test('invalid watch time is ignored and long-stale affinity expires despite renewed exposure', () {
    store.recordWatch(accountMid: 1, bvid: 'invalid', ownerMid: 2, seconds: double.nan);
    expect(store.recentlySeen('invalid', accountMid: 1), isFalse);
    store.recordWatch(accountMid: 1, bvid: 'seed', ownerMid: 2, seconds: 30);
    now = now.add(const Duration(days: 29));
    store.recordSeen(accountMid: 1, bvid: 'seed', ownerMid: 2);
    now = now.add(const Duration(days: 2));
    expect(selected(store, [card('first', 1), card('other', 2)]), ['first', 'other']);
  });

  test('memory is bounded per account and old entries expire', () {
    for (var i = 0; i <= FeedPreferences.entriesPerAccount; i++) {
      store.recordSeen(accountMid: 1, bvid: 'v$i', ownerMid: 1);
    }
    expect(store.recentlySeen('v0', accountMid: 1), isFalse);
    expect(store.recentlySeen('v1', accountMid: 1), isTrue);
    now = now.add(FeedPreferences.keepFor + const Duration(seconds: 1));
    store.recordSeen(accountMid: 1, bvid: 'new', ownerMid: 1);
    expect(store.recentlySeen('v1', accountMid: 1), isFalse);
    expect(store.recentlySeen('new', accountMid: 1), isTrue);
  });

  group('persistence', () {
    late Directory directory;
    late String path;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('bilifast-feed-preferences-');
      path = '${directory.path}/preferences.json';
    });
    tearDown(() async => directory.delete(recursive: true));

    test('reloads separate accounts and coalesces writes to the newest snapshot', () async {
      final disk = await FeedPreferences.load(path, now: () => now);
      disk.recordSeen(accountMid: 1, bvid: 'one', ownerMid: 1);
      final first = disk.flush();
      disk.recordWatch(accountMid: 2, bvid: 'two', ownerMid: 2, seconds: 12, completed: true);
      final second = disk.flush();
      await Future.wait([first, second]);
      disk.dispose();
      final reloaded = await FeedPreferences.load(path, now: () => now);
      expect(reloaded.recentlySeen('one', accountMid: 1), isTrue);
      expect(reloaded.recentlySeen('one', accountMid: 2), isFalse);
      expect(reloaded.recentlySeen('two', accountMid: 2), isTrue);
      now = now.add(const Duration(days: 3));
      expect(reloaded.recentlySeen('one', accountMid: 1), isFalse);
      expect(reloaded.recentlySeen('two', accountMid: 2), isTrue);
      reloaded.dispose();
      expect(await File('$path.tmp').exists(), isFalse);
    });

    test('corrupt files recover and invalid rows do not discard valid ones', () async {
      await File(path).writeAsString('{bad json');
      final empty = await FeedPreferences.load(path, now: () => now);
      expect(empty.unseenCount([card('valid', 1)], accountMid: 1), 1);
      empty.dispose();
      final timestamp = now.millisecondsSinceEpoch;
      await File(path).writeAsString(jsonEncode({
        'version': 1,
        'accounts': {
          '1': [
            null,
            {'bvid': 'bad', 'owner': -1, 'updated': timestamp, 'watched': 0},
            {'bvid': 'future', 'owner': 1, 'updated': timestamp + 1, 'seen': timestamp + 1, 'watched': 0},
            {'bvid': 'valid', 'owner': 1, 'updated': timestamp, 'seen': timestamp, 'watched': 0},
          ],
          'not-an-account': <Object?>[],
        },
      }));
      final recovered = await FeedPreferences.load(path, now: () => now);
      expect(recovered.recentlySeen('valid', accountMid: 1), isTrue);
      expect(recovered.recentlySeen('bad', accountMid: 1), isFalse);
      expect(recovered.recentlySeen('future', accountMid: 1), isFalse);
      recovered.dispose();
      final sanitized = jsonDecode(await File(path).readAsString()) as Map<String, Object?>;
      final accounts = sanitized['accounts'] as Map<String, Object?>;
      expect(accounts.keys, ['1']);
      expect((accounts['1'] as List<Object?>).length, 1, reason: 'invalid rows leave disk during load');
    });

    test('loading removes expired data from disk even without a new exposure', () async {
      final expired = now.subtract(FeedPreferences.keepFor + const Duration(seconds: 1)).millisecondsSinceEpoch;
      await File(path).writeAsString(jsonEncode({
        'version': 1,
        'accounts': {
          '1': [
            {'bvid': 'expired', 'owner': 1, 'updated': expired, 'seen': expired, 'watched': 0},
          ],
        },
      }));
      final disk = await FeedPreferences.load(path, now: () => now);
      final saved = jsonDecode(await File(path).readAsString()) as Map<String, Object?>;
      expect(saved['accounts'], isEmpty);
      disk.dispose();
    });

    test('retains at most ten accounts and keeps the most recently active ones', () async {
      final disk = await FeedPreferences.load(path, now: () => now);
      for (var i = 1; i <= FeedPreferences.accountLimit + 1; i++) {
        disk.recordSeen(accountMid: i, bvid: 'v$i', ownerMid: i);
        now = now.add(const Duration(seconds: 1));
      }
      await disk.flush();
      disk.dispose();
      final reloaded = await FeedPreferences.load(path, now: () => now);
      expect(reloaded.recentlySeen('v1', accountMid: 1), isFalse);
      expect(reloaded.recentlySeen('v2', accountMid: 2), isTrue);
      reloaded.dispose();
    });

    test('write failures retain memory and can be retried without failing the caller', () async {
      await Directory(path).create();
      final disk = await FeedPreferences.load(path, now: () => now);
      disk.recordSeen(accountMid: 1, bvid: 'one', ownerMid: 1);
      await disk.flush();
      expect(disk.recentlySeen('one', accountMid: 1), isTrue);
      await Directory(path).delete();
      await disk.flush();
      final reloaded = await FeedPreferences.load(path, now: () => now);
      expect(reloaded.recentlySeen('one', accountMid: 1), isTrue);
      disk.dispose();
      reloaded.dispose();
    });

    test('dispose flushes pending exposure and ignores later records', () async {
      final disk = await FeedPreferences.load(path, now: () => now);
      disk.recordSeen(accountMid: 1, bvid: 'kept', ownerMid: 1);
      disk.dispose();
      disk.recordSeen(accountMid: 1, bvid: 'ignored', ownerMid: 1);
      await disk.flush();
      final reloaded = await FeedPreferences.load(path, now: () => now);
      expect(reloaded.recentlySeen('kept', accountMid: 1), isTrue);
      expect(reloaded.recentlySeen('ignored', accountMid: 1), isFalse);
      reloaded.dispose();
    });
  });
}
