import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import 'panel_glyphs.dart';

/// What the panel's frame tells its rows: whether it sits at the right of a landscape screen (false in the portrait
/// sheet), and the open animation the rows reveal themselves along.
class PanelScope extends InheritedWidget {
  const PanelScope({
    super.key,
    required this.landscape,
    required this.reveal,
    this.pad = false,
    required super.child,
  });

  final bool landscape;
  final Animation<double> reveal;

  /// On the iPad, where full screen's 清晰度 and 倍速 draw their own rows (ipad/10, 11).
  final bool pad;

  static PanelScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PanelScope>();

  static bool landscapeOf(BuildContext context) => maybeOf(context)?.landscape ?? true;

  /// Full screen on the iPad.
  static bool padStripOf(BuildContext context) {
    final scope = maybeOf(context);
    return scope != null && scope.pad && scope.landscape;
  }

  @override
  bool updateShouldNotify(PanelScope oldWidget) =>
      landscape != oldWidget.landscape || reveal != oldWidget.reveal || pad != oldWidget.pad;
}

/// Fades a row in a little after the one above it as the panel opens, sliding in from the side it came from.
class PanelReveal extends StatelessWidget {
  const PanelReveal({super.key, required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = PanelScope.maybeOf(context);
    if (scope == null) return child;
    final start = (order * 0.06).clamp(0.0, 0.45);
    final curve = CurvedAnimation(
      parent: scope.reveal,
      curve: Interval(start, (start + 0.55).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final hidden = (1 - curve.value) * BiliMetrics.panelRevealShift;
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(offset: scope.landscape ? Offset(hidden, 0) : Offset(0, hidden), child: child),
        );
      },
      child: child,
    );
  }
}

/// Shrinks a touch and lightens under the finger.
class PanelPressable extends StatefulWidget {
  const PanelPressable({super.key, required this.onTap, required this.child, this.radius = BiliMetrics.panelRowRadius});

  final VoidCallback? onTap;
  final Widget child;
  final double radius;

  @override
  State<PanelPressable> createState() => _PanelPressableState();
}

class _PanelPressableState extends State<PanelPressable> {
  bool _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    onTapDown: widget.onTap == null ? null : (_) => _press(true),
    onTapUp: (_) => _press(false),
    onTapCancel: () => _press(false),
    child: AnimatedScale(
      scale: _down ? BiliMetrics.pressedScale : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _down ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: BiliColors.panelPressed,
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A panel's title, a back chevron before it when it is a page inside another, and whatever sits at the right. Its
/// row is [BiliMetrics.panelHitBox] tall so the chevron and the trailing control are full-size touches; pages start
/// it [BiliMetrics.panelHeaderTop] down.
class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.title, this.back, this.trailing});

  final String title;
  final VoidCallback? back;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: BiliMetrics.panelHitBox,
    child: Stack(
      children: [
        Positioned.fill(
          child: Row(
            children: [
              if (back != null) const SizedBox(width: BiliMetrics.panelHeaderHeight),
              Text(title),
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
        if (back case final back?)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: BiliMetrics.panelHitBox,
            child: Semantics(
              button: true,
              label: '返回',
              child: GestureDetector(
                key: const ValueKey('panel-back'),
                behavior: HitTestBehavior.opaque,
                onTap: back,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(Icons.arrow_back_ios_new, size: BiliMetrics.panelTitleText, color: BiliColors.panelText),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// A page under a [PanelHeader]: its rows [spacing] apart, the first as far below the header's drawn line as the
/// rest are from each other.
class PanelPage extends StatelessWidget {
  const PanelPage({super.key, required this.header, required this.children, this.spacing = BiliMetrics.panelGap});

  final PanelHeader header;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BiliMetrics.panelHeaderTop),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: spacing - (BiliMetrics.panelHitBox - BiliMetrics.panelHeaderHeight) / 2),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: spacing, children: children),
      ],
    ),
  );
}

/// Toasts what a setter's future completes with when it failed.
void toastFailure(Future<String?> result, ValueChanged<String> toast) {
  result.then((message) {
    if (message != null) toast(message);
  });
}

/// A section's title over its card, as 定时关闭.
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: BiliMetrics.panelSectionTitle,
    child: Row(children: [Text(text), const Spacer(), ?trailing]),
  );
}

/// One dark rounded card per option, as in the 清晰度 list; the chosen one is pink.
class PanelCardRow extends StatelessWidget {
  const PanelCardRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.trailing,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final String? badge;

  /// At the right of the title line, as 清晰度's ⓘ.
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: PanelPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: BiliMetrics.panelCardHeight),
        padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.panelCardPadX, vertical: BiliMetrics.panelCardPadY),
        decoration: BoxDecoration(
          color: BiliColors.panelCard,
          borderRadius: BorderRadius.circular(BiliMetrics.panelRowRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Transform.translate(
                offset: Offset(0, subtitle == null ? 0 : -BiliMetrics.panelSubtitleLift),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 160),
                                  style: DefaultTextStyle.of(context).style.copyWith(
                                    color: selected ? BiliColors.colorsOf(context).pink : BiliColors.panelText,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    strutStyle: BiliFonts.strutOf(context),
                                  ),
                                ),
                              ),
                              if (badge case final badge?) ...[
                                const SizedBox(width: BiliMetrics.panelBadgeGap),
                                _Badge(badge),
                              ],
                            ],
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                    if (subtitle case final subtitle?)
                      Padding(
                        padding: const EdgeInsets.only(top: BiliMetrics.panelSubtitleGap),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: BiliMetrics.panelSubtitleText,
                            color: BiliColors.panelSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  static const _style = TextStyle(
    fontSize: BiliMetrics.panelSubtitleText,
    height: 1,
    color: BiliColors.onPink,
    fontWeight: FontWeight.w400,
  );

  @override
  Widget build(BuildContext context) => Container(
    height: BiliMetrics.panelBadgeHeight,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.panelBadgePad),
    decoration: BoxDecoration(
      color: BiliColors.colorsOf(context).pink,
      borderRadius: BorderRadius.circular(BiliMetrics.panelBadgeHeight / 2),
    ),
    child: Text(text, style: _style, strutStyle: BiliFonts.strutOf(context, _style)),
  );
}

/// Rows sharing one dark rounded card.
class PanelGroup extends StatelessWidget {
  const PanelGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: BiliColors.panelCard,
      borderRadius: BorderRadius.circular(BiliMetrics.panelGroupRadius),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// An icon, a label and whatever sits at the right, with the hairline the official card draws under it from the
/// label on.
class PanelRowFrame extends StatelessWidget {
  const PanelRowFrame({
    super.key,
    required this.icon,
    required this.title,
    required this.trailing,
    this.divider = true,
  });

  final Widget icon;
  final String title;
  final Widget trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    height: BiliMetrics.panelRowHeight,
    padding: const EdgeInsets.only(left: BiliMetrics.panelRowLead, right: BiliMetrics.panelRowTrailing),
    foregroundDecoration: divider ? const _Hairline() : null,
    child: Row(
      children: [
        SizedBox(
          width: BiliMetrics.panelRowIcon,
          child: Center(child: icon),
        ),
        const SizedBox(width: BiliMetrics.panelLabelInset - BiliMetrics.panelRowLead - BiliMetrics.panelRowIcon),
        Text(title, maxLines: 1, strutStyle: BiliFonts.strutOf(context)),
        Expanded(child: trailing),
      ],
    ),
  );
}

/// Where the official card has a row this app doesn't (后台听视频, 色觉辅助), so the rest sit where they do in 21.
class PanelBlankRow extends StatelessWidget {
  const PanelBlankRow({super.key, this.divider = true});

  final bool divider;

  @override
  Widget build(BuildContext context) =>
      Container(height: BiliMetrics.panelRowHeight, foregroundDecoration: divider ? const _Hairline() : null);
}

class _Hairline extends Decoration {
  const _Hairline();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _HairlinePainter();
}

class _HairlinePainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx + BiliMetrics.panelLabelInset,
        offset.dy + size.height - BiliMetrics.panelHairline,
        size.width - BiliMetrics.panelLabelInset,
        BiliMetrics.panelHairline,
      ),
      Paint()..color = BiliColors.panelHairline,
    );
  }
}

class PanelToggleRow extends StatelessWidget {
  const PanelToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.divider = true,
  });

  final Widget icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: title,
    onTap: () => onChanged(!value),
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: PanelRowFrame(
        icon: icon,
        title: title,
        divider: divider,
        trailing: Align(
          alignment: Alignment.centerRight,
          child: PanelSwitch(on: value),
        ),
      ),
    ),
  );
}

/// The official switch is smaller than the system's, with a pink track.
class PanelSwitch extends StatelessWidget {
  const PanelSwitch({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    const inset = (BiliMetrics.panelSwitchHeight - BiliMetrics.panelSwitchKnob) / 2;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: BiliMetrics.panelSwitchWidth,
      height: BiliMetrics.panelSwitchHeight,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: on ? BiliColors.colorsOf(context).pink : BiliColors.panelTrackOff,
        borderRadius: BorderRadius.circular(BiliMetrics.panelSwitchHeight / 2),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: BiliMetrics.panelSwitchKnob,
          height: BiliMetrics.panelSwitchKnob,
          decoration: const BoxDecoration(color: BiliColors.panelKnob, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Segments split by hairlines, the chosen one pink: sharing the card's width equally (定时关闭), or [compact], each as
/// wide as its text and packed to the right (循环播放).
class PanelSegments<T> extends StatelessWidget {
  const PanelSegments({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.compact = false,
  });

  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelect;
  final bool compact;

  Widget _segment(BuildContext context, T value, String title) {
    final chosen = value == selected;
    final style = DefaultTextStyle.of(context).style.copyWith(
      fontSize: BiliMetrics.panelDetailText,
      color: chosen ? BiliColors.colorsOf(context).pink : BiliColors.panelText,
      fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
    );
    final label = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 160),
      style: style,
      child: Text(title, maxLines: 1, strutStyle: BiliFonts.strut(style)),
    );
    return Semantics(
      button: true,
      selected: chosen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(value),
        child: compact
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.panelSegmentPad),
                child: Center(child: label),
              )
            : SizedBox.expand(
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: label),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final (index, (value, title)) in items.indexed) ...[
        if (index > 0)
          Container(
            width: BiliMetrics.panelHairline,
            height: BiliMetrics.panelSegmentDivider,
            color: BiliColors.panelHairline,
          ),
        if (compact) _segment(context, value, title) else Expanded(child: _segment(context, value, title)),
      ],
    ];
    if (!compact) return Row(children: children);
    // The official row lets 单集循环 run under the label on a narrow screen; this one shrinks instead.
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: SizedBox(
          height: BiliMetrics.panelRowHeight,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

/// The secondary text and chevron at the right of a row that opens a page.
class PanelDisclosure extends StatelessWidget {
  const PanelDisclosure({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        text,
        style: const TextStyle(fontSize: BiliMetrics.panelDetailText, color: BiliColors.panelSecondary),
      ),
      const SizedBox(width: BiliMetrics.panelChevronGap),
      const PanelGlyph(PanelGlyphKind.chevron, color: BiliColors.panelSecondary),
      const SizedBox(width: BiliMetrics.panelChevronTrailing),
    ],
  );
}
