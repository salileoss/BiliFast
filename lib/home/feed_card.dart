import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../app/form_factor.dart';
import '../app/zoom_back_route.dart';
import '../shared/cover_placeholder.dart';
import '../shared/cover_preset.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../video/video_route.dart';
import 'feed_dislike.dart';
import 'feed_model.dart' show CardDislike;
import 'feed_more_sheet.dart';

/// Card sizes that depend on the text size, so the grid can give every card the same height.
abstract final class FeedCardSize {
  static const _lineHeight = BiliMetrics.cardTitleLine / BiliMetrics.cardTitleText;

  static double titleHeight(TextScaler scaler) => scaler.scale(BiliMetrics.cardTitleText) * _lineHeight * 2;

  /// The tag, uploader and ⋮ row with its gaps. Its text keeps one size, as Swift's fixed `.system(size:)` did.
  static const footerHeight = BiliMetrics.cardFooterInset * 2 + BiliMetrics.cardTagHeight;

  /// The whole card for a column [width] wide: 4:3 cover, two title lines, the footer and their gaps.
  static double height(double width, TextScaler scaler) =>
      width / BiliMetrics.coverAspect + BiliMetrics.cardTitleTop + titleHeight(scaler) + footerHeight;

  /// The cover's box on a card [width] wide: what its picture is decoded to cover, and a precache's size.
  static Size cover(double width) => Size(width, width / BiliMetrics.coverAspect);
}

/// One 推荐 card (01, port of FeedCard.swift): the cover with counts and duration, a two-line title, and the tag,
/// uploader and ⋮ footer. It gives a little under the finger. [onOpen] gets the card's [ZoomSource], for the swipe
/// back into it. ⋮ opens its sheet (90); after 不感兴趣 ([dislike] set) the card shows [FeedDislikedCard] (91) instead.
class FeedCardView extends StatefulWidget {
  const FeedCardView({
    super.key,
    required this.card,
    required this.onOpen,
    required this.onWatchLater,
    this.dislike,
    this.onDislike,
    this.onUndo,
    this.onReason,
  });

  final FeedCard card;
  final ValueChanged<ZoomSource> onOpen;
  final VoidCallback onWatchLater;

  /// The card's 不感兴趣 while it stands.
  final CardDislike? dislike;

  /// 不感兴趣 with one of the card's reasons (the video's or the uploader's).
  final ValueChanged<FeedReason>? onDislike;
  final VoidCallback? onUndo;

  /// The reasons sheet's pick.
  final ValueChanged<FeedReason>? onReason;

  /// Gets [url] ready as a card with a [size] cover box asks for it (the same preset), so the card draws it the frame
  /// it comes.
  static Future<bool> precacheCover(BuildContext context, String? url, Size size) =>
      RemoteImage.precache(context, url, size: size, cover: true, preset: _preset(context));

  /// The iPhone app's 4:3 preset; the iPad's 16:9 boxes take [CoverPreset.forBox]'s.
  static CoverPreset? _preset(BuildContext context) => FormFactor.of(context).isPad ? null : CoverPreset.feed;

  /// The iPad's line under the title: the uploader, and the date where the card has one.
  static String padByline(FeedCard card, {required DateTime now}) {
    if (card.published <= 0) return card.ownerName;
    return '${card.ownerName} · ${padDate(card.published, now: now)}';
  }

  /// As comments read it, but two and three days back as N天前 (02's 3天前 beside 10月24日 five days back).
  static String padDate(int unix, {required DateTime now}) {
    final then = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
    final days = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(then.year, then.month, then.day));
    if (now.difference(then) >= const Duration(days: 1) && (days.inDays == 2 || days.inDays == 3)) {
      return '${days.inDays}天前';
    }
    return TimeFormat.comment(unix, now: now);
  }

  /// Covers say 0:18, not 00:18 (01).
  static String duration(int seconds) {
    final clock = TimeFormat.clock(seconds.toDouble());
    return clock.startsWith('0') && clock.length == 5 ? clock.substring(1) : clock;
  }

  @override
  State<FeedCardView> createState() => _FeedCardViewState();
}

class _FeedCardViewState extends State<FeedCardView> {
  bool _pressed = false;

  TextStyle get _title => TextStyle(
    fontSize: BiliMetrics.cardTitleText,
    color: BiliColors.colorsOf(context).text,
    height: FeedCardSize._lineHeight,
  );
  TextStyle get _owner => TextStyle(fontSize: BiliMetrics.cardFooterText, color: BiliColors.colorsOf(context).secondaryText, height: 1);

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
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

  @override
  Widget build(BuildContext context) {
    final dislike = widget.dislike;
    final data = widget.card.dislike;
    final offersReasons = data != null && (data.tiles.isNotEmpty || data.repeated != null);
    final pad = FormFactor.of(context).isPad;
    final disliked = dislike == null
        ? null
        : FeedDislikedCard(
            key: const ValueKey('feed-card-disliked'),
            card: widget.card,
            onUndo: () => widget.onUndo?.call(),
            onReasons: offersReasons ? () => unawaited(_reasons()) : null,
          );
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : FeedDislikeTheme.fadeIn,
      child: disliked == null
          ? ZoomSourceBox(key: const ValueKey('feed-card-live'), builder: pad ? _padCard : _card)
          // The phone's 4:3 card, shrunk into the iPad's slot until it has a shape of its own.
          : pad
          ? LayoutBuilder(
              key: const ValueKey('feed-card-disliked-pad'),
              builder: (context, box) => FittedBox(
                alignment: Alignment.topCenter,
                child: SizedBox(width: box.maxWidth, child: disliked),
              ),
            )
          : disliked,
    );
  }

  Widget _card(BuildContext context, ZoomSource source) {
    final card = widget.card;
    final scaler = MediaQuery.textScalerOf(context);
    // Passthrough keeps the grid's tight size on the card.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        _body(context, card, scaler, source),
        // ⋮'s own element, over the footer's ⋮: inside the card's excluded subtree it could only be a custom action,
        // which Windows UIA (and so ghosthand) doesn't offer. Touches pass through it to the ⋮ under it.
        Positioned(
          right: 0,
          bottom: (FeedCardSize.footerHeight - BiliMetrics.cardMoreTarget) / 2,
          width: BiliMetrics.cardMoreTarget,
          height: BiliMetrics.cardMoreTarget,
          child: Semantics(
            key: const ValueKey('card-more-semantics'),
            container: true,
            button: true,
            label: '更多',
            onTap: () => unawaited(_more()),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, FeedCard card, TextScaler scaler, ZoomSource source) {
    // One element for VoiceOver, named by the title, with 稍后再看 as its action.
    return Semantics(
      button: true,
      label: card.title,
      onTap: () => widget.onOpen(source),
      customSemanticsActions: {
        const CustomSemanticsAction(label: '稍后再看'): widget.onWatchLater,
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: () => widget.onOpen(source),
        child: AnimatedScale(
          scale: _pressed ? BiliMetrics.pressedScale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BiliMetrics.cardRadius),
            child: ColoredBox(
              color: BiliColors.colorsOf(context).card,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Cover(card: card),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: BiliMetrics.cardInset,
                      right: BiliMetrics.cardInset,
                      top: BiliMetrics.cardTitleTop,
                    ),
                    child: SizedBox(
                      height: FeedCardSize.titleHeight(scaler),
                      child: Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _title,
                        strutStyle: BiliFonts.strutOf(context, _title),
                      ),
                    ),
                  ),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1,
                    child: SizedBox(
                      height: FeedCardSize.footerHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(left: BiliMetrics.cardInset),
                        child: Row(
                          children: [
                            _Badge(card: card),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                card.ownerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _owner,
                                strutStyle: BiliFonts.strutOf(context, _owner),
                              ),
                            ),
                            GestureDetector(
                              key: const ValueKey('card-more'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => unawaited(_more()),
                              child: SizedBox.square(
                                dimension: BiliMetrics.cardMoreTarget,
                                child: Transform.translate(
                                  offset: const Offset(0, BiliMetrics.cardMoreDrop),
                                  child: Icon(
                                    Icons.more_vert,
                                    size: BiliMetrics.cardFooterText + 4,
                                    color: BiliColors.colorsOf(context).secondaryText,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  /// [FeedCardView.padByline], the dot set a little wider than spaces make it (02).
  static InlineSpan _padByline(FeedCard card) {
    if (card.published <= 0) return TextSpan(text: card.ownerName);
    const gap = WidgetSpan(child: SizedBox(width: PadHomeTheme.bylineDotGap));
    return TextSpan(
      children: [
        TextSpan(text: card.ownerName),
        gap,
        const TextSpan(text: ' · '),
        gap,
        TextSpan(text: FeedCardView.padDate(card.published, now: DateTime.now())),
      ],
    );
  }

  /// The iPad's card (ipad/01, 02): a 16:9 cover with rounded corners on the page's white, then the uploader's face,
  /// the title after its reason tag, the uploader and date, and ⋮.
  Widget _padCard(BuildContext context, ZoomSource source) {
    final card = widget.card;
    final title = TextStyle(
      fontSize: PadHomeTheme.titleText,
      color: BiliColors.colorsOf(context).text,
      height: PadHomeTheme.titleLine / PadHomeTheme.titleText,
    );
    final byline = TextStyle(fontSize: PadHomeTheme.subText, color: PadHomeTheme.colorsOf(context).subInk, height: 1.2);
    final reason = card.reason;
    return LayoutBuilder(
      builder: (context, box) {
        final cover = PadHomeTheme.coverHeight(box.maxWidth);
        const more = PadHomeTheme.moreTarget;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Semantics(
              button: true,
              label: card.title,
              onTap: () => widget.onOpen(source),
              customSemanticsActions: {const CustomSemanticsAction(label: '稍后再看'): widget.onWatchLater},
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _press(true),
                onTapUp: (_) => _press(false),
                onTapCancel: () => _press(false),
                onTap: () => widget.onOpen(source),
                child: AnimatedScale(
                  scale: _pressed ? BiliMetrics.pressedScale : 1,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: cover,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(PadHomeTheme.coverRadius),
                          child: _PadCover(card: card, size: Size(box.maxWidth, cover)),
                        ),
                      ),
                      SizedBox(
                        height: PadHomeTheme.footer,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: PadHomeTheme.faceTop,
                              width: PadHomeTheme.face,
                              height: PadHomeTheme.face,
                              child: ClipOval(
                                key: const ValueKey('feed-card-face'),
                                child: RemoteImage.avatar(card.ownerFace),
                              ),
                            ),
                            Positioned(
                              left: PadHomeTheme.titleLeft,
                              right: PadHomeTheme.titleRight,
                              top: PadHomeTheme.titleTop,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    if (reason != null && reason.isNotEmpty) ...[
                                      WidgetSpan(alignment: PlaceholderAlignment.middle, child: _PadTag(reason)),
                                      const WidgetSpan(child: SizedBox(width: PadHomeTheme.tagGap)),
                                    ],
                                    TextSpan(text: card.title),
                                  ],
                                ),
                                key: const ValueKey('feed-card-title'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: title,
                                strutStyle: BiliFonts.strutOf(context, title),
                              ),
                            ),
                            Positioned(
                              left: PadHomeTheme.titleLeft,
                              right: PadHomeTheme.titleRight,
                              top: PadHomeTheme.subTop,
                              child: Text.rich(
                                _padByline(card),
                                key: const ValueKey('feed-card-byline'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: byline,
                                strutStyle: BiliFonts.strutOf(context, byline),
                              ),
                            ),
                            Positioned(
                              right: PadHomeTheme.moreRight - more / 2,
                              top: PadHomeTheme.moreCentre - more / 2,
                              width: more,
                              height: more,
                              child: GestureDetector(
                                key: const ValueKey('card-more'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => unawaited(_more()),
                                child: CustomPaint(painter: _PadMorePainter(palette: BiliPalette.of(context))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: PadHomeTheme.moreRight - more / 2,
              top: cover + PadHomeTheme.moreCentre - more / 2,
              width: more,
              height: more,
              child: Semantics(
                key: const ValueKey('card-more-semantics'),
                container: true,
                button: true,
                label: '更多',
                onTap: () => unawaited(_more()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ⋮ as the iPad draws it: three dots one above the other.
class _PadMorePainter extends CustomPainter {
  final BiliPalette palette;

  const _PadMorePainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = PadHomeThemeColors(palette).moreInk;
    final centre = size.center(Offset.zero);
    for (final step in const [-1, 0, 1]) {
      canvas.drawCircle(centre + Offset(0, step * PadHomeTheme.morePitch), PadHomeTheme.moreDot / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_PadMorePainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

class _PadTag extends StatelessWidget {
  const _PadTag(this.text);

  final String text;

  static const _style = TextStyle(fontSize: PadHomeTheme.tagText, color: BiliColors.reason, height: 1);

  @override
  Widget build(BuildContext context) => Container(
    height: PadHomeTheme.tagHeight,
    padding: const EdgeInsets.symmetric(horizontal: PadHomeTheme.tagPad),
    decoration: BoxDecoration(
      color: BiliColors.colorsOf(context).reasonTint,
      borderRadius: BorderRadius.circular(PadHomeTheme.tagRadius),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(text, maxLines: 1, style: _style, strutStyle: BiliFonts.strutOf(context, _style)),
    ),
  );
}

/// The iPad's cover: the picture decoded at [size], the shade, and the counts and duration over it.
class _PadCover extends StatelessWidget {
  const _PadCover({required this.card, required this.size});

  final FeedCard card;
  final Size size;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Hero(
        tag: VideoRoute.coverTag(card.bvid),
        child: RemoteImage(
          card.cover,
          cover: true,
          size: size,
          placeholder: const CoverPlaceholder(),
          fadeIn: false,
          overlay: const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: PadHomeTheme.shade,
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
      ),
      Positioned(
        left: PadHomeTheme.statLead,
        right: PadHomeTheme.statTrail,
        bottom: 0,
        height: PadHomeTheme.statCentre * 2,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1,
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: BiliFonts.family,
              fontFamilyFallback: BiliFonts.fallback,
              fontSize: PadHomeTheme.statText,
              color: BiliColors.onCover,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const _StatIcon(_StatIcon.play, pad: true),
                      const SizedBox(width: PadHomeTheme.statIconGap),
                      Flexible(child: _StatText(card.viewsText ?? CountFormat.short(card.views))),
                      const SizedBox(width: PadHomeTheme.statGap),
                      const _StatIcon(_StatIcon.danmaku, pad: true),
                      const SizedBox(width: PadHomeTheme.statIconGap),
                      Flexible(child: _StatText(card.danmakuText ?? CountFormat.short(card.danmaku))),
                    ],
                  ),
                ),
                const SizedBox(width: PadHomeTheme.durationGap),
                _StatText(FeedCardView.duration(card.duration)),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _Cover extends StatelessWidget {
  const _Cover({required this.card});

  final FeedCard card;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: BiliMetrics.coverAspect,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: VideoRoute.coverTag(card.bvid),
          // A cover still loading is the official flat grey with no shade, and a late one pops in (14).
          child: RemoteImage(
            card.cover,
            cover: true,
            preset: CoverPreset.feed,
            placeholder: const CoverPlaceholder(),
            fadeIn: false,
            overlay: const Align(
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
        ),
        Positioned(
          left: BiliMetrics.cardStatLead,
          right: BiliMetrics.cardStatTrail,
          bottom: 0,
          height: BiliMetrics.cardStatCentre * 2,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1,
            child: DefaultTextStyle(
              style: TextStyle(
                fontFamily: BiliFonts.family,
                fontFamilyFallback: BiliFonts.fallback,
                fontSize: BiliMetrics.cardStatText,
                color: BiliColors.onCover,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              // On a card too narrow for them all, the counts give way before the duration does.
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const _StatIcon(_StatIcon.play),
                        const SizedBox(width: BiliMetrics.cardStatIconGap),
                        Flexible(child: _StatText(card.viewsText ?? CountFormat.short(card.views))),
                        const SizedBox(width: BiliMetrics.cardStatGap),
                        const _StatIcon(_StatIcon.danmaku),
                        const SizedBox(width: BiliMetrics.cardStatIconGap),
                        Flexible(child: _StatText(card.danmakuText ?? CountFormat.short(card.danmaku))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _StatText(FeedCardView.duration(card.duration)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The official play or danmaku count icon, drawn white.
class _StatIcon extends StatelessWidget {
  const _StatIcon(this.asset, {this.pad = false});

  static const play = 'assets/images/card/stat_play.png';
  static const danmaku = 'assets/images/card/stat_danmaku.png';

  final String asset;
  final bool pad;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: pad ? PadHomeTheme.statIconWidth : BiliMetrics.cardStatIconWidth,
    height: pad ? PadHomeTheme.statIconHeight : BiliMetrics.cardStatIconHeight,
    color: BiliColors.onCover,
    colorBlendMode: BlendMode.srcIn,
    excludeFromSemantics: true,
  );
}

class _StatText extends StatelessWidget {
  const _StatText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Transform.translate(offset: const Offset(0, BiliMetrics.cardStatTextDrop), child: Text(text));
}

class _Badge extends StatelessWidget {
  const _Badge({required this.card});

  final FeedCard card;

  @override
  Widget build(BuildContext context) {
    final reason = card.reason;
    if (reason != null && reason.isNotEmpty) return _Tag(reason);
    if (card.isVertical) return const _Tag('竖屏');
    return const UpBadge();
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  static const _style = TextStyle(fontSize: BiliMetrics.cardTagText, color: BiliColors.reason, height: 1);

  @override
  Widget build(BuildContext context) => Container(
    height: BiliMetrics.cardTagHeight,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: BiliColors.colorsOf(context).reasonTint, borderRadius: BorderRadius.circular(2)),
    child: Text(text, maxLines: 1, style: _style, strutStyle: BiliFonts.strutOf(context, _style)),
  );
}

class UpBadge extends StatelessWidget {
  const UpBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: BiliMetrics.upBadgeHeight,
    padding: const EdgeInsets.symmetric(horizontal: 2),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: BiliColors.colorsOf(context).secondaryText),
      borderRadius: BorderRadius.circular(2.5),
    ),
    child: Text(
      'UP',
      style: TextStyle(
        fontSize: BiliMetrics.upBadgeText,
        fontWeight: FontWeight.bold,
        color: BiliColors.colorsOf(context).secondaryText,
        height: 1,
      ),
    ),
  );
}

/// A card's outline while the first page loads, a light band sweeping across it.
class FeedCardSkeleton extends StatelessWidget {
  const FeedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    if (FormFactor.of(context).isPad) return _pad();
    final scaler = MediaQuery.textScalerOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(BiliMetrics.cardRadius),
      child: ColoredBox(
        color: BiliColors.colorsOf(context).card,
        // Inside the card, so the sweep lights only the grey shapes and not the white around them.
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: BiliMetrics.coverAspect,
                child: ColoredBox(color: BiliColors.colorsOf(context).shimmerBase),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: BiliMetrics.cardInset,
                  right: BiliMetrics.cardInset * 3,
                  top: BiliMetrics.cardTitleTop,
                ),
                child: SizedBox(
                  height: FeedCardSize.titleHeight(scaler),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Bar(),
                      FractionallySizedBox(widthFactor: 0.6, child: _Bar()),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: FeedCardSize.footerHeight,
                child: Padding(
                  padding: EdgeInsets.only(left: BiliMetrics.cardInset),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(widthFactor: 0.4, child: _Bar()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The iPad's card shapes on the page's white: the cover, the face and two lines.
  Widget _pad() => Shimmer(
    child: LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: PadHomeTheme.coverHeight(box.maxWidth),
            decoration: BoxDecoration(
              color: BiliColors.colorsOf(context).shimmerBase,
              borderRadius: BorderRadius.circular(PadHomeTheme.coverRadius),
            ),
          ),
          SizedBox(
            height: PadHomeTheme.footer,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: PadHomeTheme.faceTop,
                  child: SizedBox.square(
                    dimension: PadHomeTheme.face,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: BiliColors.colorsOf(context).shimmerBase, shape: BoxShape.circle),
                    ),
                  ),
                ),
                Positioned(
                  left: PadHomeTheme.titleLeft,
                  right: PadHomeTheme.titleRight,
                  top: PadHomeTheme.faceTop + PadHomeTheme.skeletonTitleDrop,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Bar(),
                      SizedBox(height: PadHomeTheme.skeletonLineGap),
                      FractionallySizedBox(widthFactor: 0.6, alignment: Alignment.centerLeft, child: _Bar()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) => Container(
    height: 12,
    decoration: BoxDecoration(color: BiliColors.colorsOf(context).shimmerBase, borderRadius: BorderRadius.circular(3)),
  );
}

/// Sweeps a light band across [child] every 1.3 s; still when the system asks for less motion.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      unawaited(_sweep.repeat());
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sweep.isAnimating) return widget.child;
    return AnimatedBuilder(
      animation: _sweep,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final at = -1.0 + _sweep.value * 3;
          return LinearGradient(
            begin: Alignment(at - 1, -0.3),
            end: Alignment(at + 1, 0.3),
            colors: [BiliColors.colorsOf(context).shimmerBase, BiliColors.colorsOf(context).shimmerHighlight, BiliColors.colorsOf(context).shimmerBase],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}
