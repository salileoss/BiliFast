import 'dart:async';
import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../account/login_gate.dart';
import '../app/app_environment.dart';
import '../app/app_scope.dart';
import '../comments/comments_tab.dart' show NearEndPaging;
import '../player_ui/end_screen_portrait.dart' show ShareLink, shareThroughSystem;
import '../shared/cover_preset.dart';
import '../shared/loading_tv.dart';
import '../shared/menu.dart';
import '../shared/release_refresh.dart';
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import '../shared/toast.dart';
import '../video/video_route.dart';
import 'history_glyphs.dart';
import 'history_model.dart';
import 'history_sheet.dart';

/// 历史记录 (28, 45-48), pushed from the shortcut on the avatar page (49) and 我的 (87): the title bar and the list
/// grouped 今天, 昨天, 更早, without the official 🔍, ⋮ and tab row (the app only plays videos). A row's ⋮ opens 48's
/// sheet over the page.
class WatchHistoryPage extends StatefulWidget {
  const WatchHistoryPage({super.key, this.model, this.loginGate, this.share = shareThroughSystem, this.open});

  /// Tests hand in their own; the app builds one over the page calls of [AppScope].
  final HistoryModel? model;

  /// Tests hand in a fake; otherwise [AppScope]'s.
  final LoginGate? loginGate;

  /// Hands 分享's link to the system share sheet; tests record it instead.
  final ShareLink share;

  /// Opens a row's video; [openVideoPage] unless a test watches it instead.
  final void Function(BuildContext context, VideoRoute route)? open;

  @override
  State<WatchHistoryPage> createState() => _WatchHistoryPageState();
}

class _WatchHistoryPageState extends State<WatchHistoryPage> {
  HistoryModel? _model;
  bool _ownsModel = false;
  AppEnvironment? _environment;
  final _menu = ValueNotifier<HistoryItem?>(null);
  late final _paging = NearEndPaging(canAsk: () => _model?.canLoadMore ?? false, ask: () => _model!.loadMore());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model != null) return;
    final given = widget.model;
    if (given != null) {
      _model = given;
    } else {
      final services = AppScope.of(context);
      final environment = services.environment;
      _environment = environment..addListener(_accountChanged);
      _ownsModel = true;
      _model = HistoryModel(
        api: services.pageApi,
        isLoggedIn: () => switch (environment.account) {
          LoggedOut() || LoginExpired() => false,
          LoggedIn() || AccountUnknown() => true,
        },
      );
    }
    unawaited(_model!.start());
  }

  /// Logging in elsewhere (or the account check finishing) while the page asks for a login loads the list.
  void _accountChanged() {
    final model = _model;
    if (model == null || !model.needsLogin) return;
    if (_environment?.account is LoggedIn) unawaited(model.reload());
  }

  @override
  void dispose() {
    _environment?.removeListener(_accountChanged);
    _paging.dispose();
    _menu.dispose();
    if (_ownsModel) _model?.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final gate = widget.loginGate ?? AppScope.of(context).loginGate;
    final loggedIn = await gate.request(context);
    // The account change has usually reloaded the list already.
    final model = _model;
    if (loggedIn && mounted && model != null && model.needsLogin) await model.reload();
  }

  Future<void> _refresh() async {
    final message = await _model?.reload();
    if (message != null && mounted) showToast(context, message);
  }

  void _openRow(HistoryItem item) {
    final route = HistoryModel.route(item);
    final open = widget.open;
    if (open != null) {
      open(context, route);
    } else {
      unawaited(openVideoPage(context, route));
    }
  }

  Future<void> _share(HistoryItem item) async {
    _menu.value = null;
    try {
      await widget.share(HistoryModel.shareLink(item));
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'history share failed', {'error': '$error'});
      if (mounted) showToast(context, '分享失败');
    }
  }

  Future<void> _delete(HistoryItem item) async {
    _menu.value = null;
    final failure = await _model?.delete(item);
    if (failure != null && mounted) showToast(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final model = _model!;
    final top = MediaQuery.paddingOf(context).top;
    return ValueListenableBuilder<HistoryItem?>(
      valueListenable: _menu,
      builder: (context, open, page) => PopScope<Object?>(
        canPop: open == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _menu.value = null;
        },
        child: page!,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: BiliPalette.of(context).isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        // Pushed on a plain page route with no Material above it, the words would otherwise inherit the app's
        // fallback style, a synthetic w900.
        child: DefaultTextStyle(
          style: _style(HistoryTheme.stateText, BiliColors.colorsOf(context).text),
          child: ColoredBox(
            color: BiliColors.colorsOf(context).card,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: top),
                    const _TitleBar(),
                    SizedBox(
                      height: HistoryTheme.barHairline,
                      child: ColoredBox(color: HistoryTheme.colorsOf(context).divider),
                    ),
                    Expanded(
                      child: ListenableBuilder(listenable: model, builder: (context, _) => _body(model)),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: HistorySheet(
                    item: _menu,
                    onShare: (item) => unawaited(_share(item)),
                    onDelete: (item) => unawaited(_delete(item)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(HistoryModel model) {
    if (model.needsLogin) return _LoggedOut(onLogin: () => unawaited(_login()));
    if (model.items.isEmpty) {
      final error = model.error;
      if (error != null && !model.loading) {
        return _Failed(message: error, onRetry: () => unawaited(model.loadMore()));
      }
      if (model.isEnd && !model.loading) {
        return const Center(key: ValueKey('history-empty'), child: _StateText('还没有看过视频'));
      }
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: LoadingTvTheme.stateTop),
          child: LoadingTvState(key: ValueKey('history-loading')),
        ),
      );
    }
    final sections = model.sections;
    return _paging.listen(
      CustomScrollView(
        key: const ValueKey('history-list'),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          ReleaseRefreshControl(onRefresh: _refresh),
          for (final section in sections)
            SliverMainAxisGroup(
              slivers: [
                SliverPersistentHeader(pinned: true, delegate: _SectionHeader(section.title)),
                SliverList.builder(
                  itemCount: section.items.length,
                  itemBuilder: (context, index) {
                    final item = section.items[index];
                    return _HistoryRow(
                      key: ValueKey('history-${item.id}'),
                      item: item,
                      time: model.timeLabel(item),
                      last: index == section.items.length - 1,
                      onOpen: () => _openRow(item),
                      onMore: () => _menu.value = item,
                    );
                  },
                ),
              ],
            ),
          SliverToBoxAdapter(
            child: _Footer(
              loading: model.loading && !model.refreshing,
              error: model.error,
              isEnd: model.isEnd,
              onRetry: () => unawaited(model.loadMore()),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

TextStyle _style(double size, Color color, {FontWeight weight = HistoryTheme.textWeight, double? height}) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  leadingDistribution: height == null ? null : TextLeadingDistribution.even,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: HistoryTheme.barHeight,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, HistoryTheme.titleDrop),
          child: Text('历史记录', style: _style(HistoryTheme.titleText, BiliColors.colorsOf(context).text, weight: HistoryTheme.titleWeight)),
        ),
        Positioned(
          left: HistoryTheme.backTipX + HistoryTheme.backWidth / 2 - HistoryTheme.backTarget / 2,
          top: 0,
          bottom: 0,
          width: HistoryTheme.backTarget,
          child: Semantics(
            button: true,
            label: '返回',
            onTap: () => unawaited(Navigator.of(context).maybePop()),
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('history-back'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(Navigator.of(context).maybePop()),
              child: CustomPaint(painter: HistoryBackPainter(colors: HistoryTheme.colorsOf(context))),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends SliverPersistentHeaderDelegate {
  const _SectionHeader(this.title);

  final String title;

  @override
  double get minExtent => HistoryTheme.headerHeight;

  @override
  double get maxExtent => HistoryTheme.headerHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(
    color: BiliColors.colorsOf(context).card,
    child: Padding(
      padding: EdgeInsets.only(left: HistoryTheme.headerInset, top: HistoryTheme.headerTextTop),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(title, style: _style(HistoryTheme.headerText, BiliColors.colorsOf(context).text, height: 1)),
      ),
    ),
  );

  @override
  bool shouldRebuild(_SectionHeader oldDelegate) => oldDelegate.title != title;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.item,
    required this.time,
    required this.last,
    required this.onOpen,
    required this.onMore,
  });

  final HistoryItem item;
  final String time;
  final bool last;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const textLeft = HistoryTheme.gutter + HistoryTheme.coverWidth + HistoryTheme.textGap;
    const coverBottom = HistoryTheme.rowPadTop + HistoryTheme.coverHeight;
    const metaRoom = HistoryTheme.moreCentreRight + HistoryTheme.moreTarget / 2;
    final titleStyle = _style(
      HistoryTheme.rowTitleText,
      HistoryTheme.colorsOf(context).rowTitle,
      height: HistoryTheme.rowTitleLine / HistoryTheme.rowTitleText,
    );
    return SizedBox(
      height: HistoryTheme.rowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '${item.title}，${item.ownerName}，${HistoryModel.progressLabel(item)}',
              onTap: onOpen,
              excludeSemantics: true,
              child: PressHighlight(onTap: onOpen, child: const SizedBox.expand()),
            ),
          ),
          Positioned(
            left: HistoryTheme.gutter,
            top: HistoryTheme.rowPadTop,
            width: HistoryTheme.coverWidth,
            height: HistoryTheme.coverHeight,
            child: IgnorePointer(child: _Cover(item: item)),
          ),
          Positioned(
            left: textLeft,
            right: HistoryTheme.titleRight,
            top: HistoryTheme.rowPadTop + HistoryTheme.rowTitleTop,
            child: IgnorePointer(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
                strutStyle: BiliFonts.strut(titleStyle),
              ),
            ),
          ),
          Positioned(
            left: textLeft,
            right: metaRoom,
            top: coverBottom + HistoryTheme.metaBottom - HistoryTheme.metaLine * 2 - HistoryTheme.metaGap,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaLine(glyph: const HistoryUpGlyph(), text: item.ownerName),
                  const SizedBox(height: HistoryTheme.metaGap),
                  _MetaLine(glyph: HistoryDeviceGlyph(item.deviceKind), text: time, spacing: HistoryTheme.timeSpacing),
                ],
              ),
            ),
          ),
          Positioned(
            right: HistoryTheme.moreCentreRight - HistoryTheme.moreTarget / 2,
            width: HistoryTheme.moreTarget,
            top: coverBottom + HistoryTheme.metaBottom - HistoryTheme.metaLine / 2 - HistoryTheme.moreTarget / 2,
            height: HistoryTheme.moreTarget,
            child: Semantics(
              button: true,
              label: '更多操作',
              onTap: onMore,
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('history-more-${item.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: CustomPaint(painter: HistoryMorePainter(colors: HistoryTheme.colorsOf(context))),
              ),
            ),
          ),
          if (!last)
            Positioned(
              left: HistoryTheme.gutter,
              right: 0,
              bottom: 0,
              height: HistoryTheme.hairline,
              child: ColoredBox(color: HistoryTheme.colorsOf(context).divider),
            ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.glyph, required this.text, this.spacing = 0});

  final Widget glyph;
  final String text;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final style = _style(
      HistoryTheme.metaText,
      HistoryTheme.colorsOf(context).meta,
      height: HistoryTheme.metaLine / HistoryTheme.metaText,
    ).copyWith(letterSpacing: spacing);
    return SizedBox(
      height: HistoryTheme.metaLine,
      child: Row(
        children: [
          SizedBox(width: HistoryTheme.glyphBox, height: HistoryTheme.metaLine, child: glyph),
          const SizedBox(width: HistoryTheme.glyphGap),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
              strutStyle: BiliFonts.strut(style),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final fraction = HistoryModel.progressFraction(item);
    return ClipRRect(
      borderRadius: BorderRadius.circular(HistoryTheme.coverRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RemoteImage(
            item.cover,
            size: const Size(HistoryTheme.coverWidth, HistoryTheme.coverHeight),
            cover: true,
            preset: CoverPreset.history,
          ),
          Positioned(
            right: HistoryTheme.pillRight,
            bottom: HistoryTheme.pillBottom,
            height: HistoryTheme.pillHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HistoryTheme.pillFill,
                borderRadius: BorderRadius.circular(HistoryTheme.pillRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: HistoryTheme.pillPadX),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    HistoryModel.progressLabel(item),
                    key: const ValueKey('history-progress'),
                    style: _style(HistoryTheme.pillFont, HistoryTheme.pillInk, height: 1),
                  ),
                ),
              ),
            ),
          ),
          if (fraction > 0)
            Positioned(
              left: 0,
              bottom: 0,
              height: HistoryTheme.progressHeight,
              width: math.max(fraction * HistoryTheme.coverWidth, HistoryTheme.progressMin),
              child: const ColoredBox(key: ValueKey('history-progress-line'), color: HistoryTheme.progress),
            ),
        ],
      ),
    );
  }
}

class _StateText extends StatelessWidget {
  const _StateText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center, style: _style(HistoryTheme.stateText, HistoryTheme.colorsOf(context).stateInk));
}

class _PinkButton extends StatelessWidget {
  const _PinkButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.text,
    required this.height,
    required this.padX,
  });

  final String label;
  final VoidCallback onTap;
  final double text;
  final double height;
  final double padX;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: padX),
        decoration: ShapeDecoration(color: BiliColors.colorsOf(context).pink, shape: StadiumBorder()),
        child: Center(
          widthFactor: 1,
          child: Text(label, style: _style(text, BiliColors.onPink, weight: HistoryTheme.buttonWeight)),
        ),
      ),
    ),
  );
}

class _LoggedOut extends StatelessWidget {
  const _LoggedOut({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('history-logged-out'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _StateText('登录后查看历史记录'),
        const SizedBox(height: HistoryTheme.stateGap),
        _PinkButton(
          key: const ValueKey('history-login'),
          label: '登录',
          onTap: onLogin,
          text: HistoryTheme.loginText,
          height: HistoryTheme.loginHeight,
          padX: HistoryTheme.loginPadX,
        ),
      ],
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('history-failed'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: HistoryTheme.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StateText(message),
          const SizedBox(height: HistoryTheme.stateGap),
          _PinkButton(
            key: const ValueKey('history-retry'),
            label: '重试',
            onTap: onRetry,
            text: HistoryTheme.retryText,
            height: HistoryTheme.retryHeight,
            padX: HistoryTheme.retryPadX,
          ),
        ],
      ),
    ),
  );
}

/// Under the list: the spinner while the next page loads, 没有更多了, or 加载失败，点击重试.
class _Footer extends StatelessWidget {
  const _Footer({required this.loading, required this.error, required this.isEnd, required this.onRetry});

  final bool loading;
  final String? error;
  final bool isEnd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(vertical: HistoryTheme.footerPad);
    final style = _style(HistoryTheme.footerText, HistoryTheme.colorsOf(context).footerInk);
    if (error != null && !loading) {
      return Semantics(
        key: const ValueKey('history-footer-retry'),
        button: true,
        label: '加载失败，点击重试',
        onTap: onRetry,
        excludeSemantics: true,
        child: GestureDetector(
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
    if (isEnd && !loading) {
      return Padding(
        padding: padding,
        child: Text('没有更多了', key: const ValueKey('history-end'), textAlign: TextAlign.center, style: style),
      );
    }
    return Padding(
      padding: padding,
      child: SizedBox(
        height: HistoryTheme.spinnerRadius * 2,
        child: loading ? const CupertinoActivityIndicator(radius: HistoryTheme.spinnerRadius) : null,
      ),
    );
  }
}
