import 'package:bili_core/api.dart';
import 'package:bili_core/logic.dart';
import 'package:flutter/widgets.dart';

import '../../history/history_glyphs.dart';
import '../../home/feed_card.dart' show FeedCardView;
import '../../shared/cover_preset.dart';
import '../../shared/menu.dart' show PressHighlight;
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../search_glyphs.dart';

/// How 搜索's rows word counts, dates and lengths (56, 60, 61).
abstract final class SearchFormat {
  /// 9.2万, 148.1万, 8385.
  static String count(int n) => CountFormat.short(n);

  /// 刚刚, N分钟前 and N小时前 within a day, 昨天 HH:mm, M月D日 this year, YYYY-MM-DD before; '' when unknown.
  static String date(DateTime? published, {required DateTime now, Duration? utcOffset}) => published == null
      ? ''
      : TimeFormat.comment(published.millisecondsSinceEpoch ~/ 1000, now: now, utcOffset: utcOffset);

  /// 2:42, 38:32, 1:02:03.
  static String duration(int seconds) => FeedCardView.duration(seconds);

  /// "9.2万 · 23小时前" under a video; the date is left out when unknown.
  static String plays(SearchVideo video, {required DateTime now}) {
    final when = date(video.published, now: now);
    return when.isEmpty ? count(video.play) : '${count(video.play)} · $when';
  }

  /// "148.1万粉丝 · 539个视频", or the fans alone for someone with no videos.
  static String fans(SearchUser user) =>
      user.videos > 0 ? '${count(user.fans)}粉丝 · ${count(user.videos)}个视频' : '${count(user.fans)}粉丝';
}

/// What a failed call logs: a transport error's words can end with the request's URL, so only its kind and code.
String searchLogReason(Object error) => switch (error) {
  BiliHTTPError(:final status) => 'http $status',
  BiliAPIError(:final code) => 'api $code',
  _ => '${error.runtimeType}',
};

TextStyle searchStyle(double size, Color color, {double? line, FontWeight weight = FontWeight.w400}) => TextStyle(
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

/// [text] with the spaces around each · widened to 56's and 60's.
TextSpan dotted(String text) {
  const space = TextStyle(letterSpacing: SearchResultTheme.dotSpacing);
  final parts = text.split(' · ');
  return TextSpan(
    children: [
      for (final (index, part) in parts.indexed) ...[
        if (index > 0) ...[
          const TextSpan(text: ' ', style: space),
          const TextSpan(text: '·'),
          const TextSpan(text: ' ', style: space),
        ],
        TextSpan(text: part),
      ],
    ],
  );
}

/// A 综合 row (56): the cover with its length, the title with the searched words in pink, the uploader, the plays
/// and the date, and ⋮.
class SearchVideoRow extends StatelessWidget {
  const SearchVideoRow({super.key, required this.video, required this.now, required this.onOpen, required this.onMore});

  final SearchVideo video;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  static const height =
      SearchResultTheme.rowPadTop +
      SearchResultTheme.coverHeight +
      SearchResultTheme.rowPadBottom +
      SearchResultTheme.hairline;

  @override
  Widget build(BuildContext context) {
    const textLeft = SearchResultTheme.gutter + SearchResultTheme.coverWidth + SearchResultTheme.textGap;
    const coverBottom = SearchResultTheme.rowPadTop + SearchResultTheme.coverHeight;
    const metaRight = SearchResultTheme.moreCentreRight + SearchResultTheme.moreTarget / 2;
    const metaTop =
        coverBottom + SearchResultTheme.metaBottom - SearchResultTheme.metaLine * 2 - SearchResultTheme.metaGap;
    final titleStyle = searchStyle(
      SearchResultTheme.titleText,
      SearchResultTheme.colorsOf(context).titleInk,
      line: SearchResultTheme.titleLine,
    );
    final title = video.title;
    final plays = SearchFormat.plays(video, now: now);
    final length = video.duration > 0 ? '，${SearchFormat.duration(video.duration)}' : '';
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '${title.text}，${video.author}$length，$plays',
              onTap: onOpen,
              excludeSemantics: true,
              child: PressHighlight(
                key: ValueKey('search-video-${video.bvid}'),
                onTap: onOpen,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: SearchResultTheme.gutter,
            top: SearchResultTheme.rowPadTop,
            width: SearchResultTheme.coverWidth,
            height: SearchResultTheme.coverHeight,
            child: IgnorePointer(child: _Cover(video: video)),
          ),
          Positioned(
            left: textLeft,
            right: SearchResultTheme.titleRight,
            top: SearchResultTheme.rowPadTop + SearchResultTheme.titleTop,
            child: IgnorePointer(
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final run in title.runs)
                      TextSpan(
                        text: run.text,
                        style: run.highlighted ? TextStyle(color: SearchResultTheme.colorsOf(context).highlight) : null,
                      ),
                  ],
                ),
                key: ValueKey('search-title-${video.bvid}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
                strutStyle: BiliFonts.strut(titleStyle),
              ),
            ),
          ),
          Positioned(
            left: textLeft,
            right: metaRight,
            top: metaTop,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchMetaLine(
                    glyph: const SizedBox(
                      width: HistoryTheme.upWidth,
                      height: SearchResultTheme.metaLine,
                      child: HistoryUpGlyph(),
                    ),
                    text: video.author,
                  ),
                  const SizedBox(height: SearchResultTheme.metaGap),
                  SearchMetaLine(
                    glyph: SearchGlyphIcon(
                      SearchGlyph.play,
                      size: SearchResultTheme.metaGlyph,
                      color: SearchResultTheme.colorsOf(context).metaInk,
                    ),
                    text: plays,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: SearchResultTheme.moreCentreRight - SearchResultTheme.moreTarget / 2,
            width: SearchResultTheme.moreTarget,
            top:
                coverBottom +
                SearchResultTheme.metaBottom -
                SearchResultTheme.metaLine / 2 -
                SearchResultTheme.moreTarget / 2,
            height: SearchResultTheme.moreTarget,
            child: Semantics(
              button: true,
              label: '更多操作',
              onTap: onMore,
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('search-more-${video.bvid}'),
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: const CustomPaint(painter: HistoryMorePainter()),
              ),
            ),
          ),
          Positioned(
            left: SearchResultTheme.gutter,
            right: 0,
            bottom: 0,
            height: SearchResultTheme.hairline,
            child: ColoredBox(color: SearchResultTheme.colorsOf(context).rowHairlineInk),
          ),
        ],
      ),
    );
  }
}

/// A glyph and one line of grey text after it: the uploader, or the plays and the date.
class SearchMetaLine extends StatelessWidget {
  const SearchMetaLine({super.key, required this.glyph, required this.text});

  final Widget glyph;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = searchStyle(SearchResultTheme.metaText, SearchResultTheme.colorsOf(context).metaInk, line: SearchResultTheme.metaLine);
    return SizedBox(
      height: SearchResultTheme.metaLine,
      child: Row(
        children: [
          SizedBox(
            width: SearchResultTheme.metaGlyphSlot,
            height: SearchResultTheme.metaLine,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: SearchResultTheme.metaGlyphInset,
                  top: 0,
                  bottom: 0,
                  child: Center(widthFactor: 1, child: glyph),
                ),
              ],
            ),
          ),
          const SizedBox(width: SearchResultTheme.metaGlyphGap),
          Flexible(
            child: Text.rich(
              dotted(text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
              strutStyle: BiliFonts.strut(style),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.video});

  final SearchVideo video;

  @override
  Widget build(BuildContext context) {
    final style = searchStyle(
      SearchResultTheme.durationText,
      SearchResultTheme.durationInk,
      line: SearchResultTheme.durationHeight,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(SearchResultTheme.coverRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video.cover.isEmpty)
            ColoredBox(key: ValueKey('search-cover-placeholder'), color: SearchResultTheme.colorsOf(context).coverPlaceholder)
          else
            RemoteImage(
              video.cover,
              size: const Size(SearchResultTheme.coverWidth, SearchResultTheme.coverHeight),
              cover: true,
              preset: CoverPreset.exact,
            ),
          if (video.duration > 0)
            Positioned(
              right: SearchResultTheme.durationRight,
              bottom: SearchResultTheme.durationBottom,
              height: SearchResultTheme.durationHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SearchResultTheme.durationFill,
                  borderRadius: BorderRadius.circular(SearchResultTheme.durationRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SearchResultTheme.durationPadX),
                  child: Center(widthFactor: 1, child: Text(SearchFormat.duration(video.duration), style: style)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
