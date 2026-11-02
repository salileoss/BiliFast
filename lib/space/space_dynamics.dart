import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/widgets.dart';

import '../dynamic/card/dynamic_card.dart';
import '../dynamic/dynamic_api.dart';
import '../shared/theme.dart';
import 'own/own_tab_cards.dart' show OwnFirstLoad, OwnPagingFooter;
import 'own/own_tab_paging.dart';
import 'space_video_row.dart' show spaceVideosStyle;
import 'space_videos.dart' show SpaceVideosSliver;

/// A space's 动态, kept by the page while it is open: the person's posts, a page at a time from where the last one
/// ended.
final class SpaceDynamicsPager extends OwnPager<DynamicItem> {
  SpaceDynamicsPager({required this.api, required this.mid});

  final DynamicApi api;
  final int mid;

  /// Where the next page starts, as the last page's answer gave it.
  String? _offset;
  int _pages = 0;

  @override
  String get name => 'space dynamics';

  @override
  Object idOf(DynamicItem item) => item.id;

  @override
  Future<OwnPage<DynamicItem>> fetchPage(int page) async {
    final answer = await api.spacePosts(mid, offset: page == 1 ? null : _offset);
    _offset = answer.offset;
    Logger.shared.info(LogCategory.ui, 'space dynamics page', {
      'page': ++_pages,
      'items': answer.items.length,
      'hasMore': answer.hasMore,
      if (answer.skipped.isNotEmpty)
        'skipped': [for (final MapEntry(:key, :value) in answer.skipped.entries) '$key $value'].join(', '),
    });
    // An empty offset would ask for the first page again.
    return (items: answer.items, hasMore: answer.hasMore && answer.offset.isNotEmpty);
  }
}

/// 动态 as slivers in the space's scroll view (136): the posts as cards, each drawing the grey band under itself
/// (`space: true`), on the page's grey, which shows only below the last. First the loading TV, then the small spinner
/// while the next page comes, the failure's own words with 点击重试 (请求过于频繁，请稍后再试，点击重试 under risk
/// control), and 投稿's 已经到底啦~ at the end or when there are none. No card plays inline here.
class SpaceDynamicsSliver extends StatefulWidget {
  const SpaceDynamicsSliver({super.key, required this.pager});

  final SpaceDynamicsPager pager;

  /// What the cards lie on.
  static const fill = BiliColors.softGrey;
  static Color fillOf(BuildContext context) => BiliColors.colorsOf(context).softGrey;

  @override
  State<SpaceDynamicsSliver> createState() => _SpaceDynamicsSliverState();
}

class _SpaceDynamicsSliverState extends State<SpaceDynamicsSliver> with OwnPagerView<SpaceDynamicsSliver, DynamicItem> {
  static const _keyPrefix = 'space-dynamics';

  @override
  SpaceDynamicsPager get pager => widget.pager;

  @override
  Widget build(BuildContext context) {
    final pager = this.pager;
    final posts = pager.items;
    final failed = pager.failed;
    return DecoratedSliver(
      decoration: BoxDecoration(color: SpaceDynamicsSliver.fillOf(context)),
      sliver: SliverMainAxisGroup(
        slivers: [
          if (posts.isEmpty && (!pager.loaded || failed))
            SliverToBoxAdapter(
              child: OwnFirstLoad(keyPrefix: _keyPrefix, failed: failed, onRetry: pager.retry, message: pager.failure),
            )
          else if (posts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: SpaceVideosTheme.stateTop),
                child: _End(key: ValueKey('space-dynamics-empty')),
              ),
            )
          else ...[
            SliverList.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return ColoredBox(
                  color: BiliColors.colorsOf(context).card,
                  child: DynamicCard(key: ValueKey('space-dynamic-${post.id}'), item: post, space: true),
                );
              },
            ),
            SliverToBoxAdapter(
              child: pager.loading || failed
                  ? OwnPagingFooter(keyPrefix: _keyPrefix, failed: failed, onRetry: pager.retry, message: pager.failure)
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: SpaceVideosTheme.footerPad),
                      child: pager.hasMore
                          ? const SizedBox(height: SpaceVideosTheme.footerLine)
                          : const _End(key: ValueKey('space-dynamics-end')),
                    ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

/// 已经到底啦~, as 投稿's.
class _End extends StatelessWidget {
  const _End({super.key});

  @override
  Widget build(BuildContext context) {
    final style = spaceVideosStyle(
      SpaceVideosTheme.endText,
      SpaceVideosTheme.colorsOf(context).endInk,
      line: SpaceVideosTheme.footerLine,
    );
    return Text(
      SpaceVideosSliver.endMessage,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: style,
      strutStyle: BiliFonts.strut(style),
    );
  }
}
