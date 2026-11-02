import 'package:bili_core/api.dart';
import 'package:bili_core/logic.dart' show CountFormat, TimeFormat;
import 'package:flutter/widgets.dart';

import '../player_ui/end_screen_portrait.dart' show CountGlyph, CountPainter;
import '../shared/cover_preset.dart';
import '../shared/menu.dart' show PressHighlight;
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../video/video_route.dart';
import 'space_video_glyphs.dart';

/// How 投稿's rows word lengths and counts (63, 69, 70, 74).
abstract final class SpaceVideoFormat {
  /// Under a minute it reads 0:28, then 01:22 and 20:35, and 1:47:09 past an hour.
  static String duration(int seconds) {
    final clock = TimeFormat.clock(seconds.toDouble());
    return clock.startsWith('00:') ? clock.substring(1) : clock;
  }

  /// 77.6万, 1120.
  static String count(int n) => CountFormat.short(n);
}

/// The style every line of 投稿 draws with: the app's font, and with [line] an even line box, so a line can be placed by
/// its middle.
TextStyle spaceVideosStyle(double size, Color color, {double? line, FontWeight weight = FontWeight.w400}) => TextStyle(
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

/// A 投稿 row (63, 69, 70): the cover with its length and badges, the title in up to two lines, the date, ▶ plays and
/// danmaku, ⋮ at the far right, and the hairline under it. [onMore] gets the ⋮'s box on screen, for the popover.
class SpaceVideoRow extends StatelessWidget {
  const SpaceVideoRow({super.key, required this.video, required this.onOpen, required this.onMore, this.hero = false});

  final SpaceVideo video;
  final VoidCallback onOpen;
  final ValueChanged<Rect> onMore;

  /// Whether the cover flies into the video page this row opened, and back.
  final bool hero;

  static const height = SpaceVideosTheme.rowHeight;
  static const _coverTop = SpaceVideosTheme.rowPadTop;
  static const _textLeft = SpaceVideosTheme.gutter + SpaceVideosTheme.coverWidth + SpaceVideosTheme.textGap;

  @override
  Widget build(BuildContext context) {
    final title = spaceVideosStyle(
      SpaceVideosTheme.titleText,
      SpaceVideosTheme.colorsOf(context).titleInk,
      line: SpaceVideosTheme.titleLine,
    );
    final meta = spaceVideosStyle(SpaceVideosTheme.metaText, SpaceVideosTheme.colorsOf(context).metaInk, line: SpaceVideosTheme.metaLine);
    final plays = SpaceVideoFormat.count(video.play);
    final danmaku = SpaceVideoFormat.count(video.danmaku);
    final length = video.duration > 0 ? '，${SpaceVideoFormat.duration(video.duration)}' : '';
    final when = video.publishedText.isEmpty ? '' : '，${video.publishedText}';
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '${video.title}$length$when，$plays播放，$danmaku弹幕',
              onTap: onOpen,
              excludeSemantics: true,
              child: PressHighlight(
                key: ValueKey('space-video-${video.bvid}'),
                onTap: onOpen,
                child: SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: SpaceVideosTheme.gutter,
            top: _coverTop,
            width: SpaceVideosTheme.coverWidth,
            height: SpaceVideosTheme.coverHeight,
            child: IgnorePointer(
              child: _Cover(video: video, hero: hero),
            ),
          ),
          Positioned(
            left: _textLeft,
            right: SpaceVideosTheme.titleRight,
            top: _coverTop + SpaceVideosTheme.titleTop,
            child: IgnorePointer(
              child: Text(
                video.title,
                key: ValueKey('space-title-${video.bvid}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: title,
                strutStyle: BiliFonts.strut(title),
              ),
            ),
          ),
          if (video.publishedText.isNotEmpty)
            Positioned(
              left: _textLeft,
              right: SpaceVideosTheme.moreCentreRight + SpaceVideosTheme.moreTarget / 2,
              top: _coverTop + SpaceVideosTheme.dateCentre - SpaceVideosTheme.metaLine / 2,
              height: SpaceVideosTheme.metaLine,
              child: IgnorePointer(
                child: Text(
                  video.publishedText,
                  key: ValueKey('space-date-${video.bvid}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: meta,
                  strutStyle: BiliFonts.strut(meta),
                ),
              ),
            ),
          Positioned(
            left: _textLeft + SpaceVideosTheme.countsInset,
            right: SpaceVideosTheme.moreCentreRight + SpaceVideosTheme.moreTarget / 2,
            top: _coverTop + SpaceVideosTheme.countsCentre - SpaceVideosTheme.metaLine / 2,
            height: SpaceVideosTheme.metaLine,
            child: IgnorePointer(
              child: Row(
                children: [
                  SizedBox(
                    width: SpaceVideosTheme.danmakuColumn,
                    child: _Count(glyph: CountGlyph.views, text: plays, style: meta),
                  ),
                  Flexible(
                    child: _Count(glyph: CountGlyph.danmaku, text: danmaku, style: meta),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: SpaceVideosTheme.moreCentreRight - SpaceVideosTheme.moreTarget / 2,
            width: SpaceVideosTheme.moreTarget,
            top: _coverTop + SpaceVideosTheme.countsCentre - SpaceVideosTheme.moreTarget / 2,
            height: SpaceVideosTheme.moreTarget,
            child: Builder(
              builder: (context) {
                void more() {
                  final box = context.findRenderObject()! as RenderBox;
                  onMore(box.localToGlobal(Offset.zero) & box.size);
                }

                return Semantics(
                  button: true,
                  label: '更多操作',
                  onTap: more,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: ValueKey('space-more-${video.bvid}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: more,
                    child: CustomPaint(painter: MoreDotsPainter(palette: BiliPalette.of(context))),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: SpaceVideosTheme.gutter,
            right: 0,
            top: _coverTop + SpaceVideosTheme.coverHeight + SpaceVideosTheme.rowPadBottom,
            height: SpaceVideosTheme.hairline,
            child: ColoredBox(color: SpaceVideosTheme.colorsOf(context).hairlineInk),
          ),
        ],
      ),
    );
  }
}

/// A count glyph and its number after it.
class _Count extends StatelessWidget {
  const _Count({required this.glyph, required this.text, required this.style});

  final CountGlyph glyph;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomPaint(
        size: const Size(SpaceVideosTheme.countGlyphWidth, SpaceVideosTheme.countGlyphHeight),
        painter: CountPainter(glyph, color: SpaceVideosTheme.colorsOf(context).metaInk),
      ),
      const SizedBox(width: SpaceVideosTheme.countGap),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: style,
          strutStyle: BiliFonts.strut(style),
        ),
      ),
    ],
  );
}

class _Cover extends StatelessWidget {
  const _Cover({required this.video, required this.hero});

  final SpaceVideo video;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final picture = video.cover.isEmpty
        ? ColoredBox(key: ValueKey('space-cover-placeholder'), color: SpaceVideosTheme.colorsOf(context).coverPlaceholder)
        : RemoteImage(
            video.cover,
            size: const Size(SpaceVideosTheme.coverWidth, SpaceVideosTheme.coverHeight),
            cover: true,
            preset: CoverPreset.space,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(SpaceVideosTheme.coverRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Off except for the video the list opened last: the page that opened the space can hold a Hero of the same
          // video, which would otherwise fly into the list as the space pushes.
          HeroMode(
            enabled: hero,
            child: Hero(tag: VideoRoute.coverTag(video.bvid), child: picture),
          ),
          if (video.badges.isNotEmpty)
            Positioned(
              top: SpaceVideosTheme.badgeTop,
              right: SpaceVideosTheme.badgeRight,
              child: Row(
                spacing: SpaceVideosTheme.badgeGap,
                children: [for (final badge in video.badges) _Pill.badge(badge)],
              ),
            ),
          if (video.duration > 0)
            Positioned(
              right: SpaceVideosTheme.durationRight,
              bottom: SpaceVideosTheme.durationBottom,
              child: _Pill.duration(SpaceVideoFormat.duration(video.duration)),
            ),
        ],
      ),
    );
  }
}

/// The length on the cover's lower right, or a pink badge (合作) on its upper right.
class _Pill extends StatelessWidget {
  const _Pill.duration(this.text) : badge = false;
  const _Pill.badge(this.text) : badge = true;

  final String text;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final height = badge ? SpaceVideosTheme.badgeHeight : SpaceVideosTheme.durationHeight;
    final style = spaceVideosStyle(
      badge ? SpaceVideosTheme.badgeText : SpaceVideosTheme.durationText,
      badge ? SpaceVideosTheme.badgeInk : SpaceVideosTheme.durationInk,
      line: height,
    );
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: badge ? SpaceVideosTheme.badgePadX : SpaceVideosTheme.durationPadX),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badge ? SpaceVideosTheme.colorsOf(context).badgeFill : SpaceVideosTheme.durationFill,
        borderRadius: BorderRadius.circular(badge ? SpaceVideosTheme.badgeRadius : SpaceVideosTheme.durationRadius),
      ),
      child: Text(text, maxLines: 1, softWrap: false, style: style, strutStyle: BiliFonts.strut(style)),
    );
  }
}
