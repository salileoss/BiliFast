import 'dart:async';

import 'package:flutter/widgets.dart';

import '../shared/theme.dart';
import 'comment_callbacks.dart';
import 'comment_row.dart';
import 'comments_model.dart';
import 'comments_tab.dart';

/// 评论详情 (13): the 评论详情 header with ✕, the root comment in full, a grey band, 相关回复共N条 with its sort, the
/// replies paging as they near the end, and the 发条评论 bar.
class ThreadView extends StatefulWidget {
  const ThreadView({super.key, required this.model, required this.thread, required this.callbacks});

  final CommentsModel model;

  /// The thread as the overlay last saw it; while [model]'s open thread has the same root, that one shows instead,
  /// and once the thread closes this one stays on screen as it lowers.
  final ThreadState thread;
  final CommentCallbacks callbacks;

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  late NearEndPaging _paging = _pagingFor(widget.model);

  @override
  void didUpdateWidget(ThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.model, widget.model)) return;
    _paging.dispose();
    _paging = _pagingFor(widget.model);
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  NearEndPaging _pagingFor(CommentsModel model) => NearEndPaging(
    canAsk: () {
      final thread = model.thread;
      return thread != null &&
          thread.root.rpid == widget.thread.root.rpid &&
          thread.page > 0 &&
          !thread.loading &&
          !thread.isEnd &&
          thread.error == null;
    },
    ask: model.loadMoreThread,
  );

  ThreadState get _shown => switch (widget.model.thread) {
    final live? when live.root.rpid == widget.thread.root.rpid => live,
    _ => widget.thread,
  };

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final callbacks = widget.callbacks;
    return ColoredBox(
      color: CommentListTheme.colorsOf(context).background,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) {
          final thread = _shown;
          final root = thread.root;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onClose: model.closeThread),
              Expanded(
                child: _paging.listen(
                  CustomScrollView(
                    key: ValueKey(root.rpid),
                    primary: false,
                    slivers: [
                      SliverToBoxAdapter(
                        child: CommentRow(
                          key: const ValueKey('thread-root'),
                          comment: root,
                          model: model,
                          callbacks: callbacks,
                          showsReplies: false,
                          showsDivider: false,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          key: ValueKey('thread-band'),
                          height: CommentListTheme.bandHeight,
                          child: ColoredBox(color: CommentListTheme.colorsOf(context).band),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: CommentSortHeader(
                          title: '相关回复共${thread.total}条',
                          sort: thread.sort,
                          onChange: (sort) => unawaited(model.setThreadSort(sort)),
                          height: CommentListTheme.threadSortHeight,
                          centre: CommentListTheme.threadSortCentre,
                        ),
                      ),
                      commentRows(
                        thread.replies,
                        (reply) => CommentRow(
                          key: ValueKey(reply.rpid),
                          comment: reply,
                          model: model,
                          callbacks: callbacks,
                          thread: root,
                          showsReplies: false,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: CommentListFooter(
                          loading: thread.loading,
                          error: thread.error,
                          isEnd: thread.isEnd,
                          isEmpty: thread.replies.isEmpty,
                          onRetry: () => unawaited(model.loadMoreThread()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              CommentWriteBar(
                prompt: thread.prompt ?? model.childPrompt,
                onWrite: (emotes) => callbacks.reply(ReplyToComment(root), emotes),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 评论详情 and ✕ over the thread, where the tab row was.
class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('thread-header'),
    height: CommentListTheme.threadHeaderHeight,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: CommentListTheme.colorsOf(context).background,
        border: Border(
          bottom: BorderSide(color: CommentListTheme.colorsOf(context).rule, width: CommentListTheme.threadHairline),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: CommentListTheme.gutter),
          Expanded(
            child: Text(
              '评论详情',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: BiliFonts.family,
                fontSize: CommentListTheme.threadTitleText,
                color: CommentListTheme.colorsOf(context).threadTitleInk,
                letterSpacing: CommentListTheme.threadTitleSpacing,
              ),
            ),
          ),
          Semantics(
            key: const ValueKey('thread-close'),
            button: true,
            label: '关闭',
            onTap: onClose,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: SizedBox(
                width: CommentListTheme.closeBox,
                height: CommentListTheme.threadHeaderHeight,
                child: Center(
                  child: CustomPaint(size: Size.square(CommentListTheme.close), painter: _CloseGlyphPainter(palette: BiliPalette.of(context))),
                ),
              ),
            ),
          ),
          const SizedBox(width: CommentListTheme.closeTrailing),
        ],
      ),
    ),
  );
}

class _CloseGlyphPainter extends CustomPainter {
  final BiliPalette palette;
  const _CloseGlyphPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommentListThemeColors(palette).closeInk
      ..strokeWidth = CommentListTheme.closeStroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    // The ink spans the square, round ends included.
    final inset = CommentListTheme.closeStroke / 2;
    canvas
      ..drawLine(Offset(inset, inset), Offset(size.width - inset, size.height - inset), paint)
      ..drawLine(Offset(size.width - inset, inset), Offset(inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
