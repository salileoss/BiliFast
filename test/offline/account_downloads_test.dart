import 'dart:async';

import 'package:bilifast/offline/offline_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../playback/fakes.dart';
import 'disk_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Rig rig;
  int? active;
  var generation = 0;

  setUp(() {
    active = 101;
    generation = 0;
    rig = Rig();
    rig.accountMid = () => active;
    rig.accountGeneration = () => generation;
  });
  tearDown(() => rig.dispose());

  test('switch pauses and persists the owner; B cannot resume A\'s unfinished part', () async {
    final library = await rig.started();
    await library.enqueue([offlineRequest(cid: 1)]);
    await library.settled();
    expect(rig.entry(1)['ownerMid'], 101);
    await library.accountWillChange();
    active = 202;
    generation++;
    rig.client.invalidateSession();
    final started = rig.engine.downloadsStarted.length;
    expect(library.item(1)!.state, OfflineState.paused);
    expect(library.canResume(1), isFalse);
    library.resume(1);
    library.startAll();
    await library.settled();
    expect(rig.engine.downloadsStarted, hasLength(started));
    expect(rig.entry(1)['state'], 'paused');
    expect(rig.entry(1)['ownerMid'], 101);
    active = 101;
    generation++;
    rig.client.invalidateSession();
    expect(library.canResume(1), isTrue);
    library.resume(1);
    await library.settled();
    expect(rig.engine.downloadsStarted, hasLength(started + 1));
  });

  test('restart under another account does not auto-start the old owner\'s queue', () async {
    final first = await rig.started();
    await first.enqueue([offlineRequest(cid: 1)]);
    await first.settled();
    rig.close(first);
    active = 202;
    generation++;
    rig.client.invalidateSession();
    final before = rig.engine.downloadsStarted.length;
    final reopened = await rig.started();
    expect(reopened.item(1)!.state, OfflineState.paused);
    expect(reopened.canResume(1), isFalse);
    expect(rig.engine.downloadsStarted, hasLength(before));
  });

  test('a guest download is owned by guest mode and cannot resume as B', () async {
    active = null;
    final library = await rig.started();
    await library.enqueue([offlineRequest(cid: 1)]);
    await library.settled();
    expect(rig.entry(1)['ownerKnown'], isTrue);
    expect(rig.entry(1)['ownerMid'], isNull);
    await library.accountWillChange();
    active = 202;
    generation++;
    expect(library.canResume(1), isFalse);
  });

  test('native cancellation is awaited before account handoff can finish', () async {
    final library = await rig.started();
    await library.enqueue([offlineRequest(cid: 1)]);
    await library.settled();
    final gate = rig.host.takeBackHeld = Completer<void>();
    var changed = false;
    final changing = library.accountWillChange().then((_) => changed = true);
    await pumpEventQueue();
    expect(changed, isFalse);
    expect(library.item(1)!.state, OfflineState.paused);
    expect(library.canResume(1), isFalse);
    gate.complete();
    await changing;
    expect(changed, isTrue);
  });

  test('failed native cancellation prevents credential publication', () async {
    final library = await rig.started();
    rig.host.takeBackError = StateError('fixture-native-failure');
    await expectLater(library.accountWillChange(), throwsStateError);
    expect(active, 101);
  });

  test('a playurl waiting on signing does not send after A is suspended', () async {
    final library = await rig.started();
    final original = rig.client;
    final gate = rig.http.gates[Canned.navPath] = Completer<void>();
    await library.enqueue([offlineRequest(cid: 1)]);
    for (var i = 0; i < 100 && rig.http.to(Canned.navPath).isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(rig.http.to(Canned.navPath), hasLength(1));
    await library.accountWillChange();
    active = 202;
    generation++;
    original.invalidateSession();
    gate.complete();
    await library.settled();
    expect(library.item(1)!.state, OfflineState.paused);
    final afterSwitch = rig.http.to(Canned.playUrlPath).length;
    library.resume(1);
    await library.settled();
    expect(rig.http.to(Canned.playUrlPath), hasLength(afterSwitch));
    expect(afterSwitch, 0);
  });
}
