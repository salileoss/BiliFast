import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;

import '../app/app_environment.dart';
import '../device/network_monitor.dart';
import 'watch_reporter.dart';

/// `BiliClient.heartbeat`'s shape.
typedef SendHeartbeat = Future<void> Function({required String bvid, required int cid, required int playedTime});

/// The account's latest 历史记录 page (`BiliClient.history`).
typedef ReadRecentHistory = Future<HistoryPage> Function();

/// The last watch report of one video that got no answer, in the part it was made in: the seconds played, or -1 for
/// finished.
@immutable
final class PendingReport {
  const PendingReport({required this.bvid, required this.cid, required this.played, required this.at, this.ownerMid});

  factory PendingReport.fromJson(Map<String, Object?> json) => PendingReport(
    bvid: json['bvid']! as String,
    cid: json['cid']! as int,
    played: json['played']! as int,
    at: DateTime.fromMillisecondsSinceEpoch(json['at']! as int),
    ownerMid: json['ownerMid'] as int?,
  );

  final String bvid;
  final int cid;
  final int played;
  final int? ownerMid;
  (int?, String) get key => (ownerMid, bvid);

  /// When the report was made.
  final DateTime at;

  Map<String, Object?> toJson() => {
    'bvid': bvid, 'cid': cid, 'played': played, 'at': at.millisecondsSinceEpoch, 'ownerMid': ?ownerMid,
  };

  @override
  bool operator ==(Object other) =>
      other is PendingReport && other.bvid == bvid && other.cid == cid && other.played == played && other.at == at &&
      other.ownerMid == ownerMid;

  @override
  int get hashCode => Object.hash(bvid, cid, played, at, ownerMid);
}

enum _Flushed { sent, gone, dropped, noAnswer, kept }

/// Watch reports that got no answer (offline, timed out), kept until Bilibili takes them, so a part watched with no
/// network still reaches the account's history (KaiC watches on several devices). One per account and video, the latest, as
/// Bilibili keeps one place per video whatever the part; a later report of the video that goes through makes it moot.
/// Kept 30 days, in a JSON file in the support folder. Every heartbeat goes through [send], one at a time with
/// [flush]'s, so Bilibili never hears an older place last.
class HistoryOutbox {
  HistoryOutbox._(this._path, this._held, this._logger, this._now);

  HistoryOutbox.memory({Logger? logger, DateTime Function() now = DateTime.now})
    : this._(null, {}, logger ?? Logger.shared, now);

  static const keptFor = Duration(days: 30);

  /// A flush holding a report older than this asks the account's history first: another device may have watched the
  /// video since.
  static const checkAfter = Duration(minutes: 5);

  /// [path] null keeps the reports in memory only. An unreadable file starts empty; entries that don't decode are
  /// dropped one by one, and so are those past [keptFor].
  static Future<HistoryOutbox> load(String? path, {
    Logger? logger, DateTime Function() now = DateTime.now, bool requireOwner = true,
  }) async {
    final log = logger ?? Logger.shared;
    final held = <(int?, String), PendingReport>{};
    var discarded = false;
    if (path != null) {
      final file = File(path);
      try {
        if (await file.exists()) {
          final json = jsonDecode(await file.readAsString());
          if (json is! List) throw const FormatException('not a list');
          var skipped = 0;
          for (final entry in json) {
            try {
              final report = PendingReport.fromJson(entry as Map<String, Object?>);
              if ((requireOwner && report.ownerMid == null) || (report.ownerMid != null && report.ownerMid! <= 0)) {
                discarded = true;
                skipped++;
                continue;
              }
              final kept = held[report.key];
              if (kept == null || kept.at.isBefore(report.at)) held[report.key] = report;
            } on TypeError {
              skipped++;
            }
          }
          if (skipped > 0) log.warn(LogCategory.app, 'history outbox entries skipped', {'skipped': skipped});
        }
      } catch (error) {
        log.warn(LogCategory.app, 'history outbox unreadable, starting empty', {'error': _reason(error)});
      }
    }
    final outbox = HistoryOutbox._(path, held, log, now);
    if (discarded) outbox._save();
    final dropped = outbox._dropExpired();
    if (held.isNotEmpty || dropped > 0) {
      log.info(LogCategory.app, 'history outbox', {'held': held.length, 'dropped': dropped});
    }
    return outbox;
  }

  final String? _path;

  /// One place per video, separately for each account.
  final Map<(int?, String), PendingReport> _held;
  final Logger _logger;
  final DateTime Function() _now;

  /// Reports [send] has taken and not yet settled, by part.
  final Map<(int?, String, int), int> _inFlight = {};
  final Map<int, int> _ownerGenerations = {};

  /// Bumped by [clear], so a report out at a logout that then gets no answer isn't kept for the next account.
  int _generation = 0;

  /// The end of the last task queued, while any is queued or running.
  Future<void>? _lane;
  Future<void>? _flushing;

  /// The latest explicit request made while another flush runs, including a new account's.
  ({int? owner, Future<bool> Function() pass})? _nextFlush;
  Future<void> _writing = Future.value();

  /// What is waiting, oldest first.
  List<PendingReport> get reports => [..._held.values]..sort((a, b) => a.at.compareTo(b.at));

  /// A report of the part is waiting or on its way: what this phone saw of it is newer than anything Bilibili has.
  bool holds(String bvid, int cid, {int? ownerMid}) {
    if ((_inFlight[(ownerMid, bvid, cid)] ?? 0) > 0) return true;
    final report = _held[(ownerMid, bvid)];
    return report != null && report.cid == cid && !_expired(report);
  }

  /// No answer at all; Bilibili's own refusals and the Windows guard's are answers.
  static bool isNetworkFailure(Object error) => error is BiliNetworkError;

  /// Sends one report through [beat] after every one before it, a flush's included. A report that goes through
  /// clears the video's waiting one, older whatever its part; one that gets no answer takes its place. Errors reach
  /// the caller.
  Future<void> send(String bvid, int cid, int played, Future<void> Function() beat, {
    int? ownerMid, bool Function()? isCurrent,
  }) {
    final part = (ownerMid, bvid, cid);
    _inFlight[part] = (_inFlight[part] ?? 0) + 1;
    final generation = _generation;
    final ownerGeneration = _ownerGenerations[ownerMid] ?? 0;
    final report = PendingReport(bvid: bvid, cid: cid, played: played, at: _now(), ownerMid: ownerMid);
    bool retained() => generation == _generation && ownerGeneration == (_ownerGenerations[ownerMid] ?? 0);
    return _inLane(() async {
      if (!retained()) return;
      if (isCurrent != null && !isCurrent()) {
        _keep(report);
        return;
      }
      try {
        await beat();
      } catch (error) {
        if ((isNetworkFailure(error) || (isCurrent != null && !isCurrent())) && retained()) _keep(report);
        rethrow;
      }
      if (!retained() || (isCurrent != null && !isCurrent())) return;
      final waiting = _held[report.key];
      if (waiting != null && !waiting.at.isAfter(report.at)) _remove(waiting);
    }).whenComplete(() {
      final left = (_inFlight[part] ?? 1) - 1;
      if (left > 0) {
        _inFlight[part] = left;
      } else {
        _inFlight.remove(part);
      }
    });
  }

  /// Sends what is waiting, oldest first and one at a time, through [heartbeat]; stops at the first that gets no
  /// answer. Holding a report older than [checkAfter], it first reads [recent] once and drops each report whose video
  /// the account has watched since (another device). A report Bilibili refuses outright (a video gone) is dropped, as
  /// sending it again gets the same answer; a login refused or risk control keeps it for a later flush. A flush asked
  /// for while one runs gets one more pass if that one ended with no answer (the network may be back).
  Future<void> flush(SendHeartbeat heartbeat, {
    required ReadRecentHistory recent, int? ownerMid, bool Function()? isCurrent,
  }) {
    Future<bool> pass() => _pass(heartbeat, recent, ownerMid, isCurrent);
    final running = _flushing;
    if (running != null) {
      _nextFlush = (owner: ownerMid, pass: pass);
      return running;
    }
    late final Future<void> flushing;
    flushing = _run(pass, ownerMid).whenComplete(() {
      if (identical(_flushing, flushing)) _flushing = null;
    });
    return _flushing = flushing;
  }

  Future<void> _run(Future<bool> Function() pass, int? owner) async {
    var retry = await pass();
    while (_nextFlush != null) {
      final next = _nextFlush!;
      _nextFlush = null;
      if (retry || next.owner != owner) {
        retry = await next.pass();
        owner = next.owner;
      }
    }
  }

  /// Whether it ended with no answer.
  Future<bool> _pass(SendHeartbeat heartbeat, ReadRecentHistory recent, int? ownerMid, bool Function()? isCurrent) async {
    bool current() => isCurrent == null || isCurrent();
    if (!current()) return true;
    var dropped = _dropExpired();
    var stale = 0;
    var sent = 0;
    var failed = 0;
    var noAnswer = false;
    List<PendingReport> selected() => reports.where((report) => report.ownerMid == ownerMid).toList();
    if (selected().any((report) => _now().difference(report.at) > checkAfter)) {
      try {
        final history = await recent();
        if (!current()) return true;
        stale = _dropWatchedSince(history.items, ownerMid);
      } catch (error) {
        failed++;
        noAnswer = isNetworkFailure(error);
      }
    }
    if (failed == 0) {
      for (final report in selected()) {
        final outcome = await _inLane(() async {
          if (!current()) return _Flushed.kept;
          // A page's own report may have settled it, or a newer one taken its place, while this one waited its turn.
          final waiting = _held[report.key];
          if (waiting == null) return _Flushed.gone;
          try {
            await heartbeat(bvid: waiting.bvid, cid: waiting.cid, playedTime: waiting.played);
          } catch (error) {
            if (!current()) return _Flushed.kept;
            if (isNetworkFailure(error)) return _Flushed.noAnswer;
            if (!_refusedForGood(error)) return _Flushed.kept;
            _remove(waiting);
            return _Flushed.dropped;
          }
          if (!current()) return _Flushed.kept;
          _remove(waiting);
          return _Flushed.sent;
        });
        switch (outcome) {
          case _Flushed.sent:
            sent++;
          case _Flushed.dropped:
            dropped++;
          case _Flushed.noAnswer || _Flushed.kept:
            failed++;
          case _Flushed.gone:
            break;
        }
        if (outcome == _Flushed.noAnswer || outcome == _Flushed.kept) {
          noAnswer = outcome == _Flushed.noAnswer;
          break;
        }
      }
    }
    if (sent + dropped + stale + failed > 0) {
      _logger.info(LogCategory.api, 'history outbox', {
        'sent': sent,
        'dropped': dropped,
        'stale': stale,
        'failed': failed,
        'held': _held.length,
      });
    }
    return noAnswer || !current();
  }

  void _remove(PendingReport report) {
    if (!identical(_held[report.key], report)) return;
    _held.remove(report.key);
    _save();
  }

  /// Drops the reports whose video [items] shows watched at or after the report was made.
  int _dropWatchedSince(List<HistoryItem> items, int? ownerMid) {
    final watched = <String, int>{};
    for (final item in items) {
      watched[item.bvid] = max(watched[item.bvid] ?? 0, item.viewAt);
    }
    final moved = [
      for (final report in _held.values)
        if (report.ownerMid == ownerMid && (watched[report.bvid] ?? 0) * 1000 >= report.at.millisecondsSinceEpoch) report.key,
    ];
    if (moved.isEmpty) return 0;
    moved.forEach(_held.remove);
    _save();
    return moved.length;
  }

  static bool _refusedForGood(Object error) => switch (error) {
    BiliAPIError(code: -101 || -352 || -412) => false,
    BiliAPIError(code: GuardedTransport.readOnlyCode || GuardedTransport.capCode || GuardedTransport.haltCode) => false,
    BiliAPIError() => true,
    _ => false,
  };

  /// 退出登录: what is waiting was the old account's, and so is any report still out.
  void clear() {
    _generation++;
    if (_held.isEmpty) return;
    final dropped = _held.length;
    _held.clear();
    _save();
    _logger.info(LogCategory.api, 'history outbox', {'dropped': dropped, 'held': 0});
  }

  /// Forgetting one account also invalidates its queued and in-flight reports.
  void removeOwner(int mid) {
    _ownerGenerations[mid] = (_ownerGenerations[mid] ?? 0) + 1;
    final before = _held.length;
    _held.removeWhere((key, _) => key.$1 == mid);
    if (_held.length != before) _save();
  }

  /// Waits for the reports and writes under way; for tests.
  Future<void> settle() async {
    await _lane;
    await _flushing;
    await _writing;
  }

  void _keep(PendingReport report) {
    final kept = _held[report.key];
    if (kept != null && kept.at.isAfter(report.at)) return;
    final added = kept == null;
    _held[report.key] = report;
    _save();
    if (added) _logger.info(LogCategory.api, 'history outbox', {'queued': 1, 'held': _held.length});
  }

  bool _expired(PendingReport report) => _now().difference(report.at) > keptFor;

  int _dropExpired() {
    final expired = [
      for (final report in _held.values)
        if (_expired(report)) report.key,
    ];
    if (expired.isEmpty) return 0;
    expired.forEach(_held.remove);
    _save();
    return expired.length;
  }

  /// One task at a time; a failed one doesn't stop the next. Idle, a task starts at once, so the lane never hangs on
  /// a future made in another zone (a test's setUp).
  Future<T> _inLane<T>(Future<T> Function() task) {
    final before = _lane;
    final result = before == null ? Future.sync(task) : before.then((_) => task());
    late final Future<void> end;
    end = result.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_lane, end)) _lane = null;
    });
    _lane = end;
    return result;
  }

  void _save() {
    final path = _path;
    if (path == null) return;
    final text = jsonEncode([for (final report in reports) report.toJson()]);
    // One write after another, so an older list never lands last.
    _writing = _writing.then((_) => _write(path, text));
  }

  Future<void> _write(String path, String text) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      final temporary = File('$path.tmp');
      await temporary.writeAsString(text, flush: true);
      await temporary.rename(path);
    } catch (error) {
      _logger.warn(LogCategory.app, 'history outbox not saved', {'error': _reason(error)});
    }
  }

  /// The error without the text that failed or the path: a FormatException quotes it.
  static String _reason(Object error) => switch (error) {
    FormatException(:final message) => message,
    FileSystemException(:final message, :final osError) => osError == null ? message : '$message: $osError',
    _ => '${error.runtimeType}',
  };
}

/// Flushes [outbox] while [WatchReporter.canReport] allows: once the account check says logged in (the launch's,
/// a login), whenever the app comes back to the foreground, and on every network change. Forgetting an account
/// removes its reports; switching retains them for that owner.
class HistoryOutboxFlusher with WidgetsBindingObserver {
  HistoryOutboxFlusher({required this.outbox, required this._environment, NetworkMonitor? network}) {
    WidgetsBinding.instance.addObserver(this);
    _account = _environment.account;
    _knownOwners = _environment.savedAccounts.map((account) => account.mid).toSet();
    _environment.addListener(_accountChanged);
    _environment.sessions.addListener(_sessionChanged);
    _network = (network ?? NetworkMonitor.platform()).changes.listen((_) => flush());
    // The launch's check may have answered before the app's services were made.
    if (_account is LoggedIn) flush();
  }

  final HistoryOutbox outbox;
  final AppEnvironment _environment;
  late final StreamSubscription<bool> _network;
  late Account _account;
  late Set<int> _knownOwners;
  bool _disposed = false;

  /// Sends what is waiting, if the account may report.
  void flush() {
    if (_disposed || outbox.reports.isEmpty || !WatchReporter.canReport(_environment)) return;
    final client = _environment.client;
    final generation = client.sessionGeneration;
    final owner = _environment.hasAccountVault ? _environment.activeAccountMid : null;
    if (_environment.hasAccountVault && owner == null) return;
    bool current() => generation == client.sessionGeneration && WatchReporter.canReport(_environment) &&
        (!_environment.hasAccountVault || _environment.activeAccountMid == owner);
    unawaited(outbox.flush(
      ({required bvid, required cid, required playedTime}) => client.runInSession(generation,
          () => client.heartbeat(bvid: bvid, cid: cid, playedTime: playedTime)),
      recent: () => client.runInSession(generation, client.history),
      ownerMid: owner,
      isCurrent: current,
    ));
  }

  void _accountChanged() {
    final now = _environment.account;
    final was = _account;
    _account = now;
    final owners = _environment.savedAccounts.map((account) => account.mid).toSet();
    for (final removed in _knownOwners.difference(owners)) {
      outbox.removeOwner(removed);
    }
    _knownOwners = owners;
    if (now is LoggedIn && was is! LoggedIn) flush();
    // Whoever logs in next may be another account.
    if (!_environment.hasAccountVault && now is LoggedOut && was is! LoggedOut) outbox.clear();
  }

  void _sessionChanged() {
    // The transition's final notification removes its busy state before flushing.
    Timer.run(flush);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) flush();
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _environment.removeListener(_accountChanged);
    _environment.sessions.removeListener(_sessionChanged);
    unawaited(_network.cancel());
  }
}
