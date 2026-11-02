import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_environment.dart';
import '../../app/app_scope.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../video/actions/actions_model.dart' show ActionsModel;
import '../search_glyphs.dart';
import 'video_row.dart' show searchLogReason, searchStyle;

/// A result row's ⋮ (59): the light sheet with 添加至稍后再看 and the feedback buttons, over a dimmed page. An in-page
/// overlay in the search page's Stack; [onClose] removes it.
///
/// It rises when shown and sinks before [onClose] runs; a tap on the dim or a drag down closes it.
class ResultMoreSheet extends StatefulWidget {
  const ResultMoreSheet({super.key, required this.video, required this.onClose});

  final SearchVideo video;
  final VoidCallback onClose;

  @override
  State<ResultMoreSheet> createState() => _ResultMoreSheetState();
}

class _ResultMoreSheetState extends State<ResultMoreSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: SearchResultTheme.sheetIn,
    reverseDuration: SearchResultTheme.sheetOut,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final _sheetKey = GlobalKey();
  bool _closing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_motion.forward());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _motion
      ..duration = still ? Duration.zero : SearchResultTheme.sheetIn
      ..reverseDuration = still ? Duration.zero : SearchResultTheme.sheetOut;
  }

  @override
  void dispose() {
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _motion.reverse();
    if (mounted) widget.onClose();
  }

  double get _sheetHeight => _sheetKey.currentContext?.size?.height ?? 1;

  void _dragged(DragUpdateDetails details) {
    if (_closing) return;
    _motion.value -= details.primaryDelta! / _sheetHeight;
  }

  void _released(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > SearchResultTheme.sheetFlingClose || _motion.value < 1 - SearchResultTheme.sheetDragClose) {
      unawaited(_close());
    } else {
      unawaited(_motion.forward());
    }
  }

  /// Logged out it goes to the login page; an account still being checked tries, and goes there only if Bilibili
  /// answers that it needs a login.
  Future<void> _watchLater() async {
    if (_busy || _closing) return;
    final services = AppScope.of(context);
    if (services.environment.account case LoggedOut() || LoginExpired()) {
      unawaited(services.loginGate.request(context));
      await _close();
      return;
    }
    _busy = true;
    try {
      await services.pageApi.addToWatchLater(aid: widget.video.aid);
      if (mounted) showToast(context, '已添加至稍后再看');
    } catch (error) {
      if (error is BiliError && error.needsLogin) {
        if (mounted) unawaited(services.loginGate.request(context));
      } else {
        Logger.shared.warn(LogCategory.ui, 'watch later failed', {'error': searchLogReason(error)});
        if (mounted) showToast(context, ActionsModel.failureMessage(error));
      }
    } finally {
      _busy = false;
    }
    if (mounted) await _close();
  }

  void _notYet() {
    if (_closing) return;
    showToast(context, '暂未开放');
    unawaited(_close());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return BlockSemantics(
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '关闭',
              onTap: _close,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('search-sheet-dim'),
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: FadeTransition(
                  opacity: _curve,
                  child: const ColoredBox(color: SearchResultTheme.sheetDim),
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
              child: GestureDetector(
                key: const ValueKey('search-sheet'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _dragged,
                onVerticalDragEnd: _released,
                child: Container(
                  key: _sheetKey,
                  decoration: BoxDecoration(
                    color: SearchResultTheme.colorsOf(context).sheetFill,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(SearchResultTheme.sheetRadius)),
                  ),
                  padding: EdgeInsets.only(
                    left: SearchResultTheme.sheetInset,
                    right: SearchResultTheme.sheetInset,
                    bottom: bottom + SearchResultTheme.sheetBottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: SearchResultTheme.sheetCardTop,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: SearchResultTheme.grabberTop),
                            child: SizedBox(
                              width: SearchResultTheme.grabberWidth,
                              height: SearchResultTheme.grabberHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: SearchResultTheme.colorsOf(context).grabberInk,
                                  borderRadius: BorderRadius.all(Radius.circular(SearchResultTheme.grabberHeight / 2)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _Card(
                        key: const ValueKey('search-sheet-watch-later'),
                        height: SearchResultTheme.sheetCardHeight,
                        label: '添加至稍后再看',
                        onTap: () => unawaited(_watchLater()),
                        child: Row(
                          children: [
                            SizedBox(width: SearchResultTheme.sheetIconLeft),
                            SearchGlyphIcon(
                              SearchGlyph.watchLater,
                              size: SearchResultTheme.sheetIcon,
                              color: SearchResultTheme.colorsOf(context).sheetInk,
                            ),
                            SizedBox(width: SearchResultTheme.sheetIconGap),
                            _Words('添加至稍后再看'),
                          ],
                        ),
                      ),
                      const _Heading('匹配度反馈'),
                      _Pair(labels: const ['不感兴趣', '与搜索词无关'], onTap: _notYet),
                      const _Heading('内容反馈'),
                      _Pair(labels: const ['内容质量差', '内容过时'], onTap: _notYet),
                      const SizedBox(height: SearchResultTheme.sheetButtonGap),
                      _Pair(labels: const ['色情低俗', '内容不适'], onTap: _notYet),
                      const SizedBox(height: SearchResultTheme.sheetButtonGap),
                      _Pair(labels: const ['相似过多', '其他'], onTap: _notYet),
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

class _Words extends StatelessWidget {
  const _Words(
    this.text, {
    this.size = SearchResultTheme.sheetText,
    this.weight = FontWeight.w400,
    this.drop = SearchResultTheme.sheetTextDrop,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final double drop;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, drop),
    child: Text(
      text,
      maxLines: 1,
      style: searchStyle(size, SearchResultTheme.colorsOf(context).sheetInk, weight: weight).copyWith(height: 1),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: SearchResultTheme.sheetHeaderBlock,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          top: SearchResultTheme.sheetHeaderCentre - SearchResultTheme.sheetHeaderText / 2,
          height: SearchResultTheme.sheetHeaderText,
          child: Semantics(
            header: true,
            child: _Words(
              text,
              size: SearchResultTheme.sheetHeaderText,
              weight: SearchResultTheme.sheetHeaderWeight,
              drop: 0,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Pair extends StatelessWidget {
  const _Pair({required this.labels, required this.onTap});

  final List<String> labels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    spacing: SearchResultTheme.sheetButtonGap,
    children: [
      for (final label in labels)
        Expanded(
          child: _Card(
            key: ValueKey('search-sheet-$label'),
            height: SearchResultTheme.sheetButtonHeight,
            label: label,
            onTap: onTap,
            child: Center(child: _Words(label)),
          ),
        ),
    ],
  );
}

class _Card extends StatefulWidget {
  const _Card({super.key, required this.height, required this.label, required this.onTap, required this.child});

  final double height;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        foregroundDecoration: BoxDecoration(
          color: _pressed ? BiliColors.colorsOf(context).pressedFill : null,
          borderRadius: BorderRadius.circular(SearchResultTheme.sheetCardRadius),
        ),
        decoration: BoxDecoration(
          color: SearchResultTheme.colorsOf(context).sheetCardFill,
          borderRadius: BorderRadius.circular(SearchResultTheme.sheetCardRadius),
        ),
        child: widget.child,
      ),
    ),
  );
}
