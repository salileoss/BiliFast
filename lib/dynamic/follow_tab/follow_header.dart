import 'package:flutter/widgets.dart';

import '../../home/tab_bar_icons.dart' show SkinDecodeGate;
import '../../shared/theme.dart';
import '../../skin/skin.dart';
import 'follow_parts.dart';

/// 关注's header (127): the centred title and the ✏️ at the right, over the equipped 装扮's `head_bg` (cover-fit and
/// cropped about its centre, as on 首页) or a white bar.
class FollowHeader extends StatelessWidget {
  const FollowHeader({super.key, required this.skin, required this.onWrite});

  /// A skin with a `head_bg`, its picture decoded, or null.
  final Skin? skin;
  final VoidCallback onWrite;

  /// How tall it is under [topPadding], the status bar's.
  static double heightOf(double topPadding) => topPadding + DynamicFeedTheme.barRow - DynamicFeedTheme.barRise;

  @override
  Widget build(BuildContext context) {
    final head = skin?.headBg;
    final ink = skin?.color ?? DynamicFeedTheme.colorsOf(context).titleInk;
    return SizedBox(
      key: const ValueKey('follow-header'),
      height: heightOf(MediaQuery.paddingOf(context).top),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (head != null)
            SkinDecodeGate.image(head, key: const ValueKey('follow-head-art'))
          else
            ColoredBox(color: DynamicFeedTheme.colorsOf(context).bar),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: DynamicFeedTheme.barRow,
            child: Center(
              child: Semantics(
                header: true,
                child: Text(
                  '关注',
                  key: const ValueKey('follow-title'),
                  style: followStyle(DynamicFeedTheme.titleText, ink, weight: DynamicFeedTheme.titleWeight),
                ),
              ),
            ),
          ),
          Positioned(
            right: DynamicFeedTheme.writeCentreRight - DynamicFeedTheme.writeTarget / 2,
            bottom: 0,
            width: DynamicFeedTheme.writeTarget,
            height: DynamicFeedTheme.barRow,
            child: FollowTap(
              key: const ValueKey('follow-write'),
              label: '发布动态',
              onTap: onWrite,
              child: Center(
                child: Image.asset(
                  'assets/images/dynamic/follow_write.png',
                  width: DynamicFeedTheme.write,
                  height: DynamicFeedTheme.write,
                  color: ink.withValues(alpha: ink.a * DynamicFeedTheme.writeOpacity),
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
