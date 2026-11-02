import 'package:flutter/widgets.dart';

import '../shared/remote_image.dart';
import '../shared/theme.dart';
import 'space_header.dart';
import 'space_header_glyphs.dart';

/// What sits over the top of the space: 〈, 私信, search and ⋮ in dark discs over the banner (63), and, once the
/// header has scrolled away, the white bar with the face and + 关注 between them (73). The discs fade as the bar
/// comes in and 私信 goes; the glyphs turn grey.
class SpaceBar extends StatelessWidget {
  const SpaceBar({
    super.key,
    required this.collapsed,
    required this.face,
    required this.onBack,
    required this.onSoon,
    this.following = false,
    this.onFollow,
    this.name,
  });

  /// The white bar is up.
  final bool collapsed;
  final String? face;
  final VoidCallback onBack;

  /// 私信, search and ⋮.
  final VoidCallback onSoon;
  final bool following;

  /// The pill's tap; null while the space loads, when [name] shows instead.
  final VoidCallback? onFollow;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final centre = top + SpaceTheme.buttonDrop;
    final still = MediaQuery.disableAnimationsOf(context);
    final fade = still ? Duration.zero : SpaceTheme.barFade;
    final follow = onFollow;
    final name = this.name;
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
                // Up, the bar takes the taps meant for what has scrolled under it.
                child: GestureDetector(
                  key: const ValueKey('space-bar'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: ColoredBox(color: SpaceTheme.colorsOf(context).bar),
                ),
              ),
            ),
          ),
          if (name != null)
            Positioned(
              left: 0,
              right: 0,
              top: centre - SpaceTheme.pillHeight / 2,
              height: SpaceTheme.pillHeight,
              child: Center(child: _Title(face: face, name: name)),
            )
          else if (follow != null)
            Positioned(
              left: 0,
              right: 0,
              top: centre - SpaceTheme.pillHeight / 2,
              height: SpaceTheme.pillHeight,
              child: IgnorePointer(
                ignoring: !collapsed,
                child: AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: fade,
                  child: Center(child: _Pill(face: face, following: following, onTap: follow)),
                ),
              ),
            ),
          _Button(
            key: const ValueKey('space-back'),
            label: '返回',
            centreX: SpaceTheme.backCentre,
            centreY: centre,
            glyph: SpaceGlyph.back,
            glyphWidth: SpaceTheme.backWidth,
            glyphHeight: SpaceTheme.backHeight,
            glyphShift: const Offset(SpaceTheme.backGlyphShift, 0),
            collapsed: collapsed,
            fade: fade,
            onTap: onBack,
          ),
          if (follow != null || name == null) ...[
            _Button(
              key: const ValueKey('space-chat'),
              label: '私信',
              centreX: -SpaceTheme.chatCentreRight,
              centreY: centre,
              glyph: SpaceGlyph.chat,
              glyphWidth: SpaceTheme.chatWidth,
              glyphHeight: SpaceTheme.chatHeight,
              collapsed: collapsed,
              fade: fade,
              onTap: onSoon,
              goesWhenCollapsed: true,
            ),
            _Button(
              key: const ValueKey('space-search'),
              label: '搜索',
              centreX: -SpaceTheme.searchCentreRight,
              centreY: centre,
              glyph: SpaceGlyph.search,
              glyphWidth: SpaceTheme.searchSize,
              glyphHeight: SpaceTheme.searchSize,
              glyphShift: const Offset(SpaceTheme.searchGlyphShift, SpaceTheme.searchGlyphShift),
              collapsed: collapsed,
              fade: fade,
              onTap: onSoon,
            ),
            _Button(
              key: const ValueKey('space-more'),
              label: '更多',
              centreX: -SpaceTheme.moreCentreRight,
              centreY: centre,
              glyph: SpaceGlyph.more,
              glyphWidth: SpaceTheme.moreDot,
              glyphHeight: SpaceTheme.moreDot + SpaceTheme.moreStep * 2,
              collapsed: collapsed,
              fade: fade,
              onTap: onSoon,
            ),
          ],
        ],
      ),
    );
  }
}

/// One of the four: a disc with a white glyph over the banner, a grey glyph on the bar. A negative [centreX] counts
/// from the right edge.
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
    required this.fade,
    required this.onTap,
    this.glyphShift = Offset.zero,
    this.goesWhenCollapsed = false,
  });

  final String label;
  final double centreX;
  final double centreY;
  final SpaceGlyph glyph;
  final double glyphWidth;
  final double glyphHeight;
  final Offset glyphShift;
  final bool collapsed;
  final Duration fade;
  final VoidCallback onTap;

  /// 私信 isn't on the bar.
  final bool goesWhenCollapsed;

  @override
  Widget build(BuildContext context) {
    const half = SpaceTheme.buttonTarget / 2;
    Widget glyphIn(Color color) => Transform.translate(
      offset: glyphShift,
      child: SpaceGlyphIcon(glyph, width: glyphWidth, height: glyphHeight, color: color),
    );
    final gone = goesWhenCollapsed && collapsed;
    return Positioned(
      left: centreX >= 0 ? centreX - half : null,
      right: centreX < 0 ? -centreX - half : null,
      top: centreY - half,
      width: SpaceTheme.buttonTarget,
      height: SpaceTheme.buttonTarget,
      child: IgnorePointer(
        ignoring: gone,
        child: ExcludeSemantics(
          excluding: gone,
          child: Semantics(
            button: true,
            label: label,
            onTap: onTap,
            excludeSemantics: true,
            child: GestureDetector(
              // Over the banner only the disc answers (its circle decoration is what gets hit): the whole target
              // would take taps meant for + 关注's right end while the header scrolls under it.
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
                  if (!goesWhenCollapsed)
                    AnimatedOpacity(
                      opacity: collapsed ? 1 : 0,
                      duration: fade,
                      child: glyphIn(SpaceTheme.colorsOf(context).barInk),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.face, required this.following, required this.onTap});

  final String? face;
  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = following ? SpaceTheme.colorsOf(context).pillFollowedInk : SpaceTheme.colorsOf(context).pillInk;
    return Semantics(
      button: true,
      label: following ? '已关注' : '关注',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('space-pill'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: SpaceTheme.pillHeight,
          decoration: BoxDecoration(
            color: following ? SpaceTheme.colorsOf(context).pillFollowedFill : SpaceTheme.colorsOf(context).pillFill,
            borderRadius: BorderRadius.circular(SpaceTheme.pillHeight / 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: SpaceTheme.pillFaceInset),
              SizedBox.square(
                dimension: SpaceTheme.pillFace,
                child: ClipOval(child: RemoteImage.avatar(face)),
              ),
              const SizedBox(width: SpaceTheme.pillFaceGap),
              if (!following) ...[
                SpaceGlyphIcon(SpaceGlyph.plus, width: SpaceTheme.pillPlus, height: SpaceTheme.pillPlus, color: ink),
                const SizedBox(width: SpaceTheme.pillPlusGap),
              ],
              spaceLine(following ? '已关注' : '关注', spaceStyle(SpaceTheme.pillText, ink, line: SpaceTheme.pillHeight)),
              const SizedBox(width: SpaceTheme.pillPadRight),
            ],
          ),
        ),
      ),
    );
  }
}

/// While the space loads: the face and the name the tap brought.
class _Title extends StatelessWidget {
  const _Title({required this.face, required this.name});

  final String? face;
  final String name;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: SpaceTheme.loadingNameWidth),
    child: Row(
      key: const ValueKey('space-loading-title'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: SpaceTheme.pillFace,
          child: ClipOval(child: RemoteImage.avatar(face)),
        ),
        const SizedBox(width: SpaceTheme.loadingNameGap),
        Flexible(
          child: spaceLine(
            name,
            spaceStyle(SpaceTheme.loadingNameText, BiliColors.colorsOf(context).text, line: SpaceTheme.pillHeight),
          ),
        ),
      ],
    ),
  );
}
