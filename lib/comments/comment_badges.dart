import 'package:bili_core/api.dart' show BiliClient, CommentMember;
import 'package:flutter/widgets.dart';

import '../shared/remote_image.dart';
import '../shared/theme.dart';

/// Characters drawn from blocks, like a pixel font: the LV badge (LV6) and the fan card's number (NO. 017949) have
/// this look in the official app. 1 is narrow, and N, V and 7 have their diagonals, as 13 draws them.
abstract final class SegmentGlyph {
  static const _shapes = <String, List<_Segment>>{
    '0': [.a, .b, .c, .d, .e, .f],
    'O': [.a, .b, .c, .d, .e, .f],
    '1': [.a, .b, .c],
    '2': [.a, .b, .g, .e, .d],
    '3': [.a, .b, .g, .c, .d],
    '4': [.f, .g, .b, .c],
    '5': [.a, .f, .g, .c, .d],
    '6': [.a, .f, .g, .e, .d, .c],
    '7': [.a],
    '8': [.a, .b, .c, .d, .e, .f, .g],
    '9': [.a, .b, .c, .d, .f, .g],
    'C': [.a, .f, .e, .d],
    'L': [.f, .e, .d],
    'N': [.f, .e, .b, .c],
  };

  /// 1's share of a glyph's width.
  static const _narrow = 0.45;

  /// A diagonal's breadth across, against a straight stroke's.
  static const _slant = 1.4;

  /// How wide [character] is drawn among glyphs [width] wide.
  static double glyphWidth(String character, {required double width, required double weight}) => switch (character) {
    '.' => weight,
    '1' => width * _narrow,
    _ => width,
  };

  static double advance(String character, {required double width, required double weight, required double gap}) =>
      glyphWidth(character, width: width, weight: weight) + gap;

  /// One character in [rect], which is [glyphWidth] wide, strokes [weight] thick.
  static void draw(Canvas canvas, String character, Rect rect, double weight, Paint paint) {
    if (character == '.') {
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - weight, weight, weight), paint);
      return;
    }
    final half = rect.height / 2;
    for (final segment in _shapes[character] ?? const <_Segment>[]) {
      canvas.drawRect(switch (segment) {
        _Segment.a => Rect.fromLTWH(rect.left, rect.top, rect.width, weight),
        _Segment.b => Rect.fromLTWH(rect.right - weight, rect.top, weight, half + weight / 2),
        _Segment.c => Rect.fromLTWH(rect.right - weight, rect.top + half - weight / 2, weight, half + weight / 2),
        _Segment.d => Rect.fromLTWH(rect.left, rect.bottom - weight, rect.width, weight),
        _Segment.e => Rect.fromLTWH(rect.left, rect.top + half - weight / 2, weight, half + weight / 2),
        _Segment.f => Rect.fromLTWH(rect.left, rect.top, weight, half + weight / 2),
        _Segment.g => Rect.fromLTWH(rect.left, rect.top + half - weight / 2, rect.width, weight),
      }, paint);
    }
    final across = weight * _slant;
    switch (character) {
      case 'N':
        _band(canvas, rect.topLeft, Offset(rect.right - across, rect.bottom), across, paint);
      case '7':
        _band(
          canvas,
          Offset(rect.right - across, rect.top + weight),
          Offset(rect.left + rect.width * 0.22, rect.bottom),
          across,
          paint,
        );
      case 'V':
        // Straight down for the top half, then in to a point at the bottom.
        final knee = rect.top + half;
        final tip = rect.center.dx - weight / 2;
        canvas
          ..drawRect(Rect.fromLTRB(rect.left, rect.top, rect.left + weight, knee), paint)
          ..drawRect(Rect.fromLTRB(rect.right - weight, rect.top, rect.right, knee), paint);
        _band(canvas, Offset(rect.left, knee), Offset(tip, rect.bottom), weight, paint);
        _band(canvas, Offset(rect.right - weight, knee), Offset(tip, rect.bottom), weight, paint);
    }
  }

  /// A slanted stroke [across] wide whose left edge runs from [from] to [to].
  static void _band(Canvas canvas, Offset from, Offset to, double across, Paint paint) =>
      canvas.drawPath(Path()..addPolygon([from, from.translate(across, 0), to.translate(across, 0), to], true), paint);
}

enum _Segment { a, b, c, d, e, f, g }

/// LV0-LV6 as on 10 and 13: a block in the level's colour, the digit's part a little taller, white block letters.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0, CommentRowTheme.levels.length - 1);
    return Semantics(
      label: 'LV$clamped',
      child: CustomPaint(
        size: const Size(CommentRowTheme.levelWidth, CommentRowTheme.levelHeight),
        painter: _LevelPainter(clamped),
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  const _LevelPainter(this.level);

  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.height / 9;
    final corner = Radius.circular(unit);
    final block = Paint()..color = CommentRowTheme.levels[level];
    canvas
      ..drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, unit, 12 * unit, 8 * unit), corner), block)
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(11 * unit, 0, size.width - 11 * unit, 9 * unit), corner),
        block,
      );
    // Traced on 13's LV5 and LV6 at 12×, in ninths of the badge's height.
    final weight = 1.3 * unit;
    final ink = Paint()..color = CommentRowTheme.levelInk;
    SegmentGlyph.draw(canvas, 'L', Rect.fromLTWH(1.3 * unit, 2.1 * unit, 3.5 * unit, 5.7 * unit), weight, ink);
    SegmentGlyph.draw(canvas, 'V', Rect.fromLTWH(5.9 * unit, 2.1 * unit, 4.4 * unit, 5.7 * unit), weight, ink);
    final digit = '$level';
    final width = SegmentGlyph.glyphWidth(digit, width: 4.5 * unit, weight: weight);
    final digitRect = Rect.fromLTWH(14.65 * unit - width / 2, 1.35 * unit, width, 6.5 * unit);
    SegmentGlyph.draw(canvas, digit, digitRect, weight, ink);
  }

  @override
  bool shouldRepaint(_LevelPainter oldDelegate) => oldDelegate.level != level;
}

/// UP, after the LV badge on the uploader's own comments.
class UpBadge extends StatelessWidget {
  const UpBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: CommentRowTheme.levelHeight,
    padding: const EdgeInsets.symmetric(horizontal: CommentRowTheme.upPadding),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: CommentRowTheme.colorsOf(context).upFill,
      borderRadius: BorderRadius.circular(CommentRowTheme.upRadius),
    ),
    child: Text(
      'UP',
      style: TextStyle(
        fontFamily: BiliFonts.family,
        fontSize: CommentRowTheme.upText,
        fontWeight: FontWeight.w800,
        height: 1,
        color: CommentRowTheme.upInk,
      ),
    ),
  );
}

/// 置顶, set inline before a pinned comment's text so it wraps with it.
class PinnedTag extends StatelessWidget {
  const PinnedTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: CommentRowTheme.pinnedPadding),
    decoration: BoxDecoration(
      border: Border.all(color: CommentRowTheme.colorsOf(context).pinnedInk, width: CommentRowTheme.pinnedBorder),
      borderRadius: BorderRadius.circular(CommentRowTheme.pinnedRadius),
    ),
    child: Text(
      '置顶',
      style: TextStyle(
        fontFamily: BiliFonts.family,
        fontSize: CommentRowTheme.pinnedText,
        height: 1.3,
        leadingDistribution: TextLeadingDistribution.even,
        color: CommentRowTheme.colorsOf(context).pinnedInk,
      ),
    ),
  );
}

/// The avatar, the pendant frame around it, and the pink 大 of 大会员.
class CommentAvatar extends StatelessWidget {
  const CommentAvatar({super.key, required this.member});

  final CommentMember member;

  @override
  Widget build(BuildContext context) {
    final pendant = member.pendant;
    final face = pendant == null ? CommentRowTheme.avatar : CommentRowTheme.pendantAvatar;
    const frame = CommentRowTheme.pendantAvatar * CommentRowTheme.pendantScale;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: CommentRowTheme.avatar,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: face,
              child: ClipOval(child: RemoteImage.avatar(member.face)),
            ),
            if (pendant != null)
              OverflowBox(
                maxWidth: frame,
                maxHeight: frame,
                child: IgnorePointer(
                  child: SizedBox.square(
                    key: const ValueKey('comment-pendant'),
                    dimension: frame,
                    child: DecorImage(pendant),
                  ),
                ),
              ),
            if (member.isVip)
              const Positioned(
                right: CommentRowTheme.vipMarkRight - CommentRowTheme.vipMarkRing,
                bottom: CommentRowTheme.vipMarkBottom - CommentRowTheme.vipMarkRing,
                child: VipMark(),
              ),
          ],
        ),
      ),
    );
  }
}

/// The pink 大 in its white ring.
class VipMark extends StatelessWidget {
  const VipMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('comment-vip'),
    width: CommentRowTheme.vipMark + CommentRowTheme.vipMarkRing * 2,
    height: CommentRowTheme.vipMark + CommentRowTheme.vipMarkRing * 2,
    padding: const EdgeInsets.all(CommentRowTheme.vipMarkRing),
    decoration: const BoxDecoration(color: CommentRowTheme.vipMarkRim, shape: BoxShape.circle),
    child: DecoratedBox(
      decoration: BoxDecoration(color: CommentRowTheme.colorsOf(context).vipMarkFill, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '大',
          style: TextStyle(
            fontFamily: BiliFonts.family,
            fontSize: CommentRowTheme.vipMarkText,
            fontWeight: FontWeight.w700,
            height: 1,
            color: CommentRowTheme.vipMarkInk,
          ),
        ),
      ),
    ),
  );
}

/// The fan card's art at its own aspect from its left edge, with its number in two lines over the right part (10, 13).
class FanCard extends StatelessWidget {
  const FanCard({super.key, required this.image, this.number, this.color});

  final String image;
  final String? number;

  /// The number's colour as the server writes it, such as "#f35543".
  final String? color;

  /// "#f35543" as a colour; null for anything else.
  static Color? cssColour(String? css) {
    if (css == null || css.length != 7 || !css.startsWith('#')) return null;
    final value = int.tryParse(css.substring(1), radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final number = this.number;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecorImage(image, alignment: Alignment.centerLeft, fit: BoxFit.fitHeight),
            ),
            if (number != null)
              Positioned(
                left: CommentRowTheme.fanNumberLead,
                top: CommentRowTheme.fanNumberTop,
                child: FanNumber(number: number, color: cssColour(color) ?? CommentRowTheme.fanNumber),
              ),
          ],
        ),
      ),
    );
  }
}

/// The fan card's two lines, "NO." over the number, in the card's colour.
class FanNumber extends StatelessWidget {
  const FanNumber({super.key, required this.number, required this.color});

  final String number;
  final Color color;

  static double _width(String line) {
    var width = 0.0;
    for (final character in line.split('')) {
      width += SegmentGlyph.advance(
        character,
        width: CommentRowTheme.fanGlyphWidth,
        weight: CommentRowTheme.fanGlyphWeight,
        gap: CommentRowTheme.fanGlyphGap,
      );
    }
    return line.isEmpty ? 0 : width - CommentRowTheme.fanGlyphGap;
  }

  @override
  Widget build(BuildContext context) {
    final lines = ['NO.', number.toUpperCase()];
    final width = lines.map(_width).reduce((a, b) => a > b ? a : b);
    return CustomPaint(
      size: Size(width, CommentRowTheme.fanGlyphHeight * 2 + CommentRowTheme.fanLineGap),
      painter: _FanNumberPainter(lines, color),
    );
  }
}

class _FanNumberPainter extends CustomPainter {
  const _FanNumberPainter(this.lines, this.color);

  final List<String> lines;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const weight = CommentRowTheme.fanGlyphWeight;
    final ink = Paint()..color = color;
    for (var row = 0; row < lines.length; row++) {
      var x = 0.0;
      final y = row * (CommentRowTheme.fanGlyphHeight + CommentRowTheme.fanLineGap);
      for (final character in lines[row].split('')) {
        final width = SegmentGlyph.glyphWidth(character, width: CommentRowTheme.fanGlyphWidth, weight: weight);
        SegmentGlyph.draw(canvas, character, Rect.fromLTWH(x, y, width, CommentRowTheme.fanGlyphHeight), weight, ink);
        x += width + CommentRowTheme.fanGlyphGap;
      }
    }
  }

  @override
  bool shouldRepaint(_FanNumberPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.lines.join('\n') != lines.join('\n');
}

/// The comment's own thumb (10, 12): rounder and stubbier than the action row's, its cuff marked off by a line. Solid
/// when the viewer has pressed it; [down] is 👎, the same hand upside down.
class CommentThumb extends StatelessWidget {
  const CommentThumb({
    super.key,
    required this.color,
    this.solid = false,
    this.down = false,
    this.width = CommentRowTheme.thumbInk,
  });

  final Color color;
  final bool solid;
  final bool down;
  final double width;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(width, width * _ThumbPainter.aspect),
      painter: _ThumbPainter(color: color, solid: solid, down: down),
    ),
  );
}

class _ThumbPainter extends CustomPainter {
  const _ThumbPainter({required this.color, required this.solid, required this.down});

  final Color color;
  final bool solid;
  final bool down;

  // Traced on 12 at 12×, in its pixels: the ink is 41.35 wide and 38.1 tall, the line 2.75 thick, the cuff's edge at
  // 11.4.
  static const _width = 41.35;
  static const _height = 38.1;
  static const aspect = _height / _width;
  static const _line = 2.75;
  static const _cuffEdge = 11.4;

  static Path _cuff(double right) => Path()
    ..moveTo(right, 13.5)
    ..lineTo(5.4, 13.5)
    ..quadraticBezierTo(1.4, 13.5, 1.4, 17.5)
    ..lineTo(1.4, 32.7)
    ..quadraticBezierTo(1.4, 36.7, 5.4, 36.7)
    ..lineTo(right, 36.7);

  static Path _hand(double left) => Path()
    ..moveTo(left, 36.7)
    ..lineTo(left, 13.5)
    ..lineTo(13.6, 13.5)
    ..lineTo(20.4, 4.0)
    ..cubicTo(21.4, 2.2, 22.4, 1.4, 23.6, 1.4)
    ..cubicTo(25.4, 1.4, 26.4, 2.6, 26.4, 4.5)
    ..lineTo(26.4, 13.5)
    ..lineTo(36.4, 13.5)
    ..quadraticBezierTo(40.4, 13.5, 40.0, 17.0)
    ..lineTo(34.0, 33.5)
    ..quadraticBezierTo(33.0, 36.7, 29.9, 36.7)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _width;
    canvas.save();
    if (down) {
      canvas
        ..translate(0, size.height)
        ..scale(1, -1);
    }
    canvas.scale(scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _line
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (solid) {
      // A sliver of the background between the cuff and the hand, as the official solid thumb has.
      const gap = _line * 0.7;
      final fill = Paint()..color = color;
      final cuff = _cuff(_cuffEdge - gap / 2 - _line / 2)..close();
      final hand = _hand(_cuffEdge + gap / 2 + _line / 2);
      canvas
        ..drawPath(cuff, fill)
        ..drawPath(cuff, stroke)
        ..drawPath(hand, fill)
        ..drawPath(hand, stroke);
    } else {
      canvas
        ..drawPath(_cuff(_cuffEdge), stroke)
        ..drawPath(_hand(_cuffEdge), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.solid != solid || oldDelegate.down != down;
}

/// Transparent art (pendants, fan cards) at its own aspect with nothing behind it, faded in once it arrives.
class DecorImage extends StatefulWidget {
  const DecorImage(this.url, {super.key, this.alignment = Alignment.center, this.fit = BoxFit.contain});

  final String url;
  final Alignment alignment;
  final BoxFit fit;

  @override
  State<DecorImage> createState() => _DecorImageState();
}

class _DecorImageState extends State<DecorImage> {
  /// The address a frame has shown for: when the page comes back after the memory cache let it go, the Image asks
  /// again and its new stream starts with no frame, but gapless playback still paints the old one, so it stays up
  /// (RemoteImage's faces do the same).
  String? _shown;

  @override
  Widget build(BuildContext context) {
    final address = secureImageUrl(widget.url);
    return Image(
      image: StoredNetworkImage(address, headers: BiliClient.mediaHeaders, still: false),
      fit: widget.fit,
      alignment: widget.alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, synchronous) {
        if (frame != null) _shown = address;
        if (synchronous) return child;
        return AnimatedOpacity(
          opacity: _shown == address ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
  }
}
