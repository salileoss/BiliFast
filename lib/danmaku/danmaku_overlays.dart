import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app/form_factor.dart';
import '../device/orientation.dart';
import '../player_ui/panels/panel_layer.dart' show PadSheetDim, PadSheetFrame;
import '../shared/theme.dart';
import 'danmaku_session.dart';
import 'send/danmaku_send_bar.dart';
import 'send/danmaku_send_model.dart';
import 'send/danmaku_style_panel.dart';

/// The send bar riding on the keyboard, with the style panel in the keyboard's place after A (22, 23, 36-39), as a
/// layer in the page's Stack. On the small player the page under the player dims (39) and a tap there closes (on the
/// iPad's page everything but the player); in landscape and 竖屏 a tap anywhere above the bar does. Lets touches
/// through while the bar is down.
class DanmakuOverlays extends StatefulWidget {
  const DanmakuOverlays({
    super.key,
    required this.session,
    required this.presentation,
    required this.playerBottom,
    required this.toast,
    this.padFrame,
  });

  final DanmakuSession session;
  final Presentation presentation;

  /// Where the small player ends on the page; the dim starts there.
  final double playerBottom;
  final ValueChanged<String> toast;

  /// The iPad page's, outside full screen: the bar takes its column, and all but its player dims and closes.
  final PadSheetFrame? padFrame;

  /// Forgets the keyboard heights the style panel takes; for tests.
  @visibleForTesting
  static void debugForgetKeyboard() => _DanmakuOverlaysState._keyboard.clear();

  @override
  State<DanmakuOverlays> createState() => _DanmakuOverlaysState();
}

class _DanmakuOverlaysState extends State<DanmakuOverlays> {
  /// The keyboard's height the last time it was up, landscape's and portrait's apart, which the style panel takes so
  /// the bar stays put.
  static final Map<bool, double> _keyboard = {};

  final _focus = FocusNode(debugLabel: 'danmaku-send');
  bool _styleShown = false;
  double _lastInset = 0;
  Timer? _keyboardWait;

  @override
  void initState() {
    super.initState();
    widget.session.sendOpen.addListener(_openChanged);
    widget.session.sender.addListener(_changed);
    widget.session.addListener(_changed);
    _focus.addListener(_focusChanged);
    if (widget.session.sendOpen.value) _focusSoon();
  }

  @override
  void didUpdateWidget(DanmakuOverlays oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      oldWidget.session.sendOpen.removeListener(_openChanged);
      oldWidget.session.sender.removeListener(_changed);
      oldWidget.session.removeListener(_changed);
      widget.session.sendOpen.addListener(_openChanged);
      widget.session.sender.addListener(_changed);
      widget.session.addListener(_changed);
      _openChanged();
    }
  }

  @override
  void dispose() {
    widget.session.sendOpen.removeListener(_openChanged);
    widget.session.sender.removeListener(_changed);
    widget.session.removeListener(_changed);
    _keyboardWait?.cancel();
    _focus.dispose();
    super.dispose();
  }

  bool get _landscape => widget.presentation == Presentation.landscape;

  /// Which keyboard is up: the iPad's page has a landscape one too.
  bool get _keyboardWide {
    if (!FormFactor.of(context).isPad) return _landscape;
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _openChanged() {
    if (!mounted) return;
    if (widget.session.sendOpen.value) {
      setState(() => _styleShown = false);
      _focusSoon();
    } else {
      _keyboardWait?.cancel();
      _focus.unfocus();
      setState(() => _styleShown = false);
    }
  }

  /// The field is built in the next frame; it takes focus then, which brings the keyboard.
  void _focusSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && widget.session.sendOpen.value && !_styleShown) _focus.requestFocus();
  });

  void _focusChanged() {
    if (_focus.hasFocus && _styleShown) _waitForKeyboard();
  }

  /// The panel stays until the keyboard has risen over it (see [_trackKeyboard]), or gives way after a while: a
  /// hardware keyboard shows no software one.
  void _waitForKeyboard() {
    _keyboardWait?.cancel();
    _keyboardWait = Timer(DanmakuSendTheme.keyboardWait, _leaveStyle);
  }

  void _leaveStyle() {
    if (!mounted || !_focus.hasFocus || !_styleShown) return;
    _keyboardWait?.cancel();
    setState(() => _styleShown = false);
  }

  void _trackKeyboard(double inset, double panel) {
    if (inset > 0 && _focus.hasFocus) {
      // Kept while it rises or rests; a keyboard on its way down has no height worth keeping.
      if (!_styleShown && inset >= _lastInset) _keyboard[_keyboardWide] = inset;
      if (_styleShown && inset >= panel - 0.5) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _leaveStyle());
      }
    }
    _lastInset = inset;
  }

  double get _panelHeight =>
      _keyboard[_keyboardWide] ??
      switch ((FormFactor.of(context).isPad, _keyboardWide)) {
        (true, true) => PadDanmakuTheme.landscapePanelHeight,
        (true, false) => PadDanmakuTheme.portraitPanelHeight,
        (false, true) => DanmakuSendTheme.landscapePanelHeight,
        (false, false) => DanmakuSendTheme.portraitPanelHeight,
      };

  void _toggleStyle() {
    widget.session.sender.sawStyleHint();
    if (_styleShown) {
      _focus.requestFocus();
      return;
    }
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 0) _keyboard[_keyboardWide] = inset;
    setState(() => _styleShown = true);
    _focus.unfocus();
  }

  Future<void> _send() async {
    final session = widget.session;
    final sender = session.sender;
    // The page's toast outlives this layer, so an answer still shows after the bar has gone.
    final toast = widget.toast;
    if (session.closed) {
      toast('UP主已关闭弹幕');
      return;
    }
    if (!sender.canSend) return;
    final message = await sender.send();
    if (message == null) {
      if (mounted && identical(widget.session, session)) session.closeSend();
    } else if (message.isNotEmpty) {
      toast(message);
    }
  }

  void _close() => widget.session.closeSend();

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (!session.sendOpen.value) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final panel = _panelHeight;
    _trackKeyboard(inset, panel);
    // 置底 picked in landscape isn't offered in portrait or 竖屏; there it sends as 滚动. Changed after the frame,
    // since the style's listeners rebuild.
    if (!_landscape && session.sender.style.position == DanmakuPosition.bottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sender = widget.session.sender;
        if (!mounted || _landscape || sender.style.position != DanmakuPosition.bottom) return;
        sender.style = sender.style.copyWith(position: DanmakuPosition.scroll);
      });
    }
    final dark = _landscape;
    final inline = widget.presentation == Presentation.inline;
    final padFrame = inline && FormFactor.of(context).isPad ? widget.padFrame : null;
    final below = _styleShown
        ? SizedBox(
            height: panel,
            child: DanmakuStylePanel(
              model: session.sender,
              dark: dark,
              offerBottom: _landscape,
              isVip: session.isVip,
              onVipOnly: () => widget.toast('开通大会员后可使用'),
            ),
          )
        : SizedBox(
            key: const ValueKey('danmaku-send-keyboard'),
            height: math.max(inset, media.viewPadding.bottom),
            child: ColoredBox(color: dark ? DanmakuSendTheme.darkArea : DanmakuSendTheme.colorsOf(context).lightBar),
          );
    final dim = Semantics(
      button: true,
      label: '关闭',
      onTap: _close,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('danmaku-send-dim'),
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: inline ? const ColoredBox(color: DanmakuSendTheme.dim) : const SizedBox.expand(),
      ),
    );
    return BlockSemantics(
      child: Stack(
        children: [
          if (padFrame != null)
            Positioned.fill(child: PadSheetDim(player: padFrame.player, child: dim))
          else
            Positioned(left: 0, right: 0, top: inline ? widget.playerBottom : 0, bottom: 0, child: dim),
          Positioned(
            left: 0,
            right: padFrame == null ? 0 : null,
            width: padFrame?.column,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DanmakuSendBar(
                  model: session.sender,
                  presentation: widget.presentation,
                  focusNode: _focus,
                  styleShown: _styleShown,
                  closed: session.closed,
                  onStyle: _toggleStyle,
                  onSend: () => unawaited(_send()),
                ),
                below,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
