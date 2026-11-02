import 'package:flutter/widgets.dart';

import '../shared/theme.dart';

/// 播放全部's pink ring with its solid ▶ (63, 69), drawn in a [SpaceVideosTheme.playAllRing] square.
class PlayAllGlyph extends StatelessWidget {
  const PlayAllGlyph({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: SpaceVideosTheme.playAllRing,
      child: CustomPaint(painter: _PlayAllPainter(palette: BiliPalette.of(context))),
    ),
  );
}

class _PlayAllPainter extends CustomPainter {
  final BiliPalette palette;

  const _PlayAllPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    const stroke = SpaceVideosTheme.playAllStroke;
    canvas.drawCircle(
      centre,
      (size.shortestSide - stroke) / 2,
      Paint()
        ..color = SpaceVideosThemeColors(palette).playAllGlyphInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    const left = SpaceVideosTheme.playAllTriangleLeft;
    const right = SpaceVideosTheme.playAllTriangleRight;
    const half = SpaceVideosTheme.playAllTriangleHalf;
    final triangle = Path()
      ..moveTo(centre.dx + left, centre.dy - half)
      ..lineTo(centre.dx + right, centre.dy)
      ..lineTo(centre.dx + left, centre.dy + half)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..color = SpaceVideosThemeColors(palette).playAllGlyphInk
        ..style = PaintingStyle.fill,
    );
    // A thin stroke of the same colour rounds the triangle's corners, as the official one's are.
    canvas.drawPath(
      triangle,
      Paint()
        ..color = SpaceVideosThemeColors(palette).playAllGlyphInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = SpaceVideosTheme.playAllTriangleRound
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PlayAllPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// The sort's ≡: three grey bars 4 apart (63, 69).
class SortGlyph extends StatelessWidget {
  const SortGlyph({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: SpaceVideosTheme.sortGlyphWidth,
      height: SpaceVideosTheme.sortGlyphPitch * 2 + SpaceVideosTheme.sortGlyphBar,
      child: CustomPaint(painter: _SortPainter(palette: BiliPalette.of(context))),
    ),
  );
}

class _SortPainter extends CustomPainter {
  final BiliPalette palette;

  const _SortPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = SpaceVideosThemeColors(palette).sortGlyphInk;
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * SpaceVideosTheme.sortGlyphPitch, size.width, SpaceVideosTheme.sortGlyphBar),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SortPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// A row's ⋮: three grey dots centred in the box it gets.
class MoreDotsPainter extends CustomPainter {
  final BiliPalette palette;

  const MoreDotsPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final paint = Paint()..color = SpaceVideosThemeColors(palette).moreInk;
    for (final step in const [-1, 0, 1]) {
      canvas.drawCircle(centre.translate(0, step * SpaceVideosTheme.morePitch), SpaceVideosTheme.moreDot / 2, paint);
    }
  }

  @override
  bool shouldRepaint(MoreDotsPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
