import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import '../account/login_gate.dart';
import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../app/swipe_back_route.dart';
import '../comments/comments_tab.dart' show NearEndPaging;
import '../history/history_glyphs.dart' show HistoryBackPainter;
import '../home/feed_model.dart' show requestFailureMessage;
import '../player_ui/end_screen_portrait.dart' show ShareLink, shareThroughSystem;
import '../shared/loading_tv.dart';
import '../shared/release_refresh.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/video_route.dart';
import 'favourite_rows.dart';
import 'favourites_api.dart';
import 'favourites_glyphs.dart';
import 'favourites_model.dart';
import 'folder_page.dart';
import 'new_folder_page.dart';
import 'unfavourite_sheet.dart';

/// 收藏夹 or 视频, the chips under the bar.
enum FavouritesChip { folders, videos }

/// 收藏夹's two layouts: 80's cards with three covers each, or 99's list with one cover and ▶ 播放.
enum FavouritesLayout { cards, list }

/// The layout chosen last, kept while the app runs: 我的收藏 has no settings file to keep it in across launches.
@visibleForTesting
FavouritesLayout favouritesLayout = FavouritesLayout.cards;

/// 我的收藏 (80, 83, 84, 99), from the shortcut on the avatar page (49) and 我的 (87): 收藏 (追更 is 暂未开放), then
/// 收藏夹, the account's folders as cards or a list, or 视频, every favourite across them. A folder opens its page
/// (81); + and 新建收藏夹 open 创建 (100).
class FavouritesPage extends StatefulWidget {
  const FavouritesPage({super.key, this.api, this.loginGate, this.share = shareThroughSystem, this.open});

  /// Tests hand in their own; the app's comes from [AppScope].
  final FavouritesApi? api;

  /// Tests hand in a fake; otherwise [AppScope]'s.
  final LoginGate? loginGate;

  /// A folder's 分享; tests record it instead.
  final ShareLink share;

  /// Opens a row's video; [openVideoPage] unless a test watches it instead.
  final OpenFavourite? open;

  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
  late FavouritesApi _api;
  late AppEnvironment _environment;
  FavouriteFoldersModel? _folders;
  AllVideosModel? _videos;
  var _chip = FavouritesChip.folders;

  /// A removal in a folder since 视频 last loaded.
  bool _videosStale = false;

  /// 播放 is finding a folder's first video.
  bool _playing = false;
  final _sheet = ValueNotifier<FavouriteRow?>(null);
  late final _paging = NearEndPaging(canAsk: () => _videos?.canLoadMore ?? false, ask: () => _videos!.loadMore());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_folders != null) return;
    final services = AppScope.of(context);
    _api = widget.api ?? services.favouritesApi;
    _environment = services.environment..addListener(_accountChanged);
    _folders = FavouriteFoldersModel(api: _api, mid: () => _environment.mid, isLoggedIn: _isLoggedIn);
    unawaited(_folders!.start());
  }

  bool _isLoggedIn() => switch (_environment.account) {
    LoggedOut() || LoginExpired() => false,
    LoggedIn() || AccountUnknown() => true,
  };

  /// Logging in elsewhere (or the account check finishing) while the page asks for a login loads it.
  void _accountChanged() {
    if (_environment.account is! LoggedIn) return;
    final folders = _folders;
    if (folders != null && folders.needsLogin) unawaited(folders.reload());
    final videos = _videos;
    if (videos != null && videos.needsLogin) unawaited(videos.reload());
  }

  @override
  void dispose() {
    _environment.removeListener(_accountChanged);
    _paging.dispose();
    _sheet.dispose();
    _folders?.dispose();
    _videos?.dispose();
    super.dispose();
  }

  void _soon() => showToast(context, '暂未开放');

  void _choose(FavouritesChip chip) {
    if (chip == _chip) return;
    setState(() => _chip = chip);
    switch (chip) {
      case FavouritesChip.folders:
        unawaited(_folders!.refreshIfStale());
      case FavouritesChip.videos:
        final videos = _videos;
        if (videos == null) {
          _videos = AllVideosModel(api: _api, isLoggedIn: _isLoggedIn, onRemoved: _folders!.removedEverywhere);
          unawaited(_videos!.start());
        } else if (_videosStale) {
          unawaited(videos.reload());
        }
        _videosStale = false;
    }
  }

  Future<void> _login() async {
    final gate = widget.loginGate ?? AppScope.of(context).loginGate;
    final loggedIn = await gate.request(context);
    if (!loggedIn || !mounted) return;
    final folders = _folders!;
    if (folders.needsLogin) await folders.reload();
    final videos = _videos;
    if (videos != null && videos.needsLogin) await videos.reload();
  }

  Future<void> _refreshFolders() async {
    final message = await _folders?.reload();
    if (message != null && mounted) showToast(context, message);
  }

  Future<void> _refreshVideos() async {
    final message = await _videos?.reload();
    if (message != null && mounted) showToast(context, message);
  }

  void _toggleLayout() => setState(
    () => favouritesLayout = switch (favouritesLayout) {
      FavouritesLayout.cards => FavouritesLayout.list,
      FavouritesLayout.list => FavouritesLayout.cards,
    },
  );

  Future<void> _newFolder() async {
    if (!_isLoggedIn() || _folders!.needsLogin) {
      await _login();
      return;
    }
    var madeCover = '';
    final folder = await openNewFolder(
      context,
      create: ({required title, required intro, required isPrivate, cover = ''}) async {
        final made = await _api.createFolder(title: title, intro: intro, isPrivate: isPrivate, cover: cover);
        madeCover = cover;
        return made;
      },
      uploadCover: _api.uploadCover,
    );
    if (folder != null && mounted) _folders!.added(folder, cover: madeCover);
  }

  Future<void> _play(FavFolder folder) async {
    if (_playing) return;
    _playing = true;
    try {
      final video = await _folders!.firstVideo(folder);
      if (video != null && mounted) _openRow(FavouriteRow.fromFolder(video));
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'favourites play failed', {'error': '$error'});
      if (mounted) showToast(context, requestFailureMessage(error));
    } finally {
      _playing = false;
    }
  }

  void _openFolder(FavFolder folder) {
    final folders = _folders!;
    unawaited(
      Navigator.of(context).push(
        SwipeBackPageRoute<void>(
          builder: (_) => FolderPage(
            folder: folder,
            api: _api,
            onRemoved: (removed, newest) {
              folders.removedFrom(folder.id, removed, newest: newest);
              _videosStale = true;
            },
            loginGate: widget.loginGate,
            share: widget.share,
            open: widget.open,
          ),
        ),
      ),
    );
  }

  void _openRow(FavouriteRow row) {
    final open = widget.open;
    if (open != null) {
      open(context, row.route);
    } else {
      unawaited(openVideoPage(context, row.route));
    }
  }

  Future<void> _remove(FavouriteRow row) async {
    _sheet.value = null;
    final failure = await _videos?.remove(row);
    if (failure != null && mounted) showToast(context, failure);
  }

  @override
  Widget build(BuildContext context) {
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
        // Pushed on a plain page route with no Material above it, the words would otherwise inherit the app's
        // fallback style, a synthetic w900.
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
                    _Bar(onFollowing: _soon),
                    _ChipRow(
                      chip: _chip,
                      layout: favouritesLayout,
                      onChip: _choose,
                      onNew: () => unawaited(_newFolder()),
                      onLayout: _toggleLayout,
                      onSoon: _soon,
                    ),
                    SizedBox(
                      height: FavouritesTheme.headerHairline,
                      child: ColoredBox(color: FavouritesTheme.colorsOf(context).headerHairlineInk),
                    ),
                    Expanded(
                      child: switch (_chip) {
                        FavouritesChip.folders => _foldersView(_folders!),
                        FavouritesChip.videos => _videosView(_videos!),
                      },
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

  Widget _foldersView(FavouriteFoldersModel model) => ColoredBox(
    color: FavouritesTheme.colorsOf(context).page,
    child: ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        if (model.needsLogin) {
          return FavLoggedOut(
            key: const ValueKey('fav-folders-logged-out'),
            keyPrefix: 'fav-folders',
            onLogin: () => unawaited(_login()),
          );
        }
        if (model.folders.isEmpty) {
          final error = model.error;
          if (error != null && !model.loading) {
            return Center(
              child: FavFailed(
                key: const ValueKey('fav-folders-failed'),
                keyPrefix: 'fav-folders',
                message: error,
                onRetry: () => unawaited(model.reload()),
              ),
            );
          }
          if (!model.loaded || model.loading) {
            return const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: LoadingTvTheme.stateTop),
                child: LoadingTvState(key: ValueKey('fav-folders-loading')),
              ),
            );
          }
        }
        final folders = model.folders;
        final layout = favouritesLayout;
        return CustomScrollView(
          key: ValueKey('fav-folders-${layout.name}'),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          // Only the cards on screen are built, so only they ask for their covers.
          scrollCacheExtent: const ScrollCacheExtent.pixels(0),
          slivers: [
            ReleaseRefreshControl(onRefresh: _refreshFolders),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                FavouritesTheme.cardInset,
                FavouritesTheme.listTop,
                FavouritesTheme.cardInset,
                0,
              ),
              sliver: SliverList.separated(
                itemCount: folders.length,
                separatorBuilder: (context, index) => const SizedBox(height: FavouritesTheme.cardGap),
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return switch (layout) {
                    FavouritesLayout.cards => _FolderCard(
                      key: ValueKey('fav-folder-${folder.id}'),
                      folder: folder,
                      model: model,
                      onOpen: () => _openFolder(folder),
                    ),
                    FavouritesLayout.list => _FolderRow(
                      key: ValueKey('fav-folder-${folder.id}'),
                      folder: folder,
                      cover: model.cover(folder.id),
                      onOpen: () => _openFolder(folder),
                      onPlay: () => unawaited(_play(folder)),
                    ),
                  };
                },
              ),
            ),
            SliverToBoxAdapter(child: _NewFolder(onTap: () => unawaited(_newFolder()))),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
          ],
        );
      },
    ),
  );

  Widget _videosView(AllVideosModel model) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => _paging.listen(
      CustomScrollView(
        key: const ValueKey('fav-videos-list'),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          ReleaseRefreshControl(onRefresh: _refreshVideos),
          ...favouriteRowSlivers(
            context: context,
            model: model,
            keyPrefix: 'fav-videos',
            stateTop: LoadingTvTheme.stateTop,
            onLogin: () => unawaited(_login()),
            onOpen: _openRow,
            onMore: (row) => _sheet.value = row,
          ),
        ],
      ),
    ),
  );
}

/// ‹, then 收藏 (chosen) and 追更 (暂未开放) in the middle.
class _Bar extends StatelessWidget {
  const _Bar({required this.onFollowing});

  final VoidCallback onFollowing;

  @override
  Widget build(BuildContext context) {
    final centre = MediaQuery.sizeOf(context).width / 2 + FavouritesTheme.tabCentreShift;
    Widget tab(String key, String label, double middle, {required bool chosen, VoidCallback? onTap}) {
      final style = favStyle(
        FavouritesTheme.tabText,
        chosen ? FavouritesTheme.colorsOf(context).tabChosenInk : FavouritesTheme.colorsOf(context).tabInk,
        line: FavouritesTheme.tabLine,
      );
      final words = Center(
        child: Text(label, style: style, strutStyle: BiliFonts.strut(style)),
      );
      return Positioned(
        left: middle - FavouritesTheme.tabWidth / 2,
        width: FavouritesTheme.tabWidth,
        top: 0,
        bottom: 0,
        child: onTap == null
            ? Semantics(key: ValueKey(key), header: true, selected: chosen, child: words)
            : FavTap(key: ValueKey(key), label: label, onTap: onTap, child: words),
      );
    }

    final first = centre - FavouritesTheme.tabHalfSpacing;
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
              key: const ValueKey('fav-back'),
              label: '返回',
              onTap: () => unawaited(Navigator.of(context).maybePop()),
              child: const CustomPaint(painter: HistoryBackPainter()),
            ),
          ),
          tab('fav-tab-favourites', '收藏', first, chosen: true),
          tab('fav-tab-following', '追更', centre + FavouritesTheme.tabHalfSpacing, chosen: false, onTap: onFollowing),
          Positioned(
            left: first - FavouritesTheme.tabBarWidth / 2,
            width: FavouritesTheme.tabBarWidth,
            top: FavouritesTheme.barHeight / 2 + FavouritesTheme.tabBarCentreBelow - FavouritesTheme.tabBarHeight / 2,
            height: FavouritesTheme.tabBarHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FavouritesTheme.colorsOf(context).tabChosenInk,
                borderRadius: BorderRadius.all(Radius.circular(FavouritesTheme.tabBarRadius)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 收藏夹 and 视频 on the left; on the right 🔍, + and the layout toggle (its glyph the layout shown) for the folders,
/// 🔍 and multi-select for 视频.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.chip,
    required this.layout,
    required this.onChip,
    required this.onNew,
    required this.onLayout,
    required this.onSoon,
  });

  final FavouritesChip chip;
  final FavouritesLayout layout;
  final ValueChanged<FavouritesChip> onChip;
  final VoidCallback onNew;
  final VoidCallback onLayout;
  final VoidCallback onSoon;

  @override
  Widget build(BuildContext context) {
    Widget chipButton(FavouritesChip value, String label) {
      final chosen = value == chip;
      final style = favStyle(
        FavouritesTheme.chipText,
        chosen ? FavouritesTheme.colorsOf(context).chipChosenInk : FavouritesTheme.colorsOf(context).chipInk,
        line: FavouritesTheme.chipLine,
      );
      return FavTap(
        key: ValueKey('fav-chip-${value.name}'),
        label: label,
        selected: chosen,
        onTap: () => onChip(value),
        child: Container(
          height: FavouritesTheme.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: FavouritesTheme.chipPadX),
          decoration: chosen
              ? const BoxDecoration(
                  color: FavouritesTheme.chipChosenFill,
                  borderRadius: BorderRadius.all(Radius.circular(FavouritesTheme.chipRadius)),
                )
              : null,
          child: Center(
            widthFactor: 1,
            child: Text(label, style: style, strutStyle: BiliFonts.strut(style)),
          ),
        ),
      );
    }

    Widget tool(String key, String label, Widget glyph, {VoidCallback? onTap}) => FavTap(
      key: ValueKey(key),
      label: label,
      onTap: onTap ?? onSoon,
      child: SizedBox(
        width: FavouritesTheme.toolSlot,
        height: FavouritesTheme.chipHeight,
        child: Center(
          child: Transform.translate(offset: const Offset(0, FavouritesTheme.toolCentreDrop), child: glyph),
        ),
      ),
    );

    final search = FavGlyphIcon(
      FavGlyph.search,
      width: FavouritesTheme.toolSearch,
      height: FavouritesTheme.toolSearch,
      color: FavouritesTheme.colorsOf(context).toolInk,
    );
    final tools = switch (chip) {
      FavouritesChip.folders => [
        tool('fav-tool-search', '搜索', search),
        tool(
          'fav-tool-new',
          '新建收藏夹',
          FavGlyphIcon(
            FavGlyph.plus,
            width: FavouritesTheme.toolPlus,
            height: FavouritesTheme.toolPlus,
            color: FavouritesTheme.colorsOf(context).toolInk,
          ),
          onTap: onNew,
        ),
        tool('fav-tool-layout', '切换布局', switch (layout) {
          FavouritesLayout.cards => FavGlyphIcon(
            FavGlyph.layout,
            key: ValueKey('fav-layout-cards'),
            width: FavouritesTheme.toolLayoutWidth,
            height: FavouritesTheme.toolLayoutHeight,
            color: FavouritesTheme.colorsOf(context).toolInk,
          ),
          FavouritesLayout.list => FavGlyphIcon(
            FavGlyph.layoutList,
            key: ValueKey('fav-layout-list'),
            width: FavouritesTheme.toolLayoutListWidth,
            height: FavouritesTheme.toolLayoutListHeight,
            color: FavouritesTheme.colorsOf(context).toolInk,
          ),
        }, onTap: onLayout),
      ],
      FavouritesChip.videos => [
        tool('fav-tool-search', '搜索', search),
        tool(
          'fav-tool-select',
          '批量管理',
          FavGlyphIcon(
            FavGlyph.select,
            width: FavouritesTheme.toolListWidth,
            height: FavouritesTheme.toolListHeight,
            color: FavouritesTheme.colorsOf(context).toolInk,
          ),
        ),
      ],
    };
    return SizedBox(
      height: FavouritesTheme.chipsBand,
      child: Padding(
        padding: const EdgeInsets.only(
          top: FavouritesTheme.chipTop,
          left: FavouritesTheme.chipLeft,
          right: FavouritesTheme.toolRight,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: FavouritesTheme.chipHeight,
            child: Row(
              children: [
                chipButton(FavouritesChip.folders, '收藏夹'),
                const SizedBox(width: FavouritesTheme.chipGap),
                chipButton(FavouritesChip.videos, '视频'),
                const Spacer(),
                ...tools,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A folder's card (80): its title, the count (a lock first when private) and ›, then three covers with their titles,
/// grey where it has fewer. It asks for its covers once it is on screen.
class _FolderCard extends StatefulWidget {
  const _FolderCard({super.key, required this.folder, required this.model, required this.onOpen});

  final FavFolder folder;
  final FavouriteFoldersModel model;
  final VoidCallback onOpen;

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  bool _asking = false;

  @override
  void dispose() {
    widget.model.dropPreview(widget.folder.id);
    super.dispose();
  }

  /// Asked after the frame: the model's change would otherwise rebuild the list mid-layout.
  void _askAfterFrame() {
    if (_asking) return;
    _asking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _asking = false;
      if (mounted && widget.model.preview(widget.folder.id) == null) widget.model.wantPreview(widget.folder);
    });
  }

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;
    final preview = widget.model.preview(folder.id);
    if (preview == null) _askAfterFrame();
    final videos = switch (preview) {
      PreviewReady(:final videos) => videos,
      _ => const <FavVideo>[],
    };
    final titled = folder.count > 0;
    final title = favStyle(
      FavouritesTheme.cardTitleText,
      FavouritesTheme.colorsOf(context).cardTitleInk,
      line: FavouritesTheme.cardTitleLine,
      weight: FavouritesTheme.cardTitleWeight,
    );
    final count = favStyle(
      FavouritesTheme.cardCountText,
      FavouritesTheme.colorsOf(context).cardCountInk,
      line: FavouritesTheme.cardTitleLine,
    );
    final tileTitle = favStyle(
      FavouritesTheme.tileTitleText,
      FavouritesTheme.colorsOf(context).tileTitleInk,
      line: FavouritesTheme.tileTitleLine,
    );
    final countText = FavouriteFormat.cardCount(folder.count);
    return FavTap(
      label: '${folder.title}，${folder.isPrivate ? '私密，' : ''}$countText',
      onTap: widget.onOpen,
      child: Container(
        height:
            FavouritesTheme.tilesTop +
            FavouritesTheme.tileHeight +
            (titled ? FavouritesTheme.cardBottomTitled : FavouritesTheme.cardBottom),
        decoration: BoxDecoration(
          color: FavouritesTheme.colorsOf(context).cardFill,
          borderRadius: BorderRadius.all(Radius.circular(FavouritesTheme.cardRadius)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: FavouritesTheme.cardPad,
              right: FavouritesTheme.chevronRight,
              top: FavouritesTheme.cardTitleCentre - FavouritesTheme.cardTitleLine / 2,
              height: FavouritesTheme.cardTitleLine,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      folder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: title,
                      strutStyle: BiliFonts.strut(title),
                    ),
                  ),
                  if (folder.isPrivate) ...[
                    FavGlyphIcon(
                      FavGlyph.lock,
                      key: ValueKey('fav-card-lock'),
                      width: FavouritesTheme.lockWidth,
                      height: FavouritesTheme.lockHeight,
                      color: FavouritesTheme.colorsOf(context).cardCountInk,
                      stroke: FavouritesTheme.lockStroke,
                    ),
                    const SizedBox(width: FavouritesTheme.lockGap),
                    DecoratedBox(
                      decoration: BoxDecoration(color: FavouritesTheme.colorsOf(context).cardCountInk, shape: BoxShape.circle),
                      child: SizedBox.square(dimension: FavouritesTheme.dotSize),
                    ),
                    const SizedBox(width: FavouritesTheme.dotGap),
                  ],
                  Text(countText, style: count, strutStyle: BiliFonts.strut(count)),
                  const SizedBox(width: FavouritesTheme.chevronGap),
                  FavGlyphIcon(
                    FavGlyph.chevron,
                    width: FavouritesTheme.chevronWidth,
                    height: FavouritesTheme.chevronHeight,
                    color: FavouritesTheme.colorsOf(context).chevronInk,
                    stroke: FavouritesTheme.chevronStroke,
                  ),
                ],
              ),
            ),
            Positioned(
              left: FavouritesTheme.cardPad,
              top: FavouritesTheme.tilesTop,
              child: Row(
                children: [
                  for (var i = 0; i < FavouriteFoldersModel.previewSize; i++) ...[
                    if (i > 0) const SizedBox(width: FavouritesTheme.tileGap),
                    _Tile(video: i < videos.length ? videos[i] : null),
                  ],
                ],
              ),
            ),
            if (titled)
              Positioned(
                left: FavouritesTheme.cardPad,
                top:
                    FavouritesTheme.tilesTop +
                    FavouritesTheme.tileHeight +
                    FavouritesTheme.tileTitleCentre -
                    FavouritesTheme.tileTitleLine / 2,
                child: Row(
                  children: [
                    for (var i = 0; i < FavouriteFoldersModel.previewSize; i++) ...[
                      if (i > 0) const SizedBox(width: FavouritesTheme.tileGap),
                      SizedBox(
                        width: FavouritesTheme.tileWidth,
                        height: FavouritesTheme.tileTitleLine,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: FavouritesTheme.tileTitleInset),
                          child: i < videos.length
                              ? Text(
                                  videos[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tileTitle,
                                  strutStyle: BiliFonts.strut(tileTitle),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.video});

  final FavVideo? video;

  @override
  Widget build(BuildContext context) {
    final cover = video?.cover ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(FavouritesTheme.tileRadius),
      child: SizedBox(
        width: FavouritesTheme.tileWidth,
        height: FavouritesTheme.tileHeight,
        child: ColoredBox(
          color: FavouritesTheme.colorsOf(context).tileEmpty,
          child: cover.isEmpty
              ? null
              : RemoteImage(
                  cover,
                  size: const Size(FavouritesTheme.tileWidth, FavouritesTheme.tileHeight),
                  cover: true,
                ),
        ),
      ),
    );
  }
}

/// A folder in 99's list: its cover, the title, the count (a lock first when private) and ▶ 播放, which opens its
/// newest video; an empty folder's 播放 is pale and does nothing.
class _FolderRow extends StatelessWidget {
  const _FolderRow({super.key, required this.folder, required this.cover, required this.onOpen, required this.onPlay});

  final FavFolder folder;
  final String cover;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final title = favStyle(
      FavouritesTheme.cardTitleText,
      FavouritesTheme.colorsOf(context).cardTitleInk,
      line: FavouritesTheme.cardTitleLine,
      weight: FavouritesTheme.cardTitleWeight,
    );
    final count = favStyle(
      FavouritesTheme.cardCountText,
      FavouritesTheme.colorsOf(context).cardCountInk,
      line: FavouritesTheme.cardTitleLine,
    );
    final countText = FavouriteFormat.cardCount(folder.count);
    final playable = folder.count > 0;
    const pillTop = (FavouritesTheme.rowCardHeight - FavouritesTheme.playHeight) / 2;
    const textRight = FavouritesTheme.playRight + FavouritesTheme.playWidth + FavouritesTheme.rowTitleGap;
    final countCentre = FavouritesTheme.rowCountCentre - (folder.isPrivate ? FavouritesTheme.rowPrivateCountLift : 0);
    return SizedBox(
      height: FavouritesTheme.rowCardHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: FavTap(
              label: '${folder.title}，${folder.isPrivate ? '私密，' : ''}$countText',
              onTap: onOpen,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FavouritesTheme.colorsOf(context).cardFill,
                  borderRadius: BorderRadius.all(Radius.circular(FavouritesTheme.cardRadius)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: FavouritesTheme.cardPad,
                      top: FavouritesTheme.rowCoverTop,
                      width: FavouritesTheme.rowCoverWidth,
                      height: FavouritesTheme.rowCoverHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(FavouritesTheme.tileRadius),
                        child: ColoredBox(
                          color: FavouritesTheme.colorsOf(context).tileEmpty,
                          child: cover.isEmpty
                              ? null
                              : RemoteImage(
                                  cover,
                                  key: const ValueKey('fav-row-cover'),
                                  size: const Size(FavouritesTheme.rowCoverWidth, FavouritesTheme.rowCoverHeight),
                                  cover: true,
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: FavouritesTheme.rowTextLeft,
                      right: textRight,
                      top: FavouritesTheme.rowTitleCentre - FavouritesTheme.cardTitleLine / 2,
                      height: FavouritesTheme.cardTitleLine,
                      child: Text(
                        folder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: title,
                        strutStyle: BiliFonts.strut(title),
                      ),
                    ),
                    Positioned(
                      left: FavouritesTheme.rowTextLeft,
                      right: textRight,
                      top: countCentre - FavouritesTheme.cardTitleLine / 2,
                      height: FavouritesTheme.cardTitleLine,
                      child: Row(
                        children: [
                          if (folder.isPrivate) ...[
                            const SizedBox(width: FavouritesTheme.rowLockInset),
                            FavGlyphIcon(
                              FavGlyph.lock,
                              key: ValueKey('fav-row-lock'),
                              width: FavouritesTheme.lockWidth,
                              height: FavouritesTheme.lockHeight,
                              color: FavouritesTheme.colorsOf(context).cardCountInk,
                              stroke: FavouritesTheme.lockStroke,
                            ),
                            const SizedBox(width: FavouritesTheme.lockGap),
                            DecoratedBox(
                              decoration: BoxDecoration(color: FavouritesTheme.colorsOf(context).cardCountInk, shape: BoxShape.circle),
                              child: SizedBox.square(dimension: FavouritesTheme.dotSize),
                            ),
                            const SizedBox(width: FavouritesTheme.dotGap),
                          ],
                          Text(countText, style: count, strutStyle: BiliFonts.strut(count)),
                        ],
                      ),
                    ),
                    if (!playable)
                      const Positioned(right: FavouritesTheme.playRight, top: pillTop, child: _PlayPill(on: false)),
                  ],
                ),
              ),
            ),
          ),
          if (playable)
            Positioned(
              right: FavouritesTheme.playRight,
              top: pillTop,
              child: FavTap(
                key: ValueKey('fav-play-${folder.id}'),
                label: '播放',
                onTap: onPlay,
                child: const _PlayPill(on: true),
              ),
            ),
        ],
      ),
    );
  }
}

/// ▶ 播放, pale when [on] is false.
class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final style = favStyle(
      FavouritesTheme.playText,
      on ? FavouritesTheme.colorsOf(context).playInk : FavouritesTheme.colorsOf(context).playInkOff,
      line: FavouritesTheme.playLine,
    );
    return Container(
      width: FavouritesTheme.playWidth,
      height: FavouritesTheme.playHeight,
      padding: const EdgeInsets.only(left: FavouritesTheme.playPadLeft),
      decoration: ShapeDecoration(
        color: on ? FavouritesTheme.colorsOf(context).playFill : FavouritesTheme.colorsOf(context).playFillOff,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          FavGlyphIcon(
            FavGlyph.play,
            width: FavouritesTheme.playGlyphWidth,
            height: FavouritesTheme.playGlyphHeight,
            color: on ? FavouritesTheme.colorsOf(context).playInk : FavouritesTheme.colorsOf(context).playGlyphOff,
          ),
          const SizedBox(width: FavouritesTheme.playGap),
          Text('播放', style: style, strutStyle: BiliFonts.strut(style)),
        ],
      ),
    );
  }
}

/// + 新建收藏夹 under the last card.
class _NewFolder extends StatelessWidget {
  const _NewFolder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = favStyle(FavouritesTheme.newText, FavouritesTheme.colorsOf(context).newInk, line: FavouritesTheme.newLine);
    return Padding(
      padding: const EdgeInsets.only(top: FavouritesTheme.newGap, bottom: FavouritesTheme.newBottom),
      child: Center(
        child: FavTap(
          key: const ValueKey('fav-new-folder'),
          label: '新建收藏夹',
          onTap: onTap,
          child: Container(
            height: FavouritesTheme.newHeight,
            padding: const EdgeInsets.only(left: FavouritesTheme.newPadLeft, right: FavouritesTheme.newPadRight),
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(color: FavouritesTheme.colorsOf(context).newRimInk, width: FavouritesTheme.newRim),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FavGlyphIcon(
                  FavGlyph.plus,
                  width: FavouritesTheme.newPlus,
                  height: FavouritesTheme.newPlus,
                  color: FavouritesTheme.colorsOf(context).newInk,
                  stroke: FavouritesTheme.newPlusStroke,
                ),
                const SizedBox(width: FavouritesTheme.newPlusGap),
                Text('新建收藏夹', style: style, strutStyle: BiliFonts.strut(style)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
