import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_scope.dart';
import '../app/swipe_back_route.dart';
import '../settings/settings_confirm.dart';
import '../shared/theme.dart';
import '../space/space_route.dart';
import '../space/uploader_tap.dart';
import '../video/intro/collection_row.dart' show Chevron;
import '../video/link_opener.dart';
import '../video/video_route.dart';
import 'results/result_more_sheet.dart';
import 'results/results_view.dart';
import 'search_glyphs.dart';
import 'search_home_view.dart';
import 'search_model.dart';
import 'suggestion_list.dart';

/// Opens 搜索 from 首页's field; [placeholder] is the default word home already shows.
Future<void> openSearchPage(BuildContext context, {String? placeholder}) =>
    Navigator.of(context).push(SwipeBackPageRoute<void>(builder: (_) => SearchPage(placeholder: placeholder)));

final _urlPattern = RegExp(r'https?://|b23\.tv|bilibili\.com', caseSensitive: false);
final _bvPattern = RegExp(r'BV1[0-9A-Za-z]{9}(?![0-9A-Za-z])');
final _bareAvPattern = RegExp(r'^av\d{5,}$', caseSensitive: false);

/// Whether the field's [text] is a link to open rather than words to search: a URL or a BV id anywhere in it, or a
/// bare av id (`av` and five or more digits) as the whole text. [LinkParser] alone finds `av1` in "4K AV1".
bool isSearchFieldLink(String text) {
  final trimmed = text.trim();
  final looksLikeLink =
      _urlPattern.hasMatch(trimmed) || _bvPattern.hasMatch(trimmed) || _bareAvPattern.hasMatch(trimmed);
  return looksLikeLink && LinkParser.parse(trimmed) != null;
}

/// 搜索 (52-61): the field with ‹ and 搜索, then the empty page, suggestions or results. A link typed or pasted in
/// the field opens its video instead of searching.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.placeholder, this.linkOpener, this.openVideo, this.openSpace});

  final String? placeholder;

  /// Tests hand in their own; the page makes one otherwise.
  final LinkOpener? linkOpener;

  /// Opens a result's video; [openVideoPage] unless a test watches it instead.
  final void Function(BuildContext context, VideoRoute route)? openVideo;

  /// Opens a 用户 row's UP主空间, pushed over 搜索 unless a test watches it instead.
  final Future<void> Function(BuildContext context, UploaderRef uploader)? openSpace;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  SearchModel? _model;
  final _field = TextEditingController();
  final _focus = FocusNode();
  late final LinkOpener _opener = widget.linkOpener ?? LinkOpener();

  /// Whether 筛选 is open over the results, shared with [ResultsView] so back closes it first.
  final _filterOpen = ValueNotifier(false);
  String _lastText = '';
  bool _opening = false;

  /// The video whose ⋮ sheet is up.
  SearchVideo? _more;

  late final AnimationController _confirmMotion = AnimationController(
    vsync: this,
    duration: SettingsTheme.confirmIn,
    reverseDuration: SettingsTheme.confirmOut,
  );
  late final CurvedAnimation _confirmCurve = CurvedAnimation(
    parent: _confirmMotion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// Whether 清空搜索历史？ is asked; [_confirmShown] stays true while it fades out.
  bool _confirming = false;
  bool _confirmShown = false;

  SearchModel get _search => _model!;

  @override
  void initState() {
    super.initState();
    _opener.busy.addListener(_busyChanged);
    _filterOpen.addListener(_filterChanged);
    _focus.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _confirmMotion
      ..duration = still ? Duration.zero : SettingsTheme.confirmIn
      ..reverseDuration = still ? Duration.zero : SettingsTheme.confirmOut;
    if (_model != null) return;
    final services = AppScope.of(context);
    final model = SearchModel(
      api: services.searchApi,
      history: services.searchHistory,
      placeholder: widget.placeholder,
    );
    _model = model;
    model.addListener(_stageChanged);
    unawaited(
      model.loadHome().catchError((Object error) {
        Logger.shared.warn(LogCategory.ui, 'search home failed', {'error': '${error.runtimeType}'});
      }),
    );
  }

  @override
  void dispose() {
    _opener.busy.removeListener(_busyChanged);
    if (widget.linkOpener == null) _opener.dispose();
    _model?.removeListener(_stageChanged);
    _model?.dispose();
    _filterOpen.dispose();
    _confirmCurve.dispose();
    _confirmMotion.dispose();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _busyChanged() {
    if (mounted) setState(() => _opening = _opener.busy.value);
  }

  /// [PopScope.canPop] follows 筛选.
  void _filterChanged() {
    if (mounted) setState(() {});
  }

  /// 筛选 belongs to the results; leaving them leaves it closed.
  void _stageChanged() {
    if (_search.stage != SearchStage.results) _filterOpen.value = false;
  }

  /// Focus coming to the field over results, from a tap anywhere on it (the word, the magnifier, the padding), goes
  /// back to typing.
  void _focusChanged() {
    if (_focus.hasFocus && _search.stage == SearchStage.results) _search.textChanged(_field.text);
  }

  void _setText(String text) {
    _field.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _lastText = text;
  }

  /// A word from the field, a section or a suggestion: the field shows it and the keyboard goes.
  void _searchWord(String word) {
    final keyword = word.trim();
    if (keyword.isEmpty) return;
    _setText(keyword);
    _focus.unfocus();
    _search.search(keyword);
  }

  void _submit() {
    final text = _field.text;
    if (text.trim().isEmpty) {
      final placeholder = _search.placeholder;
      if (placeholder.isNotEmpty) _searchWord(placeholder);
      return;
    }
    if (isSearchFieldLink(text)) {
      unawaited(_openLink(text));
      return;
    }
    _searchWord(text);
  }

  void _textChanged(String text) {
    final grew = text.length - _lastText.length;
    _lastText = text;
    // A paste lands as one big change; typing adds a character at a time.
    if (grew > 1 && isSearchFieldLink(text)) {
      unawaited(_openLink(text));
      return;
    }
    _search.textChanged(text);
  }

  Future<void> _openLink(String text) async {
    _focus.unfocus();
    if (!await _opener.open(context, text) || !mounted) return;
    _setText('');
    _search.textChanged('');
  }

  void _clear() {
    _setText('');
    _search.textChanged('');
    _focus.requestFocus();
  }

  void _openVideo(SearchVideo video) {
    final route = VideoRoute(bvid: video.bvid, title: video.title.text, cover: video.cover);
    final open = widget.openVideo;
    if (open != null) {
      open(context, route);
    } else {
      unawaited(openVideoPage(context, route));
    }
  }

  void _openUser(SearchUser user) {
    final uploader = UploaderRef(mid: user.mid, name: user.name, face: user.face);
    unawaited((widget.openSpace ?? openSpace)(context, uploader));
  }

  void _askClear() {
    _focus.unfocus();
    setState(() => _confirming = _confirmShown = true);
    unawaited(_confirmMotion.forward());
  }

  void _dismissConfirm() {
    if (!_confirming) return;
    setState(() => _confirming = false);
    unawaited(
      _confirmMotion.reverse().then((_) {
        if (mounted && !_confirming) setState(() => _confirmShown = false);
      }),
    );
  }

  void _clearHistory() {
    if (!_confirming) return;
    _search.history.clear();
    _dismissConfirm();
  }

  void _closeOverlay() {
    if (_confirming) {
      _dismissConfirm();
    } else if (_more != null) {
      setState(() => _more = null);
    } else if (_filterOpen.value) {
      _filterOpen.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _search;
    final more = _more;
    return PopScope(
      canPop: more == null && !_confirming && !_filterOpen.value,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeOverlay();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: SearchTheme.colorsOf(context).page,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              ListenableBuilder(
                listenable: model,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SafeArea(
                      bottom: false,
                      child: _SearchBar(
                        field: _field,
                        focus: _focus,
                        placeholder: model.placeholder,
                        enabled: !_opening,
                        onChanged: _textChanged,
                        onSubmit: _submit,
                        onClear: _clear,
                      ),
                    ),
                    Expanded(
                      child: switch (model.stage) {
                        SearchStage.home => SearchHomeView(
                          model: model,
                          onSearch: _searchWord,
                          onClearHistory: _askClear,
                        ),
                        SearchStage.typing => SuggestionList(
                          suggestions: model.suggestions,
                          onSelect: (suggestion) => _searchWord(suggestion.keyword),
                        ),
                        SearchStage.results => ResultsView(
                          model: model,
                          onOpenVideo: _openVideo,
                          onOpenUser: _openUser,
                          filterOpen: _filterOpen,
                          onMore: (video) {
                            _focus.unfocus();
                            setState(() => _more = video);
                          },
                        ),
                      },
                    ),
                  ],
                ),
              ),
              if (_filterOpen.value && model.stage == SearchStage.results)
                // The PopScope holds while 筛选 is open, which turns the route's edge swipe off: this takes the same
                // edge and closes 筛选 instead.
                Positioned(
                  key: const ValueKey('search-filter-edge'),
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: math.max(BiliMetrics.swipeBackEdge, MediaQuery.paddingOf(context).left),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) >= 0) _filterOpen.value = false;
                    },
                  ),
                ),
              if (more != null)
                Positioned.fill(
                  child: ResultMoreSheet(
                    key: const ValueKey('search-more-sheet'),
                    video: more,
                    onClose: () => setState(() => _more = null),
                  ),
                ),
              if (_confirmShown)
                Positioned.fill(
                  child: SettingsConfirm(
                    title: '清空搜索历史？',
                    action: '清空',
                    motion: _confirmCurve,
                    onConfirm: _clearHistory,
                    onCancel: _dismissConfirm,
                  ),
                ),
              if (_opening)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      key: const ValueKey('search-opening'),
                      padding: const EdgeInsets.all(BiliMetrics.openingPadding),
                      decoration: BoxDecoration(
                        color: SearchTheme.openingFill,
                        borderRadius: BorderRadius.circular(BiliMetrics.toastRadius),
                      ),
                      child: const CupertinoActivityIndicator(
                        radius: BiliMetrics.openingSpinner / 2,
                        color: SearchTheme.openingSpinner,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ‹, the stadium field with the magnifier, the word and ⓧ, and 搜索.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.field,
    required this.focus,
    required this.placeholder,
    required this.enabled,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController field;
  final FocusNode focus;
  final String placeholder;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  /// iOS's own edit menu: its Paste reads the clipboard without the "Allow Paste" alert that Flutter's toolbar
  /// brings up.
  static Widget _editMenu(BuildContext context, EditableTextState state) => SystemContextMenu.isSupported(context)
      ? SystemContextMenu.editableText(editableTextState: state)
      : AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

  static TextStyle _style(Color color, {double size = SearchTheme.fieldText}) => TextStyle(
    fontFamily: BiliFonts.family,
    fontFamilyFallback: BiliFonts.fallback,
    fontSize: size,
    height: SearchTheme.fieldLine / size,
    color: color,
    decoration: TextDecoration.none,
  );

  Widget _button({required Key key, required String label, required VoidCallback onTap, required Widget child}) =>
      Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(key: key, behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final text = _style(SearchTheme.colorsOf(context).text);
    final hint = _style(SearchTheme.colorsOf(context).dim);
    return SizedBox(
      height: SearchTheme.barHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: SearchTheme.backTarget,
            child: _button(
              key: const ValueKey('search-back'),
              label: '返回',
              onTap: () => unawaited(Navigator.of(context).maybePop()),
              child: Center(
                child: Transform.flip(
                  flipX: true,
                  child: Chevron(
                    size: Size(SearchTheme.backWidth, SearchTheme.backHeight),
                    stroke: SearchTheme.backStroke,
                    color: SearchTheme.colorsOf(context).dim,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: focus.requestFocus,
                // A foreground rim: as a decoration its side would pad the contents in by its width.
                child: Container(
                  height: SearchTheme.fieldHeight,
                  padding: const EdgeInsets.only(left: SearchTheme.magnifierInset),
                  foregroundDecoration: ShapeDecoration(
                    shape: StadiumBorder(
                      side: BorderSide(color: SearchTheme.colorsOf(context).fieldRimColor, width: SearchTheme.fieldRim),
                    ),
                  ),
                  child: Row(
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -SearchTheme.magnifierLift),
                        child: SearchGlyphIcon(
                          SearchGlyph.magnifier,
                          size: SearchTheme.magnifier,
                          color: SearchTheme.colorsOf(context).dim,
                        ),
                      ),
                      const SizedBox(width: SearchTheme.magnifierGap),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('search-field'),
                          controller: field,
                          focusNode: focus,
                          autofocus: true,
                          enabled: enabled,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.search,
                          contextMenuBuilder: _editMenu,
                          cursorColor: SearchTheme.colorsOf(context).caret,
                          onChanged: onChanged,
                          onSubmitted: (_) => onSubmit(),
                          style: text,
                          strutStyle: BiliFonts.strut(text),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            // As the decorator would draw hintText, with the strut it can't be given.
                            hint: Text(
                              placeholder,
                              style: hint,
                              strutStyle: BiliFonts.strut(hint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: field,
                        builder: (context, _) => field.text.isEmpty
                            ? const SizedBox(width: SearchTheme.clearRight - SearchTheme.clear / 2)
                            : SizedBox(
                                width: SearchTheme.clearRight * 2,
                                child: _button(
                                  key: const ValueKey('search-clear'),
                                  label: '清空',
                                  onTap: onClear,
                                  child: Center(
                                    child: SearchGlyphIcon(
                                      SearchGlyph.clear,
                                      size: SearchTheme.clear,
                                      color: SearchTheme.colorsOf(context).clearColor,
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
          ),
          SizedBox(
            width: SearchTheme.submitWidth,
            child: _button(
              key: const ValueKey('search-submit'),
              label: '搜索',
              onTap: onSubmit,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, SearchTheme.submitDrop),
                  child: Text('搜索', style: _style(SearchTheme.colorsOf(context).submit, size: SearchTheme.submitText)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
