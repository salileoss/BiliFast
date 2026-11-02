import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart' show ValueListenable, precisionErrorTolerance;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/app_environment.dart' show LoggedIn;
import '../app/app_scope.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import 'space_bar.dart';
import 'space_dynamics.dart';
import 'space_follow.dart';
import 'space_header.dart';
import 'space_header_tabs.dart';
import 'space_slivers.dart';
import 'space_unfollow_sheet.dart';
import 'space_videos.dart';
import 'uploader_tap.dart';

/// UP主空间 (63, 69-75, 77, 136): the header over 投稿 or 动态, collapsing to a white bar with the tab row pinned under
/// it.
class SpacePage extends StatefulWidget {
  const SpacePage({super.key, required this.uploader});

  final UploaderRef uploader;

  @override
  State<SpacePage> createState() => _SpacePageState();
}

class _SpacePageState extends State<SpacePage> {
  static const _soon = '暂未开放';

  /// The tabs built; the others toast.
  static const _built = {SpaceTabKind.contribute, SpaceTabKind.dynamic};

  /// A scroll view per tab opened, each kept while the page is open, so a tab switched away and back is as it was
  /// left: its list, 投稿's chip and sort, and how far down it was.
  final _scrolls = <SpaceTabKind, ScrollController>{};
  final _sheet = ValueNotifier(false);

  SpaceTabKind _tab = SpaceTabKind.contribute;
  SpaceDynamicsPager? _dynamics;
  SpaceProfile? _profile;
  SpaceFailure? _failure;
  SpaceFollow? _follow;
  ValueListenable<int>? _logins;
  bool _collapsed = false;

  /// How far the space scrolls before the bar comes in, and where the tab row pins; set where the page is built.
  double _barAt = SpaceHeader.nameCentre;
  double _pinnedAt = 0;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_sheetChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_follow != null) return;
    final services = AppScope.of(context);
    final environment = services.environment;
    _follow = SpaceFollow(
      mid: widget.uploader.mid,
      api: services.pageApi,
      book: services.follows,
      isLoggedIn: () => environment.account is LoggedIn,
      requestLogin: () => unawaited(_requestLogin()),
      toast: (message) => showToast(context, message),
    )..addListener(_followChanged);
    _logins = environment.logins..addListener(_loggedIn);
    unawaited(_follow!.load());
    unawaited(_load());
  }

  @override
  void dispose() {
    _logins?.removeListener(_loggedIn);
    for (final scroll in _scrolls.values) {
      scroll.dispose();
    }
    _dynamics?.dispose();
    _sheet.dispose();
    _follow?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).spaceApi;
    if (_failure != null) setState(() => _failure = null);
    try {
      final profile = await api.profile(widget.uploader.mid);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _tab = _openingTab(profile);
        if (!_scrolls.containsKey(_tab)) _openScroll(_tab, 0);
      });
    } catch (error) {
      Logger.shared.warn(LogCategory.api, 'space failed', {'error': spaceFailureReason(error)});
      if (mounted) setState(() => _failure = spaceFailureOf(error));
    }
  }

  /// A login the environment's `logins` heard is followed there; a gate answering logged in without one still has
  /// the 关注 state asked again.
  Future<void> _requestLogin() async {
    final services = AppScope.of(context);
    final logins = services.environment.logins.value;
    final loggedIn = await services.loginGate.request(context);
    if (loggedIn && mounted && services.environment.logins.value == logins) _loggedIn();
  }

  /// The new account's 关注 for this uploader.
  void _loggedIn() => unawaited(_follow?.reload());

  void _followChanged() {
    if (mounted) setState(() {});
  }

  void _sheetChanged() {
    if (mounted) setState(() {});
  }

  /// The uploader's default tab when it is built and in the row, else 投稿.
  static SpaceTabKind _openingTab(SpaceProfile profile) {
    final kind = profile.defaultTab;
    return _built.contains(kind) && SpaceTabRow.of(profile).any((tab) => tab.kind == kind)
        ? kind
        : SpaceTabKind.contribute;
  }

  void _openScroll(SpaceTabKind kind, double at) =>
      _scrolls[kind] = ScrollController(initialScrollOffset: at)..addListener(() => _scrolled(kind));

  /// The bar comes in once the name's line has passed under the status bar (77).
  void _scrolled(SpaceTabKind kind) {
    final scroll = _scrolls[kind];
    if (kind != _tab || scroll == null || !scroll.hasClients) return;
    final collapsed = scroll.offset >= _barAt;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  void _soonToast() => showToast(context, _soon);

  void _back() => unawaited(Navigator.of(context).maybePop());

  bool get _following => _follow?.following ?? false;

  void _tapFollow() {
    if (_following) {
      _sheet.value = true;
    } else {
      unawaited(_follow!.toggle());
    }
  }

  void _unfollow() => unawaited(_follow!.toggle());

  void _tapTab(SpaceTab tab) {
    if (!_built.contains(tab.kind)) {
      _soonToast();
    } else if (tab.kind != _tab) {
      _select(tab.kind);
    }
  }

  /// The header shows the same in either tab. Shown in part, the other tab shows as much of it, its list from the
  /// top; scrolled away, the other tab is where it was left, at least at its list's top under the pinned row.
  void _select(SpaceTabKind kind) {
    final from = _scrolls[_tab];
    final offset = from != null && from.hasClients ? from.offset : 0.0;
    final header = offset.clamp(0.0, _pinnedAt);
    // A short list's end is the pinned row's place, give or take the rounding of the extents summed to it.
    final pinned = offset >= _pinnedAt - precisionErrorTolerance;
    final to = _scrolls[kind];
    if (to == null) {
      _openScroll(kind, header);
    } else if (to.hasClients) {
      to.jumpTo(pinned ? math.max(to.offset, _pinnedAt) : header);
    }
    setState(() => _tab = kind);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    // Light over a picture banner, as 72; dark over the default banner (63) and the white bar.
    final darkStatus = !BiliPalette.of(context).isDark && (profile == null || _collapsed || (profile.banner?.isEmpty ?? true));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatus ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: PopScope<Object?>(
        canPop: !_sheet.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _sheet.value = false;
        },
        // Pushed on a plain route with no Material above it, text would otherwise take the app's fallback style.
        child: DefaultTextStyle(
          style: spaceStyle(SpaceTheme.bioText, BiliColors.colorsOf(context).text),
          child: ColoredBox(
            color: SpaceTheme.colorsOf(context).page,
            child: Stack(
              children: [
                Positioned.fill(
                  child: profile == null
                      ? SpaceWaiting(failure: _failure, onRetry: () => unawaited(_load()))
                      : _space(profile),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: profile == null
                      ? SpaceBar(
                          collapsed: true,
                          face: widget.uploader.face,
                          name: widget.uploader.name ?? '',
                          onBack: _back,
                          onSoon: _soonToast,
                        )
                      : SpaceBar(
                          collapsed: _collapsed,
                          face: profile.face.isEmpty ? widget.uploader.face : profile.face,
                          following: _following,
                          onFollow: _tapFollow,
                          onBack: _back,
                          onSoon: _soonToast,
                        ),
                ),
                Positioned.fill(
                  child: SpaceUnfollowSheet(open: _sheet, onUnfollow: _unfollow, onSoon: _soonToast),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _space(SpaceProfile profile) {
    final top = MediaQuery.paddingOf(context).top;
    _barAt = SpaceHeader.nameCentre - top;
    final barHeight = top + SpaceTheme.barRow;
    final headerHeight = SpaceHeader.heightOf(profile);
    _pinnedAt = headerHeight - barHeight;
    return Stack(
      children: [
        for (final MapEntry(key: kind, value: scroll) in _scrolls.entries)
          Positioned.fill(
            key: ValueKey('space-view-${kind.name}'),
            // Kept while another tab shows: not drawn, not touched, its animations and Heroes off.
            child: Visibility(
              visible: kind == _tab,
              maintainState: true,
              child: HeroMode(
                enabled: kind == _tab,
                child: _view(profile, kind, scroll, headerHeight: headerHeight, barHeight: barHeight),
              ),
            ),
          ),
      ],
    );
  }

  Widget _view(
    SpaceProfile profile,
    SpaceTabKind kind,
    ScrollController scroll, {
    required double headerHeight,
    required double barHeight,
  }) {
    final following = _following;
    final dynamics = kind == SpaceTabKind.dynamic;
    return CustomScrollView(
      controller: scroll,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: SpaceHeaderDelegate(
            min: barHeight,
            max: headerHeight,
            builder: (stretch) => SpaceHeader(
              profile: profile,
              following: following,
              stretch: stretch,
              onFollow: _tapFollow,
              onFollowed: _tapFollow,
              onSoon: _soonToast,
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: SpaceTabsDelegate(SpaceTabRow(tabs: SpaceTabRow.of(profile), selected: _tab, onTap: _tapTab)),
        ),
        if (dynamics)
          SpaceDynamicsSliver(
            pager: _dynamics ??= SpaceDynamicsPager(api: AppScope.of(context).dynamicApi, mid: profile.mid),
          )
        else
          SpaceVideosSliver(profile: profile, api: AppScope.of(context).spaceApi),
        SpaceTailFiller(
          headerHeight: headerHeight,
          barHeight: barHeight,
          color: dynamics ? SpaceDynamicsSliver.fillOf(context) : null,
        ),
      ],
    );
  }
}
