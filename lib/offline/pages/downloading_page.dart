import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../skin/skin.dart';
import '../offline_library.dart';
import '../offline_models.dart';
import 'concurrency_sheet.dart';
import 'offline_bar.dart';
import 'offline_glyphs.dart';
import 'offline_page_kit.dart';
import 'offline_rows.dart';
import 'offline_selector.dart';
import 'offline_text.dart';

typedef _T = OfflineListTheme;

/// The unfinished parts in the order they were queued.
List<int> queuedParts(OfflineLibrary library) => [
  for (final item in library.items.reversed)
    if (!item.isDone) item.cid,
];

/// Whether anything is downloading or waiting its turn: the pill then pauses everything (146), else starts it (148).
bool anyRunning(OfflineLibrary library) =>
    library.items.any((item) => item.state == OfflineState.downloading || item.state == OfflineState.waiting);

/// 正在缓存 (146-150): 全部暂停 / 全部开始, 同时缓存数量 with its sheet (147), and every unfinished part; a tap pauses or
/// starts one (a failed one tries again). ☰ is edit mode (149) with 确定要删除吗? (150).
class DownloadingPage extends StatefulWidget {
  const DownloadingPage({super.key, this.library, this.skin});

  /// [AppScope]'s by default.
  final OfflineLibrary? library;
  final ValueListenable<Skin?>? skin;

  static const emptyMessage = '没有正在缓存的视频';
  static const vipOnly = '开通大会员后可使用';
  static const otherAccount = '请切换到下载此视频的账号后继续缓存';

  @override
  State<DownloadingPage> createState() => _DownloadingPageState();
}

class _DownloadingPageState extends State<DownloadingPage> with OfflineEditing {
  OfflineLibrary? _library;
  bool _sheet = false;

  @override
  OfflineLibrary get library => _library!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _library ??= widget.library ?? AppScope.of(context).offline;
  }

  @override
  Map<String, List<int>> selectable() => {
    for (final cid in queuedParts(library)) '$cid': [cid],
  };

  void _back() {
    if (_sheet) {
      setState(() => _sheet = false);
      return;
    }
    closeEditLayer();
  }

  void _tap(OfflineItem item) {
    switch (item.state) {
      case OfflineState.downloading || OfflineState.waiting:
        library.pause(item.cid);
      case OfflineState.paused || OfflineState.failed:
        if (!library.canResume(item.cid)) {
          showToast(context, DownloadingPage.otherAccount);
          return;
        }
        library.resume(item.cid);
      case OfflineState.done:
    }
  }

  void _all() {
    if (anyRunning(library)) {
      library.pauseAll();
    } else {
      if (library.items.any((item) => !item.isDone && !library.canResume(item.cid))) {
        showToast(context, DownloadingPage.otherAccount);
      }
      library.startAll();
    }
  }

  void _pick(int count) {
    if (count > 1 && !offlineVip(AppScope.of(context).environment)) {
      showToast(context, DownloadingPage.vipOnly);
      return;
    }
    library.setConcurrency(count);
    setState(() => _sheet = false);
  }

  @override
  Widget build(BuildContext context) => offlineScaffold(
    skin: widget.skin ?? AppScope.of(context).skin,
    canPop: !editing && !_sheet,
    onBack: _back,
    builder: (look) => LibrarySelector<List<int>>(
      library: library,
      select: queuedParts,
      equals: listEquals,
      builder: (context, queued) {
        pruneSelection();
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OfflineBar(
                  look: look,
                  title: '正在缓存',
                  onBack: () => unawaited(Navigator.of(context).maybePop()),
                  onEdit: queued.isEmpty ? null : startEdit,
                  onDone: editing ? endEdit : null,
                ),
                if (!editing) _Strip(library: library, onAll: _all, onCount: () => setState(() => _sheet = true)),
                Expanded(child: _list(queued)),
                if (editing) editBar() else SpaceFooter(library: library),
              ],
            ),
            if (_sheet)
              Positioned.fill(
                child: ConcurrencySheet(
                  current: library.concurrency,
                  onPick: _pick,
                  onClose: () => setState(() => _sheet = false),
                ),
              ),
            if (confirming) confirmLayer(),
          ],
        );
      },
    ),
  );

  Widget _list(List<int> queued) {
    if (queued.isEmpty) return const OfflineEmptyNote(DownloadingPage.emptyMessage);
    return offlineScroll(context, key: const ValueKey('offline-queue'), [
      SliverFixedExtentList.builder(
        itemExtent: _T.row,
        itemCount: queued.length,
        itemBuilder: (context, index) {
          final cid = queued[index];
          return ListenableBuilder(
            key: ValueKey('offline-queue-$cid'),
            listenable: selection,
            builder: (context, _) => QueueRow(
              library: library,
              cid: cid,
              editing: editing,
              chosen: selection.contains('$cid'),
              divider: index < queued.length - 1,
              onTap: editing ? (_) => toggle('$cid', [cid]) : _tap,
            ),
          );
        },
      ),
    ]);
  }
}

/// 146's strip: the pill, and 同时缓存数量：N ⌄ at the right.
class _Strip extends StatelessWidget {
  const _Strip({required this.library, required this.onAll, required this.onCount});

  final OfflineLibrary library;
  final VoidCallback onAll;
  final VoidCallback onCount;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _T.stripHeight,
    child: LibrarySelector<(bool, int)>(
      library: library,
      select: (library) => (anyRunning(library), library.concurrency),
      builder: (context, value) {
        final (running, concurrency) = value;
        final label = running ? '全部暂停' : '全部开始';
        final words = offlineStyle(_T.allText, _T.colorsOf(context).ink, line: _T.allHeight);
        final count = offlineStyle(_T.countText, _T.colorsOf(context).countInk, line: _T.allHeight);
        return Stack(
          children: [
            Positioned(
              left: _T.pillLeft,
              top: _T.pillTop,
              height: _T.allHeight,
              child: Semantics(
                button: true,
                label: label,
                onTap: onAll,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('offline-all'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onAll,
                  child: Container(
                    padding: const EdgeInsets.only(left: _T.allPadLeft, right: _T.allPadRight),
                    decoration: ShapeDecoration(color: _T.colorsOf(context).allFill, shape: StadiumBorder()),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AllGlyph(paused: !running),
                        const SizedBox(width: _T.allGlyphGap),
                        offlineLine(label, words, key: const ValueKey('offline-all-label')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: _T.pillTop,
              height: _T.allHeight,
              child: Semantics(
                button: true,
                label: '同时缓存数量：$concurrency',
                onTap: onCount,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('offline-concurrency'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onCount,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: _T.textRight),
                      offlineLine('同时缓存数量：$concurrency', count, key: const ValueKey('offline-concurrency-label')),
                      const SizedBox(width: _T.chevronGap),
                      const ChevronGlyph(),
                      const SizedBox(width: _T.chevronRight),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
