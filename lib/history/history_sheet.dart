import 'package:bili_core/api.dart' show HistoryItem;
import 'package:flutter/widgets.dart';

import '../shared/theme.dart';
import 'history_glyphs.dart';

/// A row's ⋮ (48): the page dims and a white sheet rises with 分享, 删除 and 取消. Where the official app lists
/// third-party apps, one button hands the link to the system share sheet. An in-page layer, not a route: [item]
/// holds the row it is for, and setting it to null (取消, a tap on the dim, back) closes it.
class HistorySheet extends StatefulWidget {
  const HistorySheet({super.key, required this.item, required this.onShare, required this.onDelete});

  final ValueNotifier<HistoryItem?> item;
  final ValueChanged<HistoryItem> onShare;
  final ValueChanged<HistoryItem> onDelete;

  @override
  State<HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<HistorySheet> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: HistoryTheme.sheetIn,
    reverseDuration: HistoryTheme.sheetOut,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The row shown: the open one, or the one going away after a close.
  HistoryItem? _shown;

  @override
  void initState() {
    super.initState();
    widget.item.addListener(_changed);
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && widget.item.value == null && mounted) {
        setState(() => _shown = null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _motion
      ..duration = still ? Duration.zero : HistoryTheme.sheetIn
      ..reverseDuration = still ? Duration.zero : HistoryTheme.sheetOut;
  }

  @override
  void didUpdateWidget(HistorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.item, widget.item)) {
      oldWidget.item.removeListener(_changed);
      widget.item.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.item.removeListener(_changed);
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _changed() {
    final next = widget.item.value;
    if (next == null) {
      if (_shown != null) _motion.reverse();
      return;
    }
    setState(() => _shown = next);
    _motion.forward();
  }

  void _close() => widget.item.value = null;

  @override
  Widget build(BuildContext context) {
    final item = _shown;
    if (item == null) return const SizedBox.shrink();
    final open = widget.item.value != null;
    return IgnorePointer(
      ignoring: !open,
      child: ExcludeSemantics(
        excluding: !open,
        // Up, it is modal: VoiceOver reads only it, not the rows under it.
        child: BlockSemantics(
          blocking: open,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('history-sheet-dim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: FadeTransition(
                    opacity: _curve,
                    child: const ColoredBox(color: HistoryTheme.sheetDim),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(_curve),
                  child: _Sheet(
                    onShare: () => widget.onShare(item),
                    onDelete: () => widget.onDelete(item),
                    onCancel: _close,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _text(String text, double size, Color color) => Transform.translate(
  offset: Offset(0, HistoryTheme.sheetTextDrop),
  child: Text(text, style: _style(size, color)),
);

TextStyle _style(double size, Color color) => TextStyle(
  fontFamily: BiliFonts.family,
  fontSize: size,
  fontWeight: HistoryTheme.textWeight,
  color: color,
  height: 1,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

class _Sheet extends StatelessWidget {
  const _Sheet({required this.onShare, required this.onDelete, required this.onCancel});

  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('history-sheet'),
    color: HistoryTheme.colorsOf(context).sheetFill,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: HistoryTheme.sheetShareBottom,
          child: Stack(
            children: [
              Positioned(
                left: HistoryTheme.sheetHeaderInset,
                top: 0,
                height: HistoryTheme.sheetHeaderHeight,
                child: Center(child: _text('分享', HistoryTheme.sheetHeaderText, HistoryTheme.colorsOf(context).sheetHeaderInk)),
              ),
              Positioned(
                left: HistoryTheme.sheetItemCentre - HistoryTheme.sheetItemWidth / 2,
                top: HistoryTheme.sheetHeaderHeight,
                width: HistoryTheme.sheetItemWidth,
                child: _Button(
                  key: const ValueKey('history-share'),
                  label: '分享链接',
                  onTap: onShare,
                  child: Column(
                    children: [
                      Container(
                        width: HistoryTheme.sheetCircle,
                        height: HistoryTheme.sheetCircle,
                        decoration: BoxDecoration(color: HistoryTheme.colorsOf(context).sheetCircleFill, shape: BoxShape.circle),
                        child: const CustomPaint(painter: HistorySharePainter()),
                      ),
                      const SizedBox(height: HistoryTheme.sheetLabelGap),
                      _text('分享链接', HistoryTheme.sheetLabelText, HistoryTheme.colorsOf(context).sheetLabelInk),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: HistoryTheme.sheetDivider,
          child: ColoredBox(color: HistoryTheme.colorsOf(context).sheetDividerInk),
        ),
        SizedBox(
          height: HistoryTheme.sheetDeleteHeight,
          child: Stack(
            children: [
              Positioned(
                left: HistoryTheme.sheetItemCentre - HistoryTheme.sheetItemWidth / 2,
                top: 0,
                bottom: 0,
                width: HistoryTheme.sheetItemWidth,
                child: _Button(
                  key: const ValueKey('history-delete'),
                  label: '删除',
                  onTap: onDelete,
                  child: Column(
                    children: [
                      const SizedBox(height: HistoryTheme.sheetTrashTop),
                      SizedBox(
                        width: HistoryTheme.sheetTrashWidth,
                        height: HistoryTheme.sheetTrashHeight,
                        child: CustomPaint(painter: HistoryTrashPainter(colors: HistoryTheme.colorsOf(context))),
                      ),
                      const SizedBox(height: HistoryTheme.sheetDeleteLabelGap),
                      _text('删除', HistoryTheme.sheetLabelText, HistoryTheme.colorsOf(context).sheetDeleteInk),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: HistoryTheme.sheetBand,
          child: ColoredBox(color: HistoryTheme.colorsOf(context).sheetBandFill),
        ),
        _Button(
          key: const ValueKey('history-cancel'),
          label: '取消',
          onTap: onCancel,
          child: SizedBox(
            height: HistoryTheme.sheetCancelHeight,
            child: Center(child: _text('取消', HistoryTheme.sheetCancelText, HistoryTheme.colorsOf(context).sheetCancelInk)),
          ),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    ),
  );
}

class _Button extends StatelessWidget {
  const _Button({super.key, required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
  );
}
