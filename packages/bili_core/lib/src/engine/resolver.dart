// Port of Bilibili-thread-ripper (see LICENSE-BTR.txt), by way of BiliNative's Resolver.swift.

import 'dart:math';

import '../shared/byte_range.dart';
import '../shared/clock.dart';
import 'ban_list.dart';
import 'node_catalog.dart';
import 'node_memory.dart';
import 'node_stats.dart';
import 'playback_engine.dart';

final class _Health {
  int failures = 0;
  double blockedUntil = 0;
}

/// Speed knowledge per node and file, without the query: a fresh signature is the same route.
final class _Route {
  double lastSuccessAt = 0;
  double lastMeasuredAt = 0;
  double bps = 0;
}

/// BTR `createResolver`, one per track (port of Resolver.swift).
final class Resolver {
  Resolver({
    required this._primary,
    required this._backups,
    required this.mode,
    this.policy = MediaURLPolicy.bilibili,
    this.bans,
    MonotonicClock? clock,
    this.priors = NodePriors.empty,
    this.exploreInHurry = true,
    this.nodes,
  }) : _clock = clock ?? MonotonicClock.system;

  /// A node left out for being slow goes back to the untested ones after this and gets another try.
  static const measurementTTL = 90000.0;

  /// Akamai's damaged copy of one file (2026-10-16) failed from the first missing byte to the end of that MiB
  /// and served the next MiB whole, so an edge's damage is taken to end at the next MiB boundary.
  static const damageBlock = 1 << 20;

  /// Damage on more blocks of one file than this is a failing node, not a damaged copy.
  static const damagedBlockLimit = 2;

  final NodeMode mode;
  final MediaURLPolicy policy;
  final BanList? bans;
  final MonotonicClock _clock;

  /// What earlier sessions measured (`NodeMemory.priors`). A node with a prior speed counts as measured until this
  /// session measures it: no warm-up range goes wide for it, no range explores it, and [speed] gives the prior's.
  final NodePriors priors;

  /// Shared latency and body-speed measurements across both tracks. Auto mode ranks the actual
  /// request size against these estimates; manual modes retain their original speed ordering.
  final NodeStats? nodes;

  /// Off: a range in a hurry goes only to measured (or remembered) nodes, so unknown and stale ones are explored on
  /// prefetch ranges alone. On (Swift): every range carries its exploration slots.
  final bool exploreInHurry;

  String _primary;
  List<String> _backups;

  /// [allURLs] for the current addresses: rebuilding it parses and checks every signed address.
  List<String>? _all;
  var _health = <String, _Health>{};
  final _routes = <String, _Route>{};
  int _cursor = 0;
  int _mediaRangeCount = 0;
  int _rangeCursor = 0;

  /// Per route: the first missing byte seen in each damaged block of that node's copy, by block index.
  var _damage = <String, Map<int, int>>{};

  /// Nodes that have sent bytes, even in copies that were cut or cancelled.
  final _streamed = <String>{};

  void replaceURLs({required String primary, required List<String> backups}) {
    _primary = primary;
    _backups = backups;
    _all = null;
  }

  /// After a network change, failures seen on the old path say nothing about the new one. A new
  /// interface also invalidates the measured speeds, so the next ranges measure wide again.
  void resetHealth({required bool clearMeasurements}) {
    _health = {};
    _damage = {};
    if (!clearMeasurements) return;
    for (final route in _routes.values) {
      route
        ..bps = 0
        ..lastMeasuredAt = 0;
    }
    _mediaRangeCount = 0;
  }

  List<String> allURLs() => List.of(_allURLs);

  List<String> get _allURLs => _all ??= List.unmodifiable(
    NodeCatalog.representationURLs(primary: _primary, backups: _backups, mode: mode, policy: policy),
  );

  /// Banned addresses are left out, unless that would leave none at all.
  List<String> urls() => List.of(_usable());

  List<String> _usable() => _unbanned(_allURLs);

  bool allows(String url) => bans?.allows(url) ?? true;

  List<String> _unbanned(List<String> list) {
    final bans = this.bans;
    if (bans == null) return list;
    final allowed = list.where(bans.allows).toList();
    return allowed.isEmpty ? list : allowed;
  }

  static String routeKey(String url) => NodeCatalog.routeKey(url);

  bool _measuredNow(String url, double now) {
    final route = _routes[routeKey(url)];
    return route != null && route.lastMeasuredAt > 0 && now - route.lastMeasuredAt < measurementTTL;
  }

  /// The prior's speed in this class's units, 0 without one.
  double _priorBps(String url) => priors.isEmpty ? 0 : priors.of(NodeCatalog.nodeKey(url))?.routeBps ?? 0;

  /// Measured within [measurementTTL], remembered from earlier sessions, or shared by the other track
  /// in Auto mode. The shared stats are reset by the session when the network changes.
  bool _known(String url, double now) =>
      _measuredNow(url, now) || _priorBps(url) > 0 || (mode is AutoNodes && (nodes?.isKnown(url) ?? false));

  bool _open(String url, double now) => (_health[url]?.blockedUntil ?? 0) <= now;

  /// Proven addresses first, then by speed: this session's measurement while fresh, else the prior's, else the
  /// stale measurement. Auto compares expected completion time first. Stable (List.sort does not promise it),
  /// so equally fast nodes keep the catalog's order.
  List<String> _sortedFasterFirst(Iterable<String> urls, {int bytes = NodePrior.routeReferenceBytes}) {
    final list = urls.toList();
    final now = _clock.nowMs();
    final proven = <bool>[];
    final speeds = <double>[];
    final finishes = <double>[];
    for (final url in list) {
      final route = _routes[routeKey(url)];
      proven.add((route?.lastSuccessAt ?? 0) > 0);
      final prior = _measuredNow(url, now) ? 0.0 : _priorBps(url);
      speeds.add(prior > 0 ? prior : route?.bps ?? 0);
      if (mode is AutoNodes) {
        final remembered = priors.of(NodeCatalog.nodeKey(url));
        final expected = nodes?.expectedMs(url, pieceBytes: bytes);
        finishes.add(expected ??
            (remembered != null && remembered.bps > 0
                ? remembered.ttfbMs + bytes * 1000 / remembered.bps
                : _measuredNow(url, now) && (route?.bps ?? 0) > 0
                    ? bytes * 1000 / route!.bps
                    : double.infinity));
      }
    }
    final order = List<int>.generate(list.length, (index) => index)
      ..sort((a, b) {
        if (mode is AutoNodes) {
          final byFinish = finishes[a].compareTo(finishes[b]);
          if (byFinish != 0) return byFinish;
        }
        if (proven[a] != proven[b]) return proven[a] ? -1 : 1;
        final bySpeed = speeds[b].compareTo(speeds[a]);
        return bySpeed != 0 ? bySpeed : a.compareTo(b);
      });
    return [for (final index in order) list[index]];
  }

  List<String> ordered({int pieceIndex = 0, Set<String> excluding = const {}}) {
    final list = _usable().where((url) => !excluding.contains(url)).toList();
    final now = _clock.nowMs();
    final available = list.where((url) => _open(url, now)).toList();
    final pool = available.isEmpty ? list : available;
    if (pool.isEmpty) return const [];
    final offset = (_cursor + pieceIndex) % pool.length;
    _cursor = (_cursor + 1) % pool.length;
    return [...pool.sublist(offset), ...pool.sublist(0, offset)];
  }

  /// The nodes for one media range. The first ranges (four overseas, one mainland) go wide to
  /// measure; afterwards measured nodes carry the work, fastest first, and one unmeasured or
  /// stale node rides along per range as exploration. With priors, remembered nodes count as
  /// measured and the warm-up is skipped. A [hurried] range explores nothing when [exploreInHurry]
  /// is off: it goes to the known nodes once two are known (one alone would carry every piece).
  /// Auto limits the first range to four nodes and later adds only one unknown node to the known set.
  List<String> rangeCandidates({bool hurried = false, int bytes = NodePrior.routeReferenceBytes}) {
    final list = _usable();
    final now = _clock.nowMs();
    final automatic = mode is AutoNodes;
    final warmup = mode is MainlandNodes || automatic ? 1 : 4;
    final pool = _sortedFasterFirst(list.where((url) => _open(url, now)), bytes: bytes);
    if (pool.isEmpty) return automatic ? _sortedFasterFirst(list, bytes: bytes).take(4).toList() : List.of(list);
    final width = min(automatic ? 4 : (_mediaRangeCount == 0 ? pool.length : 6), pool.length);
    if (hurried && !exploreInHurry) {
      final known = pool.where((url) => _known(url, now)).take(width).toList();
      if (known.length >= 2) {
        _mediaRangeCount += 1;
        return known;
      }
    }
    final remembered = pool.any((url) => _priorBps(url) > 0 || (automatic && (nodes?.isKnown(url) ?? false)));
    List<String> selected;
    if (_mediaRangeCount < warmup && !remembered) {
      selected = pool.take(width).toList();
      _rangeCursor = width % pool.length;
    } else {
      final measured = pool.where((url) => _known(url, now)).toList();
      final rest = pool.where((url) => !_known(url, now)).toList();
      final places = min(rest.length, automatic ? 1 : max(1, width - measured.length));
      final explore = [for (var index = 0; index < places; index++) rest[(_rangeCursor + index) % rest.length]];
      _rangeCursor = (_rangeCursor + places) % max(1, pool.length);
      selected = [...measured.take(max(0, width - explore.length)), ...explore];
      if (!automatic) {
        for (final url in pool) {
          if (selected.length >= min(3, pool.length)) break;
          if (!selected.contains(url)) selected.add(url);
        }
      }
    }
    _mediaRangeCount++;
    return selected;
  }

  /// The first request of a track races Bilibili's own addresses too (not in custom mode).
  List<String> startupCandidates() {
    final now = _clock.nowMs();
    final originals = mode is CustomNodes ? const <String>[] : [_primary, ..._backups].where(policy.allowsURL);
    final candidates = _unbanned(NodeCatalog.deduplicated([...originals, ..._allURLs]));
    final open = candidates.where((url) => _open(url, now));
    return (mode is AutoNodes ? _sortedFasterFirst(open, bytes: 8 * 1024) : open).take(8).toList();
  }

  List<String> rescueCandidates() {
    final now = _clock.nowMs();
    return _sortedFasterFirst(_usable().where((url) => _open(url, now)), bytes: 128 * 1024);
  }

  /// With `BanList.probation` on, a banned node's address for one backup copy of [piece] once that node's turn has
  /// come (taking the turn), else null. Never for a first copy, and never in a hurry: the player is waiting, and a
  /// node that failed twice in a row is the likeliest to fail again. A success lifts the ban (`BanList.success`).
  String? probationCopy(ByteRange piece, {bool hurried = false}) {
    final bans = this.bans;
    if (hurried || bans == null || bans.probation == null) return null;
    for (final url in _allURLs) {
      if (bans.allows(url) || avoids(url, piece) || !bans.probationDue(url)) continue;
      bans.takeProbation(url);
      return url;
    }
    return null;
  }

  void success(String url, {required double bps}) {
    bans?.success(url);
    final now = _clock.nowMs();
    _health.remove(url);
    final route = _routes.putIfAbsent(routeKey(url), _Route.new);
    route.lastSuccessAt = now;
    if (bps > 0) {
      route
        ..lastMeasuredAt = now
        ..bps = route.bps > 0 ? route.bps * 0.65 + bps * 0.35 : bps;
    }
  }

  /// The speed of a transfer cut off before its end (it lost a race): the node's speed, not proof
  /// that the address works.
  void sample(String url, {required double bps}) {
    if (bps <= 0) return;
    final route = _routes.putIfAbsent(routeKey(url), _Route.new);
    route
      ..lastMeasuredAt = _clock.nowMs()
      ..bps = route.bps > 0 ? route.bps * 0.65 + bps * 0.35 : bps;
  }

  /// The node's copy of this file is known to be damaged somewhere in [range].
  bool avoids(String url, ByteRange range) {
    final blocks = _damage[routeKey(url)];
    if (blocks == null) return false;
    return blocks.entries.any((entry) => range.start < (entry.key + 1) * damageBlock && range.end >= entry.value);
  }

  /// A copy of this node sent bytes before it was cancelled.
  void streamed(String url) => _streamed.add(NodeCatalog.nodeKey(url));

  /// [range] is the part this attempt asked for. A copy of a node that is up (it has sent bytes) which breaks
  /// off without a status, short of the end and not by a timeout, is a damaged copy at that position: the span
  /// is avoided on that node, without strikes or backoff. Damage in a third block is struck as before and not
  /// recorded. A network change forgets all damage.
  void failure(String url, {int? status, required int receivedBytes, ByteRange? range, bool timedOut = false}) {
    final delivered = bans?.hasDelivered(url) ?? false;
    final node = NodeCatalog.nodeKey(url);
    final key = routeKey(url);
    if (receivedBytes > 0) _streamed.add(node);
    if (range != null &&
        status == null &&
        !timedOut &&
        receivedBytes < range.length &&
        (delivered || _streamed.contains(node) || (_routes[key]?.lastSuccessAt ?? 0) > 0)) {
      final offset = range.start + receivedBytes;
      final blocks = _damage[key] ?? <int, int>{};
      final block = offset ~/ damageBlock;
      if (blocks[block] != null || blocks.length < damagedBlockLimit) {
        blocks[block] = min(blocks[block] ?? offset, offset);
        _damage[key] = blocks;
        return;
      }
    }
    final now = _clock.nowMs();
    bans?.record(url, receivedBytes: receivedBytes, status: status, lostAt: status == null && !timedOut ? now : null);
    final health = _health.putIfAbsent(url, _Health.new);
    health
      ..failures += 1
      ..blockedUntil = now + min(60000, 3000 * pow(2, min(health.failures, 4))).toDouble();
  }

  /// Measured bytes per second of one connection to this node, else the prior's; 0 when unknown or stale.
  double speed(String url) => _measuredNow(url, _clock.nowMs()) ? (_routes[routeKey(url)]?.bps ?? 0) : _priorBps(url);

  List<NodeStatus> status() {
    final all = allURLs();
    final bans = this.bans;
    final usable = bans == null ? all : all.where(bans.allowsAddress).toList();
    final list = usable.isEmpty ? all : usable;
    final now = _clock.nowMs();
    return [
      for (final url in list)
        NodeStatus(
          node: NodeCatalog.nodeKey(url),
          state: !(bans?.allows(url) ?? true)
              ? 'banned'
              : (_health[url]?.blockedUntil ?? 0) > now
              ? 'blocked'
              : (_routes[routeKey(url)]?.lastSuccessAt ?? 0) > 0
              ? 'healthy'
              : 'untested',
          bps: _routes[routeKey(url)]?.bps ?? 0,
        ),
    ];
  }
}
