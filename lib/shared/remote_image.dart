import 'dart:async';
import 'dart:io' show IOException;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cover_format.dart';
import 'cover_preset.dart';
import 'image_disk_cache.dart';
import 'theme.dart';

/// Bilibili's JSON hands out `//host/path` and `http://` addresses; iOS wants https. Pictures on i0 and i2 are asked
/// from i1 ([PictureSession.host]), which serves the same paths, so one connection carries them all.
String secureImageUrl(String url) {
  final secure = url.startsWith('//')
      ? 'https:$url'
      : url.startsWith('http://')
      ? 'https://${url.substring('http://'.length)}'
      : url;
  for (final mirror in _pictureMirrors) {
    if (secure.startsWith(mirror)) return 'https://${PictureSession.host}/${secure.substring(mirror.length)}';
  }
  return secure;
}

const _pictureMirrors = ['https://i0.hdslb.com/', 'https://i2.hdslb.com/'];

/// [url] from Bilibili's image CDN scaled and cropped there to [width]×[height] px (`@…w_…h_1c.webp`). Covers take
/// their [CoverPreset], or [coverImageUrl].
String sizedImageUrl(String url, {required int width, required int height}) =>
    suffixedImageUrl(url, '@${width}w_${height}h_1c.webp');

/// A video cover scaled and cropped by the CDN to [width]×[height] px as a quality 90 JPEG (`@…w_…h_1c_90q.jpg`), for
/// a cover whose preset can't be read here ([CoverFormat]) or that asks [CoverPreset.exact]. As sharp as the original
/// scaled, but made for this app alone: ~300 ms to a first byte where a preset takes ~150-175.
String coverImageUrl(String url, {required int width, required int height}) =>
    suffixedImageUrl(url, '@${width}w_${height}h_1c_90q.jpg');

/// [url] with the CDN's processing [suffix] (`@…`), on Bilibili's image hosts and only where the address has none yet.
String suffixedImageUrl(String url, String suffix) {
  final secure = secureImageUrl(url);
  final uri = Uri.tryParse(secure);
  if (uri == null || !uri.host.endsWith('hdslb.com') || uri.hasQuery || uri.path.contains('@')) return secure;
  return '$secure$suffix';
}

/// Fills the box it is given with the image, grey (or [placeholder]) until it arrives and then faded in. Sizes are
/// rounded up to steps, so cards of nearly the same width share one cached download; a [cover] is asked by its
/// [preset].
///
/// Only emotes and 装扮 pictures move; anything else shows its first frame (see [StoredNetworkImage]).
class RemoteImage extends StatelessWidget {
  const RemoteImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.size,
    this.placeholder,
    this.fallback,
    this.fadeIn = true,
    this.overlay,
    this.cdnSuffix,
    this.cover = false,
    this.preset,
  });

  /// An avatar: Bilibili's default face while it loads, if it fails and when there is none.
  const RemoteImage.avatar(this.url, {super.key, this.size})
    : fit = BoxFit.cover,
      placeholder = null,
      fallback = const DefaultAvatar(),
      fadeIn = true,
      overlay = null,
      cdnSuffix = null,
      cover = false,
      preset = null;

  final String? url;
  final BoxFit fit;

  /// Asks for the image at this size instead of the box's, so a box that changes size every frame (a Hero flight)
  /// keeps one download.
  final Size? size;

  /// The CDN's suffix (`@…`) asked for in place of the box's size rounded up, whatever the box: a size the CDN keeps
  /// pre-made answers sooner. A [cover] ignores it.
  final String? cdnSuffix;

  /// A video's cover, decoded to cover its box in device pixels, always still: asked by [preset], which the CDN keeps
  /// made, and an AVIF one decoded by ImageIO ([CoverFormat]); by [CoverPreset.exact] or where AVIF can't be read, at
  /// the box's exact size as JPEG ([coverImageUrl]).
  final bool cover;

  /// The official screen's preset for a [cover]; without one, [CoverPreset.forBox]'s.
  final CoverPreset? preset;

  /// Shown instead of the grey until the image arrives, and if it fails.
  final Widget? placeholder;

  /// Shown in place of the image while it loads, if it fails and for an empty [url]. Unlike [placeholder] it is gone
  /// once the image is in, so it never shows through a transparent one.
  final Widget? fallback;

  /// False shows the picture the frame it arrives, as 推荐's covers do in the official app (14).
  final bool fadeIn;

  /// Drawn over the picture once it is in, never over [placeholder] or [fallback]: a cover's shade.
  final Widget? overlay;

  static const _step = 60;

  /// A failure is logged once per host and status: enough to see a CDN refusing the size suffix.
  static final _loggedFailures = <String>{};

  static int _bucket(double pixels) => pixels.isFinite && pixels > 0 ? ((pixels / _step).ceil() * _step) : 480;

  /// Whole pixels for a cover's side; float error just past a whole pixel (471.0000000000001) adds none.
  static int _exact(double pixels) => pixels.isFinite && pixels > 0 ? math.max((pixels - 0.01).ceil(), 1) : 480;

  @override
  Widget build(BuildContext context) {
    final source = url;
    final fixed = size;
    final instead = fallback;
    final Widget image;
    if (source == null || source.isEmpty) {
      image = instead ?? const SizedBox.expand();
    } else if (fixed != null || (cdnSuffix != null && !cover)) {
      image = _image(context, source, fixed);
    } else {
      image = LayoutBuilder(builder: (context, constraints) => _image(context, source, constraints.biggest));
    }
    final under = placeholder;
    if (under == null) return instead != null ? image : ColoredBox(color: BiliColors.colorsOf(context).pageGrey, child: image);
    return Stack(fit: StackFit.expand, children: [under, image]);
  }

  /// Fetches and decodes [url] as a RemoteImage of [size] or [cdnSuffix] (or a [cover] of [size] and [preset]) shows
  /// it, so that box shows it at once. True once it is ready, false if it failed or there is none; never throws.
  static Future<bool> precache(
    BuildContext context,
    String? url, {
    Size? size,
    String? cdnSuffix,
    bool cover = false,
    CoverPreset? preset,
  }) async {
    if (url == null || url.isEmpty) return false;
    final provider = _provider(context, url, size, cdnSuffix: cdnSuffix, cover: cover, preset: preset);
    var ok = true;
    // Without an onError, precacheImage hands the failure to FlutterError, and CrashLog would log the signed address.
    await precacheImage(
      provider,
      context,
      onError: (error, _) {
        ok = false;
        _logFailure(provider.url, error);
      },
    );
    return ok;
  }

  /// Keyed by the address and a cover's box, so a precache and its draw of one box share one download and one decode.
  static StoredNetworkImage _provider(
    BuildContext context,
    String source,
    Size? logical, {
    String? cdnSuffix,
    bool cover = false,
    CoverPreset? preset,
  }) {
    final suffix = cover ? null : cdnSuffix;
    if (suffix != null) {
      return StoredNetworkImage(
        suffixedImageUrl(source, suffix),
        headers: BiliClient.mediaHeaders,
        still: !animates(source),
      );
    }
    final pixels = (logical ?? Size.infinite) * MediaQuery.devicePixelRatioOf(context);
    if (cover) {
      final width = _exact(pixels.width);
      final height = _exact(pixels.height);
      final box = Size(width.toDouble(), height.toDouble());
      final asked = preset ?? CoverPreset.forBox(box);
      final exact = coverImageUrl(source, width: width, height: height);
      final address = CoverFormat.shared.address(source, asked);
      return StoredNetworkImage(
        address ?? exact,
        headers: BiliClient.mediaHeaders,
        box: box,
        preset: asked,
        jpegFallback: asked.avif && address != null ? exact : null,
      );
    }
    final width = _bucket(pixels.width);
    final height = _bucket(pixels.height);
    return StoredNetworkImage(
      sizedImageUrl(source, width: width, height: height),
      headers: BiliClient.mediaHeaders,
      still: !animates(source),
    );
  }

  Widget _image(BuildContext context, String source, Size? logical) => _Picture(
    image: _provider(context, source, logical, cdnSuffix: cdnSuffix, cover: cover, preset: preset),
    fit: fit,
    fallback: fallback,
    fadeIn: fadeIn,
    overlay: overlay,
  );

  static const _fade = Duration(milliseconds: 150);

  /// The comments' emotes and 装扮 stickers are drawn moving, as in the official app.
  @visibleForTesting
  static bool animates(String url) {
    final path = Uri.tryParse(secureImageUrl(url))?.path ?? '';
    return path.startsWith('/bfs/emote/') || path.startsWith('/bfs/garb/');
  }

  /// The path shows the size suffix; the query, which can carry a signature, never goes in the log.
  static void _logFailure(String address, Object error) {
    final uri = Uri.tryParse(address);
    final host = uri?.host ?? '';
    final status = error is NetworkImageLoadException ? error.statusCode : null;
    final kind = status != null
        ? '$status'
        : error is PictureDownloadException
        ? error.reason
        : '${error.runtimeType}';
    if (!_loggedFailures.add('$host $kind')) return;
    Logger.shared.warn(LogCategory.ui, 'image failed', {
      'host': host,
      'path': uri?.path ?? '',
      if (status != null) 'status': status else 'error': kind,
    });
  }
}

/// A network picture through [ImageDiskCache.shared] (straight from the network without one, as [NetworkImage]).
/// [still] shows only its first frame: the CDN serves a GIF original (a face, a badge) as an animated webp through
/// the size suffix, and a moving picture decodes a frame every few tens of ms for as long as it is on screen. A still
/// one is cached under its own key, so it never shares an entry with the moving one.
class StoredNetworkImage extends ImageProvider<NetworkImage> implements NetworkImage {
  const StoredNetworkImage(this.url, {this.headers, this.still = true, this.box, this.preset, this.jpegFallback});

  @override
  final String url;

  @override
  final Map<String, String>? headers;

  final bool still;

  /// A cover's box in device pixels. A larger answer (a preset, an address that can't take the suffix) is decoded only
  /// as large as covering the box needs, so the box stays in the key. Always still.
  final Size? box;

  /// The preset a cover was asked by, which only names its downloads in `cover downloads`, so it is not in the key.
  final CoverPreset? preset;

  /// Set when [url] is an AVIF: the cover's exact-size JPEG ([coverImageUrl]), drawn in its place when the AVIF is
  /// refused or doesn't decode.
  final String? jpegFallback;

  @override
  double get scale => 1;

  @override
  WebHtmlElementStrategy get webHtmlElementStrategy => WebHtmlElementStrategy.never;

  /// What the image cache holds this picture under.
  NetworkImage get cacheKey => still || box != null ? this : NetworkImage(url, headers: headers);

  @override
  Future<NetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<NetworkImage>(cacheKey);

  @override
  ImageStreamCompleter loadImage(NetworkImage key, ImageDecoderCallback decode) {
    final completer = MultiFrameImageStreamCompleter(codec: _load(decode), scale: scale);
    completer.addEphemeralErrorListener((error, _) {
      // A failed picture must not stay failed in the cache, nor a stored copy that didn't decode be read again.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      if (!_network(error)) unawaited(ImageDiskCache.shared?.forget(url));
    });
    return completer;
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final box = this.box;
    if (box == null) {
      final codec = await decode(await ui.ImmutableBuffer.fromUint8List(await _bytes(url)));
      return still ? _FirstFrame(codec) : codec;
    }
    final jpeg = jpegFallback;
    if (jpeg == null) {
      return _covering(await _bytes(url, onDownloaded: _timed(url.endsWith('.webp') ? 'webp' : 'jpg')), box, decode);
    }
    final avif = CoverFormat.shared.failed(url) ? null : await _avif(box);
    if (avif != null) return avif;
    try {
      return await _covering(await _bytes(jpeg, onDownloaded: _timed('jpg')), box, decode);
    } catch (error) {
      // The completer's error listener forgets [url]'s stored copy, not this one.
      if (!_network(error)) unawaited(ImageDiskCache.shared?.forget(jpeg));
      rethrow;
    }
  }

  /// Null when the AVIF can't be shown and its JPEG is to be asked for; a stored copy that didn't decode is deleted.
  Future<ui.Codec?> _avif(Size box) async {
    PictureDownload? downloaded;
    final Uint8List bytes;
    try {
      bytes = await _bytes(url, onDownloaded: (download) => downloaded = download);
    } on NetworkImageLoadException catch (error) {
      CoverFormat.shared.refused(url, error.statusCode);
      return null;
    }
    final decoded = await CoverFormat.shared.decodeAvif(url, bytes, box.width.round(), box.height.round());
    final preset = this.preset;
    if ((preset, downloaded) case (final preset?, final download?)) {
      CoverFormat.shared.downloaded(preset, 'avif', download, decodeMs: decoded?.decodeMs);
    }
    if (decoded == null) {
      unawaited(ImageDiskCache.shared?.forget(url));
      return null;
    }
    return decoded.codec;
  }

  /// A cover's network download, for `cover downloads` as [format].
  ValueChanged<PictureDownload>? _timed(String format) {
    final preset = this.preset;
    return preset == null ? null : (download) => CoverFormat.shared.downloaded(preset, format, download);
  }

  Future<Uint8List> _bytes(String address, {ValueChanged<PictureDownload>? onDownloaded}) async {
    final stored = ImageDiskCache.shared;
    final bytes = stored != null
        ? await stored.bytes(address, headers: headers, onDownloaded: onDownloaded)
        : await ImageDiskCache.download(Uri.base.resolve(address), headers);
    if (bytes.isEmpty) throw StateError('empty picture');
    return bytes;
  }

  static bool _network(Object error) =>
      error is NetworkImageLoadException || error is TimeoutException || error is IOException;

  static Future<ui.Codec> _covering(Uint8List bytes, Size box, ImageDecoderCallback decode) async {
    final codec = await decode(
      await ui.ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (width, height) => covering(width, height, box),
    );
    return _FirstFrame(codec);
  }

  /// The size a [width] × [height] picture decodes at to cover [box], keeping its shape; its own size when it is no
  /// larger. Only the side that binds is given, so the engine keeps the aspect.
  @visibleForTesting
  static ui.TargetImageSize covering(int width, int height, Size box) {
    if (width <= 0 || height <= 0) return const ui.TargetImageSize();
    final across = box.width / width;
    final down = box.height / height;
    if (math.max(across, down) >= 1) return const ui.TargetImageSize();
    return across >= down
        ? ui.TargetImageSize(width: math.max(box.width.round(), 1))
        : ui.TargetImageSize(height: math.max(box.height.round(), 1));
  }

  @override
  bool operator ==(Object other) =>
      other is StoredNetworkImage &&
      other.url == url &&
      other.still == still &&
      other.box == box &&
      other.jpegFallback == jpegFallback &&
      mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(StoredNetworkImage, url, still, box);

  /// Host and path only: a query can carry a signature.
  @override
  String toString() {
    final uri = Uri.tryParse(url);
    final cover = box;
    return 'StoredNetworkImage("${uri?.host}${uri?.path}", still: $still'
        '${cover == null ? '' : ', box: ${cover.width.round()}×${cover.height.round()}'})';
  }
}

/// One frame, played once, so the image stream never asks for the next.
final class _FirstFrame implements ui.Codec {
  _FirstFrame(this._codec);

  final ui.Codec _codec;

  @override
  int get frameCount => 1;

  @override
  int get repetitionCount => 0;

  @override
  Future<ui.FrameInfo> getNextFrame() => _codec.getNextFrame();

  @override
  void dispose() => _codec.dispose();
}

/// The picture at [image]'s address, faded in the first time. Once a frame of that address has shown, a reload of it
/// (the Image re-resolving when its page comes back and the memory cache has let the picture go) keeps it at full
/// opacity: gapless playback still paints the old frame, but the new stream starts with no frame number.
class _Picture extends StatefulWidget {
  const _Picture({
    required this.image,
    required this.fit,
    required this.fallback,
    required this.fadeIn,
    required this.overlay,
  });

  final StoredNetworkImage image;
  final BoxFit fit;
  final Widget? fallback;
  final bool fadeIn;
  final Widget? overlay;

  @override
  State<_Picture> createState() => _PictureState();
}

class _PictureState extends State<_Picture> {
  String? _shown;

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    // A cover asked at its exact size after its AVIF failed (or AVIF went off) is still the picture already shown.
    final address = image.box == null ? image.url : '${CoverFormat.sameCover(image.url)} ${image.box}';
    final instead = widget.fallback;
    return Image(
      image: image,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      frameBuilder: (context, picture, frame, synchronous) {
        if (frame != null) _shown = address;
        final over = widget.overlay;
        final child = over == null ? picture : Stack(fit: StackFit.expand, children: [picture, over]);
        if (synchronous) return child;
        final loaded = _shown == address;
        if (instead != null) return _FadeOver(loaded: loaded, under: instead, child: child);
        return AnimatedOpacity(
          opacity: loaded ? 1 : 0,
          duration: widget.fadeIn ? RemoteImage._fade : Duration.zero,
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stack) {
        RemoteImage._logFailure(image.url, error);
        return instead ?? const SizedBox.expand();
      },
    );
  }
}

/// The image fading in over [under], which goes once the fade is done.
class _FadeOver extends StatefulWidget {
  const _FadeOver({required this.loaded, required this.under, required this.child});

  final bool loaded;
  final Widget under;
  final Widget child;

  @override
  State<_FadeOver> createState() => _FadeOverState();
}

class _FadeOverState extends State<_FadeOver> {
  // Made already loaded (a picture shown at once, now reloading), there is no fade to wait for.
  late bool _covered = widget.loaded;

  @override
  void didUpdateWidget(_FadeOver oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new address: [under] shows again until it has a frame.
    if (!widget.loaded) _covered = false;
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (!_covered) widget.under,
      AnimatedOpacity(
        opacity: widget.loaded ? 1 : 0,
        duration: RemoteImage._fade,
        curve: Curves.easeOut,
        onEnd: () {
          if (widget.loaded && mounted) setState(() => _covered = true);
        },
        child: widget.child,
      ),
    ],
  );
}

/// Bilibili's default face (PiliPlus's `noface.jpeg`), for an avatar that is loading, failed or missing.
class DefaultAvatar extends StatelessWidget {
  const DefaultAvatar({super.key});

  static const asset = 'assets/images/noface.jpeg';

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    key: const ValueKey('default-avatar'),
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    excludeFromSemantics: true,
  );
}
