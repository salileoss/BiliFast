import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../app/form_factor.dart';
import '../app/swipe_back_route.dart';
import '../app/zoom_back_route.dart';
import '../player_ui/player_loading.dart';
import '../player_ui/seek_bar.dart';
import '../history/watch_history_page.dart';
import '../search/results/video_row.dart' show searchLogReason;
import '../search/search_page.dart';
import '../shared/loading_tv.dart';
import '../shared/release_refresh.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../skin/skin.dart';
import '../video/link_opener.dart';
import '../video/page_playback.dart';
import '../video/player_prefs.dart';
import '../video/video_route.dart';
import 'avatar_page.dart';
import 'feed_big_card.dart';
import 'feed_card.dart';
import 'feed_divider.dart';
import 'feed_inline_player.dart';
import 'feed_model.dart';
import 'home_header.dart';
import 'tab_bar_icons.dart' show SkinDecodeGate;

/// 首页 (01, port of HomeView.swift): the avatar and the search entry, the 推荐 tab and its feed, above the bottom bar
/// `MainShell` holds. The entry opens 搜索 with the default word; the avatar opens its page (49), with 设置, the
/// shortcuts and the last of 最近打开.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.developerPage, this.initialLink, this.reloads, this.skin});

  /// Builds the developer page (dev builds), passed on to 设置 through the avatar's page; null leaves 开发者 out.
  final WidgetBuilder? developerPage;

  /// Opened as a pasted link once home is up (`--play=<BV or link>` on the PC).
  final String? initialLink;

  /// Notifies for each tap on the bar's 首页 while 首页 shows: 推荐 goes back to the top and refreshes.
  final Listenable? reloads;

  /// The equipped 装扮: with a `head_bg` it dresses the top (110).
  final Skin? skin;

  /// Gets a 推荐 cover ready before its card shows; tests stand in for [FeedCardView.precacheCover], as they have no
  /// network.
  @visibleForTesting
  static Future<bool> Function(BuildContext context, String? url, Size size) precacheCover = FeedCardView.precacheCover;

  /// [FeedBigCardView.precacheCover], the big cards' own, for tests as [precacheCover].
  @visibleForTesting
  static Future<bool> Function(BuildContext context, String? url, Size size) precacheBigCover =
      FeedBigCardView.precacheCover;

  /// Feed pages in place of the network for tests.
  @visibleForTesting
  static Future<List<FeedCard>> Function(int index)? feedPages;

  /// [FeedModel.minimumRefresh] for 推荐; tests about what follows a swap set it to zero.
  @visibleForTesting
  static Duration feedMinimumRefresh = FeedModel.minimumRefresh;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late AppServices _services;
  FeedModel? _feed;
  final _grid = GlobalKey<_FeedGridState>();

  /// How far 推荐 is scrolled, which folds the header's top row away (121).
  final _feedOffset = ValueNotifier<double>(0);
  late final _opener = LinkOpener(onPushed: (pushed) => unawaited(_visit(pushed)));
  bool _opening = false;

  /// The search entry's grey word, asked for once; null until it comes, and after a failure.
  String? _searchWord;

  /// Whether the feed on screen was fetched logged in; null until the first account check has answered.
  bool? _feedSignedIn;

  /// Whether the app token was held when last heard, so a new one can bring the official 推荐 and a lost one take it
  /// away.
  bool _authorized = false;

  /// The refresh of 推荐 running, from the first load, an account change, a pull, 首页 or 重试; a pull or a tap while
  /// it runs waits on it instead of asking again.
  Future<void>? _refreshing;

  /// Counts the refreshes started, so a lost token's refresh can tell whether another came first.
  int _refreshesStarted = 0;

  AppEnvironment get _environment => _services.environment;

  @override
  void initState() {
    super.initState();
    widget.reloads?.addListener(_reload);
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.reloads, widget.reloads)) {
      oldWidget.reloads?.removeListener(_reload);
      widget.reloads?.addListener(_reload);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_feed != null) return;
    _services = AppScope.of(context);
    _opener.busy.addListener(_busyChanged);
    _feed = FeedModel(
      client: _environment.client,
      minimumRefresh: HomePage.feedMinimumRefresh,
      webPage: HomePage.feedPages,
    );
    unawaited(LoadingTv.precache(context));
    unawaited(PlayerLoading.precache());
    unawaited(SeekBar.precache());
    unawaited(_refreshFeed());
    _environment.addListener(_accountChanged);
    _accountChanged();
    _authorized = _services.appAuth.authorized;
    _services.appAuth.addListener(_authChanged);
    unawaited(_loadSearchWord());
    final link = widget.initialLink;
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_opener.open(context, link));
      });
    }
  }

  @override
  void dispose() {
    widget.reloads?.removeListener(_reload);
    _opener.dispose();
    _environment.removeListener(_accountChanged);
    _services.appAuth.removeListener(_authChanged);
    _feed?.dispose();
    _feedOffset.dispose();
    super.dispose();
  }

  void _busyChanged() => setState(() => _opening = _opener.busy.value);

  Future<void> _loadSearchWord() async {
    try {
      final word = await _services.searchApi.defaultWord();
      if (mounted) setState(() => _searchWord = word);
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'default search word failed', {'error': searchLogReason(error)});
    }
  }

  /// Logging in or out changes what 推荐 recommends; the first check at launch does not.
  void _accountChanged() {
    final bool signedIn;
    switch (_environment.account) {
      case AccountUnknown():
        return;
      case LoggedIn():
        signedIn = true;
      case LoggedOut() || LoginExpired():
        signedIn = false;
    }
    final previous = _feedSignedIn;
    _feedSignedIn = signedIn;
    if (previous != null && previous != signedIn) unawaited(_refreshFeed(restart: true));
  }

  /// A token that arrives after 推荐 came from the website (at launch the stored one may land after the first load,
  /// or the confirm was just given) brings the official feed in its place. One lost (rejected, another account's,
  /// 退出登录) takes the official cards away, as they were that token's.
  void _authChanged() {
    final authorized = _services.appAuth.authorized;
    final gained = authorized && !_authorized;
    final lost = !authorized && _authorized;
    _authorized = authorized;
    if (gained && PlayerPrefs.shared.officialFeed && _feed?.source != FeedSource.official) {
      unawaited(_refreshFeed(restart: true));
    } else if (lost && _feed?.source == FeedSource.official) {
      // 退出登录 drops the token just before the account hears of it, and the account's refresh is the one wanted:
      // waiting out this turn keeps that to one call.
      final started = _refreshesStarted;
      scheduleMicrotask(() {
        if (mounted && _refreshesStarted == started) unawaited(_refreshFeed(restart: true));
      });
    }
  }

  /// The running refresh, or a new one. [restart] starts one even while another runs (whose answer the feed then
  /// drops), as a refresh asked for before the account changed would bring the old account's 推荐; its page replaces
  /// every card rather than going on top of them. A [pulled] one takes the page its pull already asked for.
  Future<void> _refreshFeed({bool restart = false, bool pulled = false}) {
    final running = _refreshing;
    if (running != null && !restart) return running;
    _refreshesStarted += 1;
    late final Future<void> refresh;
    refresh = _fetchFeed(pulled: pulled, replace: restart).whenComplete(() {
      if (identical(_refreshing, refresh)) _refreshing = null;
    });
    return _refreshing = refresh;
  }

  /// A refresh that fails with cards on screen keeps them and says why in a toast.
  Future<void> _fetchFeed({required bool pulled, required bool replace}) async {
    final failure = await _feed?.refresh(pulled: pulled, replace: replace);
    if (failure != null && mounted) showToast(context, failure);
  }

  Future<void> _pullRefresh() => _refreshFeed(pulled: true);

  /// A pull held past its trigger starts its page, unless a refresh is already out: the release joins that one.
  void _pullArmed() {
    if (_refreshing == null) _feed?.pullArmed();
  }

  void _pullDisarmed() => _feed?.pullDisarmed();

  /// Back on home from a pushed page, an account check that failed is tried again, as Swift's HomeView.task did on
  /// every return; one still running is left to answer.
  Future<void> _visit(Future<void> pushed) async {
    await pushed;
    if (mounted && _environment.account is AccountUnknown && _environment.accountCheckFailed) {
      await _environment.refreshAccount();
    }
  }

  void _openAvatarPage() {
    final page = SwipeBackPageRoute<void>(builder: (_) => AvatarPage(developerPage: widget.developerPage));
    unawaited(_visit(Navigator.of(context).push(page)));
  }

  void _openHistory() {
    final page = SwipeBackPageRoute<void>(builder: (_) => const WatchHistoryPage());
    unawaited(_visit(Navigator.of(context).push(page)));
  }

  void _openSearch() => unawaited(_visit(openSearchPage(context, placeholder: _searchWord)));

  void _reload() => unawaited(_grid.currentState?.reload());

  void _openCard(FeedCard card, ZoomSource source) => unawaited(
    _visit(
      openVideoPage(context, VideoRoute(bvid: card.bvid, title: card.title, cover: card.cover, zoomSource: source)),
    ),
  );

  /// A big card's page slides in, as the official one does (124). With the card's running [playback] the page goes
  /// on from the very frame, with sound; without it, it starts from [start] when the card had played.
  Future<void> _openBig(FeedCard card, PagePlayback? playback, double? start) => _visit(
    openVideoPage(
      context,
      VideoRoute(
        bvid: card.bvid,
        cid: playback == null && start != null && card.cid > 0 ? card.cid : null,
        start: playback == null ? start : null,
        title: card.title,
        cover: playback == null ? card.cover : null,
        playback: playback,
      ),
    ),
  );

  /// Logged out it goes to the login page and sends nothing; an account still being checked tries, and goes there
  /// only if Bilibili answers that it needs a login.
  Future<void> _watchLater(FeedCard card) async {
    if (_environment.account case LoggedOut() || LoginExpired()) {
      await _services.loginGate.request(context);
      return;
    }
    try {
      await _environment.client.addToWatchLater(aid: card.aid);
      if (mounted) showToast(context, '已添加至稍后再看');
    } catch (error) {
      if (error is BiliError && error.needsLogin) {
        if (mounted) await _services.loginGate.request(context);
        return;
      }
      Logger.shared.warn(LogCategory.ui, 'watch later failed', feedLogFields(error));
      if (mounted) showToast(context, requestFailureMessage(error));
    }
  }

  /// Without the app token the confirm is asked first; the card turns over only once it is given.
  Future<bool> _authorize() async {
    final auth = _services.appAuth;
    return auth.authorized || await auth.request(context);
  }

  Future<void> _dislike(FeedCard card, FeedReason reason) async {
    if (!await _authorize() || !mounted) return;
    _dislikeFailed(await _feed!.dislike(card, reason));
  }

  Future<void> _undoDislike(FeedCard card) async {
    if (!await _authorize() || !mounted) return;
    _dislikeFailed(await _feed!.undo(card));
  }

  /// The official app says nothing after a reason is picked, so neither does this, unless it fails.
  Future<void> _dislikeReason(FeedCard card, FeedReason reason) async {
    if (!await _authorize() || !mounted) return;
    _dislikeFailed(await _feed!.sendReason(card, reason));
  }

  /// A refused token asks for the confirm again, as the video page's 不喜欢 does; the tap isn't replayed.
  void _dislikeFailed(DislikeFailure? failure) {
    if (failure == null || !mounted) return;
    switch (failure) {
      case DislikeTokenRefused():
        unawaited(_services.appAuth.request(context));
      case DislikeError(:final message):
        showToast(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final head = widget.skin?.headBg != null ? widget.skin : null;
    return SkinDecodeGate(
      pictures: [?head?.headBg, ?head?.headTabBg],
      builder: (context, decoded) => _page(context, decoded ? head : null),
    );
  }

  /// [head] dresses the top once its pictures have decoded; null keeps 01's.
  Widget _page(BuildContext context, Skin? head) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (head != null ? head.lightStatusHome : BiliPalette.of(context).isDark)
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: FormFactor.of(context).isPad
            ? PadHomeTheme.colorsOf(context).page
            : BiliColors.colorsOf(context).card,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Column(
              children: [
                ListenableBuilder(
                  listenable: _environment,
                  builder: (context, _) => HomeHeader(
                    skin: head,
                    face: _environment.face,
                    searchWord: _searchWord,
                    feedOffset: _feedOffset,
                    onAvatar: _openAvatarPage,
                    onSearch: _openSearch,
                    onHistory: _openHistory,
                  ),
                ),
                Expanded(
                  child: _FeedGrid(
                    key: _grid,
                    feed: _feed!,
                    onOpen: _openCard,
                    onOpenBig: _openBig,
                    onWatchLater: _watchLater,
                    onDislike: _dislike,
                    onUndo: _undoDislike,
                    onReason: _dislikeReason,
                    onRefresh: _refreshFeed,
                    onPull: _pullRefresh,
                    onPullArmed: _pullArmed,
                    onPullDisarmed: _pullDisarmed,
                    refreshing: () => _refreshing,
                    scrollOffset: _feedOffset,
                  ),
                ),
              ],
            ),
            IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                child: Center(
                  child: _Presence(
                    visible: _opening,
                    duration: still ? Duration.zero : const Duration(milliseconds: 220),
                    reverseDuration: still ? Duration.zero : const Duration(milliseconds: 180),
                    builder: (context, animation) => ScaleTransition(
                      scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                      child: FadeTransition(
                        opacity: animation,
                        child: Container(
                          key: const ValueKey('opening'),
                          padding: const EdgeInsets.all(BiliMetrics.openingPadding),
                          decoration: BoxDecoration(
                            color: BiliColors.toastFill,
                            borderRadius: BorderRadius.circular(BiliMetrics.toastRadius),
                          ),
                          child: const CupertinoActivityIndicator(
                            radius: BiliMetrics.openingSpinner / 2,
                            color: BiliColors.panelText,
                          ),
                        ),
                      ),
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

/// Builds its child only while [visible] or animating out, so nothing in it (a spinner above all) keeps ticking once
/// it has gone.
class _Presence extends StatefulWidget {
  const _Presence({
    required this.visible,
    required this.duration,
    this.reverseDuration,
    this.reverseCurve = Curves.easeIn,
    required this.builder,
  });

  final bool visible;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve reverseCurve;
  final Widget Function(BuildContext context, Animation<double> animation) builder;

  @override
  State<_Presence> createState() => _PresenceState();
}

class _PresenceState extends State<_Presence> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    reverseDuration: widget.reverseDuration,
    value: widget.visible ? 1 : 0,
  )..addStatusListener(_statusChanged);
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: widget.reverseCurve,
  );

  void _statusChanged(AnimationStatus status) {
    if (status.isDismissed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_Presence oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller
      ..duration = widget.duration
      ..reverseDuration = widget.reverseDuration;
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        unawaited(_controller.forward());
      } else {
        unawaited(_controller.reverse());
      }
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _controller.isDismissed ? const SizedBox.shrink() : widget.builder(context, _curved);
}

class _FeedGrid extends StatefulWidget {
  const _FeedGrid({
    super.key,
    required this.feed,
    required this.onOpen,
    required this.onOpenBig,
    required this.onWatchLater,
    required this.onDislike,
    required this.onUndo,
    required this.onReason,
    required this.onRefresh,
    required this.onPull,
    required this.onPullArmed,
    required this.onPullDisarmed,
    required this.refreshing,
    required this.scrollOffset,
  });

  final FeedModel feed;
  final void Function(FeedCard card, ZoomSource source) onOpen;
  final Future<void> Function(FeedCard card, PagePlayback? playback, double? start) onOpenBig;
  final void Function(FeedCard card) onWatchLater;
  final void Function(FeedCard card, FeedReason reason) onDislike;
  final void Function(FeedCard card) onUndo;
  final void Function(FeedCard card, FeedReason reason) onReason;

  /// The page's refresh: the one running, or a new one.
  final Future<void> Function() onRefresh;

  /// The pull's refresh, and its arming past the trigger and falling back, which fetch ahead of the release.
  final Future<void> Function() onPull;
  final VoidCallback onPullArmed;
  final VoidCallback onPullDisarmed;

  /// The refresh running, if any.
  final Future<void>? Function() refreshing;

  /// Kept at the list's scroll offset.
  final ValueNotifier<double> scrollOffset;

  @override
  State<_FeedGrid> createState() => _FeedGridState();
}

/// A card leaving in a refresh's hand-off, drawn as it was.
typedef _Going = ({FeedCard card, CardDislike? dislike});

class _FeedGridState extends State<_FeedGrid> with SingleTickerProviderStateMixin, SkinRefreshRoom {
  static const _skeletons = 6;

  /// The next page is asked for once fewer than this many rows of cards are left below the screen.
  static const _rowsAhead = 2;

  /// Cards appearing in the same frame come in this far apart, the later ones all at the last step.
  static const _staggerStep = Duration(milliseconds: 45);
  static const _staggerSteps = 6;

  final _scroll = ScrollController();

  /// Cards that have made their entrance; one rebuilt or scrolled back into view just shows.
  final _entered = <String>{};
  int _batch = 0;
  double _rowExtent = 0;

  /// Whether 首页's refresh shows the pull-to-refresh TV at the top.
  bool _reloadHeader = false;

  /// 首页's tap is taking 推荐 back to the top: the header opens at the tap, alongside the scroll, as the official
  /// app's does (`differences/23`: both start in the tap's frame; ours used to wait for the scroll's last 6 pt).
  bool _toTop = false;

  late final AnimationController _handOff = AnimationController(vsync: this, duration: HomeTabBarTheme.handOff)
    ..addStatusListener(_handOffStatus);
  late final CurvedAnimation _incoming = CurvedAnimation(parent: _handOff, curve: HomeTabBarTheme.handOffCurve);
  late final Animation<double> _outgoing = ReverseAnimation(_incoming);

  /// The cards fading out, by grid slot, while a refresh's cards come in; null otherwise.
  List<_Going>? _going;

  /// The refresh [FeedModel.beforeShow] last saw, until its cards show (a held pull's may never): its cards, the
  /// ones they replace, and those as they will fade out.
  ({List<FeedCard> fresh, List<FeedCard> old, List<_Going> going})? _coming;

  /// What the last build and layout gave the grid, to ask for the first screen's covers at their cards' size.
  Size? _viewport;

  /// The list as last built, and the width it was built for: the header's fold changes only the height, every frame
  /// of it, and the list is laid out again without building every card again.
  Widget? _laidOut;
  double? _laidOutWidth;
  bool _rebuilt = true;
  double _inset = 0;
  TextScaler _scaler = TextScaler.noScaling;

  /// Whether the last build asked for Reduce Motion or had 首页 out of sight; either makes a hand-off instant.
  bool _still = false;
  bool _ticking = true;

  late final _inline = FeedInlineHost(viewport: _feedArea, pip: AppScope.of(context).pipKeeper);

  @override
  void initState() {
    super.initState();
    _attach(widget.feed);
  }

  @override
  void didUpdateWidget(_FeedGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feed, widget.feed)) {
      _detach(oldWidget.feed);
      _attach(widget.feed);
    }
  }

  @override
  void dispose() {
    _detach(widget.feed);
    _inline.dispose();
    _incoming.dispose();
    _handOff.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _attach(FeedModel feed) => feed
    ..addListener(_feedChanged)
    ..beforeShow = _beforeShow;

  void _detach(FeedModel feed) {
    feed.removeListener(_feedChanged);
    if (feed.beforeShow == _beforeShow) feed.beforeShow = null;
  }

  /// Whether the last build used the iPad grid rather than the phone video feed.
  bool _pad = false;

  double _columnWidth(double gridWidth) =>
      _pad ? PadHomeTheme.cardWidth(gridWidth) : (gridWidth - BiliMetrics.feedSpacing * 3) / 2;

  static double _bigWidth(double gridWidth) => gridWidth - FeedBigCardTheme.spacing * 2;

  double _cardHeight(double width) => _pad ? PadHomeTheme.cardHeight(width) : FeedCardSize.height(width, _scaler);

  double get _rowGap => _pad ? PadHomeTheme.rowGap : FeedBigCardTheme.topGap;

  /// The cards' visible area on screen, above a dressed bar's row.
  Rect? _feedArea() {
    final box = mounted ? context.findRenderObject() : null;
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final area = box.localToGlobal(Offset.zero) & box.size;
    return Rect.fromLTRB(area.left, area.top, area.right, math.max(area.top, area.bottom - _inset));
  }

  /// Notes the cards going and starts the covers of the rows the top of the list shows, at the size their cards will
  /// ask for: full-width phone tiles, or every column of an iPad row.
  CoverPrefetch _beforeShow(List<FeedCard> fresh) {
    if (!mounted) return const CoverPrefetch.skipped(CoverSkip.unmounted);
    final feed = widget.feed;
    final old = feed.cards;
    _coming = (fresh: fresh, old: old, going: _goingOf(old));
    final viewport = _viewport;
    if (viewport == null) return const CoverPrefetch.skipped(CoverSkip.noLayout);
    final columns = _pad ? PadHomeTheme.columns : 2;
    final width = _columnWidth(viewport.width);
    final bigWidth = _bigWidth(viewport.width);
    final rowExtent = _cardHeight(width) + _rowGap;
    final size = _pad ? Size(width, PadHomeTheme.coverHeight(width)) : FeedCardSize.cover(width);
    final bottom = viewport.height - _inset;
    final asks = <Future<bool>>[];
    var top = _pad ? PadHomeTheme.firstRow : FeedBigCardTheme.topGap;
    var slot = 0;
    while (slot < fresh.length && top < bottom) {
      final card = fresh[slot++];
      if (!_pad) {
        asks.add(HomePage.precacheBigCover(context, card.cover, FeedBigCardSize.video(bigWidth)));
        top += FeedBigCardSize.height(bigWidth) + _rowGap;
        continue;
      }
      asks.add(HomePage.precacheCover(context, card.cover, size));
      for (var column = 1; column < columns && slot < fresh.length; column++) {
        asks.add(HomePage.precacheCover(context, fresh[slot++].cover, size));
      }
      top += rowExtent;
    }
    if (asks.isEmpty) return const CoverPrefetch.skipped(CoverSkip.noRows);
    return CoverPrefetch(asks);
  }

  List<_Going> _goingOf(List<FeedCard> cards) => [
    for (final card in cards) (card: card, dislike: widget.feed.dislikeOf(card)),
  ];

  void _feedChanged() {
    final cards = widget.feed.cards;
    final coming = _coming;
    if (coming != null && identical(widget.feed.newest, coming.fresh)) {
      _coming = null;
      _handOffFrom(coming.going, coming.fresh);
    } else if (coming != null && identical(cards, coming.old)) {
      // A 不感兴趣 or 撤销 before the swap, read now: by the swap the refresh has dropped every one.
      _coming = (fresh: coming.fresh, old: coming.old, going: _goingOf(cards));
    }
    setState(() {});
    _inline.settleSoon();
    // A page too short to scroll leaves the end on screen with no scrolling to notice it; look once it is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _loadMoreNearEnd(_scroll.position);
    });
  }

  /// A refresh's cards taking the top from cards on screen make no entrance: the cards that held their slots fade out
  /// over them, all at once, as the official app's do (14, 122), and those kept under 刚刚看到这里 just show. At once
  /// with Reduce Motion, or while 首页 is out of sight.
  void _handOffFrom(List<_Going> old, List<FeedCard> fresh) {
    if (old.isEmpty) return;
    _entered.addAll([for (final card in fresh) card.bvid]);
    if (_still || !_ticking) {
      _going = null;
      _handOff.value = 1;
      return;
    }
    _going = old;
    unawaited(_handOff.forward(from: 0));
  }

  void _handOffStatus(AnimationStatus status) {
    if (status.isCompleted && _going != null && mounted) setState(() => _going = null);
  }

  /// 首页's tap, as the official app's: back to the top and 推荐 refreshed at once, whether scrolled or already at the
  /// top, with the pull-to-refresh TV held at the top until the new cards come (not before
  /// [FeedModel.minimumRefresh]). Nothing more while a refresh (or the first load) runs.
  Future<void> reload() async {
    final feed = widget.feed;
    if (widget.refreshing() case final running?) return running;
    if (feed.cards.isEmpty && feed.loading) return;
    final refresh = widget.onRefresh();
    if (!_scroll.hasClients) return refresh;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _toTop = true;
      widget.scrollOffset.value = 0;
      try {
        await _scroll.animateTo(0, duration: HomeTabBarTheme.reloadScroll, curve: Curves.easeOut);
      } finally {
        _toTop = false;
      }
      // A finger can stop the scroll short of the top.
      if (mounted && _scroll.hasClients) widget.scrollOffset.value = math.max(0, _scroll.position.pixels);
    }
    if (!mounted || !identical(widget.refreshing(), refresh)) return;
    setState(() => _reloadHeader = true);
    await refresh;
    if (mounted) setState(() => _reloadHeader = false);
  }

  bool _scrolled(ScrollNotification notification) {
    if (notification.depth == 0) {
      // Only what the list really scrolls: a bounce past either end (a short list, the error page) folds nothing.
      final metrics = notification.metrics;
      if (!_toTop) {
        widget.scrollOffset.value = metrics.hasContentDimensions
            ? metrics.pixels.clamp(metrics.minScrollExtent, metrics.maxScrollExtent)
            : metrics.pixels;
      }
      _loadMoreNearEnd(notification.metrics);
      // Check after layout on every scroll frame, including while the finger is still down.
      _inline.settleSoon();
    }
    return false;
  }

  void _loadMoreNearEnd(ScrollMetrics metrics) {
    if (!widget.feed.canLoadMore || !metrics.hasContentDimensions) return;
    if (metrics.extentAfter >= _rowExtent * _rowsAhead) return;
    // A scroll notification can come mid-layout, where the feed's change must not rebuild anything yet.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.feed.canLoadMore) unawaited(widget.feed.loadMore());
      });
    } else {
      unawaited(widget.feed.loadMore());
    }
  }

  Duration _nextStagger() {
    if (_batch == 0) WidgetsBinding.instance.addPostFrameCallback((_) => _batch = 0);
    return _staggerStep * math.min(_batch++, _staggerSteps);
  }

  /// [cards] from [from] up to [to], none of them big. A hand-off fades the cards [going] out over the top batch alone,
  /// in the slots they held (a small card over a small one); under 刚刚看到这里 they already stand in their new places.
  Widget _cardGrid(
    SliverGridDelegate grid,
    List<FeedCard> cards,
    int from,
    int to, {
    required List<_Going>? going,
    required bool still,
  }) {
    final feed = widget.feed;
    return SliverGrid(
      gridDelegate: grid,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final slot = from + index;
          final card = cards[slot];
          final enter = !still && _entered.add(card.bvid);
          final gone = going != null && slot < going.length ? going[slot] : null;
          return _Entrance(
            key: ValueKey('feed-card-${card.bvid}'),
            delay: enter ? _nextStagger() : null,
            child: _HandOffSlot(
              incoming: going == null ? null : _incoming,
              outgoing: _outgoing,
              going: gone == null
                  ? null
                  : FeedCardView(
                      key: ValueKey('feed-card-going-${gone.card.bvid}'),
                      card: gone.card,
                      onOpen: (_) {},
                      onWatchLater: () {},
                      dislike: gone.dislike,
                    ),
              child: FeedCardView(
                card: card,
                onOpen: (source) => widget.onOpen(card, source),
                onWatchLater: () => widget.onWatchLater(card),
                dislike: feed.dislikeOf(card),
                onDislike: (reason) => widget.onDislike(card, reason),
                onUndo: () => widget.onUndo(card),
                onReason: (reason) => widget.onReason(card, reason),
              ),
            ),
          );
        },
        childCount: to - from,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          for (var slot = from; slot < to; slot++) {
            if ('feed-card-${cards[slot].bvid}' == key.value) return slot - from;
          }
          return null;
        },
      ),
    );
  }

  /// A phone tile, with the same inline playback for every video.
  Widget _phoneCard(List<FeedCard> cards, int slot, {required List<_Going>? going, required bool still}) {
    final feed = widget.feed;
    final card = cards[slot];
    final gone = going != null && slot < going.length ? going[slot] : null;
    final enter = !still && _entered.add(card.bvid);
    return _Entrance(
      key: ValueKey('feed-card-${card.bvid}'),
      delay: enter ? _nextStagger() : null,
      child: _HandOffSlot(
        incoming: going == null ? null : _incoming,
        outgoing: _outgoing,
        going: gone == null
            ? null
            : FeedBigCardView(
                key: ValueKey('feed-card-going-${gone.card.bvid}'),
                card: gone.card,
                onOpen: (_, _) async {},
                onWatchLater: () {},
                dislike: gone.dislike,
              ),
        child: FeedBigCardView(
          card: card,
          host: _inline,
          onOpen: (playback, start) => widget.onOpenBig(card, playback, start),
          onWatchLater: () => widget.onWatchLater(card),
          dislike: feed.dislikeOf(card),
          onDislike: (reason) => widget.onDislike(card, reason),
          onUndo: () => widget.onUndo(card),
          onReason: (reason) => widget.onReason(card, reason),
        ),
      ),
    );
  }

  /// Phone tiles in a lazy list, or the iPad grid, split at 刚刚看到这里 after a refresh.
  List<Widget> _cardSlivers(SliverGridDelegate grid, List<FeedCard> cards, int? divider, {required bool still}) {
    if (!_pad) {
      Widget batch(int from, int to, {required bool first}) => SliverPadding(
        padding: EdgeInsets.fromLTRB(
          FeedBigCardTheme.spacing,
          first ? FeedBigCardTheme.topGap : 0,
          FeedBigCardTheme.spacing,
          0,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final slot = from + index;
              return KeyedSubtree(
                key: ValueKey(cards[slot].bvid),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _phoneCard(cards, slot, going: from == 0 ? _going : null, still: still),
                    const SizedBox(height: FeedBigCardTheme.topGap),
                    Divider(height: 0.5, thickness: 0.5, color: BiliPalette.of(context).divider),
                    const SizedBox(height: FeedBigCardTheme.topGap),
                  ],
                ),
              );
            },
            childCount: to - from,
            findChildIndexCallback: (key) {
              if (key is! ValueKey<String>) return null;
              for (var slot = from; slot < to; slot++) {
                if (cards[slot].bvid == key.value) return slot - from;
              }
              return null;
            },
          ),
        ),
      );
      return [
        batch(0, divider ?? cards.length, first: true),
        if (divider != null) ...[
          SliverToBoxAdapter(
            child: FeedDivider(key: const ValueKey('feed-divider'), onTap: () => unawaited(reload())),
          ),
          batch(divider, cards.length, first: false),
        ],
      ];
    }
    final slivers = <Widget>[];
    void batch(int from, int to, {required bool first, required bool last}) {
      if (from == to) return;
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            PadHomeTheme.margin,
            first ? PadHomeTheme.firstRow : 0,
            PadHomeTheme.rightMargin(_laidOutWidth ?? 0),
            last ? PadHomeTheme.rowGap : 0,
          ),
          sliver: _cardGrid(grid, cards, from, to, going: from == 0 ? _going : null, still: still),
        ),
      );
    }

    if (divider == null) {
      batch(0, cards.length, first: true, last: true);
      return slivers;
    }
    batch(0, divider, first: true, last: false);
    slivers.add(
      SliverToBoxAdapter(
        child: FeedDivider(key: const ValueKey('feed-divider'), onTap: () => unawaited(reload())),
      ),
    );
    batch(divider, cards.length, first: false, last: true);
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    _scaler = MediaQuery.textScalerOf(context);
    final still = _still = MediaQuery.disableAnimationsOf(context);
    _ticking = TickerMode.valuesOf(context).enabled;
    // A route over 首页 (a page, a sheet, ⋮'s menu) or 我的 shown pauses the big card; the app leaving, its host.
    _inline.shown = _ticking && (ModalRoute.isCurrentOf(context) ?? true);
    // Under a dressed bar the feed runs to the screen's bottom; its end stays above the bar's row.
    final inset = _inset = MediaQuery.paddingOf(context).bottom;
    final pad = _pad = FormFactor.of(context).isPad;
    _rebuilt = true;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = BiliMetrics.feedSpacing;
        _viewport = constraints.biggest;
        final laidOut = _laidOut;
        if (!_rebuilt && laidOut != null && constraints.maxWidth == _laidOutWidth) return laidOut;
        _rebuilt = false;
        _laidOutWidth = constraints.maxWidth;
        final width = pad ? _columnWidth(constraints.maxWidth) : _bigWidth(constraints.maxWidth);
        final extent = pad ? _cardHeight(width) : FeedBigCardSize.height(width);
        _rowExtent = extent + _rowGap;
        final grid = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: pad ? PadHomeTheme.columns : 1,
          mainAxisSpacing: _rowGap,
          crossAxisSpacing: pad ? PadHomeTheme.gutter : spacing,
          mainAxisExtent: extent,
        );
        final cards = feed.cards;
        final divider = switch (feed.dividerAt) {
          final at? when at > 0 && at < cards.length => at,
          _ => null,
        };
        final loadingFirst = cards.isEmpty && (feed.loading || feed.error == null);
        // While 首页's tap holds its TV at the top, a pull draws and opens nothing: the refresh it would join is
        // already showing.
        final pull = ReleaseRefreshControl(
          refreshTriggerPullDistance: refreshTrigger,
          refreshIndicatorExtent: refreshRoom,
          builder: _reloadHeader ? null : loadingTvRefreshIndicator,
          onRefresh: _reloadHeader ? null : widget.onPull,
          onArmed: _reloadHeader ? null : widget.onPullArmed,
          onDisarmed: widget.onPullDisarmed,
        );
        return _laidOut = AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 320),
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: loadingFirst
              ? CustomScrollView(
                  key: const ValueKey('feed-skeleton'),
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: pad
                          ? EdgeInsets.fromLTRB(
                              PadHomeTheme.margin,
                              PadHomeTheme.firstRow,
                              PadHomeTheme.rightMargin(constraints.maxWidth),
                              PadHomeTheme.rowGap,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: FeedBigCardTheme.spacing,
                              vertical: FeedBigCardTheme.topGap,
                            ),
                      sliver: SliverGrid(
                        gridDelegate: grid,
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => FeedCardSkeleton(inline: !pad),
                          childCount: _skeletons,
                        ),
                      ),
                    ),
                  ],
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: _scrolled,
                  child: CustomScrollView(
                    key: const ValueKey('feed'),
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      pull,
                      SliverToBoxAdapter(
                        child: _Presence(
                          visible: _reloadHeader,
                          duration: still ? Duration.zero : HomeTabBarTheme.reloadHeader,
                          reverseDuration: still ? Duration.zero : HomeTabBarTheme.reloadCollapse,
                          reverseCurve: HomeTabBarTheme.reloadCollapseCurve,
                          builder: (context, animation) => SizeTransition(
                            sizeFactor: animation,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              key: const ValueKey('feed-reload'),
                              height: pull.refreshIndicatorExtent,
                              child: Center(child: RefreshLoading(room: pull.refreshIndicatorExtent)),
                            ),
                          ),
                        ),
                      ),
                      if (cards.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: inset),
                            child: Center(
                              child: _RetryMessage(
                                message: feed.error ?? FeedModel.emptyMessage,
                                messageKey: const ValueKey('feed-error'),
                                onRetry: widget.onRefresh,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        // Split where 刚刚看到这里 falls, so a page with an odd count leaves its last row half full.
                        ..._cardSlivers(grid, cards, divider, still: still),
                        SliverToBoxAdapter(child: _Footer(feed: feed)),
                        if (inset > 0) SliverToBoxAdapter(child: SizedBox(height: inset)),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// A card's first appearance: after [delay] it fades in and rises into place. Without a delay it just shows, as it
/// does when rebuilt or scrolled back into view.
class _Entrance extends StatefulWidget {
  const _Entrance({super.key, required this.delay, required this.child});

  final Duration? delay;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> with SingleTickerProviderStateMixin {
  static const _rise = Duration(milliseconds: 380);

  AnimationController? _controller;
  CurvedAnimation? _curve;
  Animation<Offset>? _offset;

  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay == null) return;
    final total = delay + _rise;
    final controller = AnimationController(vsync: this, duration: total);
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: Curves.easeOutCubic),
    );
    _controller = controller;
    _curve = curve;
    _offset = Tween(begin: const Offset(0, BiliMetrics.cardRise), end: Offset.zero).animate(curve);
    unawaited(controller.forward());
  }

  @override
  void dispose() {
    _curve?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    final offset = _offset;
    if (curve == null || offset == null) return widget.child;
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(position: offset, child: widget.child),
    );
  }
}

/// A grid slot in a refresh's hand-off: the card that was here ([going]) fades out over the new one, or the new one
/// fades in where there was none. Taps, VoiceOver and the cover's Hero belong to the new card alone. Outside a
/// hand-off ([incoming] null) it is just the card, in the same tree, so the card's state lives on when one ends.
class _HandOffSlot extends StatelessWidget {
  const _HandOffSlot({required this.incoming, required this.outgoing, required this.going, required this.child});

  final Animation<double>? incoming;
  final Animation<double> outgoing;
  final Widget? going;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final incoming = this.incoming;
    final going = this.going;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        FadeTransition(opacity: incoming != null && going == null ? incoming : kAlwaysCompleteAnimation, child: child),
        if (incoming != null && going != null)
          IgnorePointer(
            child: ExcludeSemantics(
              child: HeroMode(
                enabled: false,
                child: FadeTransition(opacity: outgoing, child: going),
              ),
            ),
          ),
      ],
    );
  }
}

/// Under the cards: the spinner while the next page loads, or why it didn't with 重试.
class _Footer extends StatelessWidget {
  const _Footer({required this.feed});

  final FeedModel feed;

  @override
  Widget build(BuildContext context) {
    final error = feed.error;
    return Padding(
      padding: const EdgeInsets.only(top: BiliMetrics.rowGap, bottom: BiliMetrics.sectionGap + BiliMetrics.rowGap),
      child: Center(
        child: error != null
            ? _RetryMessage(message: error, messageKey: const ValueKey('feed-error'), onRetry: feed.retry)
            : feed.exhausted
            ? _RetryMessage(message: FeedModel.endMessage, messageKey: const ValueKey('feed-end'), onRetry: feed.retry)
            : SizedBox.square(
                dimension: BiliMetrics.feedSpinnerRadius * 2,
                child: feed.loading
                    ? const CupertinoActivityIndicator(
                        key: ValueKey('feed-more'),
                        radius: BiliMetrics.feedSpinnerRadius,
                      )
                    : null,
              ),
      ),
    );
  }
}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage({required this.message, required this.messageKey, required this.onRetry});

  final String message;
  final Key messageKey;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(BiliMetrics.sectionGap),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          key: messageKey,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).secondaryText),
          strutStyle: BiliFonts.strutOf(context, const TextStyle(fontSize: BiliMetrics.bodyText)),
        ),
        const SizedBox(height: BiliMetrics.rowGap),
        CupertinoButton(
          key: const ValueKey('feed-retry'),
          onPressed: onRetry,
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(BiliMetrics.pillHeight),
          child: Container(
            height: BiliMetrics.pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.sectionGap),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: BiliColors.colorsOf(context).pink)),
            ),
            child: Text(
              '重试',
              style: TextStyle(fontSize: BiliMetrics.bodyText, color: BiliColors.colorsOf(context).pink),
            ),
          ),
        ),
      ],
    ),
  );
}
