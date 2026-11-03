// Port of Bilibili-thread-ripper (see LICENSE-BTR.txt), by way of BiliNative's RangeDownloader.swift.

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import '../shared/byte_range.dart';
import 'attempt.dart';
import 'cancel.dart';
import 'connection_pool.dart';
import 'hurry_placement.dart';
import 'piece_downloader.dart';
import 'primary_assigner.dart';
import 'resolver.dart';
import 'transport.dart';

/// Port of RangeDownloader.swift. Its task groups become races that, like a task group, end only once every
/// child has: the first success or the first failure decides, then the rest are cancelled and awaited.
final class RangeDownloader {
  RangeDownloader(this.ctx) : pieces = PieceDownloader(ctx);

  final EngineContext ctx;
  final PieceDownloader pieces;
  final assigner = PrimaryAssigner();

  /// BTR `downloadStartupRange`: init and index in one request, raced over up to three nodes
  /// started 0, 120 and 300 ms apart; rounds as for pieces.
  Future<AttemptOutput> meta(ByteRange range, Resolver resolver, {CancelToken? cancel}) async {
    final started = ctx.clock.nowMs();
    Object lastError = const RipperError(RipperErrorKind.noNodes);
    for (var round = 0; round < ctx.config.pieceRounds; round++) {
      if (round > 0 && !await ctx.pauseBeforeRound(round, startedAt: started, cancel: cancel)) break;
      var candidates = resolver.startupCandidates().take(3).toList();
      if (candidates.isEmpty && round > 0) candidates = resolver.ordered(pieceIndex: round).take(3).toList();
      if (candidates.isEmpty) break;
      try {
        return await _firstSuccess(candidates, range, resolver, cancel);
      } catch (error) {
        if (cancel?.isCancelled ?? false) throw const CancelledException();
        lastError = error;
      }
    }
    throw lastError;
  }

  /// The first copy to succeed wins and the others are cancelled; when every copy fails, the last error.
  Future<AttemptOutput> _firstSuccess(
    List<String> candidates,
    ByteRange range,
    Resolver resolver,
    CancelToken? cancel,
  ) {
    const delays = [0.0, 120.0, 300.0];
    final race = CancelToken(cancel);
    final result = Completer<AttemptOutput>();
    AttemptOutput? winner;
    var pending = candidates.length;
    Object lastError = const RipperError(RipperErrorKind.noNodes);

    Future<void> runOne(int index) async {
      try {
        await cancellableSleep(delays[index], race);
        final output = await pieces.runner.runAt(
          candidates[index],
          piece: range,
          progress: AttemptProgress(),
          resolver: resolver,
          priority: 220,
          queueClass: QueueClass.critical,
          cancel: race,
        );
        if (winner == null) {
          winner = output;
          race.cancel();
        }
      } catch (error) {
        if (error is! CancelledException) lastError = error;
      } finally {
        pending -= 1;
        if (pending == 0) {
          final output = winner;
          if (output != null) {
            result.complete(output);
          } else {
            result.completeError((cancel?.isCancelled ?? false) ? const CancelledException() : lastError);
          }
        }
      }
    }

    for (var index = 0; index < candidates.length; index++) {
      unawaited(runOne(index));
    }
    return result.future.whenComplete(race.dispose);
  }

  /// The bytes of [range] in file order, each piece handed to [emit] as soon as it and all before it are in.
  /// Every piece's advertised file size must equal [expectedTotal] (when given) and each other's; a piece that
  /// disagrees fails the range before any of its bytes are emitted. [hurry] says whether playback is about to
  /// need this range: it is read once here, to size and place the pieces, and again by each piece while it
  /// waits to send another copy. [deadline] returns when playback needs the range, as a monotonic time in ms;
  /// it is re-read on every pass of the connection queue and by each piece's backup copy. A startup range with
  /// [burst] races its head first (`RipperConfig.seekBurst`); [lane] ranks every request (`RequestLane`). Only a
  /// range with [probation] (prefetch) may give a banned node its trial copy.
  Future<void> stream(
    ByteRange range,
    Resolver resolver, {
    required bool startup,
    required double priority,
    required void Function(Uint8List bytes) emit,
    double Function()? deadline,
    int? expectedTotal,
    bool Function()? hurry,
    CancelToken? cancel,
    bool burst = false,
    RequestLane lane = RequestLane.any,
    bool probation = false,
  }) async {
    final hurryCheck = ctx.config.hurry ? hurry : null;
    final hurried = hurryCheck?.call() ?? false;
    final check = _TotalCheck(expectedTotal);

    var preferred = resolver.rangeCandidates(hurried: hurried, bytes: range.length);
    if (startup && burst) {
      return _burst(
        range,
        resolver,
        preferred: preferred,
        hurried: hurried,
        hurry: hurryCheck,
        deadline: deadline,
        check: check,
        emit: emit,
        cancel: cancel,
        lane: lane,
      );
    }
    var assignable = preferred;
    var remaining = range;
    var indexOffset = 0;
    // In a hurry with nodes already measured, placement by expected finish takes the place of the race.
    if (startup && !(hurried && preferred.any(ctx.nodes.isKnown))) {
      // A small head piece raced over every candidate measures the nodes and gets the first bytes
      // to the player fast; the rest is then spread over the nodes that proved themselves.
      final headLength = min(range.length, max(64 * 1024, ctx.config.minChunkBytes));
      final head = ByteRange(range.start, range.start + headLength - 1);
      final result = await pieces.download(
        piece: head,
        index: 0,
        resolver: resolver,
        preferred: preferred,
        mode: PieceMode.probe,
        priority: 220,
        deadline: deadline,
        hurry: hurryCheck,
        cancel: cancel,
        lane: lane,
      );
      check(result);
      emit(result.bytes);
      if (head.end >= range.end) return;
      remaining = ByteRange(head.end + 1, range.end);
      preferred = [result.url, ...preferred.where((url) => url != result.url)];
      assignable = preferred.where((url) => url == result.url || resolver.speed(url) > 0).toList();
      indexOffset = 1;
    }
    final (parts, primaries, window) = _place(
      remaining,
      resolver,
      preferred: preferred,
      assignable: assignable,
      hurried: hurried,
    );
    final mode = startup ? PieceMode.startup : PieceMode.normal;
    final order = preferred;
    final run = _InOrder(cancel, check: check.call, emit: emit);
    for (var offset = 0; offset < parts.length; offset++) {
      final primary = offset < primaries.length ? primaries[offset] : order.firstOrNull;
      final piecePreferred = primary == null ? order : [primary, ...order.where((url) => url != primary)];
      final pieceIndex = offset + indexOffset;
      final piecePriority = startup ? 120.0 - min(30, pieceIndex) : priority - min(20, pieceIndex);
      run.add(
        (token) => _Window.within(
          window,
          token,
          () => pieces.download(
            piece: parts[offset],
            index: pieceIndex,
            resolver: resolver,
            preferred: piecePreferred,
            mode: mode,
            priority: piecePriority,
            deadline: deadline,
            hurry: hurryCheck,
            cancel: token,
            lane: lane,
            holdingUp: run.holdingUp,
            probation: probation,
          ),
        ),
      );
    }
    await run.close();
  }

  /// The pieces of [remaining], the node each tries first (by expected finish in a hurry, otherwise in weighted
  /// turns over [assignable]), and, when [RipperConfig.hurryPieceBytes] cut more pieces than may run at once, the
  /// window they run in.
  (List<ByteRange>, List<String>, _Window?) _place(
    ByteRange remaining,
    Resolver resolver, {
    required List<String> preferred,
    required List<String> assignable,
    required bool hurried,
  }) {
    final concurrency = ctx.pool.limit;
    final rescueReserve = concurrency >= 8 ? min(8, max(1, (concurrency + 7) ~/ 8)) : 0;
    final pieceConcurrency = max(1, concurrency - rescueReserve);
    // In a hurry many small requests get through best: right after a seek a node can be slow over a part
    // of the file it has not served lately, and a small piece is cheap to copy elsewhere (BTR PR 11).
    final minChunk = hurried
        ? ctx.config.minChunkBytes
        : ctx.meter.adaptiveMinChunk(
            base: ctx.config.minChunkBytes,
            rangeLength: remaining.length,
            pieceLimit: pieceConcurrency,
            hostCount: preferred.length,
          );
    final cap = hurried ? ctx.config.hurryPieceBytes : null;
    final parts = cap == null
        ? remaining.split(concurrency: pieceConcurrency, minChunk: minChunk)
        : remaining.split(
            concurrency: max(pieceConcurrency, (remaining.length + cap - 1) ~/ cap),
            minChunk: min(minChunk, cap),
          );
    final primaries = hurried
        ? HurryPlacement.assign(
            urls: preferred,
            count: parts.length,
            pieceBytes: parts.first.length,
            nodes: ctx.nodes,
            delivered: (url) => resolver.bans?.hasDelivered(url) ?? true,
          )
        : assigner.assign(
            urls: assignable,
            count: parts.length,
            speed: resolver.speed,
            trialKey: resolver,
            isFull: (url, placed) => ctx.nodes.isFull(url, extraInflight: placed),
          );
    // Their first copies would otherwise take the connections kept free for backups, which a cold CDN needs most.
    return (parts, primaries, parts.length > pieceConcurrency ? _Window(pieceConcurrency) : null);
  }

  /// A seek's head, first [RipperConfig.seekBurstBytes] of it in 64 KiB pieces, all asked for at once: the first on
  /// [RipperConfig.seekBurstCopies] nodes together, the others on two, so the first piece of a cold seek no longer
  /// waits 250-600 ms for its second copy. The rest of the range is placed as a startup range's, at once when the
  /// nodes are measured; otherwise the first piece is the probe, raced over every candidate, and the rest waits for
  /// what it measures. In the pool the rest queues behind the head, whose pieces are critical.
  Future<void> _burst(
    ByteRange range,
    Resolver resolver, {
    required List<String> preferred,
    required bool hurried,
    required bool Function()? hurry,
    required double Function()? deadline,
    required _TotalCheck check,
    required void Function(Uint8List bytes) emit,
    required CancelToken? cancel,
    required RequestLane lane,
  }) async {
    const pieceBytes = 64 * 1024;
    final headLength = min(range.length, max(pieceBytes, ctx.config.seekBurstBytes));
    final head = [
      for (var start = range.start; start < range.start + headLength; start += pieceBytes)
        ByteRange(start, min(range.start + headLength, start + pieceBytes) - 1),
    ];
    final known = preferred.any(ctx.nodes.isKnown);
    final best = known
        ? HurryPlacement.byExpectedFinish(
            preferred,
            pieceBytes: pieceBytes,
            nodes: ctx.nodes,
            delivered: (url) => resolver.bans?.hasDelivered(url) ?? true,
          )
        : preferred;
    final width = max(1, ctx.config.seekBurstCopies);
    final run = _InOrder(cancel, check: check.call, emit: emit);
    Future<AttemptOutput> headPiece(int index) => run.add(
      (token) => pieces.download(
        piece: head[index],
        index: index,
        resolver: resolver,
        // Each piece starts its race one node further along, so the head spreads over the best nodes.
        preferred: index == 0 || best.isEmpty
            ? best
            : [...best.skip(index % best.length), ...best.take(index % best.length)],
        mode: index == 0 && !known ? PieceMode.probe : PieceMode.burst,
        priority: 220.0 - index,
        deadline: deadline,
        hurry: hurry,
        cancel: token,
        burstWidth: index == 0 ? width : min(width, 2),
        lane: lane,
        holdingUp: run.holdingUp,
      ),
    );
    final first = headPiece(0);
    for (var index = 1; index < head.length; index++) {
      headPiece(index);
    }
    final headEnd = head.last.end;
    if (headEnd < range.end) {
      var ordered = preferred;
      var assignable = preferred.where((url) => resolver.speed(url) > 0).toList();
      if (known) {
        // The head's copies ask for their connections a microtask after they start (see PieceDownloader); the rest
        // must ask after them, or its pieces take the free connections first.
        await Future<void>.value();
      } else {
        AttemptOutput? measured;
        try {
          measured = await first;
        } catch (_) {
          // The run has failed with it; close() reports why.
        }
        if (measured == null) return run.close();
        final winner = measured.url;
        ordered = [winner, ...preferred.where((url) => url != winner)];
        assignable = ordered.where((url) => url == winner || resolver.speed(url) > 0).toList();
      }
      final (parts, primaries, window) = _place(
        ByteRange(headEnd + 1, range.end),
        resolver,
        preferred: ordered,
        assignable: assignable.isEmpty ? ordered : assignable,
        hurried: hurried,
      );
      for (var offset = 0; offset < parts.length; offset++) {
        final primary = offset < primaries.length ? primaries[offset] : ordered.first;
        final pieceIndex = head.length + offset;
        run.add(
          (token) => _Window.within(
            window,
            token,
            () => pieces.download(
              piece: parts[offset],
              index: pieceIndex,
              resolver: resolver,
              preferred: [primary, ...ordered.where((url) => url != primary)],
              mode: PieceMode.startup,
              priority: 120.0 - min(30, pieceIndex),
              deadline: deadline,
              hurry: hurry,
              cancel: token,
              lane: lane,
              holdingUp: run.holdingUp,
            ),
          ),
        );
      }
    }
    await run.close();
  }

  /// [range] as one piece, its first [copies] copies raced together on the nodes expected to deliver it first:
  /// a small audio read under [RipperConfig.audioFirst], where a probe and a split only add round trips.
  Future<void> whole(
    ByteRange range,
    Resolver resolver, {
    required int copies,
    required double priority,
    required void Function(Uint8List bytes) emit,
    double Function()? deadline,
    int? expectedTotal,
    bool Function()? hurry,
    CancelToken? cancel,
    RequestLane lane = RequestLane.any,
  }) async {
    final preferred = resolver.rangeCandidates(hurried: ctx.config.hurry && (hurry?.call() ?? false), bytes: range.length);
    final ordered = preferred.any(ctx.nodes.isKnown)
        ? HurryPlacement.byExpectedFinish(
            preferred,
            pieceBytes: range.length,
            nodes: ctx.nodes,
            delivered: (url) => resolver.bans?.hasDelivered(url) ?? true,
          )
        : preferred;
    final output = await pieces.download(
      piece: range,
      index: 0,
      resolver: resolver,
      preferred: ordered,
      mode: PieceMode.burst,
      priority: priority,
      deadline: deadline,
      hurry: ctx.config.hurry ? hurry : null,
      cancel: cancel,
      burstWidth: copies,
      lane: lane,
    );
    _TotalCheck(expectedTotal)(output);
    emit(output.bytes);
  }
}

/// Every piece of a range must advertise the same file size, and the one the headers gave when known.
final class _TotalCheck {
  _TotalCheck(this._known);

  int? _known;

  void call(AttemptOutput output) {
    final total = output.total;
    if (total == null) return;
    if (_known != null && _known != total) throw const RipperError(RipperErrorKind.totalMismatch);
    _known = total;
  }
}

/// Pieces of one range, run together and handed on in the order they were added. The first failure cancels the
/// rest; like Swift's task group, [close] ends only once every piece has.
/// At most [limit] pieces of one range downloading at once, the rest waiting their turn in order.
final class _Window {
  _Window(this.limit);

  final int limit;
  var _running = 0;
  final _waiting = Queue<Completer<void>>();

  static Future<T> within<T>(_Window? window, CancelToken cancel, Future<T> Function() task) =>
      window == null ? task() : window._run(cancel, task);

  Future<T> _run<T>(CancelToken cancel, Future<T> Function() task) async {
    if (_running < limit) {
      _running += 1;
    } else {
      final turn = Completer<void>();
      _waiting.add(turn);
      try {
        await cancel.guard(turn.future);
      } catch (_) {
        // Handed the turn just as it was cancelled: pass it on.
        if (!_waiting.remove(turn)) _release();
        rethrow;
      }
    }
    try {
      return await task();
    } finally {
      _release();
    }
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _running -= 1;
    }
  }
}

final class _InOrder {
  _InOrder(CancelToken? cancel, {required this.check, required this.emit}) : _local = CancelToken(cancel);

  final CancelToken _local;
  final void Function(AttemptOutput output) check;
  final void Function(Uint8List bytes) emit;
  final _ready = <int, AttemptOutput>{};
  final _done = Completer<void>();
  var _added = 0;
  var _next = 0;
  var _pending = 0;
  var _closed = false;
  Object? _failure;
  StackTrace? _failureStack;

  /// Whether one piece is all that is left running, so the whole range waits on it.
  bool holdingUp() => _pending == 1;

  Future<AttemptOutput> add(Future<AttemptOutput> Function(CancelToken cancel) download) {
    final order = _added++;
    _pending += 1;
    final result = Completer<AttemptOutput>();
    // A failed piece fails the range on its own, so nobody has to wait on its future.
    unawaited(result.future.then<void>((_) {}, onError: (Object _) {}));
    Future<void> run() async {
      try {
        final output = await download(_local);
        if (_failure != null) {
          result.completeError(const CancelledException());
          return;
        }
        check(output);
        result.complete(output);
        _ready[order] = output;
        for (var item = _ready.remove(_next); item != null; item = _ready.remove(_next)) {
          emit(item.bytes);
          _next += 1;
        }
      } catch (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
        if (_failure != null) return;
        _failure = error;
        _failureStack = stack;
        _local.cancel();
      } finally {
        _pending -= 1;
        _finish();
      }
    }

    unawaited(run());
    return result.future;
  }

  /// No more pieces will be added; completes once every piece has ended, with the first failure if there was one.
  Future<void> close() async {
    _closed = true;
    _finish();
    try {
      await _done.future;
    } finally {
      _local.dispose();
    }
  }

  void _finish() {
    if (!_closed || _pending > 0 || _done.isCompleted) return;
    final error = _failure;
    if (error != null) {
      _done.completeError(error, _failureStack);
    } else {
      _done.complete();
    }
  }
}
