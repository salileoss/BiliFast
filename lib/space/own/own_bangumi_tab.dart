import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../space_api.dart';
import 'own_tab_cards.dart';
import 'own_tab_paging.dart';

/// 追番 (117): three posters a row with the title and progress over each, paged, ending in 再怎么找也没有啦. 番剧 isn't
/// built, so a poster says so.
class OwnBangumiSliver extends StatefulWidget {
  const OwnBangumiSliver({super.key, required this.pager});

  final OwnBangumiPager pager;

  static const endMessage = '再怎么找也没有啦';

  /// What the posters lie on.
  static const fill = OwnSpaceTabsTheme.greyPage;
  static Color fillOf(BuildContext context) => OwnSpaceTabsTheme.colorsOf(context).greyPage;

  @override
  State<OwnBangumiSliver> createState() => _OwnBangumiSliverState();
}

/// 追番's posters, kept by the page. The call needs the app token.
final class OwnBangumiPager extends OwnPager<SpaceBangumiCard> {
  OwnBangumiPager({required this.api, required this.mid, super.authorize});

  final SpaceApi api;
  final int mid;

  @override
  String get name => 'own bangumi';

  @override
  Object idOf(SpaceBangumiCard item) => item.seasonId;

  @override
  Future<OwnPage<SpaceBangumiCard>> fetchPage(int page) async {
    final answer = await api.bangumi(mid, page: page);
    return (items: answer.items, hasMore: answer.hasMore);
  }
}

class _OwnBangumiSliverState extends State<OwnBangumiSliver> with OwnPagerView<OwnBangumiSliver, SpaceBangumiCard> {
  @override
  OwnBangumiPager get pager => widget.pager;

  @override
  Widget build(BuildContext context) {
    final pager = this.pager;
    final posters = pager.items;
    final failed = pager.failed;
    final rows = (posters.length + 2) ~/ 3;
    final end = ownStyle(OwnSpaceTabsTheme.endText, OwnSpaceTabsTheme.colorsOf(context).endInk, line: OwnSpaceTabsTheme.endLine);
    const endTop = OwnSpaceTabsTheme.endCentre - OwnSpaceTabsTheme.endLine / 2;
    return DecoratedSliver(
      decoration: BoxDecoration(color: OwnBangumiSliver.fillOf(context)),
      sliver: SliverMainAxisGroup(
        slivers: [
          if (posters.isEmpty && (!pager.loaded || failed))
            SliverToBoxAdapter(
              child: OwnFirstLoad(keyPrefix: 'own-bangumi', failed: failed, onRetry: pager.retry),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                OwnSpaceTabsTheme.gutter,
                OwnSpaceTabsTheme.bangumiTop,
                OwnSpaceTabsTheme.gutter,
                0,
              ),
              sliver: SliverList.separated(
                itemCount: rows,
                separatorBuilder: (context, index) => const SizedBox(height: OwnSpaceTabsTheme.posterGap),
                itemBuilder: (context, row) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = row * 3; i < row * 3 + 3; i++) ...[
                      if (i > row * 3) const SizedBox(width: OwnSpaceTabsTheme.posterGap),
                      Expanded(
                        child: i < posters.length
                            ? OwnPoster(
                                key: ValueKey('own-bangumi-${posters[i].seasonId}'),
                                bangumi: posters[i],
                                onTap: () => showToast(context, '暂未开放'),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: pager.loading || failed
                  ? OwnPagingFooter(keyPrefix: 'own-bangumi', failed: failed, onRetry: pager.retry)
                  : !pager.hasMore
                  ? Padding(
                      padding: const EdgeInsets.only(top: endTop, bottom: OwnSpaceTabsTheme.endBottom),
                      child: Text(
                        OwnBangumiSliver.endMessage,
                        key: const ValueKey('own-bangumi-end'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: end,
                        strutStyle: BiliFonts.strut(end),
                      ),
                    )
                  : const SizedBox(height: endTop + OwnSpaceTabsTheme.endLine + OwnSpaceTabsTheme.endBottom),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
          const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
