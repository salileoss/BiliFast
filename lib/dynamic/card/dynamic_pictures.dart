import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../comments/picture_viewer.dart';
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';

/// A post's pictures: one alone at its shape, two to four two a row, more three a row (127, 140). [detail] is the post
/// page's grid (140). A tap opens the picture viewer at that picture.
class DynamicPictureGrid extends StatelessWidget {
  const DynamicPictureGrid({super.key, required this.pictures, this.detail = false, this.onOpen});

  final List<DynamicPicture> pictures;
  final bool detail;

  /// Opens the viewer at a picture; [showDynamicPictures] over everything when null.
  final void Function(int index)? onOpen;

  /// The cells' frames for [pictures] in [width]; the first picture's shape decides a lone one's frame and the height
  /// of cells two a row.
  static List<Rect> layout(List<DynamicPicture> pictures, double width, {bool detail = false}) {
    if (pictures.isEmpty || width <= 0) return const [];
    final first = pictures.first;
    final tall = first.width > 0 && first.height > 0 ? first.height / first.width : 1.0;
    if (pictures.length == 1) {
      final double cellWidth;
      final double height;
      if (tall <= 1) {
        cellWidth = width;
        height = width * math.max(tall, 1 / DynamicCardTheme.pictureWidest);
      } else {
        cellWidth = detail ? width : math.min(width, DynamicCardTheme.pictureCell * 2 + DynamicCardTheme.pictureGap);
        height = cellWidth * math.min(tall, DynamicCardTheme.pictureTallest);
      }
      return [Rect.fromLTWH(0, 0, cellWidth, height)];
    }
    final gap = detail ? DynamicCardTheme.detailPictureGap : DynamicCardTheme.pictureGap;
    final perRow = pictures.length <= 4 ? 2 : 3;
    final cell = detail ? (width - gap * 2) / 3 : math.min(DynamicCardTheme.pictureCell, (width - gap * 2) / 3);
    final height = perRow == 2 && !detail ? cell * tall.clamp(1.0, DynamicCardTheme.pictureTallest) : cell;
    return [
      for (var i = 0; i < pictures.length; i++)
        Rect.fromLTWH((i % perRow) * (cell + gap), (i ~/ perRow) * (height + gap), cell, height),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (pictures.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final frames = layout(pictures, constraints.maxWidth, detail: detail);
        final height = frames.fold(0.0, (bottom, frame) => math.max(bottom, frame.bottom));
        return SizedBox(
          height: height,
          width: constraints.maxWidth,
          child: Stack(
            children: [
              for (final (index, frame) in frames.indexed)
                Positioned.fromRect(
                  rect: frame,
                  child: Semantics(
                    key: ValueKey('dynamic-picture-$index'),
                    button: true,
                    image: true,
                    label: '图片 ${index + 1}/${pictures.length}',
                    onTap: () => _open(context, index),
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _open(context, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(DynamicCardTheme.pictureRadius),
                        child: RemoteImage(
                          pictures[index].url,
                          size: frame.size,
                          placeholder: ColoredBox(color: DynamicCardTheme.colorsOf(context).pictureFill),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext context, int index) {
    final open = onOpen;
    if (open != null) {
      open(index);
    } else {
      showDynamicPictures(context, pictures, index);
    }
  }
}

/// A repost's pictures (136): one row [DynamicCardTheme.repostStrip] tall scrolling sideways, each picture at its own
/// shape, from [inset] in and running off the right edge. A tap opens the viewer at that picture.
class DynamicPictureStrip extends StatelessWidget {
  const DynamicPictureStrip({super.key, required this.pictures, this.inset = DynamicCardTheme.gutter, this.onOpen});

  final List<DynamicPicture> pictures;
  final double inset;

  /// Opens the viewer at a picture; [showDynamicPictures] over everything when null.
  final void Function(int index)? onOpen;

  /// A picture's width in the row: its shape at the row's height, square when its size is unknown.
  static double widthOf(DynamicPicture picture) => picture.width > 0 && picture.height > 0
      ? DynamicCardTheme.repostStrip * picture.width / picture.height
      : DynamicCardTheme.repostStrip;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: DynamicCardTheme.repostStrip,
    child: ListView.separated(
      key: const ValueKey('dynamic-picture-strip'),
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: inset),
      itemCount: pictures.length,
      separatorBuilder: (context, index) => const SizedBox(width: DynamicCardTheme.repostStripGap),
      itemBuilder: (context, index) {
        final size = Size(widthOf(pictures[index]), DynamicCardTheme.repostStrip);
        void open() {
          final opener = onOpen;
          if (opener != null) {
            opener(index);
          } else {
            showDynamicPictures(context, pictures, index);
          }
        }

        return Semantics(
          key: ValueKey('dynamic-picture-$index'),
          button: true,
          image: true,
          label: '图片 ${index + 1}/${pictures.length}',
          onTap: open,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: open,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DynamicCardTheme.repostStripRadius),
              child: SizedBox.fromSize(
                size: size,
                child: RemoteImage(
                  pictures[index].url,
                  size: size,
                  placeholder: ColoredBox(color: DynamicCardTheme.colorsOf(context).pictureFill),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The comments' picture viewer over everything, a see-through route on the root navigator: the 关注 tab has no page
/// Stack of its own, and the page under it stops being current, so its inline video pauses. Back closes it, as do a
/// tap and a swipe up or down.
void showDynamicPictures(BuildContext context, List<DynamicPicture> pictures, int index) {
  if (pictures.isEmpty) return;
  unawaited(Navigator.of(context, rootNavigator: true).push(_PictureViewerRoute(pictures: pictures, index: index)));
}

class _PictureViewerRoute extends PopupRoute<void> {
  _PictureViewerRoute({required this.pictures, required this.index});

  final List<DynamicPicture> pictures;
  final int index;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  /// The viewer fades itself in, and goes at once, as the comments' does.
  @override
  Duration get transitionDuration => Duration.zero;

  void _close() {
    // A tap can land while a swipe's throw is closing it.
    if (!isActive) return;
    final navigator = this.navigator;
    if (navigator == null) return;
    if (isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(this);
    }
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Material(
        key: const ValueKey('dynamic-picture-viewer'),
        type: MaterialType.transparency,
        child: PictureViewer(
          pictures: [
            for (final picture in pictures)
              CommentPicture(url: picture.url, width: picture.width.toDouble(), height: picture.height.toDouble()),
          ],
          initialIndex: index,
          onClose: _close,
        ),
      );
}
