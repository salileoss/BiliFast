import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';

/// Local, account-scoped feed exposure and deliberate viewing. No data is sent to a server.
class FeedPreferences {
  FeedPreferences.memory({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const seenFor = Duration(hours: 48);
  static const completedFor = Duration(days: 14);
  static const keepFor = Duration(days: 30);
  static const entriesPerAccount = 2000;
  static const accountLimit = 10;
  static const meaningfulSeconds = 30.0;

  final DateTime Function() _now;
  final _accounts = <String, Map<String, _Exposure>>{};
  String? _path;
  Timer? _saveTimer;
  Future<void> _writing = Future.value();
  DateTime? _lastPruned;
  int _revision = 0;
  int _savedRevision = 0;
  int _queuedRevision = 0;
  bool _disposed = false;

  static Future<FeedPreferences> load(String? path, {DateTime Function()? now}) async {
    final store = FeedPreferences.memory(now: now).._path = path;
    if (path == null) return store;
    try {
      final file = File(path);
      if (!await file.exists()) return store;
      if (await file.length() > 8 * 1024 * 1024) throw const FormatException('oversized preferences');
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, Object?> || data['version'] != 1) return store;
      final accounts = data['accounts'];
      if (accounts is! Map<String, Object?>) return store;
      for (final account in accounts.entries) {
        if (account.key != 'guest' && (int.tryParse(account.key) ?? 0) <= 0) continue;
        if (account.value is! List) continue;
        final rows = <String, _Exposure>{};
        for (final row in account.value as List) {
          final entry = _Exposure.decode(row, store._now());
          if (entry != null) rows[entry.bvid] = entry;
        }
        final sorted = rows.values.toList()..sort((a, b) => a.updated.compareTo(b.updated));
        store._accounts[account.key] = {
          for (final entry in sorted.skip(sorted.length > entriesPerAccount ? sorted.length - entriesPerAccount : 0))
            entry.bvid: entry,
        };
      }
      store._prune(force: true);
      // Expired, invalid and excess entries must leave disk even if this launch shows no feed.
      store._revision = 1;
      await store.flush();
    } catch (error) {
      // Error text can contain saved data or a local path.
      Logger.shared.warn(LogCategory.app, 'feed preferences unreadable', {'error': '${error.runtimeType}'});
    }
    return store;
  }

  void recordSeen({required int? accountMid, required String bvid, required int ownerMid}) {
    if (_disposed || bvid.isEmpty) return;
    final entry = _entry(accountMid, bvid, ownerMid);
    entry.seen = _now().millisecondsSinceEpoch;
    _changed();
  }

  /// [seconds] is newly watched time, excluding seeks and replayed intervals.
  void recordWatch({
    required int? accountMid,
    required String bvid,
    required int ownerMid,
    required double seconds,
    bool completed = false,
  }) {
    if (_disposed || bvid.isEmpty || !seconds.isFinite || seconds < 0 || (seconds == 0 && !completed)) return;
    final entry = _entry(accountMid, bvid, ownerMid);
    final now = _now().millisecondsSinceEpoch;
    if (entry.watchedAt == null || now - entry.watchedAt! >= keepFor.inMilliseconds) entry.watched = 0;
    if (entry.completed != null && now - entry.completed! >= keepFor.inMilliseconds) entry.completed = null;
    entry.watched = (entry.watched + seconds).clamp(0, 24 * 60 * 60).toDouble();
    entry.watchedAt = now;
    entry.seen = now;
    if (completed && entry.watched > 0) entry.completed = entry.seen;
    _changed();
  }

  bool recentlySeen(String bvid, {required int? accountMid}) => _tier(bvid, accountMid) != 0;

  int unseenCount(List<FeedCard> cards, {required int? accountMid}) => {
    for (final card in cards)
      if (!recentlySeen(card.bvid, accountMid: accountMid)) card.bvid,
  }.length;

  /// Prefer unseen videos, then spread creators while retaining the server's relevance order.
  List<FeedCard> select(List<FeedCard> cards, {required int? accountMid, required int limit}) {
    if (limit <= 0) return [];
    _prune();
    final affinity = <int, double>{};
    for (final entry in _accounts[_key(accountMid)]?.values ?? <_Exposure>[]) {
      if (entry.watchedAt == null || _now().millisecondsSinceEpoch - entry.watchedAt! >= keepFor.inMilliseconds) continue;
      if (entry.owner <= 0 || entry.watched < meaningfulSeconds && entry.completed == null) continue;
      affinity[entry.owner] = ((affinity[entry.owner] ?? 0) + 1).clamp(0, 2).toDouble();
    }
    final seen = <String>{};
    final remaining = [
      for (var i = 0; i < cards.length; i++)
        if (seen.add(cards[i].bvid)) (card: cards[i], index: i, tier: _tier(cards[i].bvid, accountMid)),
    ];
    remaining.sort((a, b) {
      final tier = a.tier.compareTo(b.tier);
      if (tier != 0) return tier;
      final score = (a.index - (affinity[a.card.ownerMid] ?? 0) * 1.05).compareTo(
        b.index - (affinity[b.card.ownerMid] ?? 0) * 1.05,
      );
      return score != 0 ? score : a.index.compareTo(b.index);
    });
    final chosen = <FeedCard>[];
    while (remaining.isNotEmpty && chosen.length < limit) {
      final tier = remaining.first.tier;
      final recentCreators = <int, int>{};
      for (final card in chosen.skip(chosen.length > 9 ? chosen.length - 9 : 0)) {
        if (card.ownerMid > 0) recentCreators.update(card.ownerMid, (n) => n + 1, ifAbsent: () => 1);
      }
      var at = remaining.indexWhere(
        (item) => item.tier == tier && (item.card.ownerMid <= 0 || (recentCreators[item.card.ownerMid] ?? 0) < 2),
      );
      // A narrow candidate pool still fills the feed, in relevance order.
      if (at < 0) at = 0;
      chosen.add(remaining.removeAt(at).card);
    }
    return chosen;
  }

  static String _key(int? accountMid) => accountMid != null && accountMid > 0 ? '$accountMid' : 'guest';

  _Exposure _entry(int? accountMid, String bvid, int ownerMid) {
    final key = _key(accountMid);
    final rows = _accounts.remove(key) ?? <String, _Exposure>{};
    _accounts[key] = rows;
    final entry = rows.remove(bvid) ?? _Exposure(bvid, ownerMid > 0 ? ownerMid : 0, _now().millisecondsSinceEpoch);
    if (ownerMid > 0) entry.owner = ownerMid;
    entry.updated = _now().millisecondsSinceEpoch;
    rows[bvid] = entry;
    return entry;
  }

  int _tier(String bvid, int? accountMid) {
    final entry = _accounts[_key(accountMid)]?[bvid];
    if (entry == null) return 0;
    final now = _now().millisecondsSinceEpoch;
    if (entry.completed case final completed? when now - completed < completedFor.inMilliseconds) return 2;
    if (entry.seen case final seen? when now - seen < seenFor.inMilliseconds) return 1;
    return 0;
  }

  void _changed() {
    _prune();
    _revision++;
    if (_path != null) _saveTimer ??= Timer(const Duration(seconds: 1), () => unawaited(flush()));
  }

  void _prune({bool force = false}) {
    final now = _now();
    if (force || _lastPruned == null || now.difference(_lastPruned!) >= const Duration(minutes: 1)) {
      final cutoff = now.subtract(keepFor).millisecondsSinceEpoch;
      for (final rows in _accounts.values) {
        rows.removeWhere((_, entry) => entry.updated < cutoff);
      }
      _accounts.removeWhere((_, rows) => rows.isEmpty);
      _lastPruned = now;
    }
    for (final rows in _accounts.values) {
      while (rows.length > entriesPerAccount) {
        rows.remove(rows.keys.first);
      }
    }
    while (_accounts.length > accountLimit) {
      // Loading may encounter accounts in any order; last activity determines retention.
      final oldest = _accounts.entries.reduce((a, b) =>
          a.value.values.last.updated <= b.value.values.last.updated ? a : b);
      _accounts.remove(oldest.key);
    }
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final path = _path;
    if (path == null || _revision == _savedRevision || _revision == _queuedRevision) return _writing;
    final revision = _revision;
    final data = jsonEncode({
      'version': 1,
      'accounts': {
        for (final account in _accounts.entries) account.key: [for (final entry in account.value.values) entry.toJson()],
      },
    });
    _queuedRevision = revision;
    _writing = _writing.then((_) async {
      final temporary = File('$path.tmp');
      try {
        await temporary.parent.create(recursive: true);
        await temporary.writeAsString(data, flush: true);
        await temporary.rename(path);
        _savedRevision = revision;
      } catch (error) {
        if (_queuedRevision == revision) _queuedRevision = _savedRevision;
        Logger.shared.warn(LogCategory.app, 'feed preferences save failed', {'error': '${error.runtimeType}'});
        try {
          if (await temporary.exists()) await temporary.delete();
        } catch (_) {
          // A failed cleanup must not interrupt playback or refresh.
        }
      }
    });
    return _writing;
  }

  void dispose() {
    _disposed = true;
    unawaited(flush());
  }
}

class _Exposure {
  _Exposure(this.bvid, this.owner, this.updated);

  final String bvid;
  int owner;
  int updated;
  int? seen;
  int? completed;
  int? watchedAt;
  double watched = 0;

  static _Exposure? decode(Object? row, DateTime now) {
    if (row is! Map<String, Object?>) return null;
    final bvid = row['bvid'];
    final owner = row['owner'];
    final updated = row['updated'];
    final seen = row['seen'];
    final completed = row['completed'];
    final watched = row['watched'];
    final watchedAt = row['watchedAt'];
    final current = now.millisecondsSinceEpoch;
    if (bvid is! String || bvid.isEmpty || bvid.length > 64 || owner is! int || owner < 0 || updated is! int ||
        updated < current - FeedPreferences.keepFor.inMilliseconds || updated > current ||
        seen != null && (seen is! int || seen > current || seen < 0) ||
        completed != null && (completed is! int || completed > current || completed < 0) ||
        watchedAt != null && (watchedAt is! int || watchedAt > current || watchedAt < 0) ||
        watched is! num || !watched.isFinite || watched < 0) {
      return null;
    }
    return _Exposure(bvid, owner, updated)
      ..seen = seen as int?
      ..completed = completed as int?
      ..watchedAt = watchedAt as int?
      ..watched = watched.clamp(0, 24 * 60 * 60).toDouble();
  }

  Map<String, Object?> toJson() => {
    'bvid': bvid,
    'owner': owner,
    'updated': updated,
    'seen': seen,
    'completed': completed,
    'watched': watched,
    'watchedAt': watchedAt,
  };
}
