import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../home/feed_model.dart' show requestFailureMessage;
import '../shared/loading_tv.dart';
import '../shared/theme.dart';
import 'space_header.dart';

/// Why a space didn't load, and whether asking again could help.
typedef SpaceFailure = ({String message, bool retry});

/// -404 is an uploader who isn't there: asking again won't bring them.
SpaceFailure spaceFailureOf(Object error) => switch (error) {
  BiliAPIError(code: -404) => (message: '用户不存在或已注销', retry: false),
  _ => (message: requestFailureMessage(error), retry: true),
};

/// What a failed space call logs: the status or code, never the message.
String spaceFailureReason(Object error) => switch (error) {
  BiliHTTPError(:final status) => 'http $status',
  BiliAPIError(:final code) => 'api $code',
  _ => '${error.runtimeType}',
};

/// Under the bar while the space loads: the loading TV, or why it failed with 点击重试 when asking again could help.
class SpaceWaiting extends StatelessWidget {
  const SpaceWaiting({super.key, required this.failure, required this.onRetry});

  final SpaceFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + SpaceTheme.barRow;
    final style = spaceStyle(SpaceTheme.retryText, SpaceTheme.colorsOf(context).retryInk);
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Center(
        child: switch (failure) {
          null => const LoadingTvState(key: ValueKey('space-loading')),
          (:final message, retry: false) => Padding(
            padding: const EdgeInsets.all(SpaceTheme.gutter),
            child: Text(message, key: const ValueKey('space-failed'), textAlign: TextAlign.center, style: style),
          ),
          (:final message, retry: true) => Semantics(
            button: true,
            label: '$message，点击重试',
            onTap: onRetry,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('space-retry'),
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.all(SpaceTheme.gutter),
                child: Text.rich(
                  key: const ValueKey('space-failed'),
                  textAlign: TextAlign.center,
                  TextSpan(
                    children: [
                      TextSpan(text: '$message\n', style: style),
                      TextSpan(text: '点击重试', style: spaceStyle(SpaceTheme.retryText, SpaceTheme.colorsOf(context).retryAction)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        },
      ),
    );
  }
}

/// A space's header, shrinking from its full height to the bar's and stretching its banner past it when pulled down.
class SpaceHeaderDelegate extends SliverPersistentHeaderDelegate {
  SpaceHeaderDelegate({required this.min, required this.max, required this.builder});

  final double min;
  final double max;
  final Widget Function(double stretch) builder;

  @override
  double get minExtent => min;

  @override
  double get maxExtent => max;

  @override
  OverScrollHeaderStretchConfiguration get stretchConfiguration => OverScrollHeaderStretchConfiguration();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => LayoutBuilder(
    builder: (context, constraints) {
      final extent = constraints.maxHeight;
      if (extent >= max) return SizedBox(height: extent, child: builder(extent - max));
      return SizedBox(
        height: extent,
        child: ClipRect(
          child: OverflowBox(alignment: Alignment.bottomCenter, minHeight: max, maxHeight: max, child: builder(0)),
        ),
      );
    },
  );

  @override
  bool shouldRebuild(SpaceHeaderDelegate oldDelegate) => true;
}

/// A space's tab row, pinned under the bar once the header has scrolled away.
class SpaceTabsDelegate extends SliverPersistentHeaderDelegate {
  const SpaceTabsDelegate(this.row);

  final Widget row;

  @override
  double get minExtent => SpaceTheme.tabsHeight;

  @override
  double get maxExtent => SpaceTheme.tabsHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => row;

  @override
  bool shouldRebuild(SpaceTabsDelegate oldDelegate) => true;
}

/// However short the tab's body is, the header can still scroll away and the tabs pin under the bar.
class SpaceTailFiller extends StatelessWidget {
  const SpaceTailFiller({super.key, required this.headerHeight, required this.barHeight, this.color});

  final double headerHeight;
  final double barHeight;

  /// The body's background, carried on under it; null leaves the page's.
  final Color? color;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final filler = SizedBox(
        height: math.max(
          0,
          constraints.viewportMainAxisExtent + headerHeight - barHeight - constraints.precedingScrollExtent,
        ),
      );
      final color = this.color;
      return SliverToBoxAdapter(
        child: color == null ? filler : ColoredBox(color: color, child: filler),
      );
    },
  );
}
