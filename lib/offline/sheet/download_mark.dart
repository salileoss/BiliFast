import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import '../offline_models.dart';
import 'sheet_art.dart';

/// A row's state in 缓存: an empty ring (not cached), the pink progress round it from twelve o'clock (waiting and
/// downloading, 141 and 154: a dot at the top until bytes arrive), or 153's green ✓. Paused draws its progress grey,
/// a failure the ring red (no screenshot of either).
class DownloadMark extends StatelessWidget {
  const DownloadMark({super.key, required this.item});

  final OfflineItem? item;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item != null && item.isDone) {
      return const SizedBox.square(
        dimension: DownloadSheetTheme.mark,
        child: SheetIcon(SheetArt.done, width: DownloadSheetTheme.mark, color: DownloadSheetTheme.markDone),
      );
    }
    final (track, arc) = switch (item?.state) {
      null || OfflineState.done => (DownloadSheetTheme.colorsOf(context).markTrack, null),
      OfflineState.failed => (DownloadSheetTheme.markFailed, null),
      OfflineState.paused => (DownloadSheetTheme.colorsOf(context).markTrack, BiliColors.colorsOf(context).secondaryText),
      OfflineState.waiting || OfflineState.downloading => (DownloadSheetTheme.colorsOf(context).markTrack, DownloadSheetTheme.colorsOf(context).playing),
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(end: item?.progress ?? 0),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, progress, _) => CustomPaint(
        size: const Size.square(DownloadSheetTheme.mark),
        painter: _RingPainter(track: track, arc: arc, progress: progress),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.track, required this.arc, required this.progress});

  final Color track;
  final Color? arc;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = DownloadSheetTheme.markStroke;
    final ring = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.width - stroke) / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(ring, 0, math.pi * 2, false, paint..color = track);
    final arc = this.arc;
    if (arc == null) return;
    // A round cap alone draws the dot 141 shows before any bytes.
    canvas.drawArc(
      ring,
      -math.pi / 2,
      math.max(progress, 0.0001) * math.pi * 2,
      false,
      paint
        ..color = arc
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.track != track || oldDelegate.arc != arc || oldDelegate.progress != progress;
}
