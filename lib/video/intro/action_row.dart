import 'dart:async';

import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../shared/action_glyphs.dart';
import '../../shared/theme.dart';
import '../actions/video_actions.dart';
import 'triple_ring.dart';

/// The action row's sizes: the iPhone's cells share the width, the iPad's are [cell] wide from the gutter.
@immutable
final class ActionRowMetrics {
  const ActionRowMetrics({
    required this.gutter,
    required this.topGap,
    required this.icon,
    required this.countGap,
    required this.countLine,
    required this.countFont,
    required this.bottom,
    required this.ring,
    required this.countColor,
    this.cell,
  });

  static const phone = ActionRowMetrics(
    gutter: BiliMetrics.gutter,
    topGap: ActionTheme.topGap,
    icon: ActionTheme.iconSize,
    countGap: ActionTheme.countGap,
    countLine: ActionTheme.countLine,
    countFont: ActionTheme.countFont,
    bottom: IntroListTheme.actionsBottom,
    ring: ActionTheme.ring,
    countColor: ActionTheme.count,
  );

  /// ipad/03.
  static const pad = ActionRowMetrics(
    gutter: PadBodyTheme.gutter,
    topGap: PadBodyTheme.actionTopGap,
    icon: PadBodyTheme.actionIcon,
    countGap: PadBodyTheme.actionCountGap,
    countLine: PadBodyTheme.actionCountLine,
    countFont: PadBodyTheme.actionCountText,
    bottom: PadBodyTheme.actionsBottom,
    ring: PadBodyTheme.actionRing,
    countColor: PadBodyTheme.actionCount,
    cell: PadBodyTheme.actionCell,
  );

  final double gutter;
  final double topGap;
  final double icon;
  final double countGap;
  final double countLine;
  final double countFont;
  final double bottom;
  final double ring;
  final Color countColor;

  /// Null: the five cells share the row.
  final double? cell;

  /// 投币's coin sits this much lower than the other icons, in proportion to the icon.
  double get coinDrop => IntroTheme.actionCoinDrop * icon / ActionTheme.iconSize;
}

/// 点赞 不喜欢 投币 收藏 分享 under the title (03). Holding 点赞 fills rings around 点赞, 投币 and 收藏 and does 三连.
/// The row owns the gap above its icons and ends [ActionRowMetrics.bottom] below its counts' line.
class ActionRow extends StatefulWidget {
  const ActionRow({super.key, required this.actions, this.metrics = ActionRowMetrics.phone});

  final VideoActions actions;
  final ActionRowMetrics metrics;

  @override
  State<ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<ActionRow> with TickerProviderStateMixin {
  late final _ring = AnimationController(vsync: this, duration: TripleTiming.fill)..addStatusListener(_ringStatus);
  late final _burst = AnimationController(vsync: this, duration: TripleTiming.burst);
  Timer? _hold;

  /// The press got as far as the rings: letting go then is an aborted 三连, not a tap on 点赞.
  bool _ringStarted = false;
  bool _tripled = false;

  VideoActions get _actions => widget.actions;

  @override
  void dispose() {
    _hold?.cancel();
    _ring.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _likeDown() {
    _hold?.cancel();
    _ringStarted = false;
    _tripled = false;
    _hold = Timer(TripleTiming.delay, () {
      if (!mounted) return;
      _ringStarted = true;
      _ring.forward(from: 0);
    });
  }

  void _likeUp() {
    _hold?.cancel();
    if (_tripled) return;
    if (_ringStarted) {
      _ring.animateBack(0, duration: TripleTiming.release);
    } else {
      unawaited(_actions.toggleLike());
    }
  }

  void _likeCancel() {
    _hold?.cancel();
    if (_ringStarted && !_tripled) _ring.animateBack(0, duration: TripleTiming.release);
  }

  void _ringStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _ringStarted && !_tripled) _triple();
  }

  void _triple() {
    _tripled = true;
    _ring.value = 0;
    // Logged out a login prompt follows, and when all three are done the model only says 已三连: no burst for those.
    if (_actions.tripleSends) {
      if (!MediaQuery.disableAnimationsOf(context)) _burst.forward(from: 0);
      unawaited(HapticFeedback.mediumImpact());
    }
    unawaited(_actions.triple());
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    return ListenableBuilder(
      listenable: _actions,
      builder: (context, _) {
        final actions = _actions;
        Widget ring(Widget cell, {double drop = 0}) =>
            _Ringed(progress: _ring, burst: _burst, metrics: metrics, drop: drop, child: cell);
        Widget slot(Widget cell) => switch (metrics.cell) {
          final width? => SizedBox(width: width, child: cell),
          null => Expanded(child: cell),
        };
        return Padding(
          padding: EdgeInsets.only(left: metrics.gutter, right: metrics.gutter, bottom: metrics.bottom),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              slot(
                _ActionCell(
                  key: const ValueKey('action-like'),
                  metrics: metrics,
                  glyph: ActionGlyph.like,
                  label: '点赞',
                  activeLabel: '取消点赞',
                  count: actions.likeCount,
                  active: actions.liked,
                  onTap: () => unawaited(actions.toggleLike()),
                  onLongPress: () => unawaited(actions.triple()),
                  onDown: _likeDown,
                  onUp: _likeUp,
                  onCancel: _likeCancel,
                  decorate: ring,
                ),
              ),
              slot(
                _ActionCell(
                  key: const ValueKey('action-dislike'),
                  metrics: metrics,
                  glyph: ActionGlyph.dislike,
                  label: '不喜欢',
                  active: actions.disliked,
                  tintsText: false,
                  onTap: () => unawaited(actions.toggleDislike()),
                ),
              ),
              slot(
                _ActionCell(
                  key: const ValueKey('action-coin'),
                  metrics: metrics,
                  glyph: ActionGlyph.coin,
                  label: '投币',
                  activeLabel: '已投币',
                  count: actions.coinCount,
                  active: actions.coins > 0,
                  onTap: () => actions.ask(ActionPrompt.coin),
                  iconDrop: metrics.coinDrop,
                  decorate: (cell) => ring(cell, drop: metrics.coinDrop),
                ),
              ),
              slot(
                _ActionCell(
                  key: const ValueKey('action-favourite'),
                  metrics: metrics,
                  glyph: ActionGlyph.favourite,
                  label: '收藏',
                  activeLabel: '已收藏',
                  count: actions.favCount,
                  active: actions.favorited,
                  onTap: () => actions.ask(ActionPrompt.favourites),
                  decorate: ring,
                ),
              ),
              slot(
                _ActionCell(
                  key: const ValueKey('action-share'),
                  metrics: metrics,
                  glyph: ActionGlyph.share,
                  label: '分享',
                  count: actions.shareCount,
                  active: false,
                  onTap: () => actions.ask(ActionPrompt.share),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The 三连 ring centred on a cell's icon, [drop] lower where the icon is.
class _Ringed extends StatelessWidget {
  const _Ringed({
    required this.progress,
    required this.burst,
    required this.metrics,
    required this.child,
    this.drop = 0,
  });

  final Animation<double> progress;
  final Animation<double> burst;
  final ActionRowMetrics metrics;
  final double drop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offset = (metrics.icon - metrics.ring) / 2;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        child,
        Positioned(
          top: metrics.topGap + offset + drop,
          child: TripleRing(progress: progress, burst: burst, size: metrics.ring),
        ),
      ],
    );
  }
}

/// One column: the icon, pink and popping when it turns on, over its count, or its name while the count is 0.
class _ActionCell extends StatefulWidget {
  const _ActionCell({
    super.key,
    required this.metrics,
    required this.glyph,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.activeLabel,
    this.tintsText = true,
    this.iconDrop = 0,
    this.onLongPress,
    this.onDown,
    this.onUp,
    this.onCancel,
    this.decorate,
  });

  final ActionRowMetrics metrics;
  final ActionGlyph glyph;
  final String label;

  /// How far the icon is drawn below its place; the count stays.
  final double iconDrop;

  /// What VoiceOver reads while [active], as landscape says it; the name under the icon stays [label].
  final String? activeLabel;
  final int? count;
  final bool active;

  /// Whether the count or name turns pink with the icon; 不喜欢's name stays grey (88).
  final bool tintsText;

  /// What a tap does; also the accessibility press.
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 点赞 takes the raw press instead of [onTap], so a hold can become 三连: [onDown] as the finger lands, then
  /// [onUp] or [onCancel].
  final VoidCallback? onDown;
  final VoidCallback? onUp;
  final VoidCallback? onCancel;
  final Widget Function(Widget cell)? decorate;

  @override
  State<_ActionCell> createState() => _ActionCellState();
}

class _ActionCellState extends State<_ActionCell> with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: ActionTheme.popScale).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: ActionTheme.popScale, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 65,
    ),
  ]).animate(_pop);
  bool _pressed = false;

  /// From the finger landing until it lifts, slides off or is taken by a scroll.
  bool _holding = false;

  @override
  void didUpdateWidget(_ActionCell old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !MediaQuery.disableAnimationsOf(context)) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  void _landed() {
    _holding = true;
    widget.onDown?.call();
  }

  void _ended({required bool cancelled}) {
    _press(false);
    if (!_holding) return;
    _holding = false;
    (cancelled ? widget.onCancel : widget.onUp)?.call();
  }

  String get _text {
    final count = widget.count;
    return count == null || count <= 0 ? widget.label : CountFormat.short(count);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final fade = still ? Duration.zero : const Duration(milliseconds: 180);
    final raw = widget.onDown != null;
    final metrics = widget.metrics;
    final cell = TweenAnimationBuilder<double>(
      tween: Tween(end: widget.active ? 1 : 0),
      duration: fade,
      builder: (context, on, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: metrics.topGap),
          Transform.translate(
            offset: Offset(0, widget.iconDrop),
            child: ScaleTransition(
              scale: _scale,
              child: ActionIcon(
                widget.glyph,
                solid: true,
                size: metrics.icon,
                stroke: ActionTheme.cutStroke,
                color: Color.lerp(ActionTheme.colorsOf(context).icon, BiliColors.colorsOf(context).pink, on)!,
              ),
            ),
          ),
          SizedBox(height: metrics.countGap),
          SizedBox(
            height: metrics.countLine,
            child: Center(
              child: Text(
                _text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontFamily: BiliFonts.family,
                  fontSize: metrics.countFont,
                  height: 1,
                  color: widget.tintsText ? Color.lerp(BiliPalette.of(context).choose(metrics.countColor, BiliPalette.of(context).secondary), BiliColors.colorsOf(context).pink, on) : BiliPalette.of(context).choose(metrics.countColor, BiliPalette.of(context).secondary),
                ),
                strutStyle: BiliFonts.strut(TextStyle(fontSize: metrics.countFont, height: 1)),
              ),
            ),
          ),
        ],
      ),
    );
    final body = AnimatedScale(
      scale: _pressed && !still ? BiliMetrics.chromePressedScale : 1,
      duration: const Duration(milliseconds: 120),
      child: cell,
    );
    return Semantics(
      button: true,
      label: widget.active ? widget.activeLabel ?? widget.label : widget.label,
      value: widget.count == null ? null : CountFormat.short(widget.count!),
      selected: widget.active,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      customSemanticsActions: widget.onLongPress == null
          ? null
          : {const CustomSemanticsAction(label: '一键三连'): widget.onLongPress!},
      excludeSemantics: true,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _PressRecognizer: GestureRecognizerFactoryWithHandlers<_PressRecognizer>(
            () => _PressRecognizer(debugOwner: this),
            (recognizer) => recognizer
              ..onPress = _landed
              ..onLost = (() => _ended(cancelled: true))
              ..onTapDown = ((_) => _press(true))
              ..onTapUp = ((_) => _ended(cancelled: false))
              ..onTapCancel = (() => _ended(cancelled: true))
              ..onTap = raw ? null : widget.onTap,
          ),
        },
        child: widget.decorate?.call(body) ?? body,
      ),
    );
  }
}

/// A tap that also says when its finger lands and when the finger is taken before any tap down. In the page's scroll
/// view and pager onTapDown waits [kPressTimeout] to see the finger isn't scrolling, which would start the 三连 hold
/// late, and a scroll that wins before then sends no cancel.
class _PressRecognizer extends TapGestureRecognizer {
  _PressRecognizer({super.debugOwner});

  VoidCallback? onPress;
  VoidCallback? onLost;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final fresh = state == GestureRecognizerState.ready;
    super.addAllowedPointer(event);
    if (fresh) onPress?.call();
  }

  @override
  void rejectGesture(int pointer) {
    final primary = pointer == primaryPointer;
    super.rejectGesture(pointer);
    if (primary) onLost?.call();
  }
}
