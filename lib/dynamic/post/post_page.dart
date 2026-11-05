import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_environment.dart';
import '../../app/app_scope.dart';
import '../../comments/comment_callbacks.dart';
import '../../comments/comment_overlays.dart';
import '../../comments/comments_model.dart';
import '../../comments/comments_tab.dart';
import '../../home/feed_inline_player.dart';
import '../../home/feed_model.dart' show requestFailureMessage;
import '../../playback/playback_controller.dart' show resolveVideoLink;
import '../../player_ui/end_screen_portrait.dart' show ShareLink, shareThroughSystem;
import '../../shared/loading_tv.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../video/video_page.dart' show VideoPageOpener;
import '../../video/video_route.dart';
import '../card/dynamic_pictures.dart';
import '../card/dynamic_repost.dart';
import '../card/dynamic_rich_text.dart';
import '../card/dynamic_video_box.dart';
import '../dynamic_like_book.dart';
import 'post_author.dart';
import 'post_bar.dart';
import 'post_bottom_bar.dart';
import 'post_failure.dart';
import 'post_tabs.dart';

/// A post on its own page (131-134, 140): ‹ and 正在努力加载... until its detail is in (133), then the author, the
/// whole text, its pictures, video or repost (a video, its own or the repost's, plays muted, 132), 评论 N / 赞和转发 N
/// pinned under the bar once scrolled to (134) over the post's comments, and 点我发评论, 💬, ⭐ and 👍 at the bottom. ↗
/// and ⋮ share it. Replies, 评论详情, the composer, pictures and delete are the video page's, in this page's Stack.
class DynamicPostPage extends StatefulWidget {
  const DynamicPostPage({
    super.key,
    required this.id,
    this.item,
    this.toComments = false,
    this.share = shareThroughSystem,
    this.openPage = openVideoPage,
  });

  final String id;

  /// The post as the list showed it, whose comment area is taken when it has one.
  final DynamicItem? item;

  /// Once the post shows, the tabs go up under the bar.
  final bool toComments;
  final ShareLink share;

  /// Where a video link in a comment goes.
  final VideoPageOpener openPage;

  @override
  State<DynamicPostPage> createState() => _DynamicPostPageState();
}

class _DynamicPostPageState extends State<DynamicPostPage> {
  static const _soon = '暂未开放';

  final _scroll = ScrollController();

  /// The status bar's tap finds this while 评论详情 covers the list.
  final _noScroll = ScrollController();
  final _area = GlobalKey();
  final _authorKey = GlobalKey();

  /// The post above the tabs, measured as it lays out, for the filler under the comments and the scroll to them.
  final _postHeight = _Height();

  AppServices? _services;
  ValueListenable<int>? _logins;
  late final Stopwatch _opened = Stopwatch()..start();

  DynamicItem? _post;
  ({String message, bool retry})? _failure;
  int _loads = 0;

  CommentsModel? _comments;
  NearEndPaging? _paging;
  final _drafts = CommentDrafts();
  final _overlays = CommentOverlayController();
  bool _threadOpen = false;

  /// The sort header stays once a list has shown, so another sort's first load keeps its toggle.
  bool _listShown = false;

  /// The poster's face and name are in the bar.
  bool _titled = false;
  bool _askingLogin = false;
  FeedInlineHost? _inline;

  late final _callbacks = CommentCallbacks(
    reply: (target, emotes) {
      if (_comments?.requireLogin() ?? false) _overlays.compose(target, emotes: emotes);
    },
    openThread: (root) => unawaited(_comments?.openThread(root)),
    viewPictures: _overlays.viewPictures,
    confirmDelete: _overlays.confirmDelete,
    // A post has no player to take a time to.
    seek: (_) {},
    openVideo: (id) => unawaited(_openVideoId(id)),
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrolled);
    _overlays.addListener(_overlaysChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services != null) return;
    final services = _services = AppScope.of(context);
    _logins = services.environment.logins..addListener(_loggedIn);
    services.dynamicLikes.addListener(_likesChanged);
    _inline = FeedInlineHost(viewport: _viewport, pip: services.pipKeeper);
    unawaited(_load());
  }

  @override
  void dispose() {
    _logins?.removeListener(_loggedIn);
    _services?.dynamicLikes.removeListener(_likesChanged);
    _inline?.dispose();
    _scroll.dispose();
    _noScroll.dispose();
    _overlays
      ..removeListener(_overlaysChanged)
      ..dispose();
    _paging?.dispose();
    _comments
      ?..removeListener(_commentsChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = _services!;
    final load = ++_loads;
    if (_failure != null) setState(() => _failure = null);
    final DynamicItem post;
    try {
      post = await services.dynamicApi.detail(widget.id);
    } catch (error) {
      Logger.shared.warn(LogCategory.api, 'dynamic post failed', {'error': _reason(error)});
      if (mounted && load == _loads) setState(() => _failure = _failureOf(error));
      return;
    }
    if (!mounted || load != _loads) return;
    final area = widget.item?.comments ?? post.comments;
    Logger.shared.info(LogCategory.ui, 'dynamic post', {
      'kind': post.kind.name,
      'type': post.typeName,
      'commentType': area?.type ?? 0,
      'ms': _opened.elapsedMilliseconds,
    });
    setState(() {
      _post = post;
      if (area != null) _comments = _commentsFor(area, post.author.mid);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _shown());
  }

  /// The first frame with the post: the comments' first page, the jump to them when asked, an inline video.
  void _shown() {
    if (!mounted) return;
    unawaited(_comments?.ensureLoaded());
    if (widget.toComments && _scroll.hasClients) _scroll.jumpTo(_commentsOffset);
    _inline?.settleSoon();
  }

  CommentsModel _commentsFor(CommentArea area, int upMid) {
    final services = _services!;
    final environment = services.environment;
    final comments = CommentsModel(
      aid: area.oid,
      type: area.type,
      upMid: upMid,
      api: services.pageApi,
      drafts: _drafts,
      isLoggedIn: () => environment.account is LoggedIn,
      accountMid: () => environment.mid,
      requestLogin: _askLogin,
      toast: _toast,
    )..addListener(_commentsChanged);
    _paging = commentsPaging(comments);
    return comments;
  }

  static ({String message, bool retry}) _failureOf(Object error) => switch (error) {
    // Deleted, or never there: asking again won't bring it.
    BiliAPIError(code: -404 || 4101131) => (message: '动态不存在或已被删除', retry: false),
    _ => (message: requestFailureMessage(error), retry: true),
  };

  /// What a failed call logs: the status or code, never the message.
  static String _reason(Object error) => switch (error) {
    BiliHTTPError(:final status) => 'http $status',
    BiliAPIError(:final code) => 'api $code',
    _ => '${error.runtimeType}',
  };

  void _commentsChanged() {
    if (!mounted) return;
    setState(() {
      _threadOpen = _comments?.thread != null;
      if (_comments case final comments?) _listShown |= !commentsFirstLoad(comments);
    });
  }

  /// Rebuilds the PopScope, which lets a pop through only with nothing over the page.
  void _overlaysChanged() {
    if (mounted) setState(() {});
  }

  void _likesChanged() {
    if (mounted) setState(() {});
  }

  /// The account changed under the page: the rows ask again whose comments offer 删除.
  void _loggedIn() => _comments?.refreshAccount();

  /// Where the tabs sit right under the bar.
  double get _commentsOffset {
    final position = _scroll.position;
    return math.min(_postHeight.value, position.maxScrollExtent);
  }

  void _scrolled() {
    final box = _authorKey.currentContext?.findRenderObject();
    final authorBottom = box is RenderBox && box.hasSize ? box.size.height : DynamicPostTheme.authorTop;
    final titled = _scroll.offset >= authorBottom;
    if (titled != _titled) setState(() => _titled = titled);
  }

  Rect? _viewport() {
    final box = _area.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _toast(String message) {
    if (mounted) showToast(context, message);
  }

  void _soonToast() => _toast(_soon);

  void _back() => unawaited(Navigator.of(context).maybePop());

  /// Closes the composer, the picture viewer or the delete confirm, else 评论详情. False when none is up. A composer
  /// that is posting stays, so a failed post still shows with its text.
  bool _closeComments() {
    if (_overlays.value case final overlay?) {
      if (overlay is! ComposeOverlay || !_drafts.anyPosting) _overlays.close();
      return true;
    }
    if (_comments case final comments? when comments.thread != null) {
      comments.closeThread();
      return true;
    }
    return false;
  }

  void _askLogin() => unawaited(_requestLogin());

  /// Every logged-out action comes here: the login page, unless the account is still being checked and turns out
  /// logged in. Nothing pressed is sent afterwards.
  Future<void> _requestLogin() async {
    final services = _services;
    if (_askingLogin || services == null || !mounted) return;
    _askingLogin = true;
    try {
      // A model can ask while a widget builds.
      await Future<void>.value();
      if (!mounted) return;
      final environment = services.environment;
      if (environment.account is AccountUnknown) {
        await environment.refreshAccount();
        if (!mounted) return;
        switch (environment.account) {
          case LoggedIn():
            return;
          case AccountUnknown():
            _toast('账号确认失败，请稍后重试');
            return;
          case LoggedOut() || LoginExpired():
            break;
        }
      }
      if (_overlays.value is ComposeOverlay && !_drafts.anyPosting) _overlays.close();
      final loggedIn = await services.loginGate.request(context);
      if (loggedIn && mounted) _comments?.refreshAccount();
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'login failed', {'error': '${error.runtimeType}'});
      _toast('无法打开登录');
    } finally {
      _askingLogin = false;
    }
  }

  Future<void> _openVideoId(String id) async {
    switch (LinkParser.parse(id)) {
      case BvidLink(id: final bvid):
        await widget.openPage(context, VideoRoute(bvid: bvid));
      case final AidLink link:
        final VideoView view;
        try {
          view = (await resolveVideoLink(_services!.environment.client, link)).$1;
        } catch (error) {
          Logger.shared.warn(LogCategory.ui, 'open video id failed', {'error': _reason(error)});
          _toast(requestFailureMessage(error, fallback: '打开视频失败，请稍后重试'));
          return;
        }
        if (!mounted || !(ModalRoute.isCurrentOf(context) ?? false)) return;
        await widget.openPage(context, VideoRoute(bvid: view.bvid, title: view.title, view: view));
      default:
        break;
    }
  }

  Future<void> _share() async {
    final post = _post;
    if (post == null) return;
    try {
      await widget.share(post.shareLink);
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'share failed', {'error': '${error.runtimeType}'});
      _toast('分享失败');
    }
  }

  void _write() {
    final comments = _comments;
    if (comments == null) {
      // A guess: no screenshot shows a post without a comment area.
      _toast('评论区暂不可用');
    } else if (comments.closedMessage case final closed?) {
      _toast(closed);
    } else {
      _callbacks.reply(const ReplyToVideo(), false);
    }
  }

  void _viewPictures(List<DynamicPicture> pictures, int index) => _overlays.viewPictures([
    for (final picture in pictures)
      CommentPicture(url: picture.url, width: picture.width.toDouble(), height: picture.height.toDouble()),
  ], index);

  void _toComments() {
    if (!_scroll.hasClients) return;
    final target = _commentsOffset;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      unawaited(_scroll.animateTo(target, duration: DynamicPostTheme.toComments, curve: Curves.easeOut));
    }
  }

  Future<void> _like() async {
    final post = _post;
    final services = _services;
    if (post == null || services == null) return;
    if (services.environment.account case LoggedOut() || LoginExpired()) {
      _askLogin();
      return;
    }
    switch (await services.dynamicLikes.toggle(post.id, post.stat)) {
      case LikeNeedsLogin():
        _askLogin();
      case LikeFailed(:final message):
        _toast(message);
      case LikeDone():
    }
  }

  /// 评论 N follows the list once its first page is in, so a post or a delete moves it. A first page counting 0 for a
  /// post that has comments keeps the post's own count (131's says 809).
  int _commentCount(DynamicStat stat) {
    final comments = _comments;
    final loaded = comments != null && (comments.comments.isNotEmpty || comments.pinned != null || comments.isEnd);
    if (!loaded || (comments.total == 0 && stat.comment > 0)) return stat.comment;
    return comments.total;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final post = _post;
    _inline?.shown =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        _overlays.value == null &&
        !_threadOpen;
    final stat = post == null ? null : _services!.dynamicLikes.stat(post.id, post.stat);
    return PopScope<Object?>(
      canPop: _overlays.value == null && !_threadOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeComments();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        // A tap on the status bar scrolls the post to its top; nothing else on the page takes the controller.
        child: PrimaryScrollController(
          controller: _threadOpen ? _noScroll : _scroll,
          child: Scaffold(
            backgroundColor: DynamicPostTheme.colorsOf(context).page,
            resizeToAvoidBottomInset: false,
            body: PrimaryScrollController.none(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PostBar(
                          onBack: _back,
                          author: post?.author,
                          titled: _titled,
                          onShare: post == null ? null : () => unawaited(_share()),
                          onMore: post == null ? null : () => unawaited(_share()),
                        ),
                        Expanded(
                          child: post == null
                              ? const SizedBox.shrink()
                              : ExcludeSemantics(
                                  excluding: _threadOpen,
                                  child: MediaQuery.removePadding(
                                    context: context,
                                    removeTop: true,
                                    removeBottom: true,
                                    child: _content(context, post),
                                  ),
                                ),
                        ),
                        if (post != null && stat != null)
                          PostBottomBar(
                            comments: _commentCount(stat),
                            favourites: stat.favourite,
                            likes: stat.like,
                            liked: stat.liked,
                            onWrite: _write,
                            onComments: _toComments,
                            onFavourite: _soonToast,
                            onLike: () => unawaited(_like()),
                          ),
                      ],
                    ),
                  ),
                  // Under the bar, over the tabs pinned there (134).
                  Positioned(
                    top: top + DynamicPostTheme.barRow,
                    left: 0,
                    right: 0,
                    height: DynamicPostTheme.barHairline,
                    child: PostBarRule(shown: _titled),
                  ),
                  // Centred on the screen, as 133's TV is; away from the bar, it leaves ‹ its taps.
                  if (post == null) Positioned.fill(child: Center(child: _waiting())),
                  Positioned.fill(
                    key: const ValueKey('post-comment-overlays'),
                    child: CommentOverlays(
                      model: _comments,
                      controller: _overlays,
                      callbacks: _callbacks,
                      threadTop: top + DynamicPostTheme.barRow,
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

  Widget _waiting() => switch (_failure) {
    null => const LoadingTvState(key: ValueKey('post-loading')),
    (:final message, :final retry) => PostFailure(message: message, onRetry: retry ? () => unawaited(_load()) : null),
  };

  Widget _content(BuildContext context, DynamicItem post) {
    final comments = _comments;
    final stat = _services!.dynamicLikes.stat(post.id, post.stat);
    final scrollView = CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: _HeightProbe(height: _postHeight, child: _postBlock(context, post)),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: PostTabsDelegate(
            PostTabs(comments: _commentCount(stat), reactions: stat.like + stat.forward, onReactions: _soonToast),
          ),
        ),
        if (comments != null) ...commentListSlivers(model: comments, callbacks: _callbacks, headerKept: _listShown),
        _TailFiller(postHeight: _postHeight),
      ],
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _inline?.onScroll(notification);
        return false;
      },
      child: KeyedSubtree(key: _area, child: _paging?.listen(scrollView) ?? scrollView),
    );
  }

  /// The author, the text, the body and, for a picture or text post, IP属地 under it (140); elsewhere it is under the
  /// time (132).
  Widget _postBlock(BuildContext context, DynamicItem post) {
    final below = switch (post.kind) {
      DynamicKind.draw || DynamicKind.word || DynamicKind.article => true,
      _ => false,
    };
    final location = post.author.location;
    final body = _body(post);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PostAuthor(key: _authorKey, author: post.author, showLocation: !below),
        if (post.nodes.isNotEmpty)
          Padding(
            key: const ValueKey('post-text'),
            padding: const EdgeInsets.only(
              left: DynamicPostTheme.gutter,
              right: DynamicPostTheme.gutter,
              top: DynamicPostTheme.textGap,
            ),
            child: DynamicRichText(
              nodes: post.nodes,
              style: postStyle(DynamicPostTheme.text, DynamicPostTheme.colorsOf(context).textInk, line: DynamicPostTheme.textLine),
            ),
          ),
        if (body != null)
          Padding(
            key: const ValueKey('post-body'),
            padding: const EdgeInsets.only(top: DynamicPostTheme.bodyGap),
            child: body,
          ),
        if (below && location.isNotEmpty) PostLocation(location: location),
        const SizedBox(height: DynamicPostTheme.endGap),
      ],
    );
  }

  Widget? _body(DynamicItem post) {
    if (post.original case final original?) {
      if (DynamicRepostBlock.blank(original)) return null;
      final pictures = switch (original.major) {
        DynamicPictures(:final pictures) => pictures,
        _ => const <DynamicPicture>[],
      };
      return DynamicRepostBlock(
        original: original,
        inline: _inline,
        detail: true,
        onOpen: (index) => _viewPictures(pictures, index),
      );
    }
    return switch (post.major) {
      DynamicPictures(:final pictures) when pictures.isNotEmpty => Padding(
        padding: const EdgeInsets.symmetric(horizontal: DynamicPostTheme.gutter),
        child: DynamicPictureGrid(pictures: pictures, detail: true, onOpen: (index) => _viewPictures(pictures, index)),
      ),
      final DynamicVideo video => Padding(
        padding: const EdgeInsets.symmetric(horizontal: DynamicPostTheme.gutter),
        child: DynamicVideoBox(video: video, inline: _inline),
      ),
      _ => null,
    };
  }
}

/// A height a child had at its last layout, read where the build mustn't depend on it.
class _Height {
  double value = 0;
}

/// Reports its child's height into [height] each layout, before the slivers after it lay out.
class _HeightProbe extends SingleChildRenderObjectWidget {
  const _HeightProbe({required this.height, required super.child});

  final _Height height;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeightProbe(height);

  @override
  void updateRenderObject(BuildContext context, _RenderHeightProbe renderObject) => renderObject.height = height;
}

class _RenderHeightProbe extends RenderProxyBox {
  _RenderHeightProbe(this.height);

  _Height height;

  @override
  void performLayout() {
    super.performLayout();
    height.value = size.height;
  }
}

/// However few the comments, the post can still scroll away and the tabs pin under the bar.
class _TailFiller extends StatelessWidget {
  const _TailFiller({required this.postHeight});

  final _Height postHeight;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) => SliverToBoxAdapter(
      child: SizedBox(
        height: math.max(0, constraints.viewportMainAxisExtent + postHeight.value - constraints.precedingScrollExtent),
      ),
    ),
  );
}
