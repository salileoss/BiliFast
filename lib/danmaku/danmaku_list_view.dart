import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/danmaku.dart';
import 'package:bili_core/devlog.dart';
import 'package:bili_core/logic.dart';
import 'package:flutter/widgets.dart';

import '../player_ui/panels/panel_controller.dart';
import '../player_ui/player_ui.dart';
import '../shared/action_glyphs.dart';
import '../shared/theme.dart';
import '../video/actions/actions_model.dart';
import 'danmaku_session.dart';

/// 当前弹幕列表 (31, 32): the danmaku shown so far, each with its 👍 and a ⋮ offering 屏蔽弹幕.
class DanmakuListView extends StatefulWidget {
  const DanmakuListView({super.key, required this.ui, required this.toast, required this.back, required this.close});

  final PlayerUi ui;
  final ValueChanged<String> toast;

  /// Back to 弹幕设置.
  final VoidCallback back;
  final VoidCallback close;

  /// Ids per 👍 count request, so a long list never makes one huge query.
  static const likesBatch = 50;

  @override
  State<DanmakuListView> createState() => _DanmakuListViewState();
}

final class _Row {
  _Row(this.elem);

  final DanmakuElem elem;
  final key = GlobalKey();
}

/// The ⋮ row's top and bottom and the list's size, in the list's own coordinates.
typedef _Menu = ({_Row row, double top, double bottom, Size list});

class _DanmakuListViewState extends State<DanmakuListView> {
  final _stack = GlobalKey();
  final _link = LayerLink();

  /// The popover reaches into the panel's right margin, past the list's own box, where the list gets no taps; in the
  /// app's overlay it takes all of its own and a tap anywhere else closes it.
  final _portal = OverlayPortalController();

  /// Read once: the list stays as it opened while the video plays on behind it.
  late final List<_Row> _rows = [for (final elem in widget.ui.danmaku?.recent() ?? const <DanmakuElem>[]) _Row(elem)];
  final Map<int, DanmakuLikeStat> _stats = {};
  final Set<int> _pending = {};
  _Menu? _menu;

  DanmakuSession? get _session => widget.ui.danmaku;

  @override
  void initState() {
    super.initState();
    widget.ui.panels.addListener(_panelsChanged);
    unawaited(_loadLikes());
  }

  @override
  void didUpdateWidget(DanmakuListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.ui.panels, widget.ui.panels)) return;
    oldWidget.ui.panels.removeListener(_panelsChanged);
    widget.ui.panels.addListener(_panelsChanged);
  }

  @override
  void dispose() {
    widget.ui.panels.removeListener(_panelsChanged);
    super.dispose();
  }

  /// The popover is outside the panel's layer, so the panel sliding out or giving way to another must take it down.
  void _panelsChanged() {
    if (_menu != null && widget.ui.panels.value != PlayerPanel.danmakuList) _closeMenu();
  }

  /// A [BiliError]'s text carries no URL or cookie; anything else is logged by type only.
  static String _describe(Object error) => error is BiliError ? '$error' : '${error.runtimeType}';

  Future<void> _loadLikes() async {
    final session = _session;
    final cid = session?.target?.cid;
    if (session == null || cid == null) return;
    final ids = {
      for (final row in _rows)
        if (row.elem.id != 0) row.elem.id,
    }.toList();
    for (var start = 0; start < ids.length; start += DanmakuListView.likesBatch) {
      final batch = ids.sublist(start, math.min(ids.length, start + DanmakuListView.likesBatch));
      try {
        final stats = await session.api.danmakuLikes(cid: cid, dmids: batch);
        if (!mounted) return;
        setState(() {
          for (final MapEntry(:key, :value) in stats.entries) {
            if (!_pending.contains(key)) _stats[key] = value;
          }
        });
      } on Object catch (error) {
        // The counts are extra: without them every 👍 still works, from zero.
        Logger.shared.warn(LogCategory.api, 'danmaku likes failed', {'error': _describe(error)});
        return;
      }
    }
  }

  Future<void> _like(DanmakuElem elem) async {
    final session = _session;
    if (session == null) return;
    if (!session.loggedIn) {
      session.requestLogin();
      return;
    }
    final cid = session.target?.cid;
    final id = elem.id;
    if (cid == null || id == 0 || _pending.contains(id)) return;
    final before = _stats[id] ?? (likes: 0, liked: false);
    final after = (likes: math.max(0, before.likes + (before.liked ? -1 : 1)), liked: !before.liked);
    setState(() {
      _stats[id] = after;
      _pending.add(id);
    });
    try {
      await session.api.likeDanmaku(cid: cid, dmid: id, on: after.liked);
    } on Object catch (error) {
      Logger.shared.warn(LogCategory.api, 'danmaku like failed', {'on': after.liked, 'error': _describe(error)});
      if (!mounted) return;
      setState(() => _stats[id] = before);
      if (error is BiliError && error.needsLogin) {
        session.requestLogin();
      } else {
        widget.toast(ActionsModel.failureMessage(error));
      }
    } finally {
      _pending.remove(id);
    }
  }

  void _openMenu(_Row row) {
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    final box = row.key.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || box == null) return;
    final top = box.localToGlobal(Offset.zero, ancestor: stack).dy;
    setState(() => _menu = (row: row, top: top, bottom: top + box.size.height, list: stack.size));
    _portal.show();
  }

  void _closeMenu() {
    setState(() => _menu = null);
    _portal.hide();
  }

  void _hide(_Row row) {
    _session?.hide(row.elem);
    _rows.remove(row);
    _closeMenu();
  }

  @override
  Widget build(BuildContext context) {
    // At least the panel's height, so a row low in it opens the popover upwards rather than past the panel's bottom.
    final fill = MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).vertical - BiliMetrics.panelBottom;
    final fade = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 150);
    final menu = _menu;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: CompositedTransformTarget(
        link: _link,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0, fill)),
          child: Stack(
            key: _stack,
            children: [
              if (_rows.isEmpty)
                SizedBox(
                  height: DanmakuListTheme.rowMinHeight,
                  child: Center(
                    child: Text('暂无弹幕', style: DanmakuListTheme.textStyle.copyWith(color: DanmakuListTheme.colorsOf(context).emptyColor)),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final row in _rows)
                      AnimatedOpacity(
                        key: row.key,
                        opacity: menu == null || identical(menu.row, row) ? 1 : DanmakuListTheme.dimmed,
                        duration: fade,
                        child: _DanmakuRow(
                          elem: row.elem,
                          stat: _stats[row.elem.id],
                          onLike: () => _like(row.elem),
                          onMore: () => _openMenu(row),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final menu = _menu;
    if (menu == null) return const SizedBox.shrink();
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('danmaku-list-menu-dismiss'),
            behavior: HitTestBehavior.opaque,
            onTap: _closeMenu,
          ),
        ),
        _popover(menu),
      ],
    );
  }

  /// Follows the list, so it stays under ⋮ wherever the panel is.
  Widget _popover(_Menu menu) {
    const height = DanmakuListTheme.popoverHeight + DanmakuListTheme.popoverArrowHeight;
    const boxWidth = DanmakuListTheme.popoverCell + DanmakuListTheme.popoverPadX * 2;
    const arrowX = boxWidth - BiliMetrics.panelTrailing - DanmakuListTheme.moreCentre;
    final belowTop = menu.bottom - DanmakuListTheme.popoverOverlap;
    final up = belowTop + height > menu.list.height && menu.top + DanmakuListTheme.popoverOverlap - height >= 0;
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: Offset(
          menu.list.width + BiliMetrics.panelTrailing - boxWidth,
          up ? menu.top + DanmakuListTheme.popoverOverlap - height : belowTop,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () {},
          child: CustomPaint(
            key: const ValueKey('danmaku-list-menu'),
            painter: _PopoverPainter(arrowX: arrowX, up: up),
            child: SizedBox(
              width: boxWidth,
              height: height,
              child: Padding(
                padding: EdgeInsets.only(
                  top: up ? 0 : DanmakuListTheme.popoverArrowHeight,
                  bottom: up ? DanmakuListTheme.popoverArrowHeight : 0,
                  left: DanmakuListTheme.popoverPadX,
                  right: DanmakuListTheme.popoverPadX,
                ),
                child: Semantics(
                  button: true,
                  label: '屏蔽弹幕',
                  onTap: () => _hide(menu.row),
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const ValueKey('danmaku-list-hide'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _hide(menu.row),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: DanmakuListTheme.popoverIconCentre - DanmakuListTheme.popoverIconHeight / 2,
                          child: const Center(
                            child: CustomPaint(
                              size: Size(DanmakuListTheme.popoverIconWidth, DanmakuListTheme.popoverIconHeight),
                              painter: _EyeSlashPainter(),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: DanmakuListTheme.popoverLabelCentre - DanmakuListTheme.popoverText / 2,
                          height: DanmakuListTheme.popoverText,
                          child: Center(child: Text('屏蔽弹幕', style: DanmakuListTheme.popoverStyle)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DanmakuRow extends StatelessWidget {
  const _DanmakuRow({required this.elem, required this.stat, required this.onLike, required this.onMore});

  final DanmakuElem elem;
  final DanmakuLikeStat? stat;
  final VoidCallback onLike;
  final VoidCallback onMore;

  /// From the 👍's box to the content's edge.
  static const _trailing = DanmakuListTheme.thumbCentre + DanmakuListTheme.thumbTarget / 2;

  @override
  Widget build(BuildContext context) {
    final liked = stat?.liked ?? false;
    final likes = stat?.likes ?? 0;
    final colour = liked ? DanmakuListTheme.colorsOf(context).liked : DanmakuListTheme.thumb;
    final count = likes > 0 ? CountFormat.short(likes) : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: DanmakuListTheme.rowMinHeight),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: DanmakuListTheme.rowPadY,
                bottom: DanmakuListTheme.rowPadY,
                right: DanmakuListTheme.textGap,
              ),
              child: Text(
                elem.content,
                style: DanmakuListTheme.textStyle,
                strutStyle: BiliFonts.strutOf(context, DanmakuListTheme.textStyle),
              ),
            ),
          ),
          SizedBox(
            width: _trailing,
            height: DanmakuListTheme.rowMinHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: DanmakuListTheme.thumbTarget,
                  child: Semantics(
                    button: true,
                    label: '点赞：${elem.content}',
                    value: count ?? '',
                    selected: liked,
                    onTap: onLike,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('danmaku-list-like'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onLike,
                      child: Transform.translate(
                        offset: const Offset(0, -DanmakuListTheme.thumbRise),
                        child: Center(
                          child: ActionIcon(
                            ActionGlyph.like,
                            solid: liked,
                            size: DanmakuListTheme.thumbIcon,
                            color: colour,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (count != null)
                  Positioned(
                    left:
                        DanmakuListTheme.thumbTarget / 2 +
                        DanmakuListTheme.thumbIcon * ActionIcon.inkShare / 2 +
                        DanmakuListTheme.countGap,
                    top:
                        DanmakuListTheme.rowMinHeight / 2 - DanmakuListTheme.countRise - DanmakuListTheme.countText / 2,
                    child: IgnorePointer(
                      child: Text(
                        count,
                        key: const ValueKey('danmaku-list-count'),
                        style: DanmakuListTheme.countStyle(colour),
                        strutStyle: BiliFonts.strutOf(context, DanmakuListTheme.countStyle(colour)),
                      ),
                    ),
                  ),
                Positioned(
                  right: DanmakuListTheme.dividerCentre - DanmakuListTheme.dividerWidth / 2,
                  width: DanmakuListTheme.dividerWidth,
                  top: (DanmakuListTheme.rowMinHeight - DanmakuListTheme.dividerHeight) / 2,
                  height: DanmakuListTheme.dividerHeight,
                  child: ColoredBox(color: DanmakuListTheme.colorsOf(context).divider),
                ),
                Positioned(
                  right: 0,
                  width: DanmakuListTheme.dividerCentre,
                  top: 0,
                  bottom: 0,
                  child: Semantics(
                    button: true,
                    label: '更多：${elem.content}',
                    onTap: onMore,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('danmaku-list-more'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onMore,
                      child: const CustomPaint(painter: _MorePainter()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ⋮, its dots centred [DanmakuListTheme.moreCentre] in from the right.
class _MorePainter extends CustomPainter {
  const _MorePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = DanmakuListTheme.more;
    final x = size.width - DanmakuListTheme.moreCentre;
    final y = size.height / 2;
    for (final step in const [-1, 0, 1]) {
      canvas.drawCircle(Offset(x, y + step * DanmakuListTheme.morePitch), DanmakuListTheme.moreDot / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_MorePainter oldDelegate) => false;
}

/// 32's dark rounded box with its arrow at [arrowX], on top, or at the bottom when it opens upwards.
class _PopoverPainter extends CustomPainter {
  const _PopoverPainter({required this.arrowX, required this.up});

  final double arrowX;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    const arrow = DanmakuListTheme.popoverArrowHeight;
    const half = DanmakuListTheme.popoverArrowWidth / 2;
    final box = Rect.fromLTWH(0, up ? 0 : arrow, size.width, size.height - arrow);
    final tipY = up ? size.height : 0.0;
    final baseY = up ? box.bottom : box.top;
    // The tip is rounded off, as the official arrow's is.
    final rise = up ? -arrow : arrow;
    final tip = Path()
      ..moveTo(arrowX - half, baseY + (up ? -1 : 1))
      ..lineTo(arrowX - half * 0.22, tipY + rise * 0.16)
      ..quadraticBezierTo(arrowX, tipY, arrowX + half * 0.22, tipY + rise * 0.16)
      ..lineTo(arrowX + half, baseY + (up ? -1 : 1))
      ..close();
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(DanmakuListTheme.popoverRadius))),
      tip,
    );
    canvas.drawPath(shape, Paint()..color = DanmakuListTheme.popoverFill);
  }

  @override
  bool shouldRepaint(_PopoverPainter oldDelegate) => oldDelegate.arrowX != arrowX || oldDelegate.up != up;
}

/// 屏蔽弹幕's eye, struck through from top right to bottom left with a gap either side of the stroke.
class _EyeSlashPainter extends CustomPainter {
  const _EyeSlashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const line = DanmakuListTheme.popoverIconStroke;
    final w = size.width, h = size.height;
    final stroke = Paint()
      ..color = DanmakuListTheme.popoverInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final eye = Path()
      ..moveTo(line, h / 2)
      ..quadraticBezierTo(w / 2, -h * 0.12, w - line, h / 2)
      ..quadraticBezierTo(w / 2, h * 1.12, line, h / 2)
      ..close();
    final centre = Offset(w / 2, h / 2);
    final pupil = h * 0.25;
    final slashFrom = Offset(w * 0.8, line / 2);
    final slashTo = Offset(w * 0.2, h - line / 2);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas
      ..drawPath(eye, stroke)
      ..drawCircle(centre, pupil, stroke)
      ..drawArc(Rect.fromCircle(center: centre, radius: pupil * 0.5), 0, math.pi / 2, false, stroke)
      ..drawLine(
        slashFrom,
        slashTo,
        Paint()
          ..blendMode = BlendMode.clear
          ..strokeWidth = line * 3
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(slashFrom, slashTo, stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_EyeSlashPainter oldDelegate) => false;
}
