// Port of Bilibili-thread-ripper (see LICENSE-BTR.txt), by way of BiliNative's AutoConcurrency.swift.

import 'dart:math';

import '../shared/clock.dart';

final class AutoConcurrencyStatus {
  const AutoConcurrencyStatus({
    required this.threads,
    required this.reason,
    required this.throughputBps,
    required this.saturation,
    required this.inStartup,
  });

  final int threads;
  final String reason;
  final double throughputBps;
  final double saturation;
  final bool inStartup;
}

typedef ConcurrencyChange = void Function(int threads, int previous, String reason);

final class _Trial {
  _Trial({required this.from, required this.level, required this.at, required this.baseline});

  final int from;
  final int level;
  final double at;
  final double baseline;
  bool stalled = false;
}

final class _Rest {
  const _Rest({required this.until, required this.hard});

  final double until;
  final bool hard;
}

final class _Bucket {
  _Bucket(this.at, this.bytes);

  final double at;
  double bytes;
}

typedef _Span = ({double from, double to});
typedef _Startup = ({int base, double until});
typedef _LowerTrial = ({int from, double at, double baseline});
typedef _Change = ({int threads, int previous, String reason});

/// BTR `createAutoConcurrency`. The connection count climbs a ladder whenever downloading is not
/// keeping up (a stall, a low buffer that stops growing while bytes arrive, connections queueing
/// too long). Every step up is a trial: if throughput has not grown by 10% ten seconds later it is taken
/// back and that level rests. 412/429 step down and block the level for three minutes. Each new
/// playback starts with at least 16 connections and comes back down once the buffer is ahead.
/// A comfortable buffer also lets it try fewer connections, restoring them if playback loses ground.
final class AutoConcurrency {
  AutoConcurrency({MonotonicClock? clock}) : _clock = clock ?? MonotonicClock.system;

  static const ladder = [8, 12, 16, 24, 32, 48, 64];
  static const startupLevel = 2;
  static const startupComfortSeconds = 15.0;
  static const startupMaxMs = 30000.0;
  static const stepCooldownMs = 2500.0;
  static const trialMs = 10000.0;
  static const windowMs = 5000.0;
  static const bucketMs = 250.0;
  static const restMs = 90000.0;
  static const pushbackRestMs = 180000.0;
  static const lowBufferSeconds = 6.0;
  static const pressureMs = 1000.0;
  static const activityMs = 1500.0;
  static const minimumGain = 1.1;
  static const comfortableSeconds = 20.0;
  static const downshiftMs = 30000.0;
  static const restoreSeconds = 10.0;

  final MonotonicClock _clock;

  int _level = 0;
  double _changedAt = 0;
  String _reason = '起步';
  _Trial? _trial;
  final _resting = <int, _Rest>{};
  final _buckets = <_Bucket>[];
  double _lastActivityAt = double.negativeInfinity;
  bool _saturated = false;
  double _saturatedSince = 0;
  final _saturatedSpans = <_Span>[];
  final _aheadSamples = <({double at, double ahead})>[];
  double _pressureSince = 0;
  _Startup? _startup;
  _LowerTrial? _lowerTrial;
  double? _comfortableSince;

  /// Called once per step, after the state changed and the call that made the step has finished with it.
  /// Steps made by one call arrive in order.
  ConcurrencyChange? onChange;

  int get threads => ladder[_level];

  AutoConcurrencyStatus status() => _mutate(
    (at, _) => AutoConcurrencyStatus(
      threads: ladder[_level],
      reason: _reason,
      throughputBps: _throughput(at),
      saturation: _saturation(at),
      inStartup: _startup != null,
    ),
  );

  /// A piece arrived whole. Hedge copies that lost are not delivery.
  void delivered(int bytes) => _mutate((at, changes) {
    final last = _buckets.lastOrNull;
    if (last != null && at - last.at < bucketMs) {
      last.bytes += bytes;
    } else {
      _buckets.add(_Bucket(at, bytes.toDouble()));
    }
    _pruneBuckets(at);
    _judgeTrial(at, changes);
  });

  void activity() => _mutate((at, _) => _lastActivityAt = at);

  void demand({required int active, required int limit, required int queued}) => _mutate((at, _) {
    final saturated = active >= limit && queued > 0;
    if (saturated == _saturated) return;
    if (_saturated) _saturatedSpans.add((from: _saturatedSince, to: at));
    _saturated = saturated;
    _saturatedSince = at;
    _saturation(at);
  });

  bool stall([String reason = '播放卡了一下']) => _mutate((at, changes) {
    _trial?.stalled = true;
    return _stepUp(reason, strong: true, at, changes);
  });

  /// Playable wall-clock seconds ahead (media seconds divided by playback rate), a few times a second.
  bool buffer({required double ahead, required bool playing}) => _mutate((at, changes) {
    final adjusted = _adjustComfort(ahead, playing, at, changes);
    _aheadSamples.add((at: at, ahead: ahead));
    while (_aheadSamples.isNotEmpty && at - _aheadSamples.first.at > pressureMs + bucketMs) {
      _aheadSamples.removeAt(0);
    }
    final start = _startup;
    if (start != null) {
      if (at >= start.until) {
        _startup = null;
      } else if (ahead >= startupComfortSeconds && at - _changedAt >= stepCooldownMs) {
        if (_level > start.base) {
          _setLevel(_level - 1, '开头已经跟上，线程数降到 ${ladder[_level - 1]}', null, at, changes);
        }
        if (_level <= start.base) _startup = null;
      }
    }
    final earlier = _aheadSamples.where((sample) => at - sample.at >= pressureMs).firstOrNull;
    final downloading = at - _lastActivityAt < activityMs;
    final pressed =
        playing && downloading && ahead < lowBufferSeconds && earlier != null && ahead <= earlier.ahead + 0.05;
    if (!pressed) {
      _pressureSince = 0;
      return adjusted;
    }
    if (_pressureSince == 0) {
      _pressureSince = at;
      return adjusted;
    }
    if (at - _pressureSince < pressureMs) return adjusted;
    _pressureSince = 0;
    return _stepUp('缓冲跟不上播放', strong: false, at, changes) || adjusted;
  });

  bool _restoreLower(String reason, double at, List<_Change> changes) {
    final trial = _lowerTrial;
    if (trial == null) return false;
    _lowerTrial = null;
    _setLevel(trial.from, reason, null, at, changes);
    return true;
  }

  bool _adjustComfort(double ahead, bool playing, double at, List<_Change> changes) {
    final trial = _lowerTrial;
    if (trial != null) {
      if (playing && ahead < restoreSeconds) {
        return _restoreLower('减少线程后缓冲不足，恢复线程数', at, changes);
      }
      if (playing && at - trial.at >= trialMs) {
        if (_saturation(at) >= 0.6 && trial.baseline > 0 && _throughput(at) < trial.baseline * 0.9) {
          return _restoreLower('减少线程后速度下降，恢复线程数', at, changes);
        }
        _lowerTrial = null;
        _comfortableSince = null;
      }
    }
    if (!playing || ahead < comfortableSeconds || _startup != null || _trial != null || _lowerTrial != null || _level == 0) {
      _comfortableSince = null;
      return false;
    }
    _comfortableSince ??= at;
    if (at - _comfortableSince! < downshiftMs) return false;
    final from = _level;
    final baseline = _throughput(at);
    _setLevel(from - 1, '缓冲充足，试用更少线程', null, at, changes);
    _lowerTrial = (from: from, at: at, baseline: baseline);
    return true;
  }

  /// A connection waited too long for its first byte while every slot was busy.
  bool slow() =>
      _mutate((at, changes) => _saturation(at) >= 0.6 ? _stepUp('连接排队等太久', strong: false, at, changes) : false);

  bool pushback({required int status}) => _mutate(
    (at, changes) => _stepDown(
      target: max(0, _level - 1),
      restLevel: _level,
      '服务器返回 $status',
      restMs: pushbackRestMs,
      hard: true,
      at,
      changes,
    ),
  );

  void newSession() => _mutate((at, changes) {
    _aheadSamples.clear();
    _pressureSince = 0;
    _trial = null;
    _lowerTrial = null;
    _comfortableSince = null;
    _buckets.clear();
    _saturatedSpans.clear();
    if (_saturated) _saturatedSince = at;
    final base = _startup?.base ?? _level;
    final target = _startupTarget(at);
    if (target > _level) _setLevel(target, '开头先用 ${ladder[target]} 线程', null, at, changes);
    _startup = _level > base ? (base: base, until: at + startupMaxMs) : null;
  });

  /// Swift's lock section: the body sees one time, and the steps it makes are reported once it has returned.
  T _mutate<T>(T Function(double at, List<_Change> changes) body) {
    final at = _clock.nowMs();
    final changes = <_Change>[];
    final result = body(at, changes);
    final notify = onChange;
    if (notify != null) {
      for (final change in changes) {
        notify(change.threads, change.previous, change.reason);
      }
    }
    return result;
  }

  void _pruneBuckets(double at) {
    while (_buckets.isNotEmpty && at - _buckets.first.at > windowMs) {
      _buckets.removeAt(0);
    }
  }

  /// Bytes per second over the window, timed from first to last delivery so an idle tail is not slowness.
  double _throughput(double at) {
    _pruneBuckets(at);
    if (_buckets.isEmpty) return 0;
    final bytes = _buckets.fold(0.0, (sum, bucket) => sum + bucket.bytes);
    return bytes * 1000 / max(1000.0, _buckets.last.at - _buckets.first.at + bucketMs);
  }

  double _saturation(double at) {
    final from = at - windowMs;
    _saturatedSpans.removeWhere((span) => span.to <= from);
    var busy = _saturatedSpans.fold(0.0, (sum, span) => sum + max(0.0, span.to - max(span.from, from)));
    if (_saturated) busy += max(0.0, at - max(_saturatedSince, from));
    return min(1.0, busy / windowMs);
  }

  _Rest? _restingAt(int level, double at) {
    final rest = _resting[level];
    if (rest == null) return null;
    if (rest.until <= at) {
      _resting.remove(level);
      return null;
    }
    return rest;
  }

  void _setLevel(int level, String reason, _Trial? trial, double at, List<_Change> changes) {
    final previous = ladder[_level];
    _level = level;
    _changedAt = at;
    _reason = reason;
    _trial = trial;
    _comfortableSince = null;
    _pressureSince = 0;
    changes.add((threads: ladder[level], previous: previous, reason: reason));
  }

  bool _stepUp(String reason, double at, List<_Change> changes, {required bool strong}) {
    if (_restoreLower('减少线程后缓冲不足，恢复线程数', at, changes)) return true;
    if (at - _changedAt < stepCooldownMs) return false;
    if (_restingAt(_level, at)?.hard ?? false) return false;
    var next = _level + 1;
    while (next < ladder.length) {
      final rest = _restingAt(next, at);
      if (rest == null) break;
      if (rest.hard || !strong) return false;
      next += 1;
    }
    if (next >= ladder.length) return false;
    final trial = _Trial(from: _level, level: next, at: at, baseline: _throughput(at));
    _setLevel(next, reason, trial, at, changes);
    _startup = null;
    return true;
  }

  int _startupTarget(double at) {
    if (_restingAt(_level, at)?.hard ?? false) return _level;
    var level = _level;
    while (level < startupLevel && !(_restingAt(level + 1, at)?.hard ?? false)) {
      level += 1;
    }
    return level;
  }

  bool _stepDown(
    String reason,
    double at,
    List<_Change> changes, {
    required int target,
    required int restLevel,
    required double restMs,
    required bool hard,
  }) {
    _lowerTrial = null;
    _comfortableSince = null;
    _resting[restLevel] = _Rest(until: at + restMs, hard: hard);
    if (target >= _level) return false;
    _setLevel(target, reason, null, at, changes);
    return true;
  }

  void _judgeTrial(double at, List<_Change> changes) {
    final trial = _trial;
    if (trial == null || at - trial.at < trialMs) return;
    _trial = null;
    if (trial.stalled || _saturation(at) < 0.6 || trial.baseline <= 0) return;
    if (_throughput(at) < trial.baseline * minimumGain) {
      _stepDown(
        target: trial.from,
        restLevel: trial.level,
        '${ladder[trial.level]} 线程没有比 ${ladder[trial.from]} 线程更快',
        restMs: restMs,
        hard: false,
        at,
        changes,
      );
    }
  }
}
