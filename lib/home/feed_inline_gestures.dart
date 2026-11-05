import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../player_ui/player_gestures.dart' show PlayerGestureLayer;
import '../player_ui/player_hud.dart';
import 'feed_inline_player.dart';

/// Horizontal seeking and hold-to-speed-up over the focused video. Vertical drags belong to the feed.
class FeedInlineGestures extends StatefulWidget {
  const FeedInlineGestures({super.key, required this.playback, required this.child});

  final FeedInlinePlayback playback;
  final Widget child;

  @override
  State<FeedInlineGestures> createState() => _FeedInlineGesturesState();
}

class _FeedInlineGesturesState extends State<FeedInlineGestures> {
  double _down = 0;

  @override
  void didUpdateWidget(FeedInlineGestures oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) oldWidget.playback.cancelGesture();
  }

  @override
  void dispose() {
    widget.playback.cancelGesture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _FeedSeekRecognizer: GestureRecognizerFactoryWithHandlers<_FeedSeekRecognizer>(
          () => _FeedSeekRecognizer(debugOwner: this),
          (recognizer) => recognizer
            ..dragStartBehavior = DragStartBehavior.down
            ..onStart = ((details) {
              _down = details.localPosition.dx;
              playback.beginSeek(context.size?.width ?? 0);
            })
            ..onUpdate = ((details) => playback.updateSeek(details.localPosition.dx - _down))
            ..onEnd = ((_) => playback.endSeek())
            ..onCancel = playback.cancelGesture
            ..onPointerCancel = playback.cancelGesture,
        ),
        _FeedHoldRecognizer: GestureRecognizerFactoryWithHandlers<_FeedHoldRecognizer>(
          () => _FeedHoldRecognizer(debugOwner: this),
          (recognizer) => recognizer
            ..onLongPressStart = ((_) => playback.beginHold())
            ..onLongPressEnd = ((_) => playback.endHold())
            ..onStopped = playback.endHold,
        ),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [widget.child, PlayerGestureHud(chrome: playback.gestureChrome)],
      ),
    );
  }
}

class _FeedSeekRecognizer extends HorizontalDragGestureRecognizer {
  _FeedSeekRecognizer({super.debugOwner});

  VoidCallback? onPointerCancel;

  @override
  void handleEvent(PointerEvent event) {
    // Flutter reports an accepted drag's cancellation as onEnd; clear the seek before that can commit it.
    if (event is PointerCancelEvent) onPointerCancel?.call();
    super.handleEvent(event);
  }
}

class _FeedHoldRecognizer extends LongPressGestureRecognizer {
  _FeedHoldRecognizer({super.debugOwner}) : super(duration: PlayerGestureLayer.holdDelay);

  VoidCallback? onStopped;

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    onStopped?.call();
  }
}
