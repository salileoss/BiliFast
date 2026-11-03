import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart';
import 'package:bili_core/shared.dart';
import 'package:bili_core/src/engine/attempt.dart';
import 'package:bili_core/src/engine/ban_list.dart';
import 'package:bili_core/src/engine/connection_pool.dart';
import 'package:bili_core/src/engine/piece_downloader.dart';
import 'package:bili_core/src/engine/resolver.dart';
import 'package:test/test.dart';

import 'support/sim_cdn.dart';

/// Wraps a SimCDN: holds every request until opened; from given offsets on it refuses with 403, holds requests,
/// or advertises a wrong file size. Records every requested range.
final class ScriptedTransport implements RangeTransport {
  ScriptedTransport(this.cdn, {this.open = true, this.refuseFrom});

  final SimCDN cdn;
  bool open;
  int? refuseFrom;
  int? holdFrom;
  int? lieFrom;
  final ranges = <ByteRange>[];

  @override
  int? get connectionsPerHost => cdn.connectionsPerHost;

  @override
  String get name => 'scripted';

  @override
  void close() {}

  @override
  Future<TransportResponse> fetch(Uri url, ByteRange range, {CancelToken? cancel}) async {
    ranges.add(range);
    while (!open) {
      await cancellableSleep(5, cancel);
    }
    if (refuseFrom case final from? when range.start >= from) {
      await cancellableSleep(2, cancel);
      return TransportResponse(status: 403, headers: const {}, body: const Stream.empty());
    }
    while (holdFrom != null && range.start >= holdFrom!) {
      await cancellableSleep(5, cancel);
    }
    final response = await cdn.fetch(url, range, cancel: cancel);
    final from = lieFrom;
    if (from == null || range.start < from) return response;
    return TransportResponse(
      status: response.status,
      headers: {...response.headers, 'content-range': 'bytes ${range.start}-${range.end}/${cdn.content.length + 1}'},
      body: response.body,
    );
  }

  /// Bytes of [segment] asked for, over all requests.
  int requestedBytes(ByteRange segment) {
    var sum = 0;
    for (final range in ranges) {
      final overlap = min(range.end, segment.end) - max<int>(range.start, segment.start) + 1;
      if (overlap > 0) sum += overlap;
    }
    return sum;
  }
}

const size = 4 * 1024 * 1024;
const headerEnd = 1023;
const segmentLength = 262144;

List<MediaSegment> segments() => [
      for (var index = 0; index < 12; index++)
        MediaSegment(
          index: index,
          range: ByteRange(headerEnd + 1 + index * segmentLength, headerEnd + (index + 1) * segmentLength),
          startTime: index * 2.0,
          duration: 2,
        ),
    ];

RipperSession makeSession(
  RangeTransport transport, {
  RipperConfig config = TestEngine.config,
  List<TrackKind> tracks = const [TrackKind.video],
  AutoConcurrency? auto,
  NodeMode mode = NodeMode.overseas,
}) =>
    RipperSession(
      sources: {for (final track in tracks) track: (primary: TestEngine.primary, backups: const [])},
      mode: mode,
      config: config,
      transport: transport,
      auto: auto,
      logger: Logger(session: 'test'),
    );

/// One retry round, so a refused range fails at once.
final quickConfig = TestEngine.config.copyWith(pieceRounds: 1);

Future<Uint8List> read(RipperSession session, ByteRange range, [TrackKind track = TrackKind.video]) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in session.read(track, range)) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Future<Object?> readError(RipperSession session, ByteRange range, [TrackKind track = TrackKind.video]) async {
  try {
    await read(session, range, track);
    return null;
  } catch (error) {
    return error;
  }
}

Future<void> waitUntil(bool Function() condition, {double seconds = 10}) async {
  expect(await eventually(condition, seconds: seconds), isTrue, reason: 'timed out waiting');
}

Future<void> sleepMs(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Uint8List bytesOf(SimCDN cdn, ByteRange range) => Uint8List.sublistView(cdn.content, range.start, range.end + 1);

const slowNode = 'upos-sz-mirrorcos.bilivideo.com';

/// One slow node (a segment takes about a second) and room for one prefetch, so after segment 0 is read segment 1
/// is being prefetched when the player asks for it. Segment 0 is the session's first request.
Future<(RipperSession, ScriptedTransport, List<MediaSegment>)> makeSlowPrefetchSession() async {
  final all = segments();
  final transport = ScriptedTransport(
      SimCDN(size: size, behaviors: {slowNode: NodeBehavior(bytesPerSecond: segmentLength.toDouble())}));
  final config = TestEngine.slowConfig.copyWith(minChunkBytes: segmentLength, prefetchVideoBytes: segmentLength);
  final session = makeSession(transport, config: config, mode: CustomNodes([NodeAddress(slowNode)]));
  session.setSegments(TrackKind.video, all);
  await read(session, all[0].range);
  expect(session.prefetchesRunning(TrackKind.video), 1, reason: 'segment 1 is being prefetched');
  return (session, transport, all);
}

/// A read of [segment] takes over its prefetch, runs for a moment and is cancelled.
Future<void> adoptAndAbandon(RipperSession session, MediaSegment segment) async {
  final reader = session.read(TrackKind.video, segment.range).listen((_) {}, onError: (Object _) {});
  await waitUntil(() => session.mediaRequestCount == 2);
  expect(session.prefetchesRunning(TrackKind.video), 0, reason: 'the read took the prefetch over');
  await sleepMs(100);
  await reader.cancel();
  await waitUntil(() => session.readsRunning == 0);
}

int deliveredBytes(ScriptedTransport transport) => transport.cdn.deliveredBytes.values.fold(0, (sum, bytes) => sum + bytes);

void main() {
  // Port of RipperSessionTests.swift.

  test('headers, segments and prefetch', () async {
    final cdn = SimCDN(size: size);
    final session = makeSession(cdn);
    final headers = await session.loadHeaders(TrackKind.video, through: headerEnd);
    expect(headers.bytes, bytesOf(cdn, ByteRange(0, 1023)));
    expect(headers.totalSize, size);
    session.setSegments(TrackKind.video, segments());
    final first = segments()[0].range;
    expect(await read(session, first), bytesOf(cdn, first));
    await sleepMs(500);
    final second = segments()[1].range;
    expect(await read(session, second), bytesOf(cdn, second));
    expect(session.stats().cacheHits, greaterThanOrEqualTo(1));
    session.close();
  });

  test('header bytes are served from memory', () async {
    final cdn = SimCDN(size: size);
    final session = makeSession(cdn);
    await session.loadHeaders(TrackKind.video, through: headerEnd);
    final before = cdn.requestCount;
    expect(await read(session, ByteRange(0, 99)), bytesOf(cdn, ByteRange(0, 99)));
    expect(cdn.requestCount, before);
    session.close();
  });

  test('seek and unaligned ranges', () async {
    final cdn = SimCDN(size: size);
    final session = makeSession(cdn);
    session.setSegments(TrackKind.video, segments());
    final late = segments()[9].range;
    expect(await read(session, late), bytesOf(cdn, late));
    final odd = ByteRange(5000, 70000);
    expect(await read(session, odd), bytesOf(cdn, odd));
    session.close();
  });

  test('fatal when every node refuses', () async {
    final session = makeSession(
        SimCDN(size: size, behaviors: {for (final node in NodeCatalog.overseas) node: const NodeBehavior(status: 403)}));
    var fatal = false;
    session.onFatal = (_) => fatal = true;
    expect(await readError(session, ByteRange(2000, 50000)), isNotNull, reason: 'expected a failure');
    expect(fatal, isTrue);
    session.close();
  });

  test('reads are checked against the total from the headers', () async {
    final cdn = SimCDN(size: size);
    final session = makeSession(cdn);
    await session.loadHeaders(TrackKind.video, through: headerEnd);
    session.setSegments(TrackKind.video, segments());
    for (final node in NodeCatalog.overseas) {
      cdn.set(node, const NodeBehavior(totalSize: size + 1));
    }
    expect(await readError(session, segments()[0].range), const RipperError(RipperErrorKind.totalMismatch),
        reason: 'nodes agreeing with each other on a wrong size are still wrong');
    session.close();
  });

  test('a prefetch with a wrong total is not cached', () async {
    final all = segments();
    final transport = ScriptedTransport(SimCDN(size: size));
    final session = makeSession(transport);
    await session.loadHeaders(TrackKind.video, through: headerEnd);
    session.setSegments(TrackKind.video, all);
    var fatal = 0;
    session.onFatal = (_) => fatal += 1;
    transport.lieFrom = all[1].range.start;
    await read(session, all[0].range);
    await waitUntil(() => session.prefetchesRunning(TrackKind.video) == 0);
    expect(session.cachedBytes(TrackKind.video), 0);
    expect(fatal, 0);
    session.close();
  });

  test('a closed session refuses reads', () async {
    final session = makeSession(SimCDN(size: size))..close();
    expect(await readError(session, ByteRange(2000, 3000)), const RipperError(RipperErrorKind.closed));
  });

  test('replaced URLs keep working', () async {
    final cdn = SimCDN(size: size);
    final session = makeSession(cdn);
    session.replaceUrls(TrackKind.video,
        primary: TestEngine.primary.replaceAll('deadline=9', 'deadline=99'), backups: const []);
    final range = ByteRange(2000, 80000);
    expect(await read(session, range), bytesOf(cdn, range));
    session.close();
  });

  test('prefetch stays under each track\'s cap', () async {
    final config =
        TestEngine.config.copyWith(prefetchVideoBytes: 3 * segmentLength, prefetchAudioBytes: segmentLength);
    final session = makeSession(SimCDN(size: size), config: config, tracks: const [TrackKind.video, TrackKind.audio]);
    session
      ..setSegments(TrackKind.video, segments())
      ..setSegments(TrackKind.audio, segments());
    bool settled() {
      expect(session.prefetchedBytes(TrackKind.video), lessThanOrEqualTo(config.prefetchVideoBytes));
      expect(session.prefetchedBytes(TrackKind.audio), lessThanOrEqualTo(config.prefetchAudioBytes));
      return session.prefetchesRunning(TrackKind.video) == 0 && session.prefetchesRunning(TrackKind.audio) == 0;
    }

    await read(session, segments()[0].range, TrackKind.video);
    await read(session, segments()[0].range, TrackKind.audio);
    await waitUntil(settled);
    expect(session.cachedBytes(TrackKind.video), 3 * segmentLength);
    expect(session.cachedBytes(TrackKind.audio), segmentLength);

    final hitsBefore = session.stats().cacheHits;
    await read(session, segments()[1].range, TrackKind.video);
    expect(session.stats().cacheHits, hitsBefore + 1);
    await waitUntil(settled);
    expect(session.cachedBytes(TrackKind.video), 3 * segmentLength);

    session.dropCache();
    expect(session.prefetchedBytes(TrackKind.video), 0);
    expect(session.prefetchedBytes(TrackKind.audio), 0);

    await read(session, segments()[6].range, TrackKind.video);
    await waitUntil(settled);
    expect(session.cachedBytes(TrackKind.video), 3 * segmentLength);
    session.close();
    expect(session.prefetchedBytes(TrackKind.video), 0);
    expect(session.prefetchedBytes(TrackKind.audio), 0);
  });

  // BiliFast: VideoPageModel.swift's cover() called the session's dropCache(); here that is dropPrefetch(), since
  // dropCache() trims for a memory warning.
  group('dropPrefetch (a covered page)', () {
    test('drops every cached segment, the back buffer too, where a memory warning keeps what is near', () async {
      final config = TestEngine.config.copyWith(
        prefetchVideoBytes: 3 * segmentLength,
        keepBehindSeconds: 30,
        keepBehindBytes: 8 << 20,
        trimOnMemoryWarning: true,
      );
      final cdn = SimCDN(size: size);
      final session = makeSession(cdn, config: config);
      addTearDown(session.close);
      session.setSegments(TrackKind.video, segments());
      await read(session, segments()[0].range);
      session.updatePlayhead(seconds: 2, rate: 1);
      await read(session, segments()[1].range);
      await waitUntil(() => session.prefetchesRunning(TrackKind.video) == 0);
      expect(session.isCached(TrackKind.video, segments()[1].range), isTrue, reason: 'kept as back buffer');
      expect(session.prefetchedBytes(TrackKind.video), greaterThan(0));

      session.dropPrefetch();
      expect(session.cachedBytes(TrackKind.video), 0);
      expect(session.prefetchedBytes(TrackKind.video), 0);

      final requests = session.mediaRequestCount;
      expect(await read(session, segments()[2].range), bytesOf(cdn, segments()[2].range), reason: 'reads go on');
      expect(session.mediaRequestCount, greaterThan(requests), reason: 'segment 2 came from the CDN again');
    });

    test('cancels a prefetch still downloading; the segment is fetched again when read', () async {
      final (session, transport, all) = await makeSlowPrefetchSession();
      addTearDown(session.close);
      session.dropPrefetch();
      expect(session.prefetchesRunning(TrackKind.video), 0);
      expect(await read(session, all[1].range), bytesOf(transport.cdn, all[1].range));
    });

    test('a prefetch a reader took over and then left is not handed back', () async {
      final (session, transport, all) = await makeSlowPrefetchSession();
      addTearDown(session.close);
      final reader = session.read(TrackKind.video, all[1].range).listen((_) {}, onError: (Object _) {});
      await waitUntil(() => session.mediaRequestCount == 2);
      expect(session.prefetchesRunning(TrackKind.video), 0, reason: 'the read took the prefetch over');
      session.dropPrefetch();
      await reader.cancel();
      await waitUntil(() => session.readsRunning == 0);
      expect(session.prefetchesRunning(TrackKind.video), 0);
      await sleepMs(1200);
      expect(session.cachedBytes(TrackKind.video), 0, reason: 'segment 1 was cancelled, not cached');
      expect(deliveredBytes(transport), lessThan(2 * segmentLength));
    });
  });

  test('a seek replaces the track\'s prefetched segments', () async {
    final config = TestEngine.config.copyWith(prefetchVideoBytes: 3 * segmentLength);
    final session = makeSession(SimCDN(size: size), config: config);
    session.setSegments(TrackKind.video, segments());
    await read(session, segments()[6].range);
    await waitUntil(() => session.prefetchesRunning(TrackKind.video) == 0);
    expect(session.cachedBytes(TrackKind.video), 3 * segmentLength);
    await read(session, segments()[0].range);
    await waitUntil(() => session.prefetchesRunning(TrackKind.video) == 0);
    expect(session.cachedBytes(TrackKind.video), 3 * segmentLength);
    final hitsBefore = session.stats().cacheHits;
    await read(session, segments()[1].range);
    expect(session.stats().cacheHits, hitsBefore + 1, reason: 'the new position is prefetched, not the one left behind');
    session.close();
  });

  test('prefetch stops at the look-ahead limit', () async {
    final config = TestEngine.config.copyWith(prefetchAheadSeconds: 5);
    final session = makeSession(SimCDN(size: size), config: config);
    session.setSegments(TrackKind.video, segments());
    await read(session, segments()[0].range);
    await waitUntil(() => session.prefetchesRunning(TrackKind.video) == 0);
    // Segments start every 2 s: those at 2 s and 4 s are within 5 s of the playhead at 0.
    expect(session.cachedBytes(TrackKind.video), 2 * segmentLength);
    session.updatePlayhead(seconds: 9, rate: 1);
    expect(session.cachedBytes(TrackKind.video), 0, reason: 'segments that ended over 2 s behind the playhead are dropped');
    session.close();
  });

  test('pipelined and reordered requests are not seeks', () async {
    final config = TestEngine.config.copyWith(prefetchVideoBytes: 0);
    final transport = ScriptedTransport(SimCDN(size: size));
    final session = makeSession(transport, config: config);
    session.setSegments(TrackKind.video, segments());
    final all = segments();
    await read(session, all[0].range);
    expect(session.seekCount, 1, reason: 'the first request of a track starts up like a seek');

    Future<void> overlapping(int first, int second) async {
      transport.open = false;
      final before = session.mediaRequestCount;
      final a = read(session, all[first].range);
      await waitUntil(() => session.mediaRequestCount == before + 1);
      final b = read(session, all[second].range);
      await waitUntil(() => session.mediaRequestCount == before + 2);
      transport.open = true;
      expect((await a).length, segmentLength);
      expect((await b).length, segmentLength);
    }

    await overlapping(1, 2);
    expect(session.seekCount, 1, reason: 'segment 2 asked for while 1 is still loading');
    await overlapping(4, 3);
    expect(session.seekCount, 1, reason: 'two neighbouring requests arriving out of order');

    await read(session, all[9].range);
    expect(session.seekCount, 2);
    await read(session, all[0].range);
    expect(session.seekCount, 3);
    await read(session, ByteRange(5000, 70000));
    expect(session.seekCount, 3, reason: 'inside the previous request');

    // Unaligned neighbours arriving out of order: 100 000-139 999 before 70 001-99 999.
    transport.open = false;
    final before = session.mediaRequestCount;
    final later = read(session, ByteRange(100000, 139999));
    await waitUntil(() => session.mediaRequestCount == before + 1);
    final earlier = read(session, ByteRange(70001, 99999));
    await waitUntil(() => session.mediaRequestCount == before + 2);
    transport.open = true;
    await Future.wait([later, earlier]);
    expect(session.seekCount, 3, reason: 'unaligned neighbours out of order');
    await read(session, ByteRange(20000, 49999));
    expect(session.seekCount, 4, reason: 'more than its own length before the previous request');
    session.close();
  });

  test('segments the player is loading are not prefetched again', () async {
    final config = TestEngine.config.copyWith(firstByteTimeoutMs: 3000);
    final all = segments();
    final transport = ScriptedTransport(SimCDN(size: size), open: false)..holdFrom = all[2].range.start;
    // One node means no backup copies, so every byte is asked for exactly once.
    final session = makeSession(transport, config: config, mode: CustomNodes([NodeAddress(slowNode)]));
    session.setSegments(TrackKind.video, all);
    final first = read(session, all[1].range);
    await waitUntil(() => session.mediaRequestCount == 1);
    final second = read(session, all[2].range);
    await waitUntil(() => session.mediaRequestCount == 2);
    transport.open = true;
    await first;
    // Segment 1 is in and its prefetch is scheduled while the player still waits for segment 2.
    expect(session.prefetchesRunning(TrackKind.video), greaterThan(0));
    transport.holdFrom = null;
    await second;
    await waitUntil(() => session.prefetchesRunning(TrackKind.video) == 0);
    expect(session.isCached(TrackKind.video, all[2].range), isFalse);
    expect(session.isCached(TrackKind.video, all[3].range), isTrue);
    expect(transport.requestedBytes(all[2].range), segmentLength);
    session.close();
  });

  test('a cancelled reader leaves the adopted prefetch running', () async {
    final (session, transport, all) = await makeSlowPrefetchSession();
    final reader = session.read(TrackKind.video, all[1].range).listen((_) {}, onError: (Object _) {});
    await waitUntil(() => session.mediaRequestCount == 2);
    await sleepMs(100);
    await reader.cancel();
    await sleepMs(300);
    expect(session.readsRunning, 0, reason: 'a cancelled read ends at once; it does not wait for the prefetch');
    expect(session.prefetchesRunning(TrackKind.video), 1, reason: 'the prefetch is back, still downloading');
    await waitUntil(() => session.isCached(TrackKind.video, all[1].range), seconds: 5);

    final hitsBefore = session.stats().cacheHits;
    expect(await read(session, all[1].range), bytesOf(transport.cdn, all[1].range));
    expect(session.stats().cacheHits, hitsBefore + 1);
    expect(transport.requestedBytes(all[1].range), segmentLength, reason: 'segment 1 was downloaded once');
    session.close();
  });

  test('close and seek still cancel a prefetch a reader left', () async {
    {
      final (session, transport, all) = await makeSlowPrefetchSession();
      await adoptAndAbandon(session, all[1]);
      expect(session.prefetchesRunning(TrackKind.video), 1);
      session.close();
      expect(session.prefetchesRunning(TrackKind.video), 0);
      await sleepMs(1200);
      expect(deliveredBytes(transport), segmentLength, reason: 'close cancelled segment 1\'s download');
    }
    {
      final (session, transport, all) = await makeSlowPrefetchSession();
      await adoptAndAbandon(session, all[1]);
      expect(session.prefetchesRunning(TrackKind.video), 1);
      await read(session, all[9].range);
      session.close();
      await sleepMs(1200);
      expect(deliveredBytes(transport), 2 * segmentLength,
          reason: 'the seek cancelled segment 1\'s download; segments 0 and 9 arrived');
    }
  });

  // AVPlayer's seek request and the close of its old one are two connections, so either can arrive first.
  test('a seek read arriving before the old reader\'s cancel still cancels the prefetch', () async {
    final (session, transport, all) = await makeSlowPrefetchSession();
    final reader = session.read(TrackKind.video, all[1].range).listen((_) {}, onError: (Object _) {});
    await waitUntil(() => session.mediaRequestCount == 2);
    expect(session.prefetchesRunning(TrackKind.video), 0, reason: 'the read took the prefetch over');
    await sleepMs(100);
    final generation = session.seekGeneration(TrackKind.video);
    final seekRead = read(session, all[9].range);
    await waitUntil(() => session.seekGeneration(TrackKind.video) > generation);
    await reader.cancel();
    await waitUntil(() => session.readsRunning == 1);
    expect(session.prefetchesRunning(TrackKind.video), 0,
        reason: 'the prefetch the old reader gave back after the seek is cancelled');
    await seekRead;
    expect(deliveredBytes(transport), 2 * segmentLength,
        reason: 'segments 0 and 9 arrived; segment 1\'s download was cancelled');
    session.close();
  });

  test('close cancels a prefetch its reader was still waiting on', () async {
    final (session, transport, all) = await makeSlowPrefetchSession();
    final reader = readError(session, all[1].range);
    await waitUntil(() => session.mediaRequestCount == 2);
    session.close();
    await reader;
    await sleepMs(1200);
    expect(deliveredBytes(transport), segmentLength);
  });

  test('prefetch failures are only logged, and a player failure signals once', () async {
    final all = segments();
    final transport = ScriptedTransport(SimCDN(size: size), refuseFrom: all[1].range.start);
    final session = makeSession(transport, config: quickConfig);
    session.setSegments(TrackKind.video, all);
    var fatal = 0;
    session.onFatal = (_) => fatal += 1;
    await read(session, all[0].range);
    await waitUntil(() => session.prefetchesRunning(TrackKind.video) == 0);
    expect(fatal, 0);
    expect(session.cachedBytes(TrackKind.video), 0);
    final error = await readError(session, all[1].range);
    expect(error, isNotNull, reason: 'expected a failure');
    expect(error, isNot(const RipperError(RipperErrorKind.closed)));
    expect(fatal, 1);
    session.close();
  });

  test('requests failing together signal once', () async {
    final transport = ScriptedTransport(SimCDN(size: size), open: false, refuseFrom: 0);
    final session = makeSession(transport, config: quickConfig, tracks: const [TrackKind.video, TrackKind.audio]);
    session
      ..setSegments(TrackKind.video, segments())
      ..setSegments(TrackKind.audio, segments());
    var fatal = 0;
    session.onFatal = (_) => fatal += 1;
    final video = readError(session, segments()[0].range, TrackKind.video);
    final audio = readError(session, segments()[0].range, TrackKind.audio);
    await waitUntil(() => session.mediaRequestCount == 2);
    transport.open = true;
    final errors = await Future.wait([video, audio]);
    expect(errors[0], isNotNull);
    expect(errors[1], isNotNull);
    expect(fatal, 1);
    // A request made after the signal (say, after the URLs were refreshed) can signal again.
    expect(await readError(session, segments()[1].range, TrackKind.video), isNotNull);
    expect(fatal, 2);
    session.close();
  });

  test('close ends running reads without signalling', () async {
    final transport = ScriptedTransport(SimCDN(size: size), open: false);
    final session = makeSession(transport);
    session.setSegments(TrackKind.video, segments());
    var fatal = false;
    session.onFatal = (_) => fatal = true;
    final pending = readError(session, segments()[0].range);
    await waitUntil(() => session.mediaRequestCount == 1);
    session.close();
    expect(await pending, const RipperError(RipperErrorKind.closed));
    expect(fatal, isFalse);
    await expectLater(
        session.loadHeaders(TrackKind.video, through: headerEnd), throwsA(const RipperError(RipperErrorKind.closed)));
  });

  test('the AutoConcurrency handler follows the open session only', () {
    final config = automaticConfig();

    final alone = AutoConcurrency();
    final closed = makeSession(SimCDN(size: 1024), config: config, auto: alone);
    final limit = closed.stats().concurrency;
    closed.close();
    alone.pushback(status: 429);
    expect(alone.threads, isNot(limit));
    expect(closed.stats().concurrency, limit, reason: 'a closed session ignores the shared connection count');

    final shared = AutoConcurrency();
    final old = makeSession(SimCDN(size: 1024), config: config, auto: shared);
    final newer = makeSession(SimCDN(size: 1024), config: config, auto: shared);
    expect(newer.stats().concurrency, shared.threads);
    old.close();
    shared.pushback(status: 429);
    expect(newer.stats().concurrency, shared.threads, reason: 'closing the old session must not unhook the new one');
    newer.close();
  });

  test('segments near the playhead are in a hurry', () {
    final segments = [
      for (var index = 0; index < 5; index++)
        MediaSegment(
          index: index,
          range: ByteRange(headerEnd + 1 + index * segmentLength, headerEnd + (index + 1) * segmentLength),
          startTime: index * 4.0,
          duration: 4,
        ),
    ];
    for (final hurry in [true, false]) {
      final session = makeSession(SimCDN(size: size), config: TestEngine.config.copyWith(hurry: hurry));
      session.setSegments(TrackKind.video, segments);
      session.updatePlayhead(seconds: 0, rate: 1);
      expect(session.hurries(TrackKind.video, segments[0].range), hurry);
      expect(session.hurries(TrackKind.video, segments[2].range), hurry);
      expect(session.hurries(TrackKind.video, segments[3].range), isFalse);
      // At double speed 10 s of playback cover 20 s of the video.
      session.updatePlayhead(seconds: 0, rate: 2);
      expect(session.hurries(TrackKind.video, segments[4].range), hurry);
      // A range that is no segment hurries only as a startup or seek read.
      expect(session.hurries(TrackKind.video, ByteRange(headerEnd + 5, headerEnd + 1000)), isFalse);
      session.close();
    }
  });

  test('concurrency comfort uses wall seconds at the playback rate', () {
    for (final rate in [1.0, 2.0, 0.0, double.nan, double.infinity]) {
      final manual = ManualClock(100000);
      final auto = AutoConcurrency(clock: manual.clock);
      final session = RipperSession(
        sources: {TrackKind.video: (primary: TestEngine.primary, backups: const <String>[])},
        mode: NodeMode.auto,
        transport: SimCDN(size: 1024),
        config: automaticConfig(),
        auto: auto,
        clock: manual.clock,
        logger: Logger(session: 'test'),
      );
      session.updatePlayhead(seconds: 0, rate: rate);
      manual.advance(3000);
      session.reportBuffer(aheadSeconds: 20, playing: true);
      expect(auto.threads, rate == 2 ? 16 : 12, reason: 'rate=$rate');
      session.close();
    }
  });

  // Not in RipperSessionTests.swift.

  test('without a fixed count the pool starts at the shared count, and a fixed count ignores it', () {
    final auto = AutoConcurrency();
    final following = makeSession(SimCDN(size: 1024), config: automaticConfig(), auto: auto);
    expect(following.stats().concurrency, auto.threads);
    final fixed = makeSession(SimCDN(size: 1024), config: TestEngine.config.copyWith(fixedConcurrency: 5), auto: auto);
    expect(fixed.stats().concurrency, 5);
    following.close();
    fixed.close();
  });

  group('reads (slice 1)', () {
    // Pieces and nodes in a read, which RipperSessionTests.swift leaves to the downloader's tests.
    test('reads come back byte-exact and in order across many pieces and nodes', () async {
      // Different speeds finish the pieces out of order.
      final cdn = SimCDN(size: 8 * _bigSegmentBytes, behaviors: {
        TestEngine.cosov: const NodeBehavior(bytesPerSecond: 20e6),
        TestEngine.aliov: const NodeBehavior(bytesPerSecond: 40e6, firstByteMs: 6),
        TestEngine.hk1: const NodeBehavior(bytesPerSecond: 80e6, firstByteMs: 1),
      });
      final session =
          _bigSession(cdn, config: const RipperConfig(fixedConcurrency: 16, hedgeDelayMs: 100), segments: 8);
      addTearDown(session.close);
      for (var index = 0; index < 8; index++) {
        expect(await read(session, _bigSegment(index)), bytesOf(cdn, _bigSegment(index)), reason: 'segment $index');
      }
      expect(cdn.urls.length, greaterThan(40));
      expect(cdn.requests.toSet(), hasLength(4));
      expect(session.seekCount, 1);
      final stats = session.stats();
      expect(stats.deliveredBytes, 8 * _bigSegmentBytes);
      expect(stats.nodeStates.map((status) => status.node), NodeCatalog.overseas);
    });

    test('an unaligned range spanning segments is delivered whole', () async {
      final cdn = SimCDN(size: 4 * _bigSegmentBytes);
      final session = _bigSession(cdn, segments: 4);
      addTearDown(session.close);
      final range = ByteRange(12345, 3 * _bigSegmentBytes + 999);
      expect(await read(session, range), bytesOf(cdn, range));
    });

    test('cancelling the subscription cancels every piece at once', () async {
      final cdn = SimCDN(size: 4 * _bigSegmentBytes);
      // Without prefetch: the read must own its pieces, not adopt a prefetch that outlives it.
      final session = _bigSession(cdn,
          config: const RipperConfig(fixedConcurrency: 8, stallTimeoutMs: 2000, prefetchVideoBytes: 0), segments: 4);
      addTearDown(session.close);
      await read(session, _bigSegment(0));
      for (final node in NodeCatalog.overseas) {
        cdn.set(node, const NodeBehavior(bytesPerSecond: 50e3));
      }
      final subscription = session.read(TrackKind.video, _bigSegment(1)).listen((_) {});
      expect(await eventually(() => cdn.inflight >= 4), isTrue);
      final requests = cdn.urls.length;
      final clock = Stopwatch()..start();
      await subscription.cancel();
      expect(await eventually(() => cdn.inflight == 0, seconds: 0.5), isTrue);
      expect(clock.elapsedMilliseconds, lessThan(200));
      expect(cdn.cancelled, greaterThanOrEqualTo(4));
      await sleepMs(300);
      expect(cdn.urls.length, requests, reason: 'nothing new starts after the cancel');
    });

    test('misbehaving nodes are routed around: refusal, truncation, stall', () async {
      final cdn = SimCDN(size: 4 * _bigSegmentBytes, behaviors: {
        TestEngine.cosov: const NodeBehavior(status: 403),
        TestEngine.aliov: const NodeBehavior(truncateAfter: 1000),
        TestEngine.hk1: const NodeBehavior(stallAfter: 2000),
      });
      final session = _bigSession(cdn, segments: 4);
      addTearDown(session.close);
      for (var index = 0; index < 4; index++) {
        expect(await read(session, _bigSegment(index)), bytesOf(cdn, _bigSegment(index)));
      }
      expect(session.stats().failures, greaterThan(0));
    });

    test('a node that drops its connections is struck and the others finish the read', () async {
      final cdn = SimCDN(size: 4 * _bigSegmentBytes, behaviors: {
        TestEngine.cosov: const NodeBehavior(connectionLost: true),
      });
      final session = _bigSession(cdn, segments: 4);
      addTearDown(session.close);
      expect(await read(session, _bigSegment(0)), bytesOf(cdn, _bigSegment(0)));
      final struck = cdn.requestsTo(TestEngine.cosov);
      expect(struck, greaterThan(0));
      for (var index = 1; index < 4; index++) {
        expect(await read(session, _bigSegment(index)), bytesOf(cdn, _bigSegment(index)));
      }
      final cosov = NodeStatus.best(TestEngine.cosov, session.stats().nodeStates)!;
      expect(cosov.state, anyOf('blocked', 'banned'));
      expect(cdn.requestsTo(TestEngine.cosov), struck, reason: 'left out of the reads after its failures');
      expect(cdn.requestsTo(TestEngine.hk3), greaterThan(0));
    });

    // Stronger than 'replaced URLs keep working': the old signature is refused and only the new one is used.
    test('replaceUrls takes effect on the next read', () async {
      final cdn = SimCDN(size: 4 * _bigSegmentBytes);
      final session = _bigSession(cdn, config: TestEngine.config.copyWith(prefetchVideoBytes: 0), segments: 4);
      addTearDown(session.close);
      await read(session, _bigSegment(0));
      final before = cdn.urls.length;
      const fresh = 'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/1/2/3/v.m4s?deadline=99&os=cosbv';
      session.replaceUrls(TrackKind.video, primary: fresh, backups: const []);
      // The old signature has expired.
      for (final node in NodeCatalog.overseas) {
        cdn.set(node, const NodeBehavior(refusedQueries: ['deadline=9&']));
      }
      expect(await read(session, _bigSegment(1)), bytesOf(cdn, _bigSegment(1)));
      final after = cdn.urls.sublist(before);
      expect(after, isNotEmpty);
      expect(after.every((url) => url.contains('deadline=99&')), isTrue);
    });
  });

  group('hedging (slice 1)', () {
    // Long timeouts, so only a hedged copy can save the piece in time.
    const config = RipperConfig(firstByteTimeoutMs: 5000, stallTimeoutMs: 5000, hedgeDelayMs: 100);

    Future<(AttemptOutput, int)> download(SimCDN cdn, {bool hurry = false}) async {
      final ctx = EngineContext(transport: cdn, pool: ConnectionPool(8), config: config, logger: Logger(session: 'test'));
      final resolver = Resolver(primary: TestEngine.primary, backups: const [], mode: NodeMode.overseas, bans: BanList());
      final clock = Stopwatch()..start();
      final output = await PieceDownloader(ctx).download(
        piece: ByteRange(0, 65535),
        index: 0,
        resolver: resolver,
        preferred: [TestEngine.on(TestEngine.cosov), TestEngine.on(TestEngine.aliov)],
        mode: PieceMode.normal,
        priority: 50,
        hurry: () => hurry,
      );
      return (output, clock.elapsedMilliseconds);
    }

    test('a node slow to its first byte gets a second copy on another node', () async {
      final cdn = SimCDN(size: 1 << 20, behaviors: {TestEngine.cosov: const NodeBehavior(firstByteMs: 2000)});
      final (output, ms) = await download(cdn);
      expect(NodeCatalog.nodeKey(output.url), TestEngine.aliov);
      expect(output.bytes, bytesOf(cdn, ByteRange(0, 65535)));
      expect(ms, lessThan(1000));
      expect(await eventually(() => cdn.inflight == 0), isTrue, reason: 'the losing copy is cancelled');
      expect(cdn.cancelled, 1);
    });

    test('in a hurry the copy goes after 250 ms without a first byte', () async {
      final cdn = SimCDN(size: 1 << 20, behaviors: {TestEngine.cosov: const NodeBehavior(firstByteMs: 2000)});
      final (output, ms) = await download(cdn, hurry: true);
      expect(NodeCatalog.nodeKey(output.url), TestEngine.aliov);
      expect(ms, inInclusiveRange(240, 1000));
    });

    test('a node that trickles is hedged too', () async {
      final cdn = SimCDN(size: 1 << 20, behaviors: {TestEngine.cosov: const NodeBehavior(bytesPerSecond: 20e3)});
      final (output, ms) = await download(cdn, hurry: true);
      expect(NodeCatalog.nodeKey(output.url), TestEngine.aliov);
      expect(ms, lessThan(2000));
    });
  });

  group('bans (slice 1)', () {
    String url(String node) => TestEngine.on(node);

    test('two 0-byte replies at different moments ban the node, which drops out of the candidates', () {
      final clock = ManualClock(10000);
      final bans = BanList();
      final resolver = Resolver(
          primary: TestEngine.primary, backups: const [], mode: NodeMode.overseas, bans: bans, clock: clock.clock);
      resolver.failure(url(TestEngine.cosov), receivedBytes: 0);
      expect(bans.allows(url(TestEngine.cosov)), isTrue);
      clock.advance(300);
      resolver.failure(url(TestEngine.cosov), receivedBytes: 0);
      expect(bans.allows(url(TestEngine.cosov)), isFalse);
      expect(resolver.urls().map(NodeCatalog.nodeKey), isNot(contains(TestEngine.cosov)));
      expect(NodeStatus.best(TestEngine.cosov, resolver.status())!.state, 'banned');
    });

    test('a transfer cut off after some bytes is no strike', () {
      final clock = ManualClock(10000);
      final bans = BanList();
      final resolver = Resolver(
          primary: TestEngine.primary, backups: const [], mode: NodeMode.overseas, bans: bans, clock: clock.clock);
      for (var round = 0; round < 3; round++) {
        resolver.failure(url(TestEngine.cosov), receivedBytes: 1000, range: ByteRange(0, 65535));
        clock.advance(300);
      }
      expect(bans.allows(url(TestEngine.cosov)), isTrue);
    });

    test('a failure blocks the node briefly; a network change clears the block', () {
      final clock = ManualClock(10000);
      final resolver = Resolver(
          primary: TestEngine.primary, backups: const [], mode: NodeMode.overseas, bans: BanList(), clock: clock.clock);
      resolver.failure(url(TestEngine.cosov), status: 503, receivedBytes: 0);
      expect(NodeStatus.best(TestEngine.cosov, resolver.status())!.state, 'blocked');
      expect(resolver.rescueCandidates().map(NodeCatalog.nodeKey), isNot(contains(TestEngine.cosov)));
      clock.advance(6001);
      expect(resolver.rescueCandidates().map(NodeCatalog.nodeKey), contains(TestEngine.cosov));
      final hk1 = url(TestEngine.hk1);
      resolver.failure(hk1, status: 503, receivedBytes: 0);
      expect(NodeStatus.best(TestEngine.hk1, resolver.status())!.state, 'blocked');
      resolver.resetHealth(clearMeasurements: false);
      expect(NodeStatus.best(TestEngine.hk1, resolver.status())!.state, 'untested');
    });
  });
}

/// TestEngine.config without the fixed connection count, so AutoConcurrency decides.
RipperConfig automaticConfig() {
  const base = TestEngine.config;
  return RipperConfig(
    firstByteTimeoutMs: base.firstByteTimeoutMs,
    stallTimeoutMs: base.stallTimeoutMs,
    attemptTimeoutMs: base.attemptTimeoutMs,
    hedgeDelayMs: base.hedgeDelayMs,
    retryWindowMs: base.retryWindowMs,
  );
}

const _bigSegmentBytes = 512 * 1024;

RipperSession _bigSession(SimCDN cdn, {RipperConfig config = TestEngine.config, int segments = 0}) {
  final session = makeSession(cdn, config: config);
  session.setSegments(TrackKind.video, [
    for (var index = 0; index < segments; index++)
      MediaSegment(index: index, range: _bigSegment(index), startTime: index * 2.0, duration: 2),
  ]);
  return session;
}

ByteRange _bigSegment(int index) => ByteRange(index * _bigSegmentBytes, (index + 1) * _bigSegmentBytes - 1);
