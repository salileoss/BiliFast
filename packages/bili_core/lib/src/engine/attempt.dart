// Port of Bilibili-thread-ripper (see LICENSE-BTR.txt), by way of BiliNative's Attempt.swift.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../devlog/log_event.dart';
import '../devlog/logger.dart';
import '../shared/byte_range.dart';
import '../shared/clock.dart';
import 'auto_concurrency.dart';
import 'cancel.dart';
import 'connection_pool.dart';
import 'engine_stats.dart';
import 'meter.dart';
import 'node_catalog.dart';
import 'node_stats.dart';
import 'playback_engine.dart';
import 'resolver.dart';
import 'ripper_config.dart';
import 'transport.dart';

final class EngineContext {
  EngineContext({
    required this.transport,
    required this.pool,
    required this.config,
    Meter? meter,
    EngineStats? stats,
    this.auto,
    MonotonicClock? clock,
    Logger? logger,
  }) : meter = meter ?? Meter(),
       stats = stats ?? EngineStats(),
       clock = clock ?? MonotonicClock.system,
       logger = logger ?? Logger.shared,
       nodes = NodeStats(connectionsPerHost: transport.connectionsPerHost);

  final RangeTransport transport;
  final ConnectionPool pool;
  final RipperConfig config;
  final Meter meter;
  final EngineStats stats;

  /// Null when the connection count is fixed.
  final AutoConcurrency? auto;
  final MonotonicClock clock;
  final Logger logger;
  final NodeStats nodes;

  /// BTR's pause before retry round [round] (1 or later): 0.5 s, 1 s, at most 2 s. False once
  /// the retry window that began at [startedAt] is spent.
  Future<bool> pauseBeforeRound(int round, {required double startedAt, CancelToken? cancel}) async {
    if (clock.nowMs() - startedAt > config.retryWindowMs) return false;
    await cancellableSleep(min(2000, 500 * pow(2, round - 1)).toDouble(), cancel);
    return true;
  }

  int _audioReads = 0;

  /// Video requests waiting for or holding a pool permit, under [RipperConfig.audioFirst].
  int _videoInPool = 0;
  final _videoGate = <_GateWaiter>[];

  /// An audio player read began waiting for bytes; until it ends, video keeps [RipperConfig.audioReserve]
  /// connections free for it.
  void audioReadBegan() => _audioReads += 1;

  void audioReadEnded() {
    if (_audioReads > 0) _audioReads -= 1;
    _openVideoGate();
  }

  int get videoInPool => _videoInPool;
  int get videoGated => _videoGate.length;

  /// A connection permit for one request. [lane] adds its priority boost and class floor, and under
  /// [RipperConfig.audioFirst] a video request first waits outside the pool while an audio read waits and video
  /// already holds or waits for all but the connections kept for audio. Give the permit back with [released].
  Future<Permit> acquire({
    required double priority,
    required QueueClass queueClass,
    double Function()? deadline,
    CancelToken? cancel,
    RequestLane lane = RequestLane.any,
  }) async {
    final floor = lane.minClass;
    final effectiveClass = floor != null && floor.index < queueClass.index ? floor : queueClass;
    final gated = _gates(lane);
    if (gated) await _enterVideo(priority + lane.boost, effectiveClass, cancel);
    try {
      return await pool.acquire(
        priority: priority + lane.boost,
        queueClass: effectiveClass,
        deadline: deadline,
        cancel: cancel,
      );
    } catch (_) {
      if (gated) _leaveVideo();
      rethrow;
    }
  }

  void released(RequestLane lane) {
    if (_gates(lane)) _leaveVideo();
  }

  bool _gates(RequestLane lane) => config.audioFirst && lane.track == TrackKind.video;

  bool get _videoMayEnter => _audioReads == 0 || _videoInPool < max(1, pool.limit - config.audioReserve);

  Future<void> _enterVideo(double rank, QueueClass queueClass, CancelToken? cancel) async {
    cancel?.throwIfCancelled();
    if (_videoGate.isEmpty && _videoMayEnter) {
      _videoInPool += 1;
      return;
    }
    final waiter = _GateWaiter(rank, queueClass);
    _videoGate.add(waiter);
    final remove = cancel?.onCancel(() {
      if (_videoGate.remove(waiter)) waiter.completer.completeError(const CancelledException());
    });
    // The pool's limit can have grown since the gate last opened.
    _openVideoGate();
    try {
      await waiter.completer.future;
    } finally {
      remove?.call();
    }
  }

  void _leaveVideo() {
    if (_videoInPool > 0) _videoInPool -= 1;
    _openVideoGate();
  }

  /// In the pool's own order: class first, then rank, then arrival.
  void _openVideoGate() {
    while (_videoGate.isNotEmpty && _videoMayEnter) {
      var best = 0;
      for (var index = 1; index < _videoGate.length; index++) {
        final candidate = _videoGate[index];
        final current = _videoGate[best];
        if (candidate.queueClass.index < current.queueClass.index ||
            (candidate.queueClass == current.queueClass && candidate.rank > current.rank)) {
          best = index;
        }
      }
      _videoInPool += 1;
      _videoGate.removeAt(best).completer.complete();
    }
  }
}

final class _GateWaiter {
  _GateWaiter(this.rank, this.queueClass);

  final double rank;
  final QueueClass queueClass;
  final completer = Completer<void>();
}

/// Which track a request serves and how it ranks against the other track's ([RipperConfig.audioFirst]).
final class RequestLane {
  const RequestLane({this.track, this.boost = 0, this.minClass});

  static const any = RequestLane();

  final TrackKind? track;

  /// Added to the request's pool priority.
  final double boost;

  /// The request queues in at least this class.
  final QueueClass? minClass;
}

/// Throws [CancelledException] as soon as [cancel] fires, and stops the timer with it.
Future<void> cancellableSleep(double ms, CancelToken? cancel) {
  if (cancel?.isCancelled ?? false) return Future.error(const CancelledException());
  if (ms <= 0) return Future.value();
  final completer = Completer<void>();
  void Function() remove = () {};
  final timer = Timer(Duration(microseconds: (ms * 1000).round()), () {
    remove();
    completer.complete();
  });
  remove =
      cancel?.onCancel(() {
        timer.cancel();
        if (!completer.isCompleted) completer.completeError(const CancelledException());
      }) ??
      remove;
  return completer.future;
}

/// Bytes already held from the front of a piece; a retry or a backup copy asks only for the rest.
final class Prefix {
  const Prefix({this.bytes = 0, this.chunks = const []});

  static const empty = Prefix();

  final int bytes;
  final List<List<int>> chunks;
}

final class AttemptOutput {
  const AttemptOutput({required this.bytes, required this.total, required this.url});

  final Uint8List bytes;
  final int? total;
  final String url;
}

/// Live state of one copy of a piece, read by the watchdog and by hedging decisions.
final class AttemptProgress {
  bool started = false;
  double startedAt = 0;
  bool gotHeaders = false;
  double headersAt = 0;
  double? firstBodyAt;
  double lastProgressAt = 0;
  Prefix base = Prefix.empty;
  int received = 0;
  final chunks = <List<int>>[];
  int length = 0;
  int seenBytes = 0;
  double seenAt = 0;
  bool failed = false;

  /// Set by the race that is about to cancel this copy because another copy won.
  bool outrun = false;

  void begin({required double at, required int length, Prefix base = Prefix.empty}) {
    started = true;
    startedAt = at;
    lastProgressAt = at;
    seenAt = at;
    this.length = length;
    this.base = base;
  }

  void headers({required double at}) {
    gotHeaders = true;
    headersAt = at;
    lastProgressAt = at;
  }

  void append(List<int> chunk, {required double at}) {
    if (chunk.isEmpty) return;
    firstBodyAt ??= at;
    received += chunk.length;
    chunks.add(chunk);
    lastProgressAt = at;
  }

  /// The resumed base plus this copy's bytes: the front of the piece this copy has made available.
  Prefix prefix() => Prefix(bytes: base.bytes + received, chunks: [...base.chunks, ...chunks]);
}

/// Port of Attempt.swift's `AttemptRunner`.
final class AttemptRunner {
  AttemptRunner(this.ctx);

  final EngineContext ctx;

  /// Swift's `run(url:)`. Without [resumeBase] the whole piece is asked for.
  Future<AttemptOutput> runAt(
    String url, {
    required ByteRange piece,
    required AttemptProgress progress,
    required Resolver resolver,
    required double priority,
    required QueueClass queueClass,
    double Function()? deadline,
    int copy = 1,
    Prefix Function()? resumeBase,
    CancelToken? cancel,
    RequestLane lane = RequestLane.any,
  }) => run(
    claim: () {
      ctx.nodes.begin(url);
      return url;
    },
    piece: piece,
    progress: progress,
    resolver: resolver,
    priority: priority,
    queueClass: queueClass,
    deadline: deadline,
    copy: copy,
    resumeBase: resumeBase,
    cancel: cancel,
    lane: lane,
  );

  /// One request for [piece] (or its missing tail): waits for a connection, then [claim] picks the URL and counts the
  /// request on its node (`NodeStats.begin`), so a request that waited for a permit goes where there is room by then.
  /// Enforces BTR's three timeouts, checks the 206 Content-Range and the length, and reports the outcome to the
  /// resolver, meter, stats and automatic connection count.
  Future<AttemptOutput> run({
    required String Function() claim,
    required ByteRange piece,
    required AttemptProgress progress,
    required Resolver resolver,
    required double priority,
    required QueueClass queueClass,
    double Function()? deadline,
    int copy = 1,
    Prefix Function()? resumeBase,
    CancelToken? cancel,
    RequestLane lane = RequestLane.any,
  }) async {
    final permit = await ctx.acquire(
      priority: priority,
      queueClass: queueClass,
      deadline: deadline,
      cancel: cancel,
      lane: lane,
    );
    try {
      cancel?.throwIfCancelled();
      final url = claim();
      try {
        // Taken now, not when queued: a backup copy that waited resumes from what the first copy has by now.
        var base = resumeBase?.call() ?? Prefix.empty;
        if (base.bytes >= piece.length) base = Prefix.empty;
        final part = ByteRange.of(piece.start + base.bytes, piece.end);
        if (part == null) throw const RipperError(RipperErrorKind.invalidURL);
        return await _attempt(url, part, base, progress, resolver, copy, cancel);
      } finally {
        ctx.nodes.end(url, receiving: progress.firstBodyAt != null);
      }
    } finally {
      permit.release();
      ctx.released(lane);
    }
  }

  Future<AttemptOutput> _attempt(
    String url,
    ByteRange part,
    Prefix base,
    AttemptProgress progress,
    Resolver resolver,
    int copy,
    CancelToken? cancel,
  ) async {
    final started = ctx.clock.nowMs();
    progress.begin(at: started, length: part.length, base: base);
    final node = NodeCatalog.nodeKey(url);
    ctx.stats.started(node);
    try {
      final output = await _transfer(url, part, progress, started, node, cancel);
      final now = ctx.clock.nowMs();
      final elapsed = max(1.0, now - started);
      ctx.meter.record(bytes: part.length, elapsedMs: elapsed);
      ctx.nodes.body(url, bytes: part.length, ms: now - (progress.firstBodyAt ?? now));
      resolver.success(url, bps: part.length >= Meter.sampleMinBytes ? part.length * 1000 / elapsed : 0);
      ctx.logger.debug(LogCategory.engine, 'piece', {
        'node': node,
        'range': '$part',
        'headersMs': (progress.headersAt - started).roundToDouble(),
        'firstByteMs': ((progress.firstBodyAt ?? now) - started).roundToDouble(),
        'bytes': part.length,
        'ms': elapsed.roundToDouble(),
        'resumed': base.bytes,
        if (copy > 1) 'copy': copy,
      });
      return output;
    } catch (error) {
      final received = progress.received;
      final now = ctx.clock.nowMs();
      final elapsed = max(1.0, now - started);
      final cancelled = (cancel?.isCancelled ?? false) || error is CancelledException;
      if (cancelled) {
        // BTR PR 11: only a copy that lost a duplicate race says anything about its node. A seek or a
        // cancelled read would blend a queued request's whole wait into the estimate.
        if (progress.outrun) {
          if (progress.firstBodyAt case final firstBodyAt?) {
            ctx.nodes.crawl(url, bytes: received, ms: now - firstBodyAt);
          } else {
            ctx.nodes.outrun(url, waitedMs: elapsed);
          }
        }
        // A copy that lost the race still measured its node; without this a slow node is never measured.
        if (received >= Meter.sampleMinBytes) resolver.sample(url, bps: received * 1000 / elapsed);
        if (received > 0) resolver.streamed(url);
        ctx.logger.debug(LogCategory.engine, 'attempt cancelled', {
          'node': node,
          'range': '$part',
          'bytes': received,
          'ms': elapsed.roundToDouble(),
        });
      } else {
        final ripperError = error is RipperError ? error : null;
        final firstByteTimeout = ripperError?.kind == RipperErrorKind.firstByteTimeout;
        final timedOut = ripperError?.isTimeout ?? false;
        // BTR PR 11: the request waited behind the node's own transfers (the transport's per-host limit on
        // HTTP/1.1 Akamai, or the node's queue), so it is neither a strike nor a reason to slow down.
        final busy = received == 0 && firstByteTimeout && ctx.nodes.isBusy(url);
        if (firstByteTimeout) ctx.nodes.silent(url, waitedMs: elapsed);
        if (!busy) {
          final status = ripperError?.status;
          resolver.failure(url, status: status, receivedBytes: received, range: part, timedOut: timedOut);
          if (status != null && (status == 412 || status == 429)) {
            ctx.auto?.pushback(status: status);
          } else if (timedOut && received == 0) {
            ctx.auto?.slow();
          }
        }
        ctx.logger.debug(LogCategory.engine, 'attempt failed', {
          'node': node,
          'range': '$part',
          'error': '$error',
          'bytes': received,
          'ms': elapsed.roundToDouble(),
          if (busy) 'busy': true,
        });
      }
      ctx.stats.failed(node, wastedBytes: received, cancelled: cancelled);
      rethrow;
    }
  }

  Future<AttemptOutput> _transfer(
    String url,
    ByteRange part,
    AttemptProgress progress,
    double started,
    String node,
    CancelToken? cancel,
  ) {
    final done = Completer<AttemptOutput>();
    final request = CancelToken(cancel);
    StreamSubscription<List<int>>? body;
    Timer? watchdog;
    final config = ctx.config;

    void fail(Object error, [StackTrace? stack]) {
      if (done.isCompleted) return;
      done.completeError(error, stack);
      watchdog?.cancel();
      body?.cancel();
      request
        ..cancel()
        ..dispose();
    }

    void succeed(AttemptOutput output) {
      if (done.isCompleted) return;
      done.complete(output);
      watchdog?.cancel();
      request.dispose();
    }

    // One timer armed for the next deadline rather than Swift's 25 ms poll: the same three checks, without
    // waking every copy 40 times a second.
    void arm() {
      final now = ctx.clock.nowMs();
      if (!progress.gotHeaders && now - started > config.firstByteTimeoutMs) {
        fail(const RipperError(RipperErrorKind.firstByteTimeout));
      } else if (progress.gotHeaders && now - progress.lastProgressAt > config.stallTimeoutMs) {
        fail(const RipperError(RipperErrorKind.stalled));
      } else if (now - started > config.attemptTimeoutMs) {
        fail(const RipperError(RipperErrorKind.attemptTimeout));
      } else {
        final next = min(
          progress.gotHeaders ? progress.lastProgressAt + config.stallTimeoutMs : started + config.firstByteTimeoutMs,
          started + config.attemptTimeoutMs,
        );
        watchdog = Timer(Duration(microseconds: ((next - now + 1) * 1000).ceil()), arm);
      }
    }

    void onDone(ContentRange contentRange) {
      if (progress.received != part.length) {
        fail(RipperError.lengthMismatch(got: progress.received, expected: part.length));
        return;
      }
      final builder = BytesBuilder(copy: false);
      progress.prefix().chunks.forEach(builder.add);
      succeed(AttemptOutput(bytes: builder.takeBytes(), total: contentRange.total, url: url));
    }

    Future<void> start() async {
      final uri = Uri.tryParse(url);
      if (uri == null) throw const RipperError(RipperErrorKind.invalidURL);
      final response = await ctx.transport.fetch(uri, part, cancel: request);
      if (done.isCompleted) {
        // Lost to a timeout or a cancel while the headers were on their way: free the connection.
        unawaited(response.body.listen(null).cancel());
        return;
      }
      final now = ctx.clock.nowMs();
      progress.headers(at: now);
      final contentRange = ContentRange.parse(response.headers['content-range']);
      if (response.status != 206 || contentRange == null || contentRange.range != part) {
        unawaited(response.body.listen(null).cancel());
        throw RipperError.badResponse(response.status);
      }
      body = response.body.listen(
        (chunk) {
          if (chunk.isEmpty) return;
          final at = ctx.clock.nowMs();
          if (progress.firstBodyAt == null) {
            ctx.stats.firstByte(node, ms: at - started);
            ctx.nodes.firstByte(url, ms: at - started);
          }
          progress.append(chunk, at: at);
          ctx.auto?.activity();
        },
        onError: fail,
        onDone: () => onDone(contentRange),
        cancelOnError: true,
      );
    }

    request.onCancel(() => fail(const CancelledException()));
    if (done.isCompleted) return done.future;
    arm();
    start().catchError(fail);
    return done.future;
  }
}
