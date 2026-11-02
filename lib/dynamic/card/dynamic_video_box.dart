import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../home/feed_inline_player.dart';
import '../../player_ui/player_loading.dart';
import '../../shared/cover_placeholder.dart';
import '../../shared/cover_preset.dart';
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import 'dynamic_open.dart';

/// The part each of a host's [FeedInlineHost.positions] belongs to: the page may have left the video on another part
/// (选集, 自动连播), and the card plays on from there.
final _parts = Expando<Map<String, int>>('dynamic inline parts');

Map<String, int> _partsOf(FeedInlineHost host) => _parts[host] ??= {};

/// A video post's box (128, 132, 139): the cover with 00:56 · 37.1万播放 · 1233弹幕, the 动态视频 badge, the TV mark, the
/// title under it when [showTitle]; muted inline play with 🔇 when [inline] picks it. A tap opens the player.
class DynamicVideoBox extends StatefulWidget {
  const DynamicVideoBox({
    super.key,
    required this.video,
    this.inline,
    this.showTitle = true,
    this.titleTop = DynamicCardTheme.titleTop,
  });

  final DynamicVideo video;
  final FeedInlineHost? inline;
  final bool showTitle;

  /// From the cover's bottom to the title's line box.
  final double titleTop;

  @override
  State<DynamicVideoBox> createState() => DynamicVideoBoxState();
}

/// The box's state, so a tap elsewhere on its card can open the video with the box's running playback.
class DynamicVideoBoxState extends State<DynamicVideoBox> implements FeedInlineCard {
  final _videoKey = GlobalKey();
  AppServices? _services;
  FeedInlinePlayback? _inline;
  Widget? _view;
  Object? _viewOf;

  @override
  void initState() {
    super.initState();
    FeedInlineChoices.sound.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services != null) return;
    _services = AppScope.of(context);
    widget.inline?.register(this);
  }

  @override
  void didUpdateWidget(DynamicVideoBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameVideo = oldWidget.video.bvid == widget.video.bvid;
    if (!identical(oldWidget.inline, widget.inline) || !sameVideo) {
      oldWidget.inline?.unregister(this);
      _letGo();
      widget.inline?.register(this);
    }
  }

  @override
  void dispose() {
    widget.inline?.unregister(this);
    _letGo();
    FeedInlineChoices.sound.removeListener(_changed);
    super.dispose();
  }

  void _letGo() {
    final inline = _inline;
    if (inline == null) return;
    _inline = null;
    inline
      ..removeListener(_changed)
      ..dispose();
  }

  void _changed() {
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
    if (widget.inline == null || !mounted) return;
    (_inline ??= _makeInline()).play();
  }

  @override
  void inlinePause() => _inline?.pause();

  FeedInlinePlayback _makeInline() {
    final host = widget.inline!;
    final video = widget.video;
    final cid = _partsOf(host)[video.bvid] ?? 0;
    return FeedInlinePlayback(
      services: _services!,
      // A post's length is its first part's: on another part the card can't tell it is at the end.
      video: InlineVideo(bvid: video.bvid, cid: cid, title: video.title, duration: cid > 0 ? 0 : video.duration),
      startAt: () => host.positions[video.bvid] ?? 0,
      released: (seconds) => _stoppedAt(host, video.bvid, seconds, cid),
    )..addListener(_changed);
  }

  static void _stoppedAt(FeedInlineHost host, String bvid, double seconds, int cid) {
    host.positions[bvid] = seconds;
    _partsOf(host)[bvid] = cid;
  }

  /// The video page, taking the running inline video along with its sound; back here, the box plays on from where the
  /// page left it, on the part it left it on.
  Future<void> open() async {
    final video = widget.video;
    final host = widget.inline;
    final inline = _inline;
    final playback = inline?.handOver();
    // Nothing to hand over (still starting, or failed): letting it go records where it stood, the page's start.
    if (playback == null) inline?.release();
    final start = playback == null ? host?.positions[video.bvid] : null;
    final cid = playback == null && host != null ? _partsOf(host)[video.bvid] : null;
    await openDynamicVideo(context, video, playback: playback, start: start, cid: cid);
    if (playback == null || host == null) return;
    final ({String bvid, int? cid, double? at}) left = playback.closed
        ? (bvid: playback.restartRoute.bvid, cid: playback.restartRoute.cid, at: playback.restartRoute.start)
        : (
            bvid: playback.controller?.video?.bvid ?? playback.bvid,
            cid: playback.controller?.page?.cid,
            at: playback.controller?.currentSeconds,
          );
    final at = left.at;
    if (at == null || left.bvid != video.bvid) return;
    // The first part is the one the card plays by itself (0), so its start-over-near-the-end rule still holds.
    final first = playback.controller?.video?.pages.firstOrNull?.cid;
    final part = left.cid == null || left.cid == first ? 0 : left.cid!;
    _stoppedAt(host, video.bvid, at, part);
    // The handed-over card's player was made for the part it played; the next play makes one for this part.
    if (mounted && _inline?.video.cid != part) {
      _letGo();
      host.settleSoon();
    }
  }

  void _toggleSound() => FeedInlineChoices.sound.value = !FeedInlineChoices.sound.value;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final box = AspectRatio(
      key: _videoKey,
      aspectRatio: DynamicCardTheme.videoAspect,
      child: ClipRRect(borderRadius: BorderRadius.circular(DynamicCardTheme.videoRadius), child: _cover(context)),
    );
    return Semantics(
      container: true,
      button: true,
      label: video.title,
      onTap: () => unawaited(open()),
      child: GestureDetector(
        key: ValueKey('dynamic-video-${video.bvid}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(open()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            box,
            if (widget.showTitle && video.title.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: widget.titleTop, bottom: DynamicCardTheme.titleBottom),
                child: ExcludeSemantics(
                  child: Text(
                    video.title,
                    key: ValueKey('dynamic-video-title-${video.bvid}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dynamicStyle(
                      DynamicCardTheme.titleText,
                      DynamicCardTheme.colorsOf(context).titleInk,
                      weight: DynamicCardTheme.titleWeight,
                      line: DynamicCardTheme.titleLine,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cover(BuildContext context) {
    final video = widget.video;
    final inline = _inline;
    final controller = inline?.controller;
    final session = inline?.session;
    final live = inline != null && inline.wanted && inline.shown && controller != null && session != null
        ? (controller, session)
        : null;
    if (!identical(_viewOf, controller)) {
      _viewOf = controller;
      _view = controller?.player.buildView();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        RemoteImage(
          video.cover,
          cover: true,
          preset: CoverPreset.player,
          placeholder: const CoverPlaceholder(),
          fadeIn: false,
        ),
        if (inline != null && inline.shown && controller != null && _view != null)
          ColoredBox(
            key: const ValueKey('dynamic-video-playing'),
            color: BiliColors.videoBackground,
            child: KeyedSubtree(key: ValueKey(controller), child: _view!),
          ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: DynamicCardTheme.shadeHeight,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [BiliColors.chromeShadeClear, DynamicCardTheme.shade],
                ),
              ),
            ),
          ),
        ),
        if (inline != null && inline.loading)
          const Center(key: ValueKey('dynamic-video-loading'), child: PlayerLoading()),
        Positioned(
          left: DynamicCardTheme.durationLeft,
          right: DynamicCardTheme.durationLeft,
          bottom: DynamicCardTheme.durationBottom,
          height: DynamicCardTheme.durationHeight,
          child: IgnorePointer(child: _Stats(video: video)),
        ),
        if (video.badge.isNotEmpty)
          Positioned(
            top: DynamicCardTheme.badgeInset,
            right: DynamicCardTheme.badgeInset,
            height: DynamicCardTheme.badgeHeight,
            child: IgnorePointer(child: _Badge(video.badge)),
          ),
        if (live == null)
          Positioned(
            right: DynamicCardTheme.tvRight,
            bottom: DynamicCardTheme.tvBottom,
            child: IgnorePointer(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  1, 0, 0, 0, 0, //
                  0, 1, 0, 0, 0, //
                  0, 0, 1, 0, 0, //
                  0, 0, 0, DynamicCardTheme.tvAlpha / DynamicCardTheme.tvArtAlpha, 0,
                ]),
                child: Image.asset(
                  DynamicArt.tv,
                  key: const ValueKey('dynamic-video-tv'),
                  width: DynamicCardTheme.tvWidth,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          )
        else ...[
          Positioned(
            right: DynamicCardTheme.speakerRight + (DynamicCardTheme.speaker - DynamicCardTheme.speakerTarget) / 2,
            bottom: DynamicCardTheme.speakerBottom + (DynamicCardTheme.speaker - DynamicCardTheme.speakerTarget) / 2,
            width: DynamicCardTheme.speakerTarget,
            height: DynamicCardTheme.speakerTarget,
            child: Semantics(
              container: true,
              button: true,
              label: FeedInlineChoices.sound.value ? '静音' : '开启声音',
              onTap: _toggleSound,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('dynamic-video-sound'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggleSound,
                child: Center(
                  child: Image.asset(
                    FeedInlineChoices.sound.value ? DynamicArt.sound : DynamicArt.muted,
                    width: DynamicCardTheme.speaker,
                    height: DynamicCardTheme.speaker,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
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

/// The duration in its pill, then the plays and danmaku, on the cover's bottom left (128, 139).
class _Stats extends StatelessWidget {
  const _Stats({required this.video});

  final DynamicVideo video;

  @override
  Widget build(BuildContext context) {
    final style = dynamicStyle(DynamicCardTheme.statText, DynamicCardTheme.statInk).copyWith(height: 1);
    return DefaultTextStyle(
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      child: Row(
        children: [
          if (video.durationText.isNotEmpty)
            Container(
              key: const ValueKey('dynamic-video-duration'),
              height: DynamicCardTheme.durationHeight,
              padding: const EdgeInsets.symmetric(horizontal: DynamicCardTheme.durationPad),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DynamicCardTheme.durationFill,
                borderRadius: BorderRadius.circular(DynamicCardTheme.durationRadius),
              ),
              child: Text(video.durationText),
            ),
          if (video.plays.isNotEmpty) ...[
            const SizedBox(width: DynamicCardTheme.statFirstGap),
            Text.rich(apartFromHan('${video.plays}播放')),
          ],
          if (video.danmaku.isNotEmpty) ...[
            const SizedBox(width: DynamicCardTheme.statGap),
            Text.rich(apartFromHan('${video.danmaku}弹幕')),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('dynamic-video-badge'),
    padding: const EdgeInsets.symmetric(horizontal: DynamicCardTheme.badgePad),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: DynamicCardTheme.badgeFill,
      borderRadius: BorderRadius.circular(DynamicCardTheme.badgeRadius),
    ),
    child: Text(
      text,
      maxLines: 1,
      style: dynamicStyle(DynamicCardTheme.badgeText, DynamicCardTheme.badgeInk).copyWith(height: 1),
    ),
  );
}

/// The played part along the cover's bottom edge (139).
class _Progress extends StatelessWidget {
  const _Progress({required this.duration, required this.seconds});

  final ValueListenable<double> duration;
  final ValueListenable<double> seconds;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([seconds, duration]),
    builder: (context, _) {
      final total = duration.value;
      final share = total > 0 ? (seconds.value / total).clamp(0.0, 1.0) : 0.0;
      return FractionallySizedBox(
        key: const ValueKey('dynamic-video-progress'),
        widthFactor: share,
        child: SizedBox(
          height: DynamicCardTheme.progress,
          child: ColoredBox(color: DynamicCardTheme.colorsOf(context).progressInk),
        ),
      );
    },
  );
}

/// [text] with [DynamicCardTheme.statHanGap] wherever a digit or Latin letter meets Chinese, either way round, as
/// PingFang sets them; MiSans needs none.
TextSpan apartFromHan(String text) {
  if (BiliFonts.nudged) return TextSpan(text: text);
  bool han(int unit) => (unit >= 0x4E00 && unit <= 0x9FFF) || (unit >= 0x3400 && unit <= 0x4DBF);
  bool latin(int unit) =>
      (unit >= 0x30 && unit <= 0x39) || (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A);
  final spans = <TextSpan>[];
  var start = 0;
  for (var i = 0; i + 1 < text.length; i++) {
    final a = text.codeUnitAt(i), b = text.codeUnitAt(i + 1);
    if ((latin(a) && han(b)) || (han(a) && latin(b))) {
      spans
        ..add(TextSpan(text: text.substring(start, i)))
        ..add(
          TextSpan(
            text: text[i],
            style: const TextStyle(letterSpacing: DynamicCardTheme.statHanGap),
          ),
        );
      start = i + 1;
    }
  }
  spans.add(TextSpan(text: text.substring(start)));
  return TextSpan(children: spans);
}
