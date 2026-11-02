import 'package:bili_core/api.dart' show SpaceVideo;
import 'package:bili_core/logic.dart' show CountFormat, TimeFormat;
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/widgets.dart';

import '../player_ui/end_screen_portrait.dart' show CountGlyph, CountPainter;
import '../shared/loading_tv.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';

TextStyle sheetStyle(double size, Color color, {double? line, FontWeight? weight}) => TextStyle(
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

/// One of the uploader's videos (68, 76): the 16:9 cover with ▶ plays, the date and the length on it, and the title
/// in two lines; the page's own video draws its title pink after the playing mark (62, 68).
class UploaderVideoCard extends StatelessWidget {
  const UploaderVideoCard({super.key, required this.video, required this.playing, required this.onOpen});

  final SpaceVideo video;
  final bool playing;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = sheetStyle(
      UploaderSheetTheme.titleText,
      playing ? UploaderSheetTheme.colorsOf(context).playingInk : UploaderSheetTheme.colorsOf(context).titleInk,
      line: UploaderSheetTheme.titleLine,
    );
    return Semantics(
      button: true,
      label: playing ? '正在播放：${video.title}' : video.title,
      onTap: onOpen,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: UploaderSheetTheme.coverAspect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(UploaderSheetTheme.coverRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RemoteImage(video.cover, cover: true),
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: UploaderSheetTheme.coverShadeHeight,
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [BiliColors.chromeShadeClear, BiliColors.coverShade],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: UploaderSheetTheme.statLeft,
                      right: UploaderSheetTheme.statRight,
                      bottom: UploaderSheetTheme.statCentre - UploaderSheetTheme.statLine / 2,
                      height: UploaderSheetTheme.statLine,
                      child: _Stats(video: video),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: UploaderSheetTheme.titleTop),
              child: Text.rich(
                TextSpan(
                  children: [
                    if (playing) const WidgetSpan(alignment: PlaceholderAlignment.middle, child: PlayingMark()),
                    TextSpan(text: video.title),
                  ],
                ),
                key: ValueKey('uploader-sheet-title-${video.bvid}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: title,
                strutStyle: BiliFonts.strut(title),
              ),
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
    final style = sheetStyle(
      UploaderSheetTheme.statText,
      UploaderSheetTheme.statInk,
      line: UploaderSheetTheme.statLine,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final strut = BiliFonts.strut(style);
    return DefaultTextStyle(
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      // On a card too narrow for them all, the date gives way before the length does.
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: UploaderSheetTheme.statIconDrop),
                  child: CustomPaint(
                    size: Size(UploaderSheetTheme.statIconWidth, UploaderSheetTheme.statIconHeight),
                    painter: CountPainter(CountGlyph.views, color: UploaderSheetTheme.statInk),
                  ),
                ),
                const SizedBox(width: UploaderSheetTheme.statIconGap),
                Text(CountFormat.short(video.play), strutStyle: strut),
                const SizedBox(width: UploaderSheetTheme.statDateGap),
                Flexible(child: Text(video.publishedText, strutStyle: strut)),
              ],
            ),
          ),
          Text(TimeFormat.clock(video.duration.toDouble()), strutStyle: strut),
        ],
      ),
    );
  }
}

/// The three bars before the playing video's title.
class PlayingMark extends StatelessWidget {
  const PlayingMark({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(
      left: UploaderSheetTheme.barsLead,
      right: UploaderSheetTheme.barsTrail,
      top: UploaderSheetTheme.barsDrop * 2,
    ),
    child: CustomPaint(
      key: ValueKey('uploader-sheet-playing'),
      size: Size(UploaderSheetTheme.barWidth + UploaderSheetTheme.barPitch * 2, UploaderSheetTheme.barTall),
      painter: _BarsPainter(),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = UploaderSheetTheme.barsInk;
    const half = UploaderSheetTheme.barWidth / 2;
    final middle = size.height / 2;
    for (final (i, height) in const [
      UploaderSheetTheme.barTall,
      UploaderSheetTheme.barShort,
      UploaderSheetTheme.barTall,
    ].indexed) {
      final x = half + i * UploaderSheetTheme.barPitch;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, middle), width: UploaderSheetTheme.barWidth, height: height),
          const Radius.circular(half),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => false;
}

/// Under the grid: the next page's spinner, 已经到底啦~ (76), or 加载失败，点击重试. Idle with more to come it stays
/// empty: the next page is asked for before the end shows.
class UploaderSheetFooter extends StatelessWidget {
  const UploaderSheetFooter({
    super.key,
    required this.loading,
    required this.error,
    required this.isEnd,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final bool isEnd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final style = sheetStyle(UploaderSheetTheme.endText, UploaderSheetTheme.colorsOf(context).endInk);
    final Widget? child;
    if (error != null && !loading) {
      child = Semantics(
        key: const ValueKey('uploader-sheet-footer-retry'),
        button: true,
        label: '加载失败，点击重试',
        onTap: onRetry,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRetry,
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '加载失败，', style: style),
                  TextSpan(
                    text: '点击重试',
                    style: style.copyWith(color: BiliColors.colorsOf(context).link),
                  ),
                ],
              ),
              strutStyle: BiliFonts.strutOf(context, style),
            ),
          ),
        ),
      );
    } else if (isEnd && !loading) {
      child = Center(
        child: Text('已经到底啦~', key: const ValueKey('uploader-sheet-end'), style: style),
      );
    } else if (loading) {
      child = const Center(
        child: CupertinoActivityIndicator(
          key: ValueKey('uploader-sheet-loading-more'),
          radius: UploaderSheetTheme.spinnerRadius,
        ),
      );
    } else {
      child = null;
    }
    return SizedBox(height: UploaderSheetTheme.footerHeight, child: child);
  }
}

/// The first page: the loading TV while it comes, or why it didn't with 重试.
class UploaderSheetFirstLoad extends StatelessWidget {
  const UploaderSheetFirstLoad({super.key, required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error;
    if (message == null) return const Center(child: LoadingTvState(key: ValueKey('uploader-sheet-first-load')));
    final style = sheetStyle(UploaderSheetTheme.stateText, UploaderSheetTheme.colorsOf(context).stateInk);
    return Center(
      key: const ValueKey('uploader-sheet-failed'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UploaderSheetTheme.side),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: style, strutStyle: BiliFonts.strutOf(context, style)),
            const SizedBox(height: UploaderSheetTheme.stateGap),
            Semantics(
              button: true,
              label: '重试',
              onTap: onRetry,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('uploader-sheet-retry'),
                behavior: HitTestBehavior.opaque,
                onTap: onRetry,
                child: Container(
                  height: UploaderSheetTheme.retryHeight,
                  padding: const EdgeInsets.symmetric(horizontal: UploaderSheetTheme.retryPadX),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(
                      side: BorderSide(color: BiliColors.colorsOf(context).pink, width: UploaderSheetTheme.retryRim),
                    ),
                  ),
                  child: Text('重试', style: sheetStyle(UploaderSheetTheme.retryText, BiliColors.colorsOf(context).pink)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grid stops at its top, so a pull there drags the sheet down instead (its overscroll); it still bounces at the
/// end.
class SheetGridPhysics extends BouncingScrollPhysics {
  const SheetGridPhysics({super.parent});

  @override
  SheetGridPhysics applyTo(ScrollPhysics? ancestor) => SheetGridPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels && position.pixels <= position.minScrollExtent) return value - position.pixels;
    if (value < position.minScrollExtent && position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
