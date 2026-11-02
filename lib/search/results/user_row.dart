import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../comments/comment_badges.dart' show LevelBadge;
import '../../shared/menu.dart' show PressHighlight;
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../search_glyphs.dart';
import 'video_row.dart';

/// A 用户 row (60): the avatar with its verified mark, the name and level, the fans and videos, the verification's
/// words if any, and + 关注.
class SearchUserRow extends StatelessWidget {
  const SearchUserRow({super.key, required this.user, required this.onOpen, required this.onFollow});

  final SearchUser user;
  final VoidCallback onOpen;
  final VoidCallback onFollow;

  static const height = SearchResultTheme.userRowHeight;

  @override
  Widget build(BuildContext context) {
    const textLeft = SearchResultTheme.gutter + SearchResultTheme.avatar + SearchResultTheme.userTextGap;
    const textRight = SearchResultTheme.textRight + SearchResultTheme.followWidth + SearchResultTheme.textRight;
    const centre = SearchResultTheme.avatarTop + SearchResultTheme.avatar / 2;
    final desc = user.officialDesc.trim();
    final three = desc.isNotEmpty;
    final countsStyle = searchStyle(
      SearchResultTheme.countsText,
      SearchResultTheme.colorsOf(context).countsInk,
      line: SearchResultTheme.countsLine,
    );

    Widget line(double offset, double height, Widget child) => Positioned(
      left: textLeft,
      right: textRight,
      top: centre + offset - height / 2,
      height: height,
      child: IgnorePointer(child: child),
    );

    Widget grey(String text, String key) => Text.rich(
      dotted(text),
      key: ValueKey(key),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: countsStyle,
      strutStyle: BiliFonts.strut(countsStyle),
    );

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '${user.name}，${SearchFormat.fans(user)}',
              onTap: onOpen,
              excludeSemantics: true,
              child: PressHighlight(
                key: ValueKey('search-user-${user.mid}'),
                onTap: onOpen,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: SearchResultTheme.gutter,
            top: SearchResultTheme.avatarTop,
            width: SearchResultTheme.avatar,
            height: SearchResultTheme.avatar,
            child: IgnorePointer(child: _Avatar(user: user)),
          ),
          line(
            three ? SearchResultTheme.nameCentreThree : SearchResultTheme.nameCentreTwo,
            SearchResultTheme.nameLine,
            _Name(user: user),
          ),
          line(
            three ? SearchResultTheme.countsCentreThree : SearchResultTheme.countsCentreTwo,
            SearchResultTheme.countsLine,
            grey(SearchFormat.fans(user), 'search-user-fans-${user.mid}'),
          ),
          if (three)
            line(
              SearchResultTheme.descCentreThree,
              SearchResultTheme.countsLine,
              grey(desc, 'search-user-desc-${user.mid}'),
            ),
          Positioned(
            right: SearchResultTheme.textRight,
            top: centre - SearchResultTheme.followHeight / 2,
            width: SearchResultTheme.followWidth,
            height: SearchResultTheme.followHeight,
            child: SearchFollowPill(
              key: ValueKey('search-follow-${user.mid}'),
              following: user.following,
              onTap: onFollow,
            ),
          ),
          Positioned(
            left: SearchResultTheme.gutter,
            right: SearchResultTheme.gutter,
            bottom: 0,
            height: SearchResultTheme.hairline,
            child: ColoredBox(color: SearchResultTheme.colorsOf(context).rowHairlineInk),
          ),
        ],
      ),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name({required this.user});

  final SearchUser user;

  @override
  Widget build(BuildContext context) {
    final style = searchStyle(SearchResultTheme.nameText, SearchResultTheme.colorsOf(context).nameInk, line: SearchResultTheme.nameLine);
    return Row(
      children: [
        Flexible(
          child: Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
            strutStyle: BiliFonts.strut(style),
          ),
        ),
        const SizedBox(width: SearchResultTheme.levelGap),
        LevelBadge(level: user.level),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final SearchUser user;

  @override
  Widget build(BuildContext context) {
    final badge = switch (user.officialType) {
      0 => SearchResultTheme.badgePerson,
      1 => SearchResultTheme.badgeOrganisation,
      _ => null,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: ClipOval(child: RemoteImage.avatar(user.face))),
        if (badge != null)
          Positioned(
            right: -SearchResultTheme.badgeRing,
            bottom: -SearchResultTheme.badgeRing,
            child: Container(
              key: ValueKey('search-verified-${user.mid}'),
              width: SearchResultTheme.badge + SearchResultTheme.badgeRing * 2,
              height: SearchResultTheme.badge + SearchResultTheme.badgeRing * 2,
              padding: const EdgeInsets.all(SearchResultTheme.badgeRing),
              decoration: BoxDecoration(color: BiliColors.colorsOf(context).card, shape: BoxShape.circle),
              child: CustomPaint(painter: VerifiedBoltPainter(badge)),
            ),
          ),
      ],
    );
  }
}

/// The verified disc: [color] with a white bolt.
class VerifiedBoltPainter extends CustomPainter {
  const VerifiedBoltPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.drawCircle(size.center(Offset.zero), side / 2, Paint()..color = color);
    Offset at(double x, double y) => Offset(x * side, y * side);
    final bolt = Path()
      ..addPolygon([
        at(0.58, 0.2),
        at(0.27, 0.53),
        at(0.47, 0.53),
        at(0.42, 0.8),
        at(0.74, 0.46),
        at(0.54, 0.46),
      ], true);
    canvas.drawPath(bolt, Paint()..color = SearchResultTheme.badgeBolt);
  }

  @override
  bool shouldRepaint(VerifiedBoltPainter oldDelegate) => oldDelegate.color != color;
}

/// 60's pink "+ 关注", or 简介's grey 已关注 once followed; the change fades and grows in as 简介's does.
class SearchFollowPill extends StatefulWidget {
  const SearchFollowPill({super.key, required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  State<SearchFollowPill> createState() => _SearchFollowPillState();
}

class _SearchFollowPillState extends State<SearchFollowPill> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final following = widget.following;
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : SearchResultTheme.followMotion;
    final ink = following ? SearchResultTheme.colorsOf(context).followedInk : SearchResultTheme.followInk;
    final label = Text(
      following ? '已关注' : '关注',
      style: searchStyle(SearchResultTheme.followText, ink).copyWith(height: 1),
    );
    return Semantics(
      button: true,
      label: following ? '已关注' : '关注',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? SearchResultTheme.followPressedScale : 1,
          duration: still ? Duration.zero : SearchResultTheme.followPressMotion,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: following ? SearchResultTheme.colorsOf(context).followedFill : SearchResultTheme.colorsOf(context).followFill,
              borderRadius: BorderRadius.circular(SearchResultTheme.followHeight / 2),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: SearchResultTheme.followSwapScale, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: following
                  ? KeyedSubtree(key: const ValueKey('followed'), child: label)
                  : Row(
                      key: const ValueKey('follow'),
                      mainAxisSize: MainAxisSize.min,
                      spacing: SearchResultTheme.followPlusGap,
                      children: [
                        SearchGlyphIcon(SearchGlyph.plus, size: SearchResultTheme.followPlus, color: ink),
                        label,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
