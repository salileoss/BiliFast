import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart';
import 'package:bili_core/shared.dart';
import 'package:test/test.dart';

import 'support/loopback_server.dart';
import 'support/sim_cdn.dart';

RangeTransport _recordingTransport() => _RecordingWarmTransport();

final class _RecordingWarmTransport implements RangeTransport, WarmableTransport {
  @override
  int? get connectionsPerHost => null;
  @override
  String get name => 'recording';
  @override
  void close() {}
  @override
  Future<TransportResponse> fetch(Uri url, ByteRange range, {CancelToken? cancel}) =>
      Future.error(StateError('warm-up should use warm'));
  @override
  Future<bool> warm(Uri url) async {
    Logger.shared.info(LogCategory.engine, 'test warm host', {'host': url.host});
    return true;
  }
}

void main() {
  late LoopbackServer server;

  setUp(() async {
    server = await LoopbackServer.start({
      '/keep': const Complete(100000, keepAlive: true),
      '/hang': const Hang(),
    });
  });

  tearDown(() => server.stop());

  test('a warm-up asks for one byte and leaves the connection open for the next request', () async {
    final transport = IoRangeTransport();
    addTearDown(transport.close);
    expect(await warmConnection(transport, server.url('/keep')), isTrue);
    expect(server.headers('/keep').single['range'], 'bytes=0-0');
    final response = await transport.fetch(server.url('/keep'), ByteRange(0, 99999));
    await response.body.drain<void>();
    expect(server.requests('/keep'), 2);
    expect(server.connections, 1, reason: 'the engine\'s first request found the warm connection');
  });

  test('a node that does not answer only costs the warm-up its time limit', () async {
    final transport = IoRangeTransport();
    addTearDown(transport.close);
    final clock = Stopwatch()..start();
    expect(await warmByFetch(transport, server.url('/hang'), timeout: const Duration(milliseconds: 200)), isFalse);
    expect(clock.elapsedMilliseconds, lessThan(2000));
  });

  test('a transport that cannot warm does nothing', () async {
    final cdn = SimCDN(size: 1024);
    expect(await warmConnection(cdn, Uri.parse(TestEngine.primary)), isFalse);
    expect(cdn.requestCount, 0);
  });

  test('Auto preconnect warms at most three hosts without extra Akamai copies', () async {
    final logs = MemorySink();
    Logger.shared.add(logs);
    addTearDown(() => Logger.shared.remove(logs));
    final engine = await PlaybackEngine.start(
      transportFactory: _recordingTransport,
      options: const EngineOptions(nodeMode: NodeMode.auto),
    );
    addTearDown(engine.dispose);
    engine.preconnect([
      'https://upos-hz-mirrorakam.akamaized.net/upgcxcode/v.m4s?hdnts=x',
      TestEngine.primary,
    ]);
    final timeout = DateTime.now().add(const Duration(seconds: 3));
    while (!logs.events.any((event) => event.msg == 'preconnect') && DateTime.now().isBefore(timeout)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final event = logs.events.singleWhere((event) => event.msg == 'preconnect');
    expect(event.f['nodes'], const LogInt(3));
    expect(event.f['requests'], const LogInt(3));
    expect(event.f['answered'], const LogInt(3));
    expect(logs.events.where((event) => event.msg == 'test warm host').map((event) => event.f['host']), [
      const LogString('upos-hz-mirrorakam.akamaized.net'),
      LogString(NodeCatalog.host(TestEngine.primary)),
      LogString(NodeCatalog.overseas.first),
    ]);
  });
}
