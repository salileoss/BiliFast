import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart' show HistoryItem;
import 'package:bili_core/logic.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../app/route_observer.dart';
import '../app/swipe_back_route.dart';
import '../favourites/favourites_page.dart';
import '../history/history_model.dart';
import '../history/watch_history_page.dart';
import '../offline/pages/offline_list_page.dart';
import '../player_ui/portrait_controls.dart';
import '../settings/settings_page.dart';
import '../shared/menu.dart';
import '../shared/release_refresh.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../watch_later/watch_later_page.dart';
import '../video/video_route.dart';
import 'feed_card.dart';
import 'recents_page.dart';
import 'shortcut_glyphs.dart';

/// What the avatar opens (49): back, the one tab 最近 (49's 看视频 and 听视频 are left out), ⚙ for 设置, the four
/// shortcuts, and the last few videos watched in a white card. The account, logging in and out, and 开发者 are in 设置.
class AvatarPage extends StatelessWidget {
  const AvatarPage({super.key, this.developerPage});

  /// Builds the developer page (dev builds), for 设置 to offer.
  final WidgetBuilder? developerPage;

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(SwipeBackPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AvatarPageTheme.colorsOf(context).background,
        body: Column(
          children: [
            SizedBox(height: top),
            _Bar(onSettings: () => _push(context, (_) => SettingsPage(developerPage: developerPage))),
            SizedBox(
              height: AvatarPageTheme.shortcutsHeight,
              child: Row(
                children: [
                  _Shortcut(
                    key: const ValueKey('avatar-offline'),
                    label: '离线缓存',
                    glyph: ShortcutGlyph.offline,
                    onTap: () => unawaited(openOfflineList(context)),
                  ),
                  _Shortcut(
                    key: const ValueKey('avatar-history'),
                    label: '历史记录',
                    glyph: ShortcutGlyph.history,
                    onTap: () => _push(context, (_) => const WatchHistoryPage()),
                  ),
                  _Shortcut(
                    key: const ValueKey('avatar-favourites'),
                    label: '我的收藏',
                    glyph: ShortcutGlyph.star,
                    onTap: () => _push(context, (_) => const FavouritesPage()),
                  ),
                  _Shortcut(
                    key: const ValueKey('avatar-later'),
                    label: '稍后再看',
                    glyph: ShortcutGlyph.later,
                    onTap: () => _push(context, (_) => const WatchLaterPage()),
                  ),
                ],
              ),
            ),
            Expanded(child: _RecentCard(push: (builder) => _push(context, builder))),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    const half = AvatarPageTheme.tapTarget / 2;
    return SizedBox(
      height: AvatarPageTheme.barHeight,
      child: Stack(
        children: [
          Positioned(
            left: AvatarPageTheme.backLeft + BiliMetrics.backGlyphWidth / 2 - half,
            top: 0,
            width: AvatarPageTheme.tapTarget,
            height: AvatarPageTheme.tapTarget,
            child: _Tap(
              key: const ValueKey('avatar-back'),
              label: '返回',
              onTap: () => Navigator.of(context).maybePop(),
              child: BackGlyph(color: AvatarPageTheme.colorsOf(context).barIcon, shadow: false),
            ),
          ),
          Positioned(
            left: AvatarPageTheme.tabCentreX - AvatarPageTheme.tapTarget,
            width: AvatarPageTheme.tapTarget * 2,
            top: 0,
            bottom: 0,
            child: Semantics(
              header: true,
              selected: true,
              child: Center(
                child: Text(
                  '最近',
                  style: TextStyle(
                    fontFamily: BiliFonts.family,
                    fontSize: AvatarPageTheme.tabText,
                    fontWeight: AvatarPageTheme.tabWeight,
                    color: BiliColors.colorsOf(context).pink,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: AvatarPageTheme.tabCentreX - AvatarPageTheme.tabUnderlineWidth / 2,
            top: AvatarPageTheme.tabUnderlineTop,
            width: AvatarPageTheme.tabUnderlineWidth,
            height: AvatarPageTheme.tabUnderlineHeight,
            child: DecoratedBox(
              decoration: ShapeDecoration(color: BiliColors.colorsOf(context).pink, shape: StadiumBorder()),
            ),
          ),
          Positioned(
            left: AvatarPageTheme.gearCentreX - half,
            top: 0,
            width: AvatarPageTheme.tapTarget,
            height: AvatarPageTheme.tapTarget,
            child: _Tap(
              key: const ValueKey('avatar-settings'),
              label: '设置',
              onTap: onSettings,
              child: CustomPaint(size: Size.square(AvatarPageTheme.gearBox), painter: _GearPainter(palette: BiliPalette.of(context))),
            ),
          ),
        ],
      ),
    );
  }
}

/// A glyph button that fades while pressed, as iOS bar buttons do.
class _Tap extends StatelessWidget {
  const _Tap({super.key, required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(AvatarPageTheme.tapTarget),
      child: Center(child: child),
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({super.key, required this.label, required this.glyph, required this.onTap});

  final String label;
  final ShortcutGlyph glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: AvatarPageTheme.shortcutIconCentre - AvatarPageTheme.shortcutIconBox / 2,
                child: CustomPaint(
                  size: const Size.square(AvatarPageTheme.shortcutIconBox),
                  painter: ShortcutPainter(glyph, palette: BiliPalette.of(context)),
                ),
              ),
              Positioned(
                top: 0,
                height: AvatarPageTheme.shortcutLabelCentre * 2,
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    // Not CupertinoButton's action style: its tracking, and no fallback to PingFang.
                    style: TextStyle(
                      fontFamily: BiliFonts.family,
                      fontFamilyFallback: BiliFonts.fallback,
                      letterSpacing: 0,
                      fontSize: AvatarPageTheme.shortcutText,
                      color: BiliColors.colorsOf(context).text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 最近在看的视频: the newest few of the account's 历史记录, asked for as the page opens and whenever it shows again.
/// Logged out, the newest few of 最近打开 instead, so the card isn't empty.
class _RecentCard extends StatefulWidget {
  const _RecentCard({required this.push});

  final void Function(WidgetBuilder builder) push;

  @override
  State<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends State<_RecentCard> with RouteAware {
  AppServices? _services;
  late final HistoryModel _history;
  late final Listenable _changes;
  PageRoute<dynamic>? _route;

  /// The account changed since the list last loaded: the next login (or coming back to the page) loads its list.
  bool _reloadDue = false;
  bool _wasLoggedIn = false;

  /// A page route is pushed over this one.
  bool _covered = false;

  AppEnvironment get _environment => _services!.environment;

  bool get _signedOut => switch (_environment.account) {
    LoggedOut() || LoginExpired() => true,
    LoggedIn() || AccountUnknown() => false,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      final services = _services = AppScope.of(context);
      _history = HistoryModel(api: services.pageApi, isLoggedIn: () => !_signedOut);
      _changes = Listenable.merge([services.environment, _history, services.recents]);
      _reloadDue = _signedOut;
      _wasLoggedIn = services.environment.account is LoggedIn;
      services.environment.addListener(_accountChanged);
      unawaited(_history.start());
    }
    if (ModalRoute.of(context) case final PageRoute<dynamic> route when route != _route) {
      pageRoutes.unsubscribe(this);
      _route = route;
      pageRoutes.subscribe(this, route);
    }
  }

  /// The environment also tells of every account check that only confirms the login; those load nothing.
  void _accountChanged() {
    final account = _environment.account;
    final wasLoggedIn = _wasLoggedIn;
    _wasLoggedIn = account is LoggedIn;
    if (_signedOut) {
      _history.signOut();
      _reloadDue = true;
      return;
    }
    if (account is! LoggedIn) {
      // A login over one that read logged in passes through here, and may be another account.
      if (wasLoggedIn) _reloadDue = true;
      return;
    }
    // Covered (设置 or the login page on top), the page coming back loads it, once.
    if (!_reloadDue || _covered) return;
    _reloadDue = false;
    unawaited(_history.reload());
  }

  @override
  void didPushNext() => _covered = true;

  /// Back from a video (or 历史记录, 设置): the account's list may have changed meanwhile.
  @override
  void didPopNext() {
    _covered = false;
    if (_signedOut) return;
    if (!_reloadDue && (_history.loading || _history.needsLogin)) return;
    _reloadDue = false;
    unawaited(_history.reload());
  }

  @override
  void dispose() {
    pageRoutes.unsubscribe(this);
    _services?.environment.removeListener(_accountChanged);
    _history.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final message = await _history.reload();
    if (message != null && mounted) showToast(context, message);
  }

  Future<void> _delete(HistoryItem item) async {
    final failure = await _history.delete(item);
    if (failure != null && mounted) showToast(context, failure);
  }

  /// As 历史记录's 登录: the account change has usually reloaded the list by the time the gate answers.
  Future<bool> _login() async {
    final loggedIn = await _services!.loginGate.request(context);
    if (loggedIn && mounted && _history.needsLogin) {
      _reloadDue = false;
      unawaited(_history.reload());
    }
    return loggedIn && mounted;
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(AvatarPageTheme.cardRadius)),
    child: ColoredBox(
      color: BiliColors.colorsOf(context).card,
      child: ListenableBuilder(
        listenable: _changes,
        builder: (context, _) => _signedOut ? _recentsList(context) : _historyList(context),
      ),
    ),
  );

  /// Bilibili answered -101 while the app still reads logged in: the card asks for a login, as 历史记录 does, and
  /// opens the login page only when pressed.
  Widget _needsLogin(BuildContext context) => _list(
    context,
    onAll: () => unawaited(() async {
      if (await _login() && mounted) widget.push((_) => const WatchHistoryPage());
    }()),
    note: '登录后查看历史记录',
    action: _LoginButton(onTap: () => unawaited(_login())),
    rows: const [],
  );

  Widget _historyList(BuildContext context) {
    final history = _history;
    if (history.needsLogin) return _needsLogin(context);
    final now = _services!.recents.now();
    String? note;
    if (history.items.isEmpty && !history.loading) {
      if (history.error != null) {
        note = '加载失败，下拉重试';
      } else if (history.isEnd) {
        note = '还没有看过视频';
      }
    }
    return _list(
      context,
      onAll: () => widget.push((_) => const WatchHistoryPage()),
      onRefresh: _refresh,
      note: note,
      rows: [
        for (final item in history.items.take(AvatarPageTheme.shown))
          _VideoRow(
            key: ValueKey('avatar-recent-${item.id}'),
            id: item.id,
            title: item.title,
            cover: item.cover,
            duration: item.duration,
            progress: HistoryModel.progressFraction(item),
            time: '${TimeFormat.relative(item.viewAt, now: now)}播放',
            onOpen: () => unawaited(openVideoPage(context, HistoryModel.route(item))),
            onRemove: () => unawaited(_delete(item)),
          ),
      ],
    );
  }

  Widget _recentsList(BuildContext context) {
    final recents = _services!.recents;
    final items = recents.items.take(AvatarPageTheme.shown).toList();
    final now = recents.now();
    return _list(
      context,
      onAll: () => widget.push((_) => const RecentsPage()),
      note: items.isEmpty ? '还没有打开过视频' : null,
      rows: [
        for (final item in items)
          _VideoRow(
            key: ValueKey('avatar-recent-${item.id}'),
            id: item.id,
            title: item.title,
            cover: item.cover,
            duration: item.duration,
            progress: switch (item.progress) {
              final progress? when progress > 0 && item.duration > 0 => math.min(1.0, progress / item.duration),
              _ => 0,
            },
            time: switch (item.openedAt) {
              final openedAt? => '${TimeFormat.relative(openedAt, now: now)}播放',
              null => null,
            },
            onOpen: () {
              // Stamps the part as opened now and puts it first, as opening a link does.
              recents.add(item);
              final route = VideoRoute(bvid: item.bvid, cid: item.cid, title: item.title, cover: item.cover);
              unawaited(openVideoPage(context, route));
            },
            onRemove: () => recents.remove(item),
          ),
      ],
    );
  }

  Widget _list(
    BuildContext context, {
    required VoidCallback onAll,
    Future<void> Function()? onRefresh,
    required String? note,
    Widget? action,
    required List<Widget> rows,
  }) => CustomScrollView(
    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    slivers: [
      if (onRefresh != null) ReleaseRefreshControl(onRefresh: onRefresh),
      SliverToBoxAdapter(child: _Header(onAll: onAll)),
      if (note != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AvatarPageTheme.rowExtent / 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note,
                  style: TextStyle(
                    fontFamily: BiliFonts.family,
                    fontSize: BiliMetrics.bodyText,
                    color: BiliColors.colorsOf(context).secondaryText,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: HistoryTheme.stateGap), action],
              ],
            ),
          ),
        ),
      SliverList.list(children: rows),
      SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onAll});

  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AvatarPageTheme.headerHeight,
    child: Stack(
      children: [
        Positioned(
          left: BiliMetrics.gutter,
          top: 0,
          height: AvatarPageTheme.headerCentre * 2,
          child: Center(
            child: Text(
              '最近在看的视频',
              style: TextStyle(
                fontFamily: BiliFonts.family,
                fontSize: AvatarPageTheme.headerText,
                fontWeight: AvatarPageTheme.headerWeight,
                color: BiliColors.colorsOf(context).text,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: AvatarPageTheme.headerCentre - AvatarPageTheme.tapTarget / 2,
          height: AvatarPageTheme.tapTarget,
          child: Semantics(
            container: true,
            button: true,
            label: '全部',
            excludeSemantics: true,
            onTap: onAll,
            child: CupertinoButton(
              key: const ValueKey('avatar-all'),
              onPressed: onAll,
              padding: const EdgeInsets.only(left: BiliMetrics.gutter, right: AvatarPageTheme.allRight),
              minimumSize: const Size.square(AvatarPageTheme.tapTarget),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '全部',
                    style: TextStyle(
                      fontFamily: BiliFonts.family,
                      fontSize: AvatarPageTheme.allText,
                      color: BiliColors.colorsOf(context).secondaryText,
                    ),
                  ),
                  const SizedBox(width: AvatarPageTheme.allChevronGap),
                  CustomPaint(
                    size: Size(AvatarPageTheme.allChevronWidth, AvatarPageTheme.allChevronHeight),
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

/// 历史记录's pink 登录, for the card's -101 state.
class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: '登录',
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      key: const ValueKey('avatar-login'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: HistoryTheme.loginHeight,
        padding: const EdgeInsets.symmetric(horizontal: HistoryTheme.loginPadX),
        decoration: ShapeDecoration(color: BiliColors.colorsOf(context).pink, shape: StadiumBorder()),
        child: Center(
          widthFactor: 1,
          child: Text(
            '登录',
            style: TextStyle(
              fontFamily: BiliFonts.family,
              fontSize: HistoryTheme.loginText,
              fontWeight: HistoryTheme.buttonWeight,
              color: BiliColors.onPink,
            ),
          ),
        ),
      ),
    ),
  );
}

/// One of 49's rows: the cover with its duration and progress, two lines of title, when it was last played, and ✕.
class _VideoRow extends StatelessWidget {
  const _VideoRow({
    super.key,
    required this.id,
    required this.title,
    required this.cover,
    required this.duration,
    required this.progress,
    required this.time,
    required this.onOpen,
    required this.onRemove,
  });

  final String id;
  final String title;
  final String? cover;

  /// Seconds; 0 when unknown.
  final int duration;

  /// How much of the pink line under the cover is filled, 0 to 1.
  final double progress;

  /// `2小时前播放`; null when unknown.
  final String? time;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const coverTop = AvatarPageTheme.rowCoverTop;
    const coverBottom = coverTop + AvatarPageTheme.coverHeight;
    final cover = this.cover;
    final time = this.time;
    final titleStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: AvatarPageTheme.titleText,
      height: AvatarPageTheme.titleLine / AvatarPageTheme.titleText,
      color: BiliColors.colorsOf(context).text,
    );
    final timeStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: AvatarPageTheme.timeText,
      color: BiliColors.colorsOf(context).secondaryText,
    );
    return SizedBox(
      height: AvatarPageTheme.rowExtent,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              container: true,
              button: true,
              label: title,
              excludeSemantics: true,
              onTap: onOpen,
              child: PressHighlight(onTap: onOpen, child: SizedBox.expand()),
            ),
          ),
          Positioned(
            left: BiliMetrics.gutter,
            top: coverTop,
            width: AvatarPageTheme.coverWidth,
            height: AvatarPageTheme.coverHeight,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AvatarPageTheme.coverRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null && cover.isNotEmpty)
                      RemoteImage(
                        cover,
                        size: const Size(AvatarPageTheme.coverWidth, AvatarPageTheme.coverHeight),
                        cover: true,
                      )
                    else
                      ColoredBox(color: BiliColors.colorsOf(context).pageGrey),
                    if (duration > 0)
                      Positioned(
                        right: AvatarPageTheme.durationInset,
                        bottom: AvatarPageTheme.durationInset,
                        height: AvatarPageTheme.durationHeight,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: AvatarPageTheme.durationPad),
                          decoration: BoxDecoration(
                            color: AvatarPageTheme.durationFill,
                            borderRadius: BorderRadius.circular(AvatarPageTheme.durationRadius),
                          ),
                          child: Text(
                            FeedCardView.duration(duration),
                            style: TextStyle(
                              fontFamily: BiliFonts.family,
                              fontSize: AvatarPageTheme.durationText,
                              height: 1,
                              color: BiliColors.onCover,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    if (progress > 0)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        height: AvatarPageTheme.progressHeight,
                        width: AvatarPageTheme.coverWidth * progress,
                        child: ColoredBox(key: ValueKey('avatar-recent-progress'), color: BiliColors.colorsOf(context).pink),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AvatarPageTheme.textLeft,
            right: BiliMetrics.gutter,
            top: coverTop - AvatarPageTheme.titleLift,
            child: IgnorePointer(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
                strutStyle: BiliFonts.strut(titleStyle),
              ),
            ),
          ),
          if (time != null)
            Positioned(
              left: AvatarPageTheme.textLeft,
              right: AvatarPageTheme.removeCentreFromRight + AvatarPageTheme.tapTarget / 2,
              bottom: AvatarPageTheme.rowExtent - coverBottom - AvatarPageTheme.timeDrop,
              child: IgnorePointer(
                child: Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: timeStyle,
                  strutStyle: BiliFonts.strutOf(context, timeStyle),
                ),
              ),
            ),
          Positioned(
            right: AvatarPageTheme.removeCentreFromRight - AvatarPageTheme.tapTarget / 2,
            top: coverTop + AvatarPageTheme.removeCentreBelowCover - AvatarPageTheme.tapTarget / 2,
            width: AvatarPageTheme.tapTarget,
            height: AvatarPageTheme.tapTarget,
            child: Semantics(
              container: true,
              button: true,
              label: '移除',
              excludeSemantics: true,
              onTap: onRemove,
              child: GestureDetector(
                key: ValueKey('avatar-remove-$id'),
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Center(
                  child: CustomPaint(size: Size.square(AvatarPageTheme.removeGlyph), painter: _CrossPainter(palette: BiliPalette.of(context))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Paint _stroke(double width, Color color) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

/// 49's ⚙: a hexagon standing on a point, with rounded corners, around a small ring.
class _GearPainter extends CustomPainter {
  final BiliPalette palette;

  const _GearPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final corners = [
      for (var i = 0; i < 6; i++)
        centre + Offset.fromDirection(-math.pi / 2 + i * math.pi / 3, AvatarPageTheme.gearRadius),
    ];
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final corner = corners[i];
      final before = corners[(i + 5) % 6];
      final after = corners[(i + 1) % 6];
      final into = corner + (before - corner) / (before - corner).distance * AvatarPageTheme.gearCorner;
      final out = corner + (after - corner) / (after - corner).distance * AvatarPageTheme.gearCorner;
      if (i == 0) {
        path.moveTo(into.dx, into.dy);
      } else {
        path.lineTo(into.dx, into.dy);
      }
      path.quadraticBezierTo(corner.dx, corner.dy, out.dx, out.dy);
    }
    path.close();
    final paint = _stroke(AvatarPageTheme.gearStroke, AvatarPageThemeColors(palette).barIcon);
    canvas
      ..drawPath(path, paint)
      ..drawCircle(centre, AvatarPageTheme.gearHole, paint);
  }

  @override
  bool shouldRepaint(_GearPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

class _ChevronPainter extends CustomPainter {
  final BiliPalette palette;

  const _ChevronPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = AvatarPageTheme.allChevronStroke / 2;
    final path = Path()
      ..moveTo(inset, inset)
      ..lineTo(size.width - inset, size.height / 2)
      ..lineTo(inset, size.height - inset);
    canvas.drawPath(path, _stroke(AvatarPageTheme.allChevronStroke, BiliColorsColors(palette).secondaryText));
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}

class _CrossPainter extends CustomPainter {
  final BiliPalette palette;

  const _CrossPainter({this.palette = const BiliPalette(Brightness.light)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(AvatarPageTheme.removeStroke, AvatarPageThemeColors(palette).remove);
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.palette.brightness != palette.brightness;
}
