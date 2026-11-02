import 'dart:ui' show ImageFilter;

import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../shared/cover_preset.dart';
import '../shared/menu.dart' show PressHighlight;
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import 'feed_dislike_glyphs.dart';
import 'feed_more_sheet.dart';

/// 不感兴趣原因 (92): the 反馈 reasons as tiles four across, then 该内容已推荐过 on its own card. It closes with the
/// reason picked, or null.
Future<FeedReason?> showFeedReasonsSheet(BuildContext context, FeedDislike dislike) {
  final tiles = dislike.tiles;
  final repeated = dislike.repeated;
  return showFeedSheet<FeedReason>(
    context,
    top: 0,
    builder: (context) {
      final title = feedSheetStyle(
        FeedDislikeTheme.titleText,
        FeedDislikeTheme.colorsOf(context).ink,
        weight: FeedDislikeTheme.titleWeight,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: FeedDislikeTheme.tilesTop,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: FeedDislikeTheme.titleCentre - FeedDislikeTheme.titleText,
                  height: FeedDislikeTheme.titleText * 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(header: true, child: Text('不感兴趣原因', style: title)),
                  ),
                ),
              ],
            ),
          ),
          for (var start = 0; start < tiles.length; start += FeedDislikeTheme.tileColumns) ...[
            if (start > 0) const SizedBox(height: FeedDislikeTheme.tileGap),
            Row(
              spacing: FeedDislikeTheme.tileGap,
              children: [
                for (var column = 0; column < FeedDislikeTheme.tileColumns; column++)
                  Expanded(
                    child: start + column < tiles.length
                        ? _ReasonTile(
                            reason: tiles[start + column],
                            onTap: () => Navigator.of(context).pop(tiles[start + column]),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
          if (repeated != null) ...[
            if (tiles.isNotEmpty) const SizedBox(height: FeedDislikeTheme.groupGap),
            FeedSheetCard(
              children: [
                FeedSheetRow(
                  key: const ValueKey('feed-reason-repeated'),
                  label: repeated.name,
                  icon: FeedDislikeGlyphIcon(
                    FeedDislikeGlyph.repeatedOff,
                    size: FeedDislikeTheme.rowIconBox,
                    color: FeedDislikeTheme.colorsOf(context).ink,
                  ),
                  onTap: () => Navigator.of(context).pop(repeated),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.reason, required this.onTap});

  final FeedReason reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = feedSheetStyle(FeedDislikeTheme.tileLabelText, FeedDislikeTheme.colorsOf(context).tileLabelInk);
    return Semantics(
      button: true,
      label: reason.name,
      onTap: onTap,
      excludeSemantics: true,
      child: ClipRRect(
        key: ValueKey('feed-reason-${reason.id}'),
        borderRadius: BorderRadius.circular(FeedDislikeTheme.cardRadius),
        child: ColoredBox(
          color: FeedDislikeTheme.colorsOf(context).cardFill,
          child: PressHighlight(
            onTap: onTap,
            child: SizedBox(
              height: FeedDislikeTheme.tileHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: FeedDislikeTheme.tileIconCentre - FeedDislikeTheme.tileIconBox / 2,
                    child: Center(
                      child: FeedDislikeGlyphIcon(
                        FeedDislikeGlyph.forReason(reason.name),
                        size: FeedDislikeTheme.tileIconBox,
                        color: FeedDislikeTheme.colorsOf(context).ink,
                        stroke: FeedDislikeTheme.tileGlyphStroke,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: FeedDislikeTheme.tileLabelCentre - FeedDislikeTheme.tileLabelText,
                    height: FeedDislikeTheme.tileLabelText * 2,
                    child: Center(
                      child: Text(reason.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: label),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 推荐 card after 不感兴趣 (91): its cover blurred under the ✓, 已减少此类内容推荐 and ↶ 撤销, and below it
/// 选择不感兴趣原因 › where the card offers reasons ([onReasons] null leaves it out). It keeps the card's size and
/// only its top corners.
class FeedDislikedCard extends StatelessWidget {
  const FeedDislikedCard({super.key, required this.card, required this.onUndo, required this.onReasons});

  final FeedCard card;
  final VoidCallback onUndo;
  final VoidCallback? onReasons;

  @override
  Widget build(BuildContext context) {
    final message = feedSheetStyle(FeedDislikeTheme.messageText, FeedDislikeTheme.messageInk);
    final undo = feedSheetStyle(FeedDislikeTheme.undoText, FeedDislikeTheme.undoInk);
    final reasons = feedSheetStyle(FeedDislikeTheme.reasonsText, FeedDislikeTheme.colorsOf(context).ink);
    final onReasons = this.onReasons;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(BiliMetrics.cardRadius)),
      child: ColoredBox(
        color: BiliColors.colorsOf(context).card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: BiliMetrics.coverAspect,
              child: LayoutBuilder(
                builder: (context, box) {
                  final middle = box.maxHeight / 2;
                  final undoCentre = box.maxHeight - FeedDislikeTheme.undoFromBottom;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // A blur paints past its child's edges; the white below must stay white.
                      ClipRect(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: FeedDislikeTheme.coverBlur,
                            sigmaY: FeedDislikeTheme.coverBlur,
                            tileMode: TileMode.clamp,
                          ),
                          child: RemoteImage(card.cover, cover: true, preset: CoverPreset.feed),
                        ),
                      ),
                      const ColoredBox(color: FeedDislikeTheme.coverShade),
                      Positioned(
                        top: middle + FeedDislikeTheme.checkCentre - FeedDislikeTheme.checkDisc / 2,
                        left: 0,
                        right: 0,
                        child: const Center(child: FeedDislikeCheck()),
                      ),
                      Positioned(
                        top: middle + FeedDislikeTheme.messageCentre - FeedDislikeTheme.messageText,
                        height: FeedDislikeTheme.messageText * 2,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text('已减少此类内容推荐', key: const ValueKey('feed-disliked-message'), style: message),
                        ),
                      ),
                      Positioned(
                        top: undoCentre - FeedDislikeTheme.undoText,
                        height: FeedDislikeTheme.undoText * 2,
                        left: FeedDislikeTheme.undoShift * 2,
                        right: 0,
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: '撤销',
                            onTap: onUndo,
                            excludeSemantics: true,
                            child: GestureDetector(
                              key: const ValueKey('feed-disliked-undo'),
                              behavior: HitTestBehavior.opaque,
                              onTap: onUndo,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: FeedDislikeTheme.undoText),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: FeedDislikeTheme.undoGlyphWidth,
                                      height: FeedDislikeTheme.undoGlyphHeight,
                                      child: FeedDislikeGlyphIcon(
                                        FeedDislikeGlyph.undo,
                                        size: FeedDislikeTheme.undoGlyphHeight,
                                        color: FeedDislikeTheme.undoInk,
                                        stroke: FeedDislikeTheme.undoGlyphStroke,
                                      ),
                                    ),
                                    const SizedBox(width: FeedDislikeTheme.undoGap),
                                    Text('撤销', style: undo),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: onReasons == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      button: true,
                      label: '选择不感兴趣原因',
                      onTap: onReasons,
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const ValueKey('feed-disliked-reasons'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onReasons,
                        child: Stack(
                          children: [
                            Positioned(
                              left: FeedDislikeTheme.reasonsShift * 2,
                              right: 0,
                              top: FeedDislikeTheme.reasonsCentre - FeedDislikeTheme.reasonsText,
                              height: FeedDislikeTheme.reasonsText * 2,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('选择不感兴趣原因', style: reasons),
                                    const SizedBox(width: FeedDislikeTheme.chevronGap),
                                    SizedBox(
                                      width: FeedDislikeTheme.chevronWidth,
                                      height: FeedDislikeTheme.chevronHeight,
                                      child: FeedDislikeGlyphIcon(
                                        FeedDislikeGlyph.chevron,
                                        size: FeedDislikeTheme.chevronHeight,
                                        color: FeedDislikeTheme.colorsOf(context).ink,
                                        stroke: FeedDislikeTheme.chevronStroke,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
