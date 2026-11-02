import 'dart:io' show File;
import 'dart:math' as math;

import 'package:bili_core/logic.dart' show TimeFormat;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../history/history_glyphs.dart' show HistoryMorePainter, HistoryUpGlyph;
import '../../player/bili_player.dart' show PlayerStatus;
import '../../shared/cover_placeholder.dart';
import '../../shared/cover_preset.dart';
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../../video/page_tabs.dart' show DanmakuCapsule;
import '../offline_library.dart';
import '../offline_models.dart';
import '../pages/offline_selector.dart';

/// The finished parts the page lists, newest first as 离线缓存 does.
List<OfflineItem> offlinePageItems(OfflineLibrary library) => [
  for (final item in library.items)
    if (item.isDone) item,
];

/// 78.4M, 9.6M, 1.2G: one decimal and no B (158, 160).
String offlinePageSize(int bytes) {
  const mib = 1024 * 1024;
  if (bytes >= 1024 * mib) return '${(bytes / (1024 * mib)).toStringAsFixed(1)}G';
  if (bytes >= mib) return '${(bytes / mib).toStringAsFixed(1)}M';
  return '${(bytes / 1024).toStringAsFixed(1)}K';
}

/// The band under the player (158): 离线缓存 (N个视频) at the left, 点我发弹幕 joined to the 弹 toggle at the right, as
/// the page's tab row has it.
class OfflinePageHeader extends StatelessWidget {
  const OfflinePageHeader({
    super.key,
    required this.count,
    required this.danmakuOn,
    required this.onToggleDanmaku,
    required this.onSendDanmaku,
    this.danmakuInputOpen = false,
    this.danmakuClosed = false,
  });

  final int count;
  final bool danmakuOn;

  /// Null before the page has its session.
  final VoidCallback? onToggleDanmaku;
  final VoidCallback onSendDanmaku;
  final bool danmakuInputOpen;
  final bool danmakuClosed;

  @override
  Widget build(BuildContext context) {
    final title = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: OfflinePageTheme.titleText,
      fontWeight: OfflinePageTheme.titleWeight,
      color: OfflinePageTheme.colorsOf(context).titleInk,
      height: 1,
      letterSpacing: 0,
    );
    final countStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: OfflinePageTheme.countText,
      color: OfflinePageTheme.colorsOf(context).countInk,
      height: 1,
      letterSpacing: 0,
    );
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: OfflinePageTheme.headerHeight,
      child: ColoredBox(
        color: BiliColors.colorsOf(context).card,
        child: Stack(
          children: [
            Positioned(
              left: OfflinePageTheme.gutter,
              top: OfflinePageTheme.titleCentre - OfflinePageTheme.titleText / 2,
              height: OfflinePageTheme.titleText,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('离线缓存', key: const ValueKey('offline-title'), style: title),
                  const SizedBox(width: OfflinePageTheme.countGap),
                  Text('（$count个视频）', key: const ValueKey('offline-count'), style: countStyle),
                ],
              ),
            ),
            Positioned(
              right: OfflinePageTheme.gutter,
              top: OfflinePageTheme.capsuleCentre - OfflinePageTheme.capsuleHeight / 2,
              height: OfflinePageTheme.capsuleHeight,
              child: DanmakuCapsule(
                on: danmakuOn,
                onToggle: onToggleDanmaku,
                onSend: danmakuClosed ? null : onSendDanmaku,
                text: danmakuClosed ? 'UP主已关闭弹幕' : (danmakuInputOpen ? '弹幕输入中' : '点我发弹幕'),
                duration: still ? Duration.zero : const Duration(milliseconds: 250),
                height: OfflinePageTheme.capsuleHeight,
                border: OfflinePageTheme.capsuleBorder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every finished part under the band (158, 160): cover with its length, the title (the one playing pink behind its
/// bars), UP and the uploader, and the size, 大会员专享 in pink for a 大会员 quality; ⋮ opens the row's sheet. A tap
/// plays the part on this page. The footer says the list holds only what this app can show.
class OfflinePageList extends StatelessWidget {
  const OfflinePageList({
    super.key,
    required this.library,
    required this.playing,
    required this.status,
    required this.onPlay,
    required this.onMore,
    this.controller,
  });

  final OfflineLibrary library;

  /// The part on the player; its row is pink.
  final int? playing;

  /// The player's status: the bars move while it plays. Null before the page has its session.
  final ValueListenable<PlayerStatus>? status;
  final ValueChanged<OfflineItem> onPlay;
  final ValueChanged<OfflineItem> onMore;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => LibrarySelector<List<OfflineItem>>(
    library: library,
    select: offlinePageItems,
    equals: listEquals,
    builder: (context, items) {
      final bottom = MediaQuery.paddingOf(context).bottom;
      return ColoredBox(
        color: BiliColors.colorsOf(context).card,
        child: ListView.builder(
          key: const ValueKey('offline-list'),
          controller: controller,
          primary: false,
          padding: EdgeInsets.only(bottom: bottom + OfflinePageTheme.footerBottom),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) return const _Footer();
            final item = items[index];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index > 0)
                  Padding(
                    padding: EdgeInsets.only(left: OfflinePageTheme.gutter),
                    child: SizedBox(
                      height: OfflinePageTheme.hairline,
                      width: double.infinity,
                      child: ColoredBox(color: OfflinePageTheme.colorsOf(context).divider),
                    ),
                  ),
                _Row(
                  key: ValueKey('offline-row-${item.cid}'),
                  item: item,
                  playing: item.cid == playing,
                  status: status,
                  onTap: () => onPlay(item),
                  onMore: () => onMore(item),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: OfflinePageTheme.footerText,
      color: OfflinePageTheme.colorsOf(context).footerInk,
      height: 1,
      letterSpacing: 0,
    );
    return SizedBox(
      height: OfflinePageTheme.footerCentre + OfflinePageTheme.footerText / 2,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Text('仅展示本App中可查看的稿件', key: const ValueKey('offline-footer'), style: style),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.item,
    required this.playing,
    required this.status,
    required this.onTap,
    required this.onMore,
  });

  final OfflineItem item;
  final bool playing;
  final ValueListenable<PlayerStatus>? status;
  final VoidCallback onTap;
  final VoidCallback onMore;

  TextStyle _meta(BuildContext context) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: OfflinePageTheme.metaText,
    height: OfflinePageTheme.metaLine / OfflinePageTheme.metaText,
    color: OfflinePageTheme.colorsOf(context).meta,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final request = item.request;
    final title = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: OfflinePageTheme.rowTitleText,
      height: OfflinePageTheme.rowTitleLine / OfflinePageTheme.rowTitleText,
      color: playing ? OfflinePageTheme.colorsOf(context).playing : OfflinePageTheme.colorsOf(context).rowTitle,
      letterSpacing: 0,
    );
    final size = offlinePageSize(item.totalBytes > 0 ? item.totalBytes : item.bytes);
    const coverTop = OfflinePageTheme.rowPadTop;
    const textLeft = OfflinePageTheme.gutter + OfflinePageTheme.coverWidth + OfflinePageTheme.textGap;
    return SizedBox(
      height: OfflinePageTheme.rowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              selected: playing,
              label: request.title,
              onTap: onTap,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Stack(
                  children: [
                    Positioned(
                      left: OfflinePageTheme.gutter,
                      top: coverTop,
                      width: OfflinePageTheme.coverWidth,
                      height: OfflinePageTheme.coverHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(OfflinePageTheme.coverRadius),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _Cover(item: item),
                            if (request.duration > 0)
                              Positioned(
                                right: OfflinePageTheme.pillRight,
                                bottom: OfflinePageTheme.pillBottom,
                                height: OfflinePageTheme.pillHeight,
                                child: _Pill(seconds: request.duration),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: textLeft,
                      right: OfflinePageTheme.titleRight,
                      top: coverTop + OfflinePageTheme.rowTitleTop,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (playing)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.aboveBaseline,
                                baseline: TextBaseline.alphabetic,
                                child: _PlayingBars(status: status),
                              ),
                            TextSpan(text: request.title),
                          ],
                        ),
                        key: const ValueKey('offline-row-title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: title,
                        strutStyle: BiliFonts.strut(title),
                      ),
                    ),
                    _line(
                      OfflinePageTheme.upCentre,
                      Row(
                        children: [
                          const SizedBox(
                            width: OfflinePageTheme.upBox,
                            height: OfflinePageTheme.metaLine,
                            child: HistoryUpGlyph(),
                          ),
                          const SizedBox(width: OfflinePageTheme.upGap),
                          Flexible(
                            child: Text(
                              request.ownerName,
                              key: const ValueKey('offline-row-owner'),
                              style: _meta(context),
                              strutStyle: BiliFonts.strut(_meta(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _line(
                      OfflinePageTheme.sizeCentre,
                      Text(
                        item.vipOnly ? '大会员专享 · $size' : size,
                        key: const ValueKey('offline-row-size'),
                        style: item.vipOnly ? _meta(context).copyWith(color: OfflinePageTheme.colorsOf(context).vip) : _meta(context),
                        strutStyle: BiliFonts.strut(_meta(context)),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: OfflinePageTheme.moreCentreRight - OfflinePageTheme.moreTarget / 2,
            top: coverTop + OfflinePageTheme.sizeCentre - OfflinePageTheme.moreTarget / 2,
            width: OfflinePageTheme.moreTarget,
            height: OfflinePageTheme.moreTarget,
            child: Semantics(
              button: true,
              label: '更多',
              onTap: onMore,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('offline-row-more'),
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: const CustomPaint(painter: HistoryMorePainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A meta line, its box centred [centre] below the cover's top.
  Widget _line(double centre, Widget child) => Positioned(
    left: OfflinePageTheme.gutter + OfflinePageTheme.coverWidth + OfflinePageTheme.textGap,
    right: OfflinePageTheme.moreCentreRight + OfflinePageTheme.moreTarget / 2,
    top: OfflinePageTheme.rowPadTop + centre - OfflinePageTheme.metaLine / 2,
    height: OfflinePageTheme.metaLine,
    child: Align(alignment: Alignment.centerLeft, child: child),
  );
}

/// The cover kept with the files, or Bilibili's until it is saved; the grey 小电视 without either.
class _Cover extends StatelessWidget {
  const _Cover({required this.item});

  final OfflineItem item;

  @override
  Widget build(BuildContext context) {
    if (item.coverFile case final path?) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stack) => const CoverPlaceholder(),
      );
    }
    return RemoteImage(
      item.request.cover,
      size: const Size(OfflinePageTheme.coverWidth, OfflinePageTheme.coverHeight),
      cover: true,
      preset: CoverPreset.history,
      fallback: const CoverPlaceholder(),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: OfflinePageTheme.pillPadX),
    decoration: BoxDecoration(
      color: OfflinePageTheme.pillFill,
      borderRadius: BorderRadius.circular(OfflinePageTheme.pillRadius),
    ),
    child: Text(
      TimeFormat.clock(seconds.toDouble()),
      key: const ValueKey('offline-row-duration'),
      style: TextStyle(
        fontFamily: BiliFonts.family,
        fontSize: OfflinePageTheme.pillText,
        height: 1,
        color: OfflinePageTheme.pillInk,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Three bars standing on the title's line, rising and falling one after another while the video plays; at rest as
/// 160 caught them.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars({required this.status});

  final ValueListenable<PlayerStatus>? status;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, duration: OfflinePageTheme.barsCycle);

  @override
  void initState() {
    super.initState();
    widget.status?.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      oldWidget.status?.removeListener(_sync);
      widget.status?.addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    final moving = widget.status?.value == PlayerStatus.playing && !MediaQuery.disableAnimationsOf(context);
    if (moving && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!moving && _motion.isAnimating) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    widget.status?.removeListener(_sync);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      left: OfflinePageTheme.barsLead,
      right: OfflinePageTheme.barsGap - OfflinePageTheme.barsLead,
      bottom: OfflinePageTheme.barsLift,
    ),
    child: CustomPaint(
      key: const ValueKey('offline-playing-bars'),
      size: const Size(OfflinePageTheme.barsWidth, OfflinePageTheme.barsHeight),
      painter: _BarsPainter(_motion),
    ),
  );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.motion) : super(repaint: motion);

  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = OfflinePageTheme.barsInk;
    final moving = motion.value > 0;
    for (var i = 0; i < 3; i++) {
      final double height;
      if (moving) {
        final wave = (math.sin((motion.value + i / 3) * 2 * math.pi) + 1) / 2;
        height = OfflinePageTheme.barMin + (size.height - OfflinePageTheme.barMin) * wave;
      } else {
        height = OfflinePageTheme.barRest[i];
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * OfflinePageTheme.barPitch, size.height - height, OfflinePageTheme.barWidth, height),
          const Radius.circular(OfflinePageTheme.barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => oldDelegate.motion != motion;
}
