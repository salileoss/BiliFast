import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app/app_environment.dart';
import '../../app/app_scope.dart';
import '../../search/results/user_row.dart' show VerifiedBoltPainter;
import '../../search/search_glyphs.dart';
import '../../shared/loading_tv.dart';
import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../../skin/skin.dart';
import '../../space/space_route.dart';
import '../../space/uploader_tap.dart';
import '../dynamic_api.dart';
import 'following_glyphs.dart';
import 'following_model.dart';

TextStyle followingStyle(double size, Color color, {double? line, FontWeight weight = FontWeight.w400}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: line == null ? null : line / size,
  leadingDistribution: line == null ? null : TextLeadingDistribution.even,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

/// One line of [text] in [style], its line box centred where it is placed.
Widget _line(String text, TextStyle style, {Key? key, TextAlign align = TextAlign.left}) => Text(
  text,
  key: key,
  style: style,
  strutStyle: BiliFonts.strut(style),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
);

String orderLabel(FollowingOrder order) => switch (order) {
  FollowingOrder.recommended => '推荐排序',
  FollowingOrder.mostVisited => '最常访问',
  FollowingOrder.recent => '最近关注',
};

/// The bar's colours: the equipped 装扮's second-page colour and text colour where the skin reaches past the main pages
/// (129's green is the equipped skin's `color_second_page`), else white. The status bar goes by the fill.
final class FollowingBarLook {
  const FollowingBarLook({required this.fill, required this.ink, required this.lightStatus});

  static const stock = FollowingBarLook(
    fill: FollowingListTheme.bar,
    ink: FollowingListTheme.barInk,
    lightStatus: false,
  );

  factory FollowingBarLook.of(Skin? skin, {BuildContext? context}) {
    final page = skin?.equip.colors.colorSecondPage;
    if (skin == null || skin.equip.primaryOnly || page == null) {
      if (context == null) return stock;
      final palette = BiliPalette.of(context);
      return FollowingBarLook(fill: FollowingListTheme.colorsOf(context).bar, ink: FollowingListTheme.colorsOf(context).barInk, lightStatus: palette.isDark);
    }
    final fill = Color(page);
    return FollowingBarLook(
      fill: fill,
      ink: skin.color ?? (skin.lightText ? FollowingListTheme.barLightInk : context == null ? FollowingListTheme.barInk : FollowingListTheme.colorsOf(context).barInk),
      lightStatus: SkinStatusBar.whiteOverColor(fill),
    );
  }

  final Color fill;
  final Color ink;
  final bool lightStatus;
}

/// 我的关注 (129): the bar, 搜索我的关注, 排序方式 with its menu (130), and the people the account follows; a row opens
/// that person's space.
class FollowingListPage extends StatefulWidget {
  const FollowingListPage({super.key, this.api, this.skin});

  /// [AppScope]'s by default.
  final DynamicApi? api;
  final ValueListenable<Skin?>? skin;

  @override
  State<FollowingListPage> createState() => _FollowingListPageState();
}

class _FollowingListPageState extends State<FollowingListPage> with SingleTickerProviderStateMixin {
  FollowingListModel? _modelOrNull;
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _listScroll = ScrollController();
  final _resultsScroll = ScrollController();
  // Once closed, the menu's layers leave the tree, so they take no more taps.
  late final _menu = AnimationController(vsync: this, duration: FollowingListTheme.menuMotion)
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
  late final _menuFade = CurvedAnimation(parent: _menu, curve: Curves.easeOut);
  bool _menuOpen = false;

  FollowingListModel get _model => _modelOrNull!;
  AppEnvironment? _environment;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_modelOrNull != null) return;
    final services = AppScope.of(context);
    final environment = _environment = services.environment..addListener(_accountChanged);
    _modelOrNull = FollowingListModel(
      api: widget.api ?? services.dynamicApi,
      mid: () => environment.mid,
      searchPause: FollowingListTheme.searchPause,
    )..start();
    // A launch check that failed is tried again, as 首页 does on coming back.
    if (environment.account is AccountUnknown && environment.accountCheckFailed) _checkAccount();
  }

  @override
  void dispose() {
    _environment?.removeListener(_accountChanged);
    _modelOrNull?.dispose();
    _field.dispose();
    _focus.dispose();
    _listScroll.dispose();
    _resultsScroll.dispose();
    _menuFade.dispose();
    _menu.dispose();
    super.dispose();
  }

  void _back() => unawaited(Navigator.of(context).maybePop());

  bool get _loggedOut => switch (_environment!.account) {
    LoggedOut() || LoginExpired() => true,
    LoggedIn() || AccountUnknown() => false,
  };

  /// The account known starts the lists; logging out empties them.
  void _accountChanged() {
    if (!mounted) return;
    if (_loggedOut) {
      _model.signOut();
    } else {
      _model.start();
    }
    setState(() {});
  }

  void _checkAccount() => unawaited(_environment!.refreshAccount());

  Future<void> _login() async {
    final loggedIn = await AppScope.of(context).loginGate.request(context);
    if (loggedIn && mounted) _model.start();
  }

  /// In place of the lists: logged out, a 登录 through the login gate (no screenshot, a guess); an account check that
  /// failed, its 重试. Null when the lists show, or wait on their TV for the check.
  Widget? _accountState() {
    if (_loggedOut) {
      return _StateMessage(
        key: const ValueKey('following-logged-out'),
        message: '登录后查看我的关注',
        action: '登录',
        actionKey: const ValueKey('following-login'),
        onAction: () => unawaited(_login()),
      );
    }
    final environment = _environment!;
    if (environment.account is AccountUnknown && environment.accountCheckFailed && environment.mid == null) {
      return _StateMessage(
        key: const ValueKey('following-account-failed'),
        message: environment.accountLabel,
        action: '重试',
        actionKey: const ValueKey('following-account-retry'),
        onAction: _checkAccount,
      );
    }
    return null;
  }

  void _setMenu(bool open) {
    if (_menuOpen == open) return;
    if (open) _focus.unfocus();
    setState(() => _menuOpen = open);
    _menu.duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : FollowingListTheme.menuMotion;
    if (open) {
      unawaited(_menu.forward());
    } else {
      unawaited(_menu.reverse());
    }
  }

  void _pick(FollowingOrder order) {
    _setMenu(false);
    if (order == _model.order) return;
    if (_listScroll.hasClients) _listScroll.jumpTo(0);
    _model.setOrder(order);
  }

  void _textChanged(String text) {
    if (text.trim().isNotEmpty) _setMenu(false);
    _model.textChanged(text);
  }

  void _clear() {
    _field.clear();
    _model.textChanged('');
  }

  void _open(FollowingUser user) {
    _focus.unfocus();
    unawaited(openSpace(context, UploaderRef(mid: user.mid, name: user.name, face: user.face)));
  }

  bool _scrolled(ScrollNotification notification) {
    if (notification.depth == 0) _loadMoreNearEnd(notification.metrics);
    return false;
  }

  void _loadMoreNearEnd(ScrollMetrics metrics) {
    if (!_model.shown.canLoadMore || !metrics.hasContentDimensions) return;
    if (metrics.extentAfter >= FollowingListTheme.loadAhead) return;
    // A scroll notification can come mid-layout, where the model's change must not rebuild anything yet.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _model.loadMore();
      });
    } else {
      _model.loadMore();
    }
  }

  /// A page too short to scroll sends no notification, so after each answer the list checks whether its end shows.
  void _checkShortList() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scroll = _model.searching ? _resultsScroll : _listScroll;
      if (scroll.hasClients && scroll.position.hasContentDimensions) _loadMoreNearEnd(scroll.position);
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin ?? AppScope.of(context).skin;
    return ValueListenableBuilder<Skin?>(
      valueListenable: skin,
      builder: (context, skin, _) => _page(FollowingBarLook.of(skin, context: context)),
    );
  }

  Widget _page(FollowingBarLook look) {
    final top = MediaQuery.paddingOf(context).top;
    const section =
        FollowingListTheme.barHairline +
        FollowingListTheme.searchTop +
        FollowingListTheme.fieldHeight +
        FollowingListTheme.searchBottom +
        FollowingListTheme.searchRule;
    final menuTop = top + FollowingListTheme.barRow + section + FollowingListTheme.sortRow;
    return PopScope(
      canPop: !_menuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setMenu(false);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: look.lightStatus ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: FollowingListTheme.colorsOf(context).page,
          resizeToAvoidBottomInset: false,
          body: DefaultTextStyle(
            style: followingStyle(FollowingListTheme.nameText, FollowingListTheme.colorsOf(context).name),
            child: ListenableBuilder(
              listenable: _model,
              builder: (context, _) {
                final searching = _model.searching;
                final account = _accountState();
                _checkShortList();
                return Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Bar(look: look, onBack: _back),
                        _SearchSection(
                          field: _field,
                          focus: _focus,
                          onChanged: _textChanged,
                          onSubmit: _model.submit,
                          onClear: _clear,
                        ),
                        if (!searching)
                          _SortRow(order: _model.order, open: _menuOpen, onTap: () => _setMenu(!_menuOpen)),
                        Expanded(child: account ?? _lanes(searching)),
                      ],
                    ),
                    if (_menuOpen || !_menu.isDismissed) ..._menuLayers(menuTop),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The followings, and over them a search's results while it shows.
  Widget _lanes(bool searching) => MediaQuery.removePadding(
    context: context,
    removeTop: true,
    child: NotificationListener<ScrollNotification>(
      onNotification: _scrolled,
      child: Stack(
        children: [
          Offstage(
            offstage: searching,
            child: TickerMode(
              enabled: !searching,
              child: _Lane(
                key: const ValueKey('following-list'),
                lane: _model.list,
                scroll: _listScroll,
                hasUpdate: _model.hasUpdate,
                empty: '还没有关注的人',
                onRetry: _model.retry,
                onOpen: _open,
              ),
            ),
          ),
          if (searching)
            _Lane(
              key: const ValueKey('following-results'),
              lane: _model.results,
              scroll: _resultsScroll,
              hasUpdate: _model.hasUpdate,
              empty: '没有找到相关的关注',
              onRetry: _model.retry,
              onOpen: _open,
            ),
        ],
      ),
    ),
  );

  List<Widget> _menuLayers(double menuTop) {
    final fade = _menuFade;
    return [
      // A tap anywhere above the menu closes it, the order's own ▽ included.
      if (_menuOpen)
        Positioned(
          key: const ValueKey('following-menu-above'),
          left: 0,
          right: 0,
          top: 0,
          height: menuTop,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _setMenu(false)),
        ),
      Positioned(
        left: 0,
        right: 0,
        top: menuTop + FollowingListTheme.menuRow * FollowingOrder.values.length,
        bottom: 0,
        child: IgnorePointer(
          ignoring: !_menuOpen,
          child: GestureDetector(
            key: const ValueKey('following-menu-dim'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _setMenu(false),
            child: FadeTransition(
              opacity: fade,
              child: ColoredBox(color: FollowingListTheme.dim),
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: menuTop - FollowingListTheme.notchHeight,
        child: FadeTransition(
          opacity: fade,
          child: IgnorePointer(
            ignoring: !_menuOpen,
            child: _SortMenu(chosen: _model.order, onPick: _pick),
          ),
        ),
      ),
      // The PopScope holds while the menu is open, which turns the route's edge swipe off: this takes the same edge
      // and closes the menu instead.
      if (_menuOpen)
        Positioned(
          key: const ValueKey('following-menu-edge'),
          left: 0,
          top: 0,
          bottom: 0,
          width: math.max(BiliMetrics.swipeBackEdge, MediaQuery.paddingOf(context).left),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) >= 0) _setMenu(false);
            },
          ),
        ),
    ];
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.look, required this.onBack});

  final FollowingBarLook look;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    const half = FollowingListTheme.backTarget / 2;
    final title = followingStyle(
      FollowingListTheme.titleText,
      look.ink,
      line: FollowingListTheme.titleLine,
      weight: FollowingListTheme.titleWeight,
    );
    return ColoredBox(
      key: const ValueKey('following-bar'),
      color: look.fill,
      child: SizedBox(
        height: top + FollowingListTheme.barRow,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: top,
              height: FollowingListTheme.rowCentre * 2,
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, FollowingListTheme.titleDrop),
                  child: _line('我的关注', title, key: const ValueKey('following-title')),
                ),
              ),
            ),
            Positioned(
              left: FollowingListTheme.backCentreX - half,
              top: top + FollowingListTheme.rowCentre - half,
              width: FollowingListTheme.backTarget,
              height: FollowingListTheme.backTarget,
              child: Semantics(
                button: true,
                label: '返回',
                onTap: onBack,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('following-back'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack,
                  child: CustomPaint(painter: FollowingBackPainter(fill: look.fill, palette: BiliPalette.of(context))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.field,
    required this.focus,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController field;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  /// iOS's own edit menu: its Paste reads the clipboard without the "Allow Paste" alert that Flutter's toolbar
  /// brings up.
  static Widget _editMenu(BuildContext context, EditableTextState state) => SystemContextMenu.isSupported(context)
      ? SystemContextMenu.editableText(editableTextState: state)
      : AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

  @override
  Widget build(BuildContext context) {
    final text = followingStyle(
      FollowingListTheme.fieldText,
      FollowingListTheme.colorsOf(context).fieldInk,
      line: FollowingListTheme.fieldLine,
    );
    final hint = text.copyWith(color: FollowingListTheme.colorsOf(context).placeholder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: FollowingListTheme.colorsOf(context).hairline,
          child: SizedBox(height: FollowingListTheme.barHairline),
        ),
        const SizedBox(height: FollowingListTheme.searchTop),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FollowingListTheme.fieldInset),
          child: GestureDetector(
            onTap: focus.requestFocus,
            child: Container(
              key: const ValueKey('following-search'),
              height: FollowingListTheme.fieldHeight,
              decoration: ShapeDecoration(color: FollowingListTheme.colorsOf(context).field, shape: StadiumBorder()),
              padding: const EdgeInsets.only(left: FollowingListTheme.magnifierLead),
              child: Row(
                children: [
                  Transform.translate(
                    offset: const Offset(0, -FollowingListTheme.magnifierLift),
                    child: SearchGlyphIcon(
                      SearchGlyph.magnifier,
                      size: FollowingListTheme.magnifier,
                      color: FollowingListTheme.colorsOf(context).magnifierInk,
                    ),
                  ),
                  const SizedBox(width: FollowingListTheme.magnifierGap),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('following-search-field'),
                      controller: field,
                      focusNode: focus,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.search,
                      contextMenuBuilder: _editMenu,
                      cursorColor: FollowingListTheme.colorsOf(context).caret,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmit(),
                      style: text,
                      strutStyle: BiliFonts.strut(text),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        // As the decorator would draw hintText, with the strut it can't be given.
                        hint: Text(
                          '搜索我的关注',
                          style: hint,
                          strutStyle: BiliFonts.strut(hint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: field,
                    builder: (context, _) => field.text.isEmpty
                        ? const SizedBox(width: FollowingListTheme.magnifierLead)
                        : Semantics(
                            button: true,
                            label: '清空',
                            onTap: onClear,
                            excludeSemantics: true,
                            child: GestureDetector(
                              key: const ValueKey('following-search-clear'),
                              behavior: HitTestBehavior.opaque,
                              onTap: onClear,
                              child: SizedBox(
                                width: FollowingListTheme.clearTarget,
                                child: Center(
                                  child: SearchGlyphIcon(
                                    SearchGlyph.clear,
                                    size: FollowingListTheme.clear,
                                    color: FollowingListTheme.colorsOf(context).clearColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: FollowingListTheme.searchBottom),
        ColoredBox(
          color: FollowingListTheme.colorsOf(context).hairline,
          child: SizedBox(height: FollowingListTheme.searchRule),
        ),
      ],
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.order, required this.open, required this.onTap});

  final FollowingOrder order;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = followingStyle(
      FollowingListTheme.sortText,
      FollowingListTheme.colorsOf(context).sortLabel,
      line: FollowingListTheme.sortLine,
    );
    final value = label.copyWith(color: FollowingListTheme.colorsOf(context).sortValue);
    return SizedBox(
      height: FollowingListTheme.sortRow,
      child: Stack(
        children: [
          Positioned.fill(
            left: FollowingListTheme.fieldInset,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(0, FollowingListTheme.sortDrop),
                child: _line('排序方式', label),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: FollowingListTheme.sortTarget,
            child: Semantics(
              button: true,
              label: '排序方式，${orderLabel(order)}',
              onTap: onTap,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('following-sort'),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: FollowingListTheme.sortChevronRight + FollowingListTheme.sortChevronStroke / 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, FollowingListTheme.sortDrop),
                        child: _line(orderLabel(order), value, key: const ValueKey('following-sort-value')),
                      ),
                      const SizedBox(width: FollowingListTheme.sortGap),
                      CustomPaint(
                        key: ValueKey(open ? 'following-sort-up' : 'following-sort-down'),
                        size: const Size(FollowingListTheme.sortChevronWidth, FollowingListTheme.sortChevronHeight),
                        painter: SortChevronPainter(open: open, palette: BiliPalette.of(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 130's menu: its top edge with the notch, then the three orders.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.chosen, required this.onPick});

  final FollowingOrder chosen;
  final ValueChanged<FollowingOrder> onPick;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('following-menu'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: const Size.fromHeight(FollowingListTheme.notchHeight + FollowingListTheme.barHairline),
          painter: MenuEdgePainter(notchX: constraints.maxWidth - FollowingListTheme.notchRight, palette: BiliPalette.of(context)),
        ),
      ),
      ColoredBox(
        color: FollowingListTheme.colorsOf(context).menuFill,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, order) in FollowingOrder.values.indexed)
              _MenuItem(
                order: order,
                chosen: order == chosen,
                // The hairline is the first row's top.
                height: FollowingListTheme.menuRow - (index == 0 ? FollowingListTheme.barHairline : 0),
                onTap: () => onPick(order),
              ),
          ],
        ),
      ),
    ],
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.order, required this.chosen, required this.height, required this.onTap});

  final FollowingOrder order;
  final bool chosen;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = followingStyle(
      FollowingListTheme.menuText,
      chosen ? FollowingListTheme.colorsOf(context).menuChosen : FollowingListTheme.colorsOf(context).menuInk,
      line: FollowingListTheme.menuLine,
    );
    // The first row lost the hairline from its top, so its middle is the full row's.
    final lift = (FollowingListTheme.menuRow - height) / 2;
    return Semantics(
      button: true,
      selected: chosen,
      label: orderLabel(order),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('following-order-${order.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                left: FollowingListTheme.fieldInset,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(0, FollowingListTheme.menuDrop - lift),
                    child: _line(orderLabel(order), style),
                  ),
                ),
              ),
              if (chosen)
                Positioned(
                  right: FollowingListTheme.checkRight - FollowingListTheme.checkWidth / 2,
                  top: height / 2 - lift + FollowingListTheme.checkDrop - FollowingListTheme.checkHeight / 2,
                  child: CustomPaint(
                    key: ValueKey('following-order-check'),
                    size: Size(FollowingListTheme.checkWidth, FollowingListTheme.checkHeight),
                    painter: SortCheckPainter(palette: BiliPalette.of(context)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list or the search's results: the TV while the first page loads, its failure with 重试, or the rows with the
/// footer's spinner or 加载失败，点击重试.
class _Lane extends StatelessWidget {
  const _Lane({
    super.key,
    required this.lane,
    required this.scroll,
    required this.hasUpdate,
    required this.empty,
    required this.onRetry,
    required this.onOpen,
  });

  final FollowingLane lane;
  final ScrollController scroll;
  final bool Function(int mid) hasUpdate;
  final String empty;
  final VoidCallback onRetry;
  final ValueChanged<FollowingUser> onOpen;

  @override
  Widget build(BuildContext context) {
    if (!lane.loaded) {
      final error = lane.error;
      if (error == null) return const Center(child: LoadingTvState());
      return _StateMessage(
        key: const ValueKey('following-failed'),
        message: error,
        action: '重试',
        actionKey: const ValueKey('following-retry'),
        onAction: onRetry,
      );
    }
    if (lane.users.isEmpty) {
      return Center(child: _line(empty, followingStyle(FollowingListTheme.stateText, FollowingListTheme.colorsOf(context).stateInk)));
    }
    final media = MediaQuery.of(context);
    final bottom = math.max(media.viewInsets.bottom, media.padding.bottom);
    final users = lane.users;
    return ListView.builder(
      controller: scroll,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: bottom),
      itemCount: users.length + 1,
      itemBuilder: (context, index) {
        if (index == users.length) {
          return _Footer(loading: lane.loading, error: lane.error, onRetry: onRetry);
        }
        final user = users[index];
        return _FollowingRow(user: user, updated: hasUpdate(user.mid), onTap: () => onOpen(user));
      },
    );
  }
}

class _FollowingRow extends StatelessWidget {
  const _FollowingRow({required this.user, required this.updated, required this.onTap});

  final FollowingUser user;
  final bool updated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = followingStyle(
      FollowingListTheme.nameText,
      user.vipPink ? FollowingListTheme.colorsOf(context).vipName : FollowingListTheme.colorsOf(context).name,
      line: FollowingListTheme.nameLine,
    );
    const faceTop = (FollowingListTheme.row - FollowingListTheme.face) / 2;
    const dotLeft = FollowingListTheme.dotRight + FollowingListTheme.dot / 2;
    return Semantics(
      button: true,
      label: updated ? '${user.name}，有新动态' : user.name,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('following-row-${user.mid}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: FollowingListTheme.row,
          child: Stack(
            children: [
              Positioned(
                left: FollowingListTheme.faceInset,
                top: faceTop,
                width: FollowingListTheme.face,
                height: FollowingListTheme.face,
                child: _Face(user: user),
              ),
              Positioned(
                left: FollowingListTheme.nameLeft,
                right: dotLeft + FollowingListTheme.nameGap,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: const Offset(0, FollowingListTheme.nameDrop),
                    child: _line(user.name, style, key: ValueKey('following-name-${user.mid}')),
                  ),
                ),
              ),
              if (updated)
                Positioned(
                  right: FollowingListTheme.dotRight - FollowingListTheme.dot / 2,
                  top: (FollowingListTheme.row - FollowingListTheme.dot) / 2,
                  width: FollowingListTheme.dot,
                  height: FollowingListTheme.dot,
                  child: DecoratedBox(
                    key: ValueKey('following-dot-${user.mid}'),
                    decoration: BoxDecoration(color: FollowingListTheme.colorsOf(context).dotInk, shape: BoxShape.circle),
                  ),
                ),
              Positioned(
                left: FollowingListTheme.rowRuleInset,
                right: FollowingListTheme.rowRuleInset,
                bottom: 0,
                height: FollowingListTheme.rowRule,
                child: ColoredBox(color: FollowingListTheme.colorsOf(context).hairline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.user});

  final FollowingUser user;

  @override
  Widget build(BuildContext context) {
    final badge = switch (user.verify) {
      DynamicVerify.personal => FollowingListTheme.badgePerson,
      DynamicVerify.organisation => FollowingListTheme.badgeOrganisation,
      DynamicVerify.none => null,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: ClipOval(child: RemoteImage.avatar(user.face))),
        if (badge != null)
          Positioned(
            right: -FollowingListTheme.badgeRing,
            bottom: -FollowingListTheme.badgeRing,
            child: Container(
              key: ValueKey('following-verified-${user.mid}'),
              width: FollowingListTheme.badge + FollowingListTheme.badgeRing * 2,
              height: FollowingListTheme.badge + FollowingListTheme.badgeRing * 2,
              padding: const EdgeInsets.all(FollowingListTheme.badgeRing),
              decoration: BoxDecoration(color: FollowingListTheme.colorsOf(context).page, shape: BoxShape.circle),
              child: CustomPaint(painter: VerifiedBoltPainter(badge)),
            ),
          ),
      ],
    );
  }
}

/// Words over a pink-ringed button, centred: a failed first page with 重试, or the account's state.
class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required super.key,
    required this.message,
    required this.action,
    required this.actionKey,
    required this.onAction,
  });

  final String message;
  final String action;
  final Key actionKey;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _line(message, followingStyle(FollowingListTheme.stateText, FollowingListTheme.colorsOf(context).stateInk)),
        const SizedBox(height: FollowingListTheme.stateGap),
        Semantics(
          button: true,
          label: action,
          onTap: onAction,
          excludeSemantics: true,
          child: GestureDetector(
            key: actionKey,
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Container(
              height: FollowingListTheme.retryHeight,
              padding: const EdgeInsets.symmetric(horizontal: FollowingListTheme.retryPadX),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: StadiumBorder(
                  side: BorderSide(color: BiliColors.colorsOf(context).pink, width: FollowingListTheme.retryRim),
                ),
              ),
              child: Text(action, style: followingStyle(FollowingListTheme.retryText, BiliColors.colorsOf(context).pink)),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Under the rows: the spinner while the next page loads, or 加载失败，点击重试.
class _Footer extends StatelessWidget {
  const _Footer({required this.loading, required this.error, required this.onRetry});

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(vertical: FollowingListTheme.footerPad);
    if (loading) {
      return const Padding(
        padding: padding,
        child: CupertinoActivityIndicator(
          key: ValueKey('following-more-spinner'),
          radius: FollowingListTheme.spinnerRadius,
        ),
      );
    }
    if (error == null) return const SizedBox.shrink();
    final style = followingStyle(FollowingListTheme.footerText, FollowingListTheme.colorsOf(context).footerInk);
    return Semantics(
      button: true,
      label: '加载失败，点击重试',
      onTap: onRetry,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('following-footer-retry'),
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: Padding(
          padding: padding,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '加载失败，', style: style),
                TextSpan(
                  text: '点击重试',
                  style: style.copyWith(color: BiliColors.colorsOf(context).link),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
