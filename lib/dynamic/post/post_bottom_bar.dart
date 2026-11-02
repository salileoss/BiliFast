import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import 'post_author.dart';

/// The bar at the post's bottom (131, 132, 140): 点我发评论, then 💬, ⭐ (only when the post has a 收藏 count) and 👍
/// with their counts, over the home indicator.
class PostBottomBar extends StatelessWidget {
  const PostBottomBar({
    super.key,
    required this.comments,
    required this.favourites,
    required this.likes,
    required this.liked,
    required this.onWrite,
    required this.onComments,
    required this.onFavourite,
    required this.onLike,
  });

  final int comments;

  /// Null hides ⭐ (132).
  final int? favourites;
  final int likes;
  final bool liked;
  final VoidCallback onWrite;
  final VoidCallback onComments;
  final VoidCallback onFavourite;
  final VoidCallback onLike;

  static const prompt = '点我发评论';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final favourites = this.favourites;
    final actions = [
      _Action(
        key: const ValueKey('post-comments'),
        icon: 'assets/images/dynamic/dy_ic_bubble_comment_line_24.png',
        iconWidth: DynamicPostTheme.commentIcon,
        iconCentre: DynamicPostTheme.commentIconCentre,
        count: comments,
        word: '评论',
        onTap: onComments,
      ),
      if (favourites != null)
        _Action(
          key: const ValueKey('post-favourite'),
          icon: 'assets/images/dynamic/dy_ic_star_favorite_line_24.png',
          iconWidth: DynamicPostTheme.starIcon,
          iconCentre: DynamicPostTheme.starIconCentre,
          count: favourites,
          word: '收藏',
          onTap: onFavourite,
        ),
      _Action(
        key: const ValueKey('post-like'),
        icon: liked
            ? 'assets/images/dynamic/dy_ic_hand_thumbsup_fill_24.png'
            : 'assets/images/dynamic/dy_ic_hand_thumbsup_line_24.png',
        iconWidth: DynamicPostTheme.likeIcon,
        iconCentre: DynamicPostTheme.likeIconCentre,
        count: likes,
        word: '点赞',
        on: liked,
        onTap: onLike,
      ),
    ];
    const actionsRight = DynamicPostTheme.lastActionRight - DynamicPostTheme.actionPitch / 2;
    final pillRight =
        actionsRight +
        DynamicPostTheme.actionPitch * actions.length -
        DynamicPostTheme.actionPitch / 2 +
        DynamicPostTheme.pillToAction;
    final promptStyle = postStyle(DynamicPostTheme.pillText, DynamicPostTheme.colorsOf(context).pillInk);
    return ColoredBox(
      key: const ValueKey('post-bottom-bar'),
      color: DynamicPostTheme.colorsOf(context).page,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: DynamicPostTheme.bottomRuleEach,
            child: ColoredBox(color: DynamicPostTheme.colorsOf(context).bottomRule),
          ),
          SizedBox(
            height: DynamicPostTheme.bottomRuleEach,
            child: ColoredBox(color: DynamicPostTheme.colorsOf(context).bottomRuleSoft),
          ),
          SizedBox(
            height: DynamicPostTheme.bottomRow,
            child: Stack(
              children: [
                Positioned(
                  left: DynamicPostTheme.pillLeft,
                  right: pillRight,
                  top: (DynamicPostTheme.bottomRow - DynamicPostTheme.pillHeight) / 2,
                  height: DynamicPostTheme.pillHeight,
                  child: Semantics(
                    button: true,
                    label: prompt,
                    onTap: onWrite,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('post-write'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onWrite,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(color: DynamicPostTheme.colorsOf(context).pillFill, shape: StadiumBorder()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: DynamicPostTheme.pillPadding),
                          child: Align(alignment: Alignment.centerLeft, child: postLine(context, prompt, promptStyle)),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: actionsRight,
                  top: 0,
                  bottom: 0,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
              ],
            ),
          ),
          SizedBox(height: bottom),
        ],
      ),
    );
  }
}

/// An icon with its count under it, in a box [DynamicPostTheme.actionPitch] wide; [word] in place of no count.
class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.iconWidth,
    required this.iconCentre,
    required this.count,
    required this.word,
    required this.onTap,
    this.on = false,
  });

  final String icon;
  final double iconWidth;

  /// How far down the row the icon's middle sits.
  final double iconCentre;
  final int count;
  final String word;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = count > 0 ? CountFormat.short(count) : word;
    const line = DynamicPostTheme.actionCountLine;
    return Semantics(
      button: true,
      selected: on,
      label: count > 0 ? '$word $text' : word,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: DynamicPostTheme.actionPitch,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: iconCentre - DynamicPostTheme.actionPitch / 2,
                height: DynamicPostTheme.actionPitch,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    icon,
                    width: iconWidth,
                    color: on ? DynamicPostTheme.colorsOf(context).actionLiked : DynamicPostTheme.colorsOf(context).actionInk,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              Positioned(
                top: DynamicPostTheme.actionCountCentre - line / 2,
                height: line,
                left: 0,
                right: 0,
                child: Center(
                  child: postLine(
                    context,
                    text,
                    postStyle(
                      DynamicPostTheme.actionCountText,
                      on ? DynamicPostTheme.colorsOf(context).actionLiked : DynamicPostTheme.colorsOf(context).actionCountInk,
                      line: line,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
