import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The official app's cover while it loads (14): grey, with a faint 小电视 in the middle.
class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({super.key});

  static const asset = 'assets/images/loading/cover_placeholder.png';

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CoverPlaceholderTheme.colorsOf(context).fill,
    child: Center(
      child: Image(
        image: AssetImage(asset),
        width: CoverPlaceholderTheme.width,
        height: CoverPlaceholderTheme.height,
        fit: BoxFit.contain,
        color: CoverPlaceholderTheme.colorsOf(context).ink,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    ),
  );
}
