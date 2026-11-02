import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import '../search_filters.dart';

/// 筛选 (58): 排序方式, 发布时间 and 内容时长 as rows of grey chips, the chosen one pink. A tap applies at once.
/// [ResultsView] places it under the tab row, over a dimmed list.
class SearchFilterPanel extends StatelessWidget {
  const SearchFilterPanel({super.key, required this.filters, required this.onChanged});

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final sections = [
      _FilterSection(
        title: '排序方式',
        chips: [
          for (final order in FilterOrder.values)
            _chip('order-${order.name}', order.label, order == filters.order, filters.copyWith(order: order)),
        ],
      ),
      _FilterSection(
        title: '发布时间',
        chips: [
          for (final published in FilterPublished.values)
            _chip(
              'published-${published.name}',
              published.label,
              published == filters.published,
              filters.copyWith(published: published),
            ),
        ],
      ),
      _FilterSection(
        title: '内容时长',
        chips: [
          for (final length in FilterLength.values)
            _chip('length-${length.name}', length.label, length == filters.length, filters.copyWith(length: length)),
        ],
      ),
    ];
    return ColoredBox(
      color: SearchFilterTheme.colorsOf(context).panel,
      child: Padding(
        padding: const EdgeInsets.only(
          left: SearchFilterTheme.side,
          right: SearchFilterTheme.side,
          top: SearchFilterTheme.firstTitleMiddle - SearchFilterTheme.titleToChips,
          bottom: SearchFilterTheme.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, section) in sections.indexed) ...[
              if (index > 0) const SizedBox(height: SearchFilterTheme.chipsToTitle - SearchFilterTheme.titleToChips),
              section,
            ],
          ],
        ),
      ),
    );
  }

  _FilterChip _chip(String id, String label, bool chosen, SearchFilters next) => _FilterChip(
    key: ValueKey('search-filter-$id'),
    label: label,
    chosen: chosen,
    onTap: () {
      if (next != filters) onChanged(next);
    },
  );
}

/// A title, then its chips four to a row.
class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.chips});

  final String title;
  final List<_FilterChip> chips;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: SearchFilterTheme.titleText,
      color: SearchFilterTheme.colorsOf(context).title,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: SearchFilterTheme.titleToChips * 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, maxLines: 1, style: style, strutStyle: BiliFonts.strutOf(context, style)),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const columns = SearchFilterTheme.columns;
            const gap = SearchFilterTheme.chipGap;
            final width = ((constraints.maxWidth - gap * (columns - 1)) / columns).floorToDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var start = 0; start < chips.length; start += columns) ...[
                  if (start > 0) const SizedBox(height: SearchFilterTheme.chipRowGap),
                  Row(
                    children: [
                      for (final (index, chip) in chips.skip(start).take(columns).indexed) ...[
                        if (index > 0) const SizedBox(width: gap),
                        SizedBox(width: width, height: SearchFilterTheme.chipHeight, child: chip),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A grey chip, its label pink while chosen.
class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.chosen, required this.onTap});

  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: SearchFilterTheme.chipText,
      color: chosen ? SearchFilterTheme.colorsOf(context).chipChosenLabel : SearchFilterTheme.colorsOf(context).chipLabel,
    );
    return Semantics(
      button: true,
      selected: chosen,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SearchFilterTheme.colorsOf(context).chip,
            borderRadius: BorderRadius.all(Radius.circular(SearchFilterTheme.chipRadius)),
          ),
          child: Center(
            child: Text.rich(_spaced(label), maxLines: 1, style: style, strutStyle: BiliFonts.strutOf(context, style)),
          ),
        ),
      ),
    );
  }
}

/// [text] with 58's spacing of digits and Latin: each a little wider than SF draws it, and set apart from Chinese.
TextSpan _spaced(String text) {
  bool latin(int unit) => unit > 0x20 && unit < 0x7F;
  bool han(int unit) => (unit >= 0x4E00 && unit <= 0x9FFF) || (unit >= 0x3400 && unit <= 0x4DBF);
  double after(int index) {
    if (index == text.length - 1) return 0;
    final a = text.codeUnitAt(index), b = text.codeUnitAt(index + 1);
    return (latin(a) ? SearchFilterTheme.chipLatinSpacing : 0) +
        ((latin(a) && han(b)) || (han(a) && latin(b)) ? SearchFilterTheme.chipHanGap : 0);
  }

  final spans = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i < text.length && after(i) == after(start)) continue;
    final spacing = after(start);
    spans.add(
      TextSpan(
        text: text.substring(start, i),
        style: spacing == 0 ? null : TextStyle(letterSpacing: spacing),
      ),
    );
    start = i;
  }
  return TextSpan(children: spans);
}
