import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../skin/skin.dart';
import '../space_header.dart' show spaceStyle;
import '../space_header_tabs.dart';
import '../space_slivers.dart';
import '../uploader_tap.dart';
import 'own_bangumi_tab.dart';
import 'own_contribute_tab.dart';
import 'own_favourites_tab.dart';
import 'own_home_tab.dart';
import 'own_space_bar.dart';
import 'own_space_header.dart';

/// The account's own space (108, 114-117): the tall themed banner, 编辑资料, the level's exp, and 主页 / 投稿 / 收藏 /
/// 追番, collapsing to the bar with the tab row pinned (115).
class OwnSpacePage extends StatefulWidget {
  const OwnSpacePage({super.key, required this.uploader, this.skin, this.initialTab});

  final UploaderRef uploader;

  /// The tab to open on (关注's 我的追番 全部 › asks for 追番) when the space has it; otherwise its default.
  final SpaceTabKind? initialTab;

  /// The equipped 装扮 the bar follows; the app's when null.
  final ValueListenable<Skin?>? skin;

  @override
  State<OwnSpacePage> createState() => _OwnSpacePageState();
}

class _OwnSpacePageState extends State<OwnSpacePage> {
  static const _soon = '暂未开放';
  static const _kinds = {SpaceTabKind.home, SpaceTabKind.contribute, SpaceTabKind.favourite, SpaceTabKind.bangumi};

  /// Without the own call's extras 主页 would be an empty page and 追番 can only fail.
  static const _plainKinds = {SpaceTabKind.contribute, SpaceTabKind.favourite};

  final _scroll = ScrollController();

  SpaceProfile? _profile;
  SpaceFailure? _failure;
  SpaceTabKind _tab = SpaceTabKind.contribute;
  bool _collapsed = false;
  bool _started = false;

  /// 收藏's and 追番's lists, made on the first visit and kept while the page is open.
  OwnFolderPager? _folders;
  OwnBangumiPager? _bangumi;

  /// How far the space scrolls before the bar comes in, and where the tab row pins; set where the page is built.
  double _barAt = OwnSpaceHeader.nameCentre;
  double _pinnedAt = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrolled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _folders?.dispose();
    _bangumi?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The own space's call needs the app token; without one the space is asked as anyone's, without the extras.
  Future<void> _load() async {
    final api = AppScope.of(context).spaceApi;
    final mid = widget.uploader.mid;
    if (_failure != null) setState(() => _failure = null);
    try {
      SpaceProfile profile;
      try {
        profile = await api.ownProfile(mid);
        if (profile.own case final own?) _logSections(own);
      } on BiliNoAppTokenError {
        Logger.shared.info(LogCategory.api, 'own space without app token');
        profile = await api.profile(mid);
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        final tabs = _tabsOf(profile);
        final asked = widget.initialTab;
        _tab = asked != null && tabs.any((tab) => tab.kind == asked)
            ? asked
            : profile.own != null && tabs.any((tab) => tab.kind == profile.defaultTab)
            ? profile.defaultTab
            : SpaceTabKind.contribute;
      });
    } catch (error) {
      Logger.shared.warn(LogCategory.api, 'own space failed', {'error': spaceFailureReason(error)});
      if (mounted) setState(() => _failure = spaceFailureOf(error));
    }
  }

  /// What each 主页 section's key brought, counts only, so a key the answer renamed shows in the phone's log.
  static void _logSections(OwnSpace own) {
    String state(SpaceSection<Object?> section) => [
      section.count == 0 && section.items.isEmpty ? 'absent' : 'count ${section.count} items ${section.items.length}',
      if (section.dropped case final dropped?) 'dropped ($dropped)',
    ].join(' ');
    Logger.shared.info(LogCategory.api, 'own space sections', {
      'favourites': state(own.favourites),
      'bangumi': state(own.bangumi),
      'coins': state(own.coins),
      'likes': state(own.likes),
      'garbs': state(own.garbs),
      'garbTotal': own.garbTotal,
      'banner': own.banner != null,
      'bannerLabel': own.bannerLabel != null,
    });
  }

  /// 主页, 投稿, 收藏 and 追番 as the profile orders them, 投稿 added when it has none; without the extras only 投稿
  /// and 收藏.
  static List<SpaceTab> _tabsOf(SpaceProfile profile) {
    final kinds = profile.own == null ? _plainKinds : _kinds;
    return [
      ...profile.tabs.where((tab) => kinds.contains(tab.kind)),
      if (!profile.tabs.any((tab) => tab.kind == SpaceTabKind.contribute))
        const SpaceTab(kind: SpaceTabKind.contribute, title: '投稿'),
    ];
  }

  Future<bool> _authorize() async {
    if (!mounted) return false;
    return AppScope.of(context).appAuth.request(context);
  }

  /// The bar comes in once the name's line has passed under the status bar, as on others' spaces.
  void _scrolled() {
    if (!_scroll.hasClients) return;
    final collapsed = _scroll.offset >= _barAt;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  void _soonToast() => showToast(context, _soon);

  void _back() => unawaited(Navigator.of(context).maybePop());

  /// A tab chosen with the header scrolled away opens at its top, the tab row still pinned under the bar.
  void _select(SpaceTabKind kind) {
    if (kind == _tab || !_kinds.contains(kind)) return;
    if (_scroll.hasClients && _scroll.offset > _pinnedAt) _scroll.jumpTo(_pinnedAt);
    setState(() => _tab = kind);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin ?? AppScope.of(context).skin;
    return ValueListenableBuilder<Skin?>(
      valueListenable: skin,
      builder: (context, skin, _) => _page(OwnBarLook.of(skin, context: context)),
    );
  }

  Widget _page(OwnBarLook look) {
    final profile = _profile;
    final banner = profile?.own?.banner ?? profile?.banner;
    final collapsed = profile == null || _collapsed;
    // Light over a picture banner; over the default banner dark, and on the bar whatever its colour wants.
    final lightStatus = collapsed ? look.lightStatus : (banner != null && banner.isNotEmpty) || BiliPalette.of(context).isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightStatus ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
                child: OwnSpaceBar(
                  collapsed: collapsed,
                  name: profile?.name ?? widget.uploader.name ?? '',
                  look: look,
                  onBack: _back,
                  onSoon: _soonToast,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _space(SpaceProfile profile) {
    final top = MediaQuery.paddingOf(context).top;
    _barAt = OwnSpaceHeader.nameCentre - top;
    final barHeight = top + SpaceTheme.barRow;
    final headerHeight = OwnSpaceHeader.heightOf(profile);
    _pinnedAt = headerHeight - barHeight;
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: SpaceHeaderDelegate(
            min: barHeight,
            max: headerHeight,
            builder: (stretch) => OwnSpaceHeader(profile: profile, stretch: stretch, onSoon: _soonToast),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: SpaceTabsDelegate(
            SpaceTabRow(tabs: _tabsOf(profile), selected: _tab, onTap: (tab) => _select(tab.kind)),
          ),
        ),
        switch (_tab) {
          SpaceTabKind.home => OwnHomeSliver(key: const ValueKey('own-tab-home'), profile: profile, onMore: _select),
          SpaceTabKind.favourite => OwnFavouritesSliver(
            key: const ValueKey('own-tab-favourite'),
            pager: _folders ??= OwnFolderPager(
              api: AppScope.of(context).favouritesApi,
              mid: profile.mid,
              authorize: _authorize,
            ),
            count: _folderCount(profile),
          ),
          SpaceTabKind.bangumi => OwnBangumiSliver(
            key: const ValueKey('own-tab-bangumi'),
            pager: _bangumi ??= OwnBangumiPager(
              api: AppScope.of(context).spaceApi,
              mid: profile.mid,
              authorize: _authorize,
            ),
          ),
          _ => OwnContributeSliver(key: const ValueKey('own-tab-contribute'), profile: profile),
        },
        SpaceTailFiller(
          headerHeight: headerHeight,
          barHeight: barHeight,
          color: switch (_tab) {
            SpaceTabKind.home => OwnHomeSliver.fillOf(context),
            SpaceTabKind.favourite => OwnFavouritesSliver.fillOf(context),
            SpaceTabKind.bangumi => OwnBangumiSliver.fillOf(context),
            _ => OwnContributeSliver.fillOf(context),
          },
        ),
      ],
    );
  }

  /// Every account has 默认收藏夹, so a 0 means the answer left 收藏 out; the list then counts the folders itself.
  static int? _folderCount(SpaceProfile profile) => switch (profile.own?.favourites.count) {
    final count? when count > 0 => count,
    _ => null,
  };
}
