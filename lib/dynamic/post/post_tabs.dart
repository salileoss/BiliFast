import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import 'post_author.dart';

/// 评论 N and 赞和转发 N over the comments (132, 140), pinned under the bar once scrolled to (134). 评论 is the one
/// shown; [onReactions] answers 赞和转发.
class PostTabs extends StatelessWidget {
  const PostTabs({super.key, required this.comments, required this.reactions, required this.onReactions});

  final int comments;
  final int reactions;
  final VoidCallback onReactions;

  static String label(String name, int count) => count > 0 ? '$name ${CountFormat.short(count)}' : name;

  @override
  Widget build(BuildContext context) {
    final chosen = postStyle(DynamicPostTheme.tabText, DynamicPostTheme.colorsOf(context).tabChosen);
    final other = postStyle(DynamicPostTheme.tabText, DynamicPostTheme.colorsOf(context).tabInk);
    const half = DynamicPostTheme.tabSpacing / 2;
    final commentsLabel = label('评论', comments);
    final reactionsLabel = label('赞和转发', reactions);
    return ColoredBox(
      color: DynamicPostTheme.colorsOf(context).page,
      child: SizedBox(
        height: DynamicPostTheme.tabsHeight,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: DynamicPostTheme.tabHairline,
              child: ColoredBox(color: DynamicPostTheme.colorsOf(context).tabRule),
            ),
            Positioned(
              left: DynamicPostTheme.tabFirst - half,
              top: 0,
              bottom: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    key: const ValueKey('post-tab-comments'),
                    button: true,
                    selected: true,
                    label: commentsLabel,
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: half),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(commentsLabel, maxLines: 1, softWrap: false, style: chosen),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: DynamicPostTheme.tabHairline,
                            height: DynamicPostTheme.tabUnderline,
                            child: ColoredBox(key: ValueKey('post-tab-underline'), color: DynamicPostTheme.colorsOf(context).tabChosen),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: reactionsLabel,
                    onTap: onReactions,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('post-tab-reactions'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onReactions,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: half),
                        child: Center(
                          widthFactor: 1,
                          child: Text(reactionsLabel, maxLines: 1, softWrap: false, style: other),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [PostTabs] as a sliver header that stays under the bar once the post has scrolled away.
class PostTabsDelegate extends SliverPersistentHeaderDelegate {
  const PostTabsDelegate(this.tabs);

  final PostTabs tabs;

  @override
  double get minExtent => DynamicPostTheme.tabsHeight;

  @override
  double get maxExtent => DynamicPostTheme.tabsHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => tabs;

  @override
  bool shouldRebuild(PostTabsDelegate oldDelegate) =>
      oldDelegate.tabs.comments != tabs.comments || oldDelegate.tabs.reactions != tabs.reactions;
}
