import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../home/feed_model.dart' show requestFailureMessage;
import '../player_ui/end_screen_portrait.dart' show ShareLink, shareThroughSystem;
import '../search/results/video_row.dart' show searchLogReason;
import '../shared/loading_tv.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/actions/actions_model.dart' show ActionsModel;
import '../video/video_route.dart';
import 'space_api.dart';
import 'space_video_glyphs.dart';
import 'space_video_menu.dart';
import 'space_video_row.dart';

/// Opens a video from 投稿; the app pushes its page.
typedef OpenSpaceVideo = void Function(BuildContext context, VideoRoute route);

/// 投稿's list as slivers in the space's scroll view (63, 69, 70, 74): the chips (hidden when there's only 视频), 播放全部
/// and the sort, then the rows, a page at a time as the scroll nears the end.
///
/// One call is out at a time; a page that adds no row ends the list, and a failure waits for 重试, so nothing loops
/// against the account. Changing the chip or the sort starts again from the top: a call still out for the old list
/// is let finish and its answer dropped, then one call asks for the latest choice.
class SpaceVideosSliver extends StatefulWidget {
  const SpaceVideosSliver({
    super.key,
    required this.profile,
    required this.api,
    this.share = shareThroughSystem,
    this.open,
  });

  final SpaceProfile profile;
  final SpaceApi api;

  /// Hands 分享's link to the system share sheet; tests record it instead.
  final ShareLink share;

  /// Tests pass their own; null pushes the video page.
  final OpenSpaceVideo? open;

  static String orderLabel(SpaceOrder order) => switch (order) {
    SpaceOrder.latest => '最新发布',
    SpaceOrder.mostPlayed => '最多播放',
  };

  static const endMessage = '已经到底啦~';

  @override
  State<SpaceVideosSliver> createState() => _SpaceVideosSliverState();
}

class _SpaceVideosSliverState extends State<SpaceVideosSliver> {
  SpaceChip? _chip;
  SpaceOrder _order = SpaceOrder.latest;
  List<SpaceVideo> _items = const [];
  String? _next;
  bool _hasMore = true;
  bool _loading = false;

  /// The list started again while a call was out; its first page is asked for when that call answers.
  bool _restartPending = false;

  /// The list's first page has answered.
  bool _loaded = false;
  String? _error;

  /// Bumped whenever the list starts again, so an answer to the list before is dropped.
  int _generation = 0;

  ScrollPosition? _position;
  bool _checkQueued = false;
  final _adding = <int>{};

  /// The video whose page this list opened last: only its cover flies.
  String? _opening;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(SpaceVideosSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.mid != widget.profile.mid) {
      _generation++;
      _start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scrolled);
      _position = position?..addListener(_scrolled);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_scrolled);
    super.dispose();
  }

  List<SpaceChip> get _chips => widget.profile.chips;

  /// Compared by value: `SpaceChip` has no ==.
  static bool _sameChip(SpaceChip? a, SpaceChip? b) =>
      a != null &&
      b != null &&
      a.kind == b.kind &&
      a.title == b.title &&
      a.seasonId == b.seasonId &&
      a.seriesId == b.seriesId;

  bool get _showChips => _chips.any((chip) => chip.kind != SpaceChipKind.video);

  bool get _onVideos => _chip == null || _chip!.kind == SpaceChipKind.video;

  void _start() {
    final orders = widget.profile.orders;
    _chip = _chips.where((chip) => chip.kind == SpaceChipKind.video).firstOrNull;
    _order = orders.isEmpty ? SpaceOrder.latest : orders.first;
    _restart();
  }

  void _restart() {
    _generation++;
    _items = const [];
    _next = null;
    _hasMore = true;
    _loaded = false;
    _error = null;
    // Quick taps on the chips or the sort would otherwise put a signed call out per tap, which risks -352.
    if (_loading) {
      _restartPending = true;
    } else {
      _load();
    }
  }

  /// Asks for the next page; callers rebuild.
  void _load() {
    if (_loading) return;
    _loading = true;
    _error = null;
    unawaited(_fetch(_generation, _chip, _order, _next));
  }

  Future<void> _fetch(int generation, SpaceChip? chip, SpaceOrder order, String? next) async {
    final mid = widget.profile.mid;
    final SpaceVideoPage page;
    try {
      page = await (chip == null || chip.kind == SpaceChipKind.video
          ? widget.api.videos(mid, order: order, next: next)
          : widget.api.chipVideos(mid, chip, next: next));
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'space videos failed', {'error': searchLogReason(error)});
      if (_answered(generation)) setState(() => _error = requestFailureMessage(error));
      return;
    }
    if (!_answered(generation)) return;
    final seen = {for (final video in _items) video.aid};
    final fresh = [
      for (final video in page.items)
        if (seen.add(video.aid)) video,
    ];
    setState(() {
      _items = [..._items, ...fresh];
      _next = page.next;
      // A page that adds nothing ends the list, so an answer repeating itself can't keep it asking.
      _hasMore = page.hasMore && page.next != null && fresh.isNotEmpty;
      _loaded = true;
    });
    // A short page may leave the end in view, with no scroll to ask for the next.
    if (_hasMore) _checkAfterFrame();
  }

  /// Ends the call that was out, and says whether its answer belongs to the list shown. When the list started again
  /// meanwhile, the answer is dropped and the new list's first page asked for.
  bool _answered(int generation) {
    if (!mounted) return false;
    _loading = false;
    if (generation == _generation) return true;
    if (_restartPending) {
      _restartPending = false;
      setState(_load);
    }
    return false;
  }

  void _retry() => setState(_load);

  void _scrolled() {
    // A position can change mid-layout, where nothing may rebuild yet.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _checkAfterFrame();
    } else {
      _loadMoreNearEnd();
    }
  }

  void _checkAfterFrame() {
    if (_checkQueued) return;
    _checkQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (mounted) _loadMoreNearEnd();
    });
  }

  void _loadMoreNearEnd() {
    if (_loading || !_loaded || !_hasMore || _error != null) return;
    final position = _position;
    if (position == null || !position.hasContentDimensions || !position.hasPixels) return;
    if (position.extentAfter >= SpaceVideosTheme.loadAhead) return;
    setState(_load);
  }

  void _selectChip(SpaceChip chip) {
    if (chip.kind == SpaceChipKind.article || chip.kind == SpaceChipKind.other) {
      showToast(context, '暂未开放');
      return;
    }
    if (_sameChip(chip, _chip)) return;
    setState(() {
      _chip = chip;
      _restart();
    });
  }

  void _toggleOrder() {
    final orders = widget.profile.orders;
    if (orders.length < 2) return;
    final next = orders[(orders.indexOf(_order) + 1) % orders.length];
    setState(() {
      _order = next;
      _restart();
    });
  }

  void _open(SpaceVideo video) {
    final route = VideoRoute(bvid: video.bvid, title: video.title, cover: video.cover.isEmpty ? null : video.cover);
    final open = widget.open;
    if (open != null) {
      open(context, route);
      return;
    }
    // Kept after the page closes, so its cover can fly back into the row.
    setState(() => _opening = video.bvid);
    unawaited(openVideoPage(context, route));
  }

  void _playAll() {
    final first = _items.firstOrNull;
    if (first != null) _open(first);
  }

  Future<void> _more(SpaceVideo video, Rect anchor) async {
    final action = await Navigator.of(context)
        .push(SpaceVideoMenuRoute(anchor: anchor, reduceMotion: MediaQuery.disableAnimationsOf(context)));
    if (!mounted || action == null) return;
    switch (action) {
      case SpaceVideoAction.watchLater:
        await _watchLater(video);
      case SpaceVideoAction.share:
        await _share(video);
    }
  }

  /// Logged out it goes to the login page; an account still being checked tries, and goes there only if Bilibili
  /// answers that it needs a login.
  Future<void> _watchLater(SpaceVideo video) async {
    final services = AppScope.of(context);
    if (services.environment.account case LoggedOut() || LoginExpired()) {
      unawaited(services.loginGate.request(context));
      return;
    }
    if (!_adding.add(video.aid)) return;
    try {
      await services.pageApi.addToWatchLater(aid: video.aid);
      if (mounted) showToast(context, '已添加至稍后再看');
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'space watch later failed', {'error': searchLogReason(error)});
      if (!mounted) return;
      if (error is BiliError && error.needsLogin) {
        unawaited(services.loginGate.request(context));
      } else {
        showToast(context, ActionsModel.failureMessage(error));
      }
    } finally {
      _adding.remove(video.aid);
    }
  }

  Future<void> _share(SpaceVideo video) async {
    try {
      await widget.share(Uri.parse('https://www.bilibili.com/video/${video.bvid}'));
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'space share failed', {'error': searchLogReason(error)});
      if (mounted) showToast(context, '分享失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final error = _error;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              if (_showChips) _Chips(chips: _chips, isChosen: (chip) => _sameChip(chip, _chip), onTap: _selectChip),
              _Strip(
                order: _onVideos && widget.profile.orders.length > 1 ? _order : null,
                onPlayAll: _playAll,
                onSort: _toggleOrder,
              ),
            ],
          ),
        ),
        if (items.isNotEmpty) ...[
          SliverFixedExtentList.builder(
            itemExtent: SpaceVideoRow.height,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final video = items[index];
              return SpaceVideoRow(
                key: ValueKey('space-row-${video.bvid}'),
                video: video,
                hero: video.bvid == _opening,
                onOpen: () => _open(video),
                onMore: (anchor) => unawaited(_more(video, anchor)),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: SpaceVideosTheme.footerPad, bottom: SpaceVideosTheme.footerPad + bottom),
              child: Center(
                child: error != null
                    ? _Failure(message: error, onRetry: _retry)
                    : _loading
                    ? const SizedBox(
                        height: SpaceVideosTheme.footerLine,
                        child: CupertinoActivityIndicator(
                          key: ValueKey('space-more-spinner'),
                          radius: SpaceVideosTheme.spinnerRadius,
                        ),
                      )
                    : !_hasMore
                    ? const _End()
                    : const SizedBox(height: SpaceVideosTheme.footerLine),
              ),
            ),
          ),
        ] else
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: SpaceVideosTheme.stateTop, bottom: SpaceVideosTheme.stateTop + bottom),
              child: Center(
                child: error != null
                    ? _Failure(message: error, onRetry: _retry)
                    : _loaded
                    ? const _End()
                    : const LoadingTvState(key: ValueKey('space-videos-loading')),
              ),
            ),
          ),
      ],
    );
  }
}

/// The chips (69, 70): the chosen one pink on a pink tint, the others grey in a hairline rim; a long title is cut
/// with …. More than fit scroll sideways.
class _Chips extends StatelessWidget {
  const _Chips({required this.chips, required this.isChosen, required this.onTap});

  final List<SpaceChip> chips;
  final bool Function(SpaceChip chip) isChosen;
  final ValueChanged<SpaceChip> onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: SpaceVideosTheme.chipsBlock,
    child: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: SpaceVideosTheme.chipsTop),
        child: SizedBox(
          height: SpaceVideosTheme.chipHeight,
          // Its sideways scrolls are the chips' own, not the page's.
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) => true,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: SpaceVideosTheme.gutter),
              itemCount: chips.length,
              separatorBuilder: (context, index) => const SizedBox(width: SpaceVideosTheme.chipGap),
              itemBuilder: (context, index) {
                final chip = chips[index];
                return _Chip(
                  key: ValueKey('space-chip-$index'),
                  chip: chip,
                  chosen: isChosen(chip),
                  onTap: () => onTap(chip),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.chip, required this.chosen, required this.onTap});

  final SpaceChip chip;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = spaceVideosStyle(
      SpaceVideosTheme.chipText,
      chosen ? SpaceVideosTheme.colorsOf(context).chipChosenInk : SpaceVideosTheme.colorsOf(context).chipInk,
      line: SpaceVideosTheme.chipHeight,
    );
    return Semantics(
      button: true,
      selected: chosen,
      label: chip.title,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chosen ? SpaceVideosTheme.colorsOf(context).chipChosenFill : null,
            borderRadius: BorderRadius.circular(SpaceVideosTheme.chipRadius),
          ),
          child: Stack(
            children: [
              if (!chosen)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(SpaceVideosTheme.chipRimInset),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.fromBorderSide(
                          BorderSide(color: SpaceVideosTheme.colorsOf(context).chipRim, width: SpaceVideosTheme.chipRimWidth),
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(SpaceVideosTheme.chipRadius - SpaceVideosTheme.chipRimInset),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SpaceVideosTheme.chipPadX),
                child: Center(
                  widthFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: SpaceVideosTheme.chipMaxText),
                    child: Text(
                      chip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textWidthBasis: TextWidthBasis.longestLine,
                      style: style,
                      strutStyle: BiliFonts.strut(style),
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

/// 播放全部 on the left, the sort on the right when [order] is given (视频 only). Both sit on one line
/// [SpaceVideosTheme.stripCentre] down, a little below the strip's middle.
class _Strip extends StatelessWidget {
  const _Strip({required this.order, required this.onPlayAll, required this.onSort});

  final SpaceOrder? order;
  final VoidCallback onPlayAll;
  final VoidCallback onSort;

  static const _line = SpaceVideosTheme.stripCentre * 2;

  @override
  Widget build(BuildContext context) {
    final playAll = spaceVideosStyle(SpaceVideosTheme.playAllText, SpaceVideosTheme.colorsOf(context).playAllInk, line: _line);
    final sort = spaceVideosStyle(SpaceVideosTheme.sortText, SpaceVideosTheme.colorsOf(context).sortInk, line: _line);
    final order = this.order;
    return SizedBox(
      height: SpaceVideosTheme.stripHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            height: _line,
            child: Semantics(
              button: true,
              label: '播放全部',
              onTap: onPlayAll,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('space-play-all'),
                behavior: HitTestBehavior.opaque,
                onTap: onPlayAll,
                child: Row(
                  children: [
                    const SizedBox(width: SpaceVideosTheme.playAllRingLeft),
                    const PlayAllGlyph(),
                    const SizedBox(
                      width:
                          SpaceVideosTheme.playAllTextLeft -
                          SpaceVideosTheme.playAllRingLeft -
                          SpaceVideosTheme.playAllRing,
                    ),
                    Text('播放全部', maxLines: 1, style: playAll, strutStyle: BiliFonts.strut(playAll)),
                    const SizedBox(width: SpaceVideosTheme.gutter),
                  ],
                ),
              ),
            ),
          ),
          if (order != null)
            Positioned(
              right: 0,
              top: 0,
              height: _line,
              child: Semantics(
                button: true,
                label: '排序：${SpaceVideosSliver.orderLabel(order)}',
                onTap: onSort,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('space-sort'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onSort,
                  child: Row(
                    children: [
                      const SizedBox(width: SpaceVideosTheme.gutter),
                      const SortGlyph(),
                      const SizedBox(width: SpaceVideosTheme.sortGlyphGap),
                      Text(
                        SpaceVideosSliver.orderLabel(order),
                        key: const ValueKey('space-sort-label'),
                        maxLines: 1,
                        style: sort,
                        strutStyle: BiliFonts.strut(sort),
                      ),
                      const SizedBox(width: SpaceVideosTheme.sortRight),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 已经到底啦~, the list's end (as the uploader sheet's, 76).
class _End extends StatelessWidget {
  const _End();

  @override
  Widget build(BuildContext context) {
    final style = spaceVideosStyle(
      SpaceVideosTheme.endText,
      SpaceVideosTheme.colorsOf(context).endInk,
      line: SpaceVideosTheme.footerLine,
    );
    return Text(
      SpaceVideosSliver.endMessage,
      key: const ValueKey('space-videos-end'),
      maxLines: 1,
      style: style,
      strutStyle: BiliFonts.strut(style),
    );
  }
}

/// Why the list stopped, and 重试.
class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final style = spaceVideosStyle(SpaceVideosTheme.stateText, SpaceVideosTheme.colorsOf(context).stateInk);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, key: const ValueKey('space-videos-error'), textAlign: TextAlign.center, style: style),
        const SizedBox(height: SpaceVideosTheme.stateGap),
        _RetryPill(onTap: onRetry),
      ],
    );
  }
}

/// 重试's pink-rimmed pill, as 搜索's; it shrinks while pressed.
class _RetryPill extends StatefulWidget {
  const _RetryPill({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RetryPill> createState() => _RetryPillState();
}

class _RetryPillState extends State<_RetryPill> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '重试',
    onTap: widget.onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('space-videos-retry'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? SpaceVideosTheme.retryPressedScale : 1,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : SpaceVideosTheme.retryPressMotion,
        curve: Curves.easeOut,
        child: Container(
          height: SpaceVideosTheme.retryHeight,
          padding: const EdgeInsets.symmetric(horizontal: SpaceVideosTheme.retryPadX),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: BiliColors.colorsOf(context).pink, width: SpaceVideosTheme.retryRim),
            ),
          ),
          child: Text('重试', style: spaceVideosStyle(SpaceVideosTheme.retryText, BiliColors.colorsOf(context).pink)),
        ),
      ),
    ),
  );
}
