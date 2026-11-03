import 'dart:convert';
import 'dart:io';

import 'package:bili_core/api.dart' show VideoCodec;
import 'package:bili_core/devlog.dart';
import 'package:bilifast/player/bili_player.dart';
import 'package:bilifast/video/player_prefs.dart';
import 'package:bilifast/video/player_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory folder;
  late String path;
  late MemorySink logs;
  late Logger logger;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('player_prefs_test');
    path = '${folder.path}${Platform.pathSeparator}player_prefs.json';
    logs = MemorySink();
    logger = Logger(session: 'test')..add(logs);
  });

  tearDown(() => folder.deleteSync(recursive: true));

  test('without a file the defaults apply: 自动连播 on, 不循环, 适应, BTR on, stats off, danmaku on, 旋转动画 '
      '自绘', () async {
    final prefs = await PlayerPrefs.load(path, logger: logger);
    expect(prefs.autoplay, isTrue);
    expect(prefs.loop, LoopMode.off);
    expect(prefs.fit, FitMode.fit);
    expect(prefs.btr, isTrue);
    expect(prefs.node, NodeChoice.auto);
    expect(prefs.showStats, isFalse);
    expect(prefs.danmakuOn, isTrue);
    expect(prefs.coinAlsoLike, isTrue);
    expect(prefs.turnTakeover, isTrue);
    expect(prefs.quality, isNull);
    expect(prefs.codec, isNull);
    expect(File(path).existsSync(), isFalse, reason: 'nothing is written until something changes');
  });

  test('legacy overseas defaults and explicit regional choices survive an upgrade', () async {
    for (final (json, expected) in [
      ('{}', NodeChoice.overseas),
      ('{"node":"overseas"}', NodeChoice.overseas),
      ('{"node":"mainland"}', NodeChoice.mainland),
      ('{"node":"auto"}', NodeChoice.auto),
    ]) {
      File(path).writeAsStringSync(json);
      final prefs = await PlayerPrefs.load(path, logger: logger);
      expect(prefs.node, expected);
      prefs.showStats = true;
      await prefs.settle();
      expect((await PlayerPrefs.load(path, logger: logger)).node, expected);
    }
  });

  test('a new install keeps Auto when another preference is saved', () async {
    final prefs = await PlayerPrefs.load(path, logger: logger)..showStats = true;
    await prefs.settle();
    expect((await PlayerPrefs.load(path, logger: logger)).node, NodeChoice.auto);
  });

  test('what is set comes back on the next launch', () async {
    final prefs = await PlayerPrefs.load(path, logger: logger);
    prefs
      ..autoplay = false
      ..loop = LoopMode.single
      ..fit = FitMode.ratio4x3
      ..btr = false
      ..showStats = true
      ..danmakuOn = false
      ..coinAlsoLike = false
      ..turnTakeover = false
      ..quality = 127
      ..codec = VideoCodec.av1;
    await prefs.settle();

    final again = await PlayerPrefs.load(path, logger: logger);
    expect(again.autoplay, isFalse);
    expect(again.loop, LoopMode.single);
    expect(again.fit, FitMode.ratio4x3);
    expect(again.btr, isFalse);
    expect(again.showStats, isTrue);
    expect(again.danmakuOn, isFalse);
    expect(again.coinAlsoLike, isFalse);
    expect(again.turnTakeover, isFalse);
    expect(again.quality, 127);
    expect(again.codec, VideoCodec.av1);
  });

  test('旋转动画 is written only as 系统; put back on 自绘 it leaves the file', () async {
    final prefs = await PlayerPrefs.load(path, logger: logger)..turnTakeover = false;
    await prefs.settle();
    expect(jsonDecode(File(path).readAsStringSync()), containsPair('turnTakeover', false));
    prefs.turnTakeover = true;
    await prefs.settle();
    final cleared = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    expect(cleared.keys.where((key) => key.startsWith('turn')), isEmpty);
    expect((await PlayerPrefs.load(path, logger: logger)).turnTakeover, isTrue);
  });

  group('旋转动画 from earlier builds', () {
    for (final (json, drawn, name) in [
      ('{"turnTakeover":false}', false, '(12) 系统'),
      ('{"turnTakeover":true}', true, '(12) 自绘'),
      ('{"turnMethod":"system"}', false, '(14) 系统'),
      ('{"turnMethod":"quietRequest","turnPicture":"fade","turnSpinStart":"afterPicture"}', true, '(14) 请求前关'),
      ('{"turnMethod":"counter","turnPicture":"none"}', true, '(13) 抵消'),
      ('{"turnMethod":"system","turnPicture":"none"}', false, '(14) 系统 with a picture'),
      ('{"turnPicture":"none"}', true, 'a (13) file without a method'),
    ]) {
      test('$json reads as ${drawn ? '自绘' : '系统'}: $name', () async {
        File(path).writeAsStringSync(json);
        final prefs = await PlayerPrefs.load(path, logger: logger);
        expect(prefs.turnTakeover, drawn);
        expect(logs.events.map((event) => event.msg), isNot(contains('player prefs value ignored')));
      });
    }

    test('the next write drops the method, picture and start, keeping 系统 as the bool', () async {
      File(path).writeAsStringSync('{"turnMethod":"system","turnPicture":"fade","turnSpinStart":"afterPicture"}');
      final prefs = await PlayerPrefs.load(path, logger: logger)..autoplay = false;
      await prefs.settle();
      final written = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      expect(written.keys.where((key) => key.startsWith('turn')), ['turnTakeover']);
      expect(written['turnTakeover'], isFalse);
      expect((await PlayerPrefs.load(path, logger: logger)).turnTakeover, isFalse);
    });

    test('a drawn method leaves nothing behind on the next write', () async {
      File(path).writeAsStringSync('{"turnMethod":"quietRequest","turnPicture":"cut","turnSpinStart":"immediate"}');
      final prefs = await PlayerPrefs.load(path, logger: logger)..autoplay = false;
      await prefs.settle();
      final written = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      expect(written.keys.where((key) => key.startsWith('turn')), isEmpty);
    });
  });

  test('a file that is not JSON is set aside and the defaults apply', () async {
    File(path).writeAsStringSync('{not json');
    final prefs = await PlayerPrefs.load(path, logger: logger);
    expect(prefs.loop, LoopMode.off);
    expect(File('$path.bad').existsSync(), isTrue);
    expect(logs.events.map((event) => event.msg), contains('player prefs unreadable, using defaults'));
    prefs.loop = LoopMode.list;
    await prefs.settle();
    expect((await PlayerPrefs.load(path, logger: logger)).loop, LoopMode.list);
  });

  test('a value of the wrong type or an unknown name falls back alone', () async {
    File(path).writeAsStringSync(
        '{"autoplay":"yes","loop":"forever","fit":"fill","quality":"high","codec":"hevc","turnTakeover":0,'
        '"turnMethod":"system"}');
    final prefs = await PlayerPrefs.load(path, logger: logger);
    expect(prefs.autoplay, isTrue);
    expect(prefs.loop, LoopMode.off);
    expect(prefs.fit, FitMode.fill);
    expect(prefs.quality, isNull);
    expect(prefs.codec, VideoCodec.hevc);
    expect(prefs.turnTakeover, isFalse, reason: 'a bool of the wrong type falls back to the method');
    final ignored = logs.events.where((event) => event.msg == 'player prefs value ignored').toList();
    expect(ignored.map((event) => event.f['key']), const [
      LogString('autoplay'),
      LogString('loop'),
      LogString('turnTakeover'),
      LogString('quality'),
    ]);
    expect(ignored.every((event) => event.level == LogLevel.warn), isTrue);
    expect(ignored.map((event) => event.f.keys.toList()), everyElement(['key']), reason: 'never the value');
  });

  test('in memory nothing touches the disk', () async {
    final prefs = PlayerPrefs.memory(logger: logger)..autoplay = false;
    await prefs.settle();
    expect(prefs.autoplay, isFalse);
    expect(folder.listSync(), isEmpty);
  });
}
