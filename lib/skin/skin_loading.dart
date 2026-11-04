import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';

import '../shared/theme.dart';
import 'skin_api.dart';
import 'skin_package.dart';

/// What a 加载动画's file is, by its first bytes.
enum SkinLoadingFormat {
  webp,
  gif,
  png,
  apng,
  jpeg,
  zip,
  unknown;

  bool get picture => this != zip && this != unknown;
}

SkinLoadingFormat skinLoadingFormat(Uint8List bytes) {
  bool starts(List<int> magic, [int at = 0]) {
    if (bytes.length < at + magic.length) return false;
    for (var index = 0; index < magic.length; index++) {
      if (bytes[at + index] != magic[index]) return false;
    }
    return true;
  }

  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return _animatedPng(bytes) ? SkinLoadingFormat.apng : SkinLoadingFormat.png;
  }
  if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits)) return SkinLoadingFormat.gif;
  if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8)) return SkinLoadingFormat.webp;
  if (starts(const [0xFF, 0xD8, 0xFF])) return SkinLoadingFormat.jpeg;
  if (starts(const [0x50, 0x4B, 0x03, 0x04])) return SkinLoadingFormat.zip;
  return SkinLoadingFormat.unknown;
}

/// An APNG names its frames (`acTL`) before its first picture data.
bool _animatedPng(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 8;
  while (offset + 8 <= bytes.length) {
    final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
    if (type == 'acTL') return true;
    if (type == 'IDAT') return false;
    offset += 12 + data.getUint32(offset);
  }
  return false;
}

/// A 加载动画 that decodes: its picture, and the first frame decoded to at most [SkinLoadingTheme.decodePixels] a
/// side, which every frame it plays is decoded to as well.
final class SkinLoadingAnimation {
  const SkinLoadingAnimation({
    required this.id,
    required this.ver,
    required this.name,
    required this.picture,
    required this.format,
    required this.frames,
    required this.width,
    required this.height,
    required this.first,
  });

  final int id;
  final int ver;
  final String name;

  /// The file's bytes, or the picture a zip held.
  final Uint8List picture;
  final SkinLoadingFormat format;
  final int frames;

  /// The picture's own size, in pixels.
  final int width;
  final int height;
  final ui.Image first;

  String get key => SkinLoadingKeeper.fileName(id, ver);

  /// The frames from the first, each decoded at [first]'s size. [ui.Codec.getNextFrame] wraps after the last, so it
  /// loops whatever the file's own repeat count.
  Future<ui.Codec> codec() => ui.instantiateImageCodec(picture, targetWidth: first.width, targetHeight: first.height);
}

/// [checkSkinLoading]'s finding: the file's format and, when it can be drawn, the picture with its first frame;
/// otherwise [refusal] says why.
final class SkinLoadingCheck {
  const SkinLoadingCheck._(
    this.format, {
    this.inner,
    this.picture,
    this.frames,
    this.width,
    this.height,
    this.first,
    this.refusal,
  });

  final SkinLoadingFormat format;

  /// The format of the picture a zip held.
  final SkinLoadingFormat? inner;
  final Uint8List? picture;
  final int? frames;
  final int? width;
  final int? height;
  final ui.Image? first;
  final String? refusal;

  SkinLoadingAnimation? animation({required int id, required int ver, required String name}) => switch (first) {
    final first? => SkinLoadingAnimation(
      id: id,
      ver: ver,
      name: name,
      picture: picture!,
      format: inner ?? format,
      frames: frames!,
      width: width!,
      height: height!,
      first: first,
    ),
    null => null,
  };

  /// For the log: never a path or a link.
  Map<String, Object> describe() => {
    'format': format.name,
    'inner': ?inner?.name,
    'frames': ?frames,
    'width': ?width,
    'height': ?height,
    'fallback': ?refusal,
  };
}

/// Checks [bytes] can be drawn: a zip's first picture is taken out, then the picture decoded up to its first frame,
/// within [SkinLimits]'s side and frame caps.
Future<SkinLoadingCheck> checkSkinLoading(Uint8List bytes) async {
  final format = skinLoadingFormat(bytes);
  var picture = bytes;
  SkinLoadingFormat? inner;
  if (format == SkinLoadingFormat.zip) {
    final (found, reason) = _firstPicture(bytes);
    if (found == null) return SkinLoadingCheck._(format, refusal: reason);
    picture = found;
    inner = skinLoadingFormat(found);
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(picture);
  final ui.ImageDescriptor descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
  } on Exception {
    return SkinLoadingCheck._(format, inner: inner, refusal: 'not a picture that decodes');
  } finally {
    // The descriptor keeps what it needs of the buffer.
    buffer.dispose();
  }
  final width = descriptor.width;
  final height = descriptor.height;
  SkinLoadingCheck refused(String reason, {int? frames}) =>
      SkinLoadingCheck._(format, inner: inner, frames: frames, width: width, height: height, refusal: reason);
  if (width < 1 || height < 1) return refused('no size');
  if (math.max(width, height) > SkinLimits.loadingSide) return refused('too large a picture');
  final scale = math.min(1.0, SkinLoadingTheme.decodePixels / math.max(width, height));
  final ui.Codec codec;
  try {
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (width * scale).round()),
      targetHeight: math.max(1, (height * scale).round()),
    );
  } on Exception {
    return refused('not a picture that decodes');
  }
  try {
    final frames = codec.frameCount;
    if (frames < 1) return refused('no frames', frames: frames);
    if (frames > SkinLimits.loadingFrames) return refused('too many frames', frames: frames);
    final ui.FrameInfo first;
    try {
      first = await codec.getNextFrame();
    } on Exception {
      return refused('first frame does not decode', frames: frames);
    }
    return SkinLoadingCheck._(
      format,
      inner: inner,
      picture: picture,
      frames: frames,
      width: width,
      height: height,
      first: first.image,
    );
  } finally {
    codec.dispose();
  }
}

/// The first entry of [zip], in its own order, that is a picture by its first bytes; or why there is none.
(Uint8List?, String) _firstPicture(Uint8List zip) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zip);
  } on Exception {
    return (null, 'zip unreadable');
  }
  for (final entry in archive) {
    if (!entry.isFile || entry.isSymbolicLink || entry.size > SkinLimits.loadingBytes) continue;
    try {
      final bytes = entry.readBytes();
      if (bytes != null && skinLoadingFormat(bytes).picture) return (bytes, '');
    } on Exception {
      continue;
    } finally {
      entry.closeSync();
    }
  }
  return (null, 'no picture in the zip');
}

/// The equipped 加载动画, kept on the device in the 装扮 folder's `loading`: `current.json` names the one last worn
/// (or none), and each picture is the file `<id>-<ver>`, a zip's picture already taken out. One shows only once its
/// first frame decodes; until then, and whenever it can't, refreshes keep the TV. A new version replaces the file, none
/// worn deletes it, and logging out hides it (the next launch starts without it) but keeps the file for the next
/// login, as the 装扮's packages are kept.
class SkinLoadingKeeper {
  SkinLoadingKeeper({required this._api, required this._root, required this._logger, this.accountMid});

  final SkinApi _api;

  /// The 装扮 folder.
  final Future<String> Function() _root;
  final Logger _logger;
  final int? Function()? accountMid;

  static const folderName = 'loading';
  static const _currentName = 'current.json';

  static String fileName(int id, int ver) => '$id-$ver';

  final _shown = ValueNotifier<SkinLoadingAnimation?>(null);

  ValueListenable<SkinLoadingAnimation?> get shown => _shown;

  /// Pictures that failed this run, by [fileName], until the answer names another.
  final Set<String> _failed = {};

  /// Pictures logged this run, by [fileName].
  final Set<String> _logged = {};

  Future<void> _disk = Future.value();
  bool _disposed = false;

  void show(SkinLoadingAnimation? animation) {
    if (!_disposed) _shown.value = animation;
  }

  /// Hides what is shown and forgets it for the next launch; the file stays.
  void hide() {
    show(null);
    final owner = accountMid?.call();
    unawaited(_exclusive(() => _writeCurrent(null, ownerMid: owner)));
  }

  /// The one worn at the last check, decoded from its file; null when none was or it can't be drawn.
  Future<SkinLoadingAnimation?> readCache() async {
    final owner = accountMid?.call();
    if (accountMid != null && owner == null) return null;
    try {
      final folder = await _folder();
      final file = File('$folder/${_currentFile(owner)}');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) throw const FormatException('not an object');
      final worn = json['loading'];
      if (worn == null) return null;
      if (worn is! Map<String, Object?>) throw const FormatException('loading not an object');
      final (id, ver, name) = (worn['id'], worn['ver'], worn['name']);
      if (id is! int || ver is! int || name is! String) throw const FormatException('loading incomplete');
      final picture = File('$folder/${fileName(id, ver)}');
      if (!await picture.exists()) {
        _logger.warn(LogCategory.ui, 'skin loading stays stock', {'reason': 'cached file missing', 'id': id});
        return null;
      }
      final bytes = await picture.readAsBytes();
      return await _checked(id: id, ver: ver, name: name, bytes: bytes, from: 'cache');
    } on Exception catch (error) {
      _logger.warn(LogCategory.ui, 'skin loading stays stock', {
        'reason': 'cache unreadable',
        'error': _describe(error),
      });
      return null;
    }
  }

  /// Follows the answer: shows its 加载动画 (kept already, or downloaded and checked now) and deletes the others, or
  /// none. A download that fails keeps what is shown; a picture that can't be drawn shows the TV. [current] is false
  /// once the account changed, and nothing then shows.
  Future<void> wear(SkinWorn worn, bool Function() current) async {
    final owner = accountMid?.call();
    if (!current()) return;
    if (worn.loadingError case final reason?) {
      _logger.warn(LogCategory.ui, 'skin loading answer not understood, keeping what is shown', {'reason': reason});
      return;
    }
    final loading = worn.loading;
    if (loading == null) {
      if (_shown.value != null) _logger.info(LogCategory.ui, 'skin loading stays stock', {'reason': 'none worn'});
      show(null);
      await _exclusive(() async {
        if (!current()) return;
        await _writeCurrent(null, ownerMid: owner);
        await _deleteFiles(keep: null);
      });
      return;
    }
    final key = fileName(loading.id, loading.ver);
    if (_shown.value?.key == key || _failed.contains(key)) return;
    final folder = await _folder();
    final kept = File('$folder/$key');
    final Uint8List bytes;
    final String from;
    if (await kept.exists()) {
      bytes = await kept.readAsBytes();
      from = 'kept';
    } else {
      try {
        bytes = await _download(loading);
      } on Exception catch (error) {
        if (error is SkinPackageError && !error.passing) _failed.add(key);
        _logger.warn(LogCategory.ui, 'skin loading not downloaded, keeping what is shown', {
          'id': loading.id,
          'ver': loading.ver,
          'error': _describe(error),
        });
        return;
      }
      from = 'download';
    }
    if (!current()) return;
    final animation = await _checked(id: loading.id, ver: loading.ver, name: loading.name, bytes: bytes, from: from);
    if (!current()) return;
    if (animation == null) {
      _failed.add(key);
      show(null);
      await _exclusive(() async {
        if (!current()) return;
        await _writeCurrent(null, ownerMid: owner);
        await _deleteFiles(keep: null);
      });
      return;
    }
    show(animation);
    await _exclusive(() async {
      if (!current()) return;
      if (from == 'download' && !await _writeFile(kept, animation.picture)) return;
      if (!current()) return;
      await _writeCurrent(animation, ownerMid: owner);
      await _deleteFiles(keep: key);
    });
  }

  Future<Uint8List> _download(SkinLoading loading) async {
    final url = Uri.tryParse(loading.url);
    if (url == null) throw const SkinPackageError('loading link unreadable');
    if (!isSkinPackageUrl(url)) throw SkinPackageError.hostNotAllowed(url, what: 'loading');
    final download = await _api.downloadLoading(url);
    if (download.length > SkinLimits.loadingBytes) throw const SkinPackageError('loading too large');
    return download is Uint8List ? download : Uint8List.fromList(download);
  }

  /// [bytes] checked and logged, once per picture this run; null when it can't be drawn.
  Future<SkinLoadingAnimation?> _checked({
    required int id,
    required int ver,
    required String name,
    required Uint8List bytes,
    required String from,
  }) async {
    final check = await checkSkinLoading(bytes);
    if (_logged.add(fileName(id, ver))) {
      final fields = <String, Object>{
        'from': from,
        'id': id,
        'ver': ver,
        'name': name,
        ...check.describe(),
        'bytes': bytes.length,
      };
      if (check.refusal == null) {
        _logger.info(LogCategory.ui, 'skin loading', fields);
      } else {
        _logger.warn(LogCategory.ui, 'skin loading', fields);
      }
    }
    return check.animation(id: id, ver: ver, name: name);
  }

  Future<String> _folder() async => '${await _root()}/$folderName';

  Future<bool> _writeFile(File file, Uint8List bytes) async {
    try {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      await _retried(() => temporary.rename(file.path));
      return true;
    } on FileSystemException catch (error) {
      _logger.warn(LogCategory.ui, 'skin loading not kept', {'error': _describe(error)});
      return false;
    }
  }

  /// Nothing to forget when nothing was ever kept, so a skin without a 加载动画 leaves no folder.
  String _currentFile(int? owner) => accountMid == null ? _currentName : 'current-$owner.json';

  Future<void> _writeCurrent(SkinLoadingAnimation? animation, {int? ownerMid}) async {
    if (accountMid != null && ownerMid == null) return;
    final currentName = _currentFile(ownerMid);
    try {
      final folder = Directory(await _folder());
      if (animation == null && !await folder.exists()) return;
      await folder.create(recursive: true);
      final temporary = File('${folder.path}/$currentName.tmp');
      final worn = animation == null ? null : {'id': animation.id, 'ver': animation.ver, 'name': animation.name};
      await temporary.writeAsString(jsonEncode({'loading': worn}), flush: true);
      await _retried(() => temporary.rename('${folder.path}/$currentName'));
    } on FileSystemException catch (error) {
      _logger.warn(LogCategory.ui, 'skin loading choice not saved', {'error': _describe(error)});
    }
  }

  /// Every picture but [keep]'s, and any write left half done.
  Future<void> _deleteFiles({required String? keep}) async {
    if (accountMid != null) return;
    var failed = 0;
    try {
      final folder = Directory(await _folder());
      if (!await folder.exists()) return;
      await for (final entity in folder.list(followLinks: false)) {
        final name = entity.path.split(RegExp(r'[\\/]')).last;
        if (name == _currentName || name == keep) continue;
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          failed++;
        }
      }
    } on FileSystemException {
      failed++;
    }
    if (failed > 0) _logger.warn(LogCategory.ui, 'old skin loading files not deleted', {'count': failed});
  }

  Future<T> _exclusive<T>(Future<T> Function() task) {
    final run = _disk.then((_) => task());
    _disk = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Waits for the disk work so far; for tests.
  Future<void> settle() => _disk;

  void dispose() {
    _disposed = true;
    _shown.dispose();
  }

  /// Windows' virus scan holds a file it has just seen written for a moment, and a rename then fails.
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

  /// A transport's own words carry the request's URL, and a file error the container's path.
  static String _describe(Object error) => switch (error) {
    SkinPackageError(:final reason) => reason,
    BiliError() => '$error',
    FileSystemException(:final message, :final osError) => osError == null ? message : '$message: ${osError.message}',
    FormatException(:final message) => message,
    _ => '${error.runtimeType}',
  };
}
