import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import '../../skin/skin.dart';
import '../space_header.dart' show spaceLine, spaceStyle;
import '../space_header_glyphs.dart';

/// The scrolled bar's colours. The official app dresses it in the equipped 装扮 when the skin has a package and
/// reaches past the main pages (`colorSecondPage`, with the skin's text colour); otherwise it is white. The status bar
/// over it goes by the fill, as 首页's and 我的's go by their pictures.
final class OwnBarLook {
  const OwnBarLook({required this.fill, required this.ink, required this.lightStatus});

  static const stock = OwnBarLook(fill: OwnSpaceTheme.bar, ink: OwnSpaceTheme.barInk, lightStatus: false);

  factory OwnBarLook.of(Skin? skin, {BuildContext? context}) {
    final page = skin?.equip.colors.colorSecondPage;
    if (skin == null || skin.equip.primaryOnly || page == null) {
      if (context == null) return stock;
      final palette = BiliPalette.of(context);
      return OwnBarLook(fill: OwnSpaceTheme.colorsOf(context).bar, ink: OwnSpaceTheme.colorsOf(context).barInk, lightStatus: palette.isDark);
    }
    final fill = Color(page);
    return OwnBarLook(
      fill: fill,
      ink: skin.color ?? (skin.lightText ? OwnSpaceTheme.barLightInk : context == null ? OwnSpaceTheme.barInk : OwnSpaceTheme.colorsOf(context).barInk),
      lightStatus: SkinStatusBar.whiteOverColor(fill),
    );
  }

  final Color fill;
  final Color ink;

  /// Light status bar text over the bar.
  final bool lightStatus;
}

/// What sits over the top of the own space: 〈, search and ⋮ in dark discs over the banner (108), and, once the header
/// has scrolled away, the bar with the name centred between them (115). The discs fade as the bar comes in.
class OwnSpaceBar extends StatelessWidget {
  const OwnSpaceBar({
    super.key,
    required this.collapsed,
    required this.name,
    required this.look,
    required this.onBack,
    required this.onSoon,
  });

  final bool collapsed;
  final String name;
  final OwnBarLook look;
  final VoidCallback onBack;

  /// Search and ⋮.
  final VoidCallback onSoon;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final centre = top + SpaceTheme.buttonDrop;
    final still = MediaQuery.disableAnimationsOf(context);
    final fade = still ? Duration.zero : SpaceTheme.barFade;
    return SizedBox(
      height: top + SpaceTheme.barRow,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !collapsed,
              child: AnimatedOpacity(
                opacity: collapsed ? 1 : 0,
                duration: fade,
                // Once in, the bar takes the taps meant for what has scrolled under it.
                child: GestureDetector(
                  key: const ValueKey('own-space-bar'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: ColoredBox(color: look.fill),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: centre - SpaceTheme.pillHeight / 2,
            height: SpaceTheme.pillHeight,
            child: ExcludeSemantics(
              excluding: !collapsed,
              child: AnimatedOpacity(
                opacity: collapsed ? 1 : 0,
                duration: fade,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: OwnSpaceTheme.barNameWidth),
                    child: spaceLine(
                      name,
                      spaceStyle(OwnSpaceTheme.barName, look.ink, line: SpaceTheme.pillHeight),
                      key: const ValueKey('own-space-bar-name'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Button(
            key: const ValueKey('own-space-back'),
            label: '返回',
            centreX: SpaceTheme.backCentre,
            centreY: centre,
            glyph: SpaceGlyph.back,
            glyphWidth: SpaceTheme.backWidth,
            glyphHeight: SpaceTheme.backHeight,
            glyphShift: const Offset(SpaceTheme.backGlyphShift, 0),
            collapsed: collapsed,
            ink: look.ink,
            fade: fade,
            onTap: onBack,
          ),
          _Button(
            key: const ValueKey('own-space-search'),
            label: '搜索',
            centreX: -SpaceTheme.searchCentreRight,
            centreY: centre,
            glyph: SpaceGlyph.search,
            glyphWidth: SpaceTheme.searchSize,
            glyphHeight: SpaceTheme.searchSize,
            glyphShift: const Offset(SpaceTheme.searchGlyphShift, SpaceTheme.searchGlyphShift),
            collapsed: collapsed,
            ink: look.ink,
            fade: fade,
            onTap: onSoon,
          ),
          _Button(
            key: const ValueKey('own-space-more'),
            label: '更多',
            centreX: -SpaceTheme.moreCentreRight,
            centreY: centre,
            glyph: SpaceGlyph.more,
            glyphWidth: SpaceTheme.moreDot,
            glyphHeight: SpaceTheme.moreDot + SpaceTheme.moreStep * 2,
            collapsed: collapsed,
            ink: look.ink,
            fade: fade,
            onTap: onSoon,
          ),
        ],
      ),
    );
  }
}

/// A disc with a white glyph over the banner, the bar's ink on the bar. A negative [centreX] counts from the right.
class _Button extends StatelessWidget {
  const _Button({
    super.key,
    required this.label,
    required this.centreX,
    required this.centreY,
    required this.glyph,
    required this.glyphWidth,
    required this.glyphHeight,
    required this.collapsed,
    required this.ink,
    required this.fade,
    required this.onTap,
    this.glyphShift = Offset.zero,
  });

  final String label;
  final double centreX;
  final double centreY;
  final SpaceGlyph glyph;
  final double glyphWidth;
  final double glyphHeight;
  final Offset glyphShift;
  final bool collapsed;
  final Color ink;
  final Duration fade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const half = SpaceTheme.buttonTarget / 2;
    Widget glyphIn(Color color) => Transform.translate(
      offset: glyphShift,
      child: SpaceGlyphIcon(glyph, width: glyphWidth, height: glyphHeight, color: color),
    );
    return Positioned(
      left: centreX >= 0 ? centreX - half : null,
      right: centreX < 0 ? -centreX - half : null,
      top: centreY - half,
      width: SpaceTheme.buttonTarget,
      height: SpaceTheme.buttonTarget,
      child: Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          // Over the banner only the disc answers, so the header's rows keep the taps around it.
          behavior: collapsed ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: collapsed ? 0 : 1,
                duration: fade,
                child: Container(
                  width: SpaceTheme.button,
                  height: SpaceTheme.button,
                  decoration: const BoxDecoration(color: SpaceTheme.buttonFill, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: glyphIn(SpaceTheme.buttonInk),
                ),
              ),
              AnimatedOpacity(opacity: collapsed ? 1 : 0, duration: fade, child: glyphIn(ink)),
            ],
          ),
        ),
      ),
    );
  }
}
