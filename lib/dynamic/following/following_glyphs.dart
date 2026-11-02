import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// The round glass ‹ (129): a disc of the bar's [fill] lifted by white, centred in what it is given.
class FollowingBackPainter extends CustomPainter {
  final BiliPalette palette;

  const FollowingBackPainter({required this.fill, this.palette = const BiliPalette(Brightness.light)});

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    const radius = FollowingListTheme.backDisc / 2;
    final disc = Rect.fromCircle(center: centre, radius: radius);
    canvas
      ..drawCircle(
        centre.translate(0, FollowingListTheme.backShadowDrop),
        radius,
        Paint()
          ..color = FollowingListTheme.backShadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, FollowingListTheme.backShadowBlur / 2),
      )
      // Opaque, so the shadow under it doesn't grey the glass.
      ..drawCircle(centre, radius, Paint()..color = Color.alphaBlend(FollowingListTheme.backLift, fill))
      ..drawCircle(
        centre,
        radius - FollowingListTheme.backRimWidth / 2,
        _stroke(FollowingListTheme.backRim, FollowingListTheme.backRimWidth),
      );
    // The light catches the glass along its top and bottom edges, fading towards the sides.
    final gloss = _stroke(FollowingListTheme.backGloss, FollowingListTheme.backGlossWidth)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FollowingListTheme.backGloss,
          FollowingListTheme.backGloss.withValues(alpha: 0),
          FollowingListTheme.backGloss.withValues(alpha: 0),
          FollowingListTheme.backGloss,
        ],
        stops: const [0, 0.3, 0.7, 1],
      ).createShader(disc);
    canvas.drawCircle(centre, radius - FollowingListTheme.backRimWidth - FollowingListTheme.backGlossWidth / 2, gloss);
    final tip = centre.dx + FollowingListTheme.backTip;
    const end = FollowingListTheme.backTip + FollowingListTheme.backWidth;
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx + end, centre.dy - FollowingListTheme.backHalfHeight)
        ..lineTo(tip, centre.dy)
        ..lineTo(centre.dx + end, centre.dy + FollowingListTheme.backHalfHeight),
      _stroke(FollowingListThemeColors(palette).backInk, FollowingListTheme.backStroke),
    );
  }

  @override
  bool shouldRepaint(FollowingBackPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness || (oldDelegate.fill != fill);
}

/// ▽ after the order, △ while the menu is open; its arms span the box.
class SortChevronPainter extends CustomPainter {
  final BiliPalette palette;

  const SortChevronPainter({required this.open, this.palette = const BiliPalette(Brightness.light)});

  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final top = open ? size.height : 0.0;
    final bottom = open ? 0.0 : size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, top)
        ..lineTo(size.width / 2, bottom)
        ..lineTo(size.width, top),
      _stroke(FollowingListThemeColors(palette).sortChevron, FollowingListTheme.sortChevronStroke),
    );
  }

  @override
  bool shouldRepaint(SortChevronPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness || (oldDelegate.open != open);
}

/// The chosen order's ✓, its arms spanning the box.
class SortCheckPainter extends CustomPainter {
  final BiliPalette palette;

  const SortCheckPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.5)
        ..lineTo(size.width * 0.36, size.height)
        ..lineTo(size.width, 0),
      _stroke(FollowingListThemeColors(palette).menuChosen, FollowingListTheme.checkStroke),
    );
  }

  @override
  bool shouldRepaint(SortCheckPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// The menu's top: the hairline with the notch rising from it at [notchX], white inside, drawn [notch] tall over the
/// row above.
class MenuEdgePainter extends CustomPainter {
  final BiliPalette palette;

  const MenuEdgePainter({required this.notchX, this.palette = const BiliPalette(Brightness.light)});

  final double notchX;

  @override
  void paint(Canvas canvas, Size size) {
    const notch = FollowingListTheme.notchHeight;
    const half = FollowingListTheme.notchWidth / 2;
    final base = notch + FollowingListTheme.barHairline / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, notch, size.width, FollowingListTheme.barHairline),
      Paint()..color = FollowingListThemeColors(palette).hairline,
    );
    final outline = Path()
      ..moveTo(notchX - half, base)
      ..lineTo(notchX, 0)
      ..lineTo(notchX + half, base);
    canvas
      ..drawPath(
        Path()
          ..moveTo(notchX - half - FollowingListTheme.notchRim, base + FollowingListTheme.barHairline)
          ..lineTo(notchX, 0)
          ..lineTo(notchX + half + FollowingListTheme.notchRim, base + FollowingListTheme.barHairline)
          ..close(),
        Paint()..color = FollowingListThemeColors(palette).menuFill,
      )
      ..drawPath(
        outline,
        Paint()
          ..color = FollowingListThemeColors(palette).hairline
          ..style = PaintingStyle.stroke
          ..strokeWidth = FollowingListTheme.notchRim,
      );
  }

  @override
  bool shouldRepaint(MenuEdgePainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness || (oldDelegate.notchX != notchX);
}
