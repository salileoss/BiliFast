import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import 'offline_glyphs.dart';
import 'offline_text.dart';

typedef _T = OfflineListTheme;

/// What edit mode has chosen, by row key; each key stands for one or more parts.
class OfflineSelection extends ChangeNotifier {
  final _chosen = <String, List<int>>{};

  bool contains(String key) => _chosen.containsKey(key);
  bool get isEmpty => _chosen.isEmpty;

  /// Every part chosen, a group's and the stacked row's all of theirs.
  List<int> get cids => [for (final cids in _chosen.values) ...cids];

  void toggle(String key, List<int> cids) {
    if (_chosen.remove(key) == null) _chosen[key] = cids;
    notifyListeners();
  }

  /// Chooses all of [rows], or nothing when they all are already.
  void toggleAll(Map<String, List<int>> rows) {
    if (rows.isNotEmpty && rows.keys.every(_chosen.containsKey)) {
      _chosen.clear();
    } else {
      _chosen
        ..clear()
        ..addAll(rows);
    }
    notifyListeners();
  }

  /// Drops what is no longer listed.
  void keepOnly(Map<String, List<int>> rows) {
    final before = _chosen.length;
    _chosen.removeWhere((key, _) => !rows.containsKey(key));
    for (final key in _chosen.keys.toList()) {
      _chosen[key] = rows[key]!;
    }
    if (_chosen.length != before) notifyListeners();
  }

  bool allOf(Map<String, List<int>> rows) => rows.isNotEmpty && rows.keys.every(_chosen.containsKey);

  void clear() {
    if (_chosen.isEmpty) return;
    _chosen.clear();
    notifyListeners();
  }
}

/// Edit mode's bottom (149): 全选 with its circle, and 删除, at half until something is chosen.
class OfflineEditBar extends StatelessWidget {
  const OfflineEditBar({
    super.key,
    required this.allChosen,
    required this.anyChosen,
    required this.onToggleAll,
    required this.onDelete,
  });

  final bool allChosen;
  final bool anyChosen;
  final VoidCallback onToggleAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final select = offlineStyle(_T.editText, _T.colorsOf(context).selectAllInk, line: _T.editBarHeight);
    final delete = offlineStyle(_T.editText, _T.colorsOf(context).deleteInk, line: _T.editBarHeight);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        key: const ValueKey('offline-edit-bar'),
        height: _T.editBarCentre * 2,
        child: Row(
          children: [
            Semantics(
              button: true,
              selected: allChosen,
              label: '全选',
              onTap: onToggleAll,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('offline-select-all'),
                behavior: HitTestBehavior.opaque,
                onTap: onToggleAll,
                child: Row(
                  children: [
                    const SizedBox(width: _T.circleCentreX - _T.circle / 2),
                    OfflineChoiceCircle(chosen: allChosen),
                    const SizedBox(width: _T.selectAllLeft - _T.circleCentreX - _T.circle / 2),
                    offlineLine('全选', select),
                    const SizedBox(width: _T.textRight),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              enabled: anyChosen,
              label: '删除',
              onTap: onDelete,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('offline-delete'),
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.only(left: _T.textRight, right: _T.deleteRight),
                  child: Opacity(opacity: anyChosen ? 1 : _T.deleteOffOpacity, child: offlineLine('删除', delete)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 确定要删除吗？ (150): 取消 and 确认 over a dim that cancels when tapped, centred between the status bar and the home
/// indicator's inset; it fades in.
class OfflineDeleteConfirm extends StatelessWidget {
  const OfflineDeleteConfirm({super.key, required this.onConfirm, required this.onCancel});

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final title = offlineStyle(_T.confirmTitleText, _T.colorsOf(context).ink, weight: _T.confirmTitleWeight);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : _T.confirmMotion,
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '取消',
              onTap: onCancel,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('offline-confirm-dim'),
                behavior: HitTestBehavior.opaque,
                onTap: onCancel,
                child: const ColoredBox(color: _T.confirmDim),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: padding.top,
            bottom: padding.bottom,
            child: Center(
              child: BlockSemantics(
                child: Container(
                  key: const ValueKey('offline-confirm'),
                  width: _T.confirmWidth,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: BiliColors.colorsOf(context).card,
                    borderRadius: BorderRadius.circular(_T.confirmRadius),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _T.confirmTitleHeight,
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(0, -_T.confirmTitleLift),
                            child: offlineLine('确定要删除吗？', title, align: TextAlign.center),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: _T.confirmRule,
                        child: ColoredBox(color: _T.colorsOf(context).confirmRuleInk),
                      ),
                      SizedBox(
                        height: _T.confirmButtonHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _ConfirmButton(
                                label: '取消',
                                color: _T.colorsOf(context).confirmCancel,
                                inset: const EdgeInsets.only(right: _T.confirmButtonSpread),
                                onTap: onCancel,
                              ),
                            ),
                            Expanded(
                              child: _ConfirmButton(
                                label: '确认',
                                color: _T.colorsOf(context).confirmAction,
                                inset: const EdgeInsets.only(left: _T.confirmButtonSpread),
                                onTap: onConfirm,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatefulWidget {
  const _ConfirmButton({required this.label, required this.color, required this.inset, required this.onTap});

  final String label;
  final Color color;

  /// Moves the label off its half's middle, as 150 has them.
  final EdgeInsets inset;
  final VoidCallback onTap;

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  var _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: ValueKey('offline-confirm-${widget.label}'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      child: ColoredBox(
        color: _down ? _T.colorsOf(context).confirmPressed : BiliColors.colorsOf(context).card,
        child: Padding(
          padding: widget.inset,
          child: Center(child: offlineLine(widget.label, offlineStyle(_T.confirmButtonText, widget.color))),
        ),
      ),
    ),
  );
}
