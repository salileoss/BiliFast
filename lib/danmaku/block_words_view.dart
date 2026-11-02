import 'dart:math' as math;

import 'package:bili_core/danmaku.dart';
import 'package:flutter/material.dart' show InputBorder, InputDecoration, Material, MaterialType, TextField, Theme;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../player_ui/player_ui.dart';
import '../shared/theme.dart';
import 'block_rule_store.dart';

/// 添加屏蔽词 (30): the field with 添加 and 同步, the tabs 关键词 / 正则 / 举报屏蔽用户, and each rule as a chip with ✕, over
/// the whole landscape screen.
class BlockWordsView extends StatefulWidget {
  const BlockWordsView({super.key, required this.ui, required this.toast, required this.back, required this.close});

  final PlayerUi ui;
  final ValueChanged<String> toast;

  /// Back to 弹幕设置.
  final VoidCallback back;
  final VoidCallback close;

  @override
  State<BlockWordsView> createState() => _BlockWordsViewState();
}

class _BlockWordsViewState extends State<BlockWordsView> {
  static const _tabs = [
    (kind: BlockRuleKind.keyword, title: '关键词'),
    (kind: BlockRuleKind.regex, title: '正则'),
    (kind: BlockRuleKind.user, title: '举报屏蔽用户'),
  ];

  final _field = TextEditingController();
  final _focus = FocusNode();
  BlockRuleKind _kind = BlockRuleKind.keyword;
  bool _adding = false;

  BlockRuleStore? get _store => widget.ui.danmaku?.rules;

  @override
  void initState() {
    super.initState();
    _store?.refresh();
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Text typed between slashes is a regex rule, kept with its slashes; anything else a keyword, whichever tab shows.
  /// Once added, its tab shows, so the new chip is in view. [BlockWordsView.toast] is the panel layer's, so a failure
  /// here or in [_sync] and [_remove] still shows after this view has closed.
  Future<void> _add() async {
    final store = _store;
    final text = _field.text.trim();
    if (store == null || text.isEmpty || _adding) return;
    final kind = text.length >= 2 && text.startsWith('/') && text.endsWith('/')
        ? BlockRuleKind.regex
        : BlockRuleKind.keyword;
    final answer = _answer();
    setState(() => _adding = true);
    final message = await store.add(kind, text);
    if (mounted) {
      setState(() {
        _adding = false;
        if (message == null) {
          _kind = kind;
          _field.clear();
        }
      });
    }
    answer(message);
  }

  Future<void> _sync() async {
    final store = _store;
    if (store == null || store.loading) return;
    final answer = _answer();
    answer(await store.refresh(force: true));
  }

  Future<void> _remove(BlockRule rule) async {
    final answer = _answer();
    answer(await _store?.remove(rule));
  }

  /// Shows a store's answer: a login it wants goes to the page's login, anything else is toasted. Taken before the
  /// store is asked, so it still works once this view has closed.
  ValueChanged<String?> _answer() {
    final toast = widget.toast;
    final danmaku = widget.ui.danmaku;
    return (message) {
      if (message == null) return;
      if (message == BlockRuleStore.needLogin) {
        danmaku?.requestLogin();
      } else {
        toast(message);
      }
    };
  }

  void _select(BlockRuleKind kind) => setState(() => _kind = kind);

  TextStyle _style(double size, Color color, {double spacing = 0}) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: size,
    color: color,
    letterSpacing: spacing,
    height: 1.2,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final store = _store;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focus.unfocus,
        child: ColoredBox(
          color: BlockWordsTheme.dim,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // The phone's landscape has no top inset; the iPad's status bar can stay up over full screen (08).
              final top = insets.top;
              final listTop = top + BlockWordsTheme.tabsTop + BlockWordsTheme.tabsHeight;
              return Stack(
                children: [
                  Positioned(
                    left: (width - BlockWordsTheme.dividerWidth) / 2,
                    width: BlockWordsTheme.dividerWidth,
                    top: listTop,
                    bottom: insets.bottom,
                    child: const ColoredBox(color: BlockWordsTheme.divider),
                  ),
                  Positioned(
                    left: insets.left,
                    right: insets.right,
                    top: listTop,
                    bottom: 0,
                    child: store == null
                        ? const SizedBox.shrink()
                        : ListenableBuilder(
                            listenable: store,
                            builder: (context, _) => _list(store, width / 2 - insets.left, width / 2 - insets.right),
                          ),
                  ),
                  Positioned(
                    left: insets.left + BlockWordsTheme.closeCentreX - BlockWordsTheme.closeHitBox / 2,
                    top: top + BlockWordsTheme.rowTop + (BlockWordsTheme.rowHeight - BlockWordsTheme.closeHitBox) / 2,
                    width: BlockWordsTheme.closeHitBox,
                    height: BlockWordsTheme.closeHitBox,
                    child: Semantics(
                      button: true,
                      label: '返回',
                      child: GestureDetector(
                        key: const ValueKey('block-words-back'),
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.back,
                        child: const CustomPaint(painter: _CrossPainter.close()),
                      ),
                    ),
                  ),
                  Positioned(
                    left: insets.left + BlockWordsTheme.fieldLeft,
                    right: insets.right,
                    top: top + BlockWordsTheme.rowTop,
                    height: BlockWordsTheme.rowHeight,
                    child: Row(
                      children: [
                        Expanded(child: _input()),
                        const SizedBox(width: BlockWordsTheme.buttonGap),
                        _button(
                          key: const ValueKey('block-words-add'),
                          label: '添加',
                          icon: const _PencilPainter(),
                          iconSize: BlockWordsTheme.addIcon,
                          iconLeft: BlockWordsTheme.addIconLeft,
                          iconGap: BlockWordsTheme.addIconGap,
                          iconLift: BlockWordsTheme.addIconLift,
                          onTap: _add,
                        ),
                        const SizedBox(width: BlockWordsTheme.buttonGap),
                        _button(
                          key: const ValueKey('block-words-sync'),
                          label: '同步',
                          icon: const _SyncPainter(),
                          iconSize: BlockWordsTheme.syncIcon,
                          iconLeft: BlockWordsTheme.syncIconLeft,
                          iconGap: BlockWordsTheme.syncIconGap,
                          iconLift: 0,
                          onTap: _sync,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: insets.left + BlockWordsTheme.tabsLeft,
                    top: top + BlockWordsTheme.tabsTop,
                    height: BlockWordsTheme.tabsHeight,
                    child: Row(
                      children: [
                        for (final (index, tab) in _tabs.indexed) ...[
                          if (index > 0) const SizedBox(width: BlockWordsTheme.tabGap),
                          _tab(tab.kind, tab.title),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _input() {
    // What the field and its hint draw in (the theme's bodyLarge under ours); the hint is a Text so it takes a strut.
    final base = Theme.of(context).textTheme.bodyLarge!;
    final field = base.merge(_style(BlockWordsTheme.fieldText, BlockWordsTheme.colorsOf(context).fieldInk));
    final hint = field.merge(
      _style(BlockWordsTheme.fieldText, BlockWordsTheme.colorsOf(context).grey, spacing: BlockWordsTheme.smallSpacing),
    );
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: BlockWordsTheme.fieldPadX),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: BlockWordsTheme.colorsOf(context).fieldFill,
          borderRadius: BorderRadius.circular(BlockWordsTheme.fieldRadius),
        ),
        child: TextField(
          key: const ValueKey('block-words-field'),
          controller: _field,
          focusNode: _focus,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          cursorColor: BlockWordsTheme.pink,
          textAlignVertical: TextAlignVertical.center,
          style: _style(BlockWordsTheme.fieldText, BlockWordsTheme.colorsOf(context).fieldInk),
          strutStyle: BiliFonts.strut(field),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hint: Text(
              '请填写要屏蔽的关键词（支持正则，以 "/" 开头 "/" 结束）',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hint,
              strutStyle: BiliFonts.strut(hint),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button({
    required Key key,
    required String label,
    required CustomPainter icon,
    required double iconSize,
    required double iconLeft,
    required double iconGap,
    required double iconLift,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: BlockWordsTheme.buttonWidth,
        height: BlockWordsTheme.rowHeight,
        padding: EdgeInsets.only(left: iconLeft),
        decoration: BoxDecoration(
          color: BlockWordsTheme.buttonFill,
          borderRadius: BorderRadius.circular(BlockWordsTheme.fieldRadius),
        ),
        child: Row(
          children: [
            Transform.translate(
              offset: Offset(0, -iconLift),
              child: CustomPaint(size: Size.square(iconSize), painter: icon),
            ),
            SizedBox(width: iconGap),
            Text(label, maxLines: 1, softWrap: false, style: _style(BlockWordsTheme.buttonText, BlockWordsTheme.text)),
          ],
        ),
      ),
    ),
  );

  Widget _tab(BlockRuleKind kind, String title) {
    final selected = kind == _kind;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      onTap: () => _select(kind),
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('block-words-tab-${kind.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(kind),
        child: SizedBox(
          height: BlockWordsTheme.tabsHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                title,
                style: _style(
                  BlockWordsTheme.tabText,
                  selected ? BlockWordsTheme.pink : BlockWordsTheme.text,
                  spacing: BlockWordsTheme.smallSpacing,
                ),
              ),
              if (selected)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: BlockWordsTheme.underline,
                  child: ColoredBox(color: BlockWordsTheme.pink),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The selected kind's rules, filling the left column then the right one row by row.
  Widget _list(BlockRuleStore store, double leftWidth, double rightWidth) {
    final rules = [
      for (final rule in store.rules)
        if (rule.kind == _kind) rule,
    ];
    final rows = (rules.length + 1) ~/ 2;
    Widget cell(int index, double width) => SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: index < rules.length
            ? Padding(
                padding: const EdgeInsets.only(left: BlockWordsTheme.listPad),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: math.max(0, width - 2 * BlockWordsTheme.listPad)),
                  child: _chip(rules[index]),
                ),
              )
            : null,
      ),
    );
    return ListView.separated(
      key: const ValueKey('block-words-list'),
      padding: EdgeInsets.only(
        top: BlockWordsTheme.listPad,
        bottom: BlockWordsTheme.listPad + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: BlockWordsTheme.rowGap),
      itemBuilder: (context, row) => Row(children: [cell(row * 2, leftWidth), cell(row * 2 + 1, rightWidth)]),
    );
  }

  Widget _chip(BlockRule rule) => Container(
    key: ValueKey('block-rule-${rule.id}'),
    height: BlockWordsTheme.chipHeight,
    padding: const EdgeInsets.only(left: BlockWordsTheme.chipPadLeft),
    decoration: BoxDecoration(
      color: BlockWordsTheme.chipFill,
      borderRadius: BorderRadius.circular(BlockWordsTheme.chipRadius),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            rule.filter,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(BlockWordsTheme.chipText, BlockWordsTheme.colorsOf(context).grey),
            strutStyle: BiliFonts.strutOf(context, _style(BlockWordsTheme.chipText, BlockWordsTheme.colorsOf(context).grey)),
          ),
        ),
        Semantics(
          button: true,
          label: '删除 ${rule.filter}',
          onTap: () => _remove(rule),
          excludeSemantics: true,
          child: GestureDetector(
            key: ValueKey('block-rule-remove-${rule.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _remove(rule),
            child: Padding(
              padding: const EdgeInsets.only(left: BlockWordsTheme.chipGlyphGap, right: BlockWordsTheme.chipPadRight),
              child: SizedBox.square(
                dimension: BlockWordsTheme.chipGlyph,
                child: CustomPaint(painter: _CrossPainter.chip(context)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The ✕ to go back (white, round ends) and a chip's (grey, thin, square ends), centred in their box.
class _CrossPainter extends CustomPainter {
  const _CrossPainter.close()
    : arm = BlockWordsTheme.closeArm,
      stroke = BlockWordsTheme.closeStroke,
      color = BlockWordsTheme.text,
      cap = StrokeCap.round;

  _CrossPainter.chip(BuildContext context)
    : arm = BlockWordsTheme.chipGlyph / 2 - BlockWordsTheme.chipGlyphInset,
      stroke = BlockWordsTheme.chipStroke,
      color = BlockWordsTheme.colorsOf(context).grey,
      cap = StrokeCap.butt;

  final double arm;
  final double stroke;
  final Color color;
  final StrokeCap cap;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = cap
      ..isAntiAlias = true;
    canvas
      ..drawLine(c + Offset(-arm, -arm), c + Offset(arm, arm), paint)
      ..drawLine(c + Offset(arm, -arm), c + Offset(-arm, arm), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.arm != arm || old.stroke != stroke || old.color != color;
}

/// 添加's pencil, traced from 30 in a 17 pt box: a square-tipped pencil at 45°, its ferrule line, a rule under it.
class _PencilPainter extends CustomPainter {
  const _PencilPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / BlockWordsTheme.addIcon;
    canvas.scale(scale);
    final paint = Paint()
      ..color = BlockWordsTheme.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = BlockWordsTheme.addStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(0.83, 16.38)
      ..lineTo(0.83, 12.33)
      ..lineTo(11.6, 1.56)
      ..arcToPoint(const Offset(12.98, 1.56), radius: const Radius.circular(0.98))
      ..lineTo(15.56, 4.14)
      ..arcToPoint(const Offset(15.56, 5.52), radius: const Radius.circular(0.98))
      ..lineTo(4.88, 16.38)
      ..close();
    canvas
      ..drawPath(body, paint)
      ..drawLine(const Offset(9.38, 3.79), const Offset(13.33, 7.75), paint)
      ..drawLine(const Offset(9.8, 16.4), const Offset(16.2, 16.4), paint);
  }

  @override
  bool shouldRepaint(_PencilPainter old) => false;
}

/// 同步's two arrows chasing round a circle, traced from 30 in a 19 pt box.
class _SyncPainter extends CustomPainter {
  const _SyncPainter();

  static const _radius = 8.75;
  static const _arrow = 4.0;
  static const _sweep = 157 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / BlockWordsTheme.syncIcon;
    canvas.scale(scale);
    final paint = Paint()
      ..color = BlockWordsTheme.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = BlockWordsTheme.syncStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const centre = Offset(BlockWordsTheme.syncIcon / 2, BlockWordsTheme.syncIcon / 2);
    final circle = Rect.fromCircle(center: centre, radius: _radius);
    for (final (start, tipDirection) in [(-math.pi / 2, 1.0), (math.pi / 2, -1.0)]) {
      canvas.drawArc(circle, start, _sweep, false, paint);
      final end = start + _sweep;
      final tip = centre + Offset(math.cos(end), math.sin(end)) * _radius;
      // Each head is a right angle opening back along the arc: up and right at the bottom, down and left at the top.
      final head = Path()
        ..moveTo(tip.dx, tip.dy - _arrow * tipDirection)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + _arrow * tipDirection, tip.dy);
      canvas.drawPath(head, paint);
    }
  }

  @override
  bool shouldRepaint(_SyncPainter old) => false;
}
