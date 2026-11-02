import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../../space/uploader_tap.dart';
import 'post_glyphs.dart';

TextStyle postStyle(double size, Color color, {double? line, FontWeight weight = FontWeight.w400}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: line == null ? null : line / size,
  leadingDistribution: TextLeadingDistribution.even,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

/// One line of text in a box [line] tall, its glyphs centred in it.
Widget postLine(BuildContext context, String text, TextStyle style, {Key? key}) => Text(
  text,
  key: key,
  maxLines: 1,
  softWrap: false,
  overflow: TextOverflow.ellipsis,
  style: style,
  strutStyle: BiliFonts.strutOf(context, style),
);

/// The author block under the bar (131, 132, 140): the face with its verify badge, the name (pink for 大会员), the
/// time, and IP属地 when [showLocation] and the post sent one. The face and the name open the author's space.
class PostAuthor extends StatelessWidget {
  const PostAuthor({super.key, required this.author, required this.showLocation});

  final DynamicAuthor author;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    void open() => openUploader(context, UploaderRef(mid: author.mid, name: author.name, face: author.face));
    final location = author.location;
    final meta = postStyle(DynamicPostTheme.metaText, DynamicPostTheme.colorsOf(context).meta, line: DynamicPostTheme.metaLine);
    final lines = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: author.name,
          onTap: open,
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('post-author-name'),
            behavior: HitTestBehavior.opaque,
            onTap: open,
            child: SizedBox(
              height: DynamicPostTheme.nameLine,
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: postLine(
                  context,
                  author.name,
                  postStyle(
                    DynamicPostTheme.nameText,
                    author.vipPink ? DynamicPostTheme.vipName : DynamicPostTheme.colorsOf(context).name,
                    line: DynamicPostTheme.nameLine,
                    weight: DynamicPostTheme.nameWeight,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (author.pubTime.isNotEmpty)
          SizedBox(
            height: DynamicPostTheme.metaLine,
            child: postLine(context, author.pubTime, meta, key: const ValueKey('post-time')),
          ),
        if (showLocation && location.isNotEmpty) ...[
          const SizedBox(height: DynamicPostTheme.metaGap),
          SizedBox(
            height: DynamicPostTheme.metaLine,
            child: postLine(context, 'IP属地：$location', meta, key: const ValueKey('post-location-top')),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(
        left: DynamicPostTheme.gutter,
        right: DynamicPostTheme.gutter,
        top: DynamicPostTheme.authorTop,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '${author.name}的头像',
            onTap: open,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('post-author-face'),
              behavior: HitTestBehavior.opaque,
              onTap: open,
              child: PostFace(face: author.face, verify: author.verify),
            ),
          ),
          const SizedBox(width: DynamicPostTheme.faceGap),
          Expanded(child: lines),
        ],
      ),
    );
  }
}

/// The author's round face with the ⚡ badge sitting on its bottom right.
class PostFace extends StatelessWidget {
  const PostFace({super.key, required this.face, required this.verify});

  final String face;
  final DynamicVerify verify;

  @override
  Widget build(BuildContext context) {
    const overhang = DynamicPostTheme.badgeRing;
    return SizedBox.square(
      dimension: DynamicPostTheme.face,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: ClipOval(child: RemoteImage.avatar(face))),
          if (verify != DynamicVerify.none)
            Positioned(
              key: const ValueKey('post-verify'),
              right: -overhang,
              bottom: -overhang,
              width: DynamicPostTheme.badge,
              height: DynamicPostTheme.badge,
              child: CustomPaint(painter: VerifyBadgePainter(verify)),
            ),
        ],
      ),
    );
  }
}

/// `IP属地：…` under the body, where a picture or text post keeps it (140).
class PostLocation extends StatelessWidget {
  const PostLocation({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      left: DynamicPostTheme.gutter,
      right: DynamicPostTheme.gutter,
      top: DynamicPostTheme.bodyGap,
    ),
    child: SizedBox(
      height: DynamicPostTheme.metaLine,
      child: postLine(
        context,
        'IP属地：$location',
        postStyle(DynamicPostTheme.metaText, DynamicPostTheme.colorsOf(context).meta, line: DynamicPostTheme.metaLine),
        key: const ValueKey('post-location'),
      ),
    ),
  );
}
