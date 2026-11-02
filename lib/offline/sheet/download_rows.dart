import 'package:bili_core/logic.dart' show TimeFormat;
import 'package:flutter/widgets.dart';

import '../../player_ui/panels/panel_glyphs.dart';
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../offline_models.dart';
import '../offline_size.dart';
import 'download_entries.dart';
import 'download_mark.dart';
import 'sheet_art.dart';

/// A row of 缓存: the title alone in a card 52 tall (141, 153) or, for a 合集's video, the cover beside a two-line
/// title (144, 154); the playing one pink with its bars; its state in the bottom right corner with its size before it.
class DownloadRow extends StatelessWidget {
  const DownloadRow({super.key, required this.entry, required this.item, required this.estimate, required this.onTap});

  final DownloadEntry entry;
  final OfflineItem? item;

  /// The bytes at the chosen quality; null when unknown.
  final int? estimate;
  final VoidCallback onTap;

  /// 约 78.4MB before it is queued; the real size once the library knows it.
  static String? sizeText(OfflineItem? item, int? estimate) {
    if (item != null && item.totalBytes > 0) return formatBytes(item.totalBytes);
    if (item == null && estimate != null) return '约 ${formatBytes(estimate)}';
    return null;
  }

  String get _state => switch (item?.state) {
    null => '未缓存',
    OfflineState.waiting => '等待缓存',
    OfflineState.downloading => '缓存中',
    OfflineState.paused => '已暂停',
    OfflineState.failed => '缓存失败',
    OfflineState.done => '已缓存',
  };

  @override
  Widget build(BuildContext context) {
    final cover = entry.cover;
    final size = sizeText(item, estimate);
    return SheetTap(
      label: [entry.title, _state, ?size].join('，'),
      selected: entry.current,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DownloadSheetTheme.colorsOf(context).card,
          borderRadius: BorderRadius.circular(DownloadSheetTheme.cardRadius),
        ),
        child: cover == null ? _titleRow(context, size) : _coverRow(context, cover, size),
      ),
    );
  }

  Widget _corner(BuildContext context, String? size) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (size != null) ...[
        Text(
          size,
          key: const ValueKey('download-size'),
          maxLines: 1,
          style: TextStyle(fontSize: DownloadSheetTheme.sizeText, height: 1, color: BiliColors.colorsOf(context).secondaryText),
        ),
        const SizedBox(width: DownloadSheetTheme.sizeGap),
      ],
      DownloadMark(item: item),
    ],
  );

  TextStyle _titleStyle(BuildContext context) => TextStyle(
    fontSize: DownloadSheetTheme.titleText,
    height: DownloadSheetTheme.titleLine / DownloadSheetTheme.titleText,
    color: entry.current ? DownloadSheetTheme.colorsOf(context).playing : BiliColors.colorsOf(context).text,
  );

  InlineSpan _title() => TextSpan(
    children: [
      if (entry.current)
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.only(right: DownloadSheetTheme.playingGap),
            child: PanelGlyph(PanelGlyphKind.playing, color: DownloadSheetTheme.playingBars),
          ),
        ),
      TextSpan(text: entry.title),
    ],
  );

  Widget _titleRow(BuildContext context, String? size) => SizedBox(
    height: DownloadSheetTheme.titleRowHeight,
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(
              left: DownloadSheetTheme.titleRowLead,
              right: DownloadSheetTheme.titleRowTrailing,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                _title(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(context),
                strutStyle: BiliFonts.strutOf(context, _titleStyle(context)),
              ),
            ),
          ),
        ),
        Positioned(right: DownloadSheetTheme.markInset, bottom: DownloadSheetTheme.markInset, child: _corner(context, size)),
      ],
    ),
  );

  Widget _coverRow(BuildContext context, String cover, String? size) {
    final seconds = entry.request.duration;
    return Padding(
      padding: const EdgeInsets.all(DownloadSheetTheme.coverRowPad),
      child: SizedBox(
        height: DownloadSheetTheme.coverHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DownloadSheetTheme.coverGap,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(BiliMetrics.cardRadius),
              child: SizedBox(
                width: DownloadSheetTheme.coverWidth,
                height: DownloadSheetTheme.coverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RemoteImage(
                      cover,
                      size: const Size(DownloadSheetTheme.coverWidth, DownloadSheetTheme.coverHeight),
                      cover: true,
                    ),
                    if (seconds > 0)
                      Positioned(
                        right: BiliMetrics.sheetBadgeInsetX,
                        bottom: BiliMetrics.sheetBadgeInsetY,
                        height: BiliMetrics.sheetBadgeHeight,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.sheetBadgePad),
                          decoration: BoxDecoration(
                            color: BiliColors.coverShade,
                            borderRadius: BorderRadius.circular(BiliMetrics.sheetBadgeRadius),
                          ),
                          child: Text(
                            TimeFormat.clock(seconds.toDouble()),
                            style: const TextStyle(
                              fontSize: BiliMetrics.sheetBadgeText,
                              height: 1,
                              color: BiliColors.onCover,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Text.rich(
                      _title(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(context),
                      strutStyle: BiliFonts.strutOf(context, _titleStyle(context)),
                    ),
                  ),
                  Positioned(right: 0, bottom: 0, child: _corner(context, size)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
