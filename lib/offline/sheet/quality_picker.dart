import 'dart:math' as math;

import 'package:bili_core/api.dart' show QualityOption;
import 'package:bili_core/logic.dart' show QualityNames, QualityRules;
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import '../offline_size.dart';
import 'sheet_art.dart';

/// 画质 (142): its own light sheet over everything, the screen dimmed behind it, one card of the qualities best first,
/// the chosen one pink and bold, 大会员 tagged, and (KaiC) each one's size for the part playing at the right. A pick
/// or a tap outside slides it away, then [dismissed] takes it off.
class QualityPicker extends StatefulWidget {
  const QualityPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.sizes,
    required this.onPick,
    required this.dismissed,
  });

  final List<QualityOption> options;
  final int? selected;

  /// The estimate for each quality id; a missing one shows no size.
  final Map<int, int> sizes;
  final ValueChanged<int> onPick;
  final VoidCallback dismissed;

  @override
  State<QualityPicker> createState() => _QualityPickerState();
}

class _QualityPickerState extends State<QualityPicker> with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 220),
  )..forward();
  late final _slide = CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  var _closing = false;

  @override
  void dispose() {
    _slide.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _close([int? pick]) {
    if (_closing) return;
    _closing = true;
    if (pick != null) widget.onPick(pick);
    _motion.reverse().whenCompleteOrCancel(() {
      if (mounted) widget.dismissed();
    });
  }

  static TextStyle _size(BuildContext context) => TextStyle(fontSize: DownloadSheetTheme.detailText, color: BiliColors.colorsOf(context).secondaryText);

  Widget _row(BuildContext context, QualityOption option, {required bool last}) {
    final chosen = option.id == widget.selected;
    final style = TextStyle(
      fontSize: DownloadSheetTheme.rowText,
      color: chosen ? BiliColors.colorsOf(context).pink : BiliColors.colorsOf(context).text,
      fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
    );
    final name = QualityNames.full(qn: option.id, serverText: option.name);
    final size = widget.sizes[option.id];
    return SheetTap(
      key: ValueKey('download-quality-${option.id}'),
      label: [name, if (QualityRules.needsVip(option.id)) '大会员', if (size != null) '约 ${formatBytes(size)}'].join('，'),
      selected: chosen,
      onTap: () => _close(option.id),
      child: Container(
        height: DownloadSheetTheme.rowHeight,
        margin: const EdgeInsets.only(left: DownloadSheetTheme.pickerRowLead),
        padding: const EdgeInsets.only(right: DownloadSheetTheme.pickerRowLead),
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: DownloadSheetTheme.colorsOf(context).hairline, width: BiliMetrics.panelHairline),
                ),
              ),
        child: Row(
          children: [
            // The name's Flexible would share the free space with a Spacer and leave each size mid-row.
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(name, maxLines: 1, style: style, strutStyle: BiliFonts.strutOf(context, style)),
                  ),
                  if (QualityRules.needsVip(option.id)) ...[
                    const SizedBox(width: BiliMetrics.panelBadgeGap),
                    const _VipTag(),
                  ],
                ],
              ),
            ),
            if (size != null) Text('约 ${formatBytes(size)}', key: const ValueKey('download-quality-size'), style: _size(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height =
        DownloadSheetTheme.pickerCardTop +
        widget.options.length * DownloadSheetTheme.rowHeight +
        DownloadSheetTheme.pickerBottom +
        bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sheet = math.min(height, constraints.maxHeight * 0.8);
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                label: '关闭',
                onTap: _close,
                child: GestureDetector(
                  key: const ValueKey('download-quality-dismiss'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: FadeTransition(
                    opacity: _slide,
                    child: const ColoredBox(color: BiliColors.sheetDim),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: sheet,
              child: AnimatedBuilder(
                animation: _slide,
                builder: (context, child) =>
                    Transform.translate(offset: Offset(0, (1 - _slide.value) * sheet), child: child),
                child: GestureDetector(
                  key: const ValueKey('download-quality-sheet'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DownloadSheetTheme.colorsOf(context).sheet,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(BiliMetrics.sheetRadius)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.only(top: BiliMetrics.sheetGrabberTop),
                          alignment: Alignment.topCenter,
                          height: DownloadSheetTheme.pickerCardTop,
                          child: Container(
                            width: BiliMetrics.sheetGrabberWidth,
                            height: BiliMetrics.sheetGrabberHeight,
                            decoration: BoxDecoration(
                              color: BiliColors.colorsOf(context).sheetGrabber,
                              borderRadius: BorderRadius.circular(BiliMetrics.sheetGrabberHeight / 2),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            primary: false,
                            padding: EdgeInsets.only(bottom: DownloadSheetTheme.pickerBottom + bottom),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: DownloadSheetTheme.cardInset),
                              decoration: BoxDecoration(
                                color: DownloadSheetTheme.colorsOf(context).card,
                                borderRadius: BorderRadius.circular(DownloadSheetTheme.cardRadius),
                              ),
                              child: Column(
                                children: [
                                  for (final (index, option) in widget.options.indexed)
                                    _row(context, option, last: index == widget.options.length - 1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// 142's pink 大会员 pill.
class _VipTag extends StatelessWidget {
  const _VipTag();

  static const _style = TextStyle(fontSize: BiliMetrics.panelSubtitleText, height: 1, color: BiliColors.onPink);

  @override
  Widget build(BuildContext context) => Container(
    height: BiliMetrics.panelBadgeHeight,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.panelBadgePad),
    decoration: BoxDecoration(
      color: BiliColors.colorsOf(context).pink,
      borderRadius: BorderRadius.circular(BiliMetrics.panelBadgeHeight / 2),
    ),
    child: Text('大会员', style: _style, strutStyle: BiliFonts.strutOf(context, _style)),
  );
}
