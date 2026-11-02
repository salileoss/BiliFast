import 'package:flutter/material.dart';

import '../shared/theme.dart';

/// 刚刚看到这里，点击刷新 (122): the row between a refresh's page and the cards from before it, its words and the
/// official ⟳ across the middle of the gap between their rows. A tap anywhere on it refreshes.
class FeedDivider extends StatelessWidget {
  const FeedDivider({super.key, required this.onTap});

  static const label = '刚刚看到这里，点击刷新';
  static const icon = 'assets/images/home/batch_refresh.png';

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: FeedBatchTheme.text, color: FeedBatchTheme.colorsOf(context).ink);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: FeedBatchTheme.dividerGap,
          padding: const EdgeInsets.only(left: FeedBatchTheme.right * 2, top: FeedBatchTheme.drop * 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, maxLines: 1, style: style, strutStyle: BiliFonts.strutOf(context, style)),
              const SizedBox(width: FeedBatchTheme.iconGap),
              Image.asset(
                icon,
                width: FeedBatchTheme.icon,
                height: FeedBatchTheme.icon,
                color: FeedBatchTheme.colorsOf(context).ink,
                colorBlendMode: BlendMode.srcIn,
                excludeFromSemantics: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
