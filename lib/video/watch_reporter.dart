import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bili_core/logic.dart';

import '../app/app_environment.dart';
import '../playback/playback_controller.dart';
import '../player/bili_player.dart';
import 'history_outbox.dart';

/// Tells Bilibili how far the video page got, so it shows in the official app's 历史记录 and the next open resumes
/// there (VideoPageModel.swift's heartbeats): once playback starts, while playing whenever the position is 15 s on from
/// the last report, on pause, after a seek, at the end (-1) and when the playback closes, while [canReport] allows.
/// It belongs to the open made just before it: once a newer open (another part, 自动连播) moves the controller on, it
/// hears nothing more, and leaving reports its own video at the last position it saw. The speed test plays without
/// one, so it reports nothing. With an [outbox], a report that gets no answer waits there for the network.
class WatchReporter {
  WatchReporter({
    required PlaybackController controller,
    required this._client,
    required this._loggedIn,
    this.onProgress,
    this._outbox,
    this.ownerMid,
    Logger? logger,
  }) : _controller = controller,
       _open = controller.opens,
       _clientGeneration = _client.sessionGeneration,
       _logger = logger ?? Logger.shared {
    // After the controller's own subscription, so its phase already reflects each event.
    _events = controller.player.events.listen(_onEvent);
  }

  /// Logged in, or still unknown with a session in the jar: a launch account check that failed (no network) must not
  /// cost the whole session its history, and Bilibili ignores the heartbeats of a session that turns out dead. Never
  /// in a `--fake-account` run.
  static bool canReport(AppEnvironment environment) => !environment.fake && !environment.accountTransitioning && switch (environment.account) {
    LoggedIn() => true,
    AccountUnknown() => environment.cookies.all.containsKey('SESSDATA'),
    LoggedOut() || LoginExpired() => false,
  };

  final PlaybackController _controller;
  final BiliClient _client;
  final bool Function() _loggedIn;
  final HistoryOutbox? _outbox;
  final int? ownerMid;
  final int _clientGeneration;
  bool get _sameSession => _clientGeneration == _client.sessionGeneration;

  /// Every position reported, logged in or not, in seconds; a finished video reports its whole length.
  final void Function(String bvid, int cid, int seconds)? onProgress;
  final Logger _logger;
  final int _open;
  late final StreamSubscription<PlayerEvent> _events;

  ({String bvid, int cid})? _item;
  HeartbeatSchedule _schedule = HeartbeatSchedule();
  bool _started = false;

  /// The finished heartbeat went out; a later mark at the end position would overwrite it.
  bool _finishedSent = false;
  PlayerStatus _status = PlayerStatus.idle;

  /// The position at this open's last event, for a leave after a newer open has moved the controller on.
  double _position = 0;
  Future<void> _sending = Future.value();
  bool _left = false;

  bool get _isCurrent => _controller.opens == _open;

  void _onEvent(PlayerEvent event) {
    if (!_isCurrent) return;
    final item = _playing();
    if (item == null) return;
    if (item != _item) {
      _item = item;
      _schedule = HeartbeatSchedule();
      _started = false;
      _finishedSent = false;
    }
    _position = _controller.currentSeconds;
    switch (event) {
      case StatusChanged(:final status):
        _status = status;
        // Statuses while a load starts or reloads are the player's, not the viewer's.
        if (_controller.phase != PlaybackPhase.playing) return;
        switch (status) {
          case PlayerStatus.playing when !_started:
            _started = true;
            _mark(item);
          case PlayerStatus.paused when _started && !_finishedSent:
            _mark(item);
          case PlayerStatus.ended when _started:
            _finishedSent = true;
            _send(item, HeartbeatSchedule.finished);
          default:
            break;
        }
      case PositionChanged(:final seconds):
        if (!_started || _finishedSent) return;
        final played = _schedule.tick(position: seconds, playing: _status == PlayerStatus.playing);
        if (played != null) _send(item, played);
      default:
        break;
    }
  }

  /// A seek the user made on the page; reported at the position asked for.
  void seeked(double seconds) {
    final item = _item;
    if (!_isCurrent || item == null || item != _playing() || !_started) return;
    _position = seconds;
    _finishedSent = false;
    _send(item, _schedule.mark(position: seconds));
  }

  /// The page is going: the last position goes out, and the reports sent so far are awaited.
  Future<void> leave() {
    if (_left) return _sending;
    _left = true;
    final item = _item;
    if (item != null && _started && !_finishedSent) {
      _send(item, _schedule.mark(position: _isCurrent ? _controller.currentSeconds : _position));
    }
    unawaited(_events.cancel());
    return _sending;
  }

  ({String bvid, int cid})? _playing() {
    final video = _controller.video;
    final page = _controller.page;
    return video == null || page == null ? null : (bvid: video.bvid, cid: page.cid);
  }

  void _mark(({String bvid, int cid}) item) => _send(item, _schedule.mark(position: _controller.currentSeconds));

  /// One after another, so a late answer never reorders the history Bilibili keeps.
  void _send(({String bvid, int cid}) item, int played) {
    if (!_sameSession) return;
    final duration = _controller.page?.duration ?? 0;
    onProgress?.call(item.bvid, item.cid, played == HeartbeatSchedule.finished ? duration : played);
    if (!_loggedIn()) return;
    bool current() => _sameSession && _loggedIn();
    Future<void> beat() async {
      if (!current()) return;
      await _client.runInSession(_clientGeneration,
          () => _client.heartbeat(bvid: item.bvid, cid: item.cid, playedTime: played));
    }
    // Handed to the outbox at once, whose lane keeps the order: a page opening this part next must know a report of
    // it is on its way.
    final queued = _outbox
        ?.send(item.bvid, item.cid, played, beat, ownerMid: ownerMid, isCurrent: current)
        .then<Object?>((_) => null, onError: (Object error) => error);
    _sending = _sending.then((_) async {
      Object? failure = await queued;
      if (queued == null) {
        try {
          await beat();
        } catch (error) {
          failure = error;
        }
      }
      if (failure == null) return;
      if (failure is BiliSessionChangedError) return;
      // The Windows guard refuses every beat and logs the first itself.
      if (failure is BiliAPIError && failure.code == GuardedTransport.readOnlyCode) return;
      _logger.warn(LogCategory.api, 'heartbeat failed', {'played': played, 'error': '$failure'});
    });
  }
}
