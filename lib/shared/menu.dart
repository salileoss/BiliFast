import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Frosted glass under a menu: the page behind shows blurred through a light fill, inside a hairline rim.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(BiliMetrics.menuRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: BiliColors.glassShadow,
            blurRadius: BiliMetrics.glassShadowBlur,
            offset: Offset(0, BiliMetrics.glassShadowDrop),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: BiliMetrics.glassBlur, sigmaY: BiliMetrics.glassBlur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: BiliColors.colorsOf(context).glassFill,
              borderRadius: radius,
              border: Border.all(color: BiliColors.colorsOf(context).glassBorder, width: BiliMetrics.glassHairline),
            ),
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }
}

/// A menu row: icon and title, greyed and disabled without [onTap].
class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.title, required this.icon, required this.onTap, this.note});

  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  /// Shown at the right of a row that does nothing yet.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? BiliColors.colorsOf(context).secondaryText : BiliColors.colorsOf(context).text;
    final titleStyle = TextStyle(fontSize: BiliMetrics.bodyText, color: color);
    final noteStyle = TextStyle(fontSize: BiliMetrics.smallText, color: BiliColors.colorsOf(context).secondaryText);
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: PressHighlight(
          onTap: onTap,
          child: SizedBox(
            height: BiliMetrics.menuRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: BiliMetrics.menuIconBox,
                    child: Icon(icon, size: BiliMetrics.menuIcon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: titleStyle, strutStyle: BiliFonts.strutOf(context, titleStyle)),
                  ),
                  if (note case final note?)
                    Text(note, style: noteStyle, strutStyle: BiliFonts.strutOf(context, noteStyle)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Darkens [child] while a finger is on it, as iOS rows answer a touch, in place of Material's ripple.
class PressHighlight extends StatefulWidget {
  const PressHighlight({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<PressHighlight> createState() => _PressHighlightState();
}

class _PressHighlightState extends State<PressHighlight> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _press(true) : null,
      onTapUp: enabled ? (_) => _press(false) : null,
      onTapCancel: enabled ? () => _press(false) : null,
      onTap: widget.onTap,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(color: _pressed ? BiliColors.colorsOf(context).pressedFill : null),
        child: widget.child,
      ),
    );
  }
}
