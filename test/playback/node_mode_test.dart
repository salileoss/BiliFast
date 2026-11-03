import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bili_core/engine.dart';
import 'package:bilifast/playback/codec_memory.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/playback/playback_setup.dart';
import 'package:bilifast/video/player_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_player.dart';
import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeEngine engine;
  late CodecMemory memory;
  late PlaybackController controller;

  setUp(() {
    engine = FakeEngine();
    memory = CodecMemory();
    final logger = Logger(session: 'test');
    controller = PlaybackController(
      client: BiliClient(transport: CannedHttp(), cookies: CookieJar(), logger: logger),
      engine: engine,
      player: FakePlayer(),
      codecMemory: memory,
      startTimer: FakeTimers().start,
      logger: logger,
    );
  });

  tearDown(() => controller.dispose());

  test('setNodeMode reaches the engine, and an engine that replaces it starts on the same nodes', () async {
    controller.setNodeMode(NodeMode.mainland);
    expect(engine.nodeModes.single, isA<MainlandNodes>());

    final next = FakeEngine();
    await controller.useEngine(() async => next);
    expect(next.nodeModes.single, isA<MainlandNodes>());
  });

  test('a replacement engine is left on its own nodes until one is chosen', () async {
    final next = FakeEngine();
    await controller.useEngine(() async => next);
    expect(next.nodeModes, isEmpty);
  });

  test('resetCodecMemory forgets the codecs the player refused', () {
    memory
      ..markFailed('av1')
      ..noteHEV1Entry();
    controller.resetCodecMemory();
    expect(memory.failedKinds, isEmpty);
    expect(memory.hev1LabelsHoldHEV1, isFalse);
  });

  test('the app starts its engine on the saved CDN 节点', () {
    final saved = PlayerPrefs.shared;
    addTearDown(() => PlayerPrefs.shared = saved);
    PlayerPrefs.shared = PlayerPrefs.memory();
    expect(appEngineOptions().nodeMode, isA<AutoNodes>());
    PlayerPrefs.shared.node = NodeChoice.overseas;
    expect(appEngineOptions().nodeMode, isA<OverseasNodes>());
    PlayerPrefs.shared.node = NodeChoice.mainland;
    expect(appEngineOptions().nodeMode, isA<MainlandNodes>());
    expect(appEngineOptions(config: const RipperConfig()).nodeMode, isA<MainlandNodes>(), reason: 'the speed test too');
  });

  test('the codec memory lives in the support folder as codec_memory.json', () {
    final path = codecMemoryPath();
    if (path != null) expect(path, endsWith('codec_memory.json'));
  });
}
