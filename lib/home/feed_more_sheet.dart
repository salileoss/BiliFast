import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../search/search_glyphs.dart';
import '../shared/menu.dart' show PressHighlight;
import '../shared/theme.dart';
import 'feed_dislike_glyphs.dart';

/// What a 推荐 card's ⋮ sheet was closed with.
enum FeedMoreChoice { watchLater, dislikeVideo, dislikeUploader }

/// A card's ⋮ (90): the light sheet over the dimmed page, 添加至稍后再看 on its own card, then 不感兴趣：当前视频 and
/// 不感兴趣：UP for a card that carries their reasons (the official feed's; the website's carry none).
Future<FeedMoreChoice?> showFeedMoreSheet(BuildContext context, FeedCard card) {
  final dislike = card.dislike;
  final video = dislike?.video != null;
  final uploader = dislike?.uploader != null;
  return showFeedSheet<FeedMoreChoice>(
    context,
    top: FeedDislikeTheme.menuTop,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeedSheetCard(
          children: [
            FeedSheetRow(
              key: const ValueKey('feed-more-watch-later'),
              label: '添加至稍后再看',
              icon: Transform.translate(
                offset: const Offset(FeedDislikeTheme.watchLaterShift, 0),
                child: SearchGlyphIcon(
                  SearchGlyph.watchLater,
                  size: FeedDislikeTheme.watchLaterIcon,
                  color: FeedDislikeTheme.colorsOf(context).ink,
                ),
              ),
              onTap: () => Navigator.of(context).pop(FeedMoreChoice.watchLater),
            ),
          ],
        ),
        if (video || uploader) ...[
          const SizedBox(height: FeedDislikeTheme.groupGap),
          FeedSheetCard(
            children: [
              if (video)
                FeedSheetRow(
                  key: const ValueKey('feed-more-dislike-video'),
                  label: '不感兴趣：当前视频',
                  icon: FeedDislikeGlyphIcon(
                    FeedDislikeGlyph.videoOff,
                    size: FeedDislikeTheme.rowIconBox,
                    color: FeedDislikeTheme.colorsOf(context).ink,
                  ),
                  onTap: () => Navigator.of(context).pop(FeedMoreChoice.dislikeVideo),
                ),
              if (uploader)
                FeedSheetRow(
                  key: const ValueKey('feed-more-dislike-uploader'),
                  label: '不感兴趣：UP',
                  icon: FeedDislikeGlyphIcon(
                    FeedDislikeGlyph.uploaderOff,
                    size: FeedDislikeTheme.rowIconBox,
                    color: FeedDislikeTheme.colorsOf(context).ink,
                  ),
                  onTap: () => Navigator.of(context).pop(FeedMoreChoice.dislikeUploader),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// The light sheet 90 and 92 share, rising over the dimmed page with its grabber; [top] is where its first content
/// starts below the sheet's top. A tap on the dim, a drag down or a fling closes it with null.
Future<T?> showFeedSheet<T>(BuildContext context, {required double top, required WidgetBuilder builder}) =>
    Navigator.of(context)
        .push(_FeedSheetRoute<T>(top: top, builder: builder, reduceMotion: MediaQuery.disableAnimationsOf(context)));

class _FeedSheetRoute<T> extends PopupRoute<T> {
  _FeedSheetRoute({required this.top, required this.builder, required this.reduceMotion});

  final double top;
  final WidgetBuilder builder;
  final bool reduceMotion;
  final _sheetKey = GlobalKey();

  @override
  Color? get barrierColor => FeedDislikeTheme.dim;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => '关闭';

  @override
  Duration get transitionDuration => reduceMotion ? Duration.zero : FeedDislikeTheme.sheetIn;

  @override
  Duration get reverseTransitionDuration => reduceMotion ? Duration.zero : FeedDislikeTheme.sheetOut;

  CurvedAnimation? _curve;

  @override
  Animation<double> createAnimation() => _curve = CurvedAnimation(
    parent: super.createAnimation(),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }

  double get _sheetHeight => _sheetKey.currentContext?.size?.height ?? 1;

  void _dragged(DragUpdateDetails details) {
    final motion = controller;
    if (motion == null || !isCurrent) return;
    motion.value -= details.primaryDelta! / _sheetHeight;
  }

  void _released(BuildContext context, DragEndDetails details) {
    final motion = controller;
    if (motion == null || !isCurrent) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > FeedDislikeTheme.flingClose || motion.value < 1 - FeedDislikeTheme.dragClose) {
      Navigator.of(context).pop();
    } else {
      unawaited(motion.forward());
    }
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
        // The route sits outside the page's Material, whose text style the rows would otherwise miss.
        child: Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _dragged,
            onVerticalDragEnd: (details) => _released(context, details),
            child: Container(
              key: _sheetKey,
              width: double.infinity,
              decoration: BoxDecoration(
                color: FeedDislikeTheme.colorsOf(context).sheetFill,
                borderRadius: BorderRadius.vertical(top: Radius.circular(FeedDislikeTheme.sheetRadius)),
              ),
              padding: EdgeInsets.only(
                left: FeedDislikeTheme.inset,
                right: FeedDislikeTheme.inset,
                bottom: bottom + FeedDislikeTheme.sheetBottom,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: FeedDislikeTheme.grabberTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: FeedDislikeTheme.grabberWidth,
                        height: FeedDislikeTheme.grabberHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: FeedDislikeTheme.colorsOf(context).grabberInk,
                            borderRadius: BorderRadius.all(Radius.circular(FeedDislikeTheme.grabberHeight / 2)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: top),
                    child: Builder(builder: builder),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// The words of the sheets, read from [BiliFonts.family] where they're built.
TextStyle feedSheetStyle(double size, Color color, {FontWeight weight = FontWeight.w400}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

/// One of the sheet's white cards; a hairline from under the words parts its rows.
class FeedSheetCard extends StatelessWidget {
  const FeedSheetCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(FeedDislikeTheme.cardRadius),
    child: ColoredBox(
      color: FeedDislikeTheme.colorsOf(context).cardFill,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed)
            if (index == children.length - 1)
              child
            else
              // The hairline is the row's last third of a point, as 90's is, so the rows stay 52 apart.
              Stack(
                children: [
                  child,
                  Positioned(
                    left: FeedDislikeTheme.rowTextLeft,
                    right: 0,
                    bottom: 0,
                    height: FeedDislikeTheme.hairline,
                    child: ColoredBox(color: FeedDislikeTheme.colorsOf(context).hairlineInk),
                  ),
                ],
              ),
        ],
      ),
    ),
  );
}

/// A 52 pt row: its icon centred [FeedDislikeTheme.rowIconCentre] in, its words at [FeedDislikeTheme.rowTextLeft].
class FeedSheetRow extends StatelessWidget {
  const FeedSheetRow({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = feedSheetStyle(FeedDislikeTheme.rowText, FeedDislikeTheme.colorsOf(context).ink);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressHighlight(
        onTap: onTap,
        child: SizedBox(
          height: FeedDislikeTheme.rowHeight,
          child: Stack(
            children: [
              Positioned(
                left: FeedDislikeTheme.rowIconCentre - FeedDislikeTheme.rowIconBox / 2,
                top: 0,
                bottom: 0,
                width: FeedDislikeTheme.rowIconBox,
                child: Center(child: icon),
              ),
              Positioned(
                left: FeedDislikeTheme.rowTextLeft,
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
