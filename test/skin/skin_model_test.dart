import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/skin/fake_skin_api.dart';
import 'package:bilifast/skin/skin.dart';
import 'package:bilifast/skin/skin_loading.dart';
import 'package:bilifast/skin/skin_model.dart';
import 'package:bilifast/skin/skin_package.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

/// The account half [SkinModel] follows: the test sets the account and counts the logins.
class _Environment extends ChangeNotifier implements AppEnvironment {
  _Environment(this._account);

  Account _account;

  @override
  Account get account => _account;

  set account(Account value) {
    _account = value;
    notifyListeners();
  }

  @override
  final _Logins logins = _Logins();

  @override
  int? mid = 1;

  /// How many listeners were added, so a model can be shown to listen to nothing before it starts.
  int listening = 0;

  @override
  void addListener(VoidCallback listener) {
    listening++;
    super.addListener(listener);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Logins extends ValueNotifier<int> {
  _Logins() : super(0);

  int listening = 0;

  @override
  void addListener(VoidCallback listener) {
    listening++;
    super.addListener(listener);
  }
}

/// A stand-in as other pages' tests make one: a fixed value, a refresh that asks nothing.
class _FixedSkinModel extends SkinModel {
  _FixedSkinModel(this._skin, {required super.environment}) : super(api: FakeSkinApi(), folder: null);

  Skin? _skin;
  int refreshes = 0;

  @override
  Skin? get value => _skin;

  set skin(Skin? skin) {
    _skin = skin;
    notifyListeners();
  }

  @override
  Future<void> refresh() async => refreshes++;
}

/// A transport error whose words end with the request's URL, as dart:io's do.
class _TransportError implements Exception {
  @override
  String toString() => 'HttpException: Connection closed, uri = https://i0.hdslb.com/bfs/garb/secret.zip';
}

const loggedIn = LoggedIn(name: 'test', vip: false);
const packageUrl = 'https://i0.hdslb.com/bfs/garb/zip/7.zip';
const colors = SkinColors(color: 0xFFFFFFFF, lightText: true, tailColor: 0xFF101010, tailColorSelected: 0xFFFF0000);

Uint8List zipOf(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final MapEntry(key: name, value: bytes) in entries.entries) {
    archive.add(ArchiveFile.bytes(name, bytes));
  }
  // Without a time every entry is stamped now, so the same package built a second later has another md5.
  return ZipEncoder().encodeBytes(archive, modified: DateTime(2026, 10, 22));
}

/// A package with every picture role, its bytes telling [ver] apart.
Uint8List packageFor(int ver) => zipOf({
  'head_bg.png': [1, ver],
  'head_tab_bg.png': [2, ver],
  'head_myself_bg.png': [3, ver],
  'tail_bg.webp': [4, ver],
  for (final tab in SkinNames.tabs) ...{
    'tail_icon_$tab.png': [5, ver],
    'tail_icon_selected_$tab.svga': [6, ver],
  },
});

SkinEquip equipFor(
  List<int> package, {
  int id = 7,
  int ver = 1,
  String url = packageUrl,
  String? md5Text,
  SkinColors palette = colors,
}) => SkinEquip(
  id: id,
  name: 'skin $id',
  ver: ver,
  packageUrl: url,
  packageMd5: md5Text ?? md5.convert(package).toString(),
  colors: palette,
);

/// A stand-in picture of one colour, drawn here.
Future<Uint8List> solidPng(Color color, int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

String nameOf(FileSystemEntity entity) => entity.path.split(RegExp(r'[\\/]')).last;

/// What the client throws for an answer [SkinEquip.fromJson] refuses.
BiliError decodingError(Map<String, Object?> data) {
  try {
    SkinEquip.fromJson(data);
  } on DecodeError catch (error) {
    return BiliError.decoding('$error');
  }
  throw StateError('$data decodes');
}

/// Real file work finishes on the event loop, not within a pump of it.
Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory folder;
  late MemorySink sink;
  late Logger logger;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('skin_model_test');
    addTearDown(() => folder.delete(recursive: true));
    sink = MemorySink();
    logger = Logger(session: 'test')..add(sink);
  });

  ({SkinModel model, _Environment environment}) make(FakeSkinApi api, {Account account = loggedIn, ValueListenable<ThemeMode>? appearance}) {
    final environment = _Environment(account);
    final model = SkinModel(api: api, environment: environment, folder: folder.path, logger: logger, appearance: appearance);
    addTearDown(() async {
      model.dispose();
      await model.settle();
    });
    return (model: model, environment: environment);
  }

  FakeSkinApi apiWith(int ver, {int id = 7}) {
    final package = packageFor(ver);
    return FakeSkinApi(
      equip: equipFor(package, id: id, ver: ver),
      package: package,
    );
  }

  /// Starts [model] and lets the check it starts finish.
  Future<void> settle(SkinModel model) async {
    await model.start();
    await model.refresh();
  }

  Iterable<LogEvent> logged(String message) => sink.events.where((event) => event.msg == message);

  String allLogText() => sink.events.map((event) => event.encode()).join('\n');

  /// The unpacked folders of [id]'s version [ver], one per package.
  List<Directory> versionFolders(int id, int ver) {
    final skin = Directory('${folder.path}/$id');
    if (!skin.existsSync()) return const [];
    return skin.listSync().whereType<Directory>().where((each) => nameOf(each).startsWith('$ver-')).toList();
  }

  bool versionExists(int id, int ver) => versionFolders(id, ver).isNotEmpty;

  test('logged in, it downloads, checks and unpacks the package and shows it', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    var notified = 0;
    model.addListener(() => notified++);
    await settle(model);

    final skin = model.value!;
    expect(api.calls, ['equipped', 'download']);
    expect(skin.equip.id, 7);
    expect(skin.headBg!.readAsBytesSync(), [1, 1]);
    expect(skin.headMyself!.path, endsWith('head_myself_bg.png'));
    expect(skin.tailIcons, hasLength(5));
    expect(skin.tailIconsSelected.every((icon) => icon.animated), isTrue);
    expect(skin.themesBar, isTrue);
    expect(notified, 1);
    expect(versionExists(7, 1), isTrue);
    expect(File('${folder.path}/current.json').existsSync(), isTrue);
  });

  test('a launch shows the cached skin at once, before the check answers', () async {
    await settle(make(apiWith(1)).model);

    final api = apiWith(1);
    final hold = api.holds['equipped'] = Completer<void>();
    final (:model, environment: _) = make(api);
    await model.start();
    expect(model.value, isNotNull, reason: 'shown from the cache while the check is out:\n${allLogText()}');
    expect(model.value!.equip.ver, 1);
    expect(model.value!.equip.colors.tailColorSelected, colors.tailColorSelected);
    expect(model.value!.tailIcons, hasLength(5));
    expect(logged('skin').last.f['from'], const LogString('cache'));
    await pumpEventQueue();
    expect(api.calls, ['equipped']);

    hold.complete();
    await model.refresh();
    expect(api.calls, ['equipped'], reason: 'the same version is on disk already');
  });

  test('an unknown account shows the cache and waits; logged in, it asks', () async {
    await settle(make(apiWith(1)).model);

    final api = apiWith(1);
    final (:model, :environment) = make(api, account: const AccountUnknown());
    await model.start();
    expect(model.value, isNotNull);
    await pumpEventQueue();
    expect(api.calls, isEmpty);

    environment.account = loggedIn;
    await model.refresh();
    expect(api.calls, ['equipped']);
  });

  test('a launch already logged out starts stock, the cache unread into view', () async {
    await settle(make(apiWith(1)).model);

    final api = apiWith(1);
    final (:model, environment: _) = make(api, account: const LoggedOut());
    await model.start();
    await pumpEventQueue();
    expect(model.value, isNull);
    expect(api.calls, isEmpty);
  });

  test('every login asks again; a login from logged out asks once', () async {
    final api = apiWith(1);
    final (:model, :environment) = make(api);
    await settle(model);
    expect(api.calls, ['equipped', 'download']);

    environment.logins.value++;
    await model.refresh();
    expect(api.calls, ['equipped', 'download', 'equipped']);

    environment.account = const LoggedOut();
    environment.account = const AccountUnknown();
    environment.account = loggedIn;
    environment.logins.value++;
    await model.refresh();
    expect(api.calls, ['equipped', 'download', 'equipped', 'equipped']);
    expect(model.value, isNotNull);
  });

  test("another account logging in over this one drops this one's skin before its own token is there", () async {
    final api = apiWith(1);
    final (:model, :environment) = make(api);
    await settle(model);
    expect(model.value, isNotNull);

    environment.logins.value++;
    await model.refresh();
    expect(model.value, isNotNull, reason: 'the same account logging in again keeps its skin');

    api.failures['equipped'] = BiliError.noAppToken;
    environment.mid = 2;
    environment.logins.value++;
    await model.refresh();
    expect(model.value, isNull);
  });

  test('logging out shows stock and keeps the files; the next launch starts stock, a login reuses them', () async {
    final api = apiWith(1);
    final (:model, :environment) = make(api);
    await settle(model);

    environment.account = const LoggedOut();
    expect(model.value, isNull);
    await model.settle();
    expect(versionExists(7, 1), isTrue, reason: 'the files stay');

    final next = make(apiWith(1), account: const AccountUnknown());
    await next.model.start();
    expect(next.model.value, isNull, reason: 'a logged-out launch never flashes the old account\'s skin');

    environment.account = loggedIn;
    await model.refresh();
    expect(model.value, isNotNull);
    expect(api.calls, ['equipped', 'download', 'equipped'], reason: 'unpacked already, nothing downloaded');
  });

  test('a login Bilibili no longer accepts shows stock too', () async {
    final (:model, :environment) = make(apiWith(1));
    await settle(model);
    environment.account = const LoginExpired();
    expect(model.value, isNull);
  });

  test('an answer for the account before a logout never shows', () async {
    final api = apiWith(1);
    final hold = api.holds['equipped'] = Completer<void>();
    final (:model, :environment) = make(api);
    await model.start();
    final check = model.refresh();
    await pumpEventQueue();
    environment.account = const LoggedOut();
    hold.complete();
    await check;
    expect(model.value, isNull);
    expect(api.calls, ['equipped'], reason: 'nothing downloaded for an account that left');
  });

  test('nothing equipped: stock, remembered for the next launch, the unpacked versions deleted', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);

    api.equip = null;
    await model.refresh();
    expect(model.value, isNull);
    expect(Directory('${folder.path}/7').existsSync(), isFalse);
    expect(logged('skin stays stock').last.f['reason'], const LogString('none equipped'));

    final next = make(FakeSkinApi(), account: const AccountUnknown());
    await next.model.start();
    expect(next.model.value, isNull);
  });

  test('without the app token it keeps what is shown and says so once', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    final shown = model.value;

    api.failures['equipped'] = BiliError.noAppToken;
    await model.refresh();
    await model.refresh();
    expect(model.value, same(shown));
    expect(sink.events.where((event) => event.msg.contains('app token')), hasLength(1));
  });

  test('a failed check or download keeps what is shown, and the log never carries the URL', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    final shown = model.value;

    api.failures['equipped'] = const BiliError.network('SocketException');
    await model.refresh();
    expect(model.value, same(shown));
    expect(logged('skin check failed, keeping what is shown'), hasLength(1));

    api.failures.remove('equipped');
    final newer = packageFor(2);
    api
      ..equip = equipFor(newer, ver: 2)
      ..package = newer
      ..failures['download'] = _TransportError();
    await model.refresh();
    expect(model.value, same(shown));
    expect(logged('skin not installed, keeping what is shown').single.f['error'], const LogString('_TransportError'));
    expect(allLogText(), isNot(contains('hdslb')));
    expect(allLogText(), isNot(contains('secret')));
    expect(versionExists(7, 1), isTrue);
    expect(versionExists(7, 2), isFalse);
  });

  test('a package whose md5 does not match is refused and nothing is unpacked', () async {
    final package = packageFor(1);
    final api = FakeSkinApi(
      equip: equipFor(package, md5Text: md5.convert([0]).toString()),
      package: package,
    );
    final (:model, environment: _) = make(api);
    await settle(model);
    expect(model.value, isNull);
    expect(api.calls, ['equipped', 'download']);
    expect(logged('skin not installed, keeping what is shown').single.f['error'], const LogString('md5 mismatch'));
    expect(Directory('${folder.path}/7').existsSync() && Directory('${folder.path}/7').listSync().isNotEmpty, isFalse);
  });

  test('an md5 in capitals matches', () async {
    final package = packageFor(1);
    final api = FakeSkinApi(
      equip: equipFor(package, md5Text: md5.convert(package).toString().toUpperCase()),
      package: package,
    );
    final (:model, environment: _) = make(api);
    await settle(model);
    expect(model.value, isNotNull);
  });

  test('a version unpacked already is reused without a download', () async {
    await settle(make(apiWith(1)).model);
    File('${folder.path}/current.json').deleteSync();

    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    expect(model.value, isNotNull);
    expect(api.calls, ['equipped']);
    expect(logged('skin').last.f['from'], const LogString('unpacked'));
  });

  test('a half-written version is unpacked again', () async {
    await settle(make(apiWith(1)).model);
    File('${folder.path}/current.json').deleteSync();
    File('${versionFolders(7, 1).single.path}/.skin.json').deleteSync();

    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    expect(model.value, isNotNull);
    expect(api.calls, ['equipped', 'download']);
  });

  test('a new version replaces the old, whose files are deleted', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);

    final newer = packageFor(2);
    api
      ..equip = equipFor(newer, ver: 2)
      ..package = newer;
    await model.refresh();
    expect(model.value!.equip.ver, 2);
    expect(model.value!.headBg!.readAsBytesSync(), [1, 2]);
    expect(versionExists(7, 1), isFalse);
    expect(versionExists(7, 2), isTrue);

    final other = packageFor(3);
    api
      ..equip = equipFor(other, id: 8, ver: 3)
      ..package = other;
    await model.refresh();
    expect(model.value!.equip.id, 8);
    expect(folder.listSync().map(nameOf).toSet(), {'8', 'current.json'});
  });

  test('a package changed under the same version unpacks beside the shown one, which then goes', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    final before = model.value!.headBg!.path;

    final changed = zipOf({
      'head_bg.png': [9, 9],
    });
    api
      ..equip = equipFor(changed)
      ..package = changed;
    await model.refresh();
    expect(model.value!.headBg!.readAsBytesSync(), [9, 9]);
    expect(model.value!.headBg!.path, isNot(before));
    expect(File(before).existsSync(), isFalse);
    expect(versionFolders(7, 1), hasLength(1));
  });

  test('a changed colour on the same version shows without a download', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    final package = api.package;
    api.equip = SkinEquip(
      id: 7,
      name: 'skin 7',
      ver: 1,
      packageUrl: packageUrl,
      packageMd5: md5.convert(package).toString(),
      colors: const SkinColors(color: 0xFF00FF00),
    );
    await model.refresh();
    expect(model.value!.equip.colors.color, 0xFF00FF00);
    expect(api.calls, ['equipped', 'download', 'equipped']);
  });

  test(
    'a package off Bilibili\'s CDN, or over plain http, is never downloaded; the log names scheme and host',
    () async {
      for (final url in ['https://example.com/7.zip?sign=secret', 'http://i0.hdslb.com/7.zip']) {
        final package = packageFor(1);
        final api = FakeSkinApi(
          equip: equipFor(package, url: url),
          package: package,
        );
        final (:model, environment: _) = make(api);
        await settle(model);
        expect(model.value, isNull, reason: url);
        expect(api.calls, ['equipped'], reason: url);
      }
      expect(logged('skin not installed, keeping what is shown').map((event) => event.f['error']), [
        const LogString('package host not allowed: https://example.com'),
        const LogString('package host not allowed: http://i0.hdslb.com'),
      ]);
      expect(allLogText(), isNot(contains('7.zip')));
      expect(allLogText(), isNot(contains('secret')));
    },
  );

  test('a download past 40 MB is refused', () async {
    final api = apiWith(1)..package = Uint8List(SkinLimits.packageBytes + 1);
    final (:model, environment: _) = make(api);
    await settle(model);
    expect(model.value, isNull);
    expect(logged('skin not installed, keeping what is shown').single.f['error'], const LogString('package too large'));
  });

  test('an answer it does not understand keeps the skin, its files and current.json, naming only keys', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    final shown = model.value;
    final current = File('${folder.path}/current.json').readAsStringSync();

    api.failures['equipped'] = decodingError({
      'user_equip': {'id': 7, 'name': 'skin 7', 'ver': 2},
    });
    await model.refresh();
    await model.settle();
    expect(model.value, same(shown));
    expect(versionExists(7, 1), isTrue);
    expect(File('${folder.path}/current.json').readAsStringSync(), current);
    expect(logged('skin stays stock'), isEmpty);
    expect(
      logged('skin answer not understood, keeping what is shown').single.f['reason'],
      const LogString('DecodeError: skin: user_equip has no package_url (user_equip keys: id, name, ver)'),
    );
  });

  test('a package without an md5 is refused before it is downloaded', () async {
    final package = packageFor(1);
    final api = FakeSkinApi(
      equip: equipFor(package, md5Text: ' '),
      package: package,
    );
    final (:model, environment: _) = make(api);
    await settle(model);
    expect(model.value, isNull);
    expect(api.calls, ['equipped']);
    expect(logged('skin not installed, keeping what is shown').single.f['error'], const LogString('no md5 in answer'));
  });

  test('a bug goes to the crash log with its stack and keeps what is shown', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    final shown = model.value;

    api.failures['equipped'] = StateError('a bug');
    await expectLater(model.refresh(), completes);
    expect(model.value, same(shown));

    final newer = packageFor(2);
    api
      ..failures.clear()
      ..equip = equipFor(newer, ver: 2)
      ..package = newer
      ..failures['download'] = RangeError('another bug');
    await expectLater(model.refresh(), completes);
    expect(model.value, same(shown));

    final crashes = logged('crash').where((event) => event.f['part'] == const LogInt(1)).toList();
    expect(crashes.map((event) => event.f['error']), [
      const LogString('Bad state: a bug'),
      const LogString('RangeError: another bug'),
    ]);
    expect(crashes.map((event) => event.f['source']), everyElement(const LogString('skin refresh')));
    expect(crashes.every((event) => (event.f['stack']! as LogString).value.isNotEmpty), isTrue);
    expect(logged('skin check failed, keeping what is shown'), isEmpty);
    expect(logged('skin not installed, keeping what is shown'), isEmpty);

    api.failures.clear();
    await model.refresh();
    expect(model.value!.equip.ver, 2, reason: 'a bug is not remembered as a bad package');
  });

  test('a package that failed is not fetched again this run, until the equip names another', () async {
    final package = packageFor(1);
    final api = FakeSkinApi(
      equip: equipFor(package, md5Text: md5.convert([0]).toString()),
      package: package,
    );
    final (:model, environment: _) = make(api);
    await settle(model);
    await model.refresh();
    expect(api.calls, ['equipped', 'download', 'equipped'], reason: 'the same id, version and md5');
    expect(
      logged('skin not installed, keeping what is shown').last.f['reason'],
      const LogString('failed earlier this run'),
    );

    api.equip = equipFor(package);
    await model.refresh();
    expect(api.calls, ['equipped', 'download', 'equipped', 'equipped', 'download']);
    expect(model.value, isNotNull);

    final newer = packageFor(2);
    api
      ..equip = equipFor(newer, ver: 2)
      ..package = newer
      ..failures['download'] = const SkinPackageError('download answered 404');
    await model.refresh();
    await model.refresh();
    expect(api.calls.where((call) => call == 'download'), hasLength(3), reason: 'a 404 is kept too');
  });

  test('a timeout or a dropped connection is tried again at the next refresh', () async {
    final api = apiWith(1)..failures['download'] = const SkinPackageError('download timed out', passing: true);
    final (:model, environment: _) = make(api);
    await settle(model);
    api.failures['download'] = _TransportError();
    await model.refresh();
    api.failures.remove('download');
    await model.refresh();
    expect(api.calls, ['equipped', 'download', 'equipped', 'download', 'equipped', 'download']);
    expect(model.value, isNotNull);
  });

  test('a logout during a download writes none at once; the download is then dropped', () async {
    final api = apiWith(1);
    final hold = api.holds['download'] = Completer<void>();
    final (:model, :environment) = make(api);
    await model.start();
    final check = model.refresh();
    await until(() => api.calls.contains('download'));

    environment.account = const LoggedOut();
    await model.settle().timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('the write waited for the download'),
    );
    expect(jsonDecode(File('${folder.path}/current.json').readAsStringSync()), {'equip': null});

    hold.complete();
    await check;
    await model.settle();
    expect(model.value, isNull);
    expect(versionExists(7, 1), isFalse, reason: 'nothing unpacked for an account that left');
    expect(jsonDecode(File('${folder.path}/current.json').readAsStringSync()), {'equip': null});
  });

  test('an unchanged skin still deletes versions an earlier refresh could not', () async {
    final api = apiWith(1);
    final (:model, environment: _) = make(api);
    await settle(model);
    final leftover = Directory('${folder.path}/7/0-00000000')..createSync(recursive: true);
    File('${leftover.path}/head_bg.png').writeAsBytesSync([1]);
    Directory('${folder.path}/6/1-11111111').createSync(recursive: true);

    await model.refresh();
    expect(api.calls, ['equipped', 'download', 'equipped']);
    expect(leftover.existsSync(), isFalse);
    expect(Directory('${folder.path}/6').existsSync(), isFalse);
    expect(versionExists(7, 1), isTrue);
    expect(model.value!.headBg!.existsSync(), isTrue);
  });

  test('an unknown launch shows the cache; a check that answers logged out goes stock, writes none, and the next '
      'launch starts stock', () async {
    await settle(make(apiWith(1)).model);

    final api = apiWith(1);
    final (:model, :environment) = make(api, account: const AccountUnknown());
    await model.start();
    expect(model.value, isNotNull);

    environment.account = const LoggedOut();
    expect(model.value, isNull);
    await model.settle();
    expect(jsonDecode(File('${folder.path}/current.json').readAsStringSync()), {'equip': null});
    expect(logged('skin stays stock').last.f['reason'], const LogString('logged out'));
    expect(versionExists(7, 1), isTrue, reason: 'the files stay for the next login');
    expect(api.calls, isEmpty);

    final next = make(apiWith(1), account: const AccountUnknown());
    await next.model.start();
    expect(next.model.value, isNull);
  });

  test('files of a role\'s name it cannot draw are logged once by name', () async {
    final package = zipOf({
      'head_bg.gif': [1],
      'tail_bg.png': [2],
      'head_myself_mp4_bg.webm': [3],
    });
    final api = FakeSkinApi(equip: equipFor(package), package: package);
    final (:model, environment: _) = make(api);
    await settle(model);
    expect(model.value!.headBg, isNull);
    expect(model.value!.tailBg, isNotNull);
    expect(
      logged('skin files skipped').single.f['skipped'],
      const LogString('head_bg.gif: not a picture, head_myself_mp4_bg.webm: not a video'),
    );

    final next = make(FakeSkinApi(), account: const AccountUnknown());
    await next.model.start();
    expect(next.model.value!.headBg, isNull, reason: 'the cache resolves the same way');
  });

  test('a second refresh while one is out joins it', () async {
    final api = apiWith(1);
    final hold = api.holds['equipped'] = Completer<void>();
    final (:model, environment: _) = make(api, account: const AccountUnknown());
    await model.start();
    final first = model.refresh();
    final second = model.refresh();
    expect(identical(first, second), isTrue);
    hold.complete();
    await Future.wait([first, second]);
    expect(api.calls, ['equipped', 'download']);
  });

  test('the log names the skin, its colours and every file with extension and size, once', () async {
    final (:model, :environment) = make(apiWith(1));
    await settle(model);
    environment.logins.value++;
    await model.refresh();

    final event = logged('skin').single;
    expect(event.f['id'], const LogInt(7));
    expect(event.f['ver'], const LogInt(1));
    expect(event.f['name'], const LogString('skin 7'));
    expect(event.f['primaryOnly'], const LogBool(false));
    expect(event.f['lightText'], const LogBool(true));
    expect(event.f['tailColorSelected'], const LogString('#ffff0000'));
    expect(event.f['bar'], const LogString('themed'));
    final files = (event.f['files']! as LogString).value;
    expect(files, contains('head_bg png 2'));
    expect(files, contains('tail_bg webp 2'));
    expect(files, contains('tail_icon_selected_main svga 2'));
    expect(allLogText(), isNot(contains('hdslb')));
  });

  test('made, it listens to nothing and asks nothing until start', () async {
    final api = apiWith(1);
    final (:model, :environment) = make(api);
    await pumpEventQueue();
    expect(environment.listening, 0);
    expect(environment.logins.listening, 0);
    expect(api.calls, isEmpty);
    expect(model.value, isNull);

    await settle(model);
    expect(environment.listening, 1);
    expect(environment.logins.listening, 1);
  });

  test('a subclass can stand in with its own value and refresh', () async {
    final environment = _Environment(loggedIn);
    final model = _FixedSkinModel(null, environment: environment);
    addTearDown(model.dispose);
    var notified = 0;
    model.addListener(() => notified++);
    final skin = Skin(equip: equipFor(const [1]));
    model.skin = skin;
    await model.refresh();
    expect(model.value, same(skin));
    expect(notified, 1);
    expect(model.refreshes, 1);
    expect(environment.listening, 0);
  });

  test('refresh never throws, even when nothing can be written', () async {
    final blocked = File('${folder.path}/blocked')..writeAsStringSync('a file where the folder should be');
    final api = apiWith(1);
    final environment = _Environment(loggedIn);
    final model = SkinModel(api: api, environment: environment, folder: blocked.path, logger: logger);
    addTearDown(model.dispose);
    await model.start();
    await expectLater(model.refresh(), completes);
    expect(model.value, isNull);

    api.equip = null;
    await expectLater(model.refresh(), completes);
    expect(model.value, isNull);
  });

  test('a cache that can\'t be read starts stock', () async {
    File('${folder.path}/current.json').writeAsStringSync('{not json');
    final (:model, environment: _) = make(FakeSkinApi(), account: const AccountUnknown());
    await model.start();
    expect(model.value, isNull);
    expect(logged('skin stays stock').single.f['reason'], const LogString('cache unreadable'));

    File('${folder.path}/current.json').writeAsStringSync(
      jsonEncode({
        'equip': {'id': 7},
      }),
    );
    final next = make(FakeSkinApi(), account: const AccountUnknown());
    await next.model.start();
    expect(next.model.value, isNull);
  });

  test('the demo package resolves every picture role but the video, at the official sizes', () async {
    final api = FakeSkinApi.demo();
    final (:model, environment: _) = make(api);
    await settle(model);

    final skin = model.value!;
    expect(api.calls, unorderedEquals(['equipped', 'download', 'loading']));
    final loading = model.loading.value!;
    expect((loading.format, loading.frames, loading.width, loading.height), (SkinLoadingFormat.gif, 8, 144, 144));
    expect(skin.equip.colors.lightText, isTrue);
    expect(skin.themesBar, isTrue);
    expect(skin.tailIcons, hasLength(5));
    expect(skin.tailIconsSelected, hasLength(5));
    expect(skin.pubButton, isNotNull);
    expect(skin.pubButtonSelected, isNotNull);
    expect(skin.headMyselfVideo, isNull);
    expect(pngSize(skin.headBg!), (1320, 430));
    expect(pngSize(skin.headTabBg!), (1320, 132));
    expect(pngSize(skin.headMyself!), (1320, 1000));
    expect(pngSize(skin.tailBg!), (1320, 300));
    for (final icon in [...skin.tailIcons, ...skin.tailIconsSelected, skin.pubButton!, skin.pubButtonSelected!]) {
      expect(pngSize(icon.file), (180, 135));
    }
  });

  group('the status bar over the headers', () {
    const darkText = SkinColors(color: 0xFF222222, tailColor: 0xFF101010, tailColorSelected: 0xFFFF0000);
    late Uint8List darkHead;
    late Uint8List lightMe;

    setUpAll(() async {
      darkHead = await solidPng(const Color(0xFF161513), 1320, 318);
      lightMe = await solidPng(const Color(0xFFF5EBD7), 1320, 1320);
    });

    FakeSkinApi pictured({Map<String, List<int>>? entries, SkinColors palette = darkText}) {
      final package = zipOf(entries ?? {'head_bg.png': darkHead, 'head_myself_bg.png': lightMe});
      return FakeSkinApi(
        equip: equipFor(package, palette: palette),
        package: package,
      );
    }

    File kept() => File('${versionFolders(7, 1).single.path}/.status.json');

    test('a transparent header follows appearance without fetching the skin, with separate cached measures', () async {
      final clear = await solidPng(const Color(0x00000000), 1320, 318);
      final api = pictured(entries: {'head_bg.png': clear});
      final appearance = ValueNotifier(ThemeMode.light);
      addTearDown(appearance.dispose);
      final (:model, environment: _) = make(api, appearance: appearance);
      await settle(model);
      await model.settle();
      expect(model.value!.lightStatusHome, isFalse);
      final downloads = api.calls.where((call) => call == 'download').length;
      final calls = List.of(api.calls);
      appearance.value = ThemeMode.dark;
      await model.settle();
      expect(model.value!.lightStatusHome, isTrue);
      expect(api.calls.where((call) => call == 'download'), hasLength(downloads));
      expect(api.calls, calls);
      final darkKept = File('${versionFolders(7, 1).single.path}/.status-dark.json');
      expect(await darkKept.exists(), isTrue);
      expect(await kept().exists(), isTrue);
      appearance.value = ThemeMode.light;
      appearance.value = ThemeMode.dark;
      appearance.value = ThemeMode.light;
      await model.settle();
      expect(model.value!.lightStatusHome, isFalse, reason: 'a stale dark measure cannot reverse the latest choice');
    });

    test("measured once the skin shows, by the pictures over color_mode's dark text: white over a dark head_bg, "
        "black over a light 我的; logged without a path or the package's URL", () async {
      final (:model, environment: _) = make(pictured());
      var notified = 0;
      model.addListener(() => notified++);
      await settle(model);
      await model.settle();

      expect(model.value!.lightText, isFalse);
      expect(model.value!.lightStatusHome, isTrue);
      expect(model.value!.lightStatusFollow, isTrue);
      expect(model.value!.lightStatusMe(card: true), isFalse);
      expect(model.value!.lightStatusMe(card: false), isFalse);
      expect(notified, 2, reason: 'shown, then the measure that changes 首页 and 关注');
      final line = logged('skin status bar').single;
      expect(line.f['home']!.toJson(), 0.01);
      expect(line.f['homeLight'], const LogBool(true));
      expect(line.f['follow']!.toJson(), 0.01);
      expect(line.f['followLight'], const LogBool(true));
      expect(line.f['me']!.toJson(), closeTo(0.84, 0.01));
      expect(line.f['meLight'], const LogBool(false));
      expect(line.f['meNoCard']!.toJson(), closeTo(0.84, 0.01));
      expect(line.f['meNoCardLight'], const LogBool(false));
      expect(allLogText(), isNot(contains('skin_model_test')));
      expect(allLogText(), isNot(contains('garb/zip')));
      expect(jsonDecode(kept().readAsStringSync()), {
        'v': 3,
        'home': closeTo(0.0075, 0.001),
        'follow': closeTo(0.0075, 0.001),
        'me': closeTo(0.84, 0.01),
        'meNoCard': closeTo(0.84, 0.01),
      });
    });

    test('kept beside the version, so a launch has it with the cache: nothing measured again, nothing flips', () async {
      final first = make(pictured()).model;
      await settle(first);
      await first.settle();
      // Kept values the pictures would never give, to show they are what the launch reads.
      kept().writeAsStringSync(jsonEncode({'v': 3, 'home': 0.9, 'follow': 0.9, 'me': 0.01, 'meNoCard': 0.9}));

      final (:model, environment: _) = make(pictured());
      await model.start();
      expect(model.value!.statusBar, isNotNull);
      expect(model.value!.lightStatusHome, isFalse);
      expect(model.value!.lightStatusFollow, isFalse);
      expect(model.value!.lightStatusMe(card: true), isTrue);
      expect(model.value!.lightStatusMe(card: false), isFalse);
      var notified = 0;
      model.addListener(() => notified++);
      await model.refresh();
      await model.settle();
      expect(notified, 0);
      expect(model.value!.lightStatusHome, isFalse);
      expect(logged('skin status bar').map((line) => line.f['homeLight']), const [LogBool(true), LogBool(false)]);
    });

    for (final (kind, older) in [
      ('我的 measured with the card only', {'v': 1, 'home': 0.9, 'me': 0.01}),
      ('关注 not measured', {'v': 2, 'home': 0.9, 'me': 0.01, 'meNoCard': 0.9}),
    ]) {
      test('a kept measure of an older kind ($kind) is measured again', () async {
        final first = make(pictured()).model;
        await settle(first);
        await first.settle();
        kept().writeAsStringSync(jsonEncode(older));

        final (:model, environment: _) = make(pictured());
        await model.start();
        expect(model.value!.statusBar, isNull);
        await model.settle();
        expect(model.value!.lightStatusHome, isTrue);
        expect(model.value!.lightStatusFollow, isTrue);
        expect(model.value!.lightStatusMe(card: true), isFalse);
        expect(jsonDecode(kept().readAsStringSync()), containsPair('v', 3));
        expect(jsonDecode(kept().readAsStringSync()), contains('meNoCard'));
        expect(jsonDecode(kept().readAsStringSync()), contains('follow'));
      });
    }

    test('a kept measure that can\'t be read is logged without a path and measured again', () async {
      final first = make(pictured()).model;
      await settle(first);
      await first.settle();
      kept().writeAsStringSync('{not json');

      final (:model, environment: _) = make(pictured());
      await model.start();
      expect(model.value!.statusBar, isNull);
      expect(logged('kept skin status bar unreadable, measuring again').single.f['error'], isNotNull);
      await model.settle();
      expect(model.value!.lightStatusHome, isTrue);
      expect(jsonDecode(kept().readAsStringSync()), containsPair('v', 3));
      expect(allLogText(), isNot(contains('skin_model_test')));
    });

    test("a head_bg that isn't a picture keeps color_mode's choice, logged as such and kept, so no launch measures it "
        'again; no 我的 picture is none', () async {
      final api = pictured(
        entries: {
          'head_bg.png': [for (var i = 0; i < 200; i++) i * 31 % 256],
        },
        palette: colors,
      );
      final (:model, environment: _) = make(api);
      await settle(model);
      await model.settle();
      expect(model.value!.lightStatusHome, isTrue);
      final line = logged('skin status bar').single;
      expect(line.f['home'], const LogString('unreadable'));
      expect(line.f['homeLight'], const LogBool(true));
      expect(line.f['follow'], const LogString('unreadable'));
      expect(line.f['me'], const LogString('none'));
      expect(line.f['meNoCard'], const LogString('none'));
      expect(jsonDecode(kept().readAsStringSync()), {
        'v': 3,
        'home': null,
        'follow': null,
        'me': null,
        'meNoCard': null,
      });

      final next = make(api).model;
      await next.start();
      expect(next.value!.statusBar, isNotNull, reason: 'read with the cache, not measured again');
      expect(next.value!.lightStatusHome, isTrue);
    });

    test('a measure that fails past the picture\'s header is logged without a path and kept nowhere, so the next '
        'launch measures again', () async {
      final whole = await solidPng(const Color(0xFF161513), 1320, 318);
      final api = pictured(entries: {'head_bg.png': whole.sublist(0, whole.length ~/ 2)});
      final (:model, environment: _) = make(api);
      await settle(model);
      await model.settle();
      expect(model.value!.statusBar, isNull);
      expect(model.value!.lightStatusHome, isFalse, reason: "color_mode's dark text meanwhile");
      expect(logged('skin status bar not measured').single.f['error'], const LogString('frame failed: _Exception'));
      expect(logged('skin status bar'), isEmpty);
      expect(kept().existsSync(), isFalse);
      expect(allLogText(), isNot(contains('skin_model_test')));

      // The failure has passed: the same version's picture now decodes.
      File('${versionFolders(7, 1).single.path}/head_bg.png').writeAsBytesSync(whole);
      final next = make(api).model;
      await next.start();
      expect(next.value!.statusBar, isNull);
      await next.settle();
      expect(next.value!.lightStatusHome, isTrue);
      expect(jsonDecode(kept().readAsStringSync()), containsPair('home', closeTo(0.0075, 0.001)));
    });

    test("我的 with a header video goes by the skin's text colour, its picture unmeasured", () async {
      final api = pictured(
        entries: {
          'head_myself_bg.png': lightMe,
          'head_myself_mp4_bg.mp4': [0, 0, 0, 0x18],
        },
        palette: const SkinColors(color: 0xFFFFFFFF),
      );
      final (:model, environment: _) = make(api);
      await settle(model);
      await model.settle();
      expect(model.value!.lightStatusMe(card: true), isTrue);
      expect(model.value!.lightStatusMe(card: false), isTrue);
      final line = logged('skin status bar').single;
      expect(line.f['me'], const LogString('color'));
      expect(line.f['meLight'], const LogBool(true));
      expect(line.f['meNoCard'], const LogString('color'));
      expect(line.f['meNoCardLight'], const LogBool(true));
      expect(line.f['home'], const LogString('none'));
    });

    test("the demo's dark pictures give white icons on both", () async {
      final (:model, environment: _) = make(FakeSkinApi.demo());
      await settle(model);
      await model.settle();
      final line = logged('skin status bar').single;
      expect(line.f['homeLight'], const LogBool(true));
      expect(line.f['meLight'], const LogBool(true));
      expect(line.f['meNoCardLight'], const LogBool(true));
      expect(line.f['home']!.toJson() as double, lessThan(SkinStatusBar.crossover));
      expect(line.f['me']!.toJson() as double, lessThan(SkinStatusBar.crossover));
      expect(line.f['meNoCard']!.toJson() as double, lessThan(SkinStatusBar.crossover));
    });
  });

  group('the 加载动画', () {
    const loadingUrl = 'https://i0.hdslb.com/bfs/garb/item/made-up-loading.gif';
    final gif = DemoSkin.loadingGif();

    SkinLoading loadingFor({int id = 2, int ver = 1, String url = loadingUrl}) =>
        SkinLoading(id: id, name: '测试加载 $id', url: url, ver: ver);

    /// The skin of [apiWith] and a 加载动画 of [picture] (the stand-in gif); [skin] false wears it alone.
    FakeSkinApi wearing({int ver = 1, List<int>? picture, bool skin = true, String url = loadingUrl}) {
      final api = skin ? apiWith(1) : FakeSkinApi();
      return api
        ..loading = loadingFor(ver: ver, url: url)
        ..loadingPicture = picture ?? gif;
    }

    Directory loadingFolder() => Directory('${folder.path}/${SkinLoadingKeeper.folderName}');

    Set<String> loadingFiles() =>
        loadingFolder().existsSync() ? loadingFolder().listSync().map(nameOf).toSet() : const <String>{};

    int downloads(FakeSkinApi api) => api.calls.where((call) => call == 'loading').length;

    test('is downloaded, checked, kept and shown, logged once without its link', () async {
      final api = wearing();
      final (:model, environment: _) = make(api);
      var notified = 0;
      model.loading.addListener(() => notified++);
      await settle(model);
      await model.settle();

      final shown = model.loading.value!;
      expect((shown.id, shown.ver, shown.frames, shown.width, shown.height), (2, 1, 8, 144, 144));
      expect(model.value, isNotNull, reason: 'the skin beside it');
      expect(notified, 1);
      expect(downloads(api), 1);
      expect(loadingFiles(), {'2-1', 'current.json'});
      expect(File('${loadingFolder().path}/2-1').readAsBytesSync(), gif);
      final line = logged('skin loading').single;
      expect(line.f['from'], const LogString('download'));
      expect(line.f['format'], const LogString('gif'));
      expect(line.f['frames'], const LogInt(8));
      expect(line.f['width'], const LogInt(144));
      expect(line.f['bytes'], LogInt(gif.length));
      expect(line.f['name'], const LogString('测试加载 2'));
      expect(line.f, isNot(contains('fallback')));
      expect(allLogText(), isNot(contains('made-up-loading')));

      await model.refresh();
      expect(downloads(api), 1, reason: 'the same one shown already');
      expect(logged('skin loading'), hasLength(1));
    });

    test('is worn without a skin', () async {
      final api = wearing(skin: false);
      final (:model, environment: _) = make(api);
      await settle(model);
      expect(model.value, isNull);
      expect(model.loading.value!.id, 2);
    });

    test('a relaunch shows it from the disk before the check answers, and downloads nothing', () async {
      final first = make(wearing()).model;
      await settle(first);
      await first.settle();

      final api = wearing();
      final hold = api.holds['equipped'] = Completer<void>();
      final (:model, environment: _) = make(api);
      await model.start();
      await model.settle();
      expect(model.loading.value!.id, 2, reason: 'from the cache:\n${allLogText()}');
      expect(logged('skin loading').last.f['from'], const LogString('cache'));
      hold.complete();
      await model.refresh();
      expect(downloads(api), 0);
      expect(model.loading.value!.id, 2);
    });

    test('a new version replaces the file', () async {
      final api = wearing();
      final (:model, environment: _) = make(api);
      await settle(model);
      final before = model.loading.value!;

      api.loading = loadingFor(ver: 2);
      await model.refresh();
      await model.settle();
      expect(model.loading.value!.ver, 2);
      expect(model.loading.value, isNot(same(before)));
      expect(downloads(api), 2);
      expect(loadingFiles(), {'2-2', 'current.json'});
    });

    test('none worn hides it and deletes its files; the next launch starts without it', () async {
      final api = wearing();
      final (:model, environment: _) = make(api);
      await settle(model);

      api.loading = null;
      await model.refresh();
      await model.settle();
      expect(model.loading.value, isNull);
      expect(loadingFiles(), {'current.json'});
      expect(logged('skin loading stays stock').last.f['reason'], const LogString('none worn'));

      final next = make(FakeSkinApi(), account: const AccountUnknown()).model;
      await next.start();
      await next.settle();
      expect(next.loading.value, isNull);
    });

    test('a skin without one leaves no folder for it', () async {
      final (:model, environment: _) = make(apiWith(1));
      await settle(model);
      await model.settle();
      expect(loadingFolder().existsSync(), isFalse);
    });

    test('logging out hides it and keeps the file; a login shows it again without a download', () async {
      final api = wearing();
      final (:model, :environment) = make(api);
      await settle(model);

      environment.account = const LoggedOut();
      expect(model.loading.value, isNull);
      await model.settle();
      expect(loadingFiles(), contains('2-1'));

      final next = make(wearing(), account: const AccountUnknown()).model;
      await next.start();
      await next.settle();
      expect(next.loading.value, isNull, reason: "a logged-out launch never shows the old account's");

      environment.account = loggedIn;
      await model.refresh();
      expect(model.loading.value!.id, 2);
      expect(downloads(api), 1);
      expect(logged('skin loading').last.f['from'], const LogString('download'), reason: 'logged once a run');
    });

    test('another account logging in hides it before its own token is there', () async {
      final api = wearing();
      final (:model, :environment) = make(api);
      await settle(model);

      api.failures['equipped'] = BiliError.noAppToken;
      environment.mid = 2;
      environment.logins.value++;
      await model.refresh();
      expect(model.loading.value, isNull);
      expect(logged('skin loading stays stock').last.f['reason'], const LogString('another account'));
    });

    test('bytes that are no picture keep the TV, say why, and are not fetched again this run', () async {
      final api = wearing(picture: [1, 2, 3]);
      final (:model, environment: _) = make(api);
      await settle(model);
      await model.settle();
      expect(model.loading.value, isNull);
      expect(model.value, isNotNull, reason: 'the skin still shows');
      final line = logged('skin loading').single;
      expect(line.level, LogLevel.warn);
      expect(line.f['format'], const LogString('unknown'));
      expect(line.f['fallback'], const LogString('not a picture that decodes'));
      expect(line.f['bytes'], const LogInt(3));
      expect(loadingFiles(), isNot(contains('2-1')));

      await model.refresh();
      expect(downloads(api), 1);
    });

    test("a picture that can't be drawn takes the one shown before away", () async {
      final api = wearing();
      final (:model, environment: _) = make(api);
      await settle(model);
      api
        ..loading = loadingFor(ver: 2)
        ..loadingPicture = [1, 2, 3];
      await model.refresh();
      await model.settle();
      expect(model.loading.value, isNull);
      expect(loadingFiles(), {'current.json'});
    });

    test("a zip's first picture is taken out and kept as the file", () async {
      final api = wearing(picture: zipOf({'readme.txt': 'hello'.codeUnits, 'loading.gif': gif}));
      final (:model, environment: _) = make(api);
      await settle(model);
      await model.settle();
      expect(model.loading.value!.format, SkinLoadingFormat.gif);
      expect(model.loading.value!.frames, 8);
      final line = logged('skin loading').single;
      expect(line.f['format'], const LogString('zip'));
      expect(line.f['inner'], const LogString('gif'));
      expect(File('${loadingFolder().path}/2-1').readAsBytesSync(), gif);
    });

    test("only Bilibili's CDN hosts are asked, and the log names the host alone", () async {
      final api = wearing(url: 'https://example.com/private/loading.gif?sign=abc');
      final (:model, environment: _) = make(api);
      await settle(model);
      expect(downloads(api), 0);
      expect(model.loading.value, isNull);
      expect(
        logged('skin loading not downloaded, keeping what is shown').single.f['error'],
        const LogString('loading host not allowed: https://example.com'),
      );
      expect(allLogText(), isNot(contains('private')));
    });

    test('a failed download keeps what is shown and tries again on the next check', () async {
      final api = wearing();
      final (:model, environment: _) = make(api);
      await settle(model);
      final shown = model.loading.value;

      api
        ..loading = loadingFor(ver: 2)
        ..failures['loading'] = _TransportError();
      await model.refresh();
      expect(model.loading.value, same(shown));
      expect(
        logged('skin loading not downloaded, keeping what is shown').single.f['error'],
        const LogString('_TransportError'),
      );
      expect(allLogText(), isNot(contains('hdslb')));

      api.failures.remove('loading');
      await model.refresh();
      expect(model.loading.value!.ver, 2);
    });

    test('a load_equip not understood keeps what is shown and its file', () async {
      final api = wearing();
      final (:model, environment: _) = make(api);
      await settle(model);
      final shown = model.loading.value;

      api
        ..loading = null
        ..loadingError = 'skin: load_equip is a string';
      await model.refresh();
      await model.settle();
      expect(model.loading.value, same(shown));
      expect(loadingFiles(), contains('2-1'));
      expect(
        logged('skin loading answer not understood, keeping what is shown').single.f['reason'],
        const LogString('skin: load_equip is a string'),
      );
    });

    test('a user_equip not understood beside it keeps the skin shown, and the 加载动画 still shows', () async {
      final api = apiWith(1);
      final (:model, environment: _) = make(api);
      await settle(model);
      final skin = model.value;

      api
        ..equip = null
        ..equipError = 'skin: no user_equip (data keys: load_equip)'
        ..loading = loadingFor()
        ..loadingPicture = gif;
      await model.refresh();
      expect(model.value, same(skin));
      expect(versionExists(7, 1), isTrue);
      expect(model.loading.value!.id, 2);
      expect(
        logged('skin answer not understood, keeping what is shown').single.f['reason'],
        const LogString('skin: no user_equip (data keys: load_equip)'),
      );
    });
  });
}

/// Width and height from a PNG's header.
(int, int) pngSize(File file) {
  final bytes = file.readAsBytesSync();
  expect(bytes.sublist(1, 4), ascii.encode('PNG'));
  final header = ByteData.sublistView(bytes, 16, 24);
  return (header.getUint32(0), header.getUint32(4));
}
