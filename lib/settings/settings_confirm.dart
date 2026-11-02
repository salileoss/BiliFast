import 'package:flutter/widgets.dart';

import '../shared/theme.dart';

/// 51's alert over the page: a title, a grey message when there is one, and 取消 / a pink [action], over a dim
/// that cancels when tapped. It fades in settling from slightly large.
class SettingsConfirm extends StatelessWidget {
  const SettingsConfirm({
    super.key,
    required this.title,
    this.message,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
    this.motion = kAlwaysCompleteAnimation,
  });

  final String title;
  final String? message;
  final String action;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// How far in it is: the page runs it forward to show and back to hide.
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      color: SettingsTheme.colorsOf(context).confirmTitle,
      decoration: TextDecoration.none,
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: motion,
            child: Semantics(
              button: true,
              label: '取消',
              onTap: onCancel,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('settings-confirm-dim'),
                behavior: HitTestBehavior.opaque,
                onTap: onCancel,
                child: const ColoredBox(color: SettingsTheme.confirmDim),
              ),
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, child) => Opacity(
              opacity: motion.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: SettingsTheme.confirmStartScale - (SettingsTheme.confirmStartScale - 1) * motion.value,
                child: child,
              ),
            ),
            child: _Alert(title: title, message: message, action: action, onConfirm: onConfirm, onCancel: onCancel),
          ),
        ),
      ],
    ),
  );
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.title,
    required this.message,
    required this.action,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String? message;
  final String action;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Container(
      key: const ValueKey('settings-confirm'),
      width: SettingsTheme.confirmWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SettingsTheme.colorsOf(context).confirm,
        borderRadius: BorderRadius.circular(SettingsTheme.confirmRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              SettingsTheme.confirmSide,
              SettingsTheme.confirmTitleTop,
              SettingsTheme.confirmSide,
              // Alone, the title sits in the middle of the space above the rule.
              message == null ? SettingsTheme.confirmTitleTop : SettingsTheme.confirmMessageBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: BiliFonts.family,
                    fontSize: SettingsTheme.confirmTitleText,
                    height: SettingsTheme.confirmTitleLine / SettingsTheme.confirmTitleText,
                    fontWeight: SettingsTheme.confirmTitleWeight,
                    color: SettingsTheme.colorsOf(context).confirmTitle,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: SettingsTheme.confirmMessageGap),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: BiliFonts.family,
                      fontSize: SettingsTheme.confirmMessageText,
                      height: SettingsTheme.confirmMessageLine / SettingsTheme.confirmMessageText,
                      color: SettingsTheme.colorsOf(context).confirmMessage,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(height: SettingsTheme.confirmRule, color: SettingsTheme.colorsOf(context).confirmRuleColor),
          SizedBox(
            height: SettingsTheme.confirmButtonHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Button(label: '取消', color: SettingsTheme.colorsOf(context).confirmCancel, onTap: onCancel),
                ),
                Expanded(
                  child: _Button(label: action, color: SettingsTheme.colorsOf(context).confirmAction, onTap: onConfirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatefulWidget {
  const _Button({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_Button> createState() => _ButtonState();
}

class _ButtonState extends State<_Button> {
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
      key: ValueKey('settings-confirm-${widget.label}'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      child: AnimatedContainer(
        duration: SettingsTheme.confirmPressMotion,
        color: _down ? SettingsTheme.colorsOf(context).confirmPressed : SettingsTheme.colorsOf(context).confirm,
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontFamily: BiliFonts.family,
            fontSize: SettingsTheme.confirmButtonText,
            color: widget.color,
          ),
        ),
      ),
    ),
  );
}
