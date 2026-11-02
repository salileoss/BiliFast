import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import '../offline_models.dart';

/// A row's ⋮ on the offline page (159): the whole page dims, the player too, and a white sheet rises with 查看详情页
/// and 取消. An in-page layer, not a route: [item] holds the row it is for, and setting it to null (取消, a tap on the
/// dim, back) closes it.
class OfflineRowSheet extends StatefulWidget {
  const OfflineRowSheet({super.key, required this.item, required this.onDetails});

  final ValueNotifier<OfflineItem?> item;
  final ValueChanged<OfflineItem> onDetails;

  @override
  State<OfflineRowSheet> createState() => _OfflineRowSheetState();
}

class _OfflineRowSheetState extends State<OfflineRowSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: OfflinePageTheme.sheetIn,
    reverseDuration: OfflinePageTheme.sheetOut,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The row shown: the open one, or the one going away after a close.
  OfflineItem? _shown;

  @override
  void initState() {
    super.initState();
    widget.item.addListener(_changed);
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && widget.item.value == null && mounted) {
        setState(() => _shown = null);
      }
    });
    if (widget.item.value != null) _changed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _motion
      ..duration = still ? Duration.zero : OfflinePageTheme.sheetIn
      ..reverseDuration = still ? Duration.zero : OfflinePageTheme.sheetOut;
  }

  @override
  void didUpdateWidget(OfflineRowSheet oldWidget) {
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
        // Up, it is modal: VoiceOver reads only it, not the page under it.
        child: BlockSemantics(
          blocking: open,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('offline-sheet-dim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: FadeTransition(
                    opacity: _curve,
                    child: const ColoredBox(color: OfflinePageTheme.sheetDim),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(_curve),
                  child: _Sheet(onDetails: () => widget.onDetails(item), onCancel: _close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _style(BuildContext context, double size) => TextStyle(
  fontFamily: BiliFonts.family,
  fontSize: size,
  color: OfflinePageTheme.colorsOf(context).sheetInk,
  height: 1,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

class _Sheet extends StatelessWidget {
  const _Sheet({required this.onDetails, required this.onCancel});

  final VoidCallback onDetails;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('offline-sheet'),
    color: OfflinePageTheme.colorsOf(context).sheetBand,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Button(
          key: const ValueKey('offline-sheet-details'),
          label: '查看详情页',
          onTap: onDetails,
          child: SizedBox(
            height: OfflinePageTheme.sheetRowHeight,
            child: ColoredBox(
              color: OfflinePageTheme.colorsOf(context).sheetFill,
              child: Row(
                children: [
                  const SizedBox(width: OfflinePageTheme.sheetIconLeft),
                  CustomPaint(size: Size.square(OfflinePageTheme.sheetIcon), painter: _PlayRingPainter(palette: BiliPalette.of(context))),
                  const SizedBox(
                    width:
                        OfflinePageTheme.sheetLabelLeft - OfflinePageTheme.sheetIconLeft - OfflinePageTheme.sheetIcon,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -OfflinePageTheme.sheetLabelLift),
                    child: Text('查看详情页', style: _style(context, OfflinePageTheme.sheetLabelText)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: OfflinePageTheme.sheetBandHeight),
        _Button(
          key: const ValueKey('offline-sheet-cancel'),
          label: '取消',
          onTap: onCancel,
          child: SizedBox(
            height: OfflinePageTheme.sheetCancelHeight,
            child: ColoredBox(
              color: OfflinePageTheme.colorsOf(context).sheetFill,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -OfflinePageTheme.sheetCancelLift),
                  child: Text('取消', style: _style(context, OfflinePageTheme.sheetCancelText)),
                ),
              ),
            ),
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

/// 查看详情页's pink ring with a rounded ▷ in it (159).
class _PlayRingPainter extends CustomPainter {
  final BiliPalette palette;
  const _PlayRingPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = OfflinePageTheme.sheetIconStroke;
    final centre = size.center(Offset.zero);
    canvas.drawCircle(
      centre,
      size.shortestSide / 2 - stroke / 2,
      Paint()
        ..color = OfflinePageThemeColors(palette).sheetIconInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    // Its ink from 2.5 left of the centre to 4.2 right of it, 9 tall, the corners rounded by a 1 pt stroke round it.
    final s = size.shortestSide / OfflinePageTheme.sheetIcon;
    final path = Path()
      ..moveTo(centre.dx - 2 * s, centre.dy - 4 * s)
      ..lineTo(centre.dx + 3.5 * s, centre.dy)
      ..lineTo(centre.dx - 2 * s, centre.dy + 4 * s)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = OfflinePageThemeColors(palette).sheetIconInk
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = OfflinePageThemeColors(palette).sheetIconInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = s
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PlayRingPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
