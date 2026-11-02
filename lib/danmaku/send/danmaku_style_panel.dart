import 'package:flutter/material.dart' show Material;
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import 'danmaku_send_model.dart';

/// 弹幕字号, 弹幕类型 and 弹幕颜色 in the keyboard's place: landscape's dark panel with the colours in one row (23),
/// portrait's light one with them in two (38).
class DanmakuStylePanel extends StatelessWidget {
  const DanmakuStylePanel({
    super.key,
    required this.model,
    required this.dark,
    required this.offerBottom,
    required this.isVip,
    required this.onVipOnly,
  });

  final DanmakuSendModel model;
  final bool dark;

  /// 置底 is offered in landscape only; 竖屏's panel has 滚动 and 置顶 (38).
  final bool offerBottom;

  /// The 会员 gradient is the 大会员's; anyone else picking it hears [onVipOnly] and keeps their colour.
  final bool isVip;
  final VoidCallback onVipOnly;

  static const _colourNames = ['白色', '红色', '黄色', '绿色', '蓝色', '品红', '黄绿', '深蓝', '橙色', '紫色', '浅蓝', '橄榄'];

  Color _accent(BuildContext context) => dark ? DanmakuSendTheme.darkAccent : DanmakuSendTheme.colorsOf(context).lightAccent;

  Color _secondary(BuildContext context) => dark ? DanmakuSendTheme.darkSecondary : DanmakuSendTheme.colorsOf(context).lightSecondary;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Material(
      key: const ValueKey('danmaku-style-panel'),
      color: dark ? DanmakuSendTheme.darkArea : DanmakuSendTheme.colorsOf(context).lightArea,
      child: Padding(
        padding: EdgeInsets.only(
          left: DanmakuSendTheme.panelGutter + padding.left,
          right: DanmakuSendTheme.panelGutter + padding.right,
          top: dark ? DanmakuSendTheme.panelTop : DanmakuSendTheme.portraitPanelTop,
        ),
        child: ListenableBuilder(
          listenable: model,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(context, '弹幕字号', [
                for (final size in DanmakuSize.values) _sizeOption(context, size),
              ]),
              _row(context, '弹幕类型', [
                for (final position in DanmakuPosition.values)
                  if (offerBottom || position != DanmakuPosition.bottom) _positionOption(context, position),
              ]),
              ..._colours(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String title) => SizedBox(
    width: DanmakuSendTheme.labelWidth,
    child: Text(
      title,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontFamily: BiliFonts.family,
        fontSize: DanmakuSendTheme.labelFont,
        letterSpacing: DanmakuSendTheme.labelSpacing,
        color: _secondary(context),
      ),
    ),
  );

  Widget _row(BuildContext context, String title, List<Widget> options) => SizedBox(
    height: DanmakuSendTheme.rowHeight,
    child: Row(children: [_label(context, title), ...options]),
  );

  Widget _sizeOption(BuildContext context, DanmakuSize size) {
    final selected = model.style.size == size;
    return _option(context,
      key: ValueKey('danmaku-style-size-${size.name}'),
      title: switch (size) {
        DanmakuSize.normal => '默认',
        DanmakuSize.small => '较小',
      },
      selected: selected,
      onTap: () => model.style = model.style.copyWith(size: size),
      glyph: CustomPaint(
        painter: _SizePainter(small: size == DanmakuSize.small, colour: selected ? _accent(context) : _secondary(context)),
      ),
    );
  }

  Widget _positionOption(BuildContext context, DanmakuPosition position) {
    final selected = model.style.position == position;
    return _option(context,
      key: ValueKey('danmaku-style-position-${position.name}'),
      title: switch (position) {
        DanmakuPosition.scroll => '滚动',
        DanmakuPosition.top => '置顶',
        DanmakuPosition.bottom => '置底',
      },
      selected: selected,
      onTap: () => model.style = model.style.copyWith(position: position),
      glyph: CustomPaint(painter: _ModePainter(position, selected ? _accent(context) : _secondary(context))),
    );
  }

  Widget _option(BuildContext context, {
    required Key key,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    required Widget glyph,
  }) {
    final tint = selected ? _accent(context) : _secondary(context);
    return Semantics(
      key: key,
      button: true,
      selected: selected,
      label: title,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: dark ? DanmakuSendTheme.option : DanmakuSendTheme.portraitOption,
          height: DanmakuSendTheme.optionHeight,
          child: Row(
            children: [
              const SizedBox(width: DanmakuSendTheme.optionIconLead),
              SizedBox(
                width: DanmakuSendTheme.optionIconWidth,
                height: DanmakuSendTheme.optionIconHeight,
                child: CustomPaint(painter: _BoxPainter(tint), child: glyph),
              ),
              const SizedBox(width: DanmakuSendTheme.optionGap),
              Text(
                title,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: BiliFonts.family,
                  fontSize: DanmakuSendTheme.optionFont,
                  letterSpacing: DanmakuSendTheme.labelSpacing,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _colours(BuildContext context) {
    final cell = dark ? DanmakuSendTheme.swatchCell : DanmakuSendTheme.portraitSwatchCell;
    final lead = dark ? DanmakuSendTheme.swatchLead : DanmakuSendTheme.portraitSwatchLead;
    final swatches = [
      _swatch(context, 0, cell, DanmakuSendTheme.rowHeight),
      _vipChip(context, cell, DanmakuSendTheme.rowHeight),
      for (var index = 1; index < DanmakuStyle.colors.length; index++) _swatch(context, index, cell, DanmakuSendTheme.rowHeight),
    ];
    Widget line(Widget leading, List<Widget> cells, double height) => SizedBox(
      height: height,
      child: Row(
        children: [
          leading,
          Transform.translate(offset: Offset(lead, 0), child: Row(children: cells)),
        ],
      ),
    );
    if (dark) return [line(_label(context, '弹幕颜色'), swatches, DanmakuSendTheme.rowHeight)];
    const split = DanmakuSendTheme.portraitSwatchesPerRow;
    return [
      line(_label(context, '弹幕颜色'), swatches.sublist(0, split), DanmakuSendTheme.rowHeight),
      line(
        const SizedBox(width: DanmakuSendTheme.labelWidth),
        [
          for (var index = split - 1; index < DanmakuStyle.colors.length; index++)
            _swatch(context, index, cell, DanmakuSendTheme.secondSwatchRow),
        ],
        DanmakuSendTheme.secondSwatchRow,
      ),
    ];
  }

  Widget _swatch(BuildContext context, int index, double cell, double height) {
    final rgb = DanmakuStyle.colors[index];
    final style = model.style;
    final selected = !style.gradient && style.color == rgb;
    final fill = dark ? DanmakuSendTheme.darkSwatches[index] : Color(0xFF000000 | rgb);
    return _cell(context,
      key: ValueKey('danmaku-style-colour-$index'),
      label: _colourNames[index],
      selected: selected,
      width: cell,
      height: height,
      onTap: () => model.style = style.copyWith(color: rgb, gradient: false),
      child: CustomPaint(
        painter: _SwatchPainter(
          fill,
          ring: dark ? DanmakuSendTheme.darkSwatchRing : DanmakuSendTheme.lightSwatchRing,
          ringWidth: dark ? DanmakuSendTheme.swatchRingWidth : DanmakuSendTheme.lightSwatchRingWidth,
        ),
      ),
    );
  }

  Widget _vipChip(BuildContext context, double cell, double height) {
    final style = model.style;
    void pick() {
      if (isVip) {
        model.style = style.copyWith(gradient: true, color: 0xFFFFFF);
      } else {
        onVipOnly();
      }
    }

    return _cell(context,
      key: const ValueKey('danmaku-style-vip'),
      label: '会员渐变色',
      selected: style.gradient,
      width: cell,
      height: height,
      onTap: pick,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (DanmakuSendTheme.swatchWidth - DanmakuSendTheme.vipWidth) / 2 + DanmakuSendTheme.vipShift,
            top: (DanmakuSendTheme.swatchHeight - DanmakuSendTheme.vipHeight) / 2,
            width: DanmakuSendTheme.vipWidth,
            height: DanmakuSendTheme.vipHeight,
            child: CustomPaint(
              painter: _VipPainter(
                dark ? DanmakuSendTheme.darkVipLeading : DanmakuSendTheme.lightVipLeading,
                dark ? DanmakuSendTheme.darkVipTrailing : DanmakuSendTheme.lightVipTrailing,
              ),
            ),
          ),
          Positioned(
            left: (DanmakuSendTheme.swatchWidth - DanmakuSendTheme.vipBadgeWidth) / 2 +
                DanmakuSendTheme.vipShift +
                DanmakuSendTheme.vipBadgeX,
            top: (DanmakuSendTheme.swatchHeight - DanmakuSendTheme.vipBadgeHeight) / 2 + DanmakuSendTheme.vipBadgeY,
            width: DanmakuSendTheme.vipBadgeWidth,
            height: DanmakuSendTheme.vipBadgeHeight,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: _accent(context),
                shape: const StadiumBorder(
                  side: BorderSide(
                    color: DanmakuSendTheme.vipBadgeBorder,
                    width: DanmakuSendTheme.vipBadgeBorderWidth,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  '会员',
                  maxLines: 1,
                  softWrap: false,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: TextStyle(
                    fontFamily: BiliFonts.family,
                    fontSize: DanmakuSendTheme.vipBadgeFont,
                    height: 1,
                    color: DanmakuSendTheme.tickColour,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A swatch's tap cell, with the tick over its bottom right corner while it is the colour.
  Widget _cell(BuildContext context, {
    required Key key,
    required String label,
    required bool selected,
    required double width,
    required double height,
    required VoidCallback onTap,
    required Widget child,
  }) => Semantics(
    key: key,
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SizedBox(
            width: DanmakuSendTheme.swatchWidth,
            height: DanmakuSendTheme.swatchHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: child),
                if (selected)
                  Positioned(
                    key: const ValueKey('danmaku-style-tick'),
                    right: -DanmakuSendTheme.tickOffset,
                    bottom: -DanmakuSendTheme.tickOffset,
                    width: DanmakuSendTheme.tickSize,
                    height: DanmakuSendTheme.tickSize,
                    child: CustomPaint(painter: _TickPainter(_accent(context))),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The rounded box every option's glyph sits in.
class _BoxPainter extends CustomPainter {
  const _BoxPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(DanmakuSendTheme.optionIconRadius)),
    Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = DanmakuSendTheme.optionIconStroke,
  );

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) => oldDelegate.colour != colour;
}

/// 默认's and 较小's stroked A, left of the middle and standing near the box's foot (23, 38), on the box's 21.1 × 17.1
/// grid.
class _SizePainter extends CustomPainter {
  const _SizePainter({required this.small, required this.colour});

  final bool small;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / DanmakuSendTheme.optionIconWidth;
    final sy = size.height / DanmakuSendTheme.optionIconHeight;
    Offset at(double x, double y) => Offset(x * sx, y * sy);
    final (apex, left, right, barLeft, barRight) = small
        ? (at(6.05, 7.6), at(3.9, 12.5), at(8.2, 12.5), at(4.56, 11.0), at(7.54, 11.0))
        : (at(7.7, 4.3), at(3.9, 13.4), at(11.5, 13.4), at(5.24, 10.2), at(10.16, 10.2));
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(right.dx, right.dy)
        ..moveTo(barLeft.dx, barLeft.dy)
        ..lineTo(barRight.dx, barRight.dy),
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = small ? DanmakuSendTheme.smallSizeGlyphStroke : DanmakuSendTheme.sizeGlyphStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SizePainter oldDelegate) => oldDelegate.small != small || oldDelegate.colour != colour;
}

/// A danmaku's lines in a screen: a dot and a dash on each, two for 滚动, one at the top or the bottom.
class _ModePainter extends CustomPainter {
  const _ModePainter(this.position, this.colour);

  final DanmakuPosition position;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = switch (position) {
      DanmakuPosition.scroll => const [0.28, 0.5],
      DanmakuPosition.top => const [0.25],
      DanmakuPosition.bottom => const [0.72],
    };
    final dot = Paint()..color = colour;
    final dash = Paint()
      ..color = colour
      ..strokeWidth = DanmakuSendTheme.modeStroke
      ..strokeCap = StrokeCap.round;
    for (final row in rows) {
      final y = size.height * row;
      canvas
        ..drawCircle(Offset(size.width * 0.27, y), DanmakuSendTheme.modeDot, dot)
        ..drawLine(Offset(size.width * 0.42, y), Offset(size.width * 0.77, y), dash);
    }
  }

  @override
  bool shouldRepaint(_ModePainter oldDelegate) => oldDelegate.position != position || oldDelegate.colour != colour;
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.fill, {required this.ring, required this.ringWidth});

  final Color fill;
  final Color ring;
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final half = ringWidth / 2;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(half),
          Radius.circular(DanmakuSendTheme.swatchRadius - half),
        ),
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(DanmakuSendTheme.swatchFillInset),
          const Radius.circular(DanmakuSendTheme.swatchFillRadius),
        ),
        Paint()..color = fill,
      );
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.ring != ring || oldDelegate.ringWidth != ringWidth;
}

class _VipPainter extends CustomPainter {
  const _VipPainter(this.leading, this.trailing);

  final Color leading;
  final Color trailing;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(DanmakuSendTheme.swatchRadius)),
        Paint()..shader = LinearGradient(colors: [leading, trailing]).createShader(rect),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            DanmakuSendTheme.vipInsetX,
            DanmakuSendTheme.vipInsetY,
            size.width - DanmakuSendTheme.vipInsetX,
            size.height - DanmakuSendTheme.vipInsetY,
          ),
          const Radius.circular(DanmakuSendTheme.vipInnerRadius),
        ),
        Paint()..color = DanmakuSendTheme.tickColour,
      );
  }

  @override
  bool shouldRepaint(_VipPainter oldDelegate) => oldDelegate.leading != leading || oldDelegate.trailing != trailing;
}

class _TickPainter extends CustomPainter {
  const _TickPainter(this.fill);

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final unit = size.shortestSide / 11;
    canvas
      ..drawCircle(centre, radius, Paint()..color = fill)
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..color = DanmakuSendTheme.tickColour
          ..style = PaintingStyle.stroke
          ..strokeWidth = DanmakuSendTheme.tickRing,
      )
      ..drawPath(
        Path()
          ..moveTo(3.3 * unit, 5.7 * unit)
          ..lineTo(4.9 * unit, 7.2 * unit)
          ..lineTo(7.8 * unit, 4.1 * unit),
        Paint()
          ..color = DanmakuSendTheme.tickColour
          ..style = PaintingStyle.stroke
          ..strokeWidth = DanmakuSendTheme.tickStroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) => oldDelegate.fill != fill;
}
