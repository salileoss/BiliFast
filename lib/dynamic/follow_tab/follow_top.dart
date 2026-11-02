import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../../video/intro/collection_row.dart' show Chevron;
import 'follow_parts.dart';

/// 全部 / 视频 (127, 128): two grey halves, the chosen one's word pink.
class FollowSwitch extends StatelessWidget {
  const FollowSwitch({super.key, required this.type, required this.onSelect});

  final DynamicFeedType type;
  final ValueChanged<DynamicFeedType> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: DynamicFeedTheme.switchHeight,
    child: Row(
      children: [
        Expanded(child: _half(context, DynamicFeedType.all, '全部')),
        const SizedBox(width: DynamicFeedTheme.switchGap),
        Expanded(child: _half(context, DynamicFeedType.video, '视频')),
      ],
    ),
  );

  Widget _half(BuildContext context, DynamicFeedType kind, String label) {
    final on = kind == type;
    return FollowTap(
      key: ValueKey('follow-switch-${kind.rawValue}'),
      label: label,
      selected: on,
      onTap: () => onSelect(kind),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DynamicFeedTheme.colorsOf(context).switchFill,
          borderRadius: BorderRadius.circular(DynamicFeedTheme.switchRadius),
        ),
        child: Center(
          child: Text(
            label,
            style: followStyle(
              DynamicFeedTheme.switchText,
              on ? DynamicFeedTheme.colorsOf(context).switchOn : DynamicFeedTheme.colorsOf(context).switchOff,
              weight: on ? DynamicFeedTheme.switchOnWeight : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// A section's title at its left, and 更多 › or 全部 › at its right when [more] is given.
class FollowSectionTitle extends StatelessWidget {
  const FollowSectionTitle({
    super.key,
    required this.title,
    this.more,
    this.moreKey,
    this.moreText = DynamicFeedTheme.moreText,
    this.moreInk,
    this.moreGap = DynamicFeedTheme.moreGap,
    this.onMore,
  });

  final String title;
  final String? more;
  final Key? moreKey;
  final double moreText;
  final Color? moreInk;
  final double moreGap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final style = followStyle(
      DynamicFeedTheme.sectionText,
      DynamicFeedTheme.colorsOf(context).sectionInk,
      weight: DynamicFeedTheme.sectionWeight,
      height: DynamicFeedTheme.sectionLine / DynamicFeedTheme.sectionText,
    );
    final more = this.more;
    final onMore = this.onMore;
    return SizedBox(
      height: DynamicFeedTheme.sectionLine,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: DynamicFeedTheme.gutter,
            top: 0,
            child: Semantics(
              header: true,
              child: Text(title, style: style, strutStyle: BiliFonts.strutOf(context, style)),
            ),
          ),
          if (more != null && onMore != null)
            Positioned(
              right: 0,
              top: (DynamicFeedTheme.sectionLine - DynamicFeedTheme.moreTarget) / 2,
              height: DynamicFeedTheme.moreTarget,
              child: FollowTap(
                key: moreKey,
                label: more,
                onTap: onMore,
                child: Padding(
                  padding: const EdgeInsets.only(left: DynamicFeedTheme.gutter, right: DynamicFeedTheme.chevronRight),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(more, style: followStyle(moreText, moreInk ?? DynamicFeedTheme.colorsOf(context).moreInk)),
                      SizedBox(width: moreGap),
                      Chevron(
                        size: Size(DynamicFeedTheme.chevronWidth, DynamicFeedTheme.chevronHeight),
                        stroke: DynamicFeedTheme.chevronStroke,
                        color: DynamicFeedTheme.colorsOf(context).chevronInk,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One 最常访问 face: the round face in its ring, the pink dot while it has news, the name under it on up to two lines.
class FollowFace extends StatelessWidget {
  const FollowFace({super.key, required this.up, required this.dot, required this.onTap});

  final DynamicUp up;
  final bool dot;
  final VoidCallback onTap;

  /// The faces row's height: the face, then two lines of name.
  static const rowHeight =
      DynamicFeedTheme.face +
      DynamicFeedTheme.nameCentre -
      DynamicFeedTheme.nameLine / 2 +
      DynamicFeedTheme.nameLine * 2;

  @override
  Widget build(BuildContext context) {
    final style = followStyle(
      DynamicFeedTheme.nameText,
      DynamicFeedTheme.colorsOf(context).nameInk,
      height: DynamicFeedTheme.nameLine / DynamicFeedTheme.nameText,
    );
    const dotLeft = DynamicFeedTheme.face / 2 + DynamicFeedTheme.dotOffset - DynamicFeedTheme.dotRing / 2;
    return FollowTap(
      label: dot ? '${up.name}，有更新' : up.name,
      onTap: onTap,
      child: SizedBox(
        width: DynamicFeedTheme.facePitch,
        child: Column(
          children: [
            SizedBox.square(
              dimension: DynamicFeedTheme.face,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: ClipOval(child: RemoteImage.avatar(up.face))),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: CircleBorder(
                          side: BorderSide(color: DynamicFeedTheme.colorsOf(context).faceRingInk, width: DynamicFeedTheme.faceRing),
                        ),
                      ),
                    ),
                  ),
                  if (dot)
                    Positioned(
                      key: ValueKey('follow-dot-${up.mid}'),
                      left: dotLeft,
                      top: dotLeft,
                      width: DynamicFeedTheme.dotRing,
                      height: DynamicFeedTheme.dotRing,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(color: BiliColors.colorsOf(context).card, shape: CircleBorder()),
                        child: Center(
                          child: SizedBox.square(
                            dimension: DynamicFeedTheme.dot,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(color: DynamicFeedTheme.colorsOf(context).dotInk, shape: CircleBorder()),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DynamicFeedTheme.nameCentre - DynamicFeedTheme.nameLine / 2),
            SizedBox(
              width: DynamicFeedTheme.nameWidth,
              child: Text(
                up.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: style,
                strutStyle: BiliFonts.strutOf(context, style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The faces side by side, scrolling sideways when there are more than fit; asks for more near its end.
class FollowFacesRow extends StatefulWidget {
  const FollowFacesRow({
    super.key,
    required this.ups,
    required this.dot,
    required this.onOpen,
    this.onNearEnd,
    this.controller,
    this.below,
  });

  final List<DynamicUp> ups;
  final bool Function(DynamicUp up) dot;
  final ValueChanged<DynamicUp> onOpen;
  final VoidCallback? onNearEnd;
  final ScrollController? controller;

  /// Drawn under the faces, inside the scrolled content: the face sheet's pointer.
  final Widget Function(BuildContext context)? below;

  @override
  State<FollowFacesRow> createState() => _FollowFacesRowState();
}

class _FollowFacesRowState extends State<FollowFacesRow> {
  bool _scrolled(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth == 0 &&
        metrics.axis == Axis.horizontal &&
        metrics.hasContentDimensions &&
        metrics.extentAfter < DynamicFeedTheme.facesAhead) {
      widget.onNearEnd?.call();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final below = widget.below;
    final faces = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final up in widget.ups)
          FollowFace(
            key: ValueKey('follow-face-${up.mid}'),
            up: up,
            dot: widget.dot(up),
            onTap: () => widget.onOpen(up),
          ),
      ],
    );
    return NotificationListener<ScrollNotification>(
      onNotification: _scrolled,
      child: SingleChildScrollView(
        controller: widget.controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: DynamicFeedTheme.facesInset),
        child: below == null ? faces : Stack(clipBehavior: Clip.none, children: [faces, below(context)]),
      ),
    );
  }
}

/// The white top under the header (127, 128): 全部 / 视频, then 最常访问 with its faces once they have come.
class FollowTop extends StatelessWidget {
  const FollowTop({
    super.key,
    required this.type,
    required this.ups,
    required this.dot,
    required this.onSelect,
    required this.onOpenFace,
    required this.onMore,
    required this.onNearEnd,
    required this.facesController,
    required this.facesKey,
  });

  final DynamicFeedType type;
  final List<DynamicUp> ups;
  final bool Function(DynamicUp up) dot;
  final ValueChanged<DynamicFeedType> onSelect;
  final ValueChanged<DynamicUp> onOpenFace;
  final VoidCallback onMore;
  final VoidCallback onNearEnd;
  final ScrollController facesController;

  /// On the faces row's box, so the face sheet can rise from where the row is.
  final GlobalKey facesKey;

  /// Without faces only the switch shows, as much white under it as over it.
  static double heightOf({required bool faces}) =>
      faces ? DynamicFeedTheme.top : DynamicFeedTheme.switchTop * 2 + DynamicFeedTheme.switchHeight;

  @override
  Widget build(BuildContext context) {
    final faces = ups.isNotEmpty;
    return ColoredBox(
      color: BiliColors.colorsOf(context).card,
      child: SizedBox(
        height: heightOf(faces: faces),
        child: Stack(
          children: [
            Positioned(
              left: DynamicFeedTheme.gutter,
              right: DynamicFeedTheme.gutter,
              top: DynamicFeedTheme.switchTop,
              child: FollowSwitch(type: type, onSelect: onSelect),
            ),
            if (faces) ...[
              Positioned(
                left: 0,
                right: 0,
                top: DynamicFeedTheme.facesTitleCentre - DynamicFeedTheme.sectionLine / 2,
                child: FollowSectionTitle(
                  title: '最常访问',
                  more: type == DynamicFeedType.all ? '更多' : null,
                  moreKey: const ValueKey('follow-faces-more'),
                  onMore: onMore,
                ),
              ),
              Positioned(
                key: facesKey,
                left: 0,
                right: 0,
                top: DynamicFeedTheme.facesTop,
                height: FollowFace.rowHeight,
                child: FollowFacesRow(
                  ups: ups,
                  dot: dot,
                  onOpen: onOpenFace,
                  onNearEnd: onNearEnd,
                  controller: facesController,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 我的追番 · 追剧 (128), on 视频 only: the posters with 全N话 over their foot and the title under each.
class FollowBangumiSection extends StatelessWidget {
  const FollowBangumiSection({super.key, required this.items, required this.onAll, required this.onOpen});

  final List<FollowedBangumi> items;
  final VoidCallback onAll;
  final ValueChanged<FollowedBangumi> onOpen;

  @override
  Widget build(BuildContext context) {
    final titleStyle = followStyle(
      DynamicFeedTheme.posterTitleText,
      DynamicFeedTheme.colorsOf(context).posterTitleInk,
      height: DynamicFeedTheme.posterTitleLine / DynamicFeedTheme.posterTitleText,
    );
    const rowHeight =
        DynamicFeedTheme.posterHeight + DynamicFeedTheme.posterTitleCentre + DynamicFeedTheme.posterTitleLine / 2;
    return ColoredBox(
      key: const ValueKey('follow-bangumi'),
      color: BiliColors.colorsOf(context).card,
      child: SizedBox(
        height: DynamicFeedTheme.bangumi,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: DynamicFeedTheme.bangumiTitleCentre - DynamicFeedTheme.sectionLine / 2,
              child: FollowSectionTitle(
                title: '我的追番 · 追剧',
                more: '全部',
                moreKey: const ValueKey('follow-bangumi-all'),
                moreText: DynamicFeedTheme.allText,
                moreInk: DynamicFeedTheme.colorsOf(context).allInk,
                moreGap: DynamicFeedTheme.allGap,
                onMore: onAll,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: DynamicFeedTheme.posterTop,
              height: rowHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: DynamicFeedTheme.gutter),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: DynamicFeedTheme.posterGap),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FollowTap(
                    key: ValueKey('follow-poster-${item.seasonId}'),
                    label: item.title,
                    onTap: () => onOpen(item),
                    child: SizedBox(
                      width: DynamicFeedTheme.posterWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Poster(item: item),
                          const SizedBox(
                            height: DynamicFeedTheme.posterTitleCentre - DynamicFeedTheme.posterTitleLine / 2,
                          ),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                            strutStyle: BiliFonts.strutOf(context, titleStyle),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.item});

  final FollowedBangumi item;

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DynamicFeedTheme.posterRadius),
      child: SizedBox(
        width: DynamicFeedTheme.posterWidth,
        height: DynamicFeedTheme.posterHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RemoteImage(item.cover, cover: true),
            if (progress.isNotEmpty) ...[
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: DynamicFeedTheme.posterShadeHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [DynamicFeedTheme.posterShadeTop, DynamicFeedTheme.posterShade],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: DynamicFeedTheme.progressLeft,
                right: DynamicFeedTheme.progressLeft,
                bottom: DynamicFeedTheme.progressBottom,
                child: Text(
                  progress,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: followStyle(DynamicFeedTheme.progressText, DynamicFeedTheme.progressInk),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
