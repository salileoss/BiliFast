import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/intro/collection_row.dart' show Chevron;
import 'search_glyphs.dart';
import 'search_model.dart';

/// 搜索's empty page (52-54): bilibili热搜, 搜索历史 when there is any, 搜索发现 and the 反馈 pill. A word searches;
/// dragging the page closes the keyboard.
class SearchHomeView extends StatefulWidget {
  const SearchHomeView({super.key, required this.model, required this.onSearch, required this.onClearHistory});

  final SearchModel model;
  final ValueChanged<String> onSearch;

  /// 🗑: the page asks before clearing.
  final VoidCallback onClearHistory;

  @override
  State<SearchHomeView> createState() => _SearchHomeViewState();
}

class _SearchHomeViewState extends State<SearchHomeView> {
  bool _expanded = false;

  static TextStyle _style(double size, Color color, {FontWeight? weight, double? line}) => TextStyle(
    fontFamily: BiliFonts.family,
    fontFamilyFallback: BiliFonts.fallback,
    fontSize: size,
    fontWeight: weight,
    height: (line ?? SearchTheme.wordLine) / size,
    color: color,
    decoration: TextDecoration.none,
  );

  TextStyle get _word => _style(SearchTheme.wordText, SearchTheme.colorsOf(context).text);

  bool _closeKeyboard(ScrollStartNotification notification) {
    if (notification.dragDetails != null) FocusManager.instance.primaryFocus?.unfocus();
    return false;
  }

  /// ↻ keeps the words shown when it fails, so it says so.
  Future<void> _refreshDiscovery() async {
    if (!await widget.model.refreshDiscovery() && mounted) showToast(context, '加载失败，请稍后重试');
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom > media.viewPadding.bottom
        ? media.viewInsets.bottom
        : media.viewPadding.bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([model, model.history]),
      builder: (context, _) {
        final history = model.history;
        final hot = model.hotWords.take(SearchTheme.hotWords).toList();
        return DefaultTextStyle.merge(
          style: _word,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: _closeKeyboard,
            child: SingleChildScrollView(
              key: const ValueKey('search-home'),
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(top: SearchTheme.hotTop, bottom: bottom + SearchTheme.feedbackBottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hot.isNotEmpty) ...[
                    _Header(
                      title: 'bilibili热搜',
                      trailing: [
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: _Button(
                            key: const ValueKey('search-hot-more'),
                            label: '完整榜单',
                            onTap: () => showToast(context, '暂未开放'),
                            child: Padding(
                              padding: const EdgeInsets.only(left: SearchTheme.gutter, right: SearchTheme.moreRight),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '完整榜单',
                                    style: _style(SearchTheme.moreText, SearchTheme.colorsOf(context).grey, line: SearchTheme.headerLine),
                                  ),
                                  const SizedBox(width: SearchTheme.moreGap),
                                  Chevron(
                                    size: Size(SearchTheme.moreChevronWidth, SearchTheme.moreChevronHeight),
                                    stroke: SearchTheme.moreChevronStroke,
                                    color: SearchTheme.colorsOf(context).grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    for (var row = 0; row < hot.length; row += 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: SearchTheme.gutter),
                        child: SizedBox(
                          height: SearchTheme.hotRowHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _HotWord(word: hot[row], style: _word, onSearch: widget.onSearch),
                              ),
                              const SizedBox(width: SearchTheme.hotColumnGap),
                              Expanded(
                                child: row + 1 < hot.length
                                    ? _HotWord(word: hot[row + 1], style: _word, onSearch: widget.onSearch)
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: SearchTheme.afterHot),
                  ],
                  if (history.words.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final words = history.words;
                        final folded = _HistoryChips.fitting(
                          context,
                          words: words,
                          style: _word,
                          width: constraints.maxWidth - SearchTheme.gutter * 2,
                          rows: SearchTheme.foldedRows,
                        );
                        // Nothing more to show when every chip fits in the folded rows.
                        final folds = folded < words.length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(
                              title: '搜索历史',
                              trailing: [
                                _HeaderGlyph(
                                  key: const ValueKey('search-history-clear'),
                                  fromRight: SearchTheme.headerFirstGlyph,
                                  lift: SearchTheme.trashLift,
                                  label: '清空搜索历史',
                                  glyph: SearchGlyph.trash,
                                  size: SearchTheme.trash,
                                  onTap: widget.onClearHistory,
                                ),
                                if (folds) ...[
                                  const _HeaderRule(),
                                  _HeaderGlyph(
                                    key: const ValueKey('search-history-expand'),
                                    fromRight: SearchTheme.headerExpandGlyph,
                                    lift: _expanded ? SearchTheme.collapseLift : 0,
                                    label: _expanded ? '收起' : '展开',
                                    glyph: _expanded ? SearchGlyph.collapse : SearchGlyph.expand,
                                    size: SearchTheme.expand,
                                    onTap: () => setState(() => _expanded = !_expanded),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: SearchTheme.listTop),
                            _HistoryChips(
                              words: _expanded || !folds ? words : words.take(folded).toList(),
                              style: _word,
                              onSearch: widget.onSearch,
                            ),
                            const SizedBox(height: SearchTheme.afterList),
                          ],
                        );
                      },
                    ),
                  _Header(
                    title: '搜索发现',
                    trailing: [
                      _HeaderGlyph(
                        key: const ValueKey('search-discovery-refresh'),
                        fromRight: SearchTheme.headerFirstGlyph,
                        label: '换一换',
                        glyph: SearchGlyph.refresh,
                        size: SearchTheme.refresh,
                        onTap: () => unawaited(_refreshDiscovery()),
                      ),
                      const _HeaderRule(),
                      _HeaderGlyph(
                        key: const ValueKey('search-discovery-eye'),
                        fromRight: SearchTheme.headerEyeGlyph,
                        label: history.discoveryHidden ? '显示搜索发现' : '隐藏搜索发现',
                        glyph: history.discoveryHidden ? SearchGlyph.eyeOff : SearchGlyph.eye,
                        size: SearchTheme.eye,
                        onTap: () => history.setDiscoveryHidden(!history.discoveryHidden),
                      ),
                    ],
                  ),
                  if (!history.discoveryHidden && model.discovery.isNotEmpty) ...[
                    const SizedBox(height: SearchTheme.listTop),
                    _DiscoveryCells(
                      words: model.discovery.take(SearchTheme.discoveryWords).toList(),
                      style: _word,
                      onSearch: widget.onSearch,
                    ),
                  ],
                  const SizedBox(height: SearchTheme.afterList + SearchTheme.feedbackTop),
                  Center(
                    child: _Button(
                      key: const ValueKey('search-feedback'),
                      label: '反馈',
                      press: _Press.scale,
                      onTap: () => showToast(context, '暂未开放'),
                      child: Container(
                        width: SearchTheme.feedbackWidth,
                        height: SearchTheme.feedbackHeight,
                        decoration: ShapeDecoration(
                          shape: StadiumBorder(
                            side: BorderSide(color: SearchTheme.colorsOf(context).rule, width: SearchTheme.feedbackRim),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SearchGlyphIcon(
                              SearchGlyph.feedback,
                              size: SearchTheme.feedbackGlyph,
                              color: SearchTheme.colorsOf(context).dim,
                            ),
                            const SizedBox(width: SearchTheme.feedbackGap),
                            Text(
                              '反馈',
                              style: _style(SearchTheme.feedbackText, SearchTheme.colorsOf(context).dim, line: SearchTheme.headerLine),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// How a [_Button] answers a finger on it.
enum _Press { none, darken, scale }

/// A tap target that answers accessibility presses. [_Press.darken] lays [BiliColors.colorsOf(context).pressedFill] over it, rounded
/// by [radius], while pressed; [_Press.scale] shrinks it.
class _Button extends StatefulWidget {
  const _Button({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.press = _Press.none,
    this.radius = 0,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final _Press press;
  final double radius;

  @override
  State<_Button> createState() => _ButtonState();
}

class _ButtonState extends State<_Button> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final answers = widget.press != _Press.none;
    final child = switch (widget.press) {
      _Press.none => widget.child,
      _Press.darken => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: _pressed ? BiliColors.colorsOf(context).pressedFill : null,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: widget.child,
      ),
      _Press.scale => AnimatedScale(
        scale: _pressed ? SearchTheme.feedbackPressedScale : 1,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : SearchTheme.pressMotion,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    };
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: answers ? (_) => _press(true) : null,
        onTapUp: answers ? (_) => _press(false) : null,
        onTapCancel: answers ? () => _press(false) : null,
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}

/// A section's title at the gutter, with its glyphs placed from the right edge.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.trailing});

  final String title;
  final List<Widget> trailing;

  static TextStyle _style(BuildContext context) => _SearchHomeViewState._style(
    SearchTheme.headerText,
    SearchTheme.colorsOf(context).text,
    weight: SearchTheme.headerWeight,
    line: SearchTheme.headerLine,
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: SearchTheme.headerHeight,
    child: Stack(
      children: [
        Positioned(
          left: SearchTheme.gutter,
          top: 0,
          bottom: 0,
          child: Center(
            child: Semantics(
              header: true,
              child: Text(title, style: _style(context), strutStyle: BiliFonts.strut(_style(context))),
            ),
          ),
        ),
        ...trailing,
      ],
    ),
  );
}

class _HeaderGlyph extends StatelessWidget {
  const _HeaderGlyph({
    super.key,
    required this.fromRight,
    required this.label,
    required this.glyph,
    required this.size,
    required this.onTap,
    this.lift = 0,
  });

  /// Where the glyph's middle is, from the right edge.
  final double fromRight;

  /// How far above the header's middle the glyph's box sits, where its drawn ink would otherwise sit low.
  final double lift;
  final String label;
  final SearchGlyph glyph;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
    right: fromRight - SearchTheme.headerGlyphTarget / 2,
    width: SearchTheme.headerGlyphTarget,
    top: 0,
    bottom: 0,
    child: _Button(
      label: label,
      onTap: onTap,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, -lift),
          child: SearchGlyphIcon(glyph, size: size, color: SearchTheme.colorsOf(context).grey),
        ),
      ),
    ),
  );
}

class _HeaderRule extends StatelessWidget {
  const _HeaderRule();

  @override
  Widget build(BuildContext context) => Positioned(
    right: SearchTheme.headerRule - SearchTheme.ruleWidth / 2,
    width: SearchTheme.ruleWidth,
    top: (SearchTheme.headerHeight - SearchTheme.ruleHeight) / 2,
    height: SearchTheme.ruleHeight,
    child: ColoredBox(color: SearchTheme.colorsOf(context).rule),
  );
}

/// A 热搜 word, cut with … before its badge when long.
class _HotWord extends StatelessWidget {
  const _HotWord({required this.word, required this.style, required this.onSearch});

  final HotWord word;
  final TextStyle style;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final icon = word.icon;
    return _Button(
      key: ValueKey('search-hot-${word.keyword}'),
      label: word.showName,
      press: _Press.darken,
      radius: SearchTheme.chipRadius,
      onTap: () => onSearch(word.keyword),
      child: Row(
        children: [
          Flexible(
            child: Text(
              word.showName,
              style: style,
              strutStyle: BiliFonts.strut(style),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (icon != null && icon.isNotEmpty) ...[
            const SizedBox(width: SearchTheme.badgeGap),
            SizedBox.square(
              dimension: SearchTheme.badge,
              child: RemoteImage(icon, fit: BoxFit.contain, fallback: const SizedBox.expand()),
            ),
          ],
        ],
      ),
    );
  }
}

/// 搜索历史's chips, [words] being those shown; a change in how many rows they take is animated.
class _HistoryChips extends StatelessWidget {
  const _HistoryChips({required this.words, required this.style, required this.onSearch});

  final List<String> words;
  final TextStyle style;
  final ValueChanged<String> onSearch;

  /// How many of [words] fit in [rows] rows of [width], as the Wrap below lays them out.
  static int fitting(
    BuildContext context, {
    required List<String> words,
    required TextStyle style,
    required double width,
    required int rows,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    var row = 1;
    var used = 0.0;
    for (var i = 0; i < words.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: words[i], style: style),
        strutStyle: BiliFonts.strut(style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: SearchTheme.chipTextMax);
      final chip = painter.width + SearchTheme.chipPadding * 2;
      painter.dispose();
      if (used > 0 && used + SearchTheme.chipSpacing + chip > width) {
        row++;
        used = chip;
      } else {
        used += (used > 0 ? SearchTheme.chipSpacing : 0) + chip;
      }
      if (row > rows) return i;
    }
    return words.length;
  }

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: SearchTheme.chipSpacing,
      runSpacing: SearchTheme.chipRunSpacing,
      children: [
        for (final word in words)
          _Button(
            key: ValueKey('search-history-$word'),
            label: word,
            press: _Press.darken,
            radius: SearchTheme.chipRadius,
            onTap: () => onSearch(word),
            child: Container(
              height: SearchTheme.chipHeight,
              padding: const EdgeInsets.symmetric(horizontal: SearchTheme.chipPadding),
              decoration: BoxDecoration(
                color: SearchTheme.colorsOf(context).chipFill,
                borderRadius: BorderRadius.circular(SearchTheme.chipRadius),
              ),
              child: Align(
                widthFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: SearchTheme.chipTextMax),
                  child: Text(
                    word,
                    style: style,
                    strutStyle: BiliFonts.strut(style),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SearchTheme.gutter),
      // Not an AnimatedSize with no duration under Reduce Motion: that one re-dirties itself mid-layout.
      child: MediaQuery.disableAnimationsOf(context)
          ? chips
          : AnimatedSize(
              duration: SearchTheme.historyMotion,
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: chips,
            ),
    );
  }
}

/// 搜索发现's grey cells, two to a row.
class _DiscoveryCells extends StatelessWidget {
  const _DiscoveryCells({required this.words, required this.style, required this.onSearch});

  final List<DiscoveryWord> words;
  final TextStyle style;
  final ValueChanged<String> onSearch;

  Widget _cell(BuildContext context, DiscoveryWord word) => _Button(
    key: ValueKey('search-discovery-${word.keyword}'),
    label: word.suffix.isEmpty ? word.showName : '${word.showName}·${word.suffix}',
    press: _Press.darken,
    radius: SearchTheme.cellRadius,
    onTap: () => onSearch(word.keyword),
    child: Container(
      height: SearchTheme.cellHeight,
      padding: const EdgeInsets.symmetric(horizontal: SearchTheme.cellPadding),
      decoration: BoxDecoration(
        color: SearchTheme.colorsOf(context).cellFill,
        borderRadius: BorderRadius.circular(SearchTheme.cellRadius),
      ),
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          text: word.showName,
          children: [
            if (word.suffix.isNotEmpty)
              TextSpan(
                text: '·${word.suffix}',
                style: TextStyle(color: SearchTheme.colorsOf(context).suffix),
              ),
          ],
        ),
        style: style,
        strutStyle: BiliFonts.strut(style),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: SearchTheme.gutter),
    child: Column(
      children: [
        for (var row = 0; row < words.length; row += 2) ...[
          if (row > 0) const SizedBox(height: SearchTheme.cellRunSpacing),
          Row(
            children: [
              Expanded(child: _cell(context, words[row])),
              const SizedBox(width: SearchTheme.cellGap),
              Expanded(child: row + 1 < words.length ? _cell(context, words[row + 1]) : const SizedBox.shrink()),
            ],
          ),
        ],
      ],
    ),
  );
}
