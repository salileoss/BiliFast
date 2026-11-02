import 'dart:async';

import 'package:bili_core/api.dart' show Comment, CommentSort;
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../shared/loading_tv.dart';
import '../shared/theme.dart';
import '../video/collapsing_player.dart';
import 'comment_callbacks.dart';
import 'comment_row.dart';
import 'comments_model.dart';

/// 评论 (10-12): 热门评论 / 最新评论 with ≡ 按热度 / 按时间, the pinned comment, the list paging as it nears the end,
/// its footer, and the 发条评论 bar fixed at the bottom. Asks [model] for its first page when it first
/// shows, with the loading TV centred over what's left above the bar until it lands (64). Its list scrolls with the
/// page's primary scroll controller and starts `PlayerReserve` below its top.
class CommentsTab extends StatefulWidget {
  const CommentsTab({super.key, required this.model, required this.callbacks});

  final CommentsModel model;
  final CommentCallbacks callbacks;

  @override
  State<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<CommentsTab> {
  late NearEndPaging _paging = commentsPaging(widget.model);

  /// The sort header stays once a list has shown, so another sort's first load keeps its toggle.
  bool _listShown = false;

  @override
  void initState() {
    super.initState();
    _listShown = !commentsFirstLoad(widget.model);
    widget.model.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfShown();
  }

  @override
  void didUpdateWidget(CommentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.model, widget.model)) return;
    oldWidget.model.removeListener(_changed);
    _paging.dispose();
    _paging = commentsPaging(widget.model);
    _listShown = !commentsFirstLoad(widget.model);
    widget.model.addListener(_changed);
    _loadIfShown();
  }

  /// The tab is kept alive beside 简介, where the pager turns its tickers off; a new video there (自动连播) waits for
  /// 评论 to show before asking for its first page.
  void _loadIfShown() {
    if (TickerMode.valuesOf(context).enabled) unawaited(widget.model.ensureLoaded());
  }

  @override
  void dispose() {
    widget.model.removeListener(_changed);
    _paging.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() => _listShown |= !commentsFirstLoad(widget.model));
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return ColoredBox(
      color: CommentListTheme.colorsOf(context).background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _paging.listen(
              CustomScrollView(
                primary: true,
                slivers: [
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (context) =>
                          SizedBox(key: const ValueKey('comments-reserve'), height: PlayerReserve.of(context)),
                    ),
                  ),
                  ...commentListSlivers(model: model, callbacks: widget.callbacks, headerKept: _listShown),
                ],
              ),
            ),
          ),
          if (model.closedMessage == null)
            CommentWriteBar(
              prompt: model.rootPrompt,
              onWrite: (emotes) => widget.callbacks.reply(const ReplyToVideo(), emotes),
            ),
        ],
      ),
    );
  }
}

/// [model]'s list asks for its next page as the end of the scroll view [NearEndPaging.listen] wraps nears.
NearEndPaging commentsPaging(CommentsModel model) => NearEndPaging(
  canAsk: () => model.hasLoaded && !model.loading && !model.isEnd && model.error == null && model.closedMessage == null,
  ask: model.loadMore,
);

/// Nothing to show yet: the first page (of a sort) is out or not yet asked for.
bool commentsFirstLoad(CommentsModel model) =>
    model.comments.isEmpty &&
    model.pinned == null &&
    model.error == null &&
    model.closedMessage == null &&
    (model.loading || !model.hasLoaded);

/// 评论's list for whatever scroll view holds it (the video page's tab, a 动态's page): the section the uploader
/// closed, or 热门评论 / 最新评论 with its sort, the loading TV centred in what is left of the view on the first load,
/// the pinned comment, the rows and the footer. [headerKept] keeps the sort header through another sort's first load,
/// once a list has shown. [header] draws the section's header in place of [CommentSortHeader].
List<Widget> commentListSlivers({
  required CommentsModel model,
  required CommentCallbacks callbacks,
  required bool headerKept,
  Widget Function(CommentsModel model)? header,
}) {
  final closed = model.closedMessage;
  if (closed != null) return [SliverToBoxAdapter(child: _ClosedNotice(message: closed))];
  final pinned = model.pinned;
  final comments = model.comments;
  final firstLoad = commentsFirstLoad(model);
  return [
    if (!firstLoad || headerKept)
      SliverToBoxAdapter(
        child:
            header?.call(model) ??
            CommentSortHeader(
              title: model.sort == CommentSort.hot ? '热门评论' : '最新评论',
              sort: model.sort,
              onChange: (sort) => unawaited(model.setSort(sort)),
            ),
      ),
    if (firstLoad)
      const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: LoadingTvState(key: ValueKey('comments-first-load'))),
      )
    else ...[
      if (pinned != null)
        SliverToBoxAdapter(
          child: CommentRow(
            key: ValueKey('pinned-${pinned.rpid}'),
            comment: pinned,
            model: model,
            callbacks: callbacks,
          ),
        ),
      commentRows(
        comments,
        (comment) => CommentRow(key: ValueKey(comment.rpid), comment: comment, model: model, callbacks: callbacks),
      ),
      SliverToBoxAdapter(
        child: CommentListFooter(
          loading: model.loading || !model.hasLoaded,
          error: model.error,
          isEnd: model.isEnd,
          isEmpty: comments.isEmpty && pinned == null,
          onRetry: () => unawaited(model.loadMore()),
        ),
      ),
    ],
  ];
}

/// [comments] as rows keyed by rpid, so a row posted at the top moves the others down rather than rebuilding them in
/// place.
SliverList commentRows(List<Comment> comments, Widget Function(Comment comment) row) {
  final indexes = {for (final (index, comment) in comments.indexed) comment.rpid: index};
  return SliverList.builder(
    itemCount: comments.length,
    itemBuilder: (context, index) => row(comments[index]),
    findChildIndexCallback: (key) => key is ValueKey<int> ? indexes[key.value] : null,
  );
}

/// Asks for the next page once the end of a list is within a screen: one ask at a time, and only while [canAsk],
/// which a list makes false while loading, at its end and after a failure, so a failed page waits for 点击重试.
class NearEndPaging {
  NearEndPaging({required this.canAsk, required this.ask});

  final bool Function() canAsk;
  final Future<void> Function() ask;

  bool _asking = false;
  bool _disposed = false;

  /// Watches [scrollView]: scrolling, and its content growing or shrinking without a scroll, as when a page arrives
  /// that still leaves the end on screen.
  Widget listen(Widget scrollView) => NotificationListener<ScrollMetricsNotification>(
    onNotification: (notification) {
      if (notification.depth == 0) _check(notification.metrics);
      return false;
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _check(notification.metrics);
        return false;
      },
      child: scrollView,
    ),
  );

  void _check(ScrollMetrics metrics) {
    if (_asking || _disposed || !metrics.hasContentDimensions || !canAsk()) return;
    if (metrics.extentAfter > metrics.viewportDimension) return;
    _asking = true;
    // A scroll notification can come mid-layout, where the model's change must not rebuild anything yet.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && canAsk()) {
          _ask();
        } else {
          _asking = false;
        }
      });
    } else {
      _ask();
    }
  }

  void _ask() => unawaited(ask().whenComplete(() => _asking = false));

  void dispose() => _disposed = true;
}

/// 热门评论 … ≡ 按热度 over the list, 相关回复共N条 … ≡ 按时间 in a thread; a tap on the right switches the sort.
class CommentSortHeader extends StatelessWidget {
  const CommentSortHeader({
    super.key,
    required this.title,
    required this.sort,
    required this.onChange,
    this.height = CommentListTheme.sortHeight,
    this.centre = CommentListTheme.sortCentre,
  });

  final String title;
  final CommentSort sort;
  final ValueChanged<CommentSort> onChange;

  final double height;

  /// Where the title's and the button's line centres, down from the header's top.
  final double centre;

  TextStyle _style(BuildContext context, double size, double spacing) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: size,
    color: CommentListTheme.colorsOf(context).sortInk,
    height: CommentListTheme.sortLine / size,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: spacing,
  );

  @override
  Widget build(BuildContext context) {
    final label = sort == CommentSort.hot ? '按热度' : '按时间';
    void toggle() => onChange(sort == CommentSort.hot ? CommentSort.time : CommentSort.hot);
    const line = CommentListTheme.sortLine;
    final titleStyle = _style(context, CommentListTheme.sortTitleText, CommentListTheme.sortTitleSpacing);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: CommentListTheme.gutter,
            top: centre - line / 2,
            height: line,
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              style: titleStyle,
              strutStyle: BiliFonts.strutOf(context, titleStyle),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Semantics(
              key: const ValueKey('comment-sort'),
              button: true,
              label: label,
              hint: '切换排序',
              onTap: toggle,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: toggle,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: CommentListTheme.sortTouchLead,
                    right: CommentListTheme.gutter,
                    top: centre - line / 2,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    widthFactor: 1,
                    child: SizedBox(
                      height: line,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomPaint(
                            size: Size(CommentListTheme.sortIconWidth, line),
                            painter: _SortGlyphPainter(palette: BiliPalette.of(context)),
                          ),
                          const SizedBox(width: CommentListTheme.sortIconGap),
                          Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: _style(context, CommentListTheme.sortText, CommentListTheme.sortSpacing),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortGlyphPainter extends CustomPainter {
  final BiliPalette palette;
  const _SortGlyphPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommentListThemeColors(palette).sortInk
      ..strokeWidth = CommentListTheme.sortIconBar;
    final middle = size.height / 2;
    for (final offset in const [-CommentListTheme.sortIconPitch, 0.0, CommentListTheme.sortIconPitch]) {
      canvas.drawLine(Offset(0, middle + offset), Offset(size.width, middle + offset), paint);
    }
  }

  @override
  bool shouldRepaint(_SortGlyphPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// The end of a list: the spinner while a page loads, 没有更多了, 还没有评论，快来抢沙发吧, or 加载失败，点击重试. Idle with
/// more to come it keeps the spinner's room empty: the next page is asked for before the end shows, and a spinner
/// left turning in a tab kept alive off screen would keep a core busy.
class CommentListFooter extends StatelessWidget {
  const CommentListFooter({
    super.key,
    required this.loading,
    required this.error,
    required this.isEnd,
    required this.isEmpty,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final bool isEnd;
  final bool isEmpty;
  final VoidCallback onRetry;

  TextStyle _style(Color color) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: CommentListTheme.footerText,
    color: color,
    height: CommentListTheme.footerLine / CommentListTheme.footerText,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(
      vertical: isEmpty ? CommentListTheme.emptyPadding : CommentListTheme.footerPadding,
    );
    final reason = error;
    if (reason != null && !loading) {
      return Semantics(
        key: const ValueKey('comments-retry'),
        button: true,
        label: reason.isEmpty ? '加载失败，点击重试' : '$reason，加载失败，点击重试',
        onTap: onRetry,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRetry,
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reason.isNotEmpty) ...[
                  Text(
                    reason,
                    key: const ValueKey('comments-error'),
                    textAlign: TextAlign.center,
                    style: _style(CommentListTheme.colorsOf(context).retryInk),
                    strutStyle: BiliFonts.strutOf(context, _style(CommentListTheme.colorsOf(context).retryInk)),
                  ),
                  const SizedBox(height: CommentListTheme.retryGap),
                ],
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '加载失败，', style: _style(CommentListTheme.colorsOf(context).retryInk)),
                      TextSpan(text: '点击重试', style: _style(CommentListTheme.colorsOf(context).retryAction)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (isEnd && !loading) {
      return Padding(
        key: const ValueKey('comments-end'),
        padding: padding,
        child: Text(
          isEmpty ? '还没有评论，快来抢沙发吧' : '没有更多了',
          textAlign: TextAlign.center,
          style: _style(CommentListTheme.colorsOf(context).footerInk),
        ),
      );
    }
    return Padding(
      padding: padding,
      child: SizedBox(
        height: CommentListTheme.spinnerRadius * 2,
        child: loading
            ? const CupertinoActivityIndicator(
                key: ValueKey('comments-loading'),
                radius: CommentListTheme.spinnerRadius,
              )
            : null,
      ),
    );
  }
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: CommentListTheme.closedText,
      color: CommentListTheme.colorsOf(context).closedInk,
      letterSpacing: 0,
    );
    return Padding(
      key: const ValueKey('comments-closed'),
      padding: const EdgeInsets.only(
        top: CommentListTheme.closedTop,
        left: CommentListTheme.gutter,
        right: CommentListTheme.gutter,
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.chat_bubble_outline,
              size: CommentListTheme.closedIcon,
              color: CommentListTheme.colorsOf(context).closedInk,
            ),
          ),
          const SizedBox(height: CommentListTheme.closedGap),
          Text(message, textAlign: TextAlign.center, style: style, strutStyle: BiliFonts.strutOf(context, style)),
        ],
      ),
    );
  }
}

/// The bar under the list and the thread (10, 13): the grey pill with the section's prompt, or 哎呦，不错哦，发条评论吧
/// when the server sent none, and the emote face at its right, over the home indicator. [onWrite] gets true from the
/// face, which opens the composer on its emotes.
class CommentWriteBar extends StatelessWidget {
  const CommentWriteBar({super.key, required this.onWrite, this.prompt});

  final ValueChanged<bool> onWrite;

  /// The comment section's own words (font-check 04), which Bilibili sends with its pages.
  final String? prompt;

  static const placeholder = CommentsModel.defaultPrompt;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final shown = prompt ?? placeholder;
    final promptStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: CommentListTheme.fieldText,
      color: CommentListTheme.colorsOf(context).fieldInk,
      letterSpacing: CommentListTheme.fieldSpacing,
    );
    return DecoratedBox(
      key: const ValueKey('comment-bar'),
      decoration: BoxDecoration(
        color: CommentListTheme.colorsOf(context).background,
        border: Border(
          top: BorderSide(color: CommentListTheme.colorsOf(context).rule, width: CommentListTheme.barHairline),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: CommentListTheme.gutter,
          top: CommentListTheme.barTop,
          bottom: CommentListTheme.barBottom + bottom,
        ),
        child: SizedBox(
          height: CommentListTheme.fieldHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Semantics(
                  key: const ValueKey('comment-field'),
                  button: true,
                  label: shown,
                  onTap: () => onWrite(false),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onWrite(false),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(color: CommentListTheme.colorsOf(context).fieldFill, shape: StadiumBorder()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CommentListTheme.fieldPadding),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            shown,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: promptStyle,
                            strutStyle: BiliFonts.strutOf(context, promptStyle),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                key: const ValueKey('comment-emotes'),
                button: true,
                label: '表情',
                onTap: () => onWrite(true),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onWrite(true),
                  child: SizedBox(
                    width: CommentListTheme.faceBox,
                    child: Center(
                      child: CustomPaint(size: Size.square(CommentListTheme.face), painter: _EmoteFacePainter(palette: BiliPalette.of(context))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 10's face: a ring, > < eyes and an ω mouth, traced at 3 px per pt as fractions of the 20 pt face.
class _EmoteFacePainter extends CustomPainter {
  final BiliPalette palette;
  const _EmoteFacePainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = size.center(Offset.zero);
    Offset p(double x, double y) => centre + Offset(x * side, y * side);
    final paint = Paint()
      ..color = CommentListThemeColors(palette).faceInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = CommentListTheme.faceStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawCircle(centre, side * 0.462, paint);
    final face = Path();
    for (final sign in const [-1.0, 1.0]) {
      final start = p(sign * 0.2385, -0.1085);
      final tip = p(sign * 0.115, -0.02);
      final end = p(sign * 0.2385, 0.0635);
      face
        ..moveTo(start.dx, start.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(end.dx, end.dy);
    }
    final left = p(-0.1285, 0.1565);
    final leftBend = p(-0.0528, 0.272);
    final middle = p(0, 0.1735);
    final rightBend = p(0.0528, 0.272);
    final right = p(0.1285, 0.1565);
    face
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(leftBend.dx, leftBend.dy, middle.dx, middle.dy)
      ..quadraticBezierTo(rightBend.dx, rightBend.dy, right.dx, right.dy);
    canvas.drawPath(face, paint);
  }

  @override
  bool shouldRepaint(_EmoteFacePainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// The iPad's 发条评论 bar under the sideways column (05): the field with the face inside its end, and ↑, which takes
/// the column back to its top.
class PadCommentWriteBar extends StatelessWidget {
  const PadCommentWriteBar({super.key, required this.onWrite, required this.onTop, this.prompt});

  final ValueChanged<bool> onWrite;
  final VoidCallback onTop;
  final String? prompt;

  static const height = CommentListTheme.barHairline + PadPageTheme.commentGap * 2 + PadPageTheme.commentFieldHeight;

  @override
  Widget build(BuildContext context) {
    final shown = prompt ?? CommentWriteBar.placeholder;
    final promptStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: PadPageTheme.commentPromptText,
      color: PadPageTheme.colorsOf(context).commentInk,
      letterSpacing: 0,
    );
    return DecoratedBox(
      key: const ValueKey('comment-bar'),
      decoration: BoxDecoration(
        color: CommentListTheme.colorsOf(context).background,
        border: Border(
          top: BorderSide(color: PadPageTheme.colorsOf(context).commentRule, width: CommentListTheme.barHairline),
        ),
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned(
              left: PadPageTheme.commentFieldLeft,
              right: PadPageTheme.commentFieldRight,
              top: CommentListTheme.barHairline + PadPageTheme.commentGap,
              height: PadPageTheme.commentFieldHeight,
              child: DecoratedBox(
                key: const ValueKey('comment-field-box'),
                decoration: ShapeDecoration(color: PadPageTheme.colorsOf(context).commentFieldFill, shape: StadiumBorder()),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Semantics(
                        key: const ValueKey('comment-field'),
                        button: true,
                        label: shown,
                        onTap: () => onWrite(false),
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onWrite(false),
                          child: Padding(
                            padding: const EdgeInsets.only(left: PadPageTheme.commentPromptLeft),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                shown,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: promptStyle,
                                strutStyle: BiliFonts.strutOf(context, promptStyle),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      key: const ValueKey('comment-emotes'),
                      button: true,
                      label: '表情',
                      onTap: () => onWrite(true),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onWrite(true),
                        child: SizedBox(
                          width: PadPageTheme.commentFaceRight * 2,
                          child: Center(
                            child: CustomPaint(size: Size.square(CommentListTheme.face), painter: _EmoteFacePainter(palette: BiliPalette.of(context))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: PadPageTheme.commentTopRight - CommentListTheme.faceBox / 2,
              width: CommentListTheme.faceBox,
              top: CommentListTheme.barHairline + PadPageTheme.commentGap,
              height: PadPageTheme.commentFieldHeight,
              child: Semantics(
                key: const ValueKey('comment-top'),
                button: true,
                label: '回到顶部',
                onTap: onTop,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTop,
                  child: Center(
                    child: CustomPaint(
                      size: Size(PadPageTheme.commentTopWidth, PadPageTheme.commentTopHeight),
                      painter: _BackToTopPainter(palette: BiliPalette.of(context)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 05's ↑: a bar over an arrow whose shaft is a hollow box, traced at 2 px per pt in the 18 × 20 glyph.
class _BackToTopPainter extends CustomPainter {
  final BiliPalette palette;
  const _BackToTopPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / PadPageTheme.commentTopWidth;
    final y = size.height / PadPageTheme.commentTopHeight;
    final paint = Paint()
      ..color = PadPageThemeColors(palette).commentInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = PadPageTheme.commentTopStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawLine(Offset(0.6 * x, 0.6 * y), Offset(17.4 * x, 0.6 * y), paint)
      ..drawPath(
        Path()
          ..moveTo(4.75 * x, 19 * y)
          ..lineTo(4.75 * x, 13.25 * y)
          ..lineTo(1.2 * x, 13.25 * y)
          ..lineTo(9 * x, 3.8 * y)
          ..lineTo(16.8 * x, 13.25 * y)
          ..lineTo(13.25 * x, 13.25 * y)
          ..lineTo(13.25 * x, 19 * y)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(_BackToTopPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// 评论 before the video's aid is known: the loading TV under the reserve, centred in a box as tall as the list, as 64
/// has it before its write bar comes (lower than [CommentsTab]'s first load). It doesn't scroll: the box runs past the
/// screen's bottom, and a drag would carry the collapsing player with it.
class CommentsSlot extends StatelessWidget {
  const CommentsSlot({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CommentListTheme.colorsOf(context).background,
    child: CustomScrollView(
      primary: true,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Builder(builder: (context) => SizedBox(height: PlayerReserve.of(context))),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) => SliverToBoxAdapter(
            child: SizedBox(
              height: constraints.viewportMainAxisExtent,
              child: const Center(child: LoadingTvState(key: ValueKey('comments-slot-loading'))),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 评论 as a section of a scroll view that holds more (the iPad's sideways column, 03): [PadCommentsHeader] over the
/// list, its first page asked for at once, the next ones as the end of the enclosing scroll view nears.
class PadCommentsSection extends StatefulWidget {
  const PadCommentsSection({super.key, required this.model, required this.callbacks, required this.onSeeAll});

  final CommentsModel model;
  final CommentCallbacks callbacks;

  /// Called by 查看N条评论 ›.
  final VoidCallback onSeeAll;

  @override
  State<PadCommentsSection> createState() => _PadCommentsSectionState();
}

class _PadCommentsSectionState extends State<PadCommentsSection> {
  late NearEndPaging _paging = commentsPaging(widget.model);
  bool _listShown = false;
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    _listShown = !commentsFirstLoad(widget.model);
    widget.model.addListener(_changed);
    unawaited(widget.model.ensureLoaded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _position)) return;
    _position?.removeListener(_scrolled);
    _position = position?..addListener(_scrolled);
  }

  @override
  void didUpdateWidget(PadCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.model, widget.model)) return;
    oldWidget.model.removeListener(_changed);
    _paging.dispose();
    _paging = commentsPaging(widget.model);
    _listShown = !commentsFirstLoad(widget.model);
    widget.model.addListener(_changed);
    unawaited(widget.model.ensureLoaded());
  }

  @override
  void dispose() {
    _position?.removeListener(_scrolled);
    widget.model.removeListener(_changed);
    _paging.dispose();
    super.dispose();
  }

  void _scrolled() {
    if (_position case final position? when position.hasPixels) _paging._check(position);
  }

  void _changed() {
    if (!mounted) return;
    setState(() => _listShown |= !commentsFirstLoad(widget.model));
    // A page that lands still short of the screen asks for the next once laid out.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrolled();
    });
  }

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: commentListSlivers(
      model: widget.model,
      callbacks: widget.callbacks,
      headerKept: _listShown,
      header: (model) => PadCommentsHeader(
        title: model.sort == CommentSort.hot ? '热门评论' : '最新评论',
        sort: model.sort,
        prompt: model.rootPrompt,
        total: model.total,
        onChange: (sort) => unawaited(model.setSort(sort)),
        onWrite: (emotes) => widget.callbacks.reply(const ReplyToVideo(), emotes),
        onSeeAll: widget.onSeeAll,
      ),
    ),
  );
}

/// The iPad's 热门评论 header (03): the title, the comment field with its face, and at the right ⇅ 按热度 | 查看N条评论 ›.
class PadCommentsHeader extends StatelessWidget {
  const PadCommentsHeader({
    super.key,
    required this.title,
    required this.sort,
    required this.prompt,
    required this.total,
    required this.onChange,
    required this.onWrite,
    required this.onSeeAll,
  });

  final String title;
  final CommentSort sort;
  final String? prompt;
  final int total;
  final ValueChanged<CommentSort> onChange;
  final ValueChanged<bool> onWrite;
  final VoidCallback onSeeAll;

  TextStyle _style(double size, Color color) => TextStyle(
    fontFamily: BiliFonts.family,
    fontSize: size,
    color: color,
    height: 1.2,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final label = sort == CommentSort.hot ? '按热度' : '按时间';
    void toggle() => onChange(sort == CommentSort.hot ? CommentSort.time : CommentSort.hot);
    final shown = prompt ?? CommentWriteBar.placeholder;
    final fieldStyle = _style(PadPageTheme.headerFieldText, PadPageTheme.colorsOf(context).headerFieldInk);
    final textStyle = _style(PadPageTheme.headerText, PadPageTheme.colorsOf(context).headerInk);
    final titleStyle = _style(
      PadPageTheme.headerTitleText,
      PadPageTheme.colorsOf(context).headerTitle,
    ).copyWith(fontWeight: PadPageTheme.headerTitleWeight);
    return DecoratedBox(
      key: const ValueKey('pad-comments-header'),
      decoration: BoxDecoration(
        color: CommentListTheme.colorsOf(context).background,
        border: Border(
          top: BorderSide(color: PadPageTheme.colorsOf(context).ruleColour, width: PadPageTheme.rule),
        ),
      ),
      child: SizedBox(
        height: PadPageTheme.headerHeight,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: PadPageTheme.headerCentre - PadPageTheme.headerFieldHeight / 2,
              height: PadPageTheme.headerFieldHeight,
              child: Row(
                children: [
                  const SizedBox(width: PadPageTheme.gutter),
                  SizedBox(
                    width: PadPageTheme.headerFieldLeft - PadPageTheme.gutter,
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: titleStyle,
                      strutStyle: BiliFonts.strutOf(context, titleStyle),
                    ),
                  ),
                  Semantics(
                    key: const ValueKey('comment-field'),
                    button: true,
                    label: shown,
                    onTap: () => onWrite(false),
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onWrite(false),
                      child: Container(
                        width: PadPageTheme.headerFieldWidth,
                        height: PadPageTheme.headerFieldHeight,
                        decoration: ShapeDecoration(color: PadPageTheme.colorsOf(context).headerFieldFill, shape: StadiumBorder()),
                        padding: const EdgeInsets.only(left: PadPageTheme.headerFieldPadding),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                shown,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: fieldStyle,
                                strutStyle: BiliFonts.strutOf(context, fieldStyle),
                              ),
                            ),
                            Semantics(
                              key: const ValueKey('comment-emotes'),
                              button: true,
                              label: '表情',
                              onTap: () => onWrite(true),
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onWrite(true),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: PadPageTheme.headerFaceRight,
                                    right: PadPageTheme.headerFaceRight,
                                  ),
                                  child: CustomPaint(
                                    size: Size.square(PadPageTheme.headerFace),
                                    painter: _EmoteFacePainter(palette: BiliPalette.of(context)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    key: const ValueKey('comment-sort'),
                    button: true,
                    label: label,
                    hint: '切换排序',
                    onTap: toggle,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: toggle,
                      child: Row(
                        children: [
                          CustomPaint(
                            size: Size.square(PadPageTheme.headerSortGlyph),
                            painter: _UpDownPainter(palette: BiliPalette.of(context)),
                          ),
                          const SizedBox(width: PadPageTheme.headerSortGap),
                          Text(label, maxLines: 1, softWrap: false, style: textStyle),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: PadPageTheme.headerRuleGap),
                  SizedBox(
                    width: PadPageTheme.rule,
                    height: PadPageTheme.headerRuleHeight,
                    child: ColoredBox(color: PadPageTheme.colorsOf(context).ruleColour),
                  ),
                  const SizedBox(width: PadPageTheme.headerRuleGap),
                  Semantics(
                    key: const ValueKey('comments-see-all'),
                    button: true,
                    label: '查看 $total 条评论',
                    onTap: onSeeAll,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onSeeAll,
                      child: Row(
                        children: [
                          Text('查看 $total 条评论', maxLines: 1, softWrap: false, style: textStyle),
                          const SizedBox(width: PadPageTheme.headerChevronGap),
                          CustomPaint(
                            size: Size(PadPageTheme.headerChevronWidth, PadPageTheme.headerChevronHeight),
                            painter: _ChevronPainter(palette: BiliPalette.of(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: PadPageTheme.headerRight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 查看N条评论's thin ›.
class _ChevronPainter extends CustomPainter {
  final BiliPalette palette;
  const _ChevronPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PadPageThemeColors(palette).headerInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = PadPageTheme.headerChevronStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

/// ⇅: an arrow up on the left, an arrow down on the right, as 03 draws the sort.
class _UpDownPainter extends CustomPainter {
  final BiliPalette palette;
  const _UpDownPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PadPageThemeColors(palette).headerInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = CommentListTheme.sortIconBar
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final up = Path()
      ..moveTo(w * 0.3, h)
      ..lineTo(w * 0.3, 0)
      ..lineTo(0, h * 0.3);
    final down = Path()
      ..moveTo(w * 0.7, 0)
      ..lineTo(w * 0.7, h)
      ..lineTo(w, h * 0.7);
    canvas
      ..drawPath(up, paint)
      ..drawPath(down, paint);
  }

  @override
  bool shouldRepaint(_UpDownPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
