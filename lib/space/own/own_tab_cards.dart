import 'package:bili_core/api.dart';
import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/widgets.dart';

import '../../favourites/favourite_rows.dart' show FavTap;
import '../../favourites/favourites_glyphs.dart';
import '../../player_ui/end_screen_portrait.dart' show CountGlyph, CountPainter;
import '../../shared/loading_tv.dart';
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import 'own_tab_glyphs.dart';

/// The style every word of the own space's tabs draws with; with [line] an even line box, so a line can be placed by
/// its middle.
TextStyle ownStyle(double size, Color color, {double? line, FontWeight weight = FontWeight.w400}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: line == null ? null : line / size,
  leadingDistribution: line == null ? null : TextLeadingDistribution.even,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

/// 0:12 and 12:05, 1:02:03 past an hour: the cover's length as 115 words it, the minutes unpadded.
String ownClock(int seconds) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  final total = seconds < 0 ? 0 : seconds;
  final h = total ~/ 3600, m = total % 3600 ~/ 60, s = total % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// "8个内容 · 私密" under a folder's title.
String folderLine(int count, {required bool isPrivate}) => '$count个内容 · ${isPrivate ? '私密' : '公开'}';

/// [text] on one line of [style], its line box from the strut so Latin and Chinese sit alike.
Widget _line(String text, TextStyle style, {Key? key, int maxLines = 1}) => Text(
  text,
  key: key,
  maxLines: maxLines,
  overflow: TextOverflow.ellipsis,
  style: style,
  strutStyle: BiliFonts.strut(style),
);

/// The white card under 收藏's folders and the videos, with its corner and shadow.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: OwnSpaceTabsTheme.cardHeight,
    decoration: BoxDecoration(
      color: OwnSpaceTabsTheme.colorsOf(context).cardFill,
      borderRadius: BorderRadius.all(Radius.circular(OwnSpaceTabsTheme.cardRadius)),
      boxShadow: [
        BoxShadow(
          color: OwnSpaceTabsTheme.cardShadow,
          blurRadius: OwnSpaceTabsTheme.cardShadowBlur,
          offset: Offset(0, OwnSpaceTabsTheme.cardShadowDrop),
        ),
      ],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(OwnSpaceTabsTheme.cardRadius), child: child),
  );
}

/// A folder's cover: its picture, or the TV on grey; the badge at its lower right.
class FolderCover extends StatelessWidget {
  const FolderCover({super.key, required this.cover, required this.tv, required this.tvInk, required this.badgeBottom});

  final String cover;
  final Size tv;
  final Color tvInk;
  final double badgeBottom;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: OwnSpaceTabsTheme.colorsOf(context).coverEmpty,
    child: Stack(
      fit: StackFit.expand,
      children: [
        RemoteImage(
          cover.isEmpty ? null : cover,
          cover: true,
          fallback: Center(
            child: CoverTv(size: tv, color: tvInk),
          ),
        ),
        Positioned(right: OwnSpaceTabsTheme.stackInset, bottom: badgeBottom, child: const FolderStackBadge()),
      ],
    ),
  );
}

/// One of 主页's 收藏 cards (114): the cover over the title and "N个内容 · 公开".
class OwnFolderCard extends StatelessWidget {
  const OwnFolderCard({super.key, required this.folder, required this.onOpen});

  final SpaceFolderCard folder;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = ownStyle(
      OwnSpaceTabsTheme.cardTitleText,
      OwnSpaceTabsTheme.colorsOf(context).cardTitleInk,
      line: OwnSpaceTabsTheme.cardTitleLine,
    );
    final count = ownStyle(
      OwnSpaceTabsTheme.folderCountText,
      OwnSpaceTabsTheme.colorsOf(context).folderCountInk,
      line: OwnSpaceTabsTheme.folderCountLine,
    );
    final line = folderLine(folder.count, isPrivate: folder.isPrivate);
    return FavTap(
      label: '${folder.title}，$line',
      onTap: onOpen,
      child: _Card(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: OwnSpaceTabsTheme.coverHeight,
              child: FolderCover(
                cover: folder.cover,
                tv: const Size(OwnSpaceTabsTheme.tvWidth, OwnSpaceTabsTheme.tvHeight),
                tvInk: OwnSpaceTabsTheme.colorsOf(context).tvInk,
                badgeBottom: OwnSpaceTabsTheme.stackInset,
              ),
            ),
            Positioned(
              left: OwnSpaceTabsTheme.cardPadX,
              right: OwnSpaceTabsTheme.cardPadX,
              top:
                  OwnSpaceTabsTheme.coverHeight +
                  OwnSpaceTabsTheme.folderTitleCentre -
                  OwnSpaceTabsTheme.cardTitleLine / 2,
              child: _line(folder.title, title),
            ),
            Positioned(
              left: OwnSpaceTabsTheme.cardPadX,
              right: OwnSpaceTabsTheme.cardPadX,
              top:
                  OwnSpaceTabsTheme.coverHeight +
                  OwnSpaceTabsTheme.folderCountCentre -
                  OwnSpaceTabsTheme.folderCountLine / 2,
              child: _line(line, count),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of 主页's video cards (115): the cover with ▶ plays, the danmaku count and the length, the title in up to two
/// lines under it.
class OwnVideoCard extends StatelessWidget {
  const OwnVideoCard({super.key, required this.video, required this.onOpen});

  final SpaceVideo video;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = ownStyle(
      OwnSpaceTabsTheme.cardTitleText,
      OwnSpaceTabsTheme.colorsOf(context).cardTitleInk,
      line: OwnSpaceTabsTheme.cardTitleLine,
    );
    return FavTap(
      label: video.title,
      onTap: onOpen,
      child: _Card(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: OwnSpaceTabsTheme.coverHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RemoteImage(video.cover, cover: true),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: OwnSpaceTabsTheme.shadeHeight,
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [BiliColors.chromeShadeClear, OwnSpaceTabsTheme.shade],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: OwnSpaceTabsTheme.statLeft,
                    right: OwnSpaceTabsTheme.statRight,
                    bottom: OwnSpaceTabsTheme.statCentre - OwnSpaceTabsTheme.statLine / 2,
                    height: OwnSpaceTabsTheme.statLine,
                    child: _Stats(video: video),
                  ),
                ],
              ),
            ),
            Positioned(
              left: OwnSpaceTabsTheme.cardPadX,
              right: OwnSpaceTabsTheme.cardPadX,
              top:
                  OwnSpaceTabsTheme.coverHeight +
                  OwnSpaceTabsTheme.videoTitleCentre -
                  OwnSpaceTabsTheme.cardTitleLine / 2,
              child: _line(video.title, title, key: ValueKey('own-video-title-${video.bvid}'), maxLines: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.video});

  final SpaceVideo video;

  @override
  Widget build(BuildContext context) {
    final style = ownStyle(OwnSpaceTabsTheme.statText, OwnSpaceTabsTheme.statInk, line: OwnSpaceTabsTheme.statLine);
    final strut = BiliFonts.strut(style);
    Widget glyph(CountGlyph glyph) => CustomPaint(
      size: const Size(OwnSpaceTabsTheme.statIconWidth, OwnSpaceTabsTheme.statIconHeight),
      painter: CountPainter(glyph, color: OwnSpaceTabsTheme.statInk),
    );
    return DefaultTextStyle(
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                glyph(CountGlyph.views),
                const SizedBox(width: OwnSpaceTabsTheme.statIconGap),
                Text(CountFormat.short(video.play), strutStyle: strut),
                const SizedBox(width: OwnSpaceTabsTheme.statGroupGap),
                glyph(CountGlyph.danmaku),
                const SizedBox(width: OwnSpaceTabsTheme.statIconGap),
                Flexible(child: Text(CountFormat.short(video.danmaku), strutStyle: strut)),
              ],
            ),
          ),
          Text(ownClock(video.duration), strutStyle: strut),
        ],
      ),
    );
  }
}

/// A 追番 poster (114, 117): the picture darkening at its bottom under the title and the progress.
class OwnPoster extends StatelessWidget {
  const OwnPoster({super.key, required this.bangumi, required this.onTap});

  final SpaceBangumiCard bangumi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = ownStyle(
      OwnSpaceTabsTheme.posterTitleText,
      OwnSpaceTabsTheme.posterInk,
      line: OwnSpaceTabsTheme.posterTitleLine,
    );
    final progress = ownStyle(
      OwnSpaceTabsTheme.posterProgressText,
      OwnSpaceTabsTheme.posterInk,
      line: OwnSpaceTabsTheme.posterProgressLine,
    );
    return FavTap(
      label: bangumi.progress.isEmpty ? bangumi.title : '${bangumi.title}，${bangumi.progress}',
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: OwnSpaceTabsTheme.posterWidth / OwnSpaceTabsTheme.posterHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OwnSpaceTabsTheme.posterRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RemoteImage(bangumi.cover),
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: OwnSpaceTabsTheme.posterShadeHeight,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [BiliColors.chromeShadeClear, OwnSpaceTabsTheme.posterShade],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: OwnSpaceTabsTheme.posterTextLeft,
                right: OwnSpaceTabsTheme.posterTextRight,
                bottom: OwnSpaceTabsTheme.posterTitleCentre - OwnSpaceTabsTheme.posterTitleLine / 2,
                child: _line(bangumi.title, title),
              ),
              if (bangumi.progress.isNotEmpty)
                Positioned(
                  left: OwnSpaceTabsTheme.posterTextLeft,
                  right: OwnSpaceTabsTheme.posterTextRight,
                  bottom: OwnSpaceTabsTheme.posterProgressCentre - OwnSpaceTabsTheme.posterProgressLine / 2,
                  child: _line(bangumi.progress, progress),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An owned 装扮 of 拥有的个性装扮 (115): the card's picture rising out of its own colour at the bottom, the title over
/// it and the NO. under that.
class OwnGarbCard extends StatelessWidget {
  const OwnGarbCard({super.key, required this.garb, required this.onTap});

  final SpaceGarbCard garb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = ownStyle(
      OwnSpaceTabsTheme.garbTitleText,
      OwnSpaceTabsTheme.garbInk,
      line: OwnSpaceTabsTheme.garbTitleLine,
    );
    final number = ownStyle(
      OwnSpaceTabsTheme.garbNumberText,
      OwnSpaceTabsTheme.garbInk,
      line: OwnSpaceTabsTheme.garbNumberHeight,
      weight: FontWeight.w500,
    );
    final mask = garb.maskColor;
    final shade = mask == null ? OwnSpaceTabsTheme.garbShade : Color(mask);
    final numberFill = garb.numberColor;
    return FavTap(
      label: garb.fansNumber.isEmpty ? garb.title : '${garb.title}，${garb.fansNumber}',
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: OwnSpaceTabsTheme.garbWidth / OwnSpaceTabsTheme.garbHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OwnSpaceTabsTheme.garbRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RemoteImage(garb.image),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: OwnSpaceTabsTheme.garbShadeHeight,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [shade.withValues(alpha: 0), shade],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: OwnSpaceTabsTheme.garbTextLeft,
                right: OwnSpaceTabsTheme.garbTextRight,
                bottom: OwnSpaceTabsTheme.garbTitleCentre - OwnSpaceTabsTheme.garbTitleLine / 2,
                child: _line(garb.title, title),
              ),
              if (garb.fansNumber.isNotEmpty)
                Positioned(
                  left: OwnSpaceTabsTheme.garbTextLeft,
                  bottom: OwnSpaceTabsTheme.garbNumberCentre - OwnSpaceTabsTheme.garbNumberHeight / 2,
                  height: OwnSpaceTabsTheme.garbNumberHeight,
                  child: Container(
                    key: const ValueKey('own-garb-number'),
                    padding: const EdgeInsets.symmetric(horizontal: OwnSpaceTabsTheme.garbNumberPadX),
                    decoration: BoxDecoration(
                      color: numberFill == null ? OwnSpaceTabsTheme.garbNumberFill : Color(numberFill),
                      borderRadius: BorderRadius.circular(OwnSpaceTabsTheme.garbNumberRadius),
                    ),
                    alignment: Alignment.center,
                    child: Text(garb.fansNumber, maxLines: 1, style: number, strutStyle: BiliFonts.strut(number)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A folder of 收藏's list (116): the cover, the title and "N个内容 · 公开" beside it.
class OwnFolderRow extends StatelessWidget {
  const OwnFolderRow({super.key, required this.folder, required this.cover, required this.onOpen});

  final FavFolder folder;
  final String cover;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = ownStyle(
      OwnSpaceTabsTheme.rowTitleText,
      OwnSpaceTabsTheme.colorsOf(context).cardTitleInk,
      line: OwnSpaceTabsTheme.rowTitleLine,
    );
    final count = ownStyle(
      OwnSpaceTabsTheme.rowCountText,
      OwnSpaceTabsTheme.colorsOf(context).folderCountInk,
      line: OwnSpaceTabsTheme.rowCountLine,
    );
    final line = folderLine(folder.count, isPrivate: folder.isPrivate);
    const textLeft = OwnSpaceTabsTheme.gutter + OwnSpaceTabsTheme.rowCoverWidth + OwnSpaceTabsTheme.rowTextGap;
    return FavTap(
      label: '${folder.title}，$line',
      onTap: onOpen,
      child: SizedBox(
        height: OwnSpaceTabsTheme.rowCoverHeight,
        child: Stack(
          children: [
            Positioned(
              left: OwnSpaceTabsTheme.gutter,
              top: 0,
              width: OwnSpaceTabsTheme.rowCoverWidth,
              height: OwnSpaceTabsTheme.rowCoverHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(OwnSpaceTabsTheme.rowCoverRadius),
                child: FolderCover(
                  cover: cover,
                  tv: const Size(OwnSpaceTabsTheme.rowTvWidth, OwnSpaceTabsTheme.rowTvHeight),
                  tvInk: OwnSpaceTabsTheme.colorsOf(context).rowTvInk,
                  badgeBottom: OwnSpaceTabsTheme.rowStackBottom,
                ),
              ),
            ),
            Positioned(
              left: textLeft,
              right: OwnSpaceTabsTheme.gutter,
              top: OwnSpaceTabsTheme.rowTitleCentre - OwnSpaceTabsTheme.rowTitleLine / 2,
              child: _line(folder.title, title),
            ),
            Positioned(
              left: textLeft,
              right: OwnSpaceTabsTheme.gutter,
              top: OwnSpaceTabsTheme.rowCountCentre - OwnSpaceTabsTheme.rowCountLine / 2,
              child: _line(line, count),
            ),
          ],
        ),
      ),
    );
  }
}

/// › after 更多 and 去创作中心领奖.
class OwnChevron extends StatelessWidget {
  const OwnChevron({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => FavGlyphIcon(
    FavGlyph.chevron,
    width: OwnSpaceTabsTheme.moreChevronWidth,
    height: OwnSpaceTabsTheme.moreChevronHeight,
    color: color,
    stroke: OwnSpaceTabsTheme.moreChevronStroke,
  );
}

/// Under a paged list: the next page's small spinner, or 加载失败，点击重试 after a failure ([message] in place of 加载失败
/// when given).
class OwnPagingFooter extends StatelessWidget {
  const OwnPagingFooter({
    super.key,
    required this.keyPrefix,
    required this.failed,
    required this.onRetry,
    this.message,
  });

  final String keyPrefix;
  final bool failed;
  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: OwnSpaceTabsTheme.footerPad),
    child: Center(
      child: failed
          ? OwnRetryLine(key: ValueKey('$keyPrefix-retry'), onRetry: onRetry, message: message)
          : SizedBox(
              height: OwnSpaceTabsTheme.spinnerRadius * 2,
              child: CupertinoActivityIndicator(
                key: ValueKey('$keyPrefix-more-spinner'),
                radius: OwnSpaceTabsTheme.spinnerRadius,
              ),
            ),
    ),
  );
}

/// 加载失败，点击重试, the whole line a tap; [message] says why in place of 加载失败.
class OwnRetryLine extends StatelessWidget {
  const OwnRetryLine({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final style = ownStyle(OwnSpaceTabsTheme.footerText, OwnSpaceTabsTheme.colorsOf(context).footerInk);
    final failure = '${message ?? '加载失败'}，';
    return FavTap(
      label: '$failure点击重试',
      onTap: onRetry,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: failure, style: style),
            TextSpan(
              text: '点击重试',
              style: style.copyWith(color: OwnSpaceTabsTheme.colorsOf(context).footerRetryInk),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// A list's first load: the TV, or the retry line once it failed ([message] in place of 加载失败 when given).
class OwnFirstLoad extends StatelessWidget {
  const OwnFirstLoad({super.key, required this.keyPrefix, required this.failed, required this.onRetry, this.message});

  final String keyPrefix;
  final bool failed;
  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: OwnSpaceTabsTheme.stateTop, bottom: OwnSpaceTabsTheme.stateTop),
    child: Center(
      child: failed
          ? OwnRetryLine(key: ValueKey('$keyPrefix-retry'), onRetry: onRetry, message: message)
          : LoadingTvState(key: ValueKey('$keyPrefix-loading')),
    ),
  );
}
