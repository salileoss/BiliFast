import 'package:flutter/widgets.dart';

import '../shared/theme.dart';

/// The style every word on the page draws with: the app's font, and with [line] an even line box, so a line can be
/// placed by its middle.
TextStyle watchLaterStyle(double size, Color color, {double? line, FontWeight weight = FontWeight.w400}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: line == null ? null : line / size,
  leadingDistribution: line == null ? null : TextLeadingDistribution.even,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

/// Words with a pink button under them: logged out (登录) or failed (重试).
class StateWithButton extends StatelessWidget {
  const StateWithButton({
    super.key,
    required this.message,
    required this.button,
    required this.buttonKey,
    required this.onTap,
  });

  final String message;
  final String button;
  final Key buttonKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: WatchLaterTheme.gutter),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: watchLaterStyle(WatchLaterTheme.stateText, WatchLaterTheme.colorsOf(context).stateInk),
        ),
        const SizedBox(height: WatchLaterTheme.stateGap),
        Semantics(
          button: true,
          label: button,
          onTap: onTap,
          excludeSemantics: true,
          child: GestureDetector(
            key: buttonKey,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: WatchLaterTheme.buttonHeight,
              padding: const EdgeInsets.symmetric(horizontal: WatchLaterTheme.buttonPadX),
              decoration: ShapeDecoration(color: BiliColors.colorsOf(context).pink, shape: StadiumBorder()),
              child: Center(
                widthFactor: 1,
                child: Text(
                  button,
                  style: watchLaterStyle(
                    WatchLaterTheme.buttonText,
                    BiliColors.onPink,
                    weight: WatchLaterTheme.buttonWeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
