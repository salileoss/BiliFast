import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../shared/menu.dart' show PressHighlight;
import '../shared/theme.dart';

/// The suggestions while typing (55): one row each with the typed part in pink, a hairline under every row.
class SuggestionList extends StatelessWidget {
  const SuggestionList({super.key, required this.suggestions, required this.onSelect});

  final List<SearchSuggestion> suggestions;
  final ValueChanged<SearchSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: SearchTheme.wordText,
      height: SearchTheme.wordLine / SearchTheme.wordText,
      color: SearchTheme.colorsOf(context).text,
      decoration: TextDecoration.none,
    );
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom > media.viewPadding.bottom
        ? media.viewInsets.bottom
        : media.viewPadding.bottom;
    return DefaultTextStyle.merge(
      style: style,
      child: ListView.builder(
        key: const ValueKey('search-suggestions'),
        padding: EdgeInsets.only(bottom: bottom),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return _Row(suggestion: suggestion, style: style, onTap: () => onSelect(suggestion));
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.suggestion, required this.style, required this.onTap});

  final SearchSuggestion suggestion;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = suggestion.text;
    return Semantics(
      button: true,
      label: text.text,
      onTap: onTap,
      excludeSemantics: true,
      child: PressHighlight(
        key: ValueKey('search-suggestion-${suggestion.keyword}'),
        onTap: onTap,
        child: SizedBox(
          height: SearchTheme.suggestionHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SearchTheme.gutter),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          for (final run in text.runs)
                            TextSpan(
                              text: run.text,
                              style: run.highlighted ? TextStyle(color: SearchTheme.colorsOf(context).highlight) : null,
                            ),
                        ],
                      ),
                      style: style,
                      strutStyle: BiliFonts.strut(style),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: SearchTheme.gutter),
                child: SizedBox(
                  height: SearchTheme.suggestionHairline,
                  child: ColoredBox(color: SearchTheme.colorsOf(context).suggestionHairlineColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
