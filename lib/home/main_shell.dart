import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_scope.dart';
import '../app/app_environment.dart';
import '../dynamic/follow_tab/face_sheet.dart';
import '../dynamic/follow_tab/follow_tab_page.dart';
import '../me/me_page.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../skin/skin.dart';
import '../skin/skin_model.dart';
import 'home_page.dart';
import 'home_tab_bar.dart';

/// The bottom bar's places: 首页, 关注 and 我的 kept alive side by side, the bar under them (01, 02, 127). A bar dressed
/// by the equipped 装扮 lies over the pages' bottom instead, so they show behind its picture (109, 110). 关注's face
/// sheet lies over everything, the bar included (139).
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.developerPage, this.initialLink, @visibleForTesting this.skin});

  final WidgetBuilder? developerPage;

  /// Passed to 首页 (`--play=` on the PC).
  final String? initialLink;

  /// The equipped 装扮 in place of [AppServices.skin], for 首页, the bar and 我的 alike.
  final SkinModel? skin;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _reloads = _Reloads();
  final _followReloads = _Reloads();
  final _faceSheet = FaceSheetController();
  HomeTab _tab = HomeTab.home;
  AppEnvironment? _environment;
  int _session = 0;
  bool _initialLink = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final environment = AppScope.of(context).environment;
    if (identical(_environment, environment)) return;
    _environment?.sessions.removeListener(_sessionChanged);
    _environment = environment;
    _session = environment.sessionGeneration;
    environment.sessions.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted) return;
    _faceSheet.close();
    setState(() {
      _session = _environment!.sessionGeneration;
      _tab = HomeTab.mine;
      _initialLink = false;
    });
  }

  @override
  void dispose() {
    _environment?.sessions.removeListener(_sessionChanged);
    _reloads.dispose();
    _followReloads.dispose();
    _faceSheet.dispose();
    super.dispose();
  }

  /// 首页 again on 首页 refreshes 推荐, and 关注 again on 关注 its list, closing the face sheet first (a guess: no
  /// recording); coming back from another place only shows it, where it was.
  void _tapped(HomeTab tab) {
    switch (tab) {
      case HomeTab.home when _tab == HomeTab.home:
        _reloads.request();
      case HomeTab.follow when _tab == HomeTab.follow:
        _faceSheet.close();
        _followReloads.request();
      case HomeTab.home || HomeTab.follow || HomeTab.mine:
        if (tab == _tab) return;
        _faceSheet.close();
        setState(() => _tab = tab);
      case HomeTab.post || HomeTab.messages:
        showToast(context, '暂未开放');
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Skin?>(
    valueListenable: widget.skin ?? AppScope.of(context).skin,
    builder: (context, skin, _) => _build(context, skin),
  );

  Widget _build(BuildContext context, Skin? skin) {
    final mine = _tab == HomeTab.mine;
    final follow = _tab == HomeTab.follow;
    final media = MediaQuery.of(context);
    final dressed = HomeTabBar.dresses(skin);
    final bar = HomeTabBar.heightOf(context) + media.padding.bottom;
    // Under a dressed bar the pages run to the screen's bottom, inset by the stock bar, so lists end above its row
    // and scroll on behind its picture.
    final pages = dressed
        ? media.copyWith(
            padding: media.padding.copyWith(bottom: bar),
            viewPadding: media.viewPadding.copyWith(bottom: bar),
          )
        : media.removePadding(removeBottom: true);
    return Material(
      color: HomeTabBarTheme.colorsOf(context).bar,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: dressed ? 0 : bar,
            child: MediaQuery(
              data: pages,
              child: IndexedStack(
                key: ValueKey(_session),
                index: _tab == HomeTab.home ? 0 : (follow ? 1 : 2),
                sizing: StackFit.expand,
                children: [
                  _Place(
                    shown: _tab == HomeTab.home,
                    child: HomePage(
                      developerPage: widget.developerPage,
                      initialLink: _initialLink ? widget.initialLink : null,
                      reloads: _reloads,
                      skin: skin,
                    ),
                  ),
                  _Place(
                    shown: follow,
                    child: FollowTabPage(active: follow, faceSheet: _faceSheet, reloads: _followReloads, skin: skin),
                  ),
                  _Place(
                    shown: mine,
                    child: AnnotatedRegion<SystemUiOverlayStyle>(
                      value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                      child: MePage(active: mine, developerPage: widget.developerPage, skin: widget.skin),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: HomeTabBar(
              selected: _tab,
              onTap: _tapped,
              onPartition: () => showToast(context, '暂未开放'),
              skin: skin,
            ),
          ),
          Positioned.fill(child: FaceSheetLayer(controller: _faceSheet)),
        ],
      ),
    );
  }
}

/// A place kept alive while hidden: still, and out of Hero flights, which an [IndexedStack] doesn't stop. Otherwise a
/// hidden 推荐 cover flies over 我的 to or from a pushed page holding the same tag (a space row's `cover-<bvid>`).
class _Place extends StatelessWidget {
  const _Place({required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: shown,
    child: HeroMode(enabled: shown, child: child),
  );
}

class _Reloads extends ChangeNotifier {
  void request() => notifyListeners();
}
