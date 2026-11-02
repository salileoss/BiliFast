import 'dart:convert' show ascii, latin1;
import 'dart:typed_data';

import 'package:bili_core/devlog.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../shared/theme.dart';
import 'composer_model.dart';

/// Why ⊕'s picker came back short, when it wasn't the viewer cancelling.
enum PickFailure {
  /// Photo access is denied or restricted in 设置.
  noAccess,

  /// Anything else: the picker, reading a file, memory.
  failed,
}

/// What ⊕'s picker brought back: nothing after a cancel, and a [failure] when it couldn't bring everything.
class PicturePick {
  const PicturePick(this.pictures, {this.failure});

  const PicturePick.failed(PickFailure this.failure) : pictures = const [];

  final List<PickedPicture> pictures;
  final PickFailure? failure;
}

/// The composer's ⊕: up to [limit] pictures from the photo library, without asking for library access.
Future<PicturePick> pickPictures({required int limit, ImagePicker? picker}) async {
  if (limit <= 0) return const PicturePick([]);
  final List<XFile> files;
  try {
    files = await (picker ?? ImagePicker()).pickMultiImage(
      limit: limit,
      // The system picker hands over only what was chosen, so iOS asks nothing; full metadata would need access.
      requestFullMetadata: false,
      // Every photo is re-encoded, at quality 1.0 unless told otherwise: well over 10 MB from the phone's camera.
      imageQuality: 90,
    );
  } catch (error) {
    Logger.shared.warn(LogCategory.ui, 'pick pictures failed', {'error': '$error'});
    return PicturePick.failed(_accessDenied(error) ? PickFailure.noAccess : PickFailure.failed);
  }
  final picked = <PickedPicture>[];
  for (final file in files.take(limit)) {
    try {
      final bytes = await file.readAsBytes();
      picked.add(PickedPicture(bytes: withoutLocation(bytes), name: _name(file, bytes)));
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'read picked picture failed', {
        'error': '${error.runtimeType}',
        'read': picked.length,
        'of': files.length,
      });
      return PicturePick(picked, failure: PickFailure.failed);
    }
  }
  return PicturePick(picked);
}

/// image_picker's iOS codes for a library the viewer, or a parental control, has shut.
bool _accessDenied(Object error) =>
    error is PlatformException && (error.code == 'photo_access_denied' || error.code == 'photo_access_restricted');

/// The upload names the picture's type by its extension; a name without one gets it from the bytes.
String _name(XFile file, Uint8List bytes) {
  final name = file.name.isEmpty ? 'picture' : file.name;
  if (name.contains('.')) return name;
  return '$name.${_type(bytes) ?? 'jpg'}';
}

String? _type(Uint8List bytes) {
  final head = bytes.length < 12 ? '' : latin1.decode(bytes.sublist(0, 12));
  return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8
      ? 'jpg'
      : head.startsWith('\x89PNG')
      ? 'png'
      : head.startsWith('GIF8')
      ? 'gif'
      : head.startsWith('RIFF') && head.substring(8) == 'WEBP'
      ? 'webp'
      : null;
}

/// [bytes] with a JPEG's EXIF GPS block emptied and any XMP that mentions GPS dropped, so a photo doesn't post where
/// it was taken. The orientation and the rest of the EXIF stay; an EXIF block that doesn't parse is dropped whole.
Uint8List withoutLocation(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    // image_picker_ios (0.8.13) re-encodes every pick to JPEG, HEIC included, except PNG and GIF, which keep their
    // format and the source's metadata: screenshots and GIFs, so this is rare.
    Logger.shared.warn(LogCategory.ui, 'picture location not checked', {'type': _type(bytes) ?? 'unknown'});
    return bytes;
  }
  Uint8List? edited;
  final dropped = <(int, int)>[];
  var at = 2;
  while (at + 4 <= bytes.length && bytes[at] == 0xFF) {
    final marker = bytes[at + 1];
    // Start of scan or end of image: the metadata segments all come before.
    if (marker == 0xDA || marker == 0xD9) break;
    final length = (bytes[at + 2] << 8) | bytes[at + 3];
    final end = at + 2 + length;
    if (length < 2 || end > bytes.length) {
      // With no telling where this segment ends, the rest stays as it came; what was cleared before it stays cleared.
      Logger.shared.warn(LogCategory.ui, 'picture location check stopped: JPEG segments do not parse', {
        'at': at,
        'size': bytes.length,
      });
      break;
    }
    if (marker == 0xE1 && _startsWith(bytes, at + 4, _exifHeader)) {
      final copy = edited ??= Uint8List.fromList(bytes);
      if (!_clearGps(ByteData.sublistView(copy, at + 4 + _exifHeader.length, end))) {
        Logger.shared.warn(LogCategory.ui, 'picture EXIF does not parse, dropped', {'bytes': length});
        dropped.add((at, end));
      }
    } else if (marker == 0xE1 && _startsWith(bytes, at + 4, _xmpHeader)) {
      if (latin1.decode(bytes.sublist(at + 4, end)).contains('GPS')) dropped.add((at, end));
    }
    at = end;
  }
  if (edited == null && dropped.isEmpty) return bytes;
  final source = edited ?? bytes;
  if (dropped.isEmpty) return source;
  final out = BytesBuilder(copy: false);
  var from = 0;
  for (final (start, end) in dropped) {
    out.add(Uint8List.sublistView(source, from, start));
    from = end;
  }
  out.add(Uint8List.sublistView(source, from));
  return out.takeBytes();
}

final _exifHeader = ascii.encode('Exif\x00\x00');
final _xmpHeader = ascii.encode('http://ns.adobe.com/xap/1.0/\x00');

bool _startsWith(Uint8List bytes, int at, List<int> prefix) {
  if (at + prefix.length > bytes.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[at + index] != prefix[index]) return false;
  }
  return true;
}

/// Bytes per value of each TIFF field type, by type number.
const _typeSizes = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8};

/// Empties the GPS IFD of the TIFF in [tiff], zeroing its entries and the values they point at, and leaves IFD0's
/// pointer to it in place so readers find an empty block. False when the structure doesn't add up.
bool _clearGps(ByteData tiff) {
  if (tiff.lengthInBytes < 8) return false;
  final Endian endian;
  switch ((tiff.getUint8(0), tiff.getUint8(1))) {
    case (0x49, 0x49):
      endian = Endian.little;
    case (0x4D, 0x4D):
      endian = Endian.big;
    default:
      return false;
  }
  if (tiff.getUint16(2, endian) != 42) return false;
  bool fits(int offset, int length) => offset >= 0 && length >= 0 && offset + length <= tiff.lengthInBytes;

  final ifd0 = tiff.getUint32(4, endian);
  if (!fits(ifd0, 2)) return false;
  final count0 = tiff.getUint16(ifd0, endian);
  if (!fits(ifd0 + 2, count0 * 12)) return false;
  int? gps;
  for (var index = 0; index < count0; index++) {
    final entry = ifd0 + 2 + index * 12;
    if (tiff.getUint16(entry, endian) == 0x8825) gps = tiff.getUint32(entry + 8, endian);
  }
  if (gps == null) return true;
  if (!fits(gps, 2)) return false;
  final count = tiff.getUint16(gps, endian);
  if (!fits(gps + 2, count * 12 + 4)) return false;
  for (var index = 0; index < count; index++) {
    final entry = gps + 2 + index * 12;
    final size = (_typeSizes[tiff.getUint16(entry + 2, endian)] ?? 1) * tiff.getUint32(entry + 4, endian);
    if (size <= 4) continue;
    final offset = tiff.getUint32(entry + 8, endian);
    if (!fits(offset, size)) return false;
    for (var byte = offset; byte < offset + size; byte++) {
      tiff.setUint8(byte, 0);
    }
  }
  for (var byte = gps; byte < gps + 2 + count * 12 + 4; byte++) {
    tiff.setUint8(byte, 0);
  }
  return true;
}

/// The picked pictures under the composer's field, each with a ✕ that takes it out.
class AttachedPictures extends StatelessWidget {
  const AttachedPictures({super.key, required this.pictures, required this.onRemove});

  final List<PickedPicture> pictures;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (pictures.isEmpty) return const SizedBox.shrink();
    // Twice the width it's shown at, so a landscape photo still covers the square once decoded.
    final pixels = (2 * MentionTheme.thumb * MediaQuery.devicePixelRatioOf(context)).ceil();
    return SizedBox(
      height: MentionTheme.thumb + MentionTheme.thumbBottom,
      child: ListView.separated(
        key: const ValueKey('attached-pictures'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: MentionTheme.gutter,
          right: MentionTheme.gutter,
          bottom: MentionTheme.thumbBottom,
        ),
        itemCount: pictures.length,
        separatorBuilder: (context, index) => const SizedBox(width: MentionTheme.thumbGap),
        itemBuilder: (context, index) => _Thumbnail(
          key: ObjectKey(pictures[index]),
          picture: pictures[index],
          number: index + 1,
          pixels: pixels,
          onRemove: () => onRemove(index),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    super.key,
    required this.picture,
    required this.number,
    required this.pixels,
    required this.onRemove,
  });

  final PickedPicture picture;
  final int number;

  /// The width it's decoded at: nine photos decoded at full size would cost hundreds of MB.
  final int pixels;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: MentionTheme.thumb,
    child: Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            container: true,
            image: true,
            label: '图片 $number',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MentionTheme.thumbRadius),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(color: MentionTheme.thumbBorder, width: MentionTheme.thumbBorderWidth),
                  borderRadius: BorderRadius.circular(MentionTheme.thumbRadius),
                ),
                child: Image.memory(
                  picture.bytes,
                  fit: BoxFit.cover,
                  cacheWidth: pixels,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => ColoredBox(color: BiliColors.colorsOf(context).pageGrey),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            container: true,
            button: true,
            label: '删除图片 $number',
            onTap: onRemove,
            excludeSemantics: true,
            child: GestureDetector(
              key: ValueKey('remove-picture-$number'),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: SizedBox.square(
                dimension: MentionTheme.removeHitBox,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: MentionTheme.removeInset, right: MentionTheme.removeInset),
                    width: MentionTheme.removeSize,
                    height: MentionTheme.removeSize,
                    decoration: const BoxDecoration(color: MentionTheme.removeFill, shape: BoxShape.circle),
                    child: const Icon(
                      Icons.close,
                      size: MentionTheme.removeGlyph,
                      color: MentionTheme.removeGlyphColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
