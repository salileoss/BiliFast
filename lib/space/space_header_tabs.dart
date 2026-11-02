import 'package:bili_core/api.dart' show SpaceProfile, SpaceTab, SpaceTabKind;
import 'package:flutter/widgets.dart';

import '../shared/theme.dart';
import 'space_header.dart';

/// The space's own tabs (63, 69, 72, 78, 136) between hairlines, [selected] pink over its bar.
class SpaceTabRow extends StatelessWidget {
  const SpaceTabRow({super.key, required this.tabs, required this.onTap, this.selected = SpaceTabKind.contribute});

  final List<SpaceTab> tabs;
  final ValueChanged<SpaceTab> onTap;
  final SpaceTabKind selected;

  /// The profile's tabs, with 投稿 added at the end when the uploader's list has none.
  static List<SpaceTab> of(SpaceProfile profile) => [
    ...profile.tabs,
    if (!profile.tabs.any((tab) => tab.kind == SpaceTabKind.contribute))
      const SpaceTab(kind: SpaceTabKind.contribute, title: '投稿'),
  ];

  @override
  Widget build(BuildContext context) {
    final hairline = SizedBox(height: SpaceTheme.tabsHairline, child: ColoredBox(color: SpaceTheme.colorsOf(context).tabsHairlineInk));
    return ColoredBox(
      key: const ValueKey('space-tabs'),
      color: SpaceTheme.colorsOf(context).page,
      child: SizedBox(
        height: SpaceTheme.tabsHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hairline,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cell = (constraints.maxWidth + SpaceTheme.tabsSpread * 2) / tabs.length;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final (i, tab) in tabs.indexed)
                        Positioned(
                          left: -SpaceTheme.tabsSpread + cell * i,
                          width: cell,
                          top: 0,
                          bottom: 0,
                          child: _Tab(tab: tab, shown: tab.kind == selected, onTap: () => onTap(tab)),
                        ),
                    ],
                  );
                },
              ),
            ),
            hairline,
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.shown, required this.onTap});

  final SpaceTab tab;
  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: shown,
      label: tab.title,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('space-tab-${tab.kind.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            spaceLine(
              tab.title,
              spaceStyle(SpaceTheme.tabText, shown ? SpaceTheme.colorsOf(context).tabSelected : SpaceTheme.colorsOf(context).tabInk, line: SpaceTheme.tabLine),
            ),
            if (shown)
              Positioned(
                bottom: SpaceTheme.indicatorBottom,
                child: Container(
                  key: const ValueKey('space-tab-indicator'),
                  width: SpaceTheme.indicatorWidth,
                  height: SpaceTheme.indicatorHeight,
                  decoration: BoxDecoration(
                    color: SpaceTheme.colorsOf(context).tabSelected,
                    borderRadius: BorderRadius.circular(SpaceTheme.indicatorHeight / 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
