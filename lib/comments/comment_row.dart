import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart' show BiliClient, Comment, CommentPicture;
import 'package:bili_core/logic.dart' show CountFormat, TimeFormat;
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart' show Icons, Material, MaterialType;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../shared/menu.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../space/space_route.dart';
import '../space/uploader_tap.dart';
import 'comment_badges.dart';
import 'comment_callbacks.dart';
import 'comments_model.dart';
import 'rich_text_view.dart';

/// One comment (10, 12, 13): avatar with its pendant and marks, name, LV and the other badges, the fan card, the
/// text, pictures, the meta line (time, place, 回复, 👍 N, 👎, ⋮) and, in the list, the replies preview. The face and
/// the name open the member's space, even on the video page (75).
class CommentRow extends StatelessWidget {
  const CommentRow({
    super.key,
    required this.comment,
    required this.model,
    required this.callbacks,
    this.thread,
    this.showsReplies = true,
    this.showsDivider = true,
  });

  final Comment comment;
  final CommentsModel model;
  final CommentCallbacks callbacks;

  /// Inside 评论详情, the thread's root: 回复 on a reply then answers it in the thread.
  final Comment? thread;

  /// The grey box of reply previews and 共N条回复, in the list only.
  final bool showsReplies;

  /// The hairline under the row, indented to the text. Without it the row is 评论详情's root and ends where the band
  /// starts.
  final bool showsDivider;

  void _reply() {
    final root = thread;
    final target = root == null || root.rpid == comment.rpid
        ? ReplyToComment(comment)
        : ReplyInThread(root: root, reply: comment);
    callbacks.reply(target, false);
  }

  void _openMenuAt(BuildContext context, BuildContext anchor) {
    final box = anchor.findRenderObject()! as RenderBox;
    _openMenu(context, box.localToGlobal(Offset.zero) & box.size);
  }

  void _openMenu(BuildContext context, Rect rect) {
    final own = model.isOwn(comment);
    unawaited(
      Navigator.of(context).push(
        _CommentMenuRoute(
          anchor: rect,
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: comment.message));
            if (context.mounted) showToast(context, '已复制');
          },
          onDelete: own ? () => callbacks.confirmDelete(comment) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = comment.member;
    final card = member.fanCardImage;
    // CommentText draws a reply's leading "回复 @name :" as the official lead itself.
    final runs = comment.runs;
    final hasText = runs.isNotEmpty || comment.isPinned;
    final repliesBox = showsReplies && (comment.replyCount > 0 || comment.previewReplies.isNotEmpty);
    final upChip = !showsReplies && comment.upLiked;
    final tail = repliesBox
        ? CommentRowTheme.boxBottom + CommentRowTheme.divider
        : upChip
        ? CommentRowTheme.upChipBottom + (showsDivider ? CommentRowTheme.divider : 0)
        : showsDivider
        ? CommentRowTheme.bottom + CommentRowTheme.divider
        : CommentListTheme.bandGap;
    const nameTop = CommentRowTheme.nameCentre - CommentRowTheme.nameLine / 2;
    const textLeft = EdgeInsets.only(left: CommentRowTheme.textLeading, right: CommentRowTheme.gutter);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: nameTop),
            Padding(
              padding: EdgeInsets.only(
                left: CommentRowTheme.textLeading,
                right: card == null
                    ? CommentRowTheme.gutter
                    : CommentRowTheme.fanCardLeft + CommentRowTheme.fanCardClearance,
              ),
              child: _NameLine(
                comment: comment,
                isUp: model.upMid != 0 && member.mid == model.upMid,
                onOpen: _spaceOpener(context, comment),
              ),
            ),
            SizedBox(height: CommentRowTheme.textTop - nameTop - CommentRowTheme.nameLine),
            if (hasText)
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: CommentRowTheme.textMinBottom - CommentRowTheme.textTop),
                child: Padding(
                  padding: textLeft,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      // A long comment's top can be under the player, so the menu opens where the finger is.
                      onLongPressStart: (details) {
                        unawaited(HapticFeedback.selectionClick());
                        _openMenu(context, Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0));
                      },
                      child: CommentText(
                        runs: runs,
                        style: CommentRowTheme.textStyle.copyWith(color: CommentRowTheme.colorsOf(context).text),
                        leading: comment.isPinned
                            ? const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: CommentRowTheme.pinnedPadding),
                                  child: PinnedTag(),
                                ),
                              )
                            : null,
                        onSeek: callbacks.seek,
                        onOpenVideo: callbacks.openVideo,
                      ),
                    ),
                  ),
                ),
              ),
            if (comment.pictures.isNotEmpty) ...[
              Padding(
                padding: textLeft,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: CommentPictures(
                    pictures: comment.pictures,
                    compact: !showsReplies,
                    onOpen: (index) => callbacks.viewPictures(comment.pictures, index),
                  ),
                ),
              ),
              const SizedBox(height: CommentRowTheme.pictureGap),
            ],
            SizedBox(
              height: CommentRowTheme.metaHeight,
              child: _MetaLine(
                comment: comment,
                onReply: _reply,
                onLike: () => unawaited(model.toggleLike(comment)),
                onHate: () => unawaited(model.toggleHate(comment)),
                onMore: (anchor) => _openMenuAt(context, anchor),
              ),
            ),
            if (showsReplies && comment.upLiked) const _UpLiked(),
            if (upChip) ...[SizedBox(height: CommentRowTheme.upChipTop), const _UpLikedChip()],
            if (repliesBox) ...[
              SizedBox(height: CommentRowTheme.boxGap),
              Padding(
                padding: const EdgeInsets.only(left: CommentRowTheme.boxLeading, right: CommentRowTheme.gutter),
                child: _RepliesBox(comment: comment, onOpen: () => callbacks.openThread(comment)),
              ),
            ],
            SizedBox(height: tail),
          ],
        ),
        Positioned(
          left: CommentRowTheme.gutter,
          top: CommentRowTheme.avatarTop,
          // VoiceOver reaches the space through the name.
          child: GestureDetector(
            key: const ValueKey('comment-avatar'),
            behavior: HitTestBehavior.opaque,
            onTap: _spaceOpener(context, comment),
            child: CommentAvatar(member: member),
          ),
        ),
        if (card != null)
          Positioned(
            top: CommentRowTheme.fanCardTop,
            right: 0,
            width: CommentRowTheme.fanCardLeft,
            height: CommentRowTheme.fanCardHeight,
            child: FanCard(image: card, number: member.fanCardNumber, color: member.fanCardColor),
          ),
        if (showsDivider)
          Positioned(
            left: CommentRowTheme.dividerLeading,
            right: 0,
            bottom: 0,
            height: CommentRowTheme.divider,
            child: ColoredBox(key: ValueKey('comment-divider'), color: CommentRowTheme.colorsOf(context).dividerColour),
          ),
      ],
    );
  }
}

/// The writer's mid: the member's, or the comment's when the member came without one.
int _writerMid(Comment comment) => comment.member.mid > 0 ? comment.member.mid : comment.mid;

/// The tap that opens [comment]'s writer's space; null when the server named no mid.
VoidCallback? _spaceOpener(BuildContext context, Comment comment) {
  final mid = _writerMid(comment);
  if (mid <= 0) return null;
  final member = comment.member;
  return () => unawaited(openSpace(context, UploaderRef(mid: mid, name: member.name, face: member.face)));
}

class _NameLine extends StatelessWidget {
  const _NameLine({required this.comment, required this.isUp, required this.onOpen});

  final Comment comment;
  final bool isUp;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final member = comment.member;
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: CommentRowTheme.nameText,
      height: CommentRowTheme.nameLine / CommentRowTheme.nameText,
      leadingDistribution: TextLeadingDistribution.even,
      color: member.isVip ? CommentRowTheme.colorsOf(context).vipName : CommentRowTheme.colorsOf(context).name,
    );
    return SizedBox(
      height: CommentRowTheme.nameLine,
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              button: onOpen != null,
              label: member.name,
              onTap: onOpen,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('comment-name'),
                behavior: HitTestBehavior.opaque,
                onTap: onOpen,
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                  strutStyle: BiliFonts.strutOf(context, style),
                ),
              ),
            ),
          ),
          const SizedBox(width: CommentRowTheme.badgeGap),
          LevelBadge(level: member.level),
          if (isUp) ...[const SizedBox(width: CommentRowTheme.upGap), const UpBadge()],
        ],
      ),
    );
  }
}

/// "1小时前 湖北 回复" at the left; 👍 N, 👎 and ⋮ at fixed places from the right edge.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.comment,
    required this.onReply,
    required this.onLike,
    required this.onHate,
    required this.onMore,
  });

  final Comment comment;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onHate;
  final ValueChanged<BuildContext> onMore;

  /// Room the left part leaves for 👍 and the widest count.
  static const _likeRoom =
      CommentRowTheme.likeTrailing +
      CommentRowTheme.thumbInk +
      CommentRowTheme.thumbCountGap +
      CommentRowTheme.countRoom;

  String get _stamp {
    final time = TimeFormat.comment(comment.ctime, now: DateTime.now());
    final location = comment.location;
    return location == null ? time : '$time $location';
  }

  @override
  Widget build(BuildContext context) {
    final hated = comment.action == 2;
    return Stack(
      children: [
        Positioned(
          left: CommentRowTheme.textLeading,
          right: _likeRoom,
          top: CommentRowTheme.metaDrop,
          bottom: -CommentRowTheme.metaDrop,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  _stamp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CommentRowTheme.metaStyle(CommentRowTheme.colorsOf(context).meta),
                  strutStyle: BiliFonts.strutOf(context, CommentRowTheme.metaStyle(CommentRowTheme.colorsOf(context).meta)),
                ),
              ),
              Semantics(
                button: true,
                label: '回复',
                onTap: onReply,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('comment-reply'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onReply,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: CommentRowTheme.replyGap,
                      right: CommentRowTheme.replyTrailing,
                    ),
                    child: Center(child: Text('回复', style: CommentRowTheme.metaStyle(CommentRowTheme.colorsOf(context).action))),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: CommentRowTheme.likeTrailing - CommentRowTheme.likeTarget,
          top: 0,
          bottom: 0,
          child: _LikeButton(liked: comment.action == 1, likes: comment.likes, onTap: onLike),
        ),
        Positioned(
          right: CommentRowTheme.dislikeCentre - CommentRowTheme.dislikeTarget / 2,
          width: CommentRowTheme.dislikeTarget,
          top: 0,
          bottom: 0,
          child: Semantics(
            button: true,
            label: '点踩',
            selected: hated,
            onTap: onHate,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('comment-dislike'),
              behavior: HitTestBehavior.opaque,
              onTap: onHate,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, CommentRowTheme.dislikeDrop - CommentRowTheme.thumbLift),
                  child: CommentThumb(
                    down: true,
                    solid: hated,
                    color: hated ? CommentRowTheme.colorsOf(context).liked : CommentRowTheme.colorsOf(context).action,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: CommentRowTheme.moreCentre - CommentRowTheme.moreTarget / 2,
          width: CommentRowTheme.moreTarget,
          top: 0,
          bottom: 0,
          child: Builder(
            builder: (anchor) => Semantics(
              button: true,
              label: '更多',
              onTap: () => onMore(anchor),
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('comment-more'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onMore(anchor),
                child: Center(
                  child: CustomPaint(
                    size: Size(CommentRowTheme.moreDot, CommentRowTheme.moreDot + CommentRowTheme.morePitch * 2),
                    painter: _DotsPainter(palette: BiliPalette.of(context)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 👍 and its count; the thumb swells once as it turns pink.
class _LikeButton extends StatefulWidget {
  const _LikeButton({required this.liked, required this.likes, required this.onTap});

  final bool liked;
  final int likes;
  final VoidCallback onTap;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: CommentRowTheme.likePopDuration,
    value: 1,
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: CommentRowTheme.likePop).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: CommentRowTheme.likePop, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]).animate(_pop);

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liked && !oldWidget.liked && !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liked = widget.liked;
    final colour = liked ? CommentRowTheme.colorsOf(context).liked : CommentRowTheme.colorsOf(context).action;
    final count = widget.likes > 0 ? CountFormat.short(widget.likes) : null;
    return Semantics(
      button: true,
      label: count == null ? '点赞' : '点赞 $count',
      selected: liked,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('comment-like'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CommentRowTheme.likeTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: const Offset(0, -CommentRowTheme.thumbLift),
                child: ScaleTransition(
                  scale: _scale,
                  child: CommentThumb(solid: liked, color: colour),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: CommentRowTheme.thumbCountGap),
                Transform.translate(
                  offset: Offset(0, CommentRowTheme.metaDrop),
                  child: Text(
                    count,
                    style: CommentRowTheme.metaStyle(colour),
                    strutStyle: BiliFonts.strutOf(context, CommentRowTheme.metaStyle(colour)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final BiliPalette palette;
  const _DotsPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = CommentRowThemeColors(palette).action;
    const radius = CommentRowTheme.moreDot / 2;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(radius, radius + i * CommentRowTheme.morePitch), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

class _UpLiked extends StatelessWidget {
  const _UpLiked();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: CommentRowTheme.textLeading),
    child: SizedBox(
      height: CommentRowTheme.upLikedHeight,
      child: Row(
        children: [
          CommentThumb(solid: true, width: CommentRowTheme.upLikedIcon, color: CommentRowTheme.colorsOf(context).upLiked),
          const SizedBox(width: CommentRowTheme.upLikedGap),
          Text(
            'UP主觉得很赞',
            style: CommentRowTheme.metaStyle(CommentRowTheme.colorsOf(context).upLiked),
            strutStyle: BiliFonts.strutOf(context, CommentRowTheme.metaStyle(CommentRowTheme.colorsOf(context).upLiked)),
          ),
        ],
      ),
    ),
  );
}

/// 评论详情's UP主觉得很赞, the text in a grey box.
class _UpLikedChip extends StatelessWidget {
  const _UpLikedChip();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: CommentRowTheme.textLeading),
    child: Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        key: const ValueKey('comment-up-liked'),
        decoration: BoxDecoration(
          color: CommentRowTheme.colorsOf(context).upChipFill,
          borderRadius: BorderRadius.all(Radius.circular(CommentRowTheme.upChipRadius)),
        ),
        child: SizedBox(
          height: CommentRowTheme.upChipHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CommentRowTheme.upChipPadding),
            child: Center(
              widthFactor: 1,
              child: Text(
                'UP主觉得很赞',
                maxLines: 1,
                softWrap: false,
                style: CommentRowTheme.upChipStyle.copyWith(color: CommentRowTheme.colorsOf(context).upChipInk),
                strutStyle: BiliFonts.strutOf(context, CommentRowTheme.upChipStyle.copyWith(color: CommentRowTheme.colorsOf(context).upChipInk)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The grey box under a comment in the list: up to two replies and 共N条回复 › (10, 12). A reply's name opens its
/// space; any other tap opens the thread. To accessibility the box is one button, with each reply's name a button
/// inside it.
class _RepliesBox extends StatelessWidget {
  const _RepliesBox({required this.comment, required this.onOpen});

  final Comment comment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final previews = comment.previewReplies.take(2).toList();
    final count = comment.replyCount;
    final moreStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: CommentRowTheme.moreText,
      color: CommentRowTheme.colorsOf(context).moreLink,
    );
    // The box's tap is PressHighlight's own: a second one on this node would split that off as a blank node.
    return Semantics(
      container: true,
      button: true,
      label: count > 0 ? '共$count条回复' : '查看回复',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CommentRowTheme.boxRadius),
        child: PressHighlight(
          key: const ValueKey('comment-replies'),
          onTap: onOpen,
          child: ColoredBox(
            color: CommentRowTheme.colorsOf(context).box,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CommentRowTheme.boxPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (previews.isNotEmpty) ...[
                    const SizedBox(height: CommentRowTheme.previewTop),
                    for (final (i, reply) in previews.indexed)
                      _PullUp(
                        by: i > 0 ? CommentRowTheme.previewOverlap : 0,
                        child: _PreviewLine(reply: reply),
                      ),
                    if (count == 0) const SizedBox(height: CommentRowTheme.previewTop),
                  ],
                  if (count > 0)
                    _PullUp(
                      by: previews.isNotEmpty ? CommentRowTheme.moreSlotOverlap : 0,
                      child: SizedBox(
                        height: CommentRowTheme.moreSlot,
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Text(
                                '共$count条回复',
                                style: moreStyle,
                                strutStyle: BiliFonts.strutOf(context, moreStyle),
                              ),
                              const SizedBox(width: CommentRowTheme.chevronGap),
                              CustomPaint(
                                size: Size(CommentRowTheme.chevronWidth, CommentRowTheme.chevronHeight),
                                painter: _ChevronPainter(palette: BiliPalette.of(context)),
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
}

/// "name: text…" in two lines, with "| 👍 N" after its last line. The name opens its space; to accessibility the
/// whole preview is that name's button.
class _PreviewLine extends StatefulWidget {
  const _PreviewLine({required this.reply});

  final Comment reply;

  @override
  State<_PreviewLine> createState() => _PreviewLineState();
}

class _PreviewLineState extends State<_PreviewLine> {
  late final _name = TapGestureRecognizer()..onTap = () => _spaceOpener(context, widget.reply)?.call();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.reply;
    final text = CommentText(
      runs: reply.runs,
      style: CommentRowTheme.previewStyle.copyWith(color: CommentRowTheme.colorsOf(context).preview),
      leading: TextSpan(
        children: [
          TextSpan(
            text: reply.member.name,
            style: TextStyle(color: CommentRowTheme.colorsOf(context).previewName),
            recognizer: _writerMid(reply) > 0 ? _name : null,
          ),
          const TextSpan(text: ': '),
        ],
      ),
      maxLines: 2,
      linksOpen: false,
    );
    final open = _spaceOpener(context, reply);
    final preview = _PreviewText(
      ellipsis: CommentRowTheme.previewStyle.copyWith(color: CommentRowTheme.colorsOf(context).preview),
      mask: CommentRowTheme.colorsOf(context).box,
      cutGrowth: CommentRowTheme.previewCutGrowth,
      children: [
        text,
        if (reply.likes <= 0)
          const SizedBox.shrink()
        else
          SizedBox(
            height: CommentRowTheme.previewLine,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: CommentRowTheme.previewRuleGap),
                SizedBox(
                  width: CommentRowTheme.previewRuleWidth,
                  height: CommentRowTheme.previewRuleHeight,
                  child: ColoredBox(color: CommentRowTheme.colorsOf(context).dividerColour),
                ),
                const SizedBox(width: CommentRowTheme.previewRuleGap),
                CommentThumb(color: CommentRowTheme.colorsOf(context).action),
                const SizedBox(width: CommentRowTheme.thumbCountGap),
                Transform.translate(
                  offset: Offset(0, CommentRowTheme.metaDrop),
                  child: Text(
                    CountFormat.short(reply.likes),
                    style: CommentRowTheme.metaStyle(CommentRowTheme.colorsOf(context).action),
                    strutStyle: BiliFonts.strutOf(context, CommentRowTheme.metaStyle(CommentRowTheme.colorsOf(context).action)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (open == null) return ExcludeSemantics(child: preview);
    // The paragraph would make the name a link and the rest of the text stops of their own; the box stays one stop.
    return Semantics(
      container: true,
      button: true,
      label: reply.member.name,
      onTap: open,
      excludeSemantics: true,
      child: preview,
    );
  }
}

/// A preview's text at the box's full width with its likes, if any, after the last line. When that line leaves no
/// room for them it is cut short with "…" there, as 12's is, rather than narrowing the first line too.
class _PreviewText extends MultiChildRenderObjectWidget {
  const _PreviewText({required this.ellipsis, required this.mask, required this.cutGrowth, required super.children});

  final TextStyle ellipsis;

  /// The box's fill, laid over the end of a line that is cut short.
  final Color mask;

  /// How much taller a preview stands when its text runs past its lines.
  final double cutGrowth;

  @override
  _RenderPreviewText createRenderObject(BuildContext context) =>
      _RenderPreviewText(ellipsis: ellipsis, mask: mask, cutGrowth: cutGrowth);

  @override
  void updateRenderObject(BuildContext context, _RenderPreviewText renderObject) {
    renderObject
      ..ellipsis = ellipsis
      ..mask = mask
      ..cutGrowth = cutGrowth;
  }
}

class _PreviewSlot extends ContainerBoxParentData<RenderBox> {}

class _RenderPreviewText extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _PreviewSlot>, RenderBoxContainerDefaultsMixin<RenderBox, _PreviewSlot> {
  _RenderPreviewText({required this._ellipsis, required this._mask, required this._cutGrowth});

  TextStyle _ellipsis;
  set ellipsis(TextStyle value) {
    if (value == _ellipsis) return;
    _ellipsis = value;
    markNeedsLayout();
  }

  Color _mask;
  set mask(Color value) {
    if (value == _mask) return;
    _mask = value;
    markNeedsPaint();
  }

  double _cutGrowth;
  set cutGrowth(double value) {
    if (value == _cutGrowth) return;
    _cutGrowth = value;
    markNeedsLayout();
  }

  final TextPainter _dots = TextPainter(textDirection: TextDirection.ltr);
  Rect? _cut;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PreviewSlot) child.parentData = _PreviewSlot();
  }

  static RenderParagraph? _paragraph(RenderObject node) {
    if (node is RenderParagraph) return node;
    RenderParagraph? found;
    node.visitChildren((child) => found ??= _paragraph(child));
    return found;
  }

  @override
  void performLayout() {
    final text = firstChild!;
    final likes = childAfter(text)!;
    final width = constraints.maxWidth;
    text.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    likes.layout(const BoxConstraints(), parentUsesSize: true);
    _cut = null;
    size = constraints.constrain(Size(width, text.size.height));
    final likesSlot = likes.parentData! as _PreviewSlot;
    final paragraph = _paragraph(text);
    final boxes = paragraph?.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length),
    );
    if (paragraph == null || boxes == null || boxes.isEmpty) {
      likesSlot.offset = Offset(text.size.width, text.size.height - likes.size.height);
      return;
    }
    if (paragraph.didExceedMaxLines) size = constraints.constrain(Size(width, text.size.height + _cutGrowth));
    final shift = MatrixUtils.transformPoint(paragraph.getTransformTo(text), Offset.zero);
    final last = boxes.last;
    final centre = (last.top + last.bottom) / 2;
    var end = 0.0;
    for (final box in boxes) {
      if ((box.top - last.top).abs() < 1) end = math.max(end, box.right);
    }
    final room = width - likes.size.width - shift.dx;
    // Without likes the text's own ellipsis ends a long preview.
    if (likes.size.width == 0 || (!paragraph.didExceedMaxLines && end <= room)) {
      likesSlot.offset = shift + Offset(end, centre - likes.size.height / 2);
      return;
    }
    _dots
      ..text = TextSpan(text: '…', style: _ellipsis)
      ..strutStyle = paragraph.strutStyle
      ..layout();
    final target = room - _dots.width;
    final start = paragraph.getPositionForOffset(Offset(0, centre)).offset;
    var cut = paragraph.getPositionForOffset(Offset(target, centre)).offset;
    var stop = 0.0;
    for (; cut > start; cut--) {
      final glyph = paragraph.getBoxesForSelection(TextSelection(baseOffset: cut - 1, extentOffset: cut));
      if (glyph.isNotEmpty && glyph.last.right <= target + 0.01) {
        stop = glyph.last.right;
        break;
      }
    }
    _cut = Rect.fromLTRB(stop, last.top, width, last.bottom).shift(shift);
    likesSlot.offset = shift + Offset(stop + _dots.width, centre - likes.size.height / 2);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final text = firstChild!;
    final likes = childAfter(text)!;
    context.paintChild(text, offset);
    final cut = _cut;
    if (cut != null) {
      context.canvas.drawRect(cut.shift(offset), Paint()..color = _mask);
      _dots.paint(context.canvas, offset + Offset(cut.left, cut.center.dy - _dots.height / 2));
    }
    context.paintChild(likes, offset + (likes.parentData! as _PreviewSlot).offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }
}

class _ChevronPainter extends CustomPainter {
  final BiliPalette palette;
  const _ChevronPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = CommentRowTheme.chevronStroke / 2;
    canvas.drawPath(
      Path()
        ..moveTo(inset, inset)
        ..lineTo(size.width - inset, size.height / 2)
        ..lineTo(inset, size.height - inset),
      Paint()
        ..color = CommentRowThemeColors(palette).moreLink
        ..style = PaintingStyle.stroke
        ..strokeWidth = CommentRowTheme.chevronStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// Its child drawn [by] higher than where the column puts it, and that much shorter, so it can sit closer to what's
/// above than a gap of zero allows.
class _PullUp extends SingleChildRenderObjectWidget {
  const _PullUp({required this.by, required super.child});

  final double by;

  @override
  _RenderPullUp createRenderObject(BuildContext context) => _RenderPullUp(by);

  @override
  void updateRenderObject(BuildContext context, _RenderPullUp renderObject) => renderObject.by = by;
}

class _RenderPullUp extends RenderShiftedBox {
  _RenderPullUp(this._by) : super(null);

  double _by;
  set by(double value) {
    if (value == _by) return;
    _by = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints, parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(0, -_by);
    size = constraints.constrain(Size(child.size.width, math.max(0, child.size.height - _by)));
  }
}

/// A comment's pictures: one large at its own aspect (10), two side by side, four in two rows, any other count in
/// rows of three. A tap opens the viewer at that picture.
class CommentPictures extends StatelessWidget {
  const CommentPictures({super.key, required this.pictures, required this.onOpen, this.compact = false});

  final List<CommentPicture> pictures;
  final ValueChanged<int> onOpen;

  /// 评论详情's smaller single picture (13).
  final bool compact;

  /// Bilibili's image servers scale on request ("@480w.webp"); the viewer asks for its own screen-sized copy.
  static String thumbnail(String url, {required int width}) {
    final secure = secureImageUrl(url);
    if (!secure.contains('hdslb.com/bfs/') || secure.contains('@') || secure.contains('?')) return secure;
    return '$secure@${width}w.webp';
  }

  /// The row's picture at [thumbnail]'s address, moving if it moves; the viewer looks for it under its cache key.
  static StoredNetworkImage thumbnailImage(String url, {required int width}) =>
      StoredNetworkImage(thumbnail(url, width: width), headers: BiliClient.mediaHeaders, still: false);

  /// The single picture's size: tall ones narrower and cut at 3:4, wide ones wider and no flatter than 16:9.
  static Size single(CommentPicture picture, {bool compact = false}) {
    final ratio = picture.width > 0 && picture.height > 0 ? picture.height / picture.width : 1.0;
    final double width = ratio >= 1
        ? (compact ? CommentRowTheme.threadPictureTall : CommentRowTheme.pictureTall)
        : (compact ? CommentRowTheme.threadPictureWide : CommentRowTheme.pictureWide);
    return Size(width, width * clampDouble(ratio, CommentRowTheme.flattestRatio, CommentRowTheme.tallestRatio));
  }

  @override
  Widget build(BuildContext context) {
    if (pictures.length == 1) {
      final picture = pictures.single;
      final size = single(picture, compact: compact);
      return _PictureCell(picture: picture, index: 0, size: size, onOpen: onOpen);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = CommentRowTheme.pictureSpacing;
        final count = pictures.length;
        final columns = count == 2 || count == 4 ? 2 : 3;
        final side = count == 2 ? (constraints.maxWidth - spacing) / 2 : (constraints.maxWidth - spacing * 2) / 3;
        final rows = (count / columns).ceil();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: spacing),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = row * columns; i < math.min(count, (row + 1) * columns); i++) ...[
                    if (i > row * columns) const SizedBox(width: spacing),
                    _PictureCell(picture: pictures[i], index: i, size: Size.square(side), onOpen: onOpen),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PictureCell extends StatelessWidget {
  const _PictureCell({required this.picture, required this.index, required this.size, required this.onOpen});

  final CommentPicture picture;
  final int index;
  final Size size;
  final ValueChanged<int> onOpen;

  /// Sizes are asked for in steps, as [RemoteImage] does, so pictures of nearly the same size share a download.
  static const _step = 60;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final pixels = ((size.width * ratio) / _step).ceil() * _step;
    final long = picture.width > 0 && picture.height / picture.width > CommentRowTheme.tallestRatio;
    return Semantics(
      button: true,
      label: '图片 ${index + 1}',
      onTap: () => onOpen(index),
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('comment-picture-$index'),
        onTap: () => onOpen(index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CommentRowTheme.pictureRadius),
          child: SizedBox.fromSize(
            size: size,
            child: ColoredBox(
              color: CommentRowTheme.colorsOf(context).picturePlaceholder,
              child: Image(
                image: CommentPictures.thumbnailImage(picture.url, width: pixels),
                fit: BoxFit.cover,
                alignment: long ? Alignment.topCenter : Alignment.center,
                width: size.width,
                height: size.height,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, synchronous) => synchronous
                    ? child
                    : AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        child: child,
                      ),
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ⋮'s menu, frosted glass as the feed card's: 复制, and 删除 on the viewer's own comment.
class _CommentMenuRoute extends PopupRoute<void> {
  _CommentMenuRoute({required this.anchor, required this.reduceMotion, required this.onCopy, required this.onDelete});

  final Rect anchor;
  final bool reduceMotion;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => '关闭菜单';

  @override
  Duration get transitionDuration => reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => reduceMotion ? Duration.zero : const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final delete = onDelete;
    final height = BiliMetrics.menuRowHeight * (delete == null ? 1 : 2);
    final lowest = screen.height - padding.bottom - BiliMetrics.gutter - height;
    final below = anchor.bottom + BiliMetrics.cardMenuGap <= lowest;
    final top = clampDouble(
      below ? anchor.bottom + BiliMetrics.cardMenuGap : anchor.top - BiliMetrics.cardMenuGap - height,
      padding.top + BiliMetrics.gutter,
      math.max(padding.top + BiliMetrics.gutter, lowest),
    );
    final left = clampDouble(
      anchor.right - BiliMetrics.cardMenuWidth,
      BiliMetrics.gutter,
      screen.width - BiliMetrics.gutter - BiliMetrics.cardMenuWidth,
    );
    void choose(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: ScaleTransition(
            alignment: below ? Alignment.topRight : Alignment.bottomRight,
            scale: Tween(begin: 0.8, end: 1.0).animate(animation),
            child: FadeTransition(
              opacity: animation,
              child: Material(
                type: MaterialType.transparency,
                child: GlassPanel(
                  width: BiliMetrics.cardMenuWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MenuRow(
                        key: const ValueKey('comment-copy'),
                        title: '复制',
                        icon: Icons.content_copy_outlined,
                        onTap: () => choose(onCopy),
                      ),
                      if (delete != null)
                        MenuRow(
                          key: const ValueKey('comment-delete'),
                          title: '删除',
                          icon: Icons.delete_outline,
                          onTap: () => choose(delete),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;

  CurvedAnimation? _curve;

  @override
  Animation<double> createAnimation() =>
      _curve = CurvedAnimation(parent: super.createAnimation(), curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);

  @override
  void dispose() {
    _curve?.dispose();
    super.dispose();
  }
}
