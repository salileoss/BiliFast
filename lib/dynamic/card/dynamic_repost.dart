import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_environment.dart';
import '../../app/app_scope.dart';
import '../../home/feed_inline_player.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../space/space_follow.dart';
import '../../space/uploader_tap.dart';
import 'dynamic_open.dart';
import 'dynamic_pictures.dart';
import 'dynamic_rich_text.dart';
import 'dynamic_video_box.dart';

/// A repost's original in its grey block (132, 136): @name in blue with + 关注 when not followed, its text and body (a
/// video's box, or its pictures in a row scrolling sideways). A tap opens the original. [detail] lays it out as the
/// post page does (132).
class DynamicRepostBlock extends StatefulWidget {
  const DynamicRepostBlock({super.key, required this.original, this.inline, this.detail = false, this.onOpen});

  final DynamicItem original;
  final FeedInlineHost? inline;
  final bool detail;

  /// Opens the viewer at one of the original's pictures; [showDynamicPictures] over everything when null.
  final void Function(int index)? onOpen;

  /// An original Bilibili no longer has: no author, only the words saying so.
  static bool deleted(DynamicItem original) => original.author.mid <= 0;

  /// An original that didn't decode: no author and nothing to say, so no block is drawn for it.
  static bool blank(DynamicItem original) => deleted(original) && _words(original).isEmpty;

  /// The original's text, or for a deleted one the words saying so.
  static List<DynamicNode> _words(DynamicItem original) {
    if (original.nodes.isNotEmpty) return original.nodes;
    if (original.major case DynamicOtherMajor(:final title) when deleted(original) && title.isNotEmpty) {
      return [DynamicTextNode(title)];
    }
    return const [];
  }

  @override
  State<DynamicRepostBlock> createState() => _DynamicRepostBlockState();
}

class _DynamicRepostBlockState extends State<DynamicRepostBlock> {
  final _video = GlobalKey<DynamicVideoBoxState>();
  SpaceFollow? _follow;

  DynamicItem get _original => widget.original;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_follow != null || DynamicRepostBlock.deleted(_original)) return;
    final services = AppScope.of(context);
    final mid = _original.author.mid;
    _follow = SpaceFollow(
      mid: mid,
      api: services.pageApi,
      book: services.follows,
      isLoggedIn: () => services.environment.account is LoggedIn,
      requestLogin: () => unawaited(services.loginGate.request(context)),
      toast: (message) {
        if (mounted) showToast(context, message);
      },
      // A 关注 changed this run outlives the answer the card came with: scrolled back or on the post page, it holds.
      following: services.follows.following(mid) ?? _original.author.following,
    )..addListener(_changed);
  }

  @override
  void dispose() {
    _follow
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _open() {
    if (DynamicRepostBlock.deleted(_original)) return;
    if (_original.major case final DynamicVideo video) {
      unawaited(_video.currentState?.open() ?? openDynamicVideo(context, video));
      return;
    }
    unawaited(openDynamicItem(context, _original));
  }

  void _openAuthor() {
    final author = _original.author;
    unawaited(DynamicOpen.space(context, UploaderRef(mid: author.mid, name: author.name, face: author.face)));
  }

  @override
  Widget build(BuildContext context) {
    final original = _original;
    if (DynamicRepostBlock.blank(original)) return const SizedBox.shrink();
    final deleted = DynamicRepostBlock.deleted(original);
    final detail = widget.detail;
    final inset = detail ? DynamicCardTheme.repostDetailInset : DynamicCardTheme.gutter;
    final follow = _follow;
    final textStyle = dynamicStyle(
      DynamicCardTheme.text,
      DynamicCardTheme.colorsOf(context).repostTextInk,
      line: DynamicCardTheme.textLine,
    );
    final nodes = DynamicRepostBlock._words(original);
    final body = deleted ? null : _body(inset);
    final double bodyGap = nodes.isEmpty
        ? (detail ? DynamicCardTheme.repostDetailBodyGap : DynamicCardTheme.repostTextGap)
        : body is DynamicPictureStrip
        ? DynamicCardTheme.repostStripTop
        : DynamicCardTheme.bodyGap;
    return GestureDetector(
      key: const ValueKey('dynamic-repost-block'),
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: ColoredBox(
        color: DynamicCardTheme.colorsOf(context).repostFill,
        child: Padding(
          padding: EdgeInsets.only(
            top: detail ? DynamicCardTheme.repostDetailTop : DynamicCardTheme.repostTop,
            bottom: detail ? DynamicCardTheme.repostDetailBottom : DynamicCardTheme.repostBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!deleted)
                Padding(
                  padding: EdgeInsets.only(
                    left: detail ? DynamicCardTheme.repostDetailNameInset : inset,
                    right: inset,
                  ),
                  child: SizedBox(
                    height: DynamicCardTheme.repostNameLine,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              key: const ValueKey('dynamic-repost-name'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _openAuthor,
                              child: Text(
                                '@${original.author.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: dynamicStyle(
                                  DynamicCardTheme.repostNameText,
                                  DynamicCardTheme.colorsOf(context).linkInk,
                                  line: DynamicCardTheme.repostNameLine,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (follow != null && follow.following == false)
                          Semantics(
                            container: true,
                            button: true,
                            label: '关注',
                            onTap: () => unawaited(follow.toggle()),
                            excludeSemantics: true,
                            child: GestureDetector(
                              key: const ValueKey('dynamic-repost-follow'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => unawaited(follow.toggle()),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: DynamicCardTheme.repostFollowPad,
                                  top: DynamicCardTheme.repostFollowDrop,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CustomPaint(
                                      size: Size.square(DynamicCardTheme.repostPlus),
                                      painter: _PlusPainter(palette: BiliPalette.of(context)),
                                    ),
                                    const SizedBox(width: DynamicCardTheme.repostPlusGap),
                                    Text(
                                      '关注',
                                      maxLines: 1,
                                      style: dynamicStyle(
                                        DynamicCardTheme.repostFollowText,
                                        DynamicCardTheme.colorsOf(context).repostFollowInk,
                                      ).copyWith(height: 1),
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
              if (nodes.isNotEmpty) ...[
                if (!deleted) const SizedBox(height: DynamicCardTheme.repostTextGap),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: DynamicRichText(
                    key: ValueKey('dynamic-repost-text-${original.id}'),
                    nodes: nodes,
                    style: textStyle,
                    maxLines: detail ? null : DynamicCardTheme.maxLines,
                    folded: original.foldedLines && !detail,
                    onMore: deleted ? null : _open,
                  ),
                ),
              ],
              if (body != null) ...[SizedBox(height: bodyGap), body],
            ],
          ),
        ),
      ),
    );
  }

  /// The video's box [inset] in (on the list 13 short of the right), or the pictures' row running off the right.
  Widget? _body(double inset) => switch (_original.major) {
    final DynamicVideo video => Padding(
      padding: EdgeInsets.only(left: inset, right: widget.detail ? inset : DynamicCardTheme.videoTrail),
      child: DynamicVideoBox(
        key: _video,
        video: video,
        inline: widget.inline,
        titleTop: widget.detail ? DynamicCardTheme.repostDetailTitleTop : DynamicCardTheme.titleTop,
      ),
    ),
    DynamicPictures(:final pictures) when pictures.isNotEmpty => DynamicPictureStrip(
      pictures: pictures,
      inset: inset,
      onOpen: widget.onOpen,
    ),
    _ => null,
  };
}

/// + 关注's thin cross (136), drawn: SF's plus is shorter and heavier.
class _PlusPainter extends CustomPainter {
  final BiliPalette palette;

  const _PlusPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = DynamicCardThemeColors(palette).repostFollowInk
      ..strokeWidth = DynamicCardTheme.repostPlusStroke;
    final centre = size.center(Offset.zero);
    canvas
      ..drawLine(Offset(0, centre.dy), Offset(size.width, centre.dy), line)
      ..drawLine(Offset(centre.dx, 0), Offset(centre.dx, size.height), line);
  }

  @override
  bool shouldRepaint(_PlusPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
