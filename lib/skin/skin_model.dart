import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Brightness, ThemeMode;

import '../app/app_environment.dart';
import '../devtools/crash_log.dart';
import '../shared/bili_palette.dart';
import 'skin.dart';
import 'skin_api.dart';
import 'skin_loading.dart';
import 'skin_package.dart';
import 'skin_status_bar.dart';

/// The equipped 装扮, asked at launch and on every login, its package downloaded once per id, version and md5 and
/// unpacked under [folder] (the support folder's `skins`). Answers from the last unpacked skin at once, so a launch
/// draws the theme from the first frame; a failure keeps what is shown, and a package that failed isn't fetched again
/// this run.
///
/// On disk: `current.json` names the skin last equipped (or none), and each package is unpacked into
/// `<id>/<ver>-<first 8 of md5>`, whole once its `.skin.json` is there (the unpack goes to a `.partial` folder and is
/// renamed into place). A package changed under the same version gets a folder of its own, so files on screen are
/// never replaced in place. Logging out shows the stock look and the next launch starts stock, but the files stay for
/// the next login. Each version's headers are measured behind the status bar on its first showing and the result kept
/// in its `.status.json`, so later launches have it with the cache.
/// Saved accounts use `current-<mid>.json`; their installed package versions stay shared.
///
/// The 加载动画 worn with it (or alone) is [loading], kept by [SkinLoadingKeeper] in the folder's `loading`, asked,
/// shown and hidden at the same moments.
class SkinModel extends ChangeNotifier implements ValueListenable<Skin?> {
  SkinModel({required this._api, required this._environment, required this._folder,
    this.appearance, Logger? logger})
    : _logger = logger ?? Logger.shared;

  final SkinApi _api;
  final AppEnvironment _environment;
  final String? _folder;
  final Logger _logger;
  final ValueListenable<ThemeMode>? appearance;
  int _appearanceGeneration = 0;

  BiliPalette get _palette => BiliPalette(appearance?.value == ThemeMode.dark ? Brightness.dark : Brightness.light);

  static String _statusNameFor(BiliPalette palette) => palette.isDark ? '.status-dark.json' : _statusName;

  static const _currentName = 'current.json';
  static const _manifestName = '.skin.json';
  static const _statusName = '.status.json';

  /// Bumped when the measure changes, so kept results are measured again.
  static const _statusMeasure = 3;

  Skin? _value;
  Future<void>? _started;
  Future<void> _cacheRead = Future.value();
  Future<void>? _refreshing;

  /// Unpacking, writing `current.json` and deleting versions run one after another; a download waits outside, so a
  /// logout's write never waits for one.
  Future<void> _disk = Future.value();

  /// Packages that failed to install this run, by [_installKey], until the equip names another.
  final Set<String> _failed = {};

  /// Versions whose skipped files were logged.
  final Set<String> _skippedLogged = {};

  /// Where versions are unpacked without [_folder]: a temporary folder, made on first use.
  Future<String>? _scratch;

  /// Status bar measures, one at a time.
  Future<void> _measuring = Future.value();
  String? _statusLogged;

  /// The account as it last settled; unknown only until the launch's check answers.
  Account _account = const AccountUnknown();

  /// The turn to logged in has refreshed already, so the login count that follows asks nothing more.
  bool _loginRefreshed = false;

  /// Bumped by every login and logout, so an answer for the account before never shows.
  int _generation = 0;
  int _sessionGeneration = 0;
  bool _toldNoToken = false;
  String? _logged;
  bool _disposed = false;

  @override
  Skin? get value => _value;

  late final SkinLoadingKeeper _loading = SkinLoadingKeeper(api: _api, root: _root, logger: _logger,
      accountMid: _environment.hasAccountVault ? () => _environment.activeAccountMid : null);
  Future<void> _loadingRead = Future.value();

  /// The account whose 加载动画 is shown.
  int? _loadingMid;

  /// The equipped 加载动画, decoded; null shows the loading TV.
  ValueListenable<SkinLoadingAnimation?> get loading => _loading.shown;

  bool get _signedIn => switch (_environment.account) {
    LoggedOut() || LoginExpired() => false,
    LoggedIn() || AccountUnknown() => true,
  };

  /// Reads the cached skin and shows it unless the account is logged out, then asks for the equipped one when logged
  /// in (not awaited). Completes once the cache is read, so `main` can draw the first frame with it.
  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    appearance?.addListener(_appearanceChanged);
    _account = _environment.account;
    _environment.addListener(_accountChanged);
    _environment.logins.addListener(_loginCompleted);
    _sessionGeneration = _environment.sessionGeneration;
    _environment.sessions.addListener(_sessionChanged);
    _loading.shown.addListener(_loadingShown);
    // Not awaited: it shows only in a refresh, never in the first frame.
    _loadingRead = _readLoadingCache(_generation);
    final generation = _generation;
    final read = _readCache();
    _cacheRead = read;
    final cached = await read;
    if (cached != null && _current(generation) && _signedIn && _value == null) _showDressed(cached, from: 'cache');
    if (_environment.account is LoggedIn) unawaited(refresh());
  }

  /// Asks for the equipped skin again; a call while one is out joins it. Never throws: pages fire it unawaited.
  Future<void> refresh() {
    if (_refreshing case final running?) return running;
    late final Future<void> run;
    run = _refresh(_generation)
        .catchError((Object error, StackTrace stack) {
          if (error is Error) {
            CrashLog.report(error, stack, source: 'skin refresh', logger: _logger);
          } else {
            _logger.warn(LogCategory.ui, 'skin refresh failed, keeping what is shown', {'error': _describe(error)});
          }
        })
        .whenComplete(() {
          if (identical(_refreshing, run)) _refreshing = null;
        });
    return _refreshing = run;
  }

  Future<void> _readLoadingCache(int generation) async {
    final cached = await _loading.readCache();
    if (cached != null && _current(generation) && _signedIn && _loading.shown.value == null) _loading.show(cached);
  }

  void _loadingShown() {
    _loadingMid = _loading.shown.value == null ? null : _environment.mid ?? _loadingMid;
  }

  Future<void> _refresh(int generation) async {
    await _cacheRead;
    await _loadingRead;
    if (!_current(generation) || !_signedIn) return;
    final SkinWorn worn;
    try {
      worn = await _api.equipped();
    } on BiliNoAppTokenError {
      if (!_toldNoToken) {
        _logger.info(LogCategory.ui, 'skin waits for the app token, keeping what is shown', {'shown': _value != null});
      }
      _toldNoToken = true;
      return;
    } on BiliDecodingError catch (error) {
      // A changed answer must not read as nothing equipped, which would delete the theme's files.
      _logger.warn(LogCategory.ui, 'skin answer not understood, keeping what is shown', {'reason': error.detail});
      return;
    } on Exception catch (error) {
      _logger.warn(LogCategory.ui, 'skin check failed, keeping what is shown', {'error': _describe(error)});
      return;
    }
    _toldNoToken = false;
    if (!_current(generation)) return;
    await Future.wait([_loading.wear(worn, () => _current(generation)), _wear(worn, generation)]);
  }

  Future<void> _wear(SkinWorn worn, int generation) async {
    final owner = _environment.activeAccountMid;
    if (worn.equipError case final reason?) {
      _logger.warn(LogCategory.ui, 'skin answer not understood, keeping what is shown', {'reason': reason});
      return;
    }
    final equip = worn.equip;
    if (equip == null) {
      _logger.info(LogCategory.ui, 'skin stays stock', {'reason': 'none equipped'});
      _show(null);
      await _exclusive(() async {
        if (!_current(generation)) return;
        await _writeCurrent(null, ownerMid: owner);
        await _deleteVersions(keep: null);
      });
      return;
    }
    final SkinEquip next = equip;
    if (_value case final shown? when _cacheText(shown.equip) == _cacheText(next)) {
      await _exclusive(() => _deleteVersions(keep: next));
      return;
    }
    final key = _installKey(next);
    if (_failed.contains(key)) {
      _logger.info(LogCategory.ui, 'skin not installed, keeping what is shown', {
        'id': next.id,
        'ver': next.ver,
        'reason': 'failed earlier this run',
      });
      return;
    }
    try {
      final installed = await _install(next, generation);
      if (installed == null || !_current(generation)) return;
      final (skin, from) = installed;
      _showDressed(skin, from: from);
      await _exclusive(() async {
        if (!_current(generation)) return;
        await _writeCurrent(next, ownerMid: owner);
        await _deleteVersions(keep: next);
      });
    } on Exception catch (error) {
      if (error is SkinPackageError && !error.passing) _failed.add(key);
      _logger.warn(LogCategory.ui, 'skin not installed, keeping what is shown', {
        'id': next.id,
        'ver': next.ver,
        'error': _describe(error),
      });
    }
  }

  /// The version's files, unpacked already, or downloaded, checked and unpacked now; null when the account changed
  /// while it downloaded.
  Future<(Skin, String)?> _install(SkinEquip equip, int generation) async {
    final target = Directory(_versionPath(await _root(), equip));
    if (await _exclusive(() => _wholeVersion(target, equip)) case final files?) {
      return (await _withKeptStatus(_resolve(equip, files), target), 'unpacked');
    }
    final md5 = equip.packageMd5.trim().toLowerCase();
    if (md5.isEmpty) throw const SkinPackageError('no md5 in answer');
    if (!_md5.hasMatch(md5)) throw const SkinPackageError('md5 in answer malformed');
    final url = Uri.tryParse(equip.packageUrl);
    if (url == null) throw const SkinPackageError('package link unreadable');
    if (!isSkinPackageUrl(url)) throw SkinPackageError.hostNotAllowed(url);
    final download = await _api.download(url);
    if (!_current(generation)) return null;
    if (download.length > SkinLimits.packageBytes) throw const SkinPackageError('package too large');
    final bytes = download is Uint8List ? download : Uint8List.fromList(download);
    return _exclusive(() async {
      if (!_current(generation)) return null;
      final partial = Directory('${target.path}.partial');
      if (await partial.exists()) await partial.delete(recursive: true);
      final unpacked = await unpackSkinPackage(bytes, md5: md5, folder: partial.path);
      if (unpacked.skipped.isNotEmpty) {
        _logger.warn(LogCategory.ui, 'skin package entries skipped', {
          'id': equip.id,
          'ver': equip.ver,
          'skipped': unpacked.skipped.join(', '),
        });
      }
      await File('${partial.path}/$_manifestName').writeAsString(jsonEncode({'md5': md5}), flush: true);
      if (await target.exists()) await _retried(() => target.delete(recursive: true));
      await _retried(() => partial.rename(target.path));
      return (_resolve(equip, await listSkinFiles(target)), 'package');
    });
  }

  static final _md5 = RegExp(r'^[0-9a-f]{32}$');

  static String _installKey(SkinEquip equip) => '${equip.id}|${equip.ver}|${equip.packageMd5.trim().toLowerCase()}';

  /// [resolveSkin], logging once per version the files of a role's name it couldn't draw.
  Skin _resolve(SkinEquip equip, List<SkinFile> files) {
    final skipped = <String>[];
    final skin = resolveSkin(equip, files, skipped: skipped);
    if (skipped.isNotEmpty && _skippedLogged.add(_installKey(equip))) {
      _logger.warn(LogCategory.ui, 'skin files skipped', {
        'id': equip.id,
        'ver': equip.ver,
        'skipped': skipped.join(', '),
      });
    }
    return skin;
  }

  /// The files of [folder] when it holds [equip]'s package whole; null otherwise, so it is unpacked again.
  Future<List<SkinFile>?> _wholeVersion(Directory folder, SkinEquip equip) async {
    try {
      final manifest = File('${folder.path}/$_manifestName');
      if (!await manifest.exists()) return null;
      final json = jsonDecode(await manifest.readAsString());
      if (json is! Map<String, Object?> || json['md5'] != equip.packageMd5.trim().toLowerCase()) return null;
      return await listSkinFiles(folder);
    } on Exception catch (error) {
      _logger.warn(LogCategory.ui, 'unpacked skin unreadable', {'id': equip.id, 'error': _describe(error)});
      return null;
    }
  }

  /// [skin] with the status bar measure kept in [version], when there is one of the current measure.
  Future<Skin> _withKeptStatus(Skin skin, Directory version) async {
    final generation = _appearanceGeneration;
    final statusName = _statusNameFor(_palette);
    try {
      final file = File('${version.path}/$statusName');
      if (!await file.exists()) return skin;
      final json = jsonDecode(await file.readAsString());
      if (generation != _appearanceGeneration || json is! Map<String, Object?> || json['v'] != _statusMeasure) return skin;
      double? luminance(String key) => switch (json[key]) {
        final num value => value.toDouble(),
        _ => null,
      };
      return skin.withStatusBar(
        SkinStatusBar(
          home: luminance('home'),
          follow: luminance('follow'),
          me: luminance('me'),
          meNoCard: luminance('meNoCard'),
        ),
      );
    } on Exception catch (error) {
      _logger.warn(LogCategory.ui, 'kept skin status bar unreadable, measuring again', {'error': _describe(error)});
      return skin;
    }
  }

  Future<void> _keepStatus(SkinEquip equip, SkinStatusBar status, BiliPalette palette) async {
    final statusName = _statusNameFor(palette);
    try {
      final version = _versionPath(await _root(), equip);
      // Deleted meanwhile, or being unpacked again.
      if (!await File('$version/$_manifestName').exists()) return;
      final temporary = File('$version/$statusName.tmp');
      await temporary.writeAsString(
        jsonEncode({
          'v': _statusMeasure,
          'home': status.home,
          'follow': status.follow,
          'me': status.me,
          'meNoCard': status.meNoCard,
        }),
        flush: true,
      );
      await _retried(() => temporary.rename('$version/$statusName'));
    } on Exception catch (error) {
      _logger.warn(LogCategory.ui, 'skin status bar not kept', {'error': _describe(error)});
    }
  }

  Future<Skin?> _readCache() async {
    final folder = _folder;
    if (folder == null) return null;
    final owner = _environment.activeAccountMid;
    if (_environment.hasAccountVault && owner == null) return null;
    try {
      final file = File('$folder/${_currentFile(owner)}');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) throw const FormatException('not an object');
      final equip = _equipFromCache(json['equip']);
      if (equip == null) {
        _logger.info(LogCategory.ui, 'skin stays stock', {'reason': 'none at the last check'});
        return null;
      }
      final version = Directory(_versionPath(folder, equip));
      final files = await _wholeVersion(version, equip);
      if (files == null) {
        _logger.warn(LogCategory.ui, 'skin stays stock', {'reason': 'cached version incomplete', 'id': equip.id});
        return null;
      }
      return await _withKeptStatus(_resolve(equip, files), version);
    } on Exception catch (error) {
      _logger.warn(LogCategory.ui, 'skin stays stock', {'reason': 'cache unreadable', 'error': _describe(error)});
      return null;
    } on Error catch (error, stack) {
      CrashLog.report(error, stack, source: 'skin cache', logger: _logger);
      return null;
    }
  }

  String _currentFile(int? owner) => _environment.hasAccountVault ? 'current-$owner.json' : _currentName;

  Future<void> _writeCurrent(SkinEquip? equip, {int? ownerMid}) async {
    final folder = _folder;
    if (folder == null) return;
    final owner = ownerMid ?? _environment.activeAccountMid;
    if (_environment.hasAccountVault && owner == null) return;
    final current = _currentFile(owner);
    try {
      await Directory(folder).create(recursive: true);
      final temporary = File('$folder/$current.tmp');
      await temporary.writeAsString(jsonEncode({'equip': equip == null ? null : _cacheJson(equip)}), flush: true);
      await _retried(() => temporary.rename('$folder/$current'));
    } on Exception catch (error) {
      _logger.warn(LogCategory.ui, 'skin choice not saved', {'error': _describe(error)});
    }
  }

  /// Every unpacked version but [keep]'s, and any unpack left half done.
  Future<void> _deleteVersions({required SkinEquip? keep}) async {
    // A different saved account may still reference any installed version.
    if (_environment.hasAccountVault) return;
    var failed = 0;
    try {
      final root = Directory(await _root());
      if (!await root.exists()) return;
      await for (final skin in root.list(followLinks: false)) {
        if (skin is! Directory || _nameOf(skin.path) == SkinLoadingKeeper.folderName) continue;
        final id = _nameOf(skin.path);
        await for (final version in skin.list(followLinks: false)) {
          if (keep != null && id == '${keep.id}' && _nameOf(version.path) == _versionName(keep)) continue;
          try {
            await version.delete(recursive: true);
          } on FileSystemException {
            failed++;
          }
        }
        if (await skin.list().isEmpty) await skin.delete();
      }
    } on FileSystemException {
      failed++;
    }
    // A file Windows still holds (see [_retried]) can't go; a later refresh tries again.
    if (failed > 0) _logger.warn(LogCategory.ui, 'old skin files not deleted', {'count': failed});
  }

  Future<String> _root() async {
    if (_folder case final folder?) return folder;
    return _scratch ??= Directory.systemTemp.createTemp('bilifast_skin_').then((folder) => folder.path);
  }

  static String _versionPath(String root, SkinEquip equip) => '$root/${equip.id}/${_versionName(equip)}';

  /// The md5 comes from an answer, so only its hex digits reach the path.
  static String _versionName(SkinEquip equip) {
    final digits = equip.packageMd5.toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');
    return '${equip.ver}-${digits.length > 8 ? digits.substring(0, 8) : digits}';
  }

  static String _nameOf(String path) => path.split(RegExp(r'[\\/]')).last;

  /// Windows' virus scan holds a file it has just seen written for a moment, and a rename or delete then fails.
  static Future<T> _retried<T>(Future<T> Function() step) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await step();
      } on FileSystemException {
        if (attempt == 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 40 * attempt));
      }
    }
  }

  /// Waits for the status bar measures and disk work so far; for tests.
  Future<void> settle() async {
    await _measuring;
    await _disk;
    await _loadingRead;
    await _loading.settle();
  }

  Future<T> _exclusive<T>(Future<T> Function() task) {
    final run = _disk.then((_) => task());
    _disk = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  void _accountChanged() {
    if (_environment.hasAccountVault && _sessionGeneration != _environment.sessionGeneration) return;
    final now = _environment.account;
    if (now is AccountUnknown) {
      // didLogin passes through here on its way to logged in; the login count after it then knows whether the turn
      // to logged in has refreshed.
      _loginRefreshed = false;
      return;
    }
    final was = _account;
    _account = now;
    if (now is! LoggedIn) {
      _signedOut(was);
    } else if (was is! LoggedIn) {
      // The cached skin shown before the check answered is taken as this account's.
      if (_value != null) _shownMid ??= _environment.mid;
      if (_loading.shown.value != null) _loadingMid ??= _environment.mid;
      _loginRefreshed = true;
      _restart();
    }
  }

  /// A login over an account that already read logged in leaves the account where it was, and may be another one.
  /// Another account's skin goes at once: its refresh can't replace it until that account's own token is confirmed.
  void _loginCompleted() {
    if (_environment.hasAccountVault) return;
    if (_loginRefreshed) {
      _loginRefreshed = false;
    } else if (_account is LoggedIn) {
      if (_value != null && _environment.mid != _shownMid) {
        _logger.info(LogCategory.ui, 'skin stays stock', {'reason': 'another account'});
        _show(null);
        unawaited(_exclusive(() => _writeCurrent(null)));
      }
      if (_loading.shown.value != null && _environment.mid != _loadingMid) {
        _logger.info(LogCategory.ui, 'skin loading stays stock', {'reason': 'another account'});
        _loading.hide();
      }
      _restart();
    }
  }

  void _sessionChanged() {
    if (!_environment.hasAccountVault) return;
    _sessionGeneration = _environment.sessionGeneration;
    final generation = ++_generation;
    _refreshing = null;
    _account = _environment.account;
    _toldNoToken = false;
    _appearanceGeneration++;
    _show(null);
    _loading.show(null);
    _loadingRead = _readLoadingCache(generation);
    _cacheRead = _readCache().then((cached) {
      if (cached != null && _current(generation) && _signedIn) _showDressed(cached, from: 'cache');
    });
    if (_signedIn) unawaited(refresh());
  }

  void _restart() {
    _generation++;
    _refreshing = null;
    unawaited(refresh());
  }

  void _signedOut(Account was) {
    _generation++;
    _refreshing = null;
    _loginRefreshed = false;
    if (was is LoggedOut || was is LoginExpired) return;
    _logger.info(LogCategory.ui, 'skin stays stock', {'reason': 'logged out', 'shown': _value != null});
    _show(null);
    if (_environment.hasAccountVault) {
      _loading.show(null);
      return;
    }
    unawaited(_exclusive(() => _writeCurrent(null)));
    _loading.hide();
  }

  bool _current(int generation) => generation == _generation && !_disposed;

  /// The account whose skin is shown.
  int? _shownMid;

  void _show(Skin? skin, {String? from}) {
    if (_disposed || identical(skin, _value)) return;
    _value = skin;
    _shownMid = skin == null ? null : _environment.mid ?? _shownMid;
    if (skin != null && from != null) _log(skin, from);
    notifyListeners();
  }

  /// Shows [skin], and with it what its headers are like behind the status bar: kept from the version's first
  /// showing, or measured now. The measure isn't awaited, so the page dresses meanwhile by `color_mode`.
  void _showDressed(Skin skin, {required String from}) {
    _show(skin, from: from);
    if (!identical(_value, skin)) return;
    if (skin.statusBar != null) {
      _logStatus(skin);
    } else {
      final generation = _appearanceGeneration;
      final palette = _palette;
      _measuring = _measuring.then((_) => _measure(skin, palette, generation));
    }
  }

  /// Appearance changes affect transparent headers without changing the equipped package.
  void _appearanceChanged() {
    _appearanceGeneration++;
    _statusLogged = null;
    final skin = _value;
    if (skin != null) _showDressed(skin.withStatusBar(null), from: 'appearance');
  }

  Future<void> _measure(Skin skin, BiliPalette palette, int generation) async {
    if (_disposed || generation != _appearanceGeneration) return;
    final SkinStatusBar status;
    try {
      status = await measureSkinStatusBar(skin, palette: palette);
    } on Exception catch (error) {
      _logger.warn(LogCategory.ui, 'skin status bar not measured', {'error': _describe(error)});
      return;
    } on Error catch (error, stack) {
      CrashLog.report(error, stack, source: 'skin status bar', logger: _logger);
      return;
    }
    if (_disposed || generation != _appearanceGeneration) return;
    final measured = skin.withStatusBar(status);
    _logStatus(measured);
    final shown = _value;
    // A measure that agrees with `color_mode` changes nothing on screen.
    if (shown != null &&
        shown.statusBar == null &&
        _cacheText(shown.equip) == _cacheText(skin.equip) &&
        (measured.lightStatusHome != shown.lightStatusHome ||
            measured.lightStatusFollow != shown.lightStatusFollow ||
            measured.lightStatusMe(card: true) != shown.lightStatusMe(card: true) ||
            measured.lightStatusMe(card: false) != shown.lightStatusMe(card: false))) {
      _show(shown.withStatusBar(status));
    }
    await _exclusive(() => _keepStatus(skin.equip, status, palette));
  }

  /// Once per skin as it changes: never a file's path.
  void _logStatus(Skin skin) {
    final key = _cacheText(skin.equip);
    if (key == _statusLogged) return;
    _statusLogged = key;
    final status = skin.statusBar;
    Object measure(File? picture, double? luminance) => switch ((picture, luminance)) {
      (null, _) => 'none',
      (_, null) => 'unreadable',
      (_, final value?) => (value * 100).round() / 100,
    };
    final video = skin.headMyselfVideo != null;
    _logger.info(LogCategory.ui, 'skin status bar', {
      'home': measure(skin.headBg, status?.home),
      'homeLight': skin.lightStatusHome,
      'follow': measure(skin.headBg, status?.follow),
      'followLight': skin.lightStatusFollow,
      'me': video ? 'color' : measure(skin.headMyself, status?.me),
      'meLight': skin.lightStatusMe(card: true),
      'meNoCard': video ? 'color' : measure(skin.headMyself, status?.meNoCard),
      'meNoCardLight': skin.lightStatusMe(card: false),
    });
  }

  /// Once per skin as it changes: never the package's URL.
  void _log(Skin skin, String from) {
    final key = _cacheText(skin.equip);
    if (key == _logged) return;
    _logged = key;
    final equip = skin.equip;
    final colors = equip.colors;
    final gaps = skinBarGaps(skin);
    _logger.info(LogCategory.ui, 'skin', {
      'from': from,
      'id': equip.id,
      'ver': equip.ver,
      'name': equip.name,
      'primaryOnly': equip.primaryOnly,
      'lightText': colors.lightText,
      'color': _hex(colors.color),
      'colorSecondPage': _hex(colors.colorSecondPage),
      'tailColor': _hex(colors.tailColor),
      'tailColorSelected': _hex(colors.tailColorSelected),
      'tailIconTinted': colors.tailIconTinted,
      'tailIconAnimated': colors.tailIconAnimated,
      'bar': gaps.isEmpty ? 'themed' : 'stock, without ${gaps.join(', ')}',
      'files': [
        for (final MapEntry(key: stem, value: file) in skin.files.entries) '$stem ${_extension(file)} ${_size(file)}',
      ].join(', '),
    });
  }

  static String _hex(int? argb) => argb == null ? 'none' : '#${argb.toRadixString(16).padLeft(8, '0')}';

  static String _extension(File file) {
    final name = _nameOf(file.path);
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '-' : name.substring(dot + 1);
  }

  static int _size(File file) {
    try {
      return file.lengthSync();
    } on FileSystemException {
      return -1;
    }
  }

  /// A transport's own words carry the request's URL, and a file error the container's path.
  static String _describe(Object error) => switch (error) {
    SkinPackageError(:final reason) => reason,
    StatusBarMeasureError() => '$error',
    BiliError() => '$error',
    FileSystemException(:final message, :final osError) => osError == null ? message : '$message: ${osError.message}',
    FormatException(:final message) => message,
    _ => '${error.runtimeType}',
  };

  @override
  void dispose() {
    _disposed = true;
    if (_started != null) {
      appearance?.removeListener(_appearanceChanged);
      _environment.removeListener(_accountChanged);
      _environment.logins.removeListener(_loginCompleted);
      _environment.sessions.removeListener(_sessionChanged);
      _loading.shown.removeListener(_loadingShown);
    }
    _loading.dispose();
    super.dispose();
  }
}

/// What `current.json` keeps of an equip: everything but the package's URL, which is needed only to download.
Map<String, Object?> _cacheJson(SkinEquip equip) {
  final colors = equip.colors;
  return {
    'id': equip.id,
    'name': equip.name,
    'ver': equip.ver,
    'md5': equip.packageMd5.trim().toLowerCase(),
    'primaryOnly': equip.primaryOnly,
    'colors': {
      'color': colors.color,
      'colorSecondPage': colors.colorSecondPage,
      'lightText': colors.lightText,
      'tailColor': colors.tailColor,
      'tailColorSelected': colors.tailColorSelected,
      'tailIconTinted': colors.tailIconTinted,
      'tailIconColor': colors.tailIconColor,
      'tailIconColorSelected': colors.tailIconColorSelected,
      'tailIconAnimated': colors.tailIconAnimated,
      'tailIconCycle': colors.tailIconCycle,
      'headMyselfVideoLoop': colors.headMyselfVideoLoop,
    },
  };
}

String _cacheText(SkinEquip equip) => jsonEncode(_cacheJson(equip));

SkinEquip? _equipFromCache(Object? json) {
  if (json == null) return null;
  if (json is! Map<String, Object?>) throw const FormatException('equip not an object');
  final colors = json['colors'];
  if (colors is! Map<String, Object?>) throw const FormatException('colors not an object');
  T need<T>(Map<String, Object?> map, String key) =>
      map[key] is T ? map[key] as T : throw FormatException('$key missing');
  int? color(String key) => colors[key] is int ? colors[key] as int : null;
  bool flag(String key) => colors[key] == true;
  return SkinEquip(
    id: need<int>(json, 'id'),
    name: need<String>(json, 'name'),
    ver: need<int>(json, 'ver'),
    packageUrl: '',
    packageMd5: need<String>(json, 'md5'),
    primaryOnly: json['primaryOnly'] == true,
    colors: SkinColors(
      color: color('color'),
      colorSecondPage: color('colorSecondPage'),
      lightText: flag('lightText'),
      tailColor: color('tailColor'),
      tailColorSelected: color('tailColorSelected'),
      tailIconTinted: flag('tailIconTinted'),
      tailIconColor: color('tailIconColor'),
      tailIconColorSelected: color('tailIconColorSelected'),
      tailIconAnimated: flag('tailIconAnimated'),
      tailIconCycle: flag('tailIconCycle'),
      headMyselfVideoLoop: flag('headMyselfVideoLoop'),
    ),
  );
}
