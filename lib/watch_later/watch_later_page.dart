import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../account/login_gate.dart';
import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../comments/comments_tab.dart' show NearEndPaging;
import '../favourites/new_folder_page.dart';
import '../shared/loading_tv.dart';
import '../shared/release_refresh.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/video_route.dart';
import 'watch_later_api.dart';
import 'watch_later_glyphs.dart';
import 'watch_later_model.dart';
import 'watch_later_row.dart';
import 'watch_later_sheets.dart';
import 'watch_later_text.dart';

/// 稍后再看 (85, 86), from the shortcut on the avatar page (49) and 我的 (87): the bar with 管理, the chips with the
/// sort and 播放全部, the list and its note, or the empty TV. 管理 opens 93's sheet, a row's ⋮ 94's; 批量管理 is the
/// edit mode (95, 96) with its bar, whose 复制到 and 移动到 open the folders (97, 98). Sheets close first on back, then
/// the edit mode.
class WatchLaterPage extends StatefulWidget {
  const WatchLaterPage({super.key, this.api, this.loginGate, this.open});

  /// Tests hand in their own; otherwise [AppScope]'s.
  final WatchLaterApi? api;
  final LoginGate? loginGate;

  /// Opens a video; [openVideoPage] unless a test watches it instead.
  final void Function(BuildContext context, VideoRoute route)? open;

  static const note = '仅展示本App中可查看的稿件';
  static const emptyMessage = '暂无稍后再看视频哦';
  static const loggedOutMessage = '登录后查看稍后再看';

  @override
  State<WatchLaterPage> createState() => _WatchLaterPageState();
}

class _WatchLaterPageState extends State<WatchLaterPage> {
  WatchLaterModel? _model;
  AppEnvironment? _environment;
  final _sheet = ValueNotifier<WatchLaterSheet?>(null);
  late final _paging = NearEndPaging(canAsk: () => _model?.canLoadMore ?? false, ask: () async => _model?.loadMore());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model != null) return;
    final services = AppScope.of(context);
    final environment = services.environment;
    _environment = environment..addListener(_accountChanged);
    _model = WatchLaterModel(
      api: widget.api ?? services.watchLaterApi,
      isLoggedIn: () => switch (environment.account) {
        LoggedOut() || LoginExpired() => false,
        LoggedIn() || AccountUnknown() => true,
      },
      accountMid: () => environment.mid,
    );
    unawaited(_model!.start());
  }

  void _accountChanged() {
    final model = _model;
    if (model == null) return;
    switch (_environment?.account) {
      case LoggedIn() when model.needsLogin:
        unawaited(model.reload());
      case LoggedOut() || LoginExpired() when !model.needsLogin:
        _sheet.value = null;
        model.signOut();
      case _:
    }
  }

  @override
  void dispose() {
    _environment?.removeListener(_accountChanged);
    _paging.dispose();
    _sheet.dispose();
    _model?.dispose();
    super.dispose();
  }

  WatchLaterModel get _m => _model!;

  LoginGate get _gate => widget.loginGate ?? AppScope.of(context).loginGate;

  Future<void> _login() async {
    final loggedIn = await _gate.request(context);
    if (loggedIn && mounted && _m.needsLogin) await _m.reload();
  }

  Future<void> _refresh() async {
    final message = await _m.reload();
    if (message != null && mounted) showToast(context, message);
  }

  void _open(WatchLaterItem item) {
    final route = WatchLaterModel.route(item);
    final open = widget.open;
    if (open != null) {
      open(context, route);
    } else {
      unawaited(openVideoPage(context, route));
    }
  }

  void _playAll() {
    if (_m.editing) return;
    final first = _m.items.firstOrNull;
    if (first != null) _open(first);
  }

  void _manage() {
    if (_m.editing) {
      _m.setEditing(false);
    } else if (_m.hasRows) {
      _sheet.value = const ManageSheet();
    }
  }

  Future<void> _clear(WatchLaterClean kind) async {
    _sheet.value = null;
    final failure = await _m.clear(kind);
    if (failure != null && mounted) showToast(context, failure);
  }

  Future<void> _remove(WatchLaterItem item) async {
    _sheet.value = null;
    final failure = await _m.remove(item);
    if (failure != null && mounted) showToast(context, failure);
  }

  Future<void> _removeChosen() async {
    final failure = await _m.removeChosen();
    if (failure != null && mounted) showToast(context, failure);
  }

  void _chooseFolder({required bool move}) {
    if (_m.chosen.isEmpty) return;
    final aid = _m.items.firstWhere((item) => _m.chosen.contains(item.aid)).aid;
    final mid = _environment?.mid;
    if (mid == null) {
      unawaited(_gate.request(context));
      return;
    }
    _sheet.value = FolderSheet(move: move, mid: mid, aid: aid);
  }

  Future<void> _send(FavFolder folder, {required bool move}) async {
    final message = await _m.sendChosen(folder, move: move);
    if (!mounted) return;
    _sheet.value = null;
    if (message != null) showToast(context, message);
  }

  Future<FavFolder?> _newFolder() {
    final services = AppScope.of(context);
    final api = widget.api ?? services.watchLaterApi;
    return openNewFolder(
      context,
      create: ({required String title, required String intro, required bool isPrivate, String cover = ''}) =>
          api.createFolder(title: title, intro: intro, isPrivate: isPrivate, cover: cover),
      uploadCover: services.favouritesApi.uploadCover,
    );
  }

  void _back() {
    if (_sheet.value != null) {
      _sheet.value = null;
    } else if (_m.editing) {
      _m.setEditing(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = _m;
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: Listenable.merge([model, _sheet]),
      builder: (context, page) => PopScope<Object?>(
        canPop: _sheet.value == null && !model.editing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: page!,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        // Pushed on a plain page route with no Material above it, the words would otherwise inherit the app's
        // fallback style, a synthetic w900.
        child: DefaultTextStyle(
          style: watchLaterStyle(WatchLaterTheme.stateText, WatchLaterTheme.colorsOf(context).ink),
          child: ColoredBox(
            color: BiliColors.colorsOf(context).card,
            child: Stack(
              children: [
                ListenableBuilder(
                  listenable: model,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: top),
                      _Bar(editing: model.editing, active: model.editing || model.hasRows, onManage: _manage),
                      _Strip(model: model, onPlayAll: _playAll),
                      SizedBox(
                        height: WatchLaterTheme.listGap,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: WatchLaterTheme.stripHairline,
                            width: double.infinity,
                            child: ColoredBox(color: WatchLaterTheme.colorsOf(context).hairlineInk),
                          ),
                        ),
                      ),
                      Expanded(child: _body(model)),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ListenableBuilder(
                    listenable: model,
                    builder: (context, _) => EditBar(
                      shown: model.editing,
                      chosen: model.chosen.length,
                      allChosen: model.allChosen,
                      onToggleAll: model.toggleAll,
                      onClearChoice: model.clearChoice,
                      onDelete: () => unawaited(_removeChosen()),
                      onCopy: () => _chooseFolder(move: false),
                      onMove: () => _chooseFolder(move: true),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SheetLayer(
                    sheet: _sheet,
                    api: widget.api ?? AppScope.of(context).watchLaterApi,
                    onClear: (kind) => unawaited(_clear(kind)),
                    onBulk: () {
                      _sheet.value = null;
                      _m.setEditing(true);
                    },
                    onRemove: (item) => unawaited(_remove(item)),
                    onSend: (folder, move) => unawaited(_send(folder, move: move)),
                    onNewFolder: _newFolder,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(WatchLaterModel model) {
    if (model.needsLogin) {
      return Center(
        key: const ValueKey('later-logged-out'),
        child: StateWithButton(
          message: WatchLaterPage.loggedOutMessage,
          button: '登录',
          buttonKey: const ValueKey('later-login'),
          onTap: () => unawaited(_login()),
        ),
      );
    }
    final items = model.items;
    if (items.isEmpty) {
      final error = model.error;
      if (error != null && !model.loading) {
        return Center(
          key: const ValueKey('later-failed'),
          child: StateWithButton(
            message: error,
            button: '重试',
            buttonKey: const ValueKey('later-retry'),
            onTap: model.retry,
          ),
        );
      }
      if (model.loaded && !model.loading) return const _Empty();
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: LoadingTvTheme.stateTop),
          child: LoadingTvState(key: ValueKey('later-loading')),
        ),
      );
    }
    final bottom = MediaQuery.paddingOf(context).bottom + (model.editing ? WatchLaterTheme.editBarHeight : 0);
    return _paging.listen(
      CustomScrollView(
        key: const ValueKey('later-list'),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          ReleaseRefreshControl(onRefresh: _refresh),
          SliverFixedExtentList.builder(
            itemExtent: WatchLaterTheme.rowHeight,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return WatchLaterRow(
                key: ValueKey('later-row-${item.bvid}'),
                item: item,
                editing: model.editing,
                chosen: model.chosen.contains(item.aid),
                onOpen: () => _open(item),
                onToggle: () => model.toggleChosen(item),
                onMore: () => _sheet.value = RowSheet(item),
              );
            },
          ),
          SliverToBoxAdapter(
            child: _Footer(
              loading: model.loading && !model.refreshing,
              error: model.error,
              hasMore: model.hasMore,
              onRetry: model.retry,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottom)),
        ],
      ),
    );
  }
}

/// ‹, 稍后再看, and 管理 (取消管理 in edit mode).
class _Bar extends StatelessWidget {
  const _Bar({required this.editing, required this.active, required this.onManage});

  final bool editing;
  final bool active;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final label = editing ? '取消管理' : '管理';
    final manage = watchLaterStyle(
      WatchLaterTheme.manageText,
      active ? WatchLaterTheme.colorsOf(context).grey : WatchLaterTheme.colorsOf(context).greyOff,
      line: WatchLaterTheme.barHeight,
    );
    void back() => unawaited(Navigator.of(context).maybePop());
    return SizedBox(
      height: WatchLaterTheme.barHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, WatchLaterTheme.titleDrop),
            child: Text(
              '稍后再看',
              style: watchLaterStyle(
                WatchLaterTheme.titleText,
                WatchLaterTheme.colorsOf(context).ink,
                weight: WatchLaterTheme.titleWeight,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: WatchLaterTheme.backTarget,
            child: Semantics(
              button: true,
              label: '返回',
              onTap: back,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('later-back'),
                behavior: HitTestBehavior.opaque,
                onTap: back,
                child: CustomPaint(painter: WatchLaterBackPainter(colors: WatchLaterTheme.colorsOf(context))),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              enabled: active,
              label: label,
              onTap: onManage,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('later-manage'),
                behavior: HitTestBehavior.opaque,
                onTap: onManage,
                child: Padding(
                  padding: const EdgeInsets.only(left: WatchLaterTheme.gutter, right: WatchLaterTheme.manageRight),
                  child: Center(
                    widthFactor: 1,
                    child: Text(label, maxLines: 1, style: manage, strutStyle: BiliFonts.strut(manage)),
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

Widget _lifted(Widget words) =>
    Transform.translate(offset: const Offset(0, -WatchLaterTheme.stripTextLift), child: words);

/// 全部 and 未看完, then ≡↑ with the order and ▶ 播放全部 at the right. The sort and 播放全部 are pale while the list is
/// empty, and everything is pale in edit mode.
class _Strip extends StatelessWidget {
  const _Strip({required this.model, required this.onPlayAll});

  final WatchLaterModel model;
  final VoidCallback onPlayAll;

  static String orderLabel(bool oldestFirst) => oldestFirst ? '最早添加' : '最近添加';

  @override
  Widget build(BuildContext context) {
    final editing = model.editing;
    final active = !editing && model.hasRows;
    final sortInk = active ? WatchLaterTheme.colorsOf(context).grey : WatchLaterTheme.colorsOf(context).greyOff;
    final playInk = active ? BiliColors.colorsOf(context).pink : WatchLaterTheme.colorsOf(context).pinkOff;
    const line = WatchLaterTheme.stripCentre * 2;
    final sort = watchLaterStyle(WatchLaterTheme.sortText, sortInk, line: line);
    final play = watchLaterStyle(WatchLaterTheme.playText, playInk, line: line);
    final order = orderLabel(model.oldestFirst);
    return SizedBox(
      height: WatchLaterTheme.stripHeight,
      child: Stack(
        children: [
          Positioned(
            left: WatchLaterTheme.gutter,
            top: WatchLaterTheme.chipTop,
            height: WatchLaterTheme.chipHeight,
            child: Row(
              spacing: WatchLaterTheme.chipGap,
              children: [
                for (final filter in WatchLaterFilter.values)
                  _Chip(
                    key: ValueKey('later-chip-${filter.name}'),
                    label: filterLabel(filter),
                    chosen: model.filter == filter,
                    editing: editing,
                    onTap: () => model.selectFilter(filter),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            height: line,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  enabled: active,
                  label: '排序：$order',
                  onTap: model.toggleOrder,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const ValueKey('later-sort'),
                    behavior: HitTestBehavior.opaque,
                    onTap: model.toggleOrder,
                    child: Row(
                      children: [
                        const SizedBox(width: WatchLaterTheme.gutter),
                        SortGlyph(color: sortInk),
                        const SizedBox(width: WatchLaterTheme.sortGlyphGap),
                        _lifted(
                          Text(
                            order,
                            key: const ValueKey('later-sort-label'),
                            maxLines: 1,
                            style: sort,
                            strutStyle: BiliFonts.strut(sort),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  enabled: active,
                  label: '播放全部',
                  onTap: onPlayAll,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const ValueKey('later-play-all'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onPlayAll,
                    child: Row(
                      children: [
                        const SizedBox(width: WatchLaterTheme.sortToPlay),
                        PlayGlyph(color: playInk),
                        const SizedBox(width: WatchLaterTheme.playGlyphGap),
                        _lifted(Text('播放全部', maxLines: 1, style: play, strutStyle: BiliFonts.strut(play))),
                        const SizedBox(width: WatchLaterTheme.playRight),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String filterLabel(WatchLaterFilter filter) => switch (filter) {
    WatchLaterFilter.all => '全部',
    WatchLaterFilter.unfinished => '未看完',
  };
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.chosen, required this.editing, required this.onTap});

  final String label;
  final bool chosen;
  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink;
    if (chosen) {
      ink = editing ? WatchLaterTheme.colorsOf(context).pinkOff : BiliColors.colorsOf(context).pink;
    } else {
      ink = editing ? WatchLaterTheme.colorsOf(context).greyOff : WatchLaterTheme.colorsOf(context).grey;
    }
    final style = watchLaterStyle(
      WatchLaterTheme.chipText,
      ink,
      line: WatchLaterTheme.chipHeight,
      weight: chosen ? WatchLaterTheme.chipChosenWeight : FontWeight.w400,
    );
    return Semantics(
      button: true,
      selected: chosen,
      enabled: !editing,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: WatchLaterTheme.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: WatchLaterTheme.chipPadX),
          decoration: chosen
              ? BoxDecoration(
                  color: editing ? WatchLaterTheme.colorsOf(context).chipChosenFillOff : WatchLaterTheme.colorsOf(context).chipChosenFill,
                  borderRadius: BorderRadius.circular(WatchLaterTheme.chipRadius),
                )
              : null,
          child: Center(
            widthFactor: 1,
            child: _lifted(Text(label, maxLines: 1, style: style, strutStyle: BiliFonts.strut(style))),
          ),
        ),
      ),
    );
  }
}

/// Under the rows: the next page's small spinner, the failure with 重试, or the note once the list is complete.
class _Footer extends StatelessWidget {
  const _Footer({required this.loading, required this.error, required this.hasMore, required this.onRetry});

  final bool loading;
  final String? error;
  final bool hasMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final style = watchLaterStyle(WatchLaterTheme.noteText, WatchLaterTheme.colorsOf(context).noteInk, line: WatchLaterTheme.noteLine);
    final Widget child;
    final error = this.error;
    if (error != null && !loading) {
      child = Semantics(
        key: const ValueKey('later-footer-retry'),
        button: true,
        label: '$error，点击重试',
        onTap: onRetry,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRetry,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$error，', style: style),
                TextSpan(
                  text: '点击重试',
                  style: style.copyWith(color: BiliColors.colorsOf(context).link),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (loading) {
      child = const CupertinoActivityIndicator(
        key: ValueKey('later-more-spinner'),
        radius: WatchLaterTheme.spinnerRadius,
      );
    } else if (!hasMore) {
      child = Text(
        WatchLaterPage.note,
        key: const ValueKey('later-note'),
        textAlign: TextAlign.center,
        maxLines: 1,
        style: style,
        strutStyle: BiliFonts.strut(style),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: WatchLaterTheme.noteTop, bottom: WatchLaterTheme.noteTop),
      child: SizedBox(
        height: WatchLaterTheme.noteLine,
        child: Center(child: child),
      ),
    );
  }
}

/// 85
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final style = watchLaterStyle(WatchLaterTheme.emptyText, WatchLaterTheme.colorsOf(context).emptyInk, line: WatchLaterTheme.noteLine);
    return Stack(
      key: const ValueKey('later-empty'),
      children: [
        const Positioned(left: WatchLaterTheme.emptyArtLeft, top: WatchLaterTheme.emptyArtTop, child: EmptyTvArt()),
        Positioned(
          left: 0,
          right: 0,
          top: WatchLaterTheme.emptyTextCentre - WatchLaterTheme.noteLine / 2,
          height: WatchLaterTheme.noteLine,
          child: Text(
            WatchLaterPage.emptyMessage,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: style,
            strutStyle: BiliFonts.strut(style),
          ),
        ),
      ],
    );
  }
}
