import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/offline/disk/background_trials.dart';
import 'package:bilifast/offline/offline_host.dart';
import 'package:bilifast/offline/offline_library.dart';
import 'package:bilifast/offline/offline_models.dart';
import 'package:bilifast/playback/codec_memory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../playback/fakes.dart';

/// The background session as a test drives it: every call recorded, takeBack answering [results] once.
final class FakeOfflineHost implements OfflineHost {
  FakeOfflineHost({this.backgroundTransfers = true});

  @override
  final bool backgroundTransfers;
  int? free = 64000000000;
  final calls = <String>[];
  final handedOff = <List<BackgroundRange>>[];
  List<BackgroundRangeResult> results = [];
  Object? handOffError;
  String? excluded;
  VoidCallback? graceEnding;
  void Function(BackgroundRangeResult result)? rangeFinished;

  @override
  Future<int?> freeBytes() async => free;

  /// What [inBackground] answers, and how often it was asked.
  bool background = false;
  int backgroundAsks = 0;

  @override
  Future<bool> inBackground() async {
    backgroundAsks += 1;
    return background;
  }

  @override
  Future<void> excludeFromBackup(String path) async => excluded = path;

  @override
  Future<void> beginGrace() async => calls.add('beginGrace');

  @override
  Future<void> endGrace() async => calls.add('endGrace');

  @override
  set onGraceEnding(VoidCallback? callback) => graceEnding = callback;

  /// The connections asked for with each hand-off.
  final handOffConnections = <int>[];

  @override
  Future<void> handOff(List<BackgroundRange> ranges, {int connections = OfflineHost.defaultConnections}) async {
    calls.add('handOff');
    handOffConnections.add(connections);
    if (handOffError case final error?) throw error;
    handedOff.add(ranges);
  }

  /// Holds takeBack until completed, as the real one waits for the session to deliver.
  Completer<void>? takeBackHeld;

  /// Thrown by [takeBack] while set.
  Object? takeBackError;

  @override
  Future<List<BackgroundRangeResult>> takeBack() async {
    calls.add('takeBack');
    await takeBackHeld?.future;
    if (takeBackError case final error?) throw error;
    final taken = results;
    results = [];
    return taken;
  }

  @override
  set onRangeFinished(void Function(BackgroundRangeResult result)? callback) => rangeFinished = callback;

  @override
  bool continuedProcessing = false;

  /// What [beginContinued] answers: null takes the request.
  String? continuedRefusal;

  /// Thrown by [beginContinued] while set.
  Object? continuedError;
  VoidCallback? continuedStarted;
  void Function(bool locked)? continuedEnded;
  final continuedBegun = <({String title, String subtitle})>[];
  final continuedUpdates = <({int done, int total, String subtitle})>[];

  /// Runs as [endContinued] is called, for what a test checks at that moment.
  VoidCallback? endingContinued;

  @override
  Future<String?> beginContinued({required String title, required String subtitle}) async {
    calls.add('beginContinued');
    continuedBegun.add((title: title, subtitle: subtitle));
    if (continuedError case final error?) throw error;
    return continuedRefusal;
  }

  @override
  Future<void> updateContinued({required int done, required int total, required String subtitle}) async =>
      continuedUpdates.add((done: done, total: total, subtitle: subtitle));

  @override
  Future<void> endContinued({required bool success}) async {
    calls.add('endContinued $success');
    endingContinued?.call();
  }

  @override
  set onContinuedStarted(VoidCallback? callback) => continuedStarted = callback;

  @override
  set onContinuedEnded(void Function(bool locked)? callback) => continuedEnded = callback;
}

/// Trials whose choice a test sets: the continued arm whenever continued processing runs (or [whileContinued]), else
/// [handOff], which is also the fallback. Every choice's `continued` and every trip recorded are kept.
final class PinnedTrials extends BackgroundTrials {
  PinnedTrials({this.handOff = BackgroundArm.fallback, this.whileContinued});

  BackgroundArm handOff;
  BackgroundArm? whileContinued;
  final asked = <bool>[];
  final recorded = <BackgroundTrip>[];

  @override
  BackgroundChoice choose({required bool continued}) {
    asked.add(continued);
    return (arm: continued ? whileContinued ?? BackgroundArm.continuedArm : handOff, why: 'pinned');
  }

  @override
  BackgroundArm bestHandOff() => handOff;

  @override
  void record(BackgroundTrip trip) {
    recorded.add(trip);
    super.record(trip);
  }
}

const toBackground = [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused];
const toForeground = [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed];

void lifecycle(List<AppLifecycleState> states) {
  for (final state in states) {
    // ignore: invalid_use_of_protected_member
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);
  }
}

OfflineRequest offlineRequest({
  int cid = 137649199,
  String bvid = 'BV1GJ411x7h7',
  int duration = 712,
  String title = '测试视频',
}) => OfflineRequest(
  bvid: bvid,
  aid: 80433022,
  cid: cid,
  title: title,
  duration: duration,
  cover: 'http://i0.hdslb.com/bfs/archive/cover$cid.jpg',
  ownerMid: 1,
  ownerName: 'UP主',
  ownerFace: 'https://i1.hdslb.com/bfs/face/face.jpg',
);

/// One library on a temporary folder, with the canned API, a fake engine and host, and the pictures answered from
/// memory. [reopen] makes another on the same folder, as a relaunch would.
final class Rig {
  Rig({FakeOfflineHost? host, CodecMemory? memory, this.danmakuGap = Duration.zero})
    : host = host ?? FakeOfflineHost(),
      memory = memory ?? CodecMemory(),
      folder = Directory.systemTemp.createTempSync('offline_test').path;

  final String folder;
  final Duration danmakuGap;
  final FakeOfflineHost host;
  final CodecMemory memory;
  final http = Canned.http();
  var engine = FakeEngine();
  final logs = MemorySink();
  final pictureUrls = <Uri>[];
  final libraries = <DiskOfflineLibrary>[];

  /// Each library's trials; pinned, so no test leans on how the real choice explores.
  BackgroundTrials Function() trials = PinnedTrials.new;
  Duration continuedStartWait = const Duration(seconds: 5);
  Duration continuedUpdateGap = const Duration(seconds: 2);
  Duration awayProgressGap = const Duration(seconds: 30);
  int? Function()? accountMid;
  int Function()? accountGeneration;

  /// The signed URLs are good for two more hours.
  DateTime now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 7200) * 1000);

  late final Logger logger = Logger(session: 'test')..add(logs);
  late final BiliClient client = BiliClient(
    transport: http,
    cookies: CookieJar(Canned.cookies),
    now: () => now,
    logger: logger,
  );

  DiskOfflineLibrary make() {
    final library = DiskOfflineLibrary(
      folder: folder,
      client: () => client,
      engine: () async => engine,
      host: host,
      codecMemory: memory,
      trials: trials(),
      logger: logger,
      pictures: (url) async {
        pictureUrls.add(url);
        return Uint8List.fromList(utf8.encode('picture'));
      },
      now: () => now,
      danmakuGap: danmakuGap,
      retryGaps: const [Duration.zero],
      continuedStartWait: continuedStartWait,
      continuedUpdateGap: continuedUpdateGap,
      awayProgressGap: awayProgressGap,
      accountMid: accountMid,
      accountGeneration: accountGeneration,
    );
    libraries.add(library);
    return library;
  }

  Future<DiskOfflineLibrary> started() async {
    final library = make();
    await library.start();
    await library.settled();
    return library;
  }

  String part(int cid) => '$folder${Platform.pathSeparator}$cid';
  String file(int cid, String name) => '${part(cid)}${Platform.pathSeparator}$name';

  Map<String, Object?> entry(int cid) =>
      jsonDecode(File(file(cid, 'entry.json')).readAsStringSync()) as Map<String, Object?>;

  /// Every log line's fields, for checks that no address reached the log.
  String get logText => logs.events.map((event) => jsonEncode(event.toJson())).join('\n');

  /// Disposes [library] as the app's end would; the rest go in [dispose].
  void close(DiskOfflineLibrary library) {
    libraries.remove(library);
    library.dispose();
  }

  void dispose() {
    for (final library in libraries) {
      library.dispose();
    }
    libraries.clear();
    try {
      Directory(folder).deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a file a moment longer; the temp folder is the OS's to clear.
    }
  }
}
