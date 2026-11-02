import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../../app/app_environment.dart';
import '../../app/app_scope.dart';
import '../../shared/loading_tv.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../video/actions/actions_model.dart' show ActionsModel;
import '../search_filters.dart';
import '../search_glyphs.dart';
import '../search_model.dart';
import 'filter_panel.dart';
import 'user_row.dart';
import 'video_row.dart';

/// The results under the field (56-61): the tab row with 筛选's funnel, then 综合's video rows or 用户's uploader
/// rows, paged as they scroll. 筛选 (58) opens over the rows below the tab row.
///
/// The tab row (with 用户's sort row) leaves as the rows scroll up and comes back as soon as they scroll down, as 57
/// shows it gone mid-list; each tab keeps its own place.
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.model,
    required this.onOpenVideo,
    required this.onOpenUser,
    required this.onMore,
    this.filterOpen,
  });

  final SearchModel model;

  /// Whether 筛选 is open, shared with the page so back closes it first; the view keeps its own without one.
  final ValueNotifier<bool>? filterOpen;
  final ValueChanged<SearchVideo> onOpenVideo;
  final ValueChanged<SearchUser> onOpenUser;

  /// A video row's ⋮: the page shows [ResultMoreSheet] over everything.
  final ValueChanged<SearchVideo> onMore;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> with TickerProviderStateMixin {
  final _scrolls = {for (final tab in SearchTab.values) tab: ScrollController()};

  /// How far the header has gone up behind the field.
  double _shift = 0;

  /// Carries [_shift] the rest of the way in or out once a scroll stops with the header part shown.
  late final AnimationController _snap = AnimationController(vsync: this, duration: SearchResultTheme.headerSnap)
    ..addListener(_snapped);
  double _snapFrom = 0;
  double _snapTo = 0;

  ValueNotifier<bool>? _ownFilterOpen;
  late ValueNotifier<bool> _filterOpenNotifier;
  bool _filterOpen = false;

  /// Uploaders whose 关注 call is out: a press meanwhile is ignored, so a rollback can't leave the wrong state.
  final _followsOut = <int>{};
  late final AnimationController _filter = AnimationController(vsync: this, duration: SearchResultTheme.filterMotion);
  late final CurvedAnimation _filterCurve = CurvedAnimation(
    parent: _filter,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late String _keyword;
  late int _searches;
  late SearchFilters _filters;
  late SearchTab _tab;

  SearchModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    _remember();
    _model.addListener(_changed);
    _filterOpenNotifier = widget.filterOpen ?? (_ownFilterOpen = ValueNotifier(false));
    _filterOpen = _filterOpenNotifier.value;
    if (_filterOpen) _filter.value = 1;
    _filterOpenNotifier.addListener(_filterNotified);
    _filter.addStatusListener((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.model, widget.model)) {
      oldWidget.model.removeListener(_changed);
      widget.model.addListener(_changed);
      _remember();
    }
    if (!identical(oldWidget.filterOpen, widget.filterOpen)) {
      _filterOpenNotifier.removeListener(_filterNotified);
      _ownFilterOpen?.dispose();
      _ownFilterOpen = null;
      _filterOpenNotifier = widget.filterOpen ?? (_ownFilterOpen = ValueNotifier(_filterOpen));
      _filterOpenNotifier.addListener(_filterNotified);
      _filterNotified();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _filter
      ..duration = still ? Duration.zero : SearchResultTheme.filterMotion
      ..reverseDuration = still ? Duration.zero : SearchResultTheme.filterMotion;
    _snap.duration = still ? Duration.zero : SearchResultTheme.headerSnap;
  }

  @override
  void dispose() {
    _model.removeListener(_changed);
    _filterOpenNotifier.removeListener(_filterNotified);
    _ownFilterOpen?.dispose();
    for (final scroll in _scrolls.values) {
      scroll.dispose();
    }
    _snap.dispose();
    _filterCurve.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _remember() {
    _keyword = _model.keyword;
    _searches = _model.searches;
    _filters = _model.filters;
    _tab = _model.tab;
  }

  void _changed() {
    if (!mounted) return;
    final model = _model;
    // A search, the same word again included, or 筛选 changed, starts from the top.
    if (model.keyword != _keyword || model.searches != _searches) {
      for (final scroll in _scrolls.values) {
        _toTop(scroll);
      }
      _showHeader();
    } else if (model.filters != _filters) {
      _toTop(_scrolls[SearchTab.all]!);
      _showHeader();
    }
    if (model.tab != _tab) {
      _showHeader();
      if (model.tab != SearchTab.all) _setFilter(false);
    }
    _remember();
    setState(() {});
    // A first page too short to scroll leaves its end on screen with no scrolling to notice it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scroll = _scrolls[_model.tab]!;
      if (mounted && scroll.hasClients) _loadMoreNearEnd(scroll.position);
    });
  }

  static void _toTop(ScrollController scroll) {
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void _showHeader() {
    _snap.stop();
    _shift = 0;
  }

  void _snapped() => setState(() => _shift = _snapFrom + (_snapTo - _snapFrom) * Curves.easeOut.transform(_snap.value));

  /// A scroll that stops with the header part shown carries it on to whichever end is nearer. While the rows' top is
  /// still under the header, it moves with them, so it stays.
  void _settleHeader(SearchTab tab, ScrollMetrics metrics) {
    final height = _headerHeight(tab);
    if (_shift <= 0 || _shift >= height || metrics.pixels < height) return;
    _snapFrom = _shift;
    _snapTo = _shift * 2 < height ? 0 : height;
    if (_snap.duration == Duration.zero) {
      setState(() => _shift = _snapTo);
    } else {
      unawaited(_snap.forward(from: 0));
    }
  }

  SearchResults<Object> get _current => _model.tab == SearchTab.all ? _model.videos : _model.users;

  static double _headerHeight(SearchTab tab) =>
      SearchResultTheme.tabRowHeight +
      (tab == SearchTab.users ? SearchResultTheme.sortRowHeight : 0) +
      SearchResultTheme.hairline;

  bool _scrolled(SearchTab tab, ScrollNotification notification) {
    if (notification.depth != 0 || tab != _model.tab) return false;
    final metrics = notification.metrics;
    // The bounce back from past the end isn't the user scrolling down, so it doesn't bring the header back.
    final bouncing = metrics.hasContentDimensions && metrics.pixels > metrics.maxScrollExtent;
    if (notification is ScrollUpdateNotification && !_filterOpen && !bouncing) {
      _snap.stop();
      final delta = notification.scrollDelta ?? 0;
      final height = _headerHeight(tab);
      final pixels = metrics.pixels.clamp(0.0, double.infinity);
      final next = (_shift + delta).clamp(0.0, height).clamp(0.0, pixels);
      if (next != _shift) setState(() => _shift = next);
    }
    if (notification is ScrollEndNotification && !_filterOpen) _settleHeader(tab, metrics);
    _loadMoreNearEnd(metrics);
    return false;
  }

  void _loadMoreNearEnd(ScrollMetrics metrics) {
    if (!_current.canLoadMore || !metrics.hasContentDimensions) return;
    if (metrics.extentAfter >= SearchResultTheme.loadAhead) return;
    // A scroll notification can come mid-layout, where the model's change must not rebuild anything yet.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _current.canLoadMore) unawaited(_model.loadMore());
      });
    } else {
      unawaited(_model.loadMore());
    }
  }

  void _setFilter(bool open) {
    if (_filterOpen == open) return;
    _filterOpen = open;
    _filterOpenNotifier.value = open;
    if (open) {
      _showHeader();
      unawaited(_filter.forward());
    } else {
      unawaited(_filter.reverse());
    }
  }

  /// The page opened or closed 筛选 (back closes it).
  void _filterNotified() {
    final open = _filterOpenNotifier.value;
    if (open != _filterOpen && mounted) setState(() => _setFilter(open));
  }

  void _toggleFilter() => setState(() => _setFilter(!_filterOpen));

  /// Logged out it asks for a login and changes nothing; otherwise the pill turns at once and turns back with a toast
  /// if Bilibili refuses.
  Future<void> _follow(SearchUser user) async {
    final services = AppScope.of(context);
    if (services.environment.account case LoggedOut() || LoginExpired()) {
      await services.loginGate.request(context);
      return;
    }
    if (!_followsOut.add(user.mid)) return;
    final on = !user.following;
    _model.setFollowing(user.mid, following: on);
    try {
      await services.pageApi.follow(mid: user.mid, on: on);
    } catch (error) {
      _model.setFollowing(user.mid, following: !on);
      if (error is BiliError && error.needsLogin) {
        if (mounted) await services.loginGate.request(context);
        return;
      }
      Logger.shared.warn(LogCategory.ui, 'search follow failed', {'error': searchLogReason(error)});
      if (mounted) showToast(context, ActionsModel.failureMessage(error));
    } finally {
      _followsOut.remove(user.mid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final tab = model.tab;
    final header = _headerHeight(tab);
    const filterTop = SearchResultTheme.tabRowHeight + SearchResultTheme.hairline;
    final now = DateTime.now();
    return ColoredBox(
      color: SearchResultTheme.colorsOf(context).page,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              // While 筛选 is open the rows under its dim are out of reach, for VoiceOver too; the field row and the
              // tab row stay pressable.
              child: ExcludeSemantics(
                excluding: _filterOpen,
                child: IndexedStack(
                  index: tab.index,
                  children: [
                    // A hidden tab's first-page TV would otherwise tick on behind the shown one, a frame at a time.
                    TickerMode(
                      enabled: tab == SearchTab.all,
                      child:
                        _ResultList<SearchVideo>(
                          key: const ValueKey('search-list-all'),
                          scroll: _scrolls[SearchTab.all]!,
                          top: _headerHeight(SearchTab.all),
                          results: model.videos,
                          onScroll: (notification) => _scrolled(SearchTab.all, notification),
                          onRetry: model.retry,
                          onLoadMore: model.loadMore,
                          extent: SearchVideoRow.height,
                          row: (video) => SearchVideoRow(
                            key: ValueKey('search-row-${video.bvid}'),
                            video: video,
                            now: now,
                            onOpen: () => widget.onOpenVideo(video),
                            onMore: () => widget.onMore(video),
                          ),
                        ),
                    ),
                    TickerMode(
                      enabled: tab == SearchTab.users,
                      child:
                        _ResultList<SearchUser>(
                          key: const ValueKey('search-list-users'),
                          scroll: _scrolls[SearchTab.users]!,
                          top: _headerHeight(SearchTab.users),
                          results: model.users,
                          onScroll: (notification) => _scrolled(SearchTab.users, notification),
                          onRetry: model.retry,
                          onLoadMore: model.loadMore,
                          extent: SearchUserRow.height,
                          row: (user) => SearchUserRow(
                            key: ValueKey('search-row-user-${user.mid}'),
                            user: user,
                            onOpen: () => widget.onOpenUser(user),
                            onFollow: () => unawaited(_follow(user)),
                          ),
                        ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_filter.isDismissed)
              Positioned(
                left: 0,
                right: 0,
                top: filterTop,
                bottom: 0,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        label: '关闭筛选',
                        onTap: _filterOpen ? _toggleFilter : null,
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: const ValueKey('search-filter-dim'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _filterOpen ? _toggleFilter : null,
                          child: FadeTransition(
                            opacity: _filterCurve,
                            child: ColoredBox(color: SearchResultTheme.filterDim),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: IgnorePointer(
                        ignoring: !_filterOpen,
                        child: SizeTransition(
                          sizeFactor: _filterCurve,
                          alignment: Alignment.bottomCenter,
                          child: SearchFilterPanel(filters: model.filters, onChanged: model.setFilters),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!model.awaitingFirstPage)
              Positioned(
                left: 0,
                right: 0,
                top: -_shift,
                height: header,
                child: _Header(
                  tab: tab,
                  filterOpen: _filterOpen,
                  onTab: (next) {
                    if (next != tab) model.selectTab(next);
                  },
                  onFilter: _toggleFilter,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One tab's rows under the header's room, with the first page's loading TV, 没有找到相关内容, the failure with 重试, and
/// the next page's spinner, failure or 加载更多 at the end.
class _ResultList<T> extends StatelessWidget {
  const _ResultList({
    super.key,
    required this.scroll,
    required this.top,
    required this.results,
    required this.onScroll,
    required this.onRetry,
    required this.onLoadMore,
    required this.extent,
    required this.row,
  });

  final ScrollController scroll;
  final double top;
  final SearchResults<T> results;
  final bool Function(ScrollNotification notification) onScroll;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLoadMore;
  final double extent;
  final Widget Function(T item) row;

  @override
  Widget build(BuildContext context) {
    final items = results.items;
    final error = results.error;
    final Widget body;
    if (items.isNotEmpty) {
      body = SliverFixedExtentList(
        itemExtent: extent,
        delegate: SliverChildBuilderDelegate((context, index) => row(items[index]), childCount: items.length),
      );
    } else if (error != null) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: _Failure(message: error, onRetry: onRetry),
        ),
      );
    } else if (results.stalled) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: _Stalled(onLoadMore: onLoadMore)),
      );
    } else if (results.isEmpty) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            '没有找到相关内容',
            key: const ValueKey('search-empty'),
            style: searchStyle(SearchResultTheme.stateText, SearchResultTheme.colorsOf(context).stateInk),
          ),
        ),
      );
    } else {
      // Measured from the field row, not the tab row: 67 has none yet while the first page loads.
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: math.max(0, LoadingTvTheme.stateTop - top)),
            child: LoadingTvState(key: ValueKey('search-first-load')),
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: CustomScrollView(
        controller: scroll,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: top)),
          body,
          if (items.isNotEmpty)
            SliverToBoxAdapter(
              child: _Footer(results: results, onRetry: onRetry, onLoadMore: onLoadMore),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.results, required this.onRetry, required this.onLoadMore});

  final SearchResults<Object?> results;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final error = results.error;
    return Padding(
      padding: EdgeInsets.only(
        top: SearchResultTheme.footerPad,
        bottom: SearchResultTheme.footerPad + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        child: error != null
            ? _Failure(message: error, onRetry: onRetry)
            : results.stalled
            ? _Pill(key: const ValueKey('search-load-more'), label: '加载更多', onTap: onLoadMore)
            : SizedBox.square(
                dimension: SearchResultTheme.spinnerRadius * 2,
                child: results.loading
                    ? const CupertinoActivityIndicator(
                        key: ValueKey('search-more-spinner'),
                        radius: SearchResultTheme.spinnerRadius,
                      )
                    : null,
              ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        message,
        key: const ValueKey('search-error'),
        textAlign: TextAlign.center,
        style: searchStyle(SearchResultTheme.stateText, SearchResultTheme.colorsOf(context).stateInk),
      ),
      const SizedBox(height: SearchResultTheme.stateGap),
      _Pill(key: const ValueKey('search-retry'), label: '重试', onTap: onRetry),
    ],
  );
}

/// A load whose pages added no row: nothing more is asked for until the user asks.
class _Stalled extends StatelessWidget {
  const _Stalled({required this.onLoadMore});

  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '没有找到相关内容',
        key: const ValueKey('search-empty'),
        style: searchStyle(SearchResultTheme.stateText, SearchResultTheme.colorsOf(context).stateInk),
      ),
      const SizedBox(height: SearchResultTheme.stateGap),
      _Pill(key: const ValueKey('search-load-more'), label: '加载更多', onTap: onLoadMore),
    ],
  );
}

/// 重试's pink-rimmed pill, also 加载更多; it shrinks while pressed, as 关注 does.
class _Pill extends StatefulWidget {
  const _Pill({super.key, required this.label, required this.onTap});

  final String label;
  final Future<void> Function() onTap;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  void _tap() => unawaited(widget.onTap());

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.label,
      onTap: _tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: _tap,
        child: AnimatedScale(
          scale: _pressed ? SearchResultTheme.followPressedScale : 1,
          duration: still ? Duration.zero : SearchResultTheme.followPressMotion,
          curve: Curves.easeOut,
          child: Container(
            height: SearchResultTheme.retryHeight,
            padding: const EdgeInsets.symmetric(horizontal: SearchResultTheme.retryPadX),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(color: BiliColors.colorsOf(context).pink, width: SearchResultTheme.retryRim),
              ),
            ),
            child: Text(widget.label, style: searchStyle(SearchResultTheme.retryText, BiliColors.colorsOf(context).pink)),
          ),
        ),
      ),
    );
  }
}

/// The tab row and, on 用户, its sort row, on the page's white.
class _Header extends StatelessWidget {
  const _Header({required this.tab, required this.filterOpen, required this.onTab, required this.onFilter});

  final SearchTab tab;
  final bool filterOpen;
  final ValueChanged<SearchTab> onTab;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SearchResultTheme.colorsOf(context).page,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: SearchResultTheme.tabRowHeight,
          child: Stack(
            children: [
              Row(
                children: [
                  for (final each in SearchTab.values) _Tab(tab: each, selected: each == tab, onTap: () => onTab(each)),
                ],
              ),
              if (tab == SearchTab.all)
                Positioned(
                  right: SearchResultTheme.funnelCentreRight - SearchResultTheme.funnelTarget / 2,
                  width: SearchResultTheme.funnelTarget,
                  top: SearchResultTheme.funnelCentreTop - SearchResultTheme.funnelTarget / 2,
                  height: SearchResultTheme.funnelTarget,
                  child: Semantics(
                    button: true,
                    selected: filterOpen,
                    label: '筛选',
                    onTap: onFilter,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const ValueKey('search-filter'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onFilter,
                      child: Center(
                        child: SearchGlyphIcon(
                          SearchGlyph.funnel,
                          size: SearchResultTheme.funnel,
                          color: filterOpen ? SearchResultTheme.colorsOf(context).funnelOpen : SearchResultTheme.colorsOf(context).funnelInk,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (tab == SearchTab.users) const _SortRow(),
        SizedBox(
          height: SearchResultTheme.hairline,
          child: ColoredBox(color: SearchResultTheme.colorsOf(context).hairlineInk),
        ),
      ],
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.selected, required this.onTap});

  final SearchTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : SearchResultTheme.tabMotion;
    final style = searchStyle(
      selected ? SearchResultTheme.tabSelectedText : SearchResultTheme.tabText,
      selected ? SearchResultTheme.colorsOf(context).tabSelected : SearchResultTheme.colorsOf(context).tabInk,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('search-tab-${tab.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: SearchResultTheme.tabSlot,
          height: SearchResultTheme.tabRowHeight,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Baseline(
                  baseline: SearchResultTheme.tabBaseline,
                  baselineType: TextBaseline.alphabetic,
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOut,
                    style: style,
                    child: Text(tab.label, maxLines: 1, softWrap: false),
                  ),
                ),
              ),
              Positioned(
                top: SearchResultTheme.indicatorTop,
                left: (SearchResultTheme.tabSlot - SearchResultTheme.indicatorWidth) / 2,
                width: SearchResultTheme.indicatorWidth,
                height: SearchResultTheme.indicatorHeight,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: duration,
                  child: DecoratedBox(
                    key: selected ? const ValueKey('search-tab-indicator') : null,
                    decoration: BoxDecoration(
                      color: SearchResultTheme.colorsOf(context).tabSelected,
                      borderRadius: BorderRadius.circular(SearchResultTheme.indicatorHeight / 2),
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

/// 用户's 默认排序 ⌄ and 全部用户 ⌄ (60), not built yet; both toast 暂未开放.
class _SortRow extends StatelessWidget {
  const _SortRow();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: SearchResultTheme.sortRowHeight,
    child: Row(
      children: [
        for (final label in const ['默认排序', '全部用户'])
          Expanded(
            child: Semantics(
              button: true,
              label: label,
              onTap: () => showToast(context, '暂未开放'),
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('search-sort-$label'),
                behavior: HitTestBehavior.opaque,
                onTap: () => showToast(context, '暂未开放'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: searchStyle(SearchResultTheme.sortText, SearchResultTheme.colorsOf(context).sortInk)),
                    const SizedBox(width: SearchResultTheme.sortChevronGap),
                    CustomPaint(
                      size: Size(SearchResultTheme.sortChevronWidth, SearchResultTheme.sortChevronHeight),
                      painter: _ChevronPainter(palette: BiliPalette.of(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  final BiliPalette palette;

  const _ChevronPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = SearchResultTheme.sortChevronStroke / 2;
    final path = Path()
      ..moveTo(inset, inset)
      ..lineTo(size.width / 2, size.height - inset)
      ..lineTo(size.width - inset, inset);
    canvas.drawPath(
      path,
      Paint()
        ..color = SearchResultThemeColors(palette).sortInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = SearchResultTheme.sortChevronStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
