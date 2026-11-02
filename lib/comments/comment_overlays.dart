import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../shared/theme.dart';
import 'comment_callbacks.dart';
import 'comments_model.dart';
import 'composer.dart';
import 'composer_model.dart';
import 'picture_viewer.dart';
import 'thread_view.dart';

sealed class CommentOverlay {
  const CommentOverlay();
}

final class ComposeOverlay extends CommentOverlay {
  const ComposeOverlay(this.target, {this.emotes = false});

  final ReplyTarget target;

  /// Opens on the emote panel rather than the keyboard.
  final bool emotes;
}

final class PicturesOverlay extends CommentOverlay {
  const PicturesOverlay(this.pictures, this.index);

  final List<CommentPicture> pictures;
  final int index;
}

final class DeleteOverlay extends CommentOverlay {
  const DeleteOverlay(this.comment);

  final Comment comment;
}

/// What [CommentOverlays] has up besides the thread, so the page's back closes it first.
class CommentOverlayController extends ValueNotifier<CommentOverlay?> {
  CommentOverlayController() : super(null);

  void compose(ReplyTarget target, {bool emotes = false}) => value = ComposeOverlay(target, emotes: emotes);

  void viewPictures(List<CommentPicture> pictures, int index) => value = PicturesOverlay(pictures, index);

  void confirmDelete(Comment comment) => value = DeleteOverlay(comment);

  void close() => value = null;
}

/// The comments' in-page overlays, in the page's Stack: 评论详情 rising from the bottom over the tab row and the list,
/// up to [threadTop] (an edge swipe lowers it with the finger and closes it), and over the whole page the composer,
/// the picture viewer and the delete confirm. Lets touches through when nothing is up.
class CommentOverlays extends StatefulWidget {
  const CommentOverlays({
    super.key,
    required this.model,
    required this.controller,
    required this.callbacks,
    required this.threadTop,
  });

  /// Null until the video's aid is known.
  final CommentsModel? model;
  final CommentOverlayController controller;
  final CommentCallbacks callbacks;

  /// The small player's bottom edge: the thread covers everything below it.
  final double threadTop;

  @override
  State<CommentOverlays> createState() => _CommentOverlaysState();
}

class _CommentOverlaysState extends State<CommentOverlays> with TickerProviderStateMixin {
  /// How far up 评论详情 is: 1 in place, 0 off the bottom. The finger sets it directly, so it carries no curve of its
  /// own; the rise and the fall pass theirs to each run.
  late final AnimationController _thread = AnimationController(vsync: this);

  /// The page's PopScope holds while the thread is open, which turns CupertinoPageRoute's edge swipe off: this one
  /// takes the same edge and lowers the thread instead.
  late final HorizontalDragGestureRecognizer _swipe = HorizontalDragGestureRecognizer(debugOwner: this)
    ..onStart = _swipeStarted
    ..onUpdate = _swipeMoved
    ..onEnd = _swipeEnded
    ..onCancel = _swipeCancelled;

  /// The thread on screen: the model's, or its last state while it slides away.
  ThreadState? _shownThread;

  /// The model's thread was open when last seen, so its next one rises even if the last is still sliding away.
  bool _modelOpen = false;

  /// Sliding off the bottom after the model closed it.
  bool _away = false;
  bool _swiping = false;

  late final AnimationController _front = AnimationController(vsync: this);
  late final CurvedAnimation _fade = CurvedAnimation(parent: _front, curve: Curves.easeOut);
  late final CurvedAnimation _settle = CurvedAnimation(
    parent: _front,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The composer, viewer or confirm on screen: the controller's, or the one going away after a close.
  CommentOverlay? _frontShown;

  /// Bumped for every overlay put up, keying it: one put up again while it goes away starts fresh.
  int _opening = 0;

  ComposerModel? _composer;
  ComposeOverlay? _composerFor;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    final thread = widget.model?.thread;
    _shownThread = thread;
    _modelOpen = thread != null;
    _thread.value = thread == null ? 0 : 1;
    _frontShown = widget.controller.value;
    if (_frontShown != null) _front.value = 1;
    _syncComposer();
    widget.model?.addListener(_modelChanged);
    widget.controller.addListener(_controllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _thread
      ..duration = _still ? Duration.zero : CommentOverlayTheme.threadRise
      ..reverseDuration = _still ? Duration.zero : CommentOverlayTheme.threadFall;
  }

  @override
  void didUpdateWidget(CommentOverlays oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_controllerChanged);
      widget.controller.addListener(_controllerChanged);
    }
    if (!identical(oldWidget.model, widget.model)) {
      oldWidget.model?.removeListener(_modelChanged);
      widget.model?.addListener(_modelChanged);
      // Another video's comments: the old thread goes at once, with no slide.
      _swiping = false;
      _away = false;
      _modelOpen = false;
      _shownThread = null;
      _thread.value = 0;
      if (widget.model?.thread != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _modelChanged();
        });
      }
    }
    _syncComposer();
  }

  @override
  void dispose() {
    widget.model?.removeListener(_modelChanged);
    widget.controller.removeListener(_controllerChanged);
    _swipe.dispose();
    _fade.dispose();
    _settle.dispose();
    _front.dispose();
    _thread.dispose();
    _composer?.dispose();
    super.dispose();
  }

  void _modelChanged() {
    final thread = widget.model?.thread;
    final reopened = thread != null && !_modelOpen;
    _modelOpen = thread != null;
    if (thread == null) {
      if (_shownThread == null) return;
      if (_thread.value == 0 && !_thread.isAnimating) {
        setState(_dropThread);
      } else if (!_away) {
        _slideDown();
      }
      return;
    }
    setState(() => _shownThread = thread);
    if (reopened) _rise();
  }

  void _dropThread() {
    _shownThread = null;
    _away = false;
    _swiping = false;
  }

  void _rise() {
    _swiping = false;
    if (_away) setState(() => _away = false);
    unawaited(_thread.animateTo(1, curve: Curves.easeOutCubic));
  }

  void _slideDown() {
    _swiping = false;
    if (!_away) setState(() => _away = true);
    _thread.animateBack(0, curve: Curves.easeOutCubic).whenCompleteOrCancel(() {
      // Turned around by a thread opened on the way.
      if (!mounted || _thread.value > 0 || !_away) return;
      if (widget.model?.thread == null && _shownThread != null) setState(_dropThread);
    });
  }

  void _edgeDown(PointerDownEvent event) {
    if (_shownThread != null && !_away && widget.model?.thread != null) _swipe.addPointer(event);
  }

  double get _threadHeight => math.max(0, (context.size?.height ?? 0) - widget.threadTop);

  void _swipeStarted(DragStartDetails details) {
    if (_shownThread == null || _away || widget.model?.thread == null) return;
    _thread.stop();
    _swiping = true;
  }

  /// The finger's travel to the right lowers the thread by as much.
  void _swipeMoved(DragUpdateDetails details) {
    final height = _threadHeight;
    if (!_swiping || height <= 0) return;
    _thread.value = (_thread.value - details.primaryDelta! / height).clamp(0.0, 1.0);
  }

  void _swipeEnded(DragEndDetails details) {
    if (!_swiping) return;
    _swiping = false;
    final width = context.size?.width ?? 0;
    final speed = width > 0 ? details.velocity.pixelsPerSecond.dx / width : 0.0;
    final close = speed.abs() >= CommentOverlayTheme.threadFlingWidths
        ? speed > 0
        : 1 - _thread.value > CommentOverlayTheme.threadCloseShare;
    if (!close) {
      _rise();
      return;
    }
    // Closed in the model now rather than once it is down: replies tapped through the sliding thread open a thread
    // of their own, which must rise instead of being closed by this slide's end.
    widget.model?.closeThread();
    if (!_away) _slideDown();
  }

  void _swipeCancelled() {
    if (_swiping) _rise();
  }

  void _controllerChanged() {
    _syncComposer();
    final next = widget.controller.value;
    if (next == null) {
      _closeFront();
      return;
    }
    final wasShown = _frontShown != null;
    setState(() {
      _frontShown = next;
      _opening++;
    });
    if (next is ComposeOverlay) {
      // The composer moves its own sheet with the keyboard.
      _front.value = 1;
      return;
    }
    _timeFront(next);
    unawaited(_front.forward(from: wasShown ? null : 0));
  }

  void _timeFront(CommentOverlay overlay) {
    final (shown, hidden) = switch (overlay) {
      PicturesOverlay() => (CommentOverlayTheme.viewerFade, CommentOverlayTheme.viewerFade),
      _ => (CommentOverlayTheme.confirmIn, CommentOverlayTheme.confirmOut),
    };
    _front
      ..duration = _still ? Duration.zero : shown
      ..reverseDuration = _still ? Duration.zero : hidden;
  }

  void _closeFront() {
    final shown = _frontShown;
    if (shown == null) return;
    if (shown is ComposeOverlay) {
      _front.value = 0;
      setState(() => _frontShown = null);
      return;
    }
    setState(() {});
    _timeFront(shown);
    _front.reverse().whenCompleteOrCancel(() {
      if (!mounted || !_front.isDismissed || widget.controller.value != null) return;
      setState(() => _frontShown = null);
    });
  }

  /// One composer model per opening, for this video's comments; the one before goes once its composer is off the tree.
  void _syncComposer() {
    final overlay = widget.controller.value;
    final model = widget.model;
    if (_composer case final composer? when !identical(overlay, _composerFor) || !identical(composer.comments, model)) {
      _composer = null;
      _composerFor = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => composer.dispose());
    }
    if (_composer == null && overlay is ComposeOverlay && model != null) {
      _composer = ComposerModel(comments: model, target: overlay.target)..showingEmotes = overlay.emotes;
      _composerFor = overlay;
    }
  }

  /// Closes [overlay], unless another has taken its place since.
  void _closeIf(CommentOverlay overlay) {
    if (identical(widget.controller.value, overlay)) widget.controller.close();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final thread = _shownThread;
    final front = _frontShown;
    final frontLayer = front == null ? null : _frontLayer(front);
    return Stack(
      children: [
        if (model != null && thread != null) ...[
          Positioned(
            key: const ValueKey('comment-thread'),
            left: 0,
            right: 0,
            top: widget.threadTop,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _thread,
              builder: (context, child) =>
                  FractionalTranslation(translation: Offset(0, 1 - _thread.value), child: child),
              child: IgnorePointer(
                ignoring: _away,
                child: ExcludeSemantics(
                  excluding: _away,
                  child: ColoredBox(
                    color: CommentOverlayTheme.colorsOf(context).threadFill,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: ThreadView(model: model, thread: thread, callbacks: widget.callbacks),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!_away)
            // The whole left edge, the player's included: with the thread open the edge swipe closes it first.
            Positioned(
              key: const ValueKey('comment-thread-edge'),
              left: 0,
              top: 0,
              bottom: 0,
              width: math.max(BiliMetrics.swipeBackEdge, MediaQuery.paddingOf(context).left),
              child: Listener(behavior: HitTestBehavior.translucent, onPointerDown: _edgeDown),
            ),
        ],
        if (frontLayer != null) Positioned.fill(key: const ValueKey('comment-front'), child: frontLayer),
      ],
    );
  }

  Widget? _frontLayer(CommentOverlay shown) {
    void close() => _closeIf(shown);
    final Widget? child = switch (shown) {
      ComposeOverlay() => switch (_composer) {
        final composer? => Composer(key: ObjectKey(composer), model: composer, onClose: close, top: widget.threadTop),
        null => null,
      },
      PicturesOverlay(:final pictures, :final index) => FadeTransition(
        opacity: _fade,
        child: PictureViewer(key: ValueKey(_opening), pictures: pictures, initialIndex: index, onClose: close),
      ),
      DeleteOverlay(:final comment) => _DeleteConfirm(
        motion: _settle,
        onCancel: close,
        onConfirm: () {
          close();
          if (widget.model case final model?) unawaited(model.delete(comment));
        },
      ),
    };
    if (child == null) return null;
    final open = identical(widget.controller.value, shown);
    return IgnorePointer(
      ignoring: !open,
      child: ExcludeSemantics(
        excluding: !open,
        // Up, it is modal: VoiceOver reads only it, not the page under it.
        child: BlockSemantics(blocking: open, child: child),
      ),
    );
  }
}

/// 删除评论 / 确定删除这条评论吗？ with 取消 and 删除, in the unfollow confirm's alert: white over a dim, settling from
/// slightly large as it fades in. A tap on the dim cancels.
class _DeleteConfirm extends StatelessWidget {
  const _DeleteConfirm({required this.motion, required this.onConfirm, required this.onCancel});

  final Animation<double> motion;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: CommentOverlayTheme.alertButtonText,
      color: CommentOverlayTheme.colorsOf(context).alertTitle,
      decoration: TextDecoration.none,
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: motion,
            child: Semantics(
              button: true,
              label: '取消',
              onTap: onCancel,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('comment-delete-dim'),
                behavior: HitTestBehavior.opaque,
                onTap: onCancel,
                child: const ColoredBox(color: CommentOverlayTheme.alertDim),
              ),
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, child) => Opacity(
              opacity: motion.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: CommentOverlayTheme.alertStartScale - (CommentOverlayTheme.alertStartScale - 1) * motion.value,
                child: child,
              ),
            ),
            child: _DeleteAlert(onConfirm: onConfirm, onCancel: onCancel),
          ),
        ),
      ],
    ),
  );
}

class _DeleteAlert extends StatelessWidget {
  const _DeleteAlert({required this.onConfirm, required this.onCancel});

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('comment-delete-alert'),
    width: CommentOverlayTheme.alertWidth,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: BiliColors.colorsOf(context).card,
      borderRadius: BorderRadius.circular(CommentOverlayTheme.alertRadius),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BiliMetrics.sectionGap,
            CommentOverlayTheme.alertTitlePadTop,
            BiliMetrics.sectionGap,
            CommentOverlayTheme.alertMessagePadBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '删除评论',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: BiliFonts.family,
                  fontSize: CommentOverlayTheme.alertTitleText,
                  fontWeight: FontWeight.w500,
                  color: CommentOverlayTheme.colorsOf(context).alertTitle,
                ),
              ),
              const SizedBox(height: CommentOverlayTheme.alertMessageGap),
              Text(
                '确定删除这条评论吗？',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: BiliFonts.family,
                  fontSize: CommentOverlayTheme.alertMessageText,
                  color: CommentOverlayTheme.colorsOf(context).alertMessage,
                ),
              ),
            ],
          ),
        ),
        Container(height: BiliMetrics.panelHairline, color: BiliColors.colorsOf(context).divider),
        SizedBox(
          height: CommentOverlayTheme.alertButtonHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _AlertButton(label: '取消', color: CommentOverlayTheme.colorsOf(context).alertCancel, onTap: onCancel),
              ),
              Container(width: BiliMetrics.panelHairline, color: BiliColors.colorsOf(context).divider),
              Expanded(
                child: _AlertButton(
                  label: '删除',
                  color: CommentOverlayTheme.colorsOf(context).alertDelete,
                  onTap: onConfirm,
                  strong: true,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AlertButton extends StatefulWidget {
  const _AlertButton({required this.label, required this.color, required this.onTap, this.strong = false});

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool strong;

  @override
  State<_AlertButton> createState() => _AlertButtonState();
}

class _AlertButtonState extends State<_AlertButton> {
  var _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: ValueKey('comment-delete-${widget.label}'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _down ? BiliColors.colorsOf(context).pressedFill : BiliColors.colorsOf(context).card,
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontFamily: BiliFonts.family,
            fontSize: CommentOverlayTheme.alertButtonText,
            fontWeight: widget.strong ? FontWeight.w500 : FontWeight.w400,
            color: widget.color,
          ),
        ),
      ),
    ),
  );
}
