import 'package:flutter/widgets.dart';

import '../search/search_glyphs.dart';
import '../shared/action_glyphs.dart';
import '../shared/menu.dart' show PressHighlight;
import '../shared/theme.dart';
import 'space_video_row.dart' show spaceVideosStyle;

/// What a row's ⋮ popover was closed with.
enum SpaceVideoAction { watchLater, share }

/// A row's ⋮ (74): a white popover under the dots with its arrow pointing up at them, over the dimmed page, holding
/// 添加至稍后再看 and 分享. Where there's no room below it opens above, its arrow pointing down. It pops with the
/// action chosen, or null when the dim is tapped.
class SpaceVideoMenuRoute extends PopupRoute<SpaceVideoAction> {
  SpaceVideoMenuRoute({required this.anchor, required this.reduceMotion});

  /// The ⋮'s tap box on screen; the arrow points at its centre, give or take [SpaceVideosTheme.menuArrowShift].
  final Rect anchor;
  final bool reduceMotion;

  static const height = SpaceVideosTheme.menuRowHeight * 2;

  @override
  Color? get barrierColor => SpaceVideosTheme.menuDim;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => '关闭菜单';

  @override
  Duration get transitionDuration => reduceMotion ? Duration.zero : SpaceVideosTheme.menuIn;

  @override
  Duration get reverseTransitionDuration => reduceMotion ? Duration.zero : SpaceVideosTheme.menuOut;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final centre = anchor.center;
    final below =
        centre.dy + SpaceVideosTheme.menuGap + height <= screen.height - padding.bottom - SpaceVideosTheme.menuMargin;
    final right = (centre.dx + SpaceVideosTheme.menuPastAnchor).clamp(
      SpaceVideosTheme.menuWidth + SpaceVideosTheme.menuMargin,
      screen.width - SpaceVideosTheme.menuMargin,
    );
    final left = right - SpaceVideosTheme.menuWidth;
    final top = below ? centre.dy + SpaceVideosTheme.menuGap : centre.dy - SpaceVideosTheme.menuGap - height;
    final arrowX = centre.dx + SpaceVideosTheme.menuArrowShift - left;
    // It grows out of the arrow's tip.
    final origin = Alignment(arrowX / SpaceVideosTheme.menuWidth * 2 - 1, below ? -1 : 1);
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: SpaceVideosTheme.menuWidth,
          height: height,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              alignment: origin,
              scale: Tween(begin: SpaceVideosTheme.menuStartScale, end: 1.0).animate(animation),
              child: SpaceVideoMenu(arrowX: arrowX, below: below),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;

  CurvedAnimation? _curve;

  @override
  Animation<double> createAnimation() => _curve = CurvedAnimation(
    parent: super.createAnimation(),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }
}

/// The popover's box and its arrow at [arrowX] from its left, on top when [below], else under it; each row pops the
/// route with its action.
class SpaceVideoMenu extends StatelessWidget {
  const SpaceVideoMenu({super.key, required this.arrowX, required this.below});

  final double arrowX;
  final bool below;

  @override
  Widget build(BuildContext context) {
    final shape = _MenuShape(arrowX: arrowX, below: below);
    return CustomPaint(
      key: const ValueKey('space-menu'),
      painter: _MenuPainter(shape, palette: BiliPalette.of(context)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SpaceVideosTheme.menuRadius),
        child: Column(
          children: [
            _MenuRow(
              key: const ValueKey('space-menu-watch-later'),
              label: '添加至稍后再看',
              iconCentre: SpaceVideosTheme.menuWatchLaterCentre,
              icon: SearchGlyphIcon(
                SearchGlyph.watchLater,
                size: SpaceVideosTheme.menuWatchLaterIcon,
                color: SpaceVideosTheme.colorsOf(context).menuIconInk,
              ),
              onTap: () => Navigator.of(context).pop(SpaceVideoAction.watchLater),
            ),
            _MenuRow(
              key: const ValueKey('space-menu-share'),
              label: '分享',
              iconCentre: SpaceVideosTheme.menuShareCentre,
              iconLift: SpaceVideosTheme.menuShareLift,
              icon: ActionIcon(
                ActionGlyph.share,
                solid: false,
                size: SpaceVideosTheme.menuShareIcon,
                color: SpaceVideosTheme.colorsOf(context).menuIconInk,
                stroke: SpaceVideosTheme.menuShareStroke,
              ),
              onTap: () => Navigator.of(context).pop(SpaceVideoAction.share),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.label,
    required this.iconCentre,
    required this.icon,
    required this.onTap,
    this.iconLift = 0,
  });

  final String label;
  final double iconCentre;
  final double iconLift;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = spaceVideosStyle(
      SpaceVideosTheme.menuText,
      SpaceVideosTheme.colorsOf(context).menuInk,
      line: SpaceVideosTheme.menuRowHeight,
    );
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressHighlight(
        onTap: onTap,
        child: SizedBox(
          height: SpaceVideosTheme.menuRowHeight,
          child: Stack(
            children: [
              Positioned(
                left: iconCentre - SpaceVideosTheme.menuIconSlot / 2,
                width: SpaceVideosTheme.menuIconSlot,
                top: -iconLift,
                bottom: iconLift,
                child: Center(child: icon),
              ),
              Positioned(
                left: SpaceVideosTheme.menuTextLeft,
                right: 0,
                top: 0,
                bottom: 0,
                child: Text(label, maxLines: 1, style: style, strutStyle: BiliFonts.strut(style)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The box with its rounded corners and the arrow joined on, as one path.
class _MenuShape {
  const _MenuShape({required this.arrowX, required this.below});

  final double arrowX;
  final bool below;

  Path outline(Size size) {
    final box = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(SpaceVideosTheme.menuRadius)));
    const rise = SpaceVideosTheme.menuArrowHeight;
    final baseY = below ? 0.0 : size.height;
    final tipY = below ? -rise : size.height + rise;
    // Sides at 45°, the tip rounded off by a curve through it.
    const round = SpaceVideosTheme.menuArrowRound;
    final towardBase = below ? round : -round;
    final arrow = Path()
      ..moveTo(arrowX - rise - SpaceVideosTheme.menuArrowFoot, baseY)
      ..lineTo(arrowX - round, tipY + towardBase)
      ..quadraticBezierTo(arrowX, tipY, arrowX + round, tipY + towardBase)
      ..lineTo(arrowX + rise + SpaceVideosTheme.menuArrowFoot, baseY)
      ..close();
    return Path.combine(PathOperation.union, box, arrow);
  }
}

class _MenuPainter extends CustomPainter {
  final BiliPalette palette;

  const _MenuPainter(this.shape, {this.palette = const BiliPalette(Brightness.light)});

  final _MenuShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(shape.outline(size), Paint()..color = SpaceVideosThemeColors(palette).menuFill);
  }

  @override
  bool shouldRepaint(_MenuPainter oldDelegate) =>
      oldDelegate.shape.arrowX != shape.arrowX || oldDelegate.shape.below != shape.below;
}
