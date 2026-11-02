import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../history/history_glyphs.dart';
import '../player_ui/end_screen_portrait.dart' show CountGlyph, CountPainter;
import '../shared/loading_tv.dart';
import '../shared/menu.dart' show PressHighlight;
import '../shared/remote_image.dart';
import '../shared/theme.dart';
import 'favourites_model.dart';

/// The style every word of 我的收藏 draws with; with [line] an even line box, so a line can be placed by its middle.
TextStyle favStyle(double size, Color color, {double? line, FontWeight weight = FavouritesTheme.textWeight}) =>
    TextStyle(
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

/// A tap target that VoiceOver and ghosthand can press too.
class FavTap extends StatelessWidget {
  const FavTap({super.key, required this.label, required this.onTap, required this.child, this.selected});

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool? selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
  );
}

/// The slivers of a row list under whatever the page puts above it.
List<Widget> favouriteRowSlivers({
  required BuildContext context,
  required FavouriteRowsModel model,
  required String keyPrefix,
  required double stateTop,
  required VoidCallback onLogin,
  required ValueChanged<FavouriteRow> onOpen,
  required ValueChanged<FavouriteRow> onMore,
}) {
  final bottom = MediaQuery.paddingOf(context).bottom;
  if (model.needsLogin) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: FavLoggedOut(key: ValueKey('$keyPrefix-logged-out'), keyPrefix: keyPrefix, onLogin: onLogin),
      ),
    ];
  }
  final rows = model.rows;
  if (rows.isEmpty) {
    final error = model.error;
    final Widget state;
    if (error != null && !model.loading) {
      state = Center(
        child: FavFailed(
          key: ValueKey('$keyPrefix-failed'),
          keyPrefix: keyPrefix,
          message: error,
          onRetry: model.loadMore,
        ),
      );
    } else if (model.isEnd && !model.loading) {
      state = Center(key: ValueKey('$keyPrefix-empty'), child: const FavStateText('还没有收藏内容'));
    } else {
      state = Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: stateTop),
          child: LoadingTvState(key: ValueKey('$keyPrefix-loading')),
        ),
      );
    }
    return [SliverFillRemaining(hasScrollBody: false, child: state)];
  }
  return [
    SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return FavouriteVideoRow(
          key: ValueKey('$keyPrefix-row-${row.aid}'),
          row: row,
          keyPrefix: keyPrefix,
          last: index == rows.length - 1,
          onOpen: () => onOpen(row),
          onMore: () => onMore(row),
        );
      },
    ),
    SliverToBoxAdapter(
      child: _Footer(
        keyPrefix: keyPrefix,
        loading: model.loading && !model.refreshing,
        error: model.error,
        isEnd: model.isEnd,
        onRetry: model.loadMore,
      ),
    ),
    SliverToBoxAdapter(child: SizedBox(height: bottom)),
  ];
}

/// A row (81, 83): the cover with its length and pink line, the title in up to two lines, the UP, ▶ plays and the
/// danmaku count, ⋮, and the hairline under it unless [last].
class FavouriteVideoRow extends StatelessWidget {
  const FavouriteVideoRow({
    super.key,
    required this.row,
    required this.keyPrefix,
    required this.last,
    required this.onOpen,
    required this.onMore,
  });

  final FavouriteRow row;
  final String keyPrefix;
  final bool last;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const textLeft = FavouritesTheme.gutter + FavouritesTheme.coverWidth + FavouritesTheme.textGap;
    const coverBottom = FavouritesTheme.rowPadTop + FavouritesTheme.coverHeight;
    const metaRoom = FavouritesTheme.moreCentreRight + FavouritesTheme.moreTarget / 2;
    final titleStyle = favStyle(
      FavouritesTheme.rowTitleText,
      FavouritesTheme.colorsOf(context).rowTitleInk,
      line: FavouritesTheme.rowTitleLine,
    );
    final length = row.length.isEmpty ? '' : '，${row.length}';
    return SizedBox(
      height: FavouritesTheme.rowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '${row.title}$length，${row.ownerName}，${row.plays}播放，${row.danmaku}弹幕',
              onTap: onOpen,
              excludeSemantics: true,
              child: PressHighlight(onTap: onOpen, child: const SizedBox.expand()),
            ),
          ),
          Positioned(
            left: FavouritesTheme.gutter,
            top: FavouritesTheme.rowPadTop,
            width: FavouritesTheme.coverWidth,
            height: FavouritesTheme.coverHeight,
            child: IgnorePointer(
              child: _Cover(row: row, keyPrefix: keyPrefix),
            ),
          ),
          Positioned(
            left: textLeft,
            right: FavouritesTheme.titleRight,
            top: FavouritesTheme.rowPadTop + FavouritesTheme.rowTitleTop,
            child: IgnorePointer(
              child: Text(
                row.title,
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
            top: coverBottom + FavouritesTheme.metaBottom - FavouritesTheme.metaLine * 2 - FavouritesTheme.metaGap,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaLine(children: [_glyph(const HistoryUpGlyph()), _metaText(context, row.ownerName)]),
                  const SizedBox(height: FavouritesTheme.metaGap),
                  _MetaLine(
                    children: [
                      _glyph(_count(context, CountGlyph.views)),
                      _metaText(context, row.plays, flexible: false, lift: FavouritesTheme.countLift),
                      const SizedBox(width: FavouritesTheme.countGap),
                      _glyph(_count(context, CountGlyph.danmaku)),
                      _metaText(context, row.danmaku, lift: FavouritesTheme.countLift),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: FavouritesTheme.moreCentreRight - FavouritesTheme.moreTarget / 2,
            width: FavouritesTheme.moreTarget,
            top:
                coverBottom +
                FavouritesTheme.metaBottom -
                FavouritesTheme.metaLine / 2 -
                FavouritesTheme.moreTarget / 2,
            height: FavouritesTheme.moreTarget,
            child: FavTap(
              key: ValueKey('$keyPrefix-more-${row.aid}'),
              label: '更多操作',
              onTap: onMore,
              child: const CustomPaint(painter: HistoryMorePainter()),
            ),
          ),
          if (!last)
            Positioned(
              left: FavouritesTheme.gutter,
              right: 0,
              bottom: 0,
              height: FavouritesTheme.hairline,
              child: ColoredBox(color: FavouritesTheme.colorsOf(context).divider),
            ),
        ],
      ),
    );
  }

  static Widget _count(BuildContext context, CountGlyph glyph) => Center(
    child: Transform.translate(
      offset: const Offset(0, -FavouritesTheme.countGlyphLift),
      child: CustomPaint(
        size: const Size(FavouritesTheme.countGlyphWidth, FavouritesTheme.countGlyphHeight),
        painter: CountPainter(glyph, color: FavouritesTheme.colorsOf(context).metaInk),
      ),
    ),
  );

  static Widget _glyph(Widget glyph) => Padding(
    padding: const EdgeInsets.only(right: FavouritesTheme.glyphGap),
    child: SizedBox(width: FavouritesTheme.glyphBox, height: FavouritesTheme.metaLine, child: glyph),
  );

  static Widget _metaText(BuildContext context, String text, {bool flexible = true, double lift = 0}) {
    final style = favStyle(FavouritesTheme.metaText, FavouritesTheme.colorsOf(context).metaInk, line: FavouritesTheme.metaLine);
    final words = Transform.translate(
      offset: Offset(0, -lift),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style, strutStyle: BiliFonts.strut(style)),
    );
    return flexible ? Flexible(child: words) : words;
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: FavouritesTheme.metaLine,
    child: Row(children: children),
  );
}

class _Cover extends StatelessWidget {
  const _Cover({required this.row, required this.keyPrefix});

  final FavouriteRow row;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(FavouritesTheme.coverRadius),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: FavouritesTheme.colorsOf(context).coverEmpty),
        if (row.cover.isNotEmpty)
          RemoteImage(
            row.cover,
            size: const Size(FavouritesTheme.coverWidth, FavouritesTheme.coverHeight),
            cover: true,
          ),
        if (row.length.isNotEmpty)
          Positioned(
            right: FavouritesTheme.pillRight,
            bottom: FavouritesTheme.pillBottom,
            height: FavouritesTheme.pillHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FavouritesTheme.pillFill,
                borderRadius: BorderRadius.circular(FavouritesTheme.pillRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: FavouritesTheme.pillPadX),
                child: Center(
                  widthFactor: 1,
                  child: Text(row.length, style: favStyle(FavouritesTheme.pillFont, FavouritesTheme.pillInk, line: 1)),
                ),
              ),
            ),
          ),
        if (row.progress > 0)
          Positioned(
            left: 0,
            bottom: 0,
            height: FavouritesTheme.progressHeight,
            width: math.min(row.progress, 1) * FavouritesTheme.coverWidth,
            child: DecoratedBox(
              key: ValueKey('$keyPrefix-progress-${row.aid}'),
              decoration: const BoxDecoration(
                color: FavouritesTheme.progress,
                borderRadius: BorderRadius.horizontal(right: Radius.circular(FavouritesTheme.progressRadius)),
              ),
            ),
          ),
      ],
    ),
  );
}

class FavStateText extends StatelessWidget {
  const FavStateText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center, style: favStyle(FavouritesTheme.stateText, FavouritesTheme.colorsOf(context).stateInk));
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
  Widget build(BuildContext context) => FavTap(
    label: label,
    onTap: onTap,
    child: Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padX),
      decoration: ShapeDecoration(color: BiliColors.colorsOf(context).pink, shape: StadiumBorder()),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: favStyle(text, BiliColors.onPink, weight: FavouritesTheme.buttonWeight)),
      ),
    ),
  );
}

/// Logged out, or Bilibili answered -101: 历史记录's words and 登录.
class FavLoggedOut extends StatelessWidget {
  const FavLoggedOut({super.key, required this.keyPrefix, required this.onLogin});

  final String keyPrefix;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FavStateText('登录后查看收藏'),
        const SizedBox(height: FavouritesTheme.stateGap),
        _PinkButton(
          key: ValueKey('$keyPrefix-login'),
          label: '登录',
          onTap: onLogin,
          text: FavouritesTheme.loginText,
          height: FavouritesTheme.loginHeight,
          padX: FavouritesTheme.loginPadX,
        ),
      ],
    ),
  );
}

class FavFailed extends StatelessWidget {
  const FavFailed({super.key, required this.keyPrefix, required this.message, required this.onRetry});

  final String keyPrefix;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: FavouritesTheme.gutter),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FavStateText(message),
        const SizedBox(height: FavouritesTheme.stateGap),
        _PinkButton(
          key: ValueKey('$keyPrefix-retry'),
          label: '重试',
          onTap: onRetry,
          text: FavouritesTheme.retryText,
          height: FavouritesTheme.retryHeight,
          padX: FavouritesTheme.retryPadX,
        ),
      ],
    ),
  );
}

/// Under the rows: the spinner while the next page loads, 加载失败，点击重试, or 仅展示本App中可查看的稿件 at the end.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.keyPrefix,
    required this.loading,
    required this.error,
    required this.isEnd,
    required this.onRetry,
  });

  final String keyPrefix;
  final bool loading;
  final String? error;
  final bool isEnd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(vertical: FavouritesTheme.footerPad);
    final style = favStyle(FavouritesTheme.footerText, FavouritesTheme.colorsOf(context).footerInk);
    if (error != null && !loading) {
      return FavTap(
        key: ValueKey('$keyPrefix-footer-retry'),
        label: '加载失败，点击重试',
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
      );
    }
    if (isEnd && !loading) {
      final end = favStyle(FavouritesTheme.endText, FavouritesTheme.colorsOf(context).endInk, line: FavouritesTheme.endLine);
      return Padding(
        padding: const EdgeInsets.only(top: FavouritesTheme.endTop, bottom: FavouritesTheme.endBottom),
        child: Text(
          '仅展示本App中可查看的稿件',
          key: ValueKey('$keyPrefix-end'),
          textAlign: TextAlign.center,
          style: end,
          strutStyle: BiliFonts.strut(end),
        ),
      );
    }
    return Padding(
      padding: padding,
      child: SizedBox(
        height: FavouritesTheme.spinnerRadius * 2,
        child: loading ? const CupertinoActivityIndicator(radius: FavouritesTheme.spinnerRadius) : null,
      ),
    );
  }
}
