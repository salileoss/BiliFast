import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../history/history_glyphs.dart' show HistoryUpGlyph;
import '../../shared/cover_placeholder.dart';
import '../../shared/cover_preset.dart';
import '../../shared/menu.dart' show PressHighlight;
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../offline_library.dart';
import '../offline_models.dart';
import '../offline_size.dart';
import 'offline_glyphs.dart';
import 'offline_selector.dart';
import 'offline_shelf.dart';
import 'offline_text.dart';

typedef _T = OfflineListTheme;

/// Where a saved file is: [path] itself when absolute, else inside the disk library's folder.
String? savedFile(OfflineLibrary library, String? path) {
  if (path == null || path.isEmpty) return null;
  if (File(path).isAbsolute) return path;
  return library is DiskOfflineLibrary ? '${library.folder}${Platform.pathSeparator}$path' : null;
}

/// A part's cover: the copy on the phone, else Bilibili's, under [overlay].
class OfflineCover extends StatelessWidget {
  const OfflineCover({super.key, required this.library, required this.item, this.overlay});

  final OfflineLibrary library;
  final OfflineItem item;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final remote = RemoteImage(
      item.request.cover,
      size: const Size(_T.coverWidth, _T.coverHeight),
      cover: true,
      preset: CoverPreset.history,
      fallback: const CoverPlaceholder(),
    );
    final file = savedFile(library, item.coverFile);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(_T.coverRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file == null)
            remote
          else
            Image.file(
              File(file),
              fit: BoxFit.cover,
              cacheWidth: (_T.coverWidth * ratio).round(),
              excludeFromSemantics: true,
              errorBuilder: (context, error, stack) => remote,
            ),
          ?overlay,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    right: _T.pillRight,
    bottom: _T.pillBottom,
    height: _T.pillHeight,
    child: DecoratedBox(
      decoration: BoxDecoration(color: _T.pillFill, borderRadius: BorderRadius.circular(_T.pillRadius)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _T.pillPadX),
        child: Center(widthFactor: 1, child: child),
      ),
    ),
  );
}

TextStyle get _pillStyle => offlineStyle(_T.pillText, _T.pillInk, line: _T.pillHeight);

/// A finished part's cover marks (145, 156): the length or watched / length, and the watched line.
class _DoneMarks extends StatelessWidget {
  const _DoneMarks({required this.item});

  final OfflineItem item;

  @override
  Widget build(BuildContext context) {
    final duration = item.request.duration;
    final watched = item.position > 0 && duration > 0 ? (item.position / duration).clamp(0.0, 1.0) : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        _Pill(
          child: Text(coverTime(item), key: ValueKey('offline-time-${item.cid}'), maxLines: 1, style: _pillStyle),
        ),
        if (watched != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _T.watchedHeight,
            child: Stack(
              key: ValueKey('offline-watched-${item.cid}'),
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: _T.watchedTrack),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: watched,
                  child: ColoredBox(color: _T.colorsOf(context).watched),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A 合集's cover marks (155): the stack and how many parts.
class _GroupMarks extends StatelessWidget {
  const _GroupMarks({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _Pill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StackGlyph(),
            const SizedBox(width: _T.stackGap),
            Text('$count', maxLines: 1, style: _pillStyle),
          ],
        ),
      ),
    ],
  );
}

/// 正在缓存's stacked cover (143, 145): shaded, N个内容 on its middle.
class _QueueMarks extends StatelessWidget {
  const _QueueMarks({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final style = offlineStyle(_T.queueCountText, _T.pillInk);
    return ColoredBox(
      color: _T.queueShade,
      child: Center(
        child: Text('$count个内容', key: const ValueKey('offline-queue-count'), maxLines: 1, style: style),
      ),
    );
  }
}

/// The line under a part's words: pink while it downloads, grey otherwise.
class OfflineProgress extends StatelessWidget {
  const OfflineProgress({super.key, required this.item});

  final OfflineItem item;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(_T.progressHeight / 2),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _T.colorsOf(context).progressTrack),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: item.progress,
          child: ColoredBox(
            key: ValueKey('offline-progress-${item.cid}-${item.state.name}'),
            color: item.state == OfflineState.downloading ? _T.colorsOf(context).progressActive : _T.colorsOf(context).progressIdle,
          ),
        ),
      ],
    ),
  );
}

/// A line's words placed by their middle, [centre] under the cover's top.
Widget _at(double centre, double line, Widget child) =>
    Positioned(left: 0, right: 0, top: _T.coverTop + centre - line / 2, height: line, child: child);

/// The row's frame (102 tall): the cover and the words, the press, and in edit mode the circle with everything 32
/// to its right. A tap opens or acts; in edit mode it chooses.
class OfflineRowFrame extends StatelessWidget {
  const OfflineRowFrame({
    super.key,
    required this.rowKey,
    required this.editing,
    required this.chosen,
    required this.label,
    required this.onTap,
    required this.divider,
    required this.cover,
    required this.words,
    this.card = false,
  });

  /// Names the row's tap target and circle for tests.
  final String rowKey;
  final bool editing;
  final bool chosen;
  final String label;
  final VoidCallback onTap;

  /// A hairline under the row: every row but a list's last.
  final bool divider;
  final Widget cover;

  /// Placed from the words' left edge and the row's top.
  final List<Widget> words;

  /// 正在缓存's grey card behind the cover.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final semantics = editing ? '${chosen ? '已选' : '未选'}，$label' : label;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: editing ? 1 : 0),
      duration: reduceMotion ? Duration.zero : _T.editMotion,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final shift = t * _T.editShift;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                selected: editing && chosen,
                label: semantics,
                onTap: onTap,
                excludeSemantics: true,
                child: PressHighlight(
                  key: ValueKey('offline-row-$rowKey'),
                  onTap: onTap,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (t > 0)
              Positioned(
                left: _T.circleCentreX - _T.circle / 2 - (1 - t) * _T.editShift,
                top: _T.coverTop + _T.coverHeight / 2 - _T.circle / 2,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: t,
                    child: OfflineChoiceCircle(key: ValueKey('offline-circle-$rowKey'), chosen: chosen),
                  ),
                ),
              ),
            if (card)
              Positioned(
                left: _T.coverLeft + _T.stackCardInset + shift,
                top: _T.coverTop - _T.stackCardRise,
                width: _T.coverWidth - _T.stackCardInset * 2,
                height: _T.stackCardRise + _T.coverRadius,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _T.colorsOf(context).stackCard,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(_T.coverRadius)),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: _T.coverLeft + shift,
              top: _T.coverTop,
              width: _T.coverWidth,
              height: _T.coverHeight,
              child: IgnorePointer(child: cover),
            ),
            Positioned(
              left: _T.textLeft + shift,
              right: _T.textRight,
              top: 0,
              height: _T.row,
              child: IgnorePointer(
                child: Stack(clipBehavior: Clip.none, children: words),
              ),
            ),
            if (divider)
              Positioned(
                left: _T.coverLeft + shift,
                right: 0,
                top: _T.row - _T.dividerHeight / 2,
                height: _T.dividerHeight,
                child: ColoredBox(color: _T.colorsOf(context).divider),
              ),
          ],
        );
      },
    );
  }
}

/// The title, up to [maxLines] lines from the cover's top.
Widget _title(BuildContext context, String text, {int maxLines = 2, Key? key}) {
  final style = offlineStyle(_T.rowTitleText, _T.colorsOf(context).ink, line: _T.rowTitleLine);
  return Positioned(
    left: 0,
    right: 0,
    top: _T.coverTop + _T.rowTitleCentre - _T.rowTitleLine / 2,
    child: Text(
      text,
      key: key,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
      strutStyle: BiliFonts.strut(style),
    ),
  );
}

/// What 正在缓存 shows of a part: a 合集 episode's 合集 then the episode, a part's video then the part, else the title
/// over two lines.
({String first, String? second}) queueLines(OfflineRequest request) {
  final collection = request.collection;
  if (collection != null) return (first: collection.title, second: request.title);
  return (first: request.title, second: request.partTitle);
}

List<Widget> _queueWords(BuildContext context, OfflineItem item) {
  final lines = queueLines(item.request);
  final second = lines.second;
  final sub = offlineStyle(_T.subText, _T.colorsOf(context).grey, line: _T.subLine);
  final state = offlineStyle(_T.stateText, _T.colorsOf(context).grey, line: _T.stateLine);
  return [
    _title(context, lines.first, maxLines: second == null ? 2 : 1, key: ValueKey('offline-title-${item.cid}')),
    if (second != null) _at(_T.subCentre, _T.subLine, offlineLine(second, sub)),
    _at(_T.stateCentre, _T.stateLine, offlineLine(stateLabel(item), state, key: ValueKey('offline-state-${item.cid}'))),
    Positioned(
      left: 0,
      right: 0,
      top: _T.coverTop + _T.coverHeight - _T.progressHeight,
      height: _T.progressHeight,
      child: OfflineProgress(item: item),
    ),
  ];
}

TextStyle _meta(Color color) => offlineStyle(_T.metaText, color, line: _T.metaLine);

Widget _sizeLine(BuildContext context, int bytes, {bool vip = false, Key? key}) => _at(
  _T.sizeCentre,
  _T.metaLine,
  offlineLine(vip ? '大会员专享 · ${formatBytes(bytes)}' : formatBytes(bytes), _meta(vip ? _T.colorsOf(context).vip : _T.colorsOf(context).meta), key: key),
);

/// A finished part (145, 156): the cover with its time and watched line, the title, UP and the name, the size.
class DoneRow extends StatelessWidget {
  const DoneRow({
    super.key,
    required this.library,
    required this.cid,
    required this.editing,
    required this.chosen,
    required this.divider,
    required this.onTap,
    this.titleOf,
  });

  final OfflineLibrary library;
  final int cid;
  final bool editing;
  final bool chosen;
  final bool divider;
  final ValueChanged<OfflineItem> onTap;

  /// The row's title; the video's by default (a video's own page lists its parts by their names).
  final String Function(OfflineItem item)? titleOf;

  @override
  Widget build(BuildContext context) => LibrarySelector<OfflineItem?>(
    library: library,
    select: (library) => library.item(cid),
    builder: (context, item) {
      if (item == null) return const SizedBox.shrink();
      final title = titleOf?.call(item) ?? item.request.title;
      final name = item.request.ownerName;
      return OfflineRowFrame(
        rowKey: '$cid',
        editing: editing,
        chosen: chosen,
        label: '$title，$name，${formatBytes(item.bytes)}',
        onTap: () => onTap(item),
        divider: divider,
        cover: OfflineCover(
          library: library,
          item: item,
          overlay: _DoneMarks(item: item),
        ),
        words: [
          _title(context, title, key: ValueKey('offline-title-$cid')),
          _at(
            _T.upCentre,
            _T.metaLine,
            Row(
              children: [
                const SizedBox(width: _T.metaInset),
                SizedBox(
                  width: _T.upBox,
                  height: _T.metaLine,
                  child: Transform.translate(offset: const Offset(0, -_T.upLift), child: const HistoryUpGlyph()),
                ),
                const SizedBox(width: _T.upGap),
                Flexible(child: offlineLine(name, _meta(_T.colorsOf(context).meta))),
              ],
            ),
          ),
          _sizeLine(context, item.bytes, vip: item.vipOnly, key: ValueKey('offline-size-$cid')),
        ],
      );
    },
  );
}

/// A 合集's or a video's finished parts (155): the first part's cover with the stack and count, the name, the size.
class GroupRow extends StatelessWidget {
  const GroupRow({
    super.key,
    required this.library,
    required this.entry,
    required this.editing,
    required this.chosen,
    required this.divider,
    required this.onTap,
  });

  final OfflineLibrary library;
  final GroupEntry entry;
  final bool editing;
  final bool chosen;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LibrarySelector<(OfflineItem?, int)>(
    library: library,
    select: (library) =>
        (library.item(entry.cids.first), entry.cids.fold<int>(0, (sum, cid) => sum + (library.item(cid)?.bytes ?? 0))),
    builder: (context, value) {
      final (first, bytes) = value;
      if (first == null) return const SizedBox.shrink();
      return OfflineRowFrame(
        rowKey: entry.key,
        editing: editing,
        chosen: chosen,
        label: '${entry.title}，${entry.cids.length}个视频，${formatBytes(bytes)}',
        onTap: onTap,
        divider: divider,
        cover: OfflineCover(
          library: library,
          item: first,
          overlay: _GroupMarks(count: entry.cids.length),
        ),
        words: [
          _title(context, entry.title, key: ValueKey('offline-title-${entry.key}')),
          _sizeLine(context, bytes, key: ValueKey('offline-size-${entry.key}')),
        ],
      );
    },
  );
}

/// One unfinished part on 正在缓存 (146-149): its lines, state and progress. A tap pauses or starts it.
class QueueRow extends StatelessWidget {
  const QueueRow({
    super.key,
    required this.library,
    required this.cid,
    required this.editing,
    required this.chosen,
    required this.divider,
    required this.onTap,
  });

  final OfflineLibrary library;
  final int cid;
  final bool editing;
  final bool chosen;
  final bool divider;
  final ValueChanged<OfflineItem> onTap;

  @override
  Widget build(BuildContext context) => LibrarySelector<OfflineItem?>(
    library: library,
    select: (library) => library.item(cid),
    builder: (context, item) {
      if (item == null) return const SizedBox.shrink();
      final lines = queueLines(item.request);
      return OfflineRowFrame(
        rowKey: '$cid',
        editing: editing,
        chosen: chosen,
        label: [lines.first, ?lines.second, stateLabel(item)].join('，'),
        onTap: () => onTap(item),
        divider: divider,
        cover: OfflineCover(library: library, item: item),
        words: _queueWords(context, item),
      );
    },
  );
}

/// 离线缓存's 正在缓存 (143, 145): every unfinished part under one stacked cover, the one downloading (else the first
/// queued) shown. A tap opens 正在缓存.
class QueueStackRow extends StatelessWidget {
  const QueueStackRow({
    super.key,
    required this.library,
    required this.cids,
    required this.editing,
    required this.chosen,
    required this.onTap,
  });

  final OfflineLibrary library;
  final List<int> cids;
  final bool editing;
  final bool chosen;
  final VoidCallback onTap;

  static OfflineItem? lead(OfflineLibrary library, List<int> cids) {
    OfflineItem? first;
    for (final cid in cids) {
      final item = library.item(cid);
      if (item == null) continue;
      if (item.state == OfflineState.downloading) return item;
      first ??= item;
    }
    return first;
  }

  @override
  Widget build(BuildContext context) => LibrarySelector<OfflineItem?>(
    library: library,
    select: (library) => lead(library, cids),
    builder: (context, item) {
      if (item == null) return const SizedBox.shrink();
      final lines = queueLines(item.request);
      return OfflineRowFrame(
        rowKey: 'queue',
        editing: editing,
        chosen: chosen,
        label: ['正在缓存${cids.length}个内容', lines.first, ?lines.second, stateLabel(item)].join('，'),
        onTap: onTap,
        divider: false,
        card: true,
        cover: OfflineCover(
          library: library,
          item: item,
          overlay: _QueueMarks(count: cids.length),
        ),
        words: _queueWords(context, item),
      );
    },
  );
}

/// 正在缓存 and 已缓存视频 (143, 145).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final style = offlineStyle(_T.headerText, _T.colorsOf(context).ink, line: _T.titleLine, weight: _T.headerWeight);
    return SizedBox(
      height: _T.headerHeight,
      child: Stack(
        children: [
          Positioned(
            left: _T.headerLeft,
            right: _T.headerLeft,
            top: _T.headerCentre - _T.titleLine / 2,
            height: _T.titleLine,
            child: offlineLine(title, style),
          ),
        ],
      ),
    );
  }
}

/// 已使用 / 剩余 at the bottom, its middle [centre] above the home indicator's inset.
class SpaceFooter extends StatelessWidget {
  const SpaceFooter({super.key, required this.library, this.centre = _T.footerCentre});

  final OfflineLibrary library;
  final double centre;

  @override
  Widget build(BuildContext context) {
    final style = offlineStyle(_T.footerText, _T.colorsOf(context).ink, line: _T.footerLine);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: centre * 2,
        child: Center(
          child: LibrarySelector<(int, int?)>(
            library: library,
            select: (library) => (library.usedBytes, library.freeBytes),
            builder: (context, space) => offlineLine(
              spaceLabel(space.$1, space.$2),
              style,
              key: const ValueKey('offline-space'),
              align: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// No screenshot: what an empty list or search says.
class OfflineEmptyNote extends StatelessWidget {
  const OfflineEmptyNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: _T.emptyTop),
    child: Align(
      alignment: Alignment.topCenter,
      child: offlineLine(message, offlineStyle(_T.emptyText, _T.colorsOf(context).meta), align: TextAlign.center),
    ),
  );
}
