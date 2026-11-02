import 'dart:async';

import 'package:bili_core/api.dart' show DynamicItem;
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../../home/feed_inline_player.dart';
import '../../shared/theme.dart';
import '../card/dynamic_card.dart';

/// Asks for the next page once a list's end comes within a screen of the bottom. It reads the list's position after
/// the frame rather than a notification's copy: metrics notifications arrive in a microtask, and a page answered just
/// before one would be judged by the layout from before it landed.
class FollowPaging {
  FollowPaging({required this.canAsk, required this.ask});

  final bool Function() canAsk;
  final Future<void> Function() ask;

  bool _queued = false;
  bool _asking = false;
  bool _disposed = false;

  Widget listen(ScrollController controller, Widget scrollView) => NotificationListener<ScrollMetricsNotification>(
    onNotification: (notification) {
      if (notification.depth == 0) _soon(controller);
      return false;
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _soon(controller);
        return false;
      },
      child: scrollView,
    ),
  );

  void _soon(ScrollController controller) {
    if (_queued || _disposed) return;
    _queued = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _queued = false;
        _check(controller);
      })
      ..ensureVisualUpdate();
  }

  void _check(ScrollController controller) {
    if (_asking || _disposed || !controller.hasClients || !canAsk()) return;
    final position = controller.position;
    if (!position.hasContentDimensions || position.extentAfter > position.viewportDimension) return;
    _asking = true;
    unawaited(ask().whenComplete(() => _asking = false));
  }

  void dispose() => _disposed = true;
}

/// A post in 关注's lists and the face sheet: its card on white. The card draws the grey band under itself, so only
/// [bandAbove] (the 关注 list's first post, under the top section) adds one.
abstract final class FollowPosts {
  /// Builds a card in place of [DynamicCard]: tests give posts a height of their own.
  @visibleForTesting
  static Widget Function(DynamicItem item, FeedInlineHost host)? cardOverride;

  static Widget row(BuildContext context, DynamicItem item, FeedInlineHost host, {required bool bandAbove}) => Column(
    key: ValueKey('follow-post-${item.id}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (bandAbove)
        SizedBox(
          height: DynamicFeedTheme.band,
          child: ColoredBox(color: DynamicFeedTheme.colorsOf(context).bandFill),
        ),
      cardOverride?.call(item, host) ?? DynamicCard(item: item, inline: host),
    ],
  );
}

TextStyle followStyle(double size, Color colour, {FontWeight weight = FontWeight.w400, double? height}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  fontWeight: weight,
  color: colour,
  height: height,
  leadingDistribution: height == null ? null : TextLeadingDistribution.even,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

/// A press target that VoiceOver and ghosthand can press too: excluding the child's semantics drops the gesture's own
/// tap action, so the Semantics carries one.
class FollowTap extends StatelessWidget {
  const FollowTap({super.key, required this.label, required this.onTap, required this.child, this.selected});

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool? selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
  );
}

/// The sheet's ✕: two strokes with round ends across [size].
class FollowCross extends StatelessWidget {
  const FollowCross({super.key, required this.size, required this.stroke, required this.color});

  final double size;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CrossPainter(stroke: stroke, color: color),
  );
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter({required this.stroke, required this.color});

  final double stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = stroke / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(inset, inset), Offset(size.width - inset, size.height - inset), paint)
      ..drawLine(Offset(size.width - inset, inset), Offset(inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.stroke != stroke || oldDelegate.color != color;
}

/// A pink stadium with white words: 登录 and 重试.
class FollowPinkButton extends StatelessWidget {
  const FollowPinkButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.text,
    required this.height,
    required this.padX,
  });

  final String label;
  final VoidCallback onTap;
  final double text;
  final double height;
  final double padX;

  @override
  Widget build(BuildContext context) => FollowTap(
    label: label,
    onTap: onTap,
    child: Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padX),
      decoration: ShapeDecoration(color: BiliColors.colorsOf(context).pink, shape: StadiumBorder()),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: followStyle(text, BiliColors.onPink, weight: DynamicFeedTheme.buttonWeight)),
      ),
    ),
  );
}

/// Words over a pink button, centred: logged out, failed.
class FollowStateMessage extends StatelessWidget {
  const FollowStateMessage({super.key, required this.message, this.button});

  final String message;
  final Widget? button;

  @override
  Widget build(BuildContext context) {
    final style = followStyle(DynamicFeedTheme.stateText, DynamicFeedTheme.colorsOf(context).stateInk);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DynamicFeedTheme.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: style, strutStyle: BiliFonts.strutOf(context, style)),
          if (button case final button?) ...[const SizedBox(height: DynamicFeedTheme.stateGap), button],
        ],
      ),
    );
  }
}

/// Under a list of posts: the small spinner while the next page loads, 没有更多了, or why the page failed and 点击重试
/// (请求过于频繁，请稍后再试，点击重试 under risk control).
class FollowFooter extends StatelessWidget {
  const FollowFooter({
    super.key,
    required this.keyPrefix,
    required this.loading,
    required this.error,
    required this.isEnd,
    required this.onRetry,
  });

  final String keyPrefix;
  final bool loading;

  /// The failure's own words (`requestFailureMessage`).
  final String? error;
  final bool isEnd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(vertical: DynamicFeedTheme.footerPad);
    final style = followStyle(DynamicFeedTheme.footerText, DynamicFeedTheme.colorsOf(context).footerInk);
    final error = this.error;
    if (error != null && !loading) {
      return FollowTap(
        key: ValueKey('$keyPrefix-footer-retry'),
        label: '$error，点击重试',
        onTap: onRetry,
        child: Padding(
          padding: padding,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$error，', style: style),
                TextSpan(
                  text: '点击重试',
                  style: style.copyWith(color: BiliColors.colorsOf(context).link),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (isEnd && !loading) {
      return Padding(
        padding: padding,
        child: Text('没有更多了', key: ValueKey('$keyPrefix-end'), textAlign: TextAlign.center, style: style),
      );
    }
    return Padding(
      padding: padding,
      child: SizedBox(
        height: DynamicFeedTheme.spinnerRadius * 2,
        child: loading
            ? CupertinoActivityIndicator(key: ValueKey('$keyPrefix-more'), radius: DynamicFeedTheme.spinnerRadius)
            : null,
      ),
    );
  }
}
