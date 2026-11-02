import 'package:bili_core/api.dart' show DynamicVerify;
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';

/// The bar's ‹, its tip [DynamicPostTheme.backTipX] from the left of a box that starts at the screen's edge.
class PostBackPainter extends CustomPainter {
  final BiliPalette palette;

  const PostBackPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    const tip = DynamicPostTheme.backTipX;
    final path = Path()
      ..moveTo(tip + DynamicPostTheme.backWidth, middle - DynamicPostTheme.backHalfHeight)
      ..lineTo(tip, middle)
      ..lineTo(tip + DynamicPostTheme.backWidth, middle + DynamicPostTheme.backHalfHeight);
    canvas.drawPath(
      path,
      Paint()
        ..color = DynamicPostThemeColors(palette).barInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = DynamicPostTheme.backStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(PostBackPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// The bar's ⋮, centred in its box.
class PostMorePainter extends CustomPainter {
  final BiliPalette palette;

  const PostMorePainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final paint = Paint()..color = DynamicPostThemeColors(palette).barInk;
    for (final step in const [-1, 0, 1]) {
      canvas.drawCircle(centre.translate(0, step * DynamicPostTheme.morePitch), DynamicPostTheme.moreDot / 2, paint);
    }
  }

  @override
  bool shouldRepaint(PostMorePainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// The ⚡ on a verified author's face: blue for an organisation, yellow for a person, in a white ring. Traced from the
/// APK's `ic_authentication_*_size_22` in 66ths of the badge.
class VerifyBadgePainter extends CustomPainter {
  const VerifyBadgePainter(this.verify);

  final DynamicVerify verify;

  static const _bolt = [
    Offset(36, 14.5),
    Offset(33.5, 29.5),
    Offset(47, 29.5),
    Offset(28.5, 50.5),
    Offset(29.5, 35),
    Offset(16, 35),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = size.center(Offset.zero);
    canvas.drawCircle(centre, side / 2, Paint()..color = DynamicPostTheme.badgeBolt);
    final disc = verify == DynamicVerify.organisation
        ? DynamicPostTheme.badgeOrganisation
        : DynamicPostTheme.badgePersonal;
    final ring = DynamicPostTheme.badgeRing * side / DynamicPostTheme.badge;
    canvas.drawCircle(centre, side / 2 - ring, Paint()..color = disc);
    final scale = side / 66;
    final origin = centre - Offset(side / 2, side / 2);
    final bolt = Path()..addPolygon([for (final point in _bolt) origin + point * scale], true);
    canvas.drawPath(bolt, Paint()..color = DynamicPostTheme.badgeBolt);
  }

  @override
  bool shouldRepaint(VerifyBadgePainter oldDelegate) => oldDelegate.verify != verify;
}
