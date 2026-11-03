// Port of Bilibili-thread-ripper (see LICENSE-BTR.txt), by way of BiliNative's RipperSession.swift.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../devlog/log_event.dart';
import '../devlog/logger.dart';
import '../shared/byte_range.dart';
import '../shared/clock.dart';
import '../shared/media_segment.dart';
import 'attempt.dart';
import 'auto_concurrency.dart';
import 'ban_list.dart';
import 'cancel.dart';
import 'connection_pool.dart';
import 'node_catalog.dart';
import 'node_memory.dart';
import 'node_stats.dart';
import 'playback_engine.dart';
import 'range_downloader.dart';
import 'resolver.dart';
import 'ripper_config.dart';
import 'transport.dart';

final class TrackHeaders {
  const TrackHeaders({required this.bytes, required this.totalSize});

  /// Bytes 0 through the end of the SIDX: init segment plus index.
  final Uint8List bytes;
  final int totalSize;
}

typedef TrackSource = ({String primary, List<String> backups});

typedef _Key = (TrackKind, ByteRange);

final class _CacheEntry {
  const _CacheEntry(this.bytes, this.endTime, {this.startTime = 0, this.served = false});

  final Uint8List bytes;
  final double startTime;
  final double endTime;

  /// The player has read it: kept as back buffer ([RipperConfig.keepBehindBytes]), not counted as prefetch.
  final bool served;
}

/// Why a segment downloads ahead of the player's request for it.
enum _FetchKind {
  prefetch,

  /// The start position, before the player's first request ([RipperSession.prime]).
  prime,

  /// Where a finger rests on the seek bar ([RipperSession.hint]).
  hint,
}

/// A segment downloading ahead of the player: Swift's prefetch Task, cancelled through its token. Its bytes so far
/// are kept in order, so a read that takes it over can pass them on before it ends ([RipperConfig.streamAdopted]).
final class _Prefetch {
  _Prefetch(this.token, {this.kind = _FetchKind.prefetch, this.startedAt = 0});

  final CancelToken token;
  final _FetchKind kind;
  final double startedAt;
  late final Future<Uint8List> bytes;
  double? firstByteAt;
  int received = 0;

  /// A player read took it over at least once.
  bool adopted = false;
  final _chunks = <Uint8List>[];
  final _listeners = <int, void Function(Uint8List chunk)>{};
  int _nextListener = 0;

  List<Uint8List> get chunks => List.of(_chunks);

  void add(Uint8List chunk, {required double at}) {
    firstByteAt ??= at;
    received += chunk.length;
    _chunks.add(chunk);
    for (final listener in _listeners.values.toList()) {
      listener(chunk);
    }
  }

  /// Returns a function that stops the listener.
  void Function() listen(void Function(Uint8List chunk) listener) {
    final id = _nextListener++;
    _listeners[id] = listener;
    return () => _listeners.remove(id);
  }

  Uint8List takeBytes() {
    final builder = BytesBuilder(copy: false);
    _chunks.forEach(builder.add);
    _chunks.clear();
    return builder.takeBytes();
  }
}

/// New prefetch waits while a seek's head is on its way ([RipperConfig.seekBurst]); [landed] lets it go once the
/// head is in, [end] when the read ends first.
final class _Hold {
  _Hold(this._head, this._release);

  final int _head;
  final void Function() _release;
  bool _done = false;

  void landed(int bytes) {
    if (bytes >= _head) end();
  }

  void end() {
    if (_done) return;
    _done = true;
    _release();
  }
}

final class _Request {
  _Request({this.memory, this.segment, this.number = 0, this.seek = false, this.firstOfTrack = false, this.total});

  /// Served from the headers or the cache.
  Uint8List? memory;

  /// A prefetch the request took over.
  _Prefetch? adopted;

  /// A plain prefetch a seek landed on ([RipperConfig.seekHurriesPrefetch]): its bytes so far go to the player,
  /// then it is cancelled and the rest is fetched as a seek.
  _Prefetch? superseded;
  final MediaSegment? segment;
  final int number;
  final bool seek;
  final bool firstOfTrack;
  final int? total;
  int generation = 0;
}

/// One playback in BTR mode (port of RipperSession.swift): both tracks' resolvers, the shared connection pool, the
/// segment cache and prefetch. Each player request is one byte range, usually one whole SIDX segment, which [read]
/// splits into pieces fetched across the nodes and delivers in order; the segments after it are then prefetched.
/// Everything runs on the engine isolate, so Swift's locks have no counterpart here.
final class RipperSession {
  factory RipperSession({
    required Map<TrackKind, TrackSource> sources,
    required NodeMode mode,
    required RangeTransport transport,
    AutoConcurrency? auto,
    RipperConfig config = const RipperConfig(),
    MediaURLPolicy policy = MediaURLPolicy.bilibili,
    MonotonicClock? clock,
    Logger? logger,
    NodeMemory? memory,
  }) {
    final follower = config.fixedConcurrency == null ? auto : null;
    final monotonic = clock ?? MonotonicClock.system;
    final pool = ConnectionPool(
      config.fixedConcurrency ?? follower?.threads ?? RipperConfig.defaultConcurrency,
      clock: monotonic,
    );
    final ctx = EngineContext(
      transport: transport,
      pool: pool,
      config: config,
      auto: follower,
      clock: monotonic,
      logger: logger,
    );
    final priors = memory?.priors ?? NodePriors.empty;
    ctx.nodes
      ..priors = priors
      ..onMeasured = memory?.record
      ..exploreInHurry = config.exploreInHurry
      ..tailBackups = config.tailBackups
      ..keepsOffSlow = config.hurryKeepsOffSlow
      ..median = config.medianEstimates;
    return RipperSession._(ctx, sources, mode, policy, priors);
  }

  RipperSession._(
    this._ctx,
    Map<TrackKind, TrackSource> sources,
    NodeMode mode,
    MediaURLPolicy policy,
    NodePriors priors,
  ) {
    _resolvers = {
      for (final MapEntry(key: kind, value: source) in sources.entries)
        kind: Resolver(
          primary: source.primary,
          backups: source.backups,
          mode: mode,
          policy: policy,
          bans: _bans,
          clock: _ctx.clock,
          nodes: _ctx.nodes,
          priors: priors,
          exploreInHurry: _ctx.config.exploreInHurry,
        ),
    };
    if (_ctx.config.banProbation) _bans.probation = BanProbation(clock: _ctx.clock);
    _downloader = RangeDownloader(_ctx);
    _bans.onBan = (node, strikes, kind) =>
        _ctx.logger.warn(LogCategory.engine, 'ban', {'node': node, 'strikes': strikes, 'kind': kind.name});
    final follower = _ctx.auto;
    if (follower != null) {
      final pool = _ctx.pool;
      pool.onChange = (active, limit, queued) => follower.demand(active: active, limit: limit, queued: queued);
      // The connection count is app-wide with one handler slot: the newest session takes it. The limit is read
      // from `threads`, not taken from the arguments, as Swift does for deliveries that arrive out of order.
      _followerHandler = (threads, previous, reason) {
        if (_closed) return;
        pool.setLimit(follower.threads);
        _ctx.logger.info(LogCategory.engine, 'threads', {'threads': threads, 'previous': previous, 'reason': reason});
      };
      follower.onChange = _followerHandler;
      follower.newSession();
      pool.setLimit(follower.threads);
    }
  }

  /// Audio player reads rank above every video request of their class, audio prefetch just above video prefetch
  /// ([RipperConfig.audioFirst]). 100 outweighs the 12 a deadline adds and over 4 s of a video request's aging.
  static const _audioReadBoost = 100.0;
  static const _audioPrefetchBoost = 5.0;

  final EngineContext _ctx;
  final _bans = BanList();
  late final Map<TrackKind, Resolver> _resolvers;
  late final RangeDownloader _downloader;
  ConcurrencyChange? _followerHandler;

  /// Parent of every read and prefetch, so [close] reaches them all.
  final _root = CancelToken();
  final _headers = <TrackKind, TrackHeaders>{};
  final _segments = <TrackKind, List<MediaSegment>>{};

  /// Position in [_segments] by range start.
  final _segmentAt = <TrackKind, Map<int, int>>{};

  /// Bytes per second of the video, for [RipperConfig.prefetchVideoMaxBytes].
  final _byteRate = <TrackKind, double>{};
  final _cache = <_Key, _CacheEntry>{};
  final _inflight = <_Key, _Prefetch>{};

  /// Each track's latest hint, so a newer one can cancel it.
  final _hints = <TrackKind, _Key>{};

  /// Heads of seek reads still on their way, and the prefetch held back until they are in.
  int _bursting = 0;
  final _deferred = <TrackKind, MediaSegment>{};

  /// Bumped by [_dropPrefetch]; a reader that adopted a prefetch before a seek must not hand it back after.
  final _seekGeneration = <TrackKind, int>{};

  /// Segments a player request is downloading or waiting on, with how many requests; prefetch leaves them alone.
  final _playerPending = <_Key, int>{};
  final _lastRequest = <TrackKind, ByteRange>{};
  double _playhead = 0;
  double _rate = 1;
  int _reads = 0;
  int _requests = 0;

  /// Requests numbered up to this were already covered by an [onFatal] call.
  int _fatalCovered = 0;
  int _seeks = 0;
  bool _closed = false;

  /// A player request failed after every retry: the app refreshes the URLs or falls back to direct mode.
  /// Requests that fail together are reported once; a request made after a report can report again.
  void Function(Object error)? onFatal;

  bool get isClosed => _closed;
  int get deliveredBytes => _ctx.stats.deliveredBytes;

  bool get _retains => _ctx.config.keepBehindBytes > 0;

  Future<TrackHeaders> loadHeaders(TrackKind track, {required int through}) async {
    if (_closed) throw const RipperError(RipperErrorKind.closed);
    final resolver = _resolvers[track];
    final range = ByteRange.of(0, through);
    if (resolver == null || range == null) throw const RipperError(RipperErrorKind.noNodes);
    final AttemptOutput output;
    try {
      output = await _downloader.meta(range, resolver, cancel: _root);
    } on CancelledException {
      if (_closed) throw const RipperError(RipperErrorKind.closed);
      rethrow;
    }
    final total = output.total;
    if (total == null) throw const RipperError.badResponse(206);
    final headers = TrackHeaders(bytes: output.bytes, totalSize: total);
    _headers[track] = headers;
    _ctx.logger.info(LogCategory.engine, 'headers', {
      'track': track.name,
      'bytes': output.bytes.length,
      'node': NodeCatalog.nodeKey(output.url),
    });
    return headers;
  }

  void setSegments(TrackKind track, List<MediaSegment> segments) {
    _segments[track] = segments;
    _segmentAt[track] = {
      for (var position = 0; position < segments.length; position++) segments[position].range.start: position,
    };
    final span = segments.isEmpty ? 0.0 : segments.last.endTime - segments.first.startTime;
    if (span > 0) {
      _byteRate[track] = segments.fold(0, (sum, segment) => sum + segment.range.length) / span;
    } else {
      _byteRate.remove(track);
    }
  }

  /// Starts the segment at [seconds] downloading as the player's first read of it would, before the player asks:
  /// that read then takes it over. With [RipperConfig.prefetchOnPrime] the segments after it are prefetched at
  /// once, after the head is in when [RipperConfig.seekBurst] is on.
  void prime(TrackKind track, {required double seconds}) {
    if (_closed) return;
    final segment = _segmentAtTime(track, seconds);
    if (segment == null) return;
    // Playback starts here: deadlines and the look-ahead count from it until the player reports a position.
    _playhead = seconds;
    _start(track, segment, _FetchKind.prime);
    if (_ctx.config.prefetchOnPrime) _schedulePrefetch(track, segment);
  }

  /// The user is about to seek to [seconds]: each track's segment there downloads as a seek read would, without
  /// counting as the player's seek; the seek's read then takes it over. A newer hint cancels an older one still
  /// downloading, so each track has at most one; null cancels them.
  void hint(double? seconds) {
    if (_closed) return;
    for (final track in _resolvers.keys) {
      final segment = seconds == null ? null : _segmentAtTime(track, seconds);
      final key = segment == null ? null : (track, segment.range);
      final previous = _hints[track];
      if (previous != null && previous != key) {
        _hints.remove(track);
        final running = _inflight[previous];
        if (running != null && running.kind == _FetchKind.hint) {
          _inflight.remove(previous);
          running.token.cancel();
        }
      }
      if (segment != null && key != null && _start(track, segment, _FetchKind.hint)) _hints[track] = key;
    }
  }

  /// Single subscription. Cancelling the subscription cancels every piece of the read at once; a prefetch the read
  /// took over goes on downloading.
  Stream<List<int>> read(TrackKind track, ByteRange range) {
    if (_closed) return Stream.error(const RipperError(RipperErrorKind.closed));
    final token = CancelToken(_root);
    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        _reads += 1;
        _serve(track, range, controller.add, token)
            .then(
              (_) => controller.close(),
              onError: (Object error, StackTrace stack) {
                controller.addError(_closed ? const RipperError(RipperErrorKind.closed) : error, stack);
                controller.close();
              },
            )
            .whenComplete(() {
              _reads -= 1;
              token.dispose();
            });
      },
      onCancel: token.cancel,
    );
    return controller.stream;
  }

  void updatePlayhead({required double seconds, required double rate}) {
    _playhead = seconds;
    _rate = rate.isFinite && rate > 0 ? rate : 1;
    _cache.removeWhere((_, entry) => entry.endTime < seconds - _ctx.config.keepBehindSeconds);
    if (_retains) _trimKept();
  }

  /// The controller reports media seconds; concurrency pressure follows time left at the current speed.
  void reportBuffer({required double aheadSeconds, required bool playing}) =>
      _ctx.auto?.buffer(ahead: max(0, aheadSeconds) / _rate, playing: playing);

  void reportStall() => _ctx.auto?.stall();

  void replaceUrls(TrackKind track, {required String primary, required List<String> backups}) {
    _resolvers[track]?.replaceURLs(primary: primary, backups: backups);
    _ctx.logger.info(LogCategory.engine, 'urls replaced', {'track': track.name, 'url': primary});
  }

  /// The phone's network path changed: bans and backoffs from the old path are dropped, and with
  /// a different interface the speed measurements too.
  void networkChanged({required bool interfaceChanged}) {
    _bans.reset();
    for (final resolver in _resolvers.values) {
      resolver.resetHealth(clearMeasurements: interfaceChanged);
    }
    _ctx.nodes.reset();
    _ctx.logger.info(LogCategory.engine, 'network changed, node health reset', {'interfaceChanged': interfaceChanged});
  }

  /// Memory warning: drops cached and still-downloading prefetched segments; playback goes on. Under
  /// [RipperConfig.trimOnMemoryWarning] the segments within [_trimBehindSeconds] behind the playhead and
  /// `hurryAheadSeconds` of the video ahead of it stay.
  void dropCache() {
    if (_ctx.config.trimOnMemoryWarning) {
      _trimCache();
      return;
    }
    _cache.clear();
    final prefetches = _inflight.values.toList();
    _inflight.clear();
    for (final prefetch in prefetches) {
      prefetch.token.cancel();
    }
  }

  /// The page was covered (Swift's `dropCache()` from `cover()`): every cached segment, the back buffer too, and
  /// every prime, hint and prefetch still downloading go; the player's own reads go on. A reader that took a
  /// prefetch over doesn't hand it back.
  void dropPrefetch() {
    var dropped = 0;
    for (final entry in _cache.values) {
      dropped += entry.bytes.length;
    }
    _cache.clear();
    _deferred.clear();
    _hints.clear();
    for (final track in _resolvers.keys) {
      _seekGeneration[track] = (_seekGeneration[track] ?? 0) + 1;
    }
    final prefetches = _inflight.values.toList();
    _inflight.clear();
    for (final prefetch in prefetches) {
      dropped += prefetch.received;
      prefetch.token.cancel();
    }
    _ctx.logger.info(LogCategory.engine, 'prefetch dropped', {'droppedBytes': dropped, 'cancelled': prefetches.length});
  }

  static const _trimBehindSeconds = 5.0;

  void _trimCache() {
    // Not scaled by the rate: at 2x on 8K that would keep about 100 MB after the warning.
    final ahead = _ctx.config.hurryAheadSeconds;
    bool near(double start, double end) => end >= _playhead - _trimBehindSeconds && start <= _playhead + ahead;
    var kept = 0;
    var dropped = 0;
    _cache.removeWhere((key, entry) {
      final drop = !near(entry.startTime, entry.endTime);
      if (drop) {
        dropped += entry.bytes.length;
      } else {
        kept += entry.bytes.length;
      }
      return drop;
    });
    for (final key in _inflight.keys.toList()) {
      final segment = _segmentFor(key);
      if (segment != null && near(segment.startTime, segment.endTime)) continue;
      final prefetch = _inflight.remove(key);
      if (prefetch == null) continue;
      dropped += prefetch.received;
      prefetch.token.cancel();
    }
    _ctx.logger.info(LogCategory.engine, 'cache trimmed', {'keptBytes': kept, 'droppedBytes': dropped});
  }

  EngineSnapshot stats({double downloadBps = 0, String transport = '', String? token}) => _ctx.stats.snapshot(
    concurrency: _ctx.pool.limit,
    nodeStates: _resolvers[TrackKind.video]?.status() ?? const [],
    downloadBps: downloadBps,
    transport: transport,
    token: token,
  );

  void close() {
    if (_closed) return;
    _closed = true;
    _cache.clear();
    _deferred.clear();
    _hints.clear();
    final prefetches = _inflight.values.toList();
    _inflight.clear();
    _ctx.pool.onChange = null;
    // Swift's handler holds the session weakly and does nothing once it is closed; dropping it does the same and
    // lets the session go.
    final follower = _ctx.auto;
    if (follower != null && identical(follower.onChange, _followerHandler)) follower.onChange = null;
    for (final prefetch in prefetches) {
      prefetch.token.cancel();
    }
    _root.cancel();
  }

  Future<void> _serve(TrackKind track, ByteRange range, void Function(Uint8List bytes) emit, CancelToken token) async {
    final resolver = _resolvers[track];
    if (resolver == null) throw const RipperError(RipperErrorKind.noNodes);
    final config = _ctx.config;
    final began = _ctx.clock.nowMs();
    final key = (track, range);
    final request = _plan(track, range, key);
    final pending = request.memory == null;
    final segment = request.segment;
    // A whole segment the player reads is kept as back buffer.
    final kept = pending && _retains && segment != null ? BytesBuilder(copy: false) : null;
    final hold = pending && request.seek && request.adopted == null ? _holdPrefetch(range) : null;
    double? firstByteAt;
    var sent = 0;
    void out(Uint8List bytes) {
      firstByteAt ??= _ctx.clock.nowMs();
      sent += bytes.length;
      kept?.add(bytes);
      emit(bytes);
      hold?.landed(sent);
    }

    final audioWait = pending && track == TrackKind.audio && config.audioFirst;
    if (audioWait) _ctx.audioReadBegan();
    try {
      var served = false;
      var source = 'fetch';
      final adopted = request.adopted;
      if (request.memory case final bytes?) {
        _ctx.stats.cache(hit: true);
        out(bytes);
        served = true;
        source = 'memory';
      } else if (adopted != null) {
        final bytes = await _takeOver(adopted, out, token);
        if (token.isCancelled) {
          _returnPrefetch(adopted, key, endTime: segment?.endTime ?? 0, generation: request.generation);
          throw const CancelledException();
        }
        if (bytes != null) {
          _ctx.stats.cache(hit: true);
          if (sent < bytes.length) out(Uint8List.sublistView(bytes, sent));
          served = true;
          source = adopted.kind.name;
        }
      }
      if (request.superseded case final old? when !served) {
        old.chunks.forEach(out);
        old.token.cancel();
        _ctx.logger.info(LogCategory.engine, 'seek hurried prefetch', {
          'track': track.name,
          'segment': segment?.index ?? -1,
          'kept': sent,
          'bytes': range.length,
        });
      }
      if (!served) {
        _ctx.stats.cache(hit: false);
        // Nothing of the track was prefetched before its first read, so only a later seek has anything to drop. A
        // seek onto a segment prefetch had reached stays near the old position, so the prefetch ahead stays too.
        if (adopted == null && request.superseded == null && request.seek && !request.firstOfTrack) {
          _dropPrefetch(track);
          _ctx.auto?.newSession();
        }
        // A streamed prefetch that broke off has already sent the front of the range.
        final rest = sent == 0 ? range : ByteRange(range.start + sent, range.end);
        try {
          await _download(
            track,
            rest,
            resolver,
            startup: request.seek,
            player: true,
            segment: segment,
            total: request.total,
            emit: out,
            cancel: token,
          );
          token.throwIfCancelled();
        } catch (error) {
          if (!token.isCancelled && error is! CancelledException) {
            _ctx.logger.error(LogCategory.engine, 'range failed', {
              'track': track.name,
              'range': '$range',
              'error': '$error',
            });
            if (_claimFatal(request.number)) onFatal?.call(error);
          }
          rethrow;
        }
      }
      if (kept != null && segment != null && !_closed) _keep(key, kept.takeBytes(), segment);
      final now = _ctx.clock.nowMs();
      final firstByteMs = ((firstByteAt ?? now) - began).roundToDouble();
      _ctx.logger.debug(LogCategory.engine, 'read', {
        'track': track.name,
        'range': '$range',
        'source': source,
        'seek': request.seek,
        'firstByteMs': firstByteMs,
        'ms': (now - began).roundToDouble(),
      });
      if (request.seek && pending) {
        _ctx.logger.info(LogCategory.engine, 'seek read', {
          'track': track.name,
          'segment': segment?.index ?? -1,
          'source': source,
          'first': request.firstOfTrack,
          'firstByteMs': firstByteMs,
          'ms': (now - began).roundToDouble(),
          'bytes': range.length,
        });
      }
      _schedulePrefetch(track, segment);
    } finally {
      hold?.end();
      if (audioWait) _ctx.audioReadEnded();
      if (pending) {
        final left = (_playerPending[key] ?? 1) - 1;
        if (left > 0) {
          _playerPending[key] = left;
        } else {
          _playerPending.remove(key);
        }
      }
    }
  }

  _Request _plan(TrackKind track, ByteRange range, _Key key) {
    if (_closed) throw const RipperError(RipperErrorKind.closed);
    final headers = _headers[track];
    if (headers != null && range.end < headers.bytes.length) {
      return _Request(memory: Uint8List.sublistView(headers.bytes, range.start, range.end + 1));
    }
    final positions = _segmentAt[track];
    final position = positions?[range.start];
    final previous = _lastRequest[track];
    _lastRequest[track] = range;
    _requests += 1;
    final request = _Request(
      segment: position == null ? null : _segments[track]?[position],
      number: _requests,
      seek: _isSeek(range, previous, positions),
      firstOfTrack: previous == null,
      total: headers?.totalSize,
    );
    final entry = _retains ? _cache[key] : _cache.remove(key);
    final prefetch = entry == null ? _inflight.remove(key) : null;
    final hinted = _hints[track] == key;
    if (hinted) _hints.remove(track);
    if (entry != null) {
      request.memory = entry.bytes;
      if (_retains) {
        _cache[key] = _CacheEntry(entry.bytes, entry.endTime, startTime: entry.startTime, served: true);
      }
      // A hint that finished before the finger lifted: the seek still leaves the old position behind.
      if (hinted && request.seek && !request.firstOfTrack) {
        _seeks += 1;
        _dropPrefetch(track);
        _ctx.auto?.newSession();
      }
    } else if (prefetch != null &&
        request.seek &&
        _ctx.config.seekHurriesPrefetch &&
        prefetch.kind == _FetchKind.prefetch &&
        prefetch.received < range.length) {
      request.superseded = prefetch;
      _seeks += 1;
      if (request.segment case final target?) _dropBefore(track, target.startTime);
    } else if (prefetch != null) {
      // Taken out of `_inflight`, so a seek cannot cancel it and its bytes do not also land in the cache.
      request.adopted = prefetch;
      // A seek onto a hint leaves the old position behind as any seek does; a prime is the start, not a seek.
      if (prefetch.kind == _FetchKind.hint && request.seek && !request.firstOfTrack) {
        _seeks += 1;
        _dropPrefetch(track);
        _ctx.auto?.newSession();
      }
      request.generation = _seekGeneration[track] ?? 0;
    } else if (request.seek) {
      _seeks += 1;
    }
    if (request.memory == null) _playerPending[key] = (_playerPending[key] ?? 0) + 1;
    return request;
  }

  /// AVPlayer may ask for a track's next segment before the current one is in, and two such requests
  /// can arrive out of order, so a request within a segment (or, unaligned, its own length) of the
  /// previous one is not a seek.
  static bool _isSeek(ByteRange range, ByteRange? previous, Map<int, int>? positions) {
    if (previous == null) return true;
    final position = positions?[range.start];
    final last = positions?[previous.start];
    if (position != null && last != null) return position < last - 1 || position > last + 2;
    return range.start < previous.start - range.length || range.start > previous.end + 1 + range.length;
  }

  bool _claimFatal(int number) {
    if (_closed || number <= _fatalCovered) return false;
    _fatalCovered = _requests;
    return true;
  }

  /// When playback needs this segment, as a monotonic time in ms; re-read on every queue pass.
  double Function()? _deadline(MediaSegment? segment) {
    if (segment == null) return null;
    final clock = _ctx.clock;
    return () => clock.nowMs() + max(0.0, segment.startTime - _playhead) / _rate * 1000;
  }

  /// Whether playback is about to need the segment: startup and seek reads always are, others once the segment
  /// starts less than `hurryAheadSeconds` of playback ahead. Re-read on every call, so a prefetch the playhead
  /// approaches turns into a hurry.
  bool Function() _hurry(MediaSegment? segment, {required bool startup}) {
    final config = _ctx.config;
    return () {
      if (!config.hurry) return false;
      if (startup) return true;
      if (segment == null) return false;
      return segment.startTime - _playhead < config.hurryAheadSeconds * _rate;
    };
  }

  /// One download for the player ([player], at the configured priority) or for prefetch (at 10). Under
  /// [RipperConfig.audioFirst] a small audio read for the player is one piece raced over two nodes.
  Future<void> _download(
    TrackKind track,
    ByteRange range,
    Resolver resolver, {
    required bool startup,
    required bool player,
    required MediaSegment? segment,
    required int? total,
    required void Function(Uint8List bytes) emit,
    required CancelToken cancel,
  }) {
    final config = _ctx.config;
    final lane = _lane(track, player: player);
    if (player && config.audioFirst && track == TrackKind.audio && range.length < config.audioWholeBytes) {
      return _downloader.whole(
        range,
        resolver,
        copies: 2,
        priority: 220,
        emit: emit,
        deadline: _deadline(segment),
        expectedTotal: total,
        hurry: _hurry(segment, startup: startup),
        cancel: cancel,
        lane: lane,
      );
    }
    return _downloader.stream(
      range,
      resolver,
      startup: startup,
      priority: player ? config.priority : 10,
      emit: emit,
      deadline: _deadline(segment),
      expectedTotal: total,
      hurry: _hurry(segment, startup: startup),
      cancel: cancel,
      burst: startup && config.seekBurst,
      lane: lane,
      probation: !player,
    );
  }

  RequestLane _lane(TrackKind track, {required bool player}) {
    if (!_ctx.config.audioFirst) return RequestLane.any;
    if (track == TrackKind.video) return const RequestLane(track: TrackKind.video);
    return player
        ? const RequestLane(track: TrackKind.audio, boost: _audioReadBoost, minClass: QueueClass.startup)
        : const RequestLane(track: TrackKind.audio, boost: _audioPrefetchBoost);
  }

  /// Under [RipperConfig.seekBurst], prefetch scheduled from now on waits until the first
  /// [RipperConfig.seekBurstBytes] of [range] are in or the read ends.
  _Hold? _holdPrefetch(ByteRange range) {
    if (!_ctx.config.seekBurst) return null;
    _bursting += 1;
    return _Hold(min(range.length, _ctx.config.seekBurstBytes), _releaseHold);
  }

  void _releaseHold() {
    if (_bursting > 0) _bursting -= 1;
    if (_bursting > 0 || _closed) return;
    final deferred = Map.of(_deferred);
    _deferred.clear();
    for (final MapEntry(key: track, value: segment) in deferred.entries) {
      _schedulePrefetch(track, segment);
    }
  }

  MediaSegment? _segmentFor(_Key key) {
    final position = _segmentAt[key.$1]?[key.$2.start];
    return position == null ? null : _segments[key.$1]?[position];
  }

  /// The segment playing at [seconds]: the last one starting at or before it.
  MediaSegment? _segmentAtTime(TrackKind track, double seconds) {
    final segments = _segments[track];
    if (segments == null || segments.isEmpty) return null;
    var low = 0;
    var high = segments.length - 1;
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (segments[middle].startTime <= seconds) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return segments[low];
  }

  /// A prime or a hint: the segment downloads as a player's seek read would, waiting in `_inflight` for the read
  /// that takes it over. False when the segment is cached, downloading or the player's already.
  bool _start(TrackKind track, MediaSegment segment, _FetchKind kind) {
    final resolver = _resolvers[track];
    final key = (track, segment.range);
    if (resolver == null || _closed) return false;
    if (_cache.containsKey(key) || _inflight.containsKey(key) || _playerPending.containsKey(key)) return false;
    final prefetch = _Prefetch(CancelToken(_root), kind: kind, startedAt: _ctx.clock.nowMs());
    prefetch.bytes = _fetchSegment(track, segment, resolver, _headers[track]?.totalSize, prefetch);
    _inflight[key] = prefetch;
    _watch(key, prefetch, segment.endTime);
    return true;
  }

  /// A seek forward onto a prefetched segment: the prefetch between the old position and the target would only compete
  /// with the target's fetch (hurried, since the playhead passed it).
  void _dropBefore(TrackKind track, double seconds) {
    _cache.removeWhere((key, entry) => key.$1 == track && !entry.served && entry.endTime <= seconds);
    for (final key in _inflight.keys.where((key) => key.$1 == track).toList()) {
      final segment = _segmentFor(key);
      if (segment != null && segment.endTime <= seconds) _inflight.remove(key)?.token.cancel();
    }
  }

  /// After a seek the track's prefetched segments belong to the old position; left in place they
  /// would hold the cap and keep the new position from being prefetched. Segments the player read stay.
  void _dropPrefetch(TrackKind track) {
    _seekGeneration[track] = (_seekGeneration[track] ?? 0) + 1;
    _cache.removeWhere((key, entry) => key.$1 == track && !entry.served);
    _deferred.remove(track);
    final keys = _inflight.keys.where((key) => key.$1 == track).toList();
    for (final key in keys) {
      _inflight.remove(key)?.token.cancel();
    }
  }

  int _prefetchedBytes(TrackKind track) {
    var bytes = 0;
    for (final MapEntry(:key, :value) in _cache.entries) {
      if (key.$1 == track && !value.served) bytes += value.bytes.length;
    }
    for (final key in _inflight.keys) {
      if (key.$1 == track) bytes += key.$2.length;
    }
    return bytes;
  }

  /// How far ahead of the playhead prefetch reaches, in seconds of the video.
  double _lookAhead() {
    final config = _ctx.config;
    if (!config.prefetchFollowsRate) return config.prefetchAheadSeconds;
    return config.prefetchAheadSeconds * _rate.clamp(1.0, RipperConfig.maxPrefetchRate);
  }

  /// The fixed cap, or with a max cap set, enough for [ahead] seconds at the track's own bitrate.
  int _prefetchCap(TrackKind track, double ahead) {
    final config = _ctx.config;
    final video = track == TrackKind.video;
    final fixed = video ? config.prefetchVideoBytes : config.prefetchAudioBytes;
    final ceiling = video ? config.prefetchVideoMaxBytes : config.prefetchAudioMaxBytes;
    final rate = _byteRate[track];
    if (ceiling == null || rate == null) return fixed;
    // A quarter more than the average, since the segments right ahead can run above it.
    return (rate * ahead * 1.25).round().clamp(fixed, max(fixed, ceiling));
  }

  void _schedulePrefetch(TrackKind track, MediaSegment? segment) {
    final resolver = _resolvers[track];
    if (segment == null || resolver == null || _closed) return;
    if (_bursting > 0) {
      _deferred[track] = segment;
      return;
    }
    final segments = _segments[track];
    final position = _segmentAt[track]?[segment.range.start];
    if (segments == null || position == null) return;
    final ahead = _lookAhead();
    final total = _headers[track]?.totalSize;
    var budget = _prefetchCap(track, ahead) - _prefetchedBytes(track);
    for (final next in segments.skip(position + 1)) {
      if (next.startTime - _playhead > ahead) break;
      final key = (track, next.range);
      if (_cache.containsKey(key) || _inflight.containsKey(key) || _playerPending.containsKey(key)) continue;
      if (next.range.length > budget) break;
      budget -= next.range.length;
      final prefetch = _Prefetch(CancelToken(_root), startedAt: _ctx.clock.nowMs());
      prefetch.bytes = _fetchSegment(track, next, resolver, total, prefetch);
      _inflight[key] = prefetch;
      _watch(key, prefetch, next.endTime);
    }
  }

  Future<Uint8List> _fetchSegment(
    TrackKind track,
    MediaSegment segment,
    Resolver resolver,
    int? total,
    _Prefetch prefetch,
  ) async {
    final cancel = prefetch.token;
    final urgent = prefetch.kind != _FetchKind.prefetch;
    final hold = urgent ? _holdPrefetch(segment.range) : null;
    try {
      await _download(
        track,
        segment.range,
        resolver,
        startup: urgent,
        player: urgent,
        segment: segment,
        total: total,
        emit: (bytes) {
          prefetch.add(bytes, at: _ctx.clock.nowMs());
          hold?.landed(prefetch.received);
        },
        cancel: cancel,
      );
      cancel.throwIfCancelled();
      if (urgent) _logFetch(track, segment, prefetch, 'done');
      return prefetch.takeBytes();
    } catch (error) {
      if (urgent) _logFetch(track, segment, prefetch, cancel.isCancelled ? 'cancelled' : 'failed');
      rethrow;
    } finally {
      hold?.end();
      cancel.dispose();
    }
  }

  /// How a prime or a hint went, for timing startup and seeks from the phone's log.
  void _logFetch(TrackKind track, MediaSegment segment, _Prefetch prefetch, String outcome) {
    final now = _ctx.clock.nowMs();
    final first = prefetch.firstByteAt;
    _ctx.logger.info(LogCategory.engine, prefetch.kind.name, {
      'track': track.name,
      'segment': segment.index,
      'outcome': outcome,
      'adopted': prefetch.adopted,
      'firstByteMs': first == null ? -1 : (first - prefetch.startedAt).roundToDouble(),
      'ms': (now - prefetch.startedAt).roundToDouble(),
      'bytes': prefetch.received,
    });
  }

  void _watch(_Key key, _Prefetch prefetch, double endTime) {
    unawaited(
      prefetch.bytes.then(
        (bytes) => _prefetchFinished(key, prefetch, endTime, bytes: bytes),
        onError: (Object error) => _prefetchFinished(key, prefetch, endTime, error: error),
      ),
    );
  }

  void _prefetchFinished(_Key key, _Prefetch prefetch, double endTime, {Uint8List? bytes, Object? error}) {
    if (identical(_inflight[key], prefetch)) {
      _inflight.remove(key);
      if (bytes != null && !_closed) {
        _cache[key] = _CacheEntry(bytes, endTime, startTime: _segmentFor(key)?.startTime ?? endTime);
      }
    }
    if (error != null && error is! CancelledException) {
      _ctx.logger.warn(LogCategory.engine, 'prefetch failed', {
        'track': key.$1.name,
        'range': '${key.$2}',
        'error': '$error',
      });
    }
  }

  /// Waits for a prefetch the read took over. Under [RipperConfig.streamAdopted] its bytes so far and those that
  /// follow go to [out] as they come; the caller sends whatever the result holds beyond them.
  Future<Uint8List?> _takeOver(_Prefetch prefetch, void Function(Uint8List bytes) out, CancelToken token) async {
    prefetch.adopted = true;
    if (!_ctx.config.streamAdopted) return _waitForPrefetch(prefetch, token);
    for (final chunk in prefetch.chunks) {
      out(chunk);
    }
    final stop = prefetch.listen(out);
    try {
      return await _waitForPrefetch(prefetch, token);
    } finally {
      stop();
    }
  }

  /// Null when the prefetch failed, and as soon as the reader is cancelled: waiting for the prefetch alone would
  /// keep the reader parked until it ends, and the prefetch is not the reader's to cancel.
  static Future<Uint8List?> _waitForPrefetch(_Prefetch prefetch, CancelToken token) async {
    try {
      return await token.guard(prefetch.bytes);
    } catch (_) {
      return null;
    }
  }

  /// A reader that gives up on an adopted prefetch hands it back to `_inflight`, so it still ends in the cache.
  /// With the session closed, a seek since the reader took it, or the segment scheduled again meanwhile,
  /// nobody wants it.
  void _returnPrefetch(_Prefetch prefetch, _Key key, {required double endTime, required int generation}) {
    if (_closed || (_seekGeneration[key.$1] ?? 0) != generation || _inflight.containsKey(key)) {
      prefetch.token.cancel();
      return;
    }
    _inflight[key] = prefetch;
    // The prefetch may have finished while it was out of `_inflight`, after the first watcher gave up on it.
    _watch(key, prefetch, endTime);
  }

  /// A segment the player read stays cached as back buffer ([RipperConfig.keepBehindBytes]).
  void _keep(_Key key, Uint8List bytes, MediaSegment segment) {
    _cache[key] = _CacheEntry(bytes, segment.endTime, startTime: segment.startTime, served: true);
    _trimKept();
  }

  /// Each track keeps at most [RipperConfig.keepBehindBytes] of segments the player read, dropping those furthest
  /// from the playhead first.
  void _trimKept() {
    final limit = _ctx.config.keepBehindBytes;
    for (final track in TrackKind.values) {
      final kept = [
        for (final MapEntry(:key, :value) in _cache.entries)
          if (key.$1 == track && value.served) (key: key, entry: value),
      ];
      var bytes = kept.fold(0, (sum, item) => sum + item.entry.bytes.length);
      if (bytes <= limit) continue;
      double distance(_CacheEntry entry) =>
          entry.endTime < _playhead ? _playhead - entry.endTime : max(0.0, entry.startTime - _playhead);
      kept.sort((a, b) => distance(b.entry).compareTo(distance(a.entry)));
      for (final item in kept) {
        if (bytes <= limit) break;
        _cache.remove(item.key);
        bytes -= item.entry.bytes.length;
      }
    }
  }

  // For tests.
  bool isCached(TrackKind track, ByteRange range) => _cache.containsKey((track, range));
  NodeStats get nodeStats => _ctx.nodes;
  int get seekCount => _seeks;
  int get mediaRequestCount => _requests;
  int prefetchedBytes(TrackKind track) => _prefetchedBytes(track);
  int cachedBytes(TrackKind track) =>
      _cache.entries.where((entry) => entry.key.$1 == track).fold(0, (sum, entry) => sum + entry.value.bytes.length);
  bool hurries(TrackKind track, ByteRange range) {
    final position = _segmentAt[track]?[range.start];
    return _hurry(position == null ? null : _segments[track]?[position], startup: false)();
  }

  int seekGeneration(TrackKind track) => _seekGeneration[track] ?? 0;
  int prefetchesRunning(TrackKind track) => _inflight.keys.where((key) => key.$1 == track).length;
  int get readsRunning => _reads;
  int prefetchCap(TrackKind track) => _prefetchCap(track, _lookAhead());
  double get lookAhead => _lookAhead();
  bool hinting(TrackKind track, ByteRange range) => _inflight[(track, range)]?.kind == _FetchKind.hint;
  bool priming(TrackKind track, ByteRange range) => _inflight[(track, range)]?.kind == _FetchKind.prime;
  EngineContext get context => _ctx;
}
