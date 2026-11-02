import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bili_core/api.dart' show SkinColors, SkinEquip;

import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/account/login_gate.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/app/route_observer.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/me/fake_me_api.dart';
import 'package:bilifast/me/me_model.dart';
import 'package:bilifast/me/me_page.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:bilifast/skin/fake_skin_api.dart';
import 'package:bilifast/skin/skin.dart';
import 'package:bilifast/skin/skin_model.dart';
import 'package:bilifast/space/fake_space_api.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';

/// 87's account: KaiC5504, LV5, 年度大会员, B币 2.3 and 硬币 878, wearing a frame.
const kaiProfile = MeProfile(
  mid: 2233,
  name: 'KaiC5504',
  face: '',
  pendant: 'https://i0.hdslb.com/bfs/garb/item/pendant.png',
  level: 5,
  coins: 878,
  bcoin: 2.3,
  vip: true,
  vipLabel: '年度大会员',
  vipBadge: true,
);

const kaiCounts = MeCounts(dynamics: 0, following: 13, followers: 0);

/// A model showing whatever [view] the test sets, counting showings, background loads and pulls.
class FixedMeModel extends MeModel {
  FixedMeModel(this._view, {required super.api, required super.environment});

  MeView _view;
  int showings = 0;
  int preloads = 0;
  int refreshes = 0;

  /// What the pull answers: null on success, else the message to toast.
  String? refreshAnswer;

  /// Holds the pull's answer until completed.
  Completer<void>? refreshGate;

  @override
  MeView get view => _view;

  set view(MeView next) {
    _view = next;
    notifyListeners();
  }

  @override
  void shown() => showings++;

  @override
  void preload() => preloads++;

  @override
  Future<String?> refresh() async {
    refreshes++;
    await refreshGate?.future;
    return refreshAnswer;
  }
}

/// A skin model answering whatever [skin] the test sets, counting pulls; it never asks the account.
class FixedSkinModel extends SkinModel {
  FixedSkinModel(this._skin, {required super.environment}) : super(api: FakeSkinApi(), folder: null);

  Skin? _skin;
  int refreshes = 0;

  @override
  Skin? get value => _skin;

  set skin(Skin? next) {
    _skin = next;
    notifyListeners();
  }

  @override
  Future<void> refresh() async => refreshes++;
}

/// 109's colours: white text and icons, light text over the picture.
SkinEquip skinEquip({int? color = 0xFFFFFFFF, bool lightText = true, bool videoLoop = true}) => SkinEquip(
  id: 1,
  name: '测试装扮',
  ver: 1,
  packageUrl: '',
  packageMd5: '',
  colors: SkinColors(color: color, lightText: lightText, headMyselfVideoLoop: videoLoop),
);

/// Writes a PNG of [width] × [height] px into [folder], painted by [paint]; run it under `tester.runAsync`.
Future<File> drawPicture(
  Directory folder,
  String name,
  int width,
  int height,
  void Function(Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return File('${folder.path}/$name')..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// A fresh folder for a test's pictures, deleted after it.
Directory pictureFolder() {
  final folder = Directory.systemTemp.createTempSync('me_skin');
  addTearDown(() => folder.deleteSync(recursive: true));
  return folder;
}

/// Lets 我的 read and decode its skin's picture until it shows, [rounds] at most. Its loading started in the test's
/// fake time, so each real step (reading, decoding) needs real time and each step after it a pump.
Future<void> settlePicture(WidgetTester tester, {int rounds = 40}) async {
  final picture = find.byKey(const ValueKey('me-skin-picture'));
  for (var i = 0; i < rounds && picture.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

/// What a test of 我的 holds on to.
class MeHarness {
  MeHarness({
    required this.model,
    required this.skin,
    required this.services,
    required this.opened,
    required this.active,
  });

  final FixedMeModel model;
  final FixedSkinModel skin;
  final AppServices services;

  /// Whether 我的 is the bar's current tab.
  final ValueNotifier<bool> active;

  /// The links the page asked to open outside the app, in order, whether or not they opened.
  final List<Uri> opened;
}

/// 我的 above a 83 pt stand-in for the bottom bar, as MainShell lays it out (the page's bottom padding taken off), on
/// KaiC's iPhone at [pixelRatio]; wrapped in a RepaintBoundary keyed `screen`.
Future<MeHarness> showMe(
  WidgetTester tester, {
  MeView view = const MeShown(kaiProfile, kaiCounts),
  bool active = true,
  LoginGate? loginGate,
  double pixelRatio = 1,
  ThemeData? theme,
  FontStore? fonts,
  bool openSucceeds = true,
  bool officialAppThere = true,
  Future<bool> Function(Uri link)? open,
  WidgetBuilder? developerPage,
  bool checkAccount = false,
  Skin? skin,
  Widget? bottomBar,
}) async {
  tester.view
    ..physicalSize = const Size(440, 956) * pixelRatio
    ..devicePixelRatio = pixelRatio
    ..padding = FakeViewPadding(top: 62 * pixelRatio, bottom: 34 * pixelRatio)
    ..viewPadding = FakeViewPadding(top: 62 * pixelRatio, bottom: 34 * pixelRatio);
  addTearDown(tester.view.reset);
  final logger = Logger(session: 'test');
  final environment = await AppEnvironment.load(
    keychain: FakeKeychain(const StoredCookies(Canned.cookies)),
    http: Canned.http(),
    logger: logger,
  );
  // Canned's nav answers a 大会员.
  if (checkAccount) await environment.refreshAccount();
  final model = FixedMeModel(view, api: FakeMeApi.demo(), environment: environment);
  addTearDown(model.dispose);
  final skins = FixedSkinModel(skin, environment: environment);
  addTearDown(skins.dispose);
  final playback = AppPlayback(() => throw StateError('no playback here'));
  addTearDown(playback.dispose);
  final services = AppServices(
    environment: environment,
    playback: playback,
    recents: await RecentStore.load(null, logger: logger),
    fonts: fonts ?? FontStore.memory(),
    loginGate: loginGate,
    pageApi: FakePageApi(),
    spaceApi: FakeSpaceApi(),
    meApi: FakeMeApi.demo(),
  );
  final shownTab = ValueNotifier(active);
  addTearDown(shownTab.dispose);
  final opened = <Uri>[];
  Future<bool> record(Uri link) async {
    opened.add(link);
    return open == null ? openSucceeds : open(link);
  }

  await tester.pumpWidget(
    ListenableBuilder(
      listenable: services.appearance,
      builder: (context, _) => MaterialApp(
      theme: theme,
      darkTheme: biliTheme(Brightness.dark),
      themeMode: services.appearance.mode,
      themeAnimationDuration: Duration.zero,
      navigatorObservers: [pageRoutes],
      builder: (context, child) => RepaintBoundary(
        key: const ValueKey('screen'),
        child: AppScope(services: services, child: child!),
      ),
      home: Scaffold(
        backgroundColor: MeTheme.background,
        body: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: shownTab,
                builder: (context, active, _) => MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: MePage(
                    active: active,
                    developerPage: developerPage,
                    model: model,
                    skin: skins,
                    openLink: record,
                    canOpenLink: (_) async => officialAppThere,
                  ),
                ),
              ),
            ),
            bottomBar ?? const SizedBox(height: 83),
          ],
        ),
      ),
      ),
    ),
  );
  await tester.pump();
  return MeHarness(model: model, skin: skins, services: services, opened: opened, active: shownTab);
}
