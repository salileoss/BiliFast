import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

import '../app/form_factor.dart';
import '../app/phone_frame.dart';
import '../shared/theme.dart';
import 'skin.dart';

/// How a header's picture lies on KaiC's iPhone: cover-fit in [box] from the screen's top-left, cropped about
/// [alignment], over [backdrop].
final class StatusBarPlacement {
  const StatusBarPlacement({required this.box, required this.alignment, required this.backdrop});

  /// 首页's top: `head_bg` down to the top row's bottom, or to 01's hairline when the package has no tab picture,
  /// over the page's grey.
  factory StatusBarPlacement.home({required bool tabPicture, BiliPalette palette = const BiliPalette(Brightness.light)}) => StatusBarPlacement(
    box: Size(_screenWidth, tabPicture ? _statusBar + BiliMetrics.topRowHeight : _homeHairline),
    alignment: Alignment.center,
    backdrop: palette.page,
  );

  /// 关注's header (127): the same `head_bg` down to its own row's bottom, shorter than 首页's top, so the picture
  /// rises less and another band lies behind the status bar; over the page's white.
  factory StatusBarPlacement.follow({BiliPalette palette = const BiliPalette(Brightness.light)}) => StatusBarPlacement(
    box: Size(_screenWidth, _statusBar + DynamicFeedTheme.barRow - DynamicFeedTheme.barRise),
    alignment: Alignment.center,
    backdrop: palette.surface,
  );

  /// 我的's header: from the screen's top down to the list's top, [MeTheme.listCut] under a 大会员 card (109) or, without
  /// one, under where the card would start, cropped at the bottom.
  factory StatusBarPlacement.me({required bool card, BiliPalette palette = const BiliPalette(Brightness.light)}) => StatusBarPlacement(
    box: Size(
      _screenWidth,
      _statusBar + MeTheme.cardTop + (card ? MeTheme.cardHeight : 0) + MeTheme.listCut,
    ),
    alignment: Alignment.topCenter,
    backdrop: palette.surface,
  );

  /// The iPhone's upright width whichever way it is held when the skin is measured; the iPad's as it is held then,
  /// since it shows 首页 and 我的 either way.
  static double get _screenWidth {
    if (!FormFactor.device.isPad) return PhoneFrame.portrait.width;
    final view = PaintingBinding.instance.platformDispatcher.implicitView;
    final width = view == null ? 0.0 : view.physicalSize.width / view.devicePixelRatio;
    return width > 0 ? width : PhoneFrame.padPortrait.width;
  }

  static double get _statusBar =>
      FormFactor.device.isPad ? PhoneFrame.padPadding.top : PhoneFrame.portraitPadding.top;
  static const _homeHairline = 141 + 2 / 3;

  /// Behind the clock and behind the icons on the right, the status bar's height.
  List<Rect> get areas =>
      [Rect.fromLTRB(24, 0, 140, _statusBar), Rect.fromLTRB(box.width - 140, 0, box.width - 24, _statusBar)];

  final Size box;
  final Alignment alignment;
  final Color backdrop;
}

/// [skin]'s headers measured behind the status bar: `head_bg` as 首页 and 关注 cut it, and 我的's picture with the 大会员
/// card and without unless a video plays over it (that one goes by the skin's colour). A read or a decode step that
/// fails throws, so a passing failure is never kept as the picture's.
Future<SkinStatusBar> measureSkinStatusBar(Skin skin, {BiliPalette palette = const BiliPalette(Brightness.light)}) async {
  final home = skin.headBg;
  final me = skin.headMyselfVideo == null ? skin.headMyself : null;
  return SkinStatusBar(
    home: home == null
        ? null
        : await statusBarLuminance(home, StatusBarPlacement.home(tabPicture: skin.headTabBg != null, palette: palette)),
    follow: home == null ? null : await statusBarLuminance(home, StatusBarPlacement.follow(palette: palette)),
    me: me == null ? null : await statusBarLuminance(me, StatusBarPlacement.me(card: true, palette: palette)),
    meNoCard: me == null ? null : await statusBarLuminance(me, StatusBarPlacement.me(card: false, palette: palette)),
  );
}

/// A picture whose header the engine read failed later in its decode. That may pass, so the measure isn't kept.
final class StatusBarMeasureError implements Exception {
  const StatusBarMeasureError(this.step, [this.cause]);

  /// `codec`, `frame` or `pixels`.
  final String step;
  final Object? cause;

  @override
  String toString() => cause == null ? '$step failed' : '$step failed: ${cause.runtimeType}';
}

/// [file] laid as [placement], over the status bar's areas: the geometric mean of L + 0.05 (the contrast ratio's
/// term, L the relative luminance), less 0.05. Null when it isn't a picture the engine can decode; any other failure
/// throws. Decoded at one pixel per point at most, as small as the measure needs.
Future<double?> statusBarLuminance(File file, StatusBarPlacement placement) async {
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
    } on Exception {
      return null;
    }
    final header = descriptor;
    final source = Size(header.width.toDouble(), header.height.toDouble());
    final scale = _coverScale(source, placement.box);
    final decoded = math.min(1.0, scale);
    codec = await _step<ui.Codec>(
      'codec',
      () => header.instantiateCodec(
        targetWidth: math.max(1, (header.width * decoded).round()),
        targetHeight: math.max(1, (header.height * decoded).round()),
      ),
    );
    final image = (await _step('frame', codec.getNextFrame)).image;
    try {
      final data = await _step('pixels', () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba));
      if (data == null) throw const StatusBarMeasureError('pixels');
      final drawn = placement.alignment.inscribe(source * scale, Offset.zero & placement.box);
      return _logAverage(data, image.width, image.height, drawn, placement);
    } finally {
      image.dispose();
    }
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

Future<T> _step<T>(String step, Future<T> Function() run) async {
  try {
    return await run();
  } on Exception catch (error) {
    throw StatusBarMeasureError(step, error);
  }
}

double _coverScale(Size source, Size box) => math.max(box.width / source.width, box.height / source.height);

double? _logAverage(ByteData data, int width, int height, Rect drawn, StatusBarPlacement placement) {
  final pixels = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final backdrop = placement.backdrop;
  final under = [backdrop.r * 255, backdrop.g * 255, backdrop.b * 255];
  var sum = 0.0;
  var count = 0;
  for (final area in placement.areas) {
    final left = ((area.left - drawn.left) * width / drawn.width).floor().clamp(0, width);
    final right = ((area.right - drawn.left) * width / drawn.width).ceil().clamp(0, width);
    final top = ((area.top - drawn.top) * height / drawn.height).floor().clamp(0, height);
    final bottom = ((area.bottom - drawn.top) * height / drawn.height).ceil().clamp(0, height);
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final at = (y * width + x) * 4;
        final alpha = pixels[at + 3] / 255;
        // Blended as the screen blends, in sRGB, then linearised.
        double channel(int index) => _linear[(pixels[at + index] * alpha + under[index] * (1 - alpha)).round()];
        sum += math.log(0.2126 * channel(0) + 0.7152 * channel(1) + 0.0722 * channel(2) + 0.05);
        count++;
      }
    }
  }
  return count == 0 ? null : math.exp(sum / count) - 0.05;
}

final _linear = List<double>.generate(256, (value) {
  final c = value / 255;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}, growable: false);
