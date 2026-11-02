import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import 'offline_text.dart';

typedef _T = OfflineListTheme;

/// 同时缓存数量's sheet (147): 1个, then 2个 and 3个 marked (大会员专享), the current count pink. It rises over a dim
/// that closes it when tapped.
class ConcurrencySheet extends StatelessWidget {
  const ConcurrencySheet({super.key, required this.current, required this.onPick, required this.onClose});

  final int current;
  final ValueChanged<int> onPick;
  final VoidCallback onClose;

  static const counts = [1, 2, 3];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : _T.sheetMotion,
      curve: Curves.easeOutCubic,
      builder: (context, t, sheet) => Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '关闭',
              onTap: onClose,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('offline-sheet-dim'),
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: Opacity(
                  opacity: t,
                  child: const ColoredBox(color: _T.sheetDim),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FractionalTranslation(translation: Offset(0, 1 - t), child: sheet),
          ),
        ],
      ),
      child: Container(
        key: const ValueKey('offline-concurrency-sheet'),
        decoration: BoxDecoration(
          color: _T.colorsOf(context).sheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(_T.sheetRadius)),
        ),
        padding: EdgeInsets.only(bottom: bottom + _T.cardBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _T.cardTop,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: _T.handleTop),
                  child: SizedBox(
                    width: _T.handleWidth,
                    height: _T.handleHeight,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(color: _T.colorsOf(context).handle, shape: StadiumBorder()),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _T.cardInset),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: BiliColors.colorsOf(context).card, borderRadius: BorderRadius.circular(_T.cardRadius)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final count in counts) ...[
                      if (count != counts.first)
                        Padding(
                          padding: EdgeInsets.only(left: _T.optionInset),
                          child: SizedBox(
                            height: _T.optionRule,
                            child: ColoredBox(color: _T.colorsOf(context).optionRuleInk),
                          ),
                        ),
                      _Option(count: count, chosen: count == current, onTap: () => onPick(count)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.count, required this.chosen, required this.onTap});

  final int count;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = offlineStyle(_T.optionText, chosen ? _T.colorsOf(context).optionChosen : _T.colorsOf(context).optionInk, line: _T.optionRow);
    final badge = offlineStyle(_T.badgeText, _T.badgeInk, line: _T.badgeHeight);
    final vipOnly = count > 1;
    return Semantics(
      button: true,
      selected: chosen,
      label: vipOnly ? '$count个，大会员专享' : '$count个',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('offline-concurrency-$count'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: _T.optionRow,
          child: Row(
            children: [
              const SizedBox(width: _T.optionInset),
              offlineLine('$count个', style),
              if (vipOnly) ...[
                const SizedBox(width: _T.badgeGap),
                Container(
                  height: _T.badgeHeight,
                  padding: const EdgeInsets.symmetric(horizontal: _T.badgePadX),
                  decoration: ShapeDecoration(color: _T.colorsOf(context).badgeFill, shape: StadiumBorder()),
                  child: Center(widthFactor: 1, child: offlineLine('(大会员专享)', badge)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
