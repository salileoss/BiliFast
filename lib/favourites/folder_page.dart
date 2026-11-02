import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../account/login_gate.dart';
import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../comments/comments_tab.dart' show NearEndPaging;
import '../history/history_glyphs.dart' show HistoryBackPainter;
import '../player_ui/end_screen_portrait.dart' show ShareLink, shareThroughSystem;
import '../shared/action_glyphs.dart';
import '../shared/release_refresh.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/video_route.dart';
import 'favourite_rows.dart';
import 'favourites_api.dart';
import 'favourites_glyphs.dart';
import 'favourites_model.dart';
import 'unfavourite_sheet.dart';

/// Opens a row's video.
typedef OpenFavourite = void Function(BuildContext context, VideoRoute route);

/// A folder (81), from its card: the bar with 🔍, multi-select and ⋮ (all 暂未开放), the title, 创建者 and the count,
/// 点赞 and 收藏 (暂未开放) and 分享, then its videos 20 at a time. A row opens its video; its ⋮ opens 82's sheet.
class FolderPage extends StatefulWidget {
  const FolderPage({
    super.key,
    required this.folder,
    required this.api,
    this.onRemoved,
    this.loginGate,
    this.share = shareThroughSystem,
    this.open,
  });

  final FavFolder folder;
  final FavouritesApi api;

  /// Told when a video left this folder, with the newest left, so the folder list follows.
  final void Function(FavouriteRow removed, FavouriteRow? newest)? onRemoved;

  /// Tests hand in a fake; otherwise [AppScope]'s.
  final LoginGate? loginGate;

  /// Hands 分享's link to the system share sheet; tests record it instead.
  final ShareLink share;

  /// [openVideoPage] unless a test watches it instead.
  final OpenFavourite? open;

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  FolderVideosModel? _model;
  AppEnvironment? _environment;
  final _sheet = ValueNotifier<FavouriteRow?>(null);
  late final _paging = NearEndPaging(canAsk: () => _model?.canLoadMore ?? false, ask: () => _model!.loadMore());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model != null) return;
    final environment = AppScope.of(context).environment;
    _environment = environment..addListener(_accountChanged);
    _model = FolderVideosModel(
      api: widget.api,
      folder: widget.folder,
      onRemoved: widget.onRemoved,
      isLoggedIn: () => switch (environment.account) {
        LoggedOut() || LoginExpired() => false,
        _ => true,
      },
    );
    unawaited(_model!.start());
  }

  void _accountChanged() {
    final model = _model;
    if (model == null || !model.needsLogin) return;
    if (_environment?.account is LoggedIn) unawaited(model.reload());
  }

  @override
  void dispose() {
    _environment?.removeListener(_accountChanged);
    _paging.dispose();
    _sheet.dispose();
    _model?.dispose();
    super.dispose();
  }

  void _soon() => showToast(context, '暂未开放');

  Future<void> _login() async {
    final gate = widget.loginGate ?? AppScope.of(context).loginGate;
    final loggedIn = await gate.request(context);
    final model = _model;
    if (loggedIn && mounted && model != null && model.needsLogin) await model.reload();
  }

  Future<void> _refresh() async {
    final message = await _model?.reload();
    if (message != null && mounted) showToast(context, message);
  }

  void _open(FavouriteRow row) {
    final open = widget.open;
    if (open != null) {
      open(context, row.route);
    } else {
      unawaited(openVideoPage(context, row.route));
    }
  }

  Future<void> _remove(FavouriteRow row) async {
    _sheet.value = null;
    final failure = await _model?.remove(row);
    if (failure != null && mounted) showToast(context, failure);
  }

  Future<void> _share() async {
    try {
      await widget.share(FavouriteFormat.folderLink(widget.folder.id));
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'favourites share failed', {'error': '$error'});
      if (mounted) showToast(context, '分享失败');
    }
  }

  String get _owner {
    final named = _model?.info.ownerName ?? '';
    if (named.isNotEmpty) return named;
    // Only the account's own folders are listed, so before the first page the creator is the account.
    return switch (_environment?.account) {
      LoggedIn(:final name) => name,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final model = _model!;
    final top = MediaQuery.paddingOf(context).top;
    return ValueListenableBuilder<FavouriteRow?>(
      valueListenable: _sheet,
      builder: (context, open, page) => PopScope<Object?>(
        canPop: open == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _sheet.value = null;
        },
        child: page!,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: DefaultTextStyle(
          style: favStyle(FavouritesTheme.stateText, BiliColors.colorsOf(context).text),
          child: ColoredBox(
            color: BiliColors.colorsOf(context).card,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: top),
                    _FolderBar(onSoon: _soon),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: model,
                        builder: (context, _) => _paging.listen(
                          CustomScrollView(
                            key: const ValueKey('fav-folder-list'),
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            slivers: [
                              ReleaseRefreshControl(onRefresh: _refresh),
                              SliverToBoxAdapter(
                                child: _FolderHeader(
                                  info: model.info,
                                  owner: _owner,
                                  onSoon: _soon,
                                  onShare: () => unawaited(_share()),
                                ),
                              ),
                              ...favouriteRowSlivers(
                                context: context,
                                model: model,
                                keyPrefix: 'fav-folder',
                                stateTop: LoadingTvTheme.stateTop - FavouritesTheme.folderHeader,
                                onLogin: () => unawaited(_login()),
                                onOpen: _open,
                                onMore: (row) => _sheet.value = row,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: UnfavouriteSheet(row: _sheet, onRemove: (row) => unawaited(_remove(row))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ‹, then 🔍, multi-select and ⋮ on the right, all 暂未开放.
class _FolderBar extends StatelessWidget {
  const _FolderBar({required this.onSoon});

  final VoidCallback onSoon;

  @override
  Widget build(BuildContext context) {
    const slot = FavouritesTheme.folderToolSlot;
    Widget tool(String key, String label, double centreRight, Widget glyph) => Positioned(
      right: centreRight - slot / 2,
      width: slot,
      top: 0,
      bottom: 0,
      child: FavTap(
        key: ValueKey(key),
        label: label,
        onTap: onSoon,
        child: Center(
          child: Transform.translate(offset: const Offset(0, FavouritesTheme.folderToolDrop), child: glyph),
        ),
      ),
    );
    return SizedBox(
      height: FavouritesTheme.barHeight,
      child: Stack(
        children: [
          Positioned(
            left: FavouritesTheme.backTipX + FavouritesTheme.backWidth / 2 - FavouritesTheme.backTarget / 2,
            top: 0,
            bottom: 0,
            width: FavouritesTheme.backTarget,
            child: FavTap(
              key: const ValueKey('fav-folder-back'),
              label: '返回',
              onTap: () => unawaited(Navigator.of(context).maybePop()),
              child: const CustomPaint(painter: HistoryBackPainter()),
            ),
          ),
          tool(
            'fav-folder-search',
            '搜索',
            FavouritesTheme.folderSearchRight,
            FavGlyphIcon(
              FavGlyph.search,
              width: FavouritesTheme.folderSearch,
              height: FavouritesTheme.folderSearch,
              color: FavouritesTheme.colorsOf(context).folderBarInk,
              stroke: FavouritesTheme.folderBarStroke,
            ),
          ),
          tool(
            'fav-folder-select',
            '批量管理',
            FavouritesTheme.folderSelectRight,
            FavGlyphIcon(
              FavGlyph.select,
              width: FavouritesTheme.folderSelectWidth,
              height: FavouritesTheme.folderSelectHeight,
              color: FavouritesTheme.colorsOf(context).folderBarInk,
              stroke: FavouritesTheme.folderBarStroke,
            ),
          ),
          tool(
            'fav-folder-more',
            '更多',
            FavouritesTheme.folderMoreRight,
            FavGlyphIcon(
              FavGlyph.more,
              width: FavouritesTheme.folderMoreDot,
              height: FavouritesTheme.folderMoreDot + FavouritesTheme.folderMorePitch * 2,
              color: FavouritesTheme.colorsOf(context).folderBarInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// The title, 创建者 and the count on the left; 点赞, 收藏 and 分享 on the right.
class _FolderHeader extends StatelessWidget {
  const _FolderHeader({required this.info, required this.owner, required this.onSoon, required this.onShare});

  final FavFolderInfo info;
  final String owner;
  final VoidCallback onSoon;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final title = favStyle(FavouritesTheme.folderTitleText, BiliColors.colorsOf(context).text, line: FavouritesTheme.folderTitleLine);
    final meta = favStyle(
      FavouritesTheme.folderMetaText,
      FavouritesTheme.colorsOf(context).folderMetaInk,
      line: FavouritesTheme.folderMetaLine,
    );
    final label = favStyle(
      FavouritesTheme.folderActionText,
      FavouritesTheme.colorsOf(context).folderActionLabelInk,
      line: FavouritesTheme.folderActionLine,
    );
    final textRight = FavouritesTheme.folderActionRights.first + FavouritesTheme.folderActionWidth / 2;
    Widget line(String text, TextStyle style, double centre, {Key? key}) => Positioned(
      left: FavouritesTheme.folderInset,
      right: textRight,
      top: centre - style.height! * style.fontSize! / 2,
      child: Text(
        text,
        key: key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
        strutStyle: BiliFonts.strut(style),
      ),
    );
    Widget action(int index, String name, String key, Widget glyph, VoidCallback onTap) {
      final centreRight = FavouritesTheme.folderActionRights[index];
      return Positioned(
        right: centreRight - FavouritesTheme.folderActionWidth / 2,
        width: FavouritesTheme.folderActionWidth,
        top: 0,
        bottom: 0,
        child: FavTap(
          key: ValueKey(key),
          label: name,
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: FavouritesTheme.folderActionGlyphCentre - FavouritesTheme.folderActionWidth / 2,
                height: FavouritesTheme.folderActionWidth,
                child: Center(child: glyph),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: FavouritesTheme.folderActionLabelCentre - FavouritesTheme.folderActionLine / 2,
                child: Text(name, textAlign: TextAlign.center, style: label, strutStyle: BiliFonts.strut(label)),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: FavouritesTheme.folderHeader,
      child: Stack(
        children: [
          line(info.title, title, FavouritesTheme.folderTitleCentre, key: const ValueKey('fav-folder-title')),
          line('创建者：$owner', meta, FavouritesTheme.folderOwnerCentre, key: const ValueKey('fav-folder-owner')),
          line(
            FavouriteFormat.folderCount(info.count),
            meta,
            FavouritesTheme.folderCountCentre,
            key: const ValueKey('fav-folder-count'),
          ),
          action(
            0,
            '点赞',
            'fav-folder-like',
            ActionIcon(
              ActionGlyph.like,
              solid: true,
              size: FavouritesTheme.folderLikeInk / ActionIcon.inkShare,
              color: FavouritesTheme.colorsOf(context).folderActionInk,
            ),
            onSoon,
          ),
          action(
            1,
            '收藏',
            'fav-folder-favourite',
            Transform.translate(
              offset: const Offset(0, FavouritesTheme.folderAddDrop),
              child: FavGlyphIcon(
                FavGlyph.folderAdd,
                width: FavouritesTheme.folderAddWidth,
                height: FavouritesTheme.folderAddHeight,
                color: FavouritesTheme.colorsOf(context).folderActionFaint,
                stroke: FavouritesTheme.folderAddStroke,
              ),
            ),
            onSoon,
          ),
          action(
            2,
            '分享',
            'fav-folder-share',
            ActionIcon(
              ActionGlyph.share,
              solid: true,
              size: FavouritesTheme.folderShareInk / ActionIcon.inkShare,
              color: FavouritesTheme.colorsOf(context).folderActionInk,
            ),
            onShare,
          ),
        ],
      ),
    );
  }
}
