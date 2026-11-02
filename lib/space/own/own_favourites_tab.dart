import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../app/swipe_back_route.dart';
import '../../favourites/favourite_rows.dart' show FavTap;
import '../../favourites/favourites_api.dart';
import '../../favourites/favourites_glyphs.dart';
import '../../favourites/folder_page.dart';
import '../../shared/theme.dart';
import 'own_tab_cards.dart';
import 'own_tab_paging.dart';

/// 收藏 (116): 我创建的收藏夹 with its count, folding and unfolding at a tap, its rows opening the folder. The folders
/// come a page at a time as the list nears the end.
class OwnFavouritesSliver extends StatefulWidget {
  const OwnFavouritesSliver({super.key, required this.pager, this.count});

  final OwnFolderPager pager;

  /// The folders in all, shown until the list is whole; null shows nothing until then.
  final int? count;

  /// What the list lies on.
  static const fill = OwnSpaceTabsTheme.whitePage;
  static Color fillOf(BuildContext context) => OwnSpaceTabsTheme.colorsOf(context).whitePage;

  @override
  State<OwnFavouritesSliver> createState() => _OwnFavouritesSliverState();
}

/// 收藏's folders with their covers, kept by the page.
final class OwnFolderPager extends OwnPager<FavFolder> {
  OwnFolderPager({required this.api, required this.mid, super.authorize});

  final FavouritesApi api;
  final int mid;
  final covers = <int, String>{};

  @override
  String get name => 'own favourites';

  @override
  Object idOf(FavFolder item) => item.id;

  @override
  Future<OwnPage<FavFolder>> fetchPage(int page) async {
    final answer = await api.folders(mid: mid, page: page);
    covers.addAll(answer.covers);
    return (items: answer.folders, hasMore: answer.hasMore);
  }
}

class _OwnFavouritesSliverState extends State<OwnFavouritesSliver> with OwnPagerView<OwnFavouritesSliver, FavFolder> {
  bool _open = true;

  @override
  OwnFolderPager get pager => widget.pager;

  @override
  bool get pagingWanted => _open;

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) checkPagingAfterFrame();
  }

  void _openFolder(FavFolder folder) => unawaited(
    Navigator.of(context).push(
      SwipeBackPageRoute<void>(
        builder: (_) => FolderPage(folder: folder, api: pager.api),
      ),
    ),
  );

  /// The list's own count once it is whole, so the header agrees with its rows; the space's count until then.
  String? get _count {
    if (pager.loaded && !pager.hasMore) return '${pager.items.length}';
    final given = widget.count;
    return given == null ? null : '$given';
  }

  @override
  Widget build(BuildContext context) {
    final pager = this.pager;
    final folders = pager.items;
    final loaded = pager.loaded;
    final failed = pager.failed;
    return DecoratedSliver(
      decoration: BoxDecoration(color: OwnFavouritesSliver.fillOf(context)),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(open: _open, count: _count, onTap: _toggle),
          ),
          const SliverToBoxAdapter(child: _Band()),
          if (_open)
            if (folders.isEmpty)
              SliverToBoxAdapter(
                child: loaded && !failed
                    ? const SizedBox.shrink()
                    : OwnFirstLoad(keyPrefix: 'own-favourites', failed: failed, onRetry: pager.retry),
              )
            else ...[
              SliverList.builder(
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: OwnSpaceTabsTheme.rowGap),
                    child: OwnFolderRow(
                      key: ValueKey('own-favourites-row-${folder.id}'),
                      folder: folder,
                      cover: pager.covers[folder.id] ?? '',
                      onOpen: () => _openFolder(folder),
                    ),
                  );
                },
              ),
              if (pager.loading || failed)
                SliverToBoxAdapter(
                  child: OwnPagingFooter(keyPrefix: 'own-favourites', failed: failed, onRetry: pager.retry),
                ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: OwnSpaceTabsTheme.rowGap),
                  child: _Band(),
                ),
              ),
            ],
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
          const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// ^ 我创建的收藏夹 N; the chevron turns over when the list folds.
class _Header extends StatelessWidget {
  const _Header({required this.open, required this.count, required this.onTap});

  final bool open;
  final String? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = ownStyle(
      OwnSpaceTabsTheme.folderHeaderTitleText,
      OwnSpaceTabsTheme.colorsOf(context).titleInk,
      line: OwnSpaceTabsTheme.headerLine,
    );
    final countStyle = ownStyle(
      OwnSpaceTabsTheme.folderHeaderCountText,
      OwnSpaceTabsTheme.colorsOf(context).countInk,
      line: OwnSpaceTabsTheme.headerLine,
    );
    final count = this.count;
    const middle = OwnSpaceTabsTheme.folderHeaderHeight / 2;
    return FavTap(
      key: const ValueKey('own-favourites-header'),
      label: '我创建的收藏夹${count == null ? '' : '，$count'}',
      selected: open,
      onTap: onTap,
      child: SizedBox(
        height: OwnSpaceTabsTheme.folderHeaderHeight,
        child: Stack(
          children: [
            Positioned(
              left: OwnSpaceTabsTheme.folderChevronLeft,
              top: middle - OwnSpaceTabsTheme.folderChevronHeight / 2,
              child: AnimatedRotation(
                key: const ValueKey('own-favourites-chevron'),
                turns: open ? 0 : 0.5,
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : OwnSpaceTabsTheme.folderChevronTurn,
                // 我的收藏's › turned to stand up as ^.
                child: RotatedBox(
                  quarterTurns: 3,
                  child: FavGlyphIcon(
                    FavGlyph.chevron,
                    width: OwnSpaceTabsTheme.folderChevronHeight,
                    height: OwnSpaceTabsTheme.folderChevronWidth,
                    color: OwnSpaceTabsTheme.colorsOf(context).folderChevronInk,
                    stroke: OwnSpaceTabsTheme.folderChevronStroke,
                  ),
                ),
              ),
            ),
            Positioned(
              left: OwnSpaceTabsTheme.folderHeaderTitleLeft,
              right: OwnSpaceTabsTheme.gutter,
              top: middle - OwnSpaceTabsTheme.headerLine / 2,
              height: OwnSpaceTabsTheme.headerLine,
              child: Row(
                children: [
                  Text('我创建的收藏夹', maxLines: 1, style: title, strutStyle: BiliFonts.strut(title)),
                  if (count != null) ...[
                    const SizedBox(width: OwnSpaceTabsTheme.folderHeaderCountGap),
                    Text(
                      count,
                      key: const ValueKey('own-favourites-count'),
                      maxLines: 1,
                      style: countStyle,
                      strutStyle: BiliFonts.strut(countStyle),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: OwnSpaceTabsTheme.folderBand,
    child: ColoredBox(color: OwnSpaceTabsTheme.colorsOf(context).folderBandInk),
  );
}
