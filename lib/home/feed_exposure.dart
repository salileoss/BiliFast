import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Records an exposure only after half the card has stayed visible for a second.
/// Building a cached/offscreen card, or fetching its metadata, does not count.
class FeedExposure extends StatefulWidget {
  const FeedExposure({
    super.key,
    required this.child,
    required this.viewport,
    required this.visibilityChanges,
    required this.onSeen,
    this.active = true,
    this.isActive,
  });

  final Widget child;
  final Rect? Function() viewport;
  final Listenable visibilityChanges;
  final VoidCallback onSeen;
  final bool active;
  final bool Function()? isActive;

  @override
  State<FeedExposure> createState() => _FeedExposureState();
}

class _FeedExposureState extends State<FeedExposure> with WidgetsBindingObserver {
  Timer? _waiting;
  bool _reported = false;
  bool _queued = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.visibilityChanges.addListener(_schedule);
  }

  @override
  void didUpdateWidget(FeedExposure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.visibilityChanges, widget.visibilityChanges)) {
      oldWidget.visibilityChanges.removeListener(_schedule);
      widget.visibilityChanges.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (_queued || !mounted) return;
    _queued = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _queued = false;
        if (mounted) _sample();
      })
      ..ensureVisualUpdate();
  }

  bool _visible() {
    if (!_foreground || !widget.active || !(widget.isActive?.call() ?? true)) return false;
    final area = widget.viewport();
    final box = context.findRenderObject();
    if (area == null || area.isEmpty || box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) {
      return false;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.overlaps(area)) return false;
    final visible = rect.intersect(area);
    return visible.width * visible.height >= rect.width * rect.height / 2;
  }

  void _sample() {
    if (!_visible()) {
      _waiting?.cancel();
      _waiting = null;
      _reported = false;
      return;
    }
    if (_reported || _waiting != null) return;
    _waiting = Timer(const Duration(seconds: 1), () {
      _waiting = null;
      if (!mounted || !_visible()) return;
      _reported = true;
      widget.onSeen();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _schedule();
    } else {
      _sample();
    }
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return widget.child;
  }

  @override
  void dispose() {
    _waiting?.cancel();
    widget.visibilityChanges.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
