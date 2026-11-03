import 'dart:typed_data';

import 'package:bili_core/engine.dart';
import 'package:bili_core/shared.dart';
import 'package:bili_core/src/engine/attempt.dart';
import 'package:bili_core/src/engine/connection_pool.dart';
import 'package:bili_core/src/engine/node_stats.dart';
import 'package:bili_core/src/engine/resolver.dart';
import 'package:test/test.dart';

const _original =
    'https://upos-hz-mirrorakam.akamaized.net/upgcxcode/v.m4s?deadline=9&hdnts=a%2Fb';
const _backup =
    'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/v.m4s?deadline=9&upsig=x';

void main() {
  late ManualClock clock;
  late Resolver resolver;

  setUp(() {
    clock = ManualClock(100000);
    resolver = Resolver(
      primary: _original,
      backups: [_backup],
      mode: NodeMode.auto,
      clock: clock.clock,
    );
  });

  test('auto bounds cold exploration and keeps exact original addresses available for media and rescue', () {
    final first = resolver.rangeCandidates();
    expect(first, hasLength(4));
    expect(first.take(2), [_original, _backup]);
    resolver.success(_original, bps: 2000000);
    final next = resolver.rangeCandidates();
    expect(
      next,
      hasLength(2),
      reason: 'one measured route plus one explorer, without the manual three-node floor',
    );
    expect(next.first, _original);
    expect(resolver.rescueCandidates(), contains(_original));
    final explored = <String>{};
    for (var index = 0; index < resolver.urls().length; index++) {
      final candidates = resolver.rangeCandidates();
      expect(candidates, hasLength(2));
      explored.add(candidates.last);
    }
    expect(
      explored,
      containsAll(resolver.urls().where((url) => url != _original)),
    );
  });

  test('auto ranks actual request size by latency and body rate, regardless of which file was proven first', () {
    final nodes = NodeStats();
    resolver = Resolver(
      primary: _original,
      backups: [_backup],
      mode: NodeMode.auto,
      clock: clock.clock,
      nodes: nodes,
    );
    nodes.firstByte(_original, ms: 20);
    nodes.body(_original, bytes: 1 << 20, ms: 1000);
    nodes.firstByte(_backup, ms: 500);
    nodes.body(_backup, bytes: 8 << 20, ms: 1000);
    resolver.success(_original, bps: 1000000);
    resolver.sample(_backup, bps: 1000000);
    expect(resolver.rangeCandidates(bytes: 16 * 1024).first, _original);
    expect(resolver.rangeCandidates(bytes: 4 << 20).first, _backup);
    expect(resolver.startupCandidates().first, _original);
    expect(resolver.rescueCandidates().first, _original);
  });

  test(
    'auto uses existing node priors without making remembered validity or bans',
    () {
      final priors = NodePriors.fixed({
        NodeCatalog.nodeKey(_original): const NodePrior(
          ttfbMs: 20,
          bps: 1000000,
        ),
        NodeCatalog.nodeKey(_backup): const NodePrior(
          ttfbMs: 500,
          bps: 8000000,
        ),
      });
      resolver = Resolver(
        primary: _original,
        backups: [_backup],
        mode: NodeMode.auto,
        clock: clock.clock,
        priors: priors,
      );
      expect(resolver.startupCandidates().first, _original);
      expect(resolver.rangeCandidates(bytes: 4 << 20).first, _backup);
      expect(
        resolver.rangeCandidates(),
        hasLength(3),
        reason: 'two remembered nodes plus one explorer',
      );
      expect(
        resolver.status().every((node) => node.state == 'untested'),
        isTrue,
      );
    },
  );

  test('auto shares the other track measurements even before network memory is available', () {
    final nodes = NodeStats();
    nodes.firstByte(_original, ms: 20);
    nodes.body(_original, bytes: 1 << 20, ms: 1000);
    resolver = Resolver(
      primary: _original,
      backups: [_backup],
      mode: NodeMode.auto,
      clock: clock.clock,
      nodes: nodes,
    );
    expect(
      resolver.rangeCandidates(),
      hasLength(2),
      reason: 'one shared measurement plus one explorer',
    );
    expect(resolver.rangeCandidates().first, _original);
    nodes.reset();
    resolver.resetHealth(clearMeasurements: true);
    expect(
      resolver.rangeCandidates(),
      hasLength(4),
      reason: 'a network change starts a bounded cold trial',
    );
  });

  test('urgent auto reads reuse learned nodes, while normal reads keep one exploration slot', () {
    resolver = Resolver(
      primary: _original,
      backups: [_backup],
      mode: NodeMode.auto,
      clock: clock.clock,
      exploreInHurry: false,
    );
    resolver.success(_original, bps: 3000000);
    resolver.success(_backup, bps: 1000000);
    expect(resolver.rangeCandidates(hurried: true), [_original, _backup]);
    expect(resolver.rangeCandidates(), hasLength(3));
    clock.advance(90001);
    expect(
      resolver.rangeCandidates(hurried: true),
      hasLength(1),
      reason: 'expired routes return to exploration',
    );
  });

  test('auto bounds last-resort candidates when all routes are backed off', () {
    for (final url in resolver.urls()) {
      resolver.failure(url, status: 503, receivedBytes: 0);
    }
    expect(resolver.rangeCandidates(), hasLength(4));
  });

  for (final bytes in [8192, 65536]) {
    test(
      'first body timing excludes headers and empty chunks ($bytes bytes)',
      () async {
        final transport = _DelayedBody(clock);
        final ctx = EngineContext(
          transport: transport,
          pool: ConnectionPool(8, clock: clock.clock),
          config: const RipperConfig(),
          clock: clock.clock,
        );
        final progress = AttemptProgress();
        await AttemptRunner(ctx).runAt(
          _original,
          piece: ByteRange(0, bytes - 1),
          progress: progress,
          resolver: resolver,
          priority: 0,
          queueClass: QueueClass.ordinary,
        );
        expect(progress.headersAt - progress.startedAt, 20);
        expect(progress.firstBodyAt! - progress.startedAt, 300);
        expect(ctx.nodes.ttfbMs(_original), 300);
        expect(
          ctx.nodes.isBusy(_original),
          isFalse,
          reason: 'the first-body receiving count is balanced at completion',
        );
        expect(
          ctx.stats
              .snapshot(concurrency: 8, nodeStates: const [])
              .nodes
              .single
              .firstByteMs,
          300,
        );
        if (bytes < 32 * 1024) {
          expect(
            ctx.nodes.bps(_original),
            0,
            reason: 'a tiny index does not establish body throughput',
          );
          expect(resolver.speed(_original), 0);
        } else {
          expect(ctx.nodes.bps(_original), closeTo(bytes / 0.04, 0.001));
          expect(resolver.speed(_original), greaterThan(0));
        }
      },
    );
  }
}

final class _DelayedBody implements RangeTransport {
  _DelayedBody(this.clock);

  final ManualClock clock;

  @override
  String get name => 'delayed body';

  @override
  int? get connectionsPerHost => null;

  @override
  void close() {}

  @override
  Future<TransportResponse> fetch(
    Uri url,
    ByteRange range, {
    CancelToken? cancel,
  }) async {
    clock.advance(20);
    Stream<List<int>> body() async* {
      clock.advance(200);
      yield const [];
      clock.advance(80);
      yield Uint8List(range.length ~/ 2);
      clock.advance(40);
      yield Uint8List(range.length - range.length ~/ 2);
    }

    return TransportResponse(
      status: 206,
      headers: {'content-range': 'bytes $range/${range.end + 1}'},
      body: body(),
    );
  }
}
