import 'package:flutter/widgets.dart';

import '../shared/menu.dart' show PressHighlight;
import '../shared/theme.dart';
import 'space_header.dart';

/// 已关注's sheet (71): the page dims and a white sheet rises with 加入特别关注, 设置分组 and 取消关注, then 取消 in its
/// own block. An in-page layer, not a route: [open] holds whether it is up, and setting it false (取消, a tap on the
/// dim, back) closes it.
class SpaceUnfollowSheet extends StatefulWidget {
  const SpaceUnfollowSheet({super.key, required this.open, required this.onUnfollow, required this.onSoon});

  final ValueNotifier<bool> open;

  /// 取消关注, after the sheet has started to close.
  final VoidCallback onUnfollow;

  /// 加入特别关注 and 设置分组.
  final VoidCallback onSoon;

  @override
  State<SpaceUnfollowSheet> createState() => _SpaceUnfollowSheetState();
}

class _SpaceUnfollowSheetState extends State<SpaceUnfollowSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: SpaceTheme.sheetIn,
    reverseDuration: SpaceTheme.sheetOut,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// Up, or still going down.
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_changed);
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !widget.open.value && mounted) setState(() => _shown = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _motion
      ..duration = still ? Duration.zero : SpaceTheme.sheetIn
      ..reverseDuration = still ? Duration.zero : SpaceTheme.sheetOut;
  }

  @override
  void didUpdateWidget(SpaceUnfollowSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.open, widget.open)) {
      oldWidget.open.removeListener(_changed);
      widget.open.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.open.removeListener(_changed);
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _changed() {
    if (!widget.open.value) {
      if (_shown) _motion.reverse();
      return;
    }
    setState(() => _shown = true);
    _motion.forward();
  }

  void _close() => widget.open.value = false;

  void _then(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shown) return const SizedBox.shrink();
    final open = widget.open.value;
    return IgnorePointer(
      ignoring: !open,
      child: ExcludeSemantics(
        excluding: !open,
        child: BlockSemantics(
          blocking: open,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('space-sheet-dim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: FadeTransition(
                    opacity: _curve,
                    child: const ColoredBox(color: SpaceTheme.sheetDim),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(_curve),
                  child: DecoratedBox(
                    key: const ValueKey('space-sheet'),
                    decoration: BoxDecoration(
                      color: SpaceTheme.colorsOf(context).sheetFill,
                      boxShadow: [BoxShadow(color: SpaceTheme.sheetShadow, blurRadius: SpaceTheme.sheetShadowBlur)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Row(
                          key: const ValueKey('space-sheet-special'),
                          label: '加入特别关注',
                          onTap: () => _then(widget.onSoon),
                        ),
                        _Row(
                          key: const ValueKey('space-sheet-group'),
                          label: '设置分组',
                          onTap: () => _then(widget.onSoon),
                          rule: true,
                        ),
                        _Row(
                          key: const ValueKey('space-sheet-unfollow'),
                          label: '取消关注',
                          onTap: () => _then(widget.onUnfollow),
                          rule: true,
                        ),
                        SizedBox(height: SpaceTheme.sheetGap, child: ColoredBox(color: SpaceTheme.colorsOf(context).sheetGapFill)),
                        PressHighlight(
                          onTap: _close,
                          child: Semantics(
                            button: true,
                            label: '取消',
                            onTap: _close,
                            excludeSemantics: true,
                            child: SizedBox(
                              key: const ValueKey('space-sheet-cancel'),
                              height: SpaceTheme.sheetCancel,
                              child: Center(
                                child: spaceLine(
                                  '取消',
                                  spaceStyle(SpaceTheme.sheetCancelText, SpaceTheme.colorsOf(context).sheetInk, line: SpaceTheme.sheetCancel),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: SpaceTheme.sheetBottom),
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

class _Row extends StatelessWidget {
  const _Row({super.key, required this.label, required this.onTap, this.rule = false});

  final String label;
  final VoidCallback onTap;

  /// The rule over the row, from the inset to the right edge.
  final bool rule;

  @override
  Widget build(BuildContext context) => PressHighlight(
    onTap: onTap,
    child: Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        height: SpaceTheme.sheetRow,
        child: Stack(
          children: [
            Positioned(
              left: SpaceTheme.sheetInset,
              right: SpaceTheme.sheetInset,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: spaceLine(label, spaceStyle(SpaceTheme.sheetText, SpaceTheme.colorsOf(context).sheetInk, line: SpaceTheme.sheetRow)),
              ),
            ),
            if (rule)
              Positioned(
                left: SpaceTheme.sheetInset,
                right: 0,
                top: 0,
                height: SpaceTheme.sheetRule,
                child: ColoredBox(color: SpaceTheme.colorsOf(context).sheetRuleInk),
              ),
          ],
        ),
      ),
    ),
  );
}
