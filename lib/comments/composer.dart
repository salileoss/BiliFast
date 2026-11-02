import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart'
    show AdaptiveTextSelectionToolbar, InputBorder, InputDecoration, Material, MaterialType, TextField;
import 'package:flutter/widgets.dart';

import '../shared/theme.dart';
import '../shared/toast.dart';
import 'composer_model.dart';
import 'emote_panel.dart';
import 'field_strut.dart';
import 'mention_picker.dart';
import 'picture_attach.dart';

/// The composer (14): a white sheet over the dimmed page that rides on the keyboard, with the field, ⤢ to make it
/// tall, 转到动态, the keyboard / emote switch, @, ⊕ and 发布, and the emote panel in the keyboard's place.
class Composer extends StatefulWidget {
  const Composer({super.key, required this.model, required this.onClose, this.pick = pickPictures, this.top});

  final ComposerModel model;

  /// A tap on the dimmed page, or a successful post.
  final VoidCallback onClose;

  /// The small player's live bottom edge, where the @ picker's box starts; the full 16:9 player's when null.
  final double? top;

  /// ⊕'s picker; tests stand in for the photo library.
  final Future<PicturePick> Function({required int limit}) pick;

  /// Forgets the keyboard's height, which the emote panel takes from one composer to the next.
  @visibleForTesting
  static void debugForgetKeyboard() => _ComposerState._keyboard = null;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> with SingleTickerProviderStateMixin {
  /// The keyboard's height the last time it was up, which the emote panel takes so the sheet stays put.
  static double? _keyboard;

  late final TextEditingController _text = TextEditingController.fromValue(_valueAtEnd(widget.model.text));
  final _focus = FocusNode();
  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: ComposerTheme.rise,
    reverseDuration: ComposerTheme.fall,
  );
  late final CurvedAnimation _motion = CurvedAnimation(
    parent: _shown,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool _expanded = false;
  bool _closing = false;
  bool _mentioning = false;
  bool _typingBeforeMention = false;
  double _lastInset = 0;
  Timer? _keyboardWait;

  List<EmotePackage>? _packages;
  bool _packagesFailed = false;
  int _packageLoads = 0;

  static TextEditingValue _valueAtEnd(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  /// iOS's own edit menu: its Paste reads the clipboard without the "Allow Paste" alert that Flutter's toolbar
  /// brings up.
  static Widget _editMenu(BuildContext context, EditableTextState state) => SystemContextMenu.isSupported(context)
      ? SystemContextMenu.editableText(editableTextState: state)
      : AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_modelChanged);
    _text.addListener(_textChanged);
    _focus.addListener(_focusChanged);
    unawaited(_loadPackages());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _shown
      ..duration = still ? Duration.zero : ComposerTheme.rise
      ..reverseDuration = still ? Duration.zero : ComposerTheme.fall;
    // Started here rather than in initState, which can't read Reduce Motion yet.
    if (_shown.isDismissed && !_closing) _shown.forward();
  }

  @override
  void didUpdateWidget(Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.model, widget.model)) {
      oldWidget.model.removeListener(_modelChanged);
      widget.model.addListener(_modelChanged);
      _modelChanged();
      unawaited(_loadPackages());
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_modelChanged);
    _keyboardWait?.cancel();
    _text.dispose();
    _focus.dispose();
    _motion.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _modelChanged() {
    final text = widget.model.text;
    if (text != _text.text) _text.value = _valueAtEnd(text);
    if (mounted) setState(() {});
  }

  void _textChanged() {
    if (_text.text != widget.model.text) widget.model.text = _text.text;
  }

  void _focusChanged() {
    if (_focus.hasFocus && widget.model.showingEmotes) _waitForKeyboard();
  }

  /// The panel stays until the keyboard has risen over it (see [_trackKeyboard]), or gives way after a while: a
  /// hardware keyboard shows no software one.
  void _waitForKeyboard() {
    _keyboardWait?.cancel();
    _keyboardWait = Timer(ComposerTheme.keyboardWait, _leaveEmotes);
  }

  void _leaveEmotes() {
    if (!mounted || !_focus.hasFocus || !widget.model.showingEmotes) return;
    _keyboardWait?.cancel();
    widget.model.showingEmotes = false;
  }

  void _trackKeyboard(double inset, double panel) {
    final model = widget.model;
    if (inset > 0 && _focus.hasFocus) {
      // Kept while it rises or rests; a keyboard on its way down has no height worth keeping.
      if (!model.showingEmotes && inset >= _lastInset) _keyboard = inset;
      if (model.showingEmotes && inset >= panel - 0.5) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _leaveEmotes());
      }
    }
    _lastInset = inset;
  }

  /// The small player's bottom edge: the @ picker sits below it, as the page's sheets do.
  double _playerBottom(BuildContext context) =>
      widget.top ?? MediaQuery.viewPaddingOf(context).top + MediaQuery.sizeOf(context).width / BiliMetrics.videoAspect;

  double _panelHeight(double safeBottom) {
    final least = ComposerTheme.tabHeight + safeBottom + ComposerTheme.sectionHeight + ComposerTheme.row;
    return math.max(least, _keyboard ?? ComposerTheme.panelHeight + ComposerTheme.tabHeight + safeBottom);
  }

  Future<void> _loadPackages() async {
    final load = ++_packageLoads;
    if (_packages == null && _packagesFailed) setState(() => _packagesFailed = false);
    try {
      final packages = await widget.model.emotePackages();
      if (!mounted || load != _packageLoads) return;
      setState(() {
        _packages = packages;
        _packagesFailed = packages.isEmpty;
      });
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'emote packages failed', {'error': '${error.runtimeType}'});
      if (!mounted || load != _packageLoads) return;
      setState(() {
        _packages = null;
        _packagesFailed = true;
      });
    }
  }

  void _toggleEmotes() {
    final model = widget.model;
    if (model.showingEmotes) {
      _focus.requestFocus();
      return;
    }
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 0) _keyboard = inset;
    model.showingEmotes = true;
    _focus.unfocus();
  }

  /// Replaces the selection, or puts [insertion] at the cursor; at the end when the field has never had one.
  void _insert(String insertion) {
    final value = _text.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    _text.value = TextEditingValue(
      text: value.text.replaceRange(start, end, insertion),
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
  }

  void _pickEmote(Emote emote) {
    _insert(emote.token);
    widget.model.usedEmote(emote);
  }

  void _openMentions() {
    _typingBeforeMention = !widget.model.showingEmotes;
    _focus.unfocus();
    setState(() => _mentioning = true);
  }

  void _closeMentions() {
    if (!_mentioning) return;
    setState(() => _mentioning = false);
    if (_typingBeforeMention) _focus.requestFocus();
  }

  void _mentionPicked(MentionCandidate who) {
    _insert('@${who.name} ');
    widget.model.mentioned(who);
    _closeMentions();
  }

  Future<void> _addPictures() async {
    final room = ComposerModel.maxPictures - widget.model.pictures.length;
    if (room <= 0) {
      showToast(context, '最多添加${ComposerModel.maxPictures}张图片');
      return;
    }
    final picked = await widget.pick(limit: room);
    if (!mounted) return;
    if (picked.pictures.isNotEmpty) widget.model.addPictures(picked.pictures);
    switch (picked.failure) {
      case PickFailure.noAccess:
        showToast(context, '无法访问照片，请在设置中允许BiliFast访问照片');
      case PickFailure.failed:
        showToast(context, picked.pictures.isEmpty ? '图片读取失败，请重试' : '部分图片读取失败');
      case null:
    }
  }

  Future<void> _publish() async {
    final model = widget.model;
    if (!model.canPost || model.posting) return;
    final posted = await model.post();
    if (posted && mounted) _close();
  }

  void _close() {
    // Closing mid-post would let a reopened composer post the same text again.
    if (widget.model.posting || _closing) return;
    _closing = true;
    _keyboardWait?.cancel();
    _focus.unfocus();
    _shown.reverse().whenCompleteOrCancel(() {
      if (mounted) widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final panel = _panelHeight(safeBottom);
    _trackKeyboard(inset, panel);
    final pictures = model.pictures;
    return BlockSemantics(
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _motion,
              child: Semantics(
                button: true,
                label: '关闭',
                onTap: _close,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('composer-dim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: const ColoredBox(color: ComposerTheme.dim),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _motion.drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
              child: DecoratedBox(
                key: const ValueKey('composer-sheet'),
                decoration: BoxDecoration(
                  color: ComposerTheme.colorsOf(context).sheet,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(ComposerTheme.sheetRadius)),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _editor(model),
                      if (pictures.isNotEmpty) AttachedPictures(pictures: pictures, onRemove: model.removePicture),
                      _toolbar(model),
                      if (model.showingEmotes)
                        EmotePanel(
                          packages: _packages,
                          recent: model.recent,
                          height: panel,
                          bottomInset: safeBottom,
                          onPick: _pickEmote,
                          onRetry: _packagesFailed ? () => unawaited(_loadPackages()) : null,
                        )
                      else
                        SizedBox(key: const ValueKey('composer-keyboard'), height: math.max(inset, safeBottom)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_mentioning)
            Positioned(
              left: 0,
              right: 0,
              top: math.min(_playerBottom(context), MediaQuery.sizeOf(context).height - inset),
              bottom: inset,
              child: BlockSemantics(
                child: MediaQuery(
                  // The box already ends at the keyboard.
                  data: MediaQuery.of(context)
                      .removeViewInsets(removeBottom: true)
                      .removePadding(removeBottom: inset > 0),
                  child: MentionPicker(search: model.searchMentions, onPick: _mentionPicked, onClose: _closeMentions),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _editor(ComposerModel model) {
    final textStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: ComposerTheme.editorFont,
      color: ComposerTheme.colorsOf(context).text,
    );
    final hintStyle = textStyle.copyWith(color: ComposerTheme.colorsOf(context).placeholder);
    final strut = fieldStrut(context, textStyle);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : ComposerTheme.expand,
      curve: Curves.easeOutCubic,
      height: _expanded ? ComposerTheme.expandedEditorHeight : ComposerTheme.editorHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: TextField(
              key: const ValueKey('composer-field'),
              controller: _text,
              focusNode: _focus,
              autofocus: !model.showingEmotes,
              expands: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              keyboardAppearance: BiliPalette.of(context).brightness,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: ComposerTheme.colorsOf(context).accent,
              contextMenuBuilder: _editMenu,
              style: textStyle,
              strutStyle: strut,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(
                  left: ComposerTheme.editorLeading,
                  top: ComposerTheme.editorTop,
                  right: ComposerTheme.editorTrailing,
                ),
                // A "回复 name :" hint sits on the typed text's strut, which hintText's own Text can't take.
                hintText: strut == null ? model.placeholder : null,
                hint: strut == null
                    ? null
                    : Text(
                        model.placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: fieldStyle(context, hintStyle),
                        strutStyle: strut,
                      ),
                hintMaxLines: 1,
                hintStyle: hintStyle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            width: ComposerTheme.editorTrailing,
            height: ComposerTheme.expandCellHeight,
            child: _button(
              key: const ValueKey('composer-expand'),
              label: _expanded ? '收起' : '展开',
              onTap: () => setState(() => _expanded = !_expanded),
              child: _Glyph(
                _expanded ? _GlyphKind.collapse : _GlyphKind.expand,
                width: ComposerTheme.expandIcon,
                height: ComposerTheme.expandIcon,
                color: ComposerTheme.colorsOf(context).tool,
                stroke: ComposerTheme.expandStroke,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(ComposerModel model) {
    final emotes = model.showingEmotes;
    return SizedBox(
      height: ComposerTheme.toolbarHeight,
      child: Row(
        children: [
          _sync(model),
          _tool(
            key: const ValueKey('composer-emotes'),
            label: emotes ? '键盘' : '表情',
            onTap: _toggleEmotes,
            child: emotes
                ? _Glyph(
                    _GlyphKind.keyboard,
                    width: ComposerTheme.toolIcon,
                    height: ComposerTheme.keyboardIconHeight,
                    color: ComposerTheme.colorsOf(context).accent,
                    stroke: ComposerTheme.toolStroke,
                  )
                : _Glyph(_GlyphKind.face, color: ComposerTheme.colorsOf(context).tool, stroke: ComposerTheme.toolStroke),
          ),
          _tool(
            key: const ValueKey('composer-mention'),
            label: '提及好友',
            onTap: _openMentions,
            child: _Glyph(_GlyphKind.at, color: ComposerTheme.colorsOf(context).tool, stroke: ComposerTheme.toolStroke),
          ),
          _tool(
            key: const ValueKey('composer-pictures'),
            label: '添加图片',
            onTap: () => unawaited(_addPictures()),
            child: _Glyph(_GlyphKind.plus, color: ComposerTheme.colorsOf(context).tool, stroke: ComposerTheme.toolStroke),
          ),
          const Spacer(),
          _publishButton(model),
        ],
      ),
    );
  }

  Widget _sync(ComposerModel model) {
    final on = model.syncToDynamic;
    void toggle() => model.syncToDynamic = !model.syncToDynamic;
    return Semantics(
      key: const ValueKey('composer-sync'),
      button: true,
      checked: on,
      label: '转到动态',
      onTap: toggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: SizedBox(
          width: ComposerTheme.syncWidth,
          height: ComposerTheme.toolbarHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: ComposerTheme.syncLeading),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: ComposerTheme.syncRingSize,
                  child: CustomPaint(painter: _SyncRingPainter(on: on, palette: BiliPalette.of(context))),
                ),
                const SizedBox(width: ComposerTheme.syncGap),
                Text(
                  '转到动态',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: BiliFonts.family,
                    fontSize: ComposerTheme.syncFont,
                    color: ComposerTheme.colorsOf(context).syncText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tool({required Key key, required String label, required VoidCallback onTap, required Widget child}) =>
      SizedBox(
        width: ComposerTheme.toolCell,
        height: ComposerTheme.toolbarHeight,
        child: _button(key: key, label: label, onTap: onTap, child: child),
      );

  Widget _button({required Key key, required String label, required VoidCallback onTap, required Widget child}) =>
      Semantics(
        key: key,
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(child: child),
        ),
      );

  Widget _publishButton(ComposerModel model) {
    final posting = model.posting;
    final enabled = model.canPost && !posting;
    void publish() => unawaited(_publish());
    return Semantics(
      key: const ValueKey('composer-publish'),
      button: true,
      enabled: enabled,
      label: '发布',
      onTap: enabled ? publish : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? publish : null,
        child: SizedBox(
          height: ComposerTheme.toolbarHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: ComposerTheme.publishTrailing, right: ComposerTheme.publishTrailing),
            child: Center(
              child: Container(
                width: ComposerTheme.publishWidth,
                height: ComposerTheme.publishHeight,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: model.canPost || posting ? ComposerTheme.colorsOf(context).accent : ComposerTheme.colorsOf(context).accentFaded,
                ),
                child: posting
                    ? const CupertinoActivityIndicator(
                        color: ComposerTheme.publishText,
                        radius: ComposerTheme.publishSpinnerRadius,
                      )
                    : Text(
                        '发布',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: BiliFonts.family,
                          fontSize: ComposerTheme.publishFont,
                          color: ComposerTheme.publishText,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncRingPainter extends CustomPainter {
  final BiliPalette palette;
  const _SyncRingPainter({this.palette = const BiliPalette(Brightness.light), required this.on});

  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (!on) {
      canvas.drawCircle(
        centre,
        radius - ComposerTheme.syncRingStroke / 2,
        Paint()
          ..color = ComposerThemeColors(palette).syncRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = ComposerTheme.syncRingStroke,
      );
      return;
    }
    canvas.drawCircle(centre, radius, Paint()..color = ComposerThemeColors(palette).accent);
    final unit = size.shortestSide / 10;
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx - 2.6 * unit, centre.dy + 0.1 * unit)
        ..lineTo(centre.dx - 0.8 * unit, centre.dy + 1.9 * unit)
        ..lineTo(centre.dx + 2.7 * unit, centre.dy - 1.8 * unit),
      Paint()
        ..color = ComposerTheme.publishText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * unit
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SyncRingPainter oldDelegate) => (oldDelegate.on != on) || oldDelegate.palette.brightness != palette.brightness;
}

enum _GlyphKind { face, keyboard, at, plus, expand, collapse }

/// The toolbar's and ⤢'s line icons, drawn to 14's: round-capped strokes of one width.
class _Glyph extends StatelessWidget {
  const _Glyph(
    this.kind, {
    this.width = ComposerTheme.toolIcon,
    this.height = ComposerTheme.toolIcon,
    required this.color,
    required this.stroke,
  });

  final _GlyphKind kind;
  final double width;
  final double height;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(painter: _GlyphPainter(kind, color, stroke)),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.kind, this.color, this.stroke);

  final _GlyphKind kind;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final half = stroke / 2;
    final centre = size.center(Offset.zero);
    // The keyboard, @ and ⊕ are drawn on a 20-unit grid across the icon's width, from 14's 60 px icons.
    final unit = size.width / 20;
    Offset at(double x, double y) => centre + Offset(x * unit, y * unit);
    switch (kind) {
      case _GlyphKind.face:
        // BiliNative's `EmoteFace`: a circle with > < eyes and a wide smile.
        final side = size.shortestSide;
        final u = side / 20;
        final origin = centre - Offset(side / 2, side / 2);
        final path = Path();
        void move(double x, double y) => path.moveTo(origin.dx + x * u, origin.dy + y * u);
        void line(double x, double y) => path.lineTo(origin.dx + x * u, origin.dy + y * u);
        void curve(double cx, double cy, double x, double y) =>
            path.quadraticBezierTo(origin.dx + cx * u, origin.dy + cy * u, origin.dx + x * u, origin.dy + y * u);
        move(5.6, 6.9);
        line(8.0, 8.4);
        line(5.6, 9.9);
        move(14.4, 6.9);
        line(12.0, 8.4);
        line(14.4, 9.9);
        move(6.6, 12.2);
        curve(8.2, 15.6, 10, 12.6);
        curve(11.8, 15.6, 13.4, 12.2);
        canvas.drawCircle(centre, side / 2 - half, pen);
        canvas.drawPath(path, pen);
      case _GlyphKind.keyboard:
        canvas.drawRRect(
          RRect.fromLTRBR(half, half, size.width - half, size.height - half, Radius.circular(4 * unit)),
          pen,
        );
        final dot = Paint()..color = color;
        for (final x in const [-4.6, -1.53, 1.53, 4.6]) {
          for (final y in const [-2.9, 0.2]) {
            canvas.drawCircle(at(x, y), 0.83 * unit, dot);
          }
        }
        canvas.drawLine(at(-4.8, 3.3), at(4.8, 3.3), pen..strokeWidth = 1.4 * unit);
      case _GlyphKind.at:
        final outer = size.shortestSide / 2 - half;
        final ring = at(0.2, -0.1);
        canvas.drawCircle(ring, 4.2 * unit, pen);
        final stem = ring + Offset(4.2 * unit, 0);
        canvas.drawPath(
          Path()
            ..moveTo(stem.dx, stem.dy)
            ..lineTo(stem.dx, at(0, 1.5).dy)
            ..cubicTo(stem.dx, at(0, 4.6).dy, centre.dx + outer, at(0, 4.6).dy, centre.dx + outer, centre.dy)
            ..arcTo(Rect.fromCircle(center: centre, radius: outer), 0, -302 * math.pi / 180, false),
          pen,
        );
      case _GlyphKind.plus:
        canvas.drawCircle(centre, size.shortestSide / 2 - half, pen);
        canvas.drawLine(at(-4, 0), at(4, 0), pen);
        canvas.drawLine(at(0, -4), at(0, 4), pen);
      case _GlyphKind.expand || _GlyphKind.collapse:
        final side = size.shortestSide;
        final u = side / 10.67;
        final near = half;
        final far = side - half;
        final mid = side / 2;
        final path = Path();
        if (kind == _GlyphKind.expand) {
          final arm = 4.1 * u;
          path
            ..moveTo(far - arm, near)
            ..lineTo(far, near)
            ..lineTo(far, near + arm)
            ..moveTo(far, near)
            ..lineTo(mid + u, mid - u)
            ..moveTo(near, far - arm)
            ..lineTo(near, far)
            ..lineTo(near + arm, far)
            ..moveTo(near, far)
            ..lineTo(mid - u, mid + u);
        } else {
          final arm = 3.6 * u;
          final inner = 0.9 * u;
          path
            ..moveTo(mid + inner, mid - inner - arm)
            ..lineTo(mid + inner, mid - inner)
            ..lineTo(mid + inner + arm, mid - inner)
            ..moveTo(mid + inner, mid - inner)
            ..lineTo(far, near)
            ..moveTo(mid - inner, mid + inner + arm)
            ..lineTo(mid - inner, mid + inner)
            ..lineTo(mid - inner - arm, mid + inner)
            ..moveTo(mid - inner, mid + inner)
            ..lineTo(near, far);
        }
        canvas.drawPath(path.shift(centre - Offset(mid, mid)), pen);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color || oldDelegate.stroke != stroke;
}
