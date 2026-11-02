import 'package:bili_core/api.dart';
import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/widgets.dart';

import '../history/history_glyphs.dart' show HistoryUpGlyph;
import '../player_ui/end_screen_portrait.dart' show CountGlyph, CountPainter;
import '../shared/cover_preset.dart';
import '../shared/menu.dart' show PressHighlight;
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import 'watch_later_glyphs.dart';
import 'watch_later_model.dart';
import 'watch_later_text.dart';

/// A row (86): the cover with watched / total, the title in up to two lines, UP and its name, ▶ plays and danmaku,
/// ⋮ at the right. In edit mode (95, 96) it slides 34 right for its circle, loses ⋮, and a tap chooses it instead of
/// opening the video.
class WatchLaterRow extends StatelessWidget {
  const WatchLaterRow({
    super.key,
    required this.item,
    required this.editing,
    required this.chosen,
    required this.onOpen,
    required this.onToggle,
    required this.onMore,
  });

  final WatchLaterItem item;
  final bool editing;
  final bool chosen;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onMore;

  static const _textLeft = WatchLaterTheme.gutter + WatchLaterTheme.coverWidth + WatchLaterTheme.textGap;
  static const _coverTop = WatchLaterTheme.rowPadTop;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final title = watchLaterStyle(WatchLaterTheme.titleLineText, WatchLaterTheme.colorsOf(context).ink, line: WatchLaterTheme.titleLine);
    final tap = editing ? onToggle : onOpen;
    final plays = CountFormat.short(item.play);
    final danmaku = CountFormat.short(item.danmaku);
    final label = editing
        ? '${chosen ? '已选' : '未选'}，${item.title}'
        : '${item.title}，${item.ownerName}，${WatchLaterModel.progressLabel(item)}，$plays播放，$danmaku弹幕';
    return TweenAnimationBuilder<double>(
      tween: Tween(end: editing ? 1 : 0),
      duration: reduceMotion ? Duration.zero : WatchLaterTheme.editMotion,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final shift = t * WatchLaterTheme.editShift;
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                selected: editing && chosen,
                label: label,
                onTap: tap,
                excludeSemantics: true,
                child: PressHighlight(
                  key: ValueKey('later-open-${item.bvid}'),
                  onTap: tap,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (t > 0)
              Positioned(
                left:
                    WatchLaterTheme.circleCentreX -
                    WatchLaterTheme.circleSize / 2 -
                    (1 - t) * WatchLaterTheme.editShift,
                top: _coverTop + WatchLaterTheme.coverHeight / 2 - WatchLaterTheme.circleSize / 2,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: t,
                    child: ChoiceCircle(key: ValueKey('later-circle-${item.bvid}'), chosen: chosen),
                  ),
                ),
              ),
            Positioned(
              left: WatchLaterTheme.gutter + shift,
              top: _coverTop,
              width: WatchLaterTheme.coverWidth,
              height: WatchLaterTheme.coverHeight,
              child: IgnorePointer(child: _Cover(item: item)),
            ),
            Positioned(
              left: _textLeft + shift,
              right: editing ? WatchLaterTheme.titleRightEditing : WatchLaterTheme.titleRight,
              top: _coverTop + WatchLaterTheme.titleTop,
              child: IgnorePointer(
                child: Text(
                  item.title,
                  key: ValueKey('later-title-${item.bvid}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: title,
                  strutStyle: BiliFonts.strut(title),
                ),
              ),
            ),
            Positioned(
              left: _textLeft + WatchLaterTheme.metaInset + shift,
              right: WatchLaterTheme.moreCentreRight + WatchLaterTheme.moreTarget / 2 - shift,
              top: _coverTop + WatchLaterTheme.upCentre - WatchLaterTheme.metaLine / 2,
              height: WatchLaterTheme.metaLine,
              child: IgnorePointer(
                child: _Meta(
                  glyph: Transform.translate(
                    offset: const Offset(0, -WatchLaterTheme.upGlyphLift),
                    child: const HistoryUpGlyph(),
                  ),
                  text: item.ownerName,
                ),
              ),
            ),
            Positioned(
              left: _textLeft + WatchLaterTheme.metaInset + shift,
              right: WatchLaterTheme.moreCentreRight + WatchLaterTheme.moreTarget / 2 - shift,
              top: _coverTop + WatchLaterTheme.countsCentre - WatchLaterTheme.metaLine / 2,
              height: WatchLaterTheme.metaLine,
              child: IgnorePointer(
                child: Row(
                  children: [
                    _Meta(glyph: const _Count(CountGlyph.views), text: plays, shrink: false),
                    const SizedBox(width: WatchLaterTheme.countsGap),
                    Flexible(
                      child: _Meta(glyph: const _Count(CountGlyph.danmaku), text: danmaku),
                    ),
                  ],
                ),
              ),
            ),
            if (t < 1)
              Positioned(
                right: WatchLaterTheme.moreCentreRight - WatchLaterTheme.moreTarget / 2 - shift,
                width: WatchLaterTheme.moreTarget,
                top: _coverTop + WatchLaterTheme.countsCentre - WatchLaterTheme.moreTarget / 2,
                height: WatchLaterTheme.moreTarget,
                child: Opacity(
                  opacity: 1 - t,
                  child: editing
                      ? CustomPaint(painter: WatchLaterMorePainter(colors: WatchLaterTheme.colorsOf(context)))
                      : Semantics(
                          button: true,
                          label: '更多操作',
                          onTap: onMore,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: ValueKey('later-more-${item.bvid}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onMore,
                            child: CustomPaint(painter: WatchLaterMorePainter(colors: WatchLaterTheme.colorsOf(context))),
                          ),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.glyph);

  final CountGlyph glyph;

  @override
  Widget build(BuildContext context) => Center(
    child: CustomPaint(
      size: const Size(WatchLaterTheme.countGlyphWidth, WatchLaterTheme.countGlyphHeight),
      painter: CountPainter(glyph, color: WatchLaterTheme.colorsOf(context).metaInk),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.glyph, required this.text, this.shrink = true});

  final Widget glyph;
  final String text;
  final bool shrink;

  @override
  Widget build(BuildContext context) {
    final style = watchLaterStyle(WatchLaterTheme.metaText, WatchLaterTheme.colorsOf(context).metaInk, line: WatchLaterTheme.metaLine);
    final words = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: style,
      strutStyle: BiliFonts.strut(style),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: WatchLaterTheme.glyphBox, height: WatchLaterTheme.metaLine, child: glyph),
        const SizedBox(width: WatchLaterTheme.glyphGap),
        shrink ? Flexible(child: words) : words,
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.item});

  final WatchLaterItem item;

  @override
  Widget build(BuildContext context) {
    final style = watchLaterStyle(WatchLaterTheme.progressText, WatchLaterTheme.progressInk).copyWith(
      height: WatchLaterTheme.progressLineHeight,
      leadingDistribution: TextLeadingDistribution.even,
      shadows: const [Shadow(color: WatchLaterTheme.progressShadow, blurRadius: WatchLaterTheme.progressShadowBlur)],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(WatchLaterTheme.coverRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.cover.isEmpty)
            ColoredBox(color: WatchLaterTheme.colorsOf(context).coverPlaceholder)
          else
            RemoteImage(
              item.cover,
              size: const Size(WatchLaterTheme.coverWidth, WatchLaterTheme.coverHeight),
              cover: true,
              preset: CoverPreset.history,
            ),
          Positioned(
            right: WatchLaterTheme.progressRight,
            bottom: WatchLaterTheme.progressBottom,
            child: Text(
              WatchLaterModel.progressLabel(item),
              key: ValueKey('later-progress-${item.bvid}'),
              maxLines: 1,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
