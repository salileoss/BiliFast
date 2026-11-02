import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/logic.dart' show CountFormat;
import 'package:flutter/widgets.dart';

import '../../app/app_environment.dart';
import '../../app/app_scope.dart';
import '../../comments/comment_badges.dart' show DecorImage, SegmentGlyph;
import '../../home/feed_inline_player.dart';
import '../../search/results/user_row.dart' show VerifiedBoltPainter;
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../space/uploader_tap.dart';
import '../dynamic_like_book.dart';
import 'dynamic_goods.dart';
import 'dynamic_more_sheet.dart';
import 'dynamic_open.dart';
import 'dynamic_pictures.dart';
import 'dynamic_repost.dart';
import 'dynamic_rich_text.dart';
import 'dynamic_video_box.dart';

/// One post in a list (127, 128, 135, 136, 139): the author row with ⋮, the text, the body (pictures, the video box,
/// a repost's grey block), UP主的推荐 and the 转发 / 评论 / 赞 row. A video post opens the player; any other the post
/// page. [inline] plays its video muted when the list's host picks it.
class DynamicCard extends StatefulWidget {
  const DynamicCard({super.key, required this.item, this.inline, this.space = false});

  final DynamicItem item;
  final FeedInlineHost? inline;

  /// In a space's 动态 tab (136): its lighter band under the card, and a 图文 post's text at the plain pitch.
  final bool space;

  @override
  State<DynamicCard> createState() => _DynamicCardState();
}

class _DynamicCardState extends State<DynamicCard> {
  final _video = GlobalKey<DynamicVideoBoxState>();

  /// 展开 opened a video post's text in place.
  bool _expanded = false;

  DynamicItem get _item => widget.item;

  @override
  void didUpdateWidget(DynamicCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) _expanded = false;
  }

  /// A 图文 post's text is set at the 关注 feed's wider pitch (127, 135).
  bool get _opus =>
      !widget.space &&
      (_item.kind == DynamicKind.draw || _item.kind == DynamicKind.word || _item.kind == DynamicKind.article);

  void _open() {
    if (_item.major case final DynamicVideo video) {
      unawaited(_video.currentState?.open() ?? openDynamicVideo(context, video));
      return;
    }
    unawaited(openDynamicItem(context, _item));
  }

  void _openAuthor() {
    final author = _item.author;
    // In a space's 动态 every post is the space's own: it is already open.
    if (author.mid <= 0 || widget.space) return;
    unawaited(DynamicOpen.space(context, UploaderRef(mid: author.mid, name: author.name, face: author.face)));
  }

  void _comment() {
    if (_item.major is DynamicVideo) {
      _open();
    } else {
      unawaited(openDynamicItem(context, _item, toComments: true));
    }
  }

  Future<void> _like() async {
    final services = AppScope.of(context);
    if (services.environment.account case LoggedOut() || LoginExpired()) {
      await services.loginGate.request(context);
      return;
    }
    final outcome = await services.dynamicLikes.toggle(_item.id, _item.stat);
    if (!mounted) return;
    switch (outcome) {
      case LikeNeedsLogin():
        await services.loginGate.request(context);
      case LikeFailed(:final message):
        showToast(context, message);
      case LikeDone():
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final opus = _opus;
    final hasText = item.nodes.isNotEmpty;
    final video = item.major is DynamicVideo;
    final textStyle = dynamicStyle(
      DynamicCardTheme.text,
      DynamicCardTheme.colorsOf(context).textInk,
      line: opus ? DynamicCardTheme.opusTextLine : DynamicCardTheme.textLine,
    );
    final body = _body();
    final goods = item.goods;
    final double headHeight =
        (!hasText
            ? DynamicCardTheme.bodyTop
            : opus
            ? DynamicCardTheme.opusTextTop
            : DynamicCardTheme.textTop) +
        (item.author.pendant.isEmpty ? 0 : DynamicCardTheme.pendantDrop);
    final double textToBody = item.original != null
        ? DynamicCardTheme.repostGap
        : opus
        ? DynamicCardTheme.opusBodyGap
        : DynamicCardTheme.bodyGap;
    return Semantics(
      container: true,
      child: Column(
        key: ValueKey('dynamic-card-${item.id}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: ColoredBox(
              color: DynamicCardTheme.colorsOf(context).fill,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: headHeight,
                    child: _AuthorRow(
                      author: item.author,
                      onAuthor: _openAuthor,
                      onMore: () => unawaited(showDynamicMoreSheet(context, item)),
                    ),
                  ),
                  if (hasText)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DynamicCardTheme.gutter),
                      child: DynamicRichText(
                        key: ValueKey('dynamic-text-${item.id}'),
                        nodes: item.nodes,
                        style: textStyle,
                        maxLines: _expanded ? null : DynamicCardTheme.maxLines,
                        folded: item.foldedLines && !_expanded,
                        moreLabel: video ? '展开' : '全文',
                        onMore: video
                            ? () => setState(() => _expanded = true)
                            : () => unawaited(openDynamicItem(context, item)),
                      ),
                    ),
                  if (body != null) ...[
                    if (hasText) SizedBox(height: textToBody),
                    body,
                  ] else if (hasText)
                    const SizedBox(height: DynamicCardTheme.footerGap),
                  if (goods != null && goods.items.isNotEmpty) DynamicGoodsBlock(goods: goods),
                  _Footer(item: item, onForward: _soon, onComment: _comment, onLike: () => unawaited(_like())),
                ],
              ),
            ),
          ),
          SizedBox(
            height: DynamicCardTheme.band,
            child: ColoredBox(color: widget.space ? DynamicCardTheme.colorsOf(context).spaceBandInk : DynamicCardTheme.colorsOf(context).bandInk),
          ),
        ],
      ),
    );
  }

  void _soon() => showToast(context, notBuilt);

  Widget? _body() {
    final item = _item;
    if (item.original case final original?) {
      if (DynamicRepostBlock.blank(original)) return null;
      return DynamicRepostBlock(
        key: ValueKey('dynamic-repost-${original.id}'),
        original: original,
        inline: widget.inline,
      );
    }
    final Widget? inner = switch (item.major) {
      final DynamicVideo video => DynamicVideoBox(
        key: _video,
        video: video,
        inline: widget.inline,
        showTitle: video.badge.isEmpty,
      ),
      DynamicPictures(:final pictures) when pictures.isNotEmpty => DynamicPictureGrid(pictures: pictures),
      _ => null,
    };
    if (inner == null) return null;
    return Padding(
      padding: EdgeInsets.only(
        left: DynamicCardTheme.gutter,
        right: inner is DynamicVideoBox ? DynamicCardTheme.videoTrail : DynamicCardTheme.gutter,
      ),
      child: inner,
    );
  }
}

/// The face with its verification and any frame, the name and `pubTime · pubAction`, the fan card and ⋮ (127, 128,
/// 136).
class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.author, required this.onAuthor, required this.onMore});

  final DynamicAuthor author;
  final VoidCallback onAuthor;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final decoration = author.decoration;
    final framed = author.pendant.isNotEmpty;
    final textLeft = framed ? DynamicCardTheme.pendantTextLeft : DynamicCardTheme.textLeft;
    final timeCentre = DynamicCardTheme.timeCentre + (framed ? DynamicCardTheme.pendantTimeDrop : 0);
    final moreCentre = DynamicCardTheme.moreCentre - (framed ? DynamicCardTheme.pendantMoreRise : 0);
    final decorationTop = DynamicCardTheme.decorationTop - (framed ? DynamicCardTheme.pendantDecorationRise : 0);
    const frame = DynamicCardTheme.pendantFace * DynamicCardTheme.pendantScale;
    final nameRight = decoration != null
        ? DynamicCardTheme.decorationRight + DynamicCardTheme.decorationWidth + DynamicCardTheme.nameClearance
        : DynamicCardTheme.moreRight + DynamicCardTheme.moreTarget / 2;
    final nameStyle = dynamicStyle(
      DynamicCardTheme.nameText,
      author.vipPink ? DynamicCardTheme.colorsOf(context).nameVipInk : DynamicCardTheme.colorsOf(context).nameInk,
      weight: DynamicCardTheme.nameWeight,
      line: DynamicCardTheme.nameLine,
    );
    final timeStyle = dynamicStyle(
      DynamicCardTheme.timeText,
      DynamicCardTheme.colorsOf(context).timeInk,
      line: DynamicCardTheme.timeLine,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: framed ? DynamicCardTheme.pendantCentreX - frame / 2 : DynamicCardTheme.gutter,
          top: framed ? DynamicCardTheme.pendantCentreY - frame / 2 : DynamicCardTheme.faceTop,
          width: framed ? frame : DynamicCardTheme.face,
          height: framed ? frame : DynamicCardTheme.face,
          child: Semantics(
            container: true,
            button: true,
            label: author.name,
            onTap: onAuthor,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('dynamic-face'),
              behavior: HitTestBehavior.opaque,
              onTap: onAuthor,
              child: _Face(author: author),
            ),
          ),
        ),
        Positioned(
          left: textLeft,
          right: nameRight,
          top: DynamicCardTheme.nameCentre - DynamicCardTheme.nameLine / 2,
          height: DynamicCardTheme.nameLine,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ExcludeSemantics(
              child: GestureDetector(
                key: const ValueKey('dynamic-name'),
                behavior: HitTestBehavior.opaque,
                onTap: onAuthor,
                child: Text(
                  author.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                  strutStyle: BiliFonts.strut(nameStyle),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: textLeft,
          right: nameRight,
          top: timeCentre - DynamicCardTheme.timeLine / 2,
          height: DynamicCardTheme.timeLine,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: author.pubTime),
                if (author.pubAction.isNotEmpty) ...[
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: DynamicCardTheme.timeDotBefore,
                        right: DynamicCardTheme.timeDotAfter,
                      ),
                      child: SizedBox.square(
                        dimension: DynamicCardTheme.timeDot,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: DynamicCardTheme.colorsOf(context).timeInk, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                  TextSpan(text: author.pubAction),
                ],
              ],
            ),
            key: const ValueKey('dynamic-time'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: timeStyle,
            strutStyle: BiliFonts.strut(timeStyle),
          ),
        ),
        if (decoration != null)
          Positioned(
            right: DynamicCardTheme.decorationRight,
            top: decorationTop,
            width: DynamicCardTheme.decorationWidth,
            height: DynamicCardTheme.decorationHeight,
            child: _Decoration(decoration: decoration),
          ),
        Positioned(
          right: DynamicCardTheme.moreRight - DynamicCardTheme.moreTarget / 2,
          top: moreCentre - DynamicCardTheme.moreTarget / 2,
          width: DynamicCardTheme.moreTarget,
          height: DynamicCardTheme.moreTarget,
          child: Semantics(
            container: true,
            button: true,
            label: '更多',
            onTap: onMore,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('dynamic-more'),
              behavior: HitTestBehavior.opaque,
              onTap: onMore,
              child: Center(
                child: DynamicIcon(
                  DynamicArt.more,
                  width: DynamicCardTheme.moreWidth,
                  height: DynamicCardTheme.moreHeight,
                  color: DynamicCardTheme.colorsOf(context).moreInk,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.author});

  final DynamicAuthor author;

  @override
  Widget build(BuildContext context) {
    final badge = switch (author.verify) {
      DynamicVerify.personal => DynamicCardTheme.badgePerson,
      DynamicVerify.organisation => DynamicCardTheme.badgeOrganisation,
      DynamicVerify.none => null,
    };
    const ring = DynamicCardTheme.badgeRing;
    final framed = author.pendant.isNotEmpty;
    // Framed, the box is the frame's and the face sits in its middle.
    final inset = framed ? DynamicCardTheme.pendantFace * (DynamicCardTheme.pendantScale - 1) / 2 : 0.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: inset,
          top: inset,
          right: inset,
          bottom: inset,
          child: ClipOval(child: RemoteImage.avatar(author.face)),
        ),
        if (framed)
          Positioned.fill(
            child: IgnorePointer(
              child: KeyedSubtree(key: const ValueKey('dynamic-pendant'), child: DecorImage(author.pendant)),
            ),
          ),
        if (badge != null)
          Positioned(
            right: inset - ring,
            bottom: inset - ring,
            child: Container(
              key: const ValueKey('dynamic-verified'),
              width: DynamicCardTheme.badge + ring * 2,
              height: DynamicCardTheme.badge + ring * 2,
              padding: const EdgeInsets.all(ring),
              decoration: BoxDecoration(color: DynamicCardTheme.colorsOf(context).fill, shape: BoxShape.circle),
              child: CustomPaint(painter: VerifiedBoltPainter(badge)),
            ),
          ),
      ],
    );
  }
}

/// The fan card's art with its number in block letters, in the number's own colour (127).
class _Decoration extends StatelessWidget {
  const _Decoration({required this.decoration});

  final DynamicDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final number = decoration.number;
    final colour = decoration.colour;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          key: const ValueKey('dynamic-decoration'),
          clipBehavior: Clip.none,
          children: [
            if (decoration.cardUrl.isNotEmpty) Positioned.fill(child: DecorImage(decoration.cardUrl)),
            if (number.isNotEmpty)
              Positioned(
                right: DynamicCardTheme.decorationNumberRight,
                top: DynamicCardTheme.decorationNumberTop,
                child: CustomPaint(
                  key: const ValueKey('dynamic-decoration-number'),
                  size: Size(_FanDigits.width(number), DynamicCardTheme.decorationGlyphHeight),
                  painter: _FanDigits(number, colour == null ? DynamicCardTheme.decorationNumberInk : Color(colour)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FanDigits extends CustomPainter {
  const _FanDigits(this.number, this.color);

  final String number;
  final Color color;

  static double _glyph(String character) => SegmentGlyph.glyphWidth(
    character,
    width: DynamicCardTheme.decorationGlyphWidth,
    weight: DynamicCardTheme.decorationGlyphWeight,
  );

  /// The card's 1 keeps a wider cell than its stroke: [DynamicCardTheme.decorationOneAdvance] to the next digit, and
  /// as the last digit its cell's end, not its stroke, meets the number's right edge.
  static double _trail(String character) => character == '1'
      ? DynamicCardTheme.decorationOneAdvance - _glyph(character) - DynamicCardTheme.decorationGlyphGap
      : 0;

  static double width(String number) {
    var width = 0.0;
    for (final character in number.toUpperCase().split('')) {
      width += _glyph(character) + _trail(character) + DynamicCardTheme.decorationGlyphGap;
    }
    return number.isEmpty ? 0 : width - DynamicCardTheme.decorationGlyphGap;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = color;
    var x = 0.0;
    for (final character in number.toUpperCase().split('')) {
      final glyph = _glyph(character);
      SegmentGlyph.draw(
        canvas,
        character,
        Rect.fromLTWH(x, 0, glyph, DynamicCardTheme.decorationGlyphHeight),
        DynamicCardTheme.decorationGlyphWeight,
        ink,
      );
      x += glyph + _trail(character) + DynamicCardTheme.decorationGlyphGap;
    }
  }

  @override
  bool shouldRepaint(_FanDigits oldDelegate) => oldDelegate.number != number || oldDelegate.color != color;
}

/// 转发, 评论 and 赞 in three equal columns between the gutters (135); a zero shows the word instead (136).
class _Footer extends StatelessWidget {
  const _Footer({required this.item, required this.onForward, required this.onComment, required this.onLike});

  final DynamicItem item;
  final VoidCallback onForward;
  final VoidCallback onComment;
  final VoidCallback onLike;

  static String count(int value, String word) => value <= 0 ? word : CountFormat.short(value);

  @override
  Widget build(BuildContext context) {
    final likes = AppScope.of(context).dynamicLikes;
    return SizedBox(
      height: DynamicCardTheme.footer,
      child: Padding(
        padding: const EdgeInsets.only(
          left: DynamicCardTheme.gutter + DynamicCardTheme.footerShift,
          right: DynamicCardTheme.gutter - DynamicCardTheme.footerShift,
        ),
        child: ListenableBuilder(
          listenable: likes,
          builder: (context, _) {
            final stat = likes.stat(item.id, item.stat);
            return Row(
              children: [
                _FooterButton(
                  key: const ValueKey('dynamic-forward'),
                  icon: DynamicArt.forward,
                  iconWidth: DynamicCardTheme.forwardWidth,
                  iconCentre: DynamicCardTheme.forwardCentre,
                  text: count(stat.forward, '转发'),
                  label: '转发',
                  onTap: onForward,
                ),
                _FooterButton(
                  key: const ValueKey('dynamic-comment'),
                  icon: DynamicArt.comment,
                  iconWidth: DynamicCardTheme.commentWidth,
                  iconCentre: DynamicCardTheme.commentCentre,
                  text: count(stat.comment, '评论'),
                  label: '评论',
                  onTap: onComment,
                ),
                _FooterButton(
                  key: const ValueKey('dynamic-like'),
                  icon: stat.liked ? DynamicArt.liked : DynamicArt.like,
                  iconWidth: DynamicCardTheme.likeWidth,
                  iconCentre: DynamicCardTheme.likeCentre,
                  text: count(stat.like, '点赞'),
                  label: stat.liked ? '取消点赞' : '点赞',
                  ink: stat.liked ? DynamicCardTheme.colorsOf(context).footerLiked : DynamicCardTheme.colorsOf(context).footerInk,
                  onTap: onLike,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    super.key,
    required this.icon,
    required this.iconWidth,
    required this.iconCentre,
    required this.text,
    required this.label,
    required this.onTap,
    this.ink,
  });

  final String icon;
  final double iconWidth;
  final double iconCentre;
  final String text;
  final String label;
  final Color? ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = dynamicStyle(DynamicCardTheme.footerText, ink ?? DynamicCardTheme.colorsOf(context).footerInk).copyWith(height: 1);
    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        label: label,
        value: text == label ? null : text,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, iconCentre - DynamicCardTheme.footerCentre),
                  child: DynamicIcon(icon, width: iconWidth, color: ink ?? DynamicCardTheme.colorsOf(context).footerInk),
                ),
                const SizedBox(width: DynamicCardTheme.footerGapToCount),
                Text.rich(apartFromHan(text), maxLines: 1, softWrap: false, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
