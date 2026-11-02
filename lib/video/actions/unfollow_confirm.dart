import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';

/// 确定不再关注？ with 取消 and 确定, over the page: a white alert over a dim, which settles from slightly large as it
/// fades in. A tap on the dim cancels.
class UnfollowConfirm extends StatelessWidget {
  const UnfollowConfirm({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.motion = kAlwaysCompleteAnimation,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// How far in it is: [ActionOverlays] runs it forward to show and back to hide.
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: FavouriteTheme.alertButtonText,
      color: BiliColors.colorsOf(context).text,
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
                key: const ValueKey('unfollow-dim'),
                behavior: HitTestBehavior.opaque,
                onTap: onCancel,
                child: const ColoredBox(color: FavouriteTheme.alertDim),
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
                scale: FavouriteTheme.alertStartScale - (FavouriteTheme.alertStartScale - 1) * motion.value,
                child: child,
              ),
            ),
            child: _Alert(onConfirm: onConfirm, onCancel: onCancel),
          ),
        ),
      ],
    ),
  );
}

class _Alert extends StatelessWidget {
  const _Alert({required this.onConfirm, required this.onCancel});

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('unfollow-alert'),
    width: FavouriteTheme.alertWidth,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: BiliColors.colorsOf(context).card, borderRadius: BorderRadius.circular(FavouriteTheme.alertRadius)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BiliMetrics.sectionGap,
            FavouriteTheme.alertTitlePadTop,
            BiliMetrics.sectionGap,
            FavouriteTheme.alertTitlePadBottom,
          ),
          child: Text(
            '确定不再关注？',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: BiliFonts.family,
              fontSize: FavouriteTheme.alertTitleText,
              fontWeight: FontWeight.w500,
              color: BiliColors.colorsOf(context).text,
            ),
          ),
        ),
        Container(height: BiliMetrics.panelHairline, color: BiliColors.colorsOf(context).divider),
        SizedBox(
          height: FavouriteTheme.alertButtonHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _AlertButton(label: '取消', color: BiliColors.colorsOf(context).secondaryText, onTap: onCancel),
              ),
              Container(width: BiliMetrics.panelHairline, color: BiliColors.colorsOf(context).divider),
              Expanded(
                child: _AlertButton(label: '确定', color: BiliColors.colorsOf(context).pink, onTap: onConfirm, strong: true),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AlertButton extends StatefulWidget {
  const _AlertButton({required this.label, required this.color, required this.onTap, this.strong = false});

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool strong;

  @override
  State<_AlertButton> createState() => _AlertButtonState();
}

class _AlertButtonState extends State<_AlertButton> {
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
      key: ValueKey('unfollow-${widget.label}'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _down ? BiliColors.colorsOf(context).pressedFill : BiliColors.colorsOf(context).card,
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontFamily: BiliFonts.family,
            fontSize: FavouriteTheme.alertButtonText,
            fontWeight: widget.strong ? FontWeight.w500 : FontWeight.w400,
            color: widget.color,
          ),
        ),
      ),
    ),
  );
}
