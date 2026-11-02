import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../app/swipe_back_route.dart';
import '../../favourites/favourite_rows.dart' show FavTap;
import '../../favourites/folder_page.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../video/video_route.dart';
import '../space_videos.dart' show OpenSpaceVideo;
import 'own_tab_cards.dart';
import 'own_tab_glyphs.dart';

/// 主页 (114, 115): 收藏, 追番, 最近投币的视频, 最近点赞的视频 and 拥有的个性装扮, each with its count (none on the two
/// video sections) and 更多 ›, from the own space's answer. [onMore] switches to 收藏's or 追番's tab.
///
/// Each section shows one row of what the answer previews and is left out when there is nothing to show. A folder
/// opens its page, a video its page; 追番, 装扮 and the other 更多 aren't built.
class OwnHomeSliver extends StatelessWidget {
  const OwnHomeSliver({super.key, required this.profile, required this.onMore, this.open});

  final SpaceProfile profile;
  final ValueChanged<SpaceTabKind> onMore;

  /// Tests pass their own; null pushes the video page.
  final OpenSpaceVideo? open;

  /// What the sections lie on.
  static const fill = OwnSpaceTabsTheme.greyPage;
  static Color fillOf(BuildContext context) => OwnSpaceTabsTheme.colorsOf(context).greyPage;

  void _soon(BuildContext context) => showToast(context, '暂未开放');

  void _openFolder(BuildContext context, SpaceFolderCard folder) {
    final api = AppScope.of(context).favouritesApi;
    final favFolder = FavFolder(
      id: folder.id,
      title: folder.title,
      count: folder.count,
      isPrivate: folder.isPrivate,
      contains: false,
      isDefault: false,
    );
    unawaited(
      Navigator.of(context).push(
        SwipeBackPageRoute<void>(
          builder: (_) => FolderPage(folder: favFolder, api: api),
        ),
      ),
    );
  }

  void _openVideo(BuildContext context, SpaceVideo video) {
    final route = VideoRoute(bvid: video.bvid, title: video.title, cover: video.cover.isEmpty ? null : video.cover);
    final open = this.open;
    if (open != null) {
      open(context, route);
    } else {
      unawaited(openVideoPage(context, route));
    }
  }

  @override
  Widget build(BuildContext context) {
    final own = profile.own;
    final sections = <Widget>[
      if (own != null) ...[
        if (own.favourites.items.isNotEmpty)
          _Section(
            name: 'favourites',
            title: '收藏',
            count: '${own.favourites.count}',
            hidden: own.favourites.hidden,
            onMore: () => onMore(SpaceTabKind.favourite),
            child: _Pair(
              children: [
                for (final folder in own.favourites.items.take(OwnSpaceTabsTheme.homeFolders))
                  OwnFolderCard(
                    key: ValueKey('own-home-folder-${folder.id}'),
                    folder: folder,
                    onOpen: () => _openFolder(context, folder),
                  ),
              ],
            ),
          ),
        if (own.bangumi.items.isNotEmpty)
          _Section(
            name: 'bangumi',
            title: '追番',
            count: '${own.bangumi.count}',
            hidden: own.bangumi.hidden,
            onMore: () => onMore(SpaceTabKind.bangumi),
            child: _Three(
              gap: OwnSpaceTabsTheme.posterGap,
              children: [
                for (final bangumi in own.bangumi.items.take(OwnSpaceTabsTheme.homeBangumi))
                  OwnPoster(
                    key: ValueKey('own-home-poster-${bangumi.seasonId}'),
                    bangumi: bangumi,
                    onTap: () => _soon(context),
                  ),
              ],
            ),
          ),
        for (final (name, title, section) in [('coins', '最近投币的视频', own.coins), ('likes', '最近点赞的视频', own.likes)])
          if (section.items.isNotEmpty)
            _Section(
              name: name,
              title: title,
              hidden: section.hidden,
              onMore: () => _soon(context),
              child: _Pair(
                children: [
                  for (final video in section.items.take(OwnSpaceTabsTheme.homeVideos))
                    OwnVideoCard(
                      key: ValueKey('own-home-$name-${video.bvid}'),
                      video: video,
                      onOpen: () => _openVideo(context, video),
                    ),
                ],
              ),
            ),
        if (own.garbs.items.isNotEmpty)
          _Section(
            name: 'garbs',
            title: '拥有的个性装扮',
            count: '${own.garbs.count}/${own.garbTotal}',
            hidden: own.garbs.hidden,
            onMore: () => _soon(context),
            child: _Three(
              gap: OwnSpaceTabsTheme.garbGap,
              children: [
                for (final (index, garb) in own.garbs.items.take(OwnSpaceTabsTheme.homeGarbs).indexed)
                  OwnGarbCard(key: ValueKey('own-home-garb-$index'), garb: garb, onTap: () => _soon(context)),
              ],
            ),
          ),
      ],
    ];
    return DecoratedSliver(
      decoration: BoxDecoration(color: OwnHomeSliver.fillOf(context)),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
          const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// A header over one row of cards: the title, its count and the eye-slash when the section is hidden from others, and
/// 更多 › at the right.
class _Section extends StatelessWidget {
  const _Section({
    required this.name,
    required this.title,
    this.count,
    required this.hidden,
    required this.onMore,
    required this.child,
  });

  final String name;
  final String title;
  final String? count;
  final bool hidden;
  final VoidCallback onMore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ownStyle(
      OwnSpaceTabsTheme.titleText,
      OwnSpaceTabsTheme.colorsOf(context).titleInk,
      line: OwnSpaceTabsTheme.headerLine,
    );
    final countStyle = ownStyle(
      OwnSpaceTabsTheme.countText,
      OwnSpaceTabsTheme.colorsOf(context).countInk,
      line: OwnSpaceTabsTheme.headerLine,
    );
    final moreStyle = ownStyle(
      OwnSpaceTabsTheme.moreText,
      OwnSpaceTabsTheme.colorsOf(context).moreInk,
      line: OwnSpaceTabsTheme.headerLine,
    );
    final count = this.count;
    const top = OwnSpaceTabsTheme.headerCentre - OwnSpaceTabsTheme.headerLine / 2;
    return Padding(
      key: ValueKey('own-home-section-$name'),
      padding: const EdgeInsets.only(bottom: OwnSpaceTabsTheme.sectionBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: OwnSpaceTabsTheme.headerHeight,
            child: Stack(
              children: [
                Positioned(
                  left: OwnSpaceTabsTheme.gutter,
                  top: top,
                  height: OwnSpaceTabsTheme.headerLine,
                  child: Row(
                    children: [
                      Text(title, maxLines: 1, style: titleStyle, strutStyle: BiliFonts.strut(titleStyle)),
                      if (count != null) ...[
                        const SizedBox(width: OwnSpaceTabsTheme.countGap),
                        Text(
                          count,
                          key: ValueKey('own-home-count-$name'),
                          maxLines: 1,
                          style: countStyle,
                          strutStyle: BiliFonts.strut(countStyle),
                        ),
                      ],
                      if (hidden) ...[
                        SizedBox(width: count != null ? OwnSpaceTabsTheme.eyeGap : OwnSpaceTabsTheme.countGap),
                        HiddenEye(key: ValueKey('own-home-eye-$name')),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: OwnSpaceTabsTheme.headerCentre - OwnSpaceTabsTheme.headerHeight / 2,
                  height: OwnSpaceTabsTheme.headerHeight,
                  child: FavTap(
                    key: ValueKey('own-home-more-$name'),
                    label: '$title，更多',
                    onTap: onMore,
                    child: Row(
                      children: [
                        const SizedBox(width: OwnSpaceTabsTheme.gutter),
                        Padding(
                          padding: const EdgeInsets.only(bottom: OwnSpaceTabsTheme.moreLift * 2),
                          child: Text('更多', maxLines: 1, style: moreStyle, strutStyle: BiliFonts.strut(moreStyle)),
                        ),
                        const SizedBox(width: OwnSpaceTabsTheme.moreChevronGap),
                        OwnChevron(color: OwnSpaceTabsTheme.colorsOf(context).moreInk),
                        const SizedBox(width: OwnSpaceTabsTheme.moreRight),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OwnSpaceTabsTheme.gutter),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Two cards a row; one alone keeps the left half.
class _Pair extends StatelessWidget {
  const _Pair({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 2; i++) ...[
        if (i > 0) const SizedBox(width: OwnSpaceTabsTheme.pairGap),
        Expanded(child: i < children.length ? children[i] : const SizedBox.shrink()),
      ],
    ],
  );
}

/// Three cards a row, [gap] apart; fewer keep their places from the left.
class _Three extends StatelessWidget {
  const _Three({required this.gap, required this.children});

  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: i < children.length ? children[i] : const SizedBox.shrink()),
      ],
    ],
  );
}
