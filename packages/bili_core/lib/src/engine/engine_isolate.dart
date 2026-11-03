import 'dart:async';
import 'dart:isolate';

import '../devlog/log_event.dart';
import '../devlog/logger.dart';
import '../local_http/local_server.dart';
import '../local_http/playback_router.dart';
import '../shared/clock.dart';
import 'auto_concurrency.dart';
import 'cancel.dart';
import 'local_source.dart';
import 'log_forwarding.dart';
import 'node_catalog.dart';
import 'node_memory.dart';
import 'node_memory_store.dart';
import 'offline_download.dart';
import 'offline_types.dart';
import 'playback_builder.dart';
import 'playback_engine.dart';
import 'ripper_config.dart';
import 'ripper_session.dart';
import 'transport.dart';

final class EngineOptions {
  const EngineOptions({
    this.nodeMode = NodeMode.overseas,
    this.policy = MediaURLPolicy.bilibili,
    this.config = const RipperConfig(),
    this.statsInterval = const Duration(seconds: 1),
    this.directPrepareSeconds = 20,
    this.forwardDebugLogs = false,
    this.nodeMemoryPath,
  });

  /// The nodes sessions start on; [PlaybackEngine.setNodeMode] changes them for the sessions prepared after it.
  final NodeMode nodeMode;
  final MediaURLPolicy policy;
  final RipperConfig config;
  final Duration statsInterval;

  /// The whole direct-mode header fetch (`PlaybackController.directPrepareSeconds`).
  final double directPrepareSeconds;

  /// The engine's debug events (every piece and attempt) reach the UI isolate's log too; for dev builds.
  final bool forwardDebugLogs;

  /// Where the engine keeps what it measured about each node between launches ([NodeMemory]); null forgets it all
  /// at the end of each session, as Swift did.
  final String? nodeMemoryPath;
}

/// [PlaybackEngine] over a background isolate that owns the transport, the sessions and the local server.
final class IsolatePlaybackEngine implements PlaybackEngine {
  IsolatePlaybackEngine._(this._events);

  /// [transportFactory] runs inside the engine isolate. A second transport from it carries direct mode's
  /// header requests, so they don't ride the engine's warm connections (as in Swift).
  static Future<IsolatePlaybackEngine> start({
    required RangeTransport Function() transportFactory,
    EngineOptions options = const EngineOptions(),
  }) async {
    final engine = IsolatePlaybackEngine._(ReceivePort('engine'));
    engine._events.listen(engine._receive);
    try {
      engine._isolate = await Isolate.spawn(
        _engineMain,
        _Boot(engine._events.sendPort, transportFactory, options),
        debugName: 'engine',
        errorsAreFatal: false,
        onExit: engine._events.sendPort,
        onError: engine._events.sendPort,
      );
      await engine._ready.future;
    } catch (_) {
      engine._shutdown();
      rethrow;
    }
    return engine;
  }

  final ReceivePort _events;
  Isolate? _isolate;
  SendPort? _commands;
  final _ready = Completer<void>();
  final _pending = <int, Completer<Object?>>{};
  int _nextId = 0;
  bool _closed = false;
  final _stats = StreamController<EngineSnapshot>.broadcast();
  final _fatals = StreamController<FatalReport>.broadcast();
  final _downloads = StreamController<DownloadEvent>.broadcast();

  @override
  Stream<EngineSnapshot> get stats => _stats.stream;

  @override
  Stream<DownloadEvent> get downloads => _downloads.stream;

  @override
  Stream<FatalReport> get fatals => _fatals.stream;

  @override
  Future<PreparedSource> prepare(PlaybackRequest request) async =>
      await _call((id) => _Prepare(id, request)) as PreparedSource;

  @override
  Future<void> release(String token) => _call((id) => _Release(id, token));

  @override
  Future<void> replaceUrls(String token, TrackKind track, {required String primary, required List<String> backups}) =>
      _call((id) => _ReplaceUrls(id, token, track, primary, backups));

  @override
  Future<void> networkChanged({required bool interfaceChanged}) => _call((id) => _NetworkChanged(id, interfaceChanged));

  @override
  void updatePlayhead(String token, {required double seconds, required double rate}) =>
      _notify(_Playhead(token, seconds, rate));

  @override
  void reportBuffer(String token, {required double aheadSeconds, required bool playing}) =>
      _notify(_Buffer(token, aheadSeconds, playing));

  @override
  void reportStall(String token) => _notify(_Stall(token));

  @override
  void dropCache() => _notify(const _DropCache());

  @override
  void dropPrefetch(String token) => _notify(_DropPrefetch(token));

  @override
  void hint(String token, double? seconds) => _notify(_Hint(token, seconds));

  @override
  void preconnect(List<String> urls) => _notify(_Preconnect(List.of(urls)));

  @override
  void setNodeMode(NodeMode mode) => _notify(_SetNodeMode(mode));

  @override
  Future<bool> ensureServing() async => await _call(_EnsureServing.new) as bool;

  @override
  Future<PreparedSource> prepareLocal(LocalPlaybackRequest request) async =>
      await _call((id) => _PrepareLocal(id, request)) as PreparedSource;

  @override
  Future<void> startDownload(DownloadRequest request) => _call((id) => _StartDownload(id, request));

  @override
  Future<DownloadGaps> stopDownload(String id) async =>
      await _call((callId) => _StopDownload(callId, id)) as DownloadGaps;

  @override
  Future<void> replaceDownloadUrls(
    String id,
    TrackKind track, {
    required String primary,
    required List<String> backups,
  }) => _call((callId) => _ReplaceDownloadUrls(callId, id, track, primary, backups));

  /// For tests and the developer menu: stops the local server's listener, as iOS does to a suspended app,
  /// so [ensureServing] has something to repair.
  Future<void> debugStopServer() => _call(_StopServer.new);

  @override
  Future<void> dispose() async {
    if (_closed) return;
    try {
      await _call(_Dispose.new).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Shut down below either way.
    }
    _shutdown();
  }

  /// Sent on the commands port too, so a notice is handled before any command sent after it.
  void _notify(_Notice notice) {
    final commands = _commands;
    if (_closed || commands == null) return;
    commands.send(notice);
  }

  Future<Object?> _call(_Command Function(int id) make) {
    final commands = _commands;
    if (_closed || commands == null) return Future.error(const RipperError(RipperErrorKind.closed));
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    commands.send(make(id));
    return completer.future;
  }

  void _receive(Object? message) {
    switch (message) {
      case _Ready(:final commands):
        _commands = commands;
        if (!_ready.isCompleted) _ready.complete();
      case _StartFailed(:final error, :final stack):
        if (!_ready.isCompleted) _ready.completeError(error, StackTrace.fromString(stack));
      case _Reply(:final id, :final value, :final error, :final stack):
        final completer = _pending.remove(id);
        if (completer == null) return;
        if (error != null) {
          completer.completeError(error, StackTrace.fromString(stack ?? ''));
        } else {
          completer.complete(value);
        }
      case _Stats(:final snapshot):
        if (!_stats.isClosed) _stats.add(snapshot);
      case final FatalReport report:
        if (!_fatals.isClosed) _fatals.add(report);
      case final DownloadEvent event:
        if (!_downloads.isClosed) _downloads.add(event);
      case _Logs(:final events):
        ForwardingLogSink.replay(events);
      case [final error, final stack]:
        Logger.shared.error(LogCategory.engine, 'engine isolate error', {'error': '$error', 'stack': '$stack'});
      case null:
        if (!_closed) Logger.shared.error(LogCategory.engine, 'engine isolate exited');
        if (!_ready.isCompleted) _ready.completeError(const RipperError(RipperErrorKind.closed));
        _shutdown();
    }
  }

  void _shutdown() {
    _closed = true;
    final pending = _pending.values.toList();
    _pending.clear();
    for (final completer in pending) {
      completer.completeError(const RipperError(RipperErrorKind.closed));
    }
    _events.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    if (!_stats.isClosed) _stats.close();
    if (!_fatals.isClosed) _fatals.close();
    if (!_downloads.isClosed) _downloads.close();
  }
}

final class _Boot {
  const _Boot(this.events, this.transportFactory, this.options);

  final SendPort events;
  final RangeTransport Function() transportFactory;
  final EngineOptions options;
}

sealed class _Command {
  const _Command(this.id);

  final int id;
}

final class _Prepare extends _Command {
  const _Prepare(super.id, this.request);

  final PlaybackRequest request;
}

final class _Release extends _Command {
  const _Release(super.id, this.token);

  final String token;
}

final class _ReplaceUrls extends _Command {
  const _ReplaceUrls(super.id, this.token, this.track, this.primary, this.backups);

  final String token;
  final TrackKind track;
  final String primary;
  final List<String> backups;
}

final class _NetworkChanged extends _Command {
  const _NetworkChanged(super.id, this.interfaceChanged);

  final bool interfaceChanged;
}

final class _PrepareLocal extends _Command {
  const _PrepareLocal(super.id, this.request);

  final LocalPlaybackRequest request;
}

final class _StartDownload extends _Command {
  const _StartDownload(super.id, this.request);

  final DownloadRequest request;
}

final class _StopDownload extends _Command {
  const _StopDownload(super.id, this.download);

  final String download;
}

final class _ReplaceDownloadUrls extends _Command {
  const _ReplaceDownloadUrls(super.id, this.download, this.track, this.primary, this.backups);

  final String download;
  final TrackKind track;
  final String primary;
  final List<String> backups;
}

final class _EnsureServing extends _Command {
  const _EnsureServing(super.id);
}

final class _StopServer extends _Command {
  const _StopServer(super.id);
}

final class _Dispose extends _Command {
  const _Dispose(super.id);
}

/// Fire and forget: no id, no reply.
sealed class _Notice {
  const _Notice();
}

final class _Playhead extends _Notice {
  const _Playhead(this.token, this.seconds, this.rate);

  final String token;
  final double seconds;
  final double rate;
}

final class _Buffer extends _Notice {
  const _Buffer(this.token, this.aheadSeconds, this.playing);

  final String token;
  final double aheadSeconds;
  final bool playing;
}

final class _Stall extends _Notice {
  const _Stall(this.token);

  final String token;
}

final class _DropCache extends _Notice {
  const _DropCache();
}

final class _DropPrefetch extends _Notice {
  const _DropPrefetch(this.token);

  final String token;
}

final class _Hint extends _Notice {
  const _Hint(this.token, this.seconds);

  final String token;
  final double? seconds;
}

final class _Preconnect extends _Notice {
  const _Preconnect(this.urls);

  final List<String> urls;
}

final class _SetNodeMode extends _Notice {
  const _SetNodeMode(this.mode);

  final NodeMode mode;
}

final class _Ready {
  const _Ready(this.commands);

  final SendPort commands;
}

final class _StartFailed {
  const _StartFailed(this.error, this.stack);

  final Object error;
  final String stack;
}

final class _Reply {
  const _Reply(this.id, {this.value, this.error, this.stack});

  final int id;
  final Object? value;
  final Object? error;
  final String? stack;
}

final class _Stats {
  const _Stats(this.snapshot);

  final EngineSnapshot snapshot;
}

final class _Logs {
  const _Logs(this.events);

  final List<LogEvent> events;
}

/// Errors go as themselves, so the caller can switch on PlaybackError and RipperError; one that can't cross
/// isolates (it holds a native resource) goes as [fallback], a RemoteError with its text.
void _sendOr(SendPort port, Object message, Object Function() fallback) {
  try {
    port.send(message);
  } catch (_) {
    port.send(fallback());
  }
}

Future<void> _engineMain(_Boot boot) async {
  final sink = ForwardingLogSink(
    (events) => boot.events.send(_Logs(events)),
    forwardDebug: boot.options.forwardDebugLogs,
  );
  Logger.shared.add(sink);
  final host = _EngineHost(boot, sink);
  try {
    await host.start();
  } catch (error, stack) {
    sink.flush();
    Logger.shared.remove(sink);
    _sendOr(boot.events, _StartFailed(error, '$stack'), () => _StartFailed(RemoteError('$error', '$stack'), '$stack'));
    host.closeTransports();
    return;
  }
  final commands = ReceivePort('engine commands');
  host.onDisposed = commands.close;
  commands.listen((message) {
    switch (message) {
      case final _Command command:
        unawaited(host.handle(command));
      case final _Notice notice:
        host.notice(notice);
    }
  });
  boot.events.send(_Ready(commands.sendPort));
}

final class _EngineHost {
  _EngineHost(this._boot, this._sink);

  final _Boot _boot;
  final ForwardingLogSink _sink;
  final _router = PlaybackRouter();
  late final LocalServer _server;
  late final RangeTransport _transport;
  RangeTransport? _directTransport;
  final _root = CancelToken();

  /// The connection count is app-wide, as in Swift: every session of this engine follows it.
  final _auto = AutoConcurrency();
  final _sessions = <String, RipperSession>{};
  final _directTokens = <String>{};
  final _localTokens = <String>{};
  final _lastDelivered = <String, int>{};
  String? _newest;
  Timer? _statsTimer;
  double _lastTickAt = 0;
  bool _disposed = false;
  void Function()? onDisposed;
  late final NodeMemoryStore? _store = switch (_options.nodeMemoryPath) {
    final String path => NodeMemoryStore(path),
    null => null,
  };
  late final NodeMemory? _memory = _store?.load();
  var _ticks = 0;
  late NodeMode _nodeMode = _options.nodeMode;
  late final _offline = OfflineDownloads(
    transport: _transport,
    auto: _auto,
    mode: () => _nodeMode,
    config: _options.config,
    policy: _options.policy,
    memory: _memory,
    emit: _boot.events.send,
  );

  EngineOptions get _options => _boot.options;

  Future<void> _refreshSignature() async {
    final memory = _memory;
    if (memory != null) memory.signature = await NodeMemoryStore.networkSignature();
  }

  void _saveMemory() {
    final memory = _memory;
    if (memory != null) _store?.save(memory);
  }

  Future<void> start() async {
    _transport = _boot.transportFactory();
    _server = await LocalServer.start(_router);
    Logger.shared.info(LogCategory.engine, 'engine started', {'transport': _transport.name, 'port': _server.port});
  }

  void closeTransports() {
    try {
      _transport.close();
    } catch (_) {
      // Never built.
    }
    _directTransport?.close();
  }

  Future<void> handle(_Command command) async {
    final port = _boot.events;
    try {
      final value = await _run(command);
      port.send(_Reply(command.id, value: value));
    } catch (error, stack) {
      _sendOr(
        port,
        _Reply(command.id, error: error, stack: '$stack'),
        () => _Reply(command.id, error: RemoteError('$error', '$stack'), stack: '$stack'),
      );
    }
    if (command is _Dispose) {
      Logger.shared.remove(_sink);
      onDisposed?.call();
    }
  }

  void notice(_Notice notice) {
    if (_disposed) return;
    switch (notice) {
      case _Playhead(:final token, :final seconds, :final rate):
        _sessions[token]?.updatePlayhead(seconds: seconds, rate: rate);
      case _Buffer(:final token, :final aheadSeconds, :final playing):
        _sessions[token]?.reportBuffer(aheadSeconds: aheadSeconds, playing: playing);
      case _Stall(:final token):
        _sessions[token]?.reportStall();
      case _DropCache():
        for (final session in _sessions.values) {
          session.dropCache();
        }
      case _DropPrefetch(:final token):
        _sessions[token]?.dropPrefetch();
      case _Hint(:final token, :final seconds):
        _sessions[token]?.hint(seconds);
      case _Preconnect(:final urls):
        _preconnect(urls);
      case _SetNodeMode(:final mode):
        _nodeMode = mode;
        Logger.shared.info(LogCategory.engine, 'node mode', {
          'mode': switch (mode) {
            MainlandNodes() => 'mainland',
            AutoNodes() => 'auto',
            OverseasNodes() => 'overseas',
            CustomNodes(:final nodes) => 'custom ${nodes.length}',
          },
        });
    }
  }

  /// Auto warms at most three hosts, favouring the current network's measurements. Regional modes keep one
  /// connection per node, three to Akamai, whose HTTP/1.1 requests each need their own connection.
  void _preconnect(List<String> urls) {
    if (urls.isEmpty) return;
    final policy = _options.policy;
    final mode = _nodeMode;
    final all = [
      if (mode is! CustomNodes) ...urls.where(policy.allowsURL),
      ...NodeCatalog.representationURLs(
        primary: urls.first,
        backups: urls.skip(1).toList(),
        mode: mode,
        policy: policy,
      ),
    ];
    final byNode = <String, Uri>{};
    for (final url in all) {
      final node = NodeCatalog.nodeKey(url);
      final uri = Uri.tryParse(url);
      if (node.isNotEmpty && uri != null) byNode.putIfAbsent(node, () => uri);
    }
    var targets = byNode.values.toList();
    if (mode is AutoNodes) {
      final priors = _memory?.priors;
      final ranked = [
        for (var index = 0; index < targets.length; index++)
          (
            uri: targets[index],
            order: index,
            prior: priors?.of(NodeCatalog.nodeKey('${targets[index]}')),
          ),
      ];
      double finishMs(NodePrior? prior) => prior == null || prior.bps <= 0
          ? double.infinity
          : prior.ttfbMs + 8192 * 1000 / prior.bps;
      ranked.sort((a, b) {
        final compared = finishMs(a.prior).compareTo(finishMs(b.prior));
        return compared == 0 ? a.order.compareTo(b.order) : compared;
      });
      targets = [for (final entry in ranked.take(3)) entry.uri];
    }
    final started = MonotonicClock.system.nowMs();
    final warming = [
      for (final uri in targets)
        for (var copy = 0; copy < (mode is! AutoNodes && NodeCatalog.isAkamai('$uri') ? 3 : 1); copy++)
          warmConnection(_transport, uri),
    ];
    unawaited(
      Future.wait(warming).then((answered) {
        Logger.shared.info(LogCategory.engine, 'preconnect', {
          'nodes': targets.length,
          'requests': warming.length,
          'answered': answered.where((ok) => ok).length,
          'ms': (MonotonicClock.system.nowMs() - started).roundToDouble(),
        });
      }),
    );
  }

  Future<Object?> _run(_Command command) async {
    if (_disposed) throw const RipperError(RipperErrorKind.closed);
    switch (command) {
      case _Prepare(:final request):
        return request.mode == PlaybackMode.btr ? _prepareRipper(request) : _prepareDirect(request);
      case _Release(:final token):
        _release(token);
      case _ReplaceUrls(:final token, :final track, :final primary, :final backups):
        _sessions[token]?.replaceUrls(track, primary: primary, backups: backups);
      case _NetworkChanged(:final interfaceChanged):
        await _refreshSignature();
        for (final session in _sessions.values) {
          session.networkChanged(interfaceChanged: interfaceChanged);
        }
        _offline.networkChanged(interfaceChanged: interfaceChanged);
      case _PrepareLocal(:final request):
        return _prepareLocal(request);
      case _StartDownload(:final request):
        await _offline.start(request);
      case _StopDownload(:final download):
        return _offline.stop(download);
      case _ReplaceDownloadUrls(:final download, :final track, :final primary, :final backups):
        _offline.replaceUrls(download, track, primary: primary, backups: backups);
      case _EnsureServing():
        return _ensureServing();
      case _StopServer():
        await _server.close();
      case _Dispose():
        await _dispose();
    }
    return null;
  }

  Future<PreparedSource> _prepareRipper(PlaybackRequest request) async {
    final choice = request.choice;
    await _refreshSignature();
    final session = RipperSession(
      sources: {
        TrackKind.video: (primary: choice.video.baseURL, backups: choice.video.backupURLs),
        TrackKind.audio: (primary: choice.audio.baseURL, backups: choice.audio.backupURLs),
      },
      mode: _nodeMode,
      transport: _transport,
      auto: _auto,
      config: _options.config,
      policy: _options.policy,
      memory: _memory,
    );
    try {
      final prepared = await PlaybackBuilder.prepare(
        choice,
        fetchHeaders: (kind, stream) async {
          final headers = await session.loadHeaders(kind, through: stream.indexRange.end);
          return (bytes: headers.bytes, total: headers.totalSize);
        },
      );
      if (_disposed) throw const RipperError(RipperErrorKind.closed);
      session
        ..setSegments(TrackKind.video, prepared.video.segments)
        ..setSegments(TrackKind.audio, prepared.audio.segments);
      if (_options.config.primeStart) {
        session
          ..prime(TrackKind.video, seconds: request.startSeconds)
          ..prime(TrackKind.audio, seconds: request.startSeconds);
      }
      final token = _router.register(
        PlaybackBuilder.ripperAssets(prepared, read: session.read, peakBandwidth: _options.config.peakBandwidth),
      );
      _sessions[token] = session;
      session.onFatal = (error) {
        if (identical(_sessions[token], session)) _boot.events.send(FatalReport(token: token, message: '$error'));
      };
      _lastDelivered[token] = session.deliveredBytes;
      _newest = token;
      _startStats();
      return PreparedSource(
        token: token,
        master: _server.url(token, 'master.m3u8'),
        video: _server.url(token, 'v.mp4'),
        audio: _server.url(token, 'a.mp4'),
        mode: PlaybackMode.btr,
        rewroteHEV1: prepared.rewroteHEV1,
        sourceEntry: prepared.sourceEntry,
        mediaHeaders: const {},
      );
    } catch (_) {
      session.close();
      rethrow;
    }
  }

  Future<PreparedSource> _prepareDirect(PlaybackRequest request) async {
    final transport = _directTransport ??= _boot.transportFactory();
    final seconds = _options.directPrepareSeconds;
    final PreparedPlayback prepared;
    try {
      prepared = await PlaybackBuilder.within(
        seconds,
        (cancel) => PlaybackBuilder.prepareDirect(request.choice, transport: transport, cancel: cancel),
        cancel: _root,
      );
    } on CandidateTimeout {
      Logger.shared.error(LogCategory.player, 'direct headers timed out', {'seconds': seconds});
      throw const PlaybackError(PlaybackErrorKind.noSource);
    }
    if (_disposed) throw const RipperError(RipperErrorKind.closed);
    final token = _router.register(PlaybackBuilder.directAssets(prepared));
    _directTokens.add(token);
    return PreparedSource(
      token: token,
      master: _server.url(token, 'master.m3u8'),
      video: Uri.parse(prepared.video.mediaUrl),
      audio: Uri.parse(prepared.audio.mediaUrl),
      mode: PlaybackMode.direct,
      rewroteHEV1: prepared.rewroteHEV1,
      sourceEntry: prepared.sourceEntry,
      mediaHeaders: request.mediaHeaders,
    );
  }

  Future<PreparedSource> _prepareLocal(LocalPlaybackRequest request) async {
    final prepared = await LocalSource.prepare(request);
    if (_disposed) throw const RipperError(RipperErrorKind.closed);
    final token = _router.register(LocalSource.assets(prepared, request));
    _localTokens.add(token);
    return PreparedSource(
      token: token,
      master: _server.url(token, 'master.m3u8'),
      video: _server.url(token, 'v.mp4'),
      audio: _server.url(token, 'a.mp4'),
      mode: PlaybackMode.local,
      rewroteHEV1: prepared.rewroteHEV1,
      sourceEntry: prepared.sourceEntry,
      mediaHeaders: const {},
    );
  }

  void _release(String token) {
    _router.unregister(token);
    _directTokens.remove(token);
    _localTokens.remove(token);
    _lastDelivered.remove(token);
    if (_sessions.remove(token) case final session?) {
      session.close();
      _saveMemory();
    }
    if (_sessions.isEmpty) _stopStats();
  }

  /// iOS can silently take a suspended app's listening socket; a server that no longer answers is bound again.
  Future<bool> _ensureServing() async {
    if (await _server.answers()) return false;
    Logger.shared.warn(LogCategory.server, 'not answering, starting a new listener', {'port': _server.port});
    try {
      await _server.restart();
    } catch (error) {
      Logger.shared.error(LogCategory.server, 'restart failed', {'error': '$error'});
      throw const PlaybackError(PlaybackErrorKind.serverDown);
    }
    Logger.shared.info(LogCategory.server, 'restarted', {'port': _server.port});
    return true;
  }

  void _startStats() {
    if (_statsTimer != null) return;
    _lastTickAt = MonotonicClock.system.nowMs();
    _statsTimer = Timer.periodic(_options.statsInterval, (_) => _tick());
  }

  void _stopStats() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  /// Download speed counts the engine's delivered bytes, as the Swift overlay did.
  void _tick() {
    final newestToken = _sessions.containsKey(_newest) ? _newest : _sessions.keys.lastOrNull;
    final newest = _sessions[newestToken];
    if (newest == null) {
      _stopStats();
      return;
    }
    final now = MonotonicClock.system.nowMs();
    var delta = 0;
    for (final MapEntry(key: token, value: session) in _sessions.entries) {
      final delivered = session.deliveredBytes;
      delta += delivered - (_lastDelivered[token] ?? 0);
      _lastDelivered[token] = delivered;
    }
    final seconds = (now - _lastTickAt) / 1000;
    _lastTickAt = now;
    final bps = seconds > 0 ? delta / seconds : 0.0;
    _boot.events.send(_Stats(newest.stats(downloadBps: bps, transport: _transport.name, token: newestToken)));
    if (++_ticks % 30 == 0) _saveMemory();
  }

  Future<void> _dispose() async {
    _disposed = true;
    _stopStats();
    _root.cancel();
    for (final token in [..._sessions.keys, ..._directTokens, ..._localTokens]) {
      _router.unregister(token);
    }
    await _offline.dispose();
    for (final session in _sessions.values) {
      session.close();
    }
    if (_sessions.isNotEmpty) _saveMemory();
    _sessions.clear();
    _directTokens.clear();
    _localTokens.clear();
    await _server.close();
    closeTransports();
    Logger.shared.info(LogCategory.engine, 'engine stopped');
    _sink.flush();
  }
}
