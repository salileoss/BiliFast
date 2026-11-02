import 'package:flutter/material.dart';

import '../../search/search_glyphs.dart';
import '../../shared/theme.dart';
import '../../skin/skin.dart';
import 'offline_glyphs.dart';
import 'offline_text.dart';

typedef _T = OfflineListTheme;

/// The bar's colours: the equipped 装扮's second-page colour and text colour (143's green is KaiC's skin's
/// `color_second_page`), else white. The status bar goes by the fill.
final class OfflineBarLook {
  const OfflineBarLook({required this.fill, required this.ink, required this.lightStatus});

  static const stock = OfflineBarLook(fill: _T.bar, ink: _T.barInk, lightStatus: false);

  factory OfflineBarLook.of(Skin? skin, {BuildContext? context}) {
    final colors = context == null ? null : _T.colorsOf(context);
    final page = skin?.equip.colors.colorSecondPage;
    if (skin == null || skin.equip.primaryOnly || page == null) {
      return context == null ? stock : OfflineBarLook(
        fill: colors!.bar,
        ink: colors.barInk,
        lightStatus: BiliPalette.of(context).isDark,
      );
    }
    final fill = Color(page);
    return OfflineBarLook(
      fill: fill,
      ink: skin.color ?? (skin.lightText ? _T.barLightInk : colors?.barInk ?? _T.barInk),
      lightStatus: SkinStatusBar.whiteOverColor(fill),
    );
  }

  final Color fill;
  final Color ink;
  final bool lightStatus;
}

/// ‹, the title and the actions on the right: 🔍 and ☰; in edit mode ‹ goes and only 完成 is on the right (149).
class OfflineBar extends StatelessWidget {
  const OfflineBar({
    super.key,
    required this.look,
    required this.title,
    this.onBack,
    this.onSearch,
    this.onEdit,
    this.onDone,
  });

  final OfflineBarLook look;
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onEdit;

  /// Edit mode: 完成 alone on the right.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final titleStyle = offlineStyle(_T.titleText, look.ink, line: _T.titleLine, weight: _T.titleWeight);
    final onDone = this.onDone;
    final onBack = this.onBack;
    final icons = <Widget>[
      if (onDone == null && onSearch != null)
        _Icon(
          key: const ValueKey('offline-search'),
          label: '搜索',
          onTap: onSearch!,
          painter: OfflineSearchPainter(look.ink),
        ),
      if (onDone == null && onEdit != null)
        _Icon(key: const ValueKey('offline-edit'), label: '编辑', onTap: onEdit!, painter: OfflineEditPainter(look.ink)),
    ];
    return ColoredBox(
      key: const ValueKey('offline-bar'),
      color: look.fill,
      child: SizedBox(
        height: top + _T.barRow,
        child: Stack(
          children: [
            Positioned(
              left: _T.iconTarget * 2 + _T.iconLastCentre,
              right: _T.iconTarget * 2 + _T.iconLastCentre,
              top: top,
              height: _T.barRow,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, _T.titleDrop),
                  child: offlineLine(
                    title,
                    titleStyle,
                    key: const ValueKey('offline-bar-title'),
                    align: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (onBack != null && onDone == null)
              Positioned(
                left: 0,
                top: top,
                width: _T.backTarget,
                height: _T.barRow,
                child: Semantics(
                  button: true,
                  label: '返回',
                  onTap: onBack,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const ValueKey('offline-back'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack,
                    child: CustomPaint(painter: OfflineBackPainter(look.ink)),
                  ),
                ),
              ),
            for (final (index, icon) in icons.reversed.indexed)
              Positioned(
                right: _T.iconLastCentre - _T.iconTarget / 2 + index * _T.iconTarget,
                top: top,
                width: _T.iconTarget,
                height: _T.barRow,
                child: icon,
              ),
            if (onDone != null)
              Positioned(
                right: 0,
                top: top,
                height: _T.barRow,
                child: _Words(
                  key: const ValueKey('offline-done'),
                  label: '完成',
                  color: look.ink,
                  right: _T.doneRight,
                  onTap: onDone,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({super.key, required this.label, required this.onTap, required this.painter});

  final String label;
  final VoidCallback onTap;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(painter: painter),
    ),
  );
}

/// 完成 or 取消: 14 pt words ending [right] from the edge.
class _Words extends StatelessWidget {
  const _Words({super.key, required this.label, required this.color, required this.right, required this.onTap});

  final String label;
  final Color color;
  final double right;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = offlineStyle(_T.actionText, color, line: _T.barRow);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(left: _T.textRight, right: right),
          child: Center(widthFactor: 1, child: offlineLine(label, style)),
        ),
      ),
    );
  }
}

/// The bar while searching (151): 搜索已下载的内容 and 取消.
class OfflineSearchBar extends StatelessWidget {
  const OfflineSearchBar({
    super.key,
    required this.look,
    required this.field,
    required this.focus,
    required this.onChanged,
    required this.onClear,
    required this.onCancel,
  });

  final OfflineBarLook look;
  final TextEditingController field;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  /// iOS's own edit menu: its Paste reads the clipboard without the "Allow Paste" alert that Flutter's toolbar
  /// brings up.
  static Widget _editMenu(BuildContext context, EditableTextState state) => SystemContextMenu.isSupported(context)
      ? SystemContextMenu.editableText(editableTextState: state)
      : AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final text = offlineStyle(_T.fieldText, _T.colorsOf(context).fieldInk, line: _T.fieldLine);
    final hint = text.copyWith(color: _T.colorsOf(context).fieldHint);
    return ColoredBox(
      key: const ValueKey('offline-search-bar'),
      color: look.fill,
      child: SizedBox(
        height: top + _T.barRow,
        child: Stack(
          children: [
            Positioned(
              left: _T.fieldLeft,
              right: _T.fieldRight,
              top: top + (_T.barRow - _T.fieldHeight) / 2,
              height: _T.fieldHeight,
              child: GestureDetector(
                onTap: focus.requestFocus,
                child: DecoratedBox(
                  key: const ValueKey('offline-search-field-box'),
                  decoration: ShapeDecoration(color: _T.colorsOf(context).field, shape: StadiumBorder()),
                  child: Stack(
                    children: [
                      Positioned(
                        left: _T.fieldGlyphCentre - _T.fieldGlyph / 2,
                        top: _T.fieldHeight / 2 + _T.fieldGlyphDrop - _T.fieldGlyph / 2,
                        child: SearchGlyphIcon(SearchGlyph.magnifier, size: _T.fieldGlyph, color: _T.colorsOf(context).fieldHint),
                      ),
                      Positioned(
                        left: _T.fieldTextLeft,
                        right: _T.clearTarget,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: TextField(
                            keyboardAppearance: BiliPalette.of(context).brightness,
                            key: const ValueKey('offline-search-field'),
                            controller: field,
                            focusNode: focus,
                            autofocus: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.search,
                            contextMenuBuilder: _editMenu,
                            cursorColor: _T.colorsOf(context).caret,
                            onChanged: onChanged,
                            style: text,
                            strutStyle: BiliFonts.strut(text),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              // As the decorator would draw hintText, with the strut it can't be given.
                              hint: Text(
                                '搜索已下载的内容',
                                style: hint,
                                strutStyle: BiliFonts.strut(hint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: _T.clearTarget,
                        child: ListenableBuilder(
                          listenable: field,
                          builder: (context, _) => field.text.isEmpty
                              ? const SizedBox.shrink()
                              : Semantics(
                                  button: true,
                                  label: '清空',
                                  onTap: onClear,
                                  excludeSemantics: true,
                                  child: GestureDetector(
                                    key: const ValueKey('offline-search-clear'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onClear,
                                    child: Center(
                                      child: SearchGlyphIcon(
                                        SearchGlyph.clear,
                                        size: _T.clearGlyph,
                                        color: _T.colorsOf(context).clearInk,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: top,
              height: _T.barRow,
              child: _Words(
                key: const ValueKey('offline-search-cancel'),
                label: '取消',
                color: look.ink,
                right: _T.cancelRight,
                onTap: onCancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
