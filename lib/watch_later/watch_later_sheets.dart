import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/widgets.dart';

import '../home/feed_model.dart' show requestFailureMessage;
import '../shared/loading_tv.dart';
import '../shared/theme.dart';
import 'watch_later_api.dart';
import 'watch_later_glyphs.dart';
import 'watch_later_text.dart';

sealed class WatchLaterSheet {
  const WatchLaterSheet();
}

/// 管理's sheet (93).
final class ManageSheet extends WatchLaterSheet {
  const ManageSheet();
}

/// A row's ⋮ (94).
final class RowSheet extends WatchLaterSheet {
  const RowSheet(this.item);

  final WatchLaterItem item;
}

/// 复制到 or 移动到's folders (97, 98); [aid] is one of the chosen videos, which the folder list asks about.
final class FolderSheet extends WatchLaterSheet {
  const FolderSheet({required this.move, required this.mid, required this.aid});

  final bool move;
  final int mid;
  final int aid;
}

/// The page's sheets as one in-page layer over it: the dim fades in as the sheet rises from the bottom, and a tap on
/// the dim, or back, lowers it.
class SheetLayer extends StatefulWidget {
  const SheetLayer({
    super.key,
    required this.sheet,
    required this.api,
    required this.onClear,
    required this.onBulk,
    required this.onRemove,
    required this.onSend,
    required this.onNewFolder,
  });

  final ValueNotifier<WatchLaterSheet?> sheet;
  final WatchLaterApi api;
  final ValueChanged<WatchLaterClean> onClear;
  final VoidCallback onBulk;
  final ValueChanged<WatchLaterItem> onRemove;
  final void Function(FavFolder folder, bool move) onSend;

  /// Completes with the folder made, or null.
  final Future<FavFolder?> Function() onNewFolder;

  @override
  State<SheetLayer> createState() => _SheetLayerState();
}

class _SheetLayerState extends State<SheetLayer> with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: WatchLaterTheme.sheetIn,
    reverseDuration: WatchLaterTheme.sheetOut,
  );
  late final _curve = CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  WatchLaterSheet? _shown;

  @override
  void initState() {
    super.initState();
    widget.sheet.addListener(_changed);
    _shown = widget.sheet.value;
    if (_shown != null) _motion.value = 1;
  }

  @override
  void dispose() {
    widget.sheet.removeListener(_changed);
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _changed() {
    final next = widget.sheet.value;
    final reduce = mounted && MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (next != null) {
      setState(() => _shown = next);
      if (reduce) {
        _motion.value = 1;
      } else {
        unawaited(_motion.forward());
      }
    } else if (_shown != null) {
      if (reduce) {
        _motion.value = 0;
        setState(() => _shown = null);
        return;
      }
      unawaited(
        _motion.reverse().then((_) {
          if (mounted && widget.sheet.value == null) setState(() => _shown = null);
        }),
      );
    }
  }

  void _close() => widget.sheet.value = null;

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final Widget panel = switch (shown) {
      ManageSheet() => _ActionPanel(
        key: const ValueKey('later-manage-sheet'),
        rows: [
          _Action(SheetGlyph.clear, '一键清除已看完视频', () => widget.onClear(WatchLaterClean.watched)),
          _Action(SheetGlyph.clear, '一键清除已失效视频', () => widget.onClear(WatchLaterClean.invalid)),
          _Action(SheetGlyph.list, '批量管理', widget.onBulk),
        ],
      ),
      RowSheet(:final item) => _ActionPanel(
        key: const ValueKey('later-row-sheet'),
        rows: [_Action(SheetGlyph.trash, '删除', () => widget.onRemove(item))],
      ),
      FolderSheet() => _FolderPanel(
        key: ValueKey('later-folder-sheet-${shown.move}'),
        sheet: shown,
        api: widget.api,
        onSend: widget.onSend,
        onNewFolder: widget.onNewFolder,
      ),
    };
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: _motion,
            child: Semantics(
              button: true,
              label: '关闭',
              onTap: _close,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('later-sheet-dim'),
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const ColoredBox(color: WatchLaterTheme.sheetDim),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(_curve),
            child: panel,
          ),
        ),
      ],
    );
  }
}

class _Action {
  const _Action(this.glyph, this.label, this.onTap);

  final SheetGlyph glyph;
  final String label;
  final VoidCallback onTap;
}

/// 93's and 94's sheet: the grabber and one white group of rows.
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({super.key, required this.rows});

  final List<_Action> rows;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WatchLaterTheme.colorsOf(context).sheetFill,
        borderRadius: BorderRadius.vertical(top: Radius.circular(WatchLaterTheme.sheetRadius)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Grabber(color: WatchLaterTheme.colorsOf(context).grabberInk),
          const SizedBox(height: WatchLaterTheme.groupTop - WatchLaterTheme.grabberTop - WatchLaterTheme.grabberHeight),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WatchLaterTheme.groupInset),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(WatchLaterTheme.groupRadius),
              child: ColoredBox(
                color: WatchLaterTheme.colorsOf(context).groupFill,
                child: Column(
                  children: [
                    for (final (index, row) in rows.indexed) _ActionRow(action: row, last: index == rows.length - 1),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: WatchLaterTheme.groupBottom + bottom),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: WatchLaterTheme.grabberTop),
    child: Center(
      child: Container(
        width: WatchLaterTheme.grabberWidth,
        height: WatchLaterTheme.grabberHeight,
        decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
      ),
    ),
  );
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({required this.action, required this.last});

  final _Action action;
  final bool last;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    const glyphLeft =
        WatchLaterTheme.actionGlyphCentre - WatchLaterTheme.groupInset - WatchLaterTheme.actionGlyphSize / 2;
    const textLeft = WatchLaterTheme.actionTextLeft - WatchLaterTheme.groupInset;
    final style = watchLaterStyle(
      WatchLaterTheme.actionText,
      WatchLaterTheme.colorsOf(context).ink,
      line: WatchLaterTheme.actionRowHeight,
      weight: WatchLaterTheme.actionWeight,
    );
    return Semantics(
      button: true,
      label: action.label,
      onTap: action.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('later-action-${action.label}'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: action.onTap,
        child: ColoredBox(
          color: _pressed ? WatchLaterTheme.actionPressed : WatchLaterTheme.actionIdle,
          child: SizedBox(
            height: WatchLaterTheme.actionRowHeight,
            child: Stack(
              children: [
                Positioned(
                  left: glyphLeft,
                  top: (WatchLaterTheme.actionRowHeight - WatchLaterTheme.actionGlyphSize) / 2,
                  child: SheetGlyphView(action.glyph),
                ),
                Positioned(
                  left: textLeft,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Text(action.label, maxLines: 1, style: style, strutStyle: BiliFonts.strut(style)),
                ),
                if (!widget.last)
                  Positioned(
                    left: textLeft,
                    right: 0,
                    bottom: 0,
                    height: WatchLaterTheme.actionHairline,
                    child: ColoredBox(color: WatchLaterTheme.colorsOf(context).actionHairlineInk),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 97's and 98's sheet: 选择收藏夹 with + 新建收藏夹, then the account's folders; a tap sends the chosen videos there.
class _FolderPanel extends StatefulWidget {
  const _FolderPanel({
    super.key,
    required this.sheet,
    required this.api,
    required this.onSend,
    required this.onNewFolder,
  });

  final FolderSheet sheet;
  final WatchLaterApi api;
  final void Function(FavFolder folder, bool move) onSend;
  final Future<FavFolder?> Function() onNewFolder;

  @override
  State<_FolderPanel> createState() => _FolderPanelState();
}

class _FolderPanelState extends State<_FolderPanel> {
  List<FavFolder>? _folders;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final folders = await widget.api.folders(mid: widget.sheet.mid, aid: widget.sheet.aid);
      if (mounted) setState(() => _folders = folders);
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'watch later folders failed', {'error': '${error.runtimeType}'});
      if (mounted) setState(() => _error = requestFailureMessage(error));
    }
  }

  void _send(FavFolder folder) {
    if (_sending) return;
    _sending = true;
    widget.onSend(folder, widget.sheet.move);
  }

  /// The new folder joins the list after the default one, as the video page's 收藏 sheet lists it.
  Future<void> _newFolder() async {
    final folder = await widget.onNewFolder();
    final folders = _folders;
    if (folder == null || folders == null || !mounted) return;
    if (folders.any((row) => row.id == folder.id)) return;
    final at = folders.indexWhere((row) => !row.isDefault);
    setState(() => _folders = [...folders]..insert(at < 0 ? folders.length : at, folder));
  }

  @override
  Widget build(BuildContext context) {
    final height = math.min(WatchLaterTheme.folderSheetHeight, MediaQuery.sizeOf(context).height);
    const headerLine = WatchLaterTheme.folderHeaderCentre * 2;
    final title = watchLaterStyle(WatchLaterTheme.folderTitleText, WatchLaterTheme.colorsOf(context).ink, line: headerLine);
    final add = watchLaterStyle(WatchLaterTheme.folderNewText, WatchLaterTheme.colorsOf(context).grey, line: headerLine);
    final folders = _folders;
    final error = _error;
    final Widget list;
    if (folders != null) {
      list = ListView.builder(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        itemCount: folders.length,
        itemBuilder: (context, index) =>
            _FolderRow(folder: folders[index], first: index == 0, onTap: () => _send(folders[index])),
      );
    } else if (error != null) {
      list = Center(
        child: StateWithButton(
          message: error,
          button: '重试',
          buttonKey: const ValueKey('later-folders-retry'),
          onTap: () => unawaited(_load()),
        ),
      );
    } else {
      list = const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: WatchLaterTheme.folderRowsTop),
          child: LoadingTvState(key: ValueKey('later-folders-loading')),
        ),
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: WatchLaterTheme.colorsOf(context).folderSheetFill,
        borderRadius: BorderRadius.vertical(top: Radius.circular(WatchLaterTheme.sheetRadius)),
      ),
      child: Stack(
        children: [
          Positioned(left: 0, right: 0, top: 0, child: _Grabber(color: WatchLaterTheme.colorsOf(context).folderGrabberInk)),
          const Positioned(
            left: WatchLaterTheme.folderIconLeft,
            top: WatchLaterTheme.folderIconTop,
            child: FolderStarGlyph(),
          ),
          Positioned(
            left: WatchLaterTheme.folderTitleLeft,
            top: 0,
            height: headerLine,
            child: Text('选择收藏夹', maxLines: 1, style: title, strutStyle: BiliFonts.strut(title)),
          ),
          Positioned(
            right: 0,
            top: 0,
            height: headerLine,
            child: Semantics(
              button: true,
              label: '新建收藏夹',
              onTap: () => unawaited(_newFolder()),
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('later-new-folder'),
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_newFolder()),
                child: Padding(
                  padding: const EdgeInsets.only(left: WatchLaterTheme.gutter, right: WatchLaterTheme.folderNewRight),
                  child: Row(
                    children: [
                      const PlusGlyph(),
                      const SizedBox(width: WatchLaterTheme.plusGap),
                      Text('新建收藏夹', maxLines: 1, style: add, strutStyle: BiliFonts.strut(add)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, top: WatchLaterTheme.folderRowsTop, bottom: 0, child: list),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder, required this.first, required this.onTap});

  final FavFolder folder;
  final bool first;
  final VoidCallback onTap;

  static String meta(FavFolder folder) => '${folder.isPrivate ? '私密' : '公开'} · ${folder.count}个内容';

  @override
  Widget build(BuildContext context) {
    const nameLine = WatchLaterTheme.folderNameCentre * 2;
    final name = watchLaterStyle(WatchLaterTheme.folderNameText, WatchLaterTheme.colorsOf(context).ink, line: nameLine);
    final metaStyle = watchLaterStyle(WatchLaterTheme.folderMetaText, WatchLaterTheme.colorsOf(context).grey, line: nameLine);
    final words = meta(folder);
    return Semantics(
      button: true,
      label: '${folder.title}，$words',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('later-folder-${folder.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: WatchLaterTheme.folderRowHeight,
          child: Stack(
            children: [
              Positioned(
                left: WatchLaterTheme.gutter,
                right: WatchLaterTheme.gutter,
                top: 0,
                height: nameLine,
                child: Text(
                  folder.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: name,
                  strutStyle: BiliFonts.strut(name),
                ),
              ),
              Positioned(
                left: WatchLaterTheme.gutter,
                right: WatchLaterTheme.gutter,
                top: WatchLaterTheme.folderMetaCentre - nameLine / 2,
                height: nameLine,
                child: Text(words, maxLines: 1, style: metaStyle, strutStyle: BiliFonts.strut(metaStyle)),
              ),
              if (!first)
                Positioned(
                  left: WatchLaterTheme.gutter,
                  right: WatchLaterTheme.gutter,
                  top: 0,
                  height: WatchLaterTheme.folderHairline,
                  child: ColoredBox(color: WatchLaterTheme.colorsOf(context).hairlineInk),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// (95, 96)
class EditBar extends StatelessWidget {
  const EditBar({
    super.key,
    required this.shown,
    required this.chosen,
    required this.allChosen,
    required this.onToggleAll,
    required this.onClearChoice,
    required this.onDelete,
    required this.onCopy,
    required this.onMove,
  });

  final bool shown;
  final int chosen;
  final bool allChosen;
  final VoidCallback onToggleAll;
  final VoidCallback onClearChoice;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final any = chosen > 0;
    final actionStyle = watchLaterStyle(
      WatchLaterTheme.editText,
      any ? WatchLaterTheme.colorsOf(context).grey : WatchLaterTheme.colorsOf(context).editActionOff,
      line: WatchLaterTheme.editBarHeight,
    );
    final allStyle = watchLaterStyle(
      WatchLaterTheme.editText,
      WatchLaterTheme.colorsOf(context).grey,
      line: WatchLaterTheme.editBarHeight,
    );
    Widget action(String key, String label, VoidCallback onTap) => Semantics(
      button: true,
      enabled: any,
      label: label,
      onTap: any ? onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('later-edit-$key'),
        behavior: HitTestBehavior.opaque,
        onTap: any ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WatchLaterTheme.editActionGap / 2),
          child: Text(label, maxLines: 1, style: actionStyle, strutStyle: BiliFonts.strut(actionStyle)),
        ),
      ),
    );
    return IgnorePointer(
      ignoring: !shown,
      child: ExcludeSemantics(
        excluding: !shown,
        child: AnimatedSlide(
          offset: shown ? Offset.zero : const Offset(0, 1.2),
          duration: reduce ? Duration.zero : WatchLaterTheme.editMotion,
          curve: Curves.easeOutCubic,
          child: Column(
            key: const ValueKey('later-edit-bar'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const IgnorePointer(
                child: SizedBox(
                  height: WatchLaterTheme.editShadeHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [WatchLaterTheme.editShadeClear, WatchLaterTheme.editShade],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: WatchLaterTheme.editBarHairline,
                child: ColoredBox(color: WatchLaterTheme.colorsOf(context).hairlineInk),
              ),
              ColoredBox(
                color: BiliColors.colorsOf(context).card,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottom),
                  child: SizedBox(
                    height: WatchLaterTheme.editBarHeight,
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          selected: allChosen,
                          label: '全选',
                          onTap: onToggleAll,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: const ValueKey('later-edit-all'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onToggleAll,
                            child: Row(
                              children: [
                                const SizedBox(width: WatchLaterTheme.circleCentreX - WatchLaterTheme.circleSize / 2),
                                ChoiceCircle(chosen: allChosen),
                                const SizedBox(
                                  width:
                                      WatchLaterTheme.selectAllLeft -
                                      WatchLaterTheme.circleCentreX -
                                      WatchLaterTheme.circleSize / 2,
                                ),
                                Text('全选', maxLines: 1, style: allStyle, strutStyle: BiliFonts.strut(allStyle)),
                                const SizedBox(width: WatchLaterTheme.gutter),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        action('clear', any ? '取消选择 ($chosen)' : '取消选择', onClearChoice),
                        action('delete', '删除', onDelete),
                        action('copy', '复制到', onCopy),
                        action('move', '移动到', onMove),
                        const SizedBox(width: WatchLaterTheme.editActionRight - WatchLaterTheme.editActionGap / 2),
                      ],
                    ),
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
