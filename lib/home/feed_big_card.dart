import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bili_core/logic.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:lottie/lottie.dart';

import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../danmaku/danmaku_layer.dart';
import '../device/orientation.dart' show Presentation;
import '../player_ui/landscape_chrome.dart' show DanmakuGlyph;
import '../player_ui/player_loading.dart';
import '../shared/cover_placeholder.dart';
import '../shared/cover_preset.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/actions/actions_model.dart' show ActionsModel;
import '../video/page_playback.dart';
import '../video/video_route.dart';
import 'feed_card.dart' show FeedCardView;
import 'feed_dislike.dart';
import 'feed_inline_gestures.dart';
import 'feed_inline_player.dart';
import 'feed_model.dart' show CardDislike, feedLogFields;
import 'feed_more_sheet.dart';

/// The big card's sizes, for the feed's layout and its covers.
abstract final class FeedBigCardSize {
  /// The video box on a card [width] wide: what its cover is decoded to cover, and a precache's size.
  static Size video(double width) => Size(width, width / FeedBigCardTheme.videoAspect);

  /// The whole card with a title of [lines] lines.
  static double height(double width, {int lines = 2}) =>
      video(width).height +
      FeedBigCardTheme.titlePad * 2 +
      FeedBigCardTheme.titleLine * lines +
      FeedBigCardTheme.bylineGap +
      FeedBigCardTheme.bylineLine;
}

/// 推荐's big card (`large_cover_v9`, 122-126): full width, its video playing inline and muted while
/// [FeedInlineHost] picks it, danmaku over it, 弹 and the speaker bottom right; on the cover a ▶ and the duration. Under
/// it the title, 👍 with its count and ⋮. A tap on the video or the title opens the page, taking the running video
/// with it ([onOpen] gets the playback, or the position to start from when it has none).
class FeedBigCardView extends StatefulWidget {
  const FeedBigCardView({
    super.key,
    required this.card,
    required this.onOpen,
    required this.onWatchLater,
    this.host,
    this.dislike,
    this.onDislike,
    this.onUndo,
    this.onReason,
  });

  final FeedCard card;

  /// Opens the page; done once it has gone again.
  final Future<void> Function(PagePlayback? playback, double? start) onOpen;
  final VoidCallback onWatchLater;

  /// Null draws the card still (a refresh's hand-off fading it out).
  final FeedInlineHost? host;
  final CardDislike? dislike;
  final ValueChanged<FeedReason>? onDislike;
  final VoidCallback? onUndo;
  final ValueChanged<FeedReason>? onReason;

  static const likeAsset = 'assets/images/card/inline_like.png';
  static const likedAsset = 'assets/lottie/feed_like.json';
  static const mutedAsset = 'assets/images/card/inline_muted.png';
  static const soundAsset = 'assets/images/card/inline_sound.png';
  static const playAsset = 'assets/images/player/paused_play.png';

  /// Gets [url] ready as the card asks for it: the player box's preset, which the page's cover shares.
  static Future<bool> precacheCover(BuildContext context, String? url, Size size) =>
      RemoteImage.precache(context, url, size: size, cover: true, preset: CoverPreset.player);

  @override
  State<FeedBigCardView> createState() => _FeedBigCardViewState();
}

class _FeedBigCardViewState extends State<FeedBigCardView> with TickerProviderStateMixin implements FeedInlineCard {
  final _videoKey = GlobalKey();
  late final _likeMotion = AnimationController(vsync: this, duration: FeedBigCardTheme.likeMotion, value: 1);
  AppServices? _services;
  FeedInlinePlayback? _inline;
  Widget? _view;
  Object? _viewOf;
  double? _height;

  bool _liked = false;
  int _likes = 0;
  bool _liking = false;
  VideoDetail? _detail;

  bool get _live => widget.host != null && widget.dislike == null;

  @override
  void initState() {
    super.initState();
    _likes = widget.card.big?.likes ?? 0;
    _liked = widget.card.big?.liked ?? false;
    FeedInlineChoices.sound.addListener(_choiceChanged);
    FeedInlineChoices.danmaku.addListener(_choiceChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services != null) return;
    _services = AppScope.of(context);
    if (_live) {
      widget.host!.register(this);
      unawaited(_loadMetadata());
    }
  }

  /// Official two-column cards often omit the face and upload date. Resolve only
  /// cards built near the viewport; the host reuses the answer when scrolling back.
  Future<void> _loadMetadata() async {
    final card = widget.card;
    if (card.published > 0 && card.ownerFace.isNotEmpty) return;
    try {
      final detail = await widget.host!.metadata.putIfAbsent(
        card.bvid,
        () => _services!.environment.client.videoDetail(bvid: card.bvid),
      );
      if (!mounted || widget.card.bvid != card.bvid || detail.bvid != card.bvid) return;
      setState(() {
        _detail = detail;
        if (card.big == null && !_liking && !_liked) _likes = detail.stat.like;
      });
    } catch (error) {
      widget.host?.metadata.remove(card.bvid);
      Logger.shared.warn(LogCategory.ui, 'feed metadata failed', feedLogFields(error));
    }
  }

  @override
  void didUpdateWidget(FeedBigCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.host != null && oldWidget.dislike == null;
    if (!identical(oldWidget.host, widget.host) || was != _live) {
      if (was) oldWidget.host!.unregister(this);
      if (_live) {
        widget.host!.register(this);
      } else {
        _letGo();
      }
    }
  }

  @override
  void dispose() {
    if (_live) widget.host!.unregister(this);
    _letGo();
    FeedInlineChoices.sound.removeListener(_choiceChanged);
    FeedInlineChoices.danmaku.removeListener(_choiceChanged);
    _likeMotion.dispose();
    super.dispose();
  }

  void _letGo() {
    final inline = _inline;
    if (inline == null) return;
    _inline = null;
    inline
      ..removeListener(_inlineChanged)
      ..dispose();
  }

  void _choiceChanged() {
    if (mounted) setState(() {});
  }

  void _inlineChanged() {
    if (mounted) setState(() {});
  }

  @override
  Rect? videoRect() {
    final box = _videoKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void inlinePlay() {
    if (!_live || !mounted) return;
    (_inline ??= _makeInline()).play();
  }

  @override
  void inlinePause() => _inline?.pause();

  FeedInlinePlayback _makeInline() {
    final host = widget.host!;
    final bvid = widget.card.bvid;
    return FeedInlinePlayback(
      services: _services!,
      video: InlineVideo.of(widget.card, detail: _detail),
      startAt: () => host.positions[bvid] ?? 0,
      released: (seconds) => host.positions[bvid] = seconds,
    )..addListener(_inlineChanged);
  }

  Future<void> _open() async {
    final inline = _inline;
    final playback = inline?.handOver();
    final card = widget.card;
    final start = playback == null ? widget.host?.positions[card.bvid] : null;
    // Nothing to hand over yet (still starting) or failed: the page loads it, and the card's own load stops.
    if (playback == null) inline?.release();
    await widget.onOpen(playback, start);
    if (playback == null) return;
    // Back on 首页 the card plays again from where the page left the video (124), unless 选集 or 自动连播 moved the
    // page on to another part or video.
    final ({String bvid, int? cid, double? at}) left = playback.closed
        ? (bvid: playback.restartRoute.bvid, cid: playback.restartRoute.cid, at: playback.restartRoute.start)
        : (
            bvid: playback.controller?.video?.bvid ?? playback.bvid,
            cid: playback.controller?.page?.cid,
            at: playback.controller?.currentSeconds,
          );
    final at = left.at;
    final samePart = left.bvid == card.bvid && (card.cid <= 0 || left.cid == null || left.cid == card.cid);
    if (at != null && samePart) widget.host?.positions[card.bvid] = at;
  }

  Future<void> _more() async {
    final card = widget.card;
    final choice = await showFeedMoreSheet(context, card);
    final dislike = card.dislike;
    switch (choice) {
      case null:
        return;
      case FeedMoreChoice.watchLater:
        widget.onWatchLater();
      case FeedMoreChoice.dislikeVideo:
        if (dislike?.video case final reason?) widget.onDislike?.call(reason);
      case FeedMoreChoice.dislikeUploader:
        if (dislike?.uploader case final reason?) widget.onDislike?.call(reason);
    }
  }

  Future<void> _reasons() async {
    final dislike = widget.card.dislike;
    if (dislike == null) return;
    final picked = await showFeedReasonsSheet(context, dislike);
    if (picked != null) widget.onReason?.call(picked);
  }

  /// 👍 as the page's: shown at once, put back if Bilibili refuses; logged out it asks for the login instead.
  Future<void> _like() async {
    final services = _services!;
    final environment = services.environment;
    if (environment.account case LoggedOut() || LoginExpired()) {
      await services.loginGate.request(context);
      return;
    }
    if (_liking) return;
    _liking = true;
    final on = !_liked;
    setState(() => _setLiked(on));
    if (on) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _likeMotion.value = 1;
      } else {
        unawaited(_likeMotion.forward(from: 0));
      }
    }
    final card = widget.card;
    try {
      await services.pageApi.like(aid: card.aid, bvid: card.bvid, on: on);
    } catch (error) {
      Logger.shared.warn(LogCategory.api, 'feed like failed', feedLogFields(error));
      if (mounted) setState(() => _setLiked(!on));
      if (!mounted) return;
      if (error is BiliError && error.needsLogin) {
        await services.loginGate.request(context);
      } else {
        showToast(context, ActionsModel.failureMessage(error));
      }
    } finally {
      _liking = false;
    }
  }

  void _setLiked(bool on) {
    if (on == _liked) return;
    _liked = on;
    _likes += on ? 1 : -1;
  }

  @override
  Widget build(BuildContext context) {
    final dislike = widget.dislike;
    final data = widget.card.dislike;
    final offersReasons = data != null && (data.tiles.isNotEmpty || data.repeated != null);
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : FeedDislikeTheme.fadeIn,
      child: dislike == null
          ? KeyedSubtree(key: const ValueKey('feed-card-live'), child: _card(context))
          : LayoutBuilder(
              key: const ValueKey('feed-card-disliked'),
              builder: (context, constraints) => SizedBox(
                height: _height ?? FeedBigCardSize.height(constraints.maxWidth),
                child: FeedDislikedCard(
                  inline: true,
                  card: widget.card,
                  onUndo: () => widget.onUndo?.call(),
                  onReasons: offersReasons ? () => unawaited(_reasons()) : null,
                ),
              ),
            ),
    );
  }

  Widget _card(BuildContext context) {
    final card = widget.card;
    final inline = _inline;
    final playing = inline != null && inline.wanted && inline.shown;
    return _Measured(
      onHeight: (height) => _height = height,
      child: ColoredBox(
        color: BiliColors.colorsOf(context).card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(FeedBigCardTheme.radius),
              child: AspectRatio(
                key: _videoKey,
                aspectRatio: FeedBigCardTheme.videoAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _opens(
                      label: '视频画面',
                      key: const ValueKey('big-card-open'),
                      child: playing
                          ? FeedInlineGestures(playback: inline, child: _video(context, inline, playing))
                          : _video(context, inline, playing),
                    ),
                    // The controls' own elements over the excluded one: touches pass through to the detectors under.
                    if (playing) ...[
                      _semantics(
                        key: const ValueKey('big-card-danmaku-semantics'),
                        label: FeedInlineChoices.danmaku.value ? '关闭弹幕' : '开启弹幕',
                        onTap: _toggleDanmaku,
                        right: FeedBigCardTheme.danmakuRight,
                      ),
                      _semantics(
                        key: const ValueKey('big-card-sound-semantics'),
                        label: FeedInlineChoices.sound.value ? '静音' : '开启声音',
                        onTap: _toggleSound,
                        right: FeedBigCardTheme.speakerRight,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Stack(
              children: [
                _opens(
                  label: card.title,
                  key: const ValueKey('big-card-open-title'),
                  actions: {const CustomSemanticsAction(label: '稍后再看'): widget.onWatchLater},
                  child: _TitleBand(
                    card: card,
                    detail: _detail,
                    liked: _liked,
                    likes: _likes,
                    likeMotion: _likeMotion,
                    onLike: () => unawaited(_like()),
                    onMore: () => unawaited(_more()),
                  ),
                ),
                Positioned(
                  right: FeedBigCardTheme.likeRight - FeedBigCardTheme.likeTarget / 2,
                  top: 0,
                  bottom: 0,
                  width: FeedBigCardTheme.likeTarget,
                  child: Semantics(
                    key: const ValueKey('big-card-like-semantics'),
                    container: true,
                    button: true,
                    label: _liked ? '取消点赞' : '点赞',
                    onTap: () => unawaited(_like()),
                  ),
                ),
                Positioned(
                  right: FeedBigCardTheme.moreRight - FeedBigCardTheme.moreTarget / 2,
                  top: FeedBigCardTheme.moreDrop * 2,
                  bottom: 0,
                  width: FeedBigCardTheme.moreTarget,
                  child: Semantics(
                    key: const ValueKey('big-card-more-semantics'),
                    container: true,
                    button: true,
                    label: '更多',
                    onTap: () => unawaited(_more()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One element for VoiceOver that opens the page, its controls excluded (they have their own).
  Widget _opens({
    required String label,
    required Key key,
    Map<CustomSemanticsAction, VoidCallback>? actions,
    required Widget child,
  }) => Semantics(
    button: true,
    label: label,
    onTap: () => unawaited(_open()),
    customSemanticsActions: actions,
    excludeSemantics: true,
    child: GestureDetector(key: key, behavior: HitTestBehavior.opaque, onTap: () => unawaited(_open()), child: child),
  );

  Widget _semantics({required Key key, required String label, required VoidCallback onTap, required double right}) =>
      Positioned(
        right: right - FeedBigCardTheme.buttonTarget / 2,
        bottom: FeedBigCardTheme.buttonCentre - FeedBigCardTheme.buttonTarget / 2,
        width: FeedBigCardTheme.buttonTarget,
        height: FeedBigCardTheme.buttonTarget,
        child: Semantics(key: key, container: true, button: true, label: label, onTap: onTap),
      );

  void _toggleDanmaku() => FeedInlineChoices.danmaku.value = !FeedInlineChoices.danmaku.value;

  void _toggleSound() => FeedInlineChoices.sound.value = !FeedInlineChoices.sound.value;

  Widget _video(BuildContext context, FeedInlinePlayback? inline, bool playing) {
    final card = widget.card;
    final controller = inline?.controller;
    final session = inline?.session;
    final live = inline != null && inline.shown && controller != null && session != null ? (controller, session) : null;
    if (!identical(_viewOf, controller)) {
      _viewOf = controller;
      _view = controller?.player.buildView();
    }
    final dimmed = (inline?.laps ?? 0) > 0;
    final still = MediaQuery.disableAnimationsOf(context);
    final fade = still ? Duration.zero : FeedBigCardTheme.dim;
    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: VideoRoute.coverTag(card.bvid),
          child: RemoteImage(
            card.cover,
            cover: true,
            preset: CoverPreset.player,
            placeholder: const CoverPlaceholder(),
            fadeIn: false,
          ),
        ),
        if (live != null && _view != null)
          ColoredBox(
            key: const ValueKey('big-card-video'),
            color: BiliColors.videoBackground,
            child: KeyedSubtree(key: ValueKey(controller), child: _view!),
          ),
        if (live case (final controller, final session))
          ListenableBuilder(
            listenable: controller.danmaku,
            builder: (context, _) => DanmakuLayer(
              key: const ValueKey('big-card-danmaku'),
              clock: controller.clock,
              timeline: controller.danmaku.timeline,
              enabled: FeedInlineChoices.danmaku.value,
              wake: session.readout.any,
              settings: _services!.danmakuSettings,
              // 126's danmaku are 竖屏's size: CJK advances of 15.05 pt in lanes about 22.5 pt apart.
              presentation: Presentation.vertical,
            ),
          ),
        AnimatedOpacity(
          opacity: playing && dimmed ? 0 : 1,
          duration: fade,
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: BiliMetrics.coverShadeHeight,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [BiliColors.chromeShadeClear, BiliColors.coverShade],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (inline != null && inline.loading)
          const Center(key: ValueKey('big-card-loading'), child: PlayerLoading())
        else if (!playing)
          Center(
            child: Opacity(
              key: const ValueKey('big-card-play'),
              opacity: FeedBigCardTheme.playOpacity,
              child: Image.asset(
                FeedBigCardView.playAsset,
                width: FeedBigCardTheme.playWidth,
                excludeFromSemantics: true,
              ),
            ),
          ),
        _Stats(card: card, playing: playing, hidden: playing && dimmed, fade: fade),
        if (playing && live != null) ...[
          _Button(
            key: const ValueKey('big-card-danmaku-toggle'),
            right: FeedBigCardTheme.danmakuRight,
            dimmed: dimmed,
            fade: fade,
            onTap: _toggleDanmaku,
            child: DanmakuGlyph(on: FeedInlineChoices.danmaku.value),
          ),
          _Button(
            key: const ValueKey('big-card-sound'),
            right: FeedBigCardTheme.speakerRight,
            dimmed: dimmed,
            fade: fade,
            onTap: _toggleSound,
            child: Image.asset(
              FeedInlineChoices.sound.value ? FeedBigCardView.soundAsset : FeedBigCardView.mutedAsset,
              width: FeedBigCardTheme.speakerSize,
              height: FeedBigCardTheme.speakerSize,
              excludeFromSemantics: true,
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: _Progress(duration: live.$1.duration, seconds: live.$2.readout.seconds),
          ),
        ],
      ],
    );
  }
}

/// Reports its child's height after each layout.
class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasured(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) => renderObject.onHeight = onHeight;
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onHeight);

  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}

/// The counts on the video's bottom left, and on the cover the duration on its right (122). Playing they sit a little
/// lower without the duration (123), and from the second time round they are gone (126).
class _Stats extends StatelessWidget {
  const _Stats({required this.card, required this.playing, required this.hidden, required this.fade});

  final FeedCard card;
  final bool playing;
  final bool hidden;
  final Duration fade;

  @override
  Widget build(BuildContext context) {
    final centre = playing ? FeedBigCardTheme.statCentrePlaying : FeedBigCardTheme.statCentre;
    return Positioned(
      key: const ValueKey('big-card-stats'),
      left: FeedBigCardTheme.statLead,
      right: FeedBigCardTheme.durationTrail,
      bottom: centre - FeedBigCardTheme.statText,
      height: FeedBigCardTheme.statText * 2,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: fade,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1,
            child: DefaultTextStyle(
              style: TextStyle(
                fontFamily: BiliFonts.family,
                fontFamilyFallback: BiliFonts.fallback,
                fontSize: FeedBigCardTheme.statText,
                color: BiliColors.onCover,
                height: 1,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              child: Row(
                children: [
                  const _StatIcon('assets/images/card/stat_play.png'),
                  const SizedBox(width: FeedBigCardTheme.statIconGap),
                  Text(card.viewsText ?? CountFormat.short(card.views)),
                  const SizedBox(width: FeedBigCardTheme.statGap),
                  const _StatIcon('assets/images/card/stat_danmaku.png'),
                  const SizedBox(width: FeedBigCardTheme.statIconGap),
                  Text(card.danmakuText ?? CountFormat.short(card.danmaku)),
                  const Spacer(),
                  if (!playing) Text(FeedCardView.duration(card.duration), key: const ValueKey('big-card-duration')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatIcon extends StatelessWidget {
  const _StatIcon(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: BiliMetrics.cardStatIconWidth,
    height: BiliMetrics.cardStatIconHeight,
    color: BiliColors.onCover,
    colorBlendMode: BlendMode.srcIn,
    excludeFromSemantics: true,
  );
}

/// 弹 or the speaker on the playing video, centred [right] from the card's right.
class _Button extends StatelessWidget {
  const _Button({
    super.key,
    required this.right,
    required this.dimmed,
    required this.fade,
    required this.onTap,
    required this.child,
  });

  final double right;
  final bool dimmed;
  final Duration fade;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    right: right - FeedBigCardTheme.buttonTarget / 2,
    bottom: FeedBigCardTheme.buttonCentre - FeedBigCardTheme.buttonTarget / 2,
    width: FeedBigCardTheme.buttonTarget,
    height: FeedBigCardTheme.buttonTarget,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedOpacity(opacity: dimmed ? FeedBigCardTheme.dimmed : 1, duration: fade, child: child),
      ),
    ),
  );
}

/// The played part along the video's bottom edge (124, 126).
class _Progress extends StatelessWidget {
  const _Progress({required this.duration, required this.seconds});

  final ValueListenable<double> duration;
  final ValueListenable<double> seconds;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([seconds, duration]),
      builder: (context, _) {
        final total = duration.value;
        final share = total > 0 ? (seconds.value / total).clamp(0.0, 1.0) : 0.0;
        return FractionallySizedBox(
          key: const ValueKey('big-card-progress'),
          widthFactor: share,
          child: SizedBox(
            height: FeedBigCardTheme.progress,
            child: ColoredBox(color: FeedBigCardTheme.colorsOf(context).progressInk),
          ),
        );
      },
    );
  }
}

/// The title, then 👍 with its count and ⋮ on the right, the band one or two lines tall (123, 126).
class _TitleBand extends StatelessWidget {
  const _TitleBand({
    required this.card,
    required this.detail,
    required this.liked,
    required this.likes,
    required this.likeMotion,
    required this.onLike,
    required this.onMore,
  });

  final FeedCard card;
  final VideoDetail? detail;
  final bool liked;
  final int likes;
  final AnimationController likeMotion;
  final VoidCallback onLike;
  final VoidCallback onMore;

  String _byline() {
    final name = card.ownerName.isNotEmpty ? card.ownerName : detail?.owner.name ?? '';
    final published = card.published > 0 ? card.published : detail?.pubdate ?? 0;
    if (published <= 0) return name;
    final date = FeedCardView.padDate(published, now: DateTime.now());
    return name.isEmpty ? date : '$name · $date';
  }

  TextStyle _title(BuildContext context) => TextStyle(
    fontSize: FeedBigCardTheme.titleText,
    color: FeedBigCardTheme.colorsOf(context).title,
    height: FeedBigCardTheme.titleLine / FeedBigCardTheme.titleText,
  );

  @override
  Widget build(BuildContext context) {
    final big = card.big;
    final showCount = (big?.showLikes ?? true) && likes > 0;
    final count = TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: FeedBigCardTheme.countText,
      color: FeedBigCardTheme.colorsOf(context).count,
      height: 1,
    );
    const ink = FeedBigCardTheme.likeInk;
    const target = FeedBigCardTheme.likeTarget;
    return Stack(
      children: [
        Padding(
          key: const ValueKey('big-card-title'),
          padding: const EdgeInsets.fromLTRB(
            0,
            FeedBigCardTheme.titlePad,
            FeedBigCardTheme.titleTrailing,
            FeedBigCardTheme.titlePad,
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: FeedBigCardTheme.avatar,
                    child: RemoteImage.avatar(
                      card.ownerFace.isNotEmpty ? card.ownerFace : detail?.owner.face ?? '',
                      key: const ValueKey('feed-uploader-avatar'),
                    ),
                  ),
                ),
                const SizedBox(width: FeedBigCardTheme.avatarGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _title(context),
                        strutStyle: BiliFonts.strutOf(context, _title(context)),
                      ),
                      const SizedBox(height: FeedBigCardTheme.bylineGap),
                      Text(
                        _byline(),
                        key: const ValueKey('feed-uploader-byline'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: FeedBigCardTheme.bylineText,
                          height: FeedBigCardTheme.bylineLine / FeedBigCardTheme.bylineText,
                          color: BiliColors.colorsOf(context).secondaryText,
                        ),
                        strutStyle: BiliFonts.strutOf(
                          context,
                          const TextStyle(
                            fontSize: FeedBigCardTheme.bylineText,
                            height: FeedBigCardTheme.bylineLine / FeedBigCardTheme.bylineText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: FeedBigCardTheme.likeRight - target / 2,
          top: 0,
          bottom: FeedBigCardTheme.likeRise * 2,
          width: target,
          child: GestureDetector(
            key: const ValueKey('big-card-like'),
            behavior: HitTestBehavior.opaque,
            onTap: onLike,
            child: Center(
              child: SizedBox.square(
                dimension: ink,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: Transform.translate(
                          offset: const Offset(0, FeedBigCardTheme.likeInkRise),
                          child: liked
                              ? Lottie.asset(
                                  FeedBigCardView.likedAsset,
                                  key: const ValueKey('big-card-liked'),
                                  controller: likeMotion,
                                  width: ink / FeedBigCardTheme.likeLottieInk,
                                  height: ink / FeedBigCardTheme.likeLottieInk,
                                  onLoaded: (composition) => likeMotion.duration = composition.duration,
                                )
                              : Image.asset(
                                  FeedBigCardView.likeAsset,
                                  key: const ValueKey('big-card-unliked'),
                                  width: ink / FeedBigCardTheme.likeAssetInk,
                                  height: ink / FeedBigCardTheme.likeAssetInk,
                                  color: FeedBigCardTheme.colorsOf(context).like,
                                  colorBlendMode: BlendMode.srcIn,
                                  excludeFromSemantics: true,
                                ),
                        ),
                      ),
                    ),
                    if (showCount)
                      Positioned(
                        left: ink - FeedBigCardTheme.countOverlap,
                        top: -FeedBigCardTheme.countTop,
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1,
                          child: Text(
                            CountFormat.short(likes),
                            key: const ValueKey('big-card-likes'),
                            maxLines: 1,
                            softWrap: false,
                            style: count.copyWith(
                              color: liked
                                  ? FeedBigCardTheme.colorsOf(context).liked
                                  : FeedBigCardTheme.colorsOf(context).count,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: FeedBigCardTheme.moreRight - FeedBigCardTheme.moreTarget / 2,
          top: FeedBigCardTheme.moreDrop * 2,
          bottom: 0,
          width: FeedBigCardTheme.moreTarget,
          child: GestureDetector(
            key: const ValueKey('big-card-more'),
            behavior: HitTestBehavior.opaque,
            onTap: onMore,
            child: Center(
              child: Icon(
                Icons.more_vert,
                size: BiliMetrics.cardFooterText + 4,
                color: BiliColors.colorsOf(context).secondaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
