import 'dart:async';

import '../home/feed_preferences.dart';
import '../playback/playback_controller.dart';
import '../player/bili_player.dart';
import 'local_watch_progress.dart';

/// Local recommendation signals only. Server watch-history reporting is separate.
class LocalWatchReporter {
  LocalWatchReporter({
    required this.controller,
    required this.preferences,
    required this.accountMid,
    required this.isCurrent,
    required this.canCount,
    this.ownerMid = 0,
  }) {
    _events = controller.player.events.listen(_onEvent);
  }

  final PlaybackController controller;
  final FeedPreferences preferences;
  final int? accountMid;
  final int ownerMid;
  final bool Function() isCurrent;
  final bool Function() canCount;
  final _progress = <(String, int), LocalWatchProgress>{};
  late final StreamSubscription<PlayerEvent> _events;
  LocalWatchProgress? _current;
  (String, int)? _item;
  int _uploader = 0;
  PlayerStatus _status = PlayerStatus.idle;
  bool _disposed = false;

  void _onEvent(PlayerEvent event) {
    if (_disposed || !isCurrent()) return;
    if (event case StatusChanged(:final status)) _status = status;
    final video = controller.video;
    final page = controller.page;
    if (video == null || page == null || controller.phase != PlaybackPhase.playing) {
      suspend();
      return;
    }
    final item = (video.bvid, page.cid);
    if (_item != item) {
      suspend();
      _item = item;
      // A single page's endless autoplay is bounded too.
      if (_progress.length >= 20 && !_progress.containsKey(item)) _progress.remove(_progress.keys.first);
      _current = _progress.putIfAbsent(item, LocalWatchProgress.new)..discontinuity();
    }
    _uploader = controller.detail?.owner.mid ?? ownerMid;
    switch (event) {
      case StatusChanged(:final status):
        _status = status;
        suspend();
      case RateChanged():
        _current?.discontinuity();
      case PositionChanged(:final seconds, :final hostMs, :final rate):
        final progress = _current!;
        final result = progress.sample(
          position: seconds,
          hostMs: hostMs,
          rate: rate,
          duration: page.duration.toDouble(),
          active: _status == PlayerStatus.playing && canCount(),
        );
        if (result != null) _save(result);
      default:
        break;
    }
  }

  void _save(({double seconds, bool completed}) batch) {
    final item = _item;
    if (item == null || !isCurrent()) return;
    preferences.recordWatch(
      accountMid: accountMid,
      bvid: item.$1,
      ownerMid: _uploader,
      seconds: batch.seconds,
      completed: batch.completed,
    );
  }

  /// Called immediately on focus/visibility changes, before an async native pause.
  void suspend() {
    final progress = _current;
    if (progress == null) return;
    final batch = progress.flush();
    if (batch != null) _save(batch);
    progress.discontinuity();
  }

  void dispose() {
    if (_disposed) return;
    suspend();
    _disposed = true;
    unawaited(_events.cancel());
  }
}
