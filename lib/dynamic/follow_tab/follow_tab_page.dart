import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_environment.dart';
import '../../app/app_scope.dart';
import '../../home/feed_inline_player.dart';
import '../../home/tab_bar_icons.dart' show SkinDecodeGate;
import '../../shared/loading_tv.dart';
import '../../shared/release_refresh.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../skin/skin.dart';
import '../../space/space_route.dart';
import '../../space/uploader_tap.dart';
import '../following/following_route.dart';
import 'face_sheet.dart';
import 'follow_feed_model.dart';
import 'follow_header.dart';
import 'follow_parts.dart';
import 'follow_top.dart';

/// The bottom bar's 关注 (127, 128): the header, 全部 / 视频, 最常访问 and, on 视频, 我的追番 · 追剧 over the posts,
/// paged, pulled to refresh. It loads the first time it is shown. A face opens the face sheet ([faceSheet], drawn by
/// `MainShell` over the bar too); video cards play muted where they settle while 关注 is shown with nothing over it.
class FollowTabPage extends StatefulWidget {
  const FollowTabPage({super.key, required this.active, required this.faceSheet, this.reloads, this.skin});

  /// 关注 is the tab shown.
  final bool active;
  final FaceSheetController faceSheet;

  /// Notifies for each tap on the bar's 关注 while 关注 shows: the list goes back to the top and refreshes.
  final Listenable? reloads;

  /// The equipped 装扮: with a `head_bg` it dresses the header.
  final Skin? skin;

  @override
  State<FollowTabPage> createState() => _FollowTabPageState();
}

class _FollowTabPageState extends State<FollowTabPage> with SkinRefreshRoom {
  static const _soon = '暂未开放';

  late AppServices _services;
  late AppEnvironment _environment;
  FollowTabModel? _model;
  bool _started = false;
  bool _signedOut = false;

  /// Counts the first loads, so 登录 can tell the login already started one.
  int _starts = 0;

  final _scroll = ScrollController();
  final _faces = ScrollController();
  final _facesKey = GlobalKey();
  final _listKey = GlobalKey();
  late final _paging = FollowPaging(
    canAsk: () => _model?.current.canLoadMore ?? false,
    ask: () => _model!.current.loadMore(),
  );
  FeedInlineHost? _inline;

  /// The refresh running, from a pull or a tap on 关注; another waits on it.
  Future<String?>? _refreshing;

  /// 关注's tap holds the TV open at the top until its refresh is done; [_reloadRoom] keeps it built while closing.
  bool _reloadHeader = false;
  bool _reloadRoom = false;

  /// Reduce Motion and the inset under the list (the home indicator, or a dressed bar), as the last build saw them.
  bool _still = false;
  double _inset = 0;

  @override
  void initState() {
    super.initState();
    widget.reloads?.addListener(_reload);
    widget.faceSheet.addListener(_sheetChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model != null) return;
    _services = AppScope.of(context);
    _environment = _services.environment..addListener(_accountChanged);
    _signedOut = _loggedOut;
    _model = FollowTabModel(api: _services.dynamicApi, mid: () => _environment.mid)..addListener(_modelChanged);
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(FollowTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.reloads, widget.reloads)) {
      oldWidget.reloads?.removeListener(_reload);
      widget.reloads?.addListener(_reload);
    }
    if (!identical(oldWidget.faceSheet, widget.faceSheet)) {
      oldWidget.faceSheet.removeListener(_sheetChanged);
      widget.faceSheet.addListener(_sheetChanged);
    }
    if (widget.active && !oldWidget.active) _start();
  }

  @override
  void dispose() {
    widget.reloads?.removeListener(_reload);
    widget.faceSheet.removeListener(_sheetChanged);
    _environment.removeListener(_accountChanged);
    _paging.dispose();
    _inline?.dispose();
    _model?.dispose();
    _faces.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _loggedOut => switch (_environment.account) {
    LoggedOut() || LoginExpired() => true,
    LoggedIn() || AccountUnknown() => false,
  };

  /// The first show loads 最常访问 and the list; logged out it asks Bilibili nothing.
  void _start() {
    if (_started || _loggedOut) return;
    _started = true;
    _starts++;
    unawaited(_model!.start());
  }

  /// Logging out empties the tab (and closes the sheet); logging in loads it at once if 关注 is showing, otherwise on
  /// its next show.
  void _accountChanged() {
    final out = _loggedOut;
    if (out == _signedOut) return;
    _signedOut = out;
    if (out) {
      widget.faceSheet.close();
      _model?.signOut();
      _started = false;
    } else if (widget.active) {
      _start();
    }
    setState(() {});
  }

  void _modelChanged() {
    if (!mounted) return;
    setState(() {});
    _inline?.settleSoon();
  }

  void _sheetChanged() {
    if (mounted) setState(() {});
  }

  Future<String?> _refresh() {
    if (_refreshing case final running?) return running;
    late final Future<String?> refresh;
    refresh = _model!.refresh().whenComplete(() {
      if (identical(_refreshing, refresh)) _refreshing = null;
    });
    return _refreshing = refresh;
  }

  Future<void> _pull() async {
    final failure = await _refresh();
    if (failure != null && mounted) showToast(context, failure);
  }

  /// 关注 tapped while shown, as 首页's: back to the top, then the TV held open there until the refresh is done. With
  /// no post shown the list's own TV stands for it, and a first load still out answers for it (a double tap on the
  /// first show asks once).
  Future<void> _reload() async {
    if (_refreshing != null || _loggedOut) return;
    if (!_started) {
      _start();
      return;
    }
    if (_model!.current.items.isEmpty) {
      unawaited(_refresh());
      return;
    }
    final refresh = _refresh();
    if (_scroll.hasClients) {
      if (_still) {
        _scroll.jumpTo(0);
      } else {
        await _scroll.animateTo(0, duration: DynamicFeedTheme.reloadScroll, curve: Curves.easeOut);
      }
    }
    if (!mounted || !identical(_refreshing, refresh)) return;
    setState(() => _reloadHeader = _reloadRoom = true);
    final failure = await refresh;
    if (!mounted) return;
    setState(() => _reloadHeader = false);
    if (failure != null) showToast(context, failure);
  }

  Future<void> _login() async {
    final starts = _starts;
    final loggedIn = await _services.loginGate.request(context);
    // A login that changed the account has loaded the tab already (_accountChanged).
    if (!loggedIn || !mounted || !widget.active || _starts != starts) return;
    if (_started) {
      unawaited(_refresh());
    } else {
      _start();
    }
  }

  void _soonToast() => showToast(context, _soon);

  /// 全部 ›: the account's own space on its 追番.
  void _openOwnBangumi() {
    final mid = _environment.mid;
    if (mid == null) return;
    unawaited(openSpace(context, UploaderRef(mid: mid, face: _environment.face), ownTab: SpaceTabKind.bangumi));
  }

  void _openFace(DynamicUp up) {
    final box = _facesKey.currentContext?.findRenderObject();
    final top = box is RenderBox && box.attached ? box.localToGlobal(Offset.zero).dy : null;
    widget.faceSheet.open(up, model: _model!, rowOffset: _faces.hasClients ? _faces.offset : 0, originTop: top);
  }

  Rect? _listArea() {
    final box = _listKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final area = box.localToGlobal(Offset.zero) & box.size;
    return Rect.fromLTRB(area.left, area.top, area.right, math.max(area.top, area.bottom - _inset));
  }

  @override
  Widget build(BuildContext context) {
    final head = widget.skin?.headBg != null ? widget.skin : null;
    return SkinDecodeGate(
      pictures: [?head?.headBg],
      builder: (context, decoded) => _page(context, decoded ? head : null),
    );
  }

  /// [head] dresses the header once its picture has decoded.
  Widget _page(BuildContext context, Skin? head) {
    _still = MediaQuery.disableAnimationsOf(context);
    _inset = MediaQuery.paddingOf(context).bottom;
    final inline = _inline ??= FeedInlineHost(viewport: _listArea, pip: _services.pipKeeper);
    // A route over the shell (a page, a sheet, a menu), another tab or the face sheet pauses the cards.
    inline.shown =
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        !widget.faceSheet.isOpen;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (head != null ? head.lightStatusFollow : BiliPalette.of(context).isDark) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Material(
        color: BiliColors.colorsOf(context).card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FollowHeader(skin: head, onWrite: _soonToast),
            Expanded(
              child: KeyedSubtree(key: _listKey, child: _body(context, inline)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, FeedInlineHost inline) {
    // A -101 with nothing shown asks for the login too: the app may still think it is logged in.
    if (_loggedOut || (_model!.current.needsLogin && _model!.current.items.isEmpty)) {
      return Center(
        key: const ValueKey('follow-logged-out'),
        child: FollowStateMessage(
          message: '登录后查看关注动态',
          button: FollowPinkButton(
            key: const ValueKey('follow-login'),
            label: '登录',
            onTap: () => unawaited(_login()),
            text: DynamicFeedTheme.loginText,
            height: DynamicFeedTheme.loginHeight,
            padX: DynamicFeedTheme.loginPadX,
          ),
        ),
      );
    }
    // Never shown yet: nothing to draw, and no TV ticking out of sight.
    if (!_started) return const SizedBox.shrink();
    final model = _model!;
    final feed = model.current;
    final items = feed.items;
    final bangumi = model.bangumi;
    final bottom = _inset;
    final still = _still;
    final room = refreshRoom;
    return _paging.listen(
      _scroll,
      NotificationListener<ScrollNotification>(
        onNotification: inline.onScroll,
        child: CustomScrollView(
          key: const ValueKey('follow-list'),
          controller: _scroll,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            ReleaseRefreshControl(
              refreshTriggerPullDistance: refreshTrigger,
              refreshIndicatorExtent: room,
              builder: _reloadHeader ? null : loadingTvRefreshIndicator,
              onRefresh: _reloadHeader ? null : _pull,
            ),
            SliverToBoxAdapter(
              child: AnimatedContainer(
                duration: still
                    ? Duration.zero
                    : _reloadHeader
                    ? DynamicFeedTheme.reloadHeader
                    : DynamicFeedTheme.reloadCollapse,
                curve: Curves.easeInOut,
                height: _reloadHeader ? room : 0,
                onEnd: () {
                  if (!_reloadHeader && mounted) setState(() => _reloadRoom = false);
                },
                child: _reloadRoom
                    ? ClipRect(
                        child: OverflowBox(
                          key: const ValueKey('follow-reload'),
                          alignment: Alignment.bottomCenter,
                          minHeight: room,
                          maxHeight: room,
                          child: Center(child: RefreshLoading(room: room)),
                        ),
                      )
                    : null,
              ),
            ),
            SliverToBoxAdapter(
              child: FollowTop(
                type: model.type,
                ups: model.ups,
                dot: model.hasUpdate,
                onSelect: model.select,
                onOpenFace: _openFace,
                onMore: () => unawaited(openFollowingList(context)),
                onNearEnd: () => unawaited(model.loadMoreUps()),
                facesController: _faces,
                facesKey: _facesKey,
              ),
            ),
            if (bangumi.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _Band()),
              SliverToBoxAdapter(
                child: FollowBangumiSection(items: bangumi, onAll: _openOwnBangumi, onOpen: (_) => _soonToast()),
              ),
            ],
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Band(),
                    Padding(
                      padding: EdgeInsets.only(top: DynamicFeedTheme.stateTop, bottom: bottom),
                      child: Center(child: _state(feed)),
                    ),
                  ],
                ),
              )
            else ...[
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => FollowPosts.row(context, items[index], inline, bandAbove: index == 0),
              ),
              SliverToBoxAdapter(
                child: FollowFooter(
                  keyPrefix: 'follow',
                  loading: feed.loading && !feed.refreshing,
                  error: feed.error,
                  isEnd: feed.isEnd,
                  onRetry: () => unawaited(feed.loadMore()),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: bottom)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _state(FollowFeed feed) {
    final error = feed.error;
    if (error != null && !feed.loading) {
      return FollowStateMessage(
        key: const ValueKey('follow-failed'),
        message: error,
        button: FollowPinkButton(
          key: const ValueKey('follow-retry'),
          label: '重试',
          onTap: () => unawaited(feed.retry()),
          text: DynamicFeedTheme.retryText,
          height: DynamicFeedTheme.retryHeight,
          padX: DynamicFeedTheme.retryPadX,
        ),
      );
    }
    if (feed.isEnd && !feed.loading) {
      return const FollowStateMessage(key: ValueKey('follow-empty'), message: '还没有动态');
    }
    return const LoadingTvState(key: ValueKey('follow-loading'));
  }
}

class _Band extends StatelessWidget {
  const _Band();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: DynamicFeedTheme.band,
    child: ColoredBox(color: DynamicFeedTheme.colorsOf(context).bandFill),
  );
}
