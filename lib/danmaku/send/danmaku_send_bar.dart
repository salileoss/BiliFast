import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart'
    show AdaptiveTextSelectionToolbar, InputBorder, InputDecoration, Material, MaterialType, TextField, Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../device/orientation.dart';
import '../../shared/theme.dart';
import 'danmaku_send_model.dart';

/// A (with its red dot until first pressed), the field and the send arrow: dark in landscape (22), white on the small
/// player (39) and in 竖屏 (36, 37), whose bar is a sheet of its own with a ⓧ in the field while it has text.
class DanmakuSendBar extends StatefulWidget {
  const DanmakuSendBar({
    super.key,
    required this.model,
    required this.presentation,
    required this.focusNode,
    required this.styleShown,
    required this.onStyle,
    required this.onSend,
    this.closed = false,
  });

  final DanmakuSendModel model;
  final Presentation presentation;
  final FocusNode focusNode;

  /// The style panel is up in the keyboard's place: A turns pink.
  final bool styleShown;
  final VoidCallback onStyle;
  final VoidCallback onSend;

  /// The uploader closed danmaku: the field says so and takes no text.
  final bool closed;

  @override
  State<DanmakuSendBar> createState() => _DanmakuSendBarState();
}

class _DanmakuSendBarState extends State<DanmakuSendBar> {
  late final TextEditingController _text = TextEditingController.fromValue(_valueAtEnd(widget.model.text));

  /// The draft's text as the field last agreed with it. Half-typed pinyin stays in the field alone, so the model
  /// notifying for anything else (sending, style) must not write its older text over the composition.
  late String _synced = widget.model.text;

  static TextEditingValue _valueAtEnd(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  /// iOS's own edit menu, whose Paste skips the "Allow Paste" alert Flutter's toolbar brings up.
  static Widget _editMenu(BuildContext context, EditableTextState state) => SystemContextMenu.isSupported(context)
      ? SystemContextMenu.editableText(editableTextState: state)
      : AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_modelChanged);
    _text.addListener(_textChanged);
  }

  @override
  void didUpdateWidget(DanmakuSendBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.model, widget.model)) {
      oldWidget.model.removeListener(_modelChanged);
      widget.model.addListener(_modelChanged);
      _modelChanged();
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_modelChanged);
    _text.dispose();
    super.dispose();
  }

  void _modelChanged() {
    final text = widget.model.text;
    if (text != _synced) {
      _synced = text;
      if (text != _text.text) _text.value = _valueAtEnd(text);
    }
    if (mounted) setState(() {});
  }

  bool get _composing => _text.value.composing.isValid;

  /// Pinyin still being typed stays out of the draft: cutting it at 100 there would write back a value without its
  /// composing range and drop the candidates. The formatter cuts once the composition ends.
  void _textChanged() {
    if (!_composing && _text.text != widget.model.text) {
      _synced = _text.text;
      widget.model.text = _text.text;
    }
    if (mounted) setState(() {});
  }

  bool get _dark => widget.presentation == Presentation.landscape;

  bool get _vertical => widget.presentation == Presentation.vertical;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final row = Row(
      children: [
        SizedBox(width: _vertical ? DanmakuSendTheme.verticalACell : DanmakuSendTheme.aCell, child: _styleButton()),
        Expanded(child: _field()),
        _sendButton(),
      ],
    );
    final bar = SizedBox(
      key: const ValueKey('danmaku-send-bar'),
      height: DanmakuSendTheme.barHeight,
      child: Padding(
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        child: Material(type: MaterialType.transparency, child: row),
      ),
    );
    if (_dark) return ColoredBox(color: DanmakuSendTheme.darkBar, child: bar);
    if (!_vertical) {
      // The small player's bar is framed by the hairline all round (39).
      return DecoratedBox(
        decoration: BoxDecoration(
          color: DanmakuSendTheme.colorsOf(context).lightBar,
          border: Border.all(color: DanmakuSendTheme.hairline, width: DanmakuSendTheme.hairlineWidth),
        ),
        child: bar,
      );
    }
    final sheet = Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: DanmakuSendTheme.colorsOf(context).lightBar)),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: DanmakuSendTheme.hairlineWidth,
          child: ColoredBox(color: DanmakuSendTheme.hairline),
        ),
        bar,
      ],
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(DanmakuSendTheme.verticalBarRadius)),
      child: sheet,
    );
  }

  Widget _styleButton() {
    final model = widget.model;
    final shown = widget.styleShown;
    final colour = shown
        ? (_dark ? DanmakuSendTheme.darkAccent : DanmakuSendTheme.colorsOf(context).lightAccent)
        : (_dark ? DanmakuSendTheme.darkGlyph : DanmakuSendTheme.colorsOf(context).lightGlyph);
    return Semantics(
      key: const ValueKey('danmaku-send-style'),
      button: true,
      selected: shown,
      label: '弹幕样式',
      onTap: widget.onStyle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onStyle,
        child: Center(
          child: SizedBox(
            width: DanmakuSendTheme.aWidth,
            height: DanmakuSendTheme.aHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: CustomPaint(painter: _APainter(colour))),
                if (!shown && !model.styleHintSeen)
                  Positioned(
                    key: const ValueKey('danmaku-send-hint'),
                    left: (DanmakuSendTheme.aWidth - DanmakuSendTheme.hintDotSize) / 2 + DanmakuSendTheme.hintDotOffset,
                    top: (DanmakuSendTheme.aHeight - DanmakuSendTheme.hintDotSize) / 2 - DanmakuSendTheme.hintDotOffset,
                    width: DanmakuSendTheme.hintDotSize,
                    height: DanmakuSendTheme.hintDotSize,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: DanmakuSendTheme.hintDot, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field() {
    final clear = !_dark && _text.text.isNotEmpty && !widget.closed;
    final pad = _vertical ? DanmakuSendTheme.verticalFieldPad : DanmakuSendTheme.fieldPad;
    final textStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: DanmakuSendTheme.fieldFont,
      color: DanmakuSendTheme.fieldText,
    );
    final hintStyle = _vertical
        ? textStyle.copyWith(
            fontSize: DanmakuSendTheme.verticalPlaceholderFont,
            color: DanmakuSendTheme.verticalPlaceholder,
            letterSpacing: DanmakuSendTheme.placeholderSpacing,
          )
        : textStyle.copyWith(
            color: DanmakuSendTheme.placeholder,
            letterSpacing: DanmakuSendTheme.placeholderSpacing,
          );
    // What the field and its hint draw in (the theme's bodyLarge under ours); the hint is a Text so it takes a strut.
    final field = Theme.of(context).textTheme.bodyLarge!.merge(textStyle);
    final hint = field.merge(hintStyle);
    return Container(
      key: const ValueKey('danmaku-send-field'),
      height: DanmakuSendTheme.fieldHeight,
      decoration: ShapeDecoration(
        color: _dark ? DanmakuSendTheme.darkField : DanmakuSendTheme.colorsOf(context).lightField,
        shape: StadiumBorder(
          side: _vertical
              ? const BorderSide(color: DanmakuSendTheme.hairline, width: DanmakuSendTheme.hairlineWidth)
              : BorderSide.none,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: TextField(
                key: const ValueKey('danmaku-send-input'),
                controller: _text,
                focusNode: widget.focusNode,
                readOnly: widget.closed,
                maxLines: 1,
                textInputAction: TextInputAction.send,
                keyboardAppearance: _dark ? Brightness.dark : BiliPalette.of(context).brightness,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    DanmakuSendModel.maxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
                  ),
                ],
                cursorColor: DanmakuSendTheme.darkAccent,
                cursorHeight: DanmakuSendTheme.cursorHeight,
                cursorWidth: DanmakuSendTheme.cursorWidth,
                cursorRadius: const Radius.circular(DanmakuSendTheme.cursorWidth / 2),
                contextMenuBuilder: _editMenu,
                style: textStyle,
                strutStyle: BiliFonts.strut(field),
                textAlignVertical: TextAlignVertical.center,
                // Sending from the keyboard keeps it up; the bar closes itself once the danmaku went.
                onEditingComplete: () {},
                onSubmitted: (_) {
                  if (!_composing) widget.onSend();
                },
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(left: pad, right: clear ? DanmakuSendTheme.clearCell : pad),
                  hint: Text(
                    widget.closed ? 'UP主已关闭弹幕' : '发个友善的弹幕见证当下',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hint,
                    strutStyle: BiliFonts.strut(hint),
                  ),
                ),
              ),
            ),
          ),
          if (clear)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: DanmakuSendTheme.clearCell,
              child: Semantics(
                key: const ValueKey('danmaku-send-clear'),
                button: true,
                label: '清除',
                onTap: _clear,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clear,
                  child: const Center(
                    child: SizedBox.square(
                      dimension: DanmakuSendTheme.clearSize,
                      child: CustomPaint(painter: _ClearPainter()),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _clear() => _text.value = _valueAtEnd('');

  Widget _sendButton() {
    final model = widget.model;
    // Closed, a press still reaches onSend, which says why nothing goes.
    final ready = model.canSend && !_composing;
    final hasText = model.text.trim().isNotEmpty && !_composing;
    final scale = _vertical ? DanmakuSendTheme.verticalSendScale : 1.0;
    final Color colour;
    var filled = false;
    if (_dark) {
      colour = DanmakuSendTheme.darkGlyph;
    } else if (hasText && !widget.closed) {
      colour = DanmakuSendTheme.sendReady;
      filled = true;
    } else {
      colour = _vertical ? DanmakuSendTheme.verticalSendIdle : DanmakuSendTheme.colorsOf(context).lightGlyph;
    }
    final glyph = model.sending
        ? CupertinoActivityIndicator(color: colour, radius: DanmakuSendTheme.sendSpinnerRadius)
        : SizedBox(
            width: DanmakuSendTheme.sendWidth * scale,
            height: DanmakuSendTheme.sendHeight * scale,
            child: CustomPaint(painter: _PlanePainter(colour, filled: filled, palette: BiliPalette.of(context))),
          );
    return Padding(
      padding: EdgeInsets.only(right: _vertical ? DanmakuSendTheme.verticalSendTrailing : 0),
      child: Semantics(
        key: const ValueKey('danmaku-send-button'),
        button: true,
        enabled: ready,
        label: '发送',
        onTap: ready ? widget.onSend : null,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: ready ? widget.onSend : null,
          child: SizedBox(
            width: _vertical ? DanmakuSendTheme.verticalSendCell : DanmakuSendTheme.sendCell,
            child: Center(child: glyph),
          ),
        ),
      ),
    );
  }
}

/// An A with a line under it, the style button's glyph.
class _APainter extends CustomPainter {
  const _APainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pen = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = DanmakuSendTheme.aStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.03, h * 0.8)
        ..lineTo(w * 0.486, h * 0.02)
        ..lineTo(w * 0.955, h * 0.8)
        ..moveTo(w * 0.2, h * 0.52)
        ..lineTo(w * 0.77, h * 0.52)
        ..moveTo(0, h * 0.99)
        ..lineTo(w, h * 0.99),
      pen,
    );
  }

  @override
  bool shouldRepaint(_APainter oldDelegate) => oldDelegate.colour != colour;
}

/// The paper plane, drawn on an 18 × 17.5 grid: outlined, with its fold line, or filled with the fold cut out of it.
class _PlanePainter extends CustomPainter {
  final BiliPalette palette;
  const _PlanePainter(this.colour, {this.palette = const BiliPalette(Brightness.light), required this.filled});

  final Color colour;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / DanmakuSendTheme.sendWidth;
    final sy = size.height / DanmakuSendTheme.sendHeight;
    Offset at(double x, double y) => Offset(x * sx, y * sy);
    final pen = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = DanmakuSendTheme.sendStroke * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (!filled) {
      final top = at(0.8, 1.0);
      final tip = at(17.2, 8.75);
      final bottom = at(0.8, 16.5);
      final fold = at(1.8, 8.75);
      canvas.drawPath(
        Path()
          ..moveTo(at(1.6, 6.0).dx, at(1.6, 6.0).dy)
          ..lineTo(top.dx, top.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(bottom.dx, bottom.dy)
          ..lineTo(fold.dx, fold.dy)
          ..lineTo(at(10.8, 8.75).dx, at(10.8, 8.75).dy),
        pen,
      );
      return;
    }
    final body = Path()
      ..moveTo(at(0.8, 1.0).dx, at(0.8, 1.0).dy)
      ..lineTo(at(17.2, 8.75).dx, at(17.2, 8.75).dy)
      ..lineTo(at(0.8, 16.5).dx, at(0.8, 16.5).dy)
      ..lineTo(at(2.8, 8.75).dx, at(2.8, 8.75).dy)
      ..close();
    canvas
      ..drawPath(body, Paint()..color = colour)
      ..drawPath(body, pen)
      ..drawLine(
        at(2.6, 8.95),
        at(10.8, 8.55),
        Paint()
          ..color = DanmakuSendThemeColors(palette).lightBar
          ..strokeWidth = sx
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_PlanePainter oldDelegate) => (oldDelegate.colour != colour || oldDelegate.filled != filled) || oldDelegate.palette.brightness != palette.brightness;
}

class _ClearPainter extends CustomPainter {
  const _ClearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    canvas.drawCircle(centre, size.shortestSide / 2, Paint()..color = DanmakuSendTheme.clearFill);
    final pen = Paint()
      ..color = DanmakuSendTheme.clearGlyph
      ..strokeWidth = DanmakuSendTheme.clearStroke
      ..strokeCap = StrokeCap.round;
    const arm = DanmakuSendTheme.clearArm;
    canvas
      ..drawLine(centre + const Offset(-arm, -arm), centre + const Offset(arm, arm), pen)
      ..drawLine(centre + const Offset(arm, -arm), centre + const Offset(-arm, arm), pen);
  }

  @override
  bool shouldRepaint(_ClearPainter oldDelegate) => false;
}
