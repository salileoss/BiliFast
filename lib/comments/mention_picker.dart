import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart' show Icons, InputBorder, InputDecoration, Material, MaterialType, TextField;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../player_ui/panels/episodes_panel.dart' show EpisodesSheetHeader;
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import 'field_strut.dart';

/// The composer's @: the people the viewer follows, searchable by name; a tap picks one. A light sheet that fills the
/// box it's given, header and search field on top.
class MentionPicker extends StatefulWidget {
  const MentionPicker({super.key, required this.search, required this.onPick, required this.onClose});

  /// An empty query lists the most recently followed.
  final Future<List<MentionCandidate>> Function(String query) search;
  final ValueChanged<MentionCandidate> onPick;
  final VoidCallback onClose;

  @override
  State<MentionPicker> createState() => _MentionPickerState();
}

class _MentionPickerState extends State<MentionPicker> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  /// Counts searches, so an answer that arrives after a newer search started is dropped.
  var _generation = 0;
  var _loading = true;
  var _failed = false;

  /// What the shown list answers.
  var _query = '';
  List<MentionCandidate> _found = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_run(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    _debounce = Timer(MentionTheme.debounce, () => unawaited(_run(text.trim())));
  }

  void _clear() {
    _field.clear();
    unawaited(_run(''));
  }

  Future<void> _run(String query) async {
    _debounce?.cancel();
    final generation = ++_generation;
    if (!_loading || _failed) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final found = await widget.search(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _query = query;
        _found = found;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      Logger.shared.warn(LogCategory.ui, 'mention search failed', {'error': '$error'});
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: MentionTheme.nameText,
      color: BiliColors.colorsOf(context).text,
      decoration: TextDecoration.none,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: BiliColors.colorsOf(context).card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(BiliMetrics.sheetRadius)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EpisodesSheetHeader(title: '选择好友', close: widget.onClose),
          Padding(
            padding: const EdgeInsets.fromLTRB(MentionTheme.gutter, 0, MentionTheme.gutter, MentionTheme.fieldBottom),
            child: _searchField(),
          ),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  TextStyle get _fieldText =>
      TextStyle(fontFamily: BiliFonts.family, fontSize: MentionTheme.fieldText, color: BiliColors.colorsOf(context).text);

  Widget _searchField() => Container(
    height: MentionTheme.fieldHeight,
    padding: const EdgeInsets.symmetric(horizontal: MentionTheme.fieldPadX),
    decoration: BoxDecoration(
      color: MentionTheme.colorsOf(context).fieldFill,
      borderRadius: BorderRadius.circular(MentionTheme.fieldHeight / 2),
    ),
    child: Row(
      children: [
        SizedBox.square(
          dimension: MentionTheme.fieldIcon,
          // A search over a list already shown spins here instead of blanking the list.
          child: _loading && _found.isNotEmpty && !_failed
              ? const CupertinoActivityIndicator(
                  key: ValueKey('mention-searching'),
                  radius: MentionTheme.fieldSpinnerRadius,
                )
              : Icon(Icons.search, size: MentionTheme.fieldIcon, color: BiliColors.colorsOf(context).secondaryText),
        ),
        const SizedBox(width: MentionTheme.fieldIconGap),
        Expanded(
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              key: const ValueKey('mention-search'),
              controller: _field,
              focusNode: _focus,
              onChanged: _typed,
              onSubmitted: (text) => unawaited(_run(text.trim())),
              textInputAction: TextInputAction.search,
              cursorColor: BiliColors.colorsOf(context).pink,
              style: _fieldText,
              strutStyle: fieldStrut(context, _fieldText),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '搜索我的关注',
                hintStyle: TextStyle(
                  fontFamily: BiliFonts.family,
                  fontSize: MentionTheme.fieldText,
                  color: BiliColors.colorsOf(context).secondaryText,
                ),
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _field,
          builder: (context, _) => _field.text.isEmpty
              ? const SizedBox.shrink()
              : Semantics(
                  container: true,
                  button: true,
                  label: '清除',
                  onTap: _clear,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const ValueKey('mention-clear'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _clear,
                    child: SizedBox(
                      width: MentionTheme.fieldHeight,
                      height: MentionTheme.fieldHeight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: MentionTheme.clearSize,
                          height: MentionTheme.clearSize,
                          decoration: BoxDecoration(color: MentionTheme.colorsOf(context).clearFill, shape: BoxShape.circle),
                          child: Icon(
                            Icons.close,
                            size: MentionTheme.clearGlyph,
                            color: MentionTheme.colorsOf(context).clearGlyphColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _body() {
    final Widget child;
    if (_failed) {
      child = _state(
        key: const ValueKey('mention-failed'),
        text: '加载失败，点击重试',
        onTap: () => unawaited(_run(_field.text.trim())),
      );
    } else if (_loading && _found.isEmpty) {
      child = const Padding(
        key: ValueKey('mention-loading'),
        padding: EdgeInsets.only(top: MentionTheme.statePad),
        child: Align(
          alignment: Alignment.topCenter,
          child: CupertinoActivityIndicator(radius: MentionTheme.spinnerRadius),
        ),
      );
    } else if (_found.isEmpty) {
      child = _state(key: const ValueKey('mention-empty'), text: _query.isEmpty ? '还没有关注任何人' : '没有找到相关的人');
    } else {
      child = _list();
    }
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 150),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      child: child,
    );
  }

  Widget _state({required Key key, required String text, VoidCallback? onTap}) {
    final label = Padding(
      padding: const EdgeInsets.all(MentionTheme.statePad),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: BiliFonts.family,
          fontSize: MentionTheme.stateText,
          color: BiliColors.colorsOf(context).secondaryText,
        ),
      ),
    );
    if (onTap == null) return Align(key: key, alignment: Alignment.topCenter, child: label);
    return Align(
      key: key,
      alignment: Alignment.topCenter,
      child: Semantics(
        container: true,
        button: true,
        label: text,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: label),
      ),
    );
  }

  Widget _list() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView.builder(
      key: const ValueKey('mention-list'),
      padding: EdgeInsets.only(bottom: bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _found.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            height: MentionTheme.sectionHeight,
            padding: const EdgeInsets.symmetric(horizontal: MentionTheme.gutter),
            alignment: Alignment.centerLeft,
            child: Text(
              _query.isEmpty ? '最近关注' : '搜索结果',
              style: TextStyle(
                fontFamily: BiliFonts.family,
                fontSize: MentionTheme.sectionText,
                color: MentionTheme.colorsOf(context).sectionColour,
              ),
            ),
          );
        }
        final who = _found[index - 1];
        return _CandidateRow(
          key: ValueKey('mention-${who.mid}'),
          who: who,
          query: _query,
          onTap: () => widget.onPick(who),
        );
      },
    );
  }
}

class _CandidateRow extends StatefulWidget {
  const _CandidateRow({super.key, required this.who, required this.query, required this.onTap});

  final MentionCandidate who;
  final String query;
  final VoidCallback onTap;

  @override
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  var _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: widget.who.name,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.onTap,
      child: Container(
        height: MentionTheme.rowHeight,
        color: _pressed ? BiliColors.colorsOf(context).pressedFill : null,
        padding: const EdgeInsets.symmetric(horizontal: MentionTheme.gutter),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: MentionTheme.avatar,
                child: RemoteImage.avatar(widget.who.face, size: const Size.square(MentionTheme.avatar)),
              ),
            ),
            const SizedBox(width: MentionTheme.avatarGap),
            Expanded(
              child: Text.rich(
                TextSpan(children: _highlighted(context, widget.who.name, widget.query)),
                strutStyle: BiliFonts.strutOf(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// [name] with each case-insensitive occurrence of [query] in pink.
  static List<TextSpan> _highlighted(BuildContext context, String name, String query) {
    final lower = name.toLowerCase();
    final needle = query.toLowerCase();
    // Lowercasing can change a string's length, and then the offsets no longer line up with the name.
    if (needle.isEmpty || lower.length != name.length) return [TextSpan(text: name)];
    final spans = <TextSpan>[];
    var from = 0;
    while (true) {
      final at = lower.indexOf(needle, from);
      if (at < 0) break;
      if (at > from) spans.add(TextSpan(text: name.substring(from, at)));
      spans.add(
        TextSpan(
          text: name.substring(at, at + needle.length),
          style: TextStyle(color: MentionTheme.colorsOf(context).match),
        ),
      );
      from = at + needle.length;
    }
    if (from < name.length) spans.add(TextSpan(text: name.substring(from)));
    return spans;
  }
}
