import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import 'post_author.dart';

/// Why the post didn't load, over 搜索's pink-rimmed 重试 when asking again could help.
class PostFailure extends StatelessWidget {
  const PostFailure({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DynamicPostTheme.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            key: const ValueKey('post-failed'),
            textAlign: TextAlign.center,
            style: postStyle(DynamicPostTheme.stateText, DynamicPostTheme.colorsOf(context).stateInk),
          ),
          if (retry != null) ...[const SizedBox(height: DynamicPostTheme.stateGap), _RetryPill(onTap: retry)],
        ],
      ),
    );
  }
}

class _RetryPill extends StatefulWidget {
  const _RetryPill({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RetryPill> createState() => _RetryPillState();
}

class _RetryPillState extends State<_RetryPill> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '重试',
    onTap: widget.onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('post-retry'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? DynamicPostTheme.retryPressedScale : 1,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : DynamicPostTheme.retryPressMotion,
        curve: Curves.easeOut,
        child: Container(
          height: DynamicPostTheme.retryHeight,
          padding: const EdgeInsets.symmetric(horizontal: DynamicPostTheme.retryPadX),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: DynamicPostTheme.colorsOf(context).retryInk, width: DynamicPostTheme.retryRim),
            ),
          ),
          child: Text('重试', style: postStyle(DynamicPostTheme.retryText, DynamicPostTheme.colorsOf(context).retryInk)),
        ),
      ),
    ),
  );
}
