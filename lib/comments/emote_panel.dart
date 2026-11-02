import 'dart:math' as math;

import 'package:bili_core/api.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/widgets.dart';

import '../shared/remote_image.dart';
import '../shared/theme.dart';

/// The emote panel in the keyboard's place under the composer (14, BiliNative `EmotePanel`): 最近使用 on the first
/// package, 所有表情 for the selected one, and the package tabs along the bottom. Text (颜文字) packages show their
/// emotes as text.
class EmotePanel extends StatefulWidget {
  const EmotePanel({
    super.key,
    required this.packages,
    required this.recent,
    required this.height,
    required this.bottomInset,
    required this.onPick,
    this.onRetry,
  });

  /// Null while they load or after a failure.
  final List<EmotePackage>? packages;
  final List<Emote> recent;

  /// The whole panel, tab bar and home indicator strip included.
  final double height;
  final double bottomInset;
  final ValueChanged<Emote> onPick;

  /// Set once loading failed: a tap on the message asks again.
  final VoidCallback? onRetry;

  @override
  State<EmotePanel> createState() => _EmotePanelState();
}

class _EmotePanelState extends State<EmotePanel> {
  int? _selection;

  EmotePackage? get _selected {
    final packages = widget.packages;
    if (packages == null || packages.isEmpty) return null;
    for (final package in packages) {
      if (package.id == _selection) return package;
    }
    return packages.first;
  }

  @override
  Widget build(BuildContext context) {
    final grid = math.max(0.0, widget.height - ComposerTheme.tabHeight - widget.bottomInset);
    final selected = _selected;
    return SizedBox(
      key: const ValueKey('emote-panel'),
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: grid,
            child: ColoredBox(color: ComposerTheme.colorsOf(context).panel, child: selected == null ? _state() : _content(selected)),
          ),
          SizedBox(
            height: ComposerTheme.tabHeight,
            child: ColoredBox(color: ComposerTheme.colorsOf(context).tabBar, child: selected == null ? null : _tabs(selected)),
          ),
          SizedBox(
            height: widget.bottomInset,
            child: ColoredBox(color: ComposerTheme.colorsOf(context).tabBar),
          ),
        ],
      ),
    );
  }

  Widget _state() {
    final onRetry = widget.onRetry;
    if (onRetry == null && widget.packages == null) {
      return const Center(child: CupertinoActivityIndicator(radius: ComposerTheme.spinnerRadius));
    }
    const message = '表情加载失败，点击重试';
    return Semantics(
      key: const ValueKey('emote-retry'),
      button: onRetry != null,
      label: message,
      onTap: onRetry,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: Center(
          child: Text(
            message,
            style: TextStyle(
              fontFamily: BiliFonts.family,
              fontSize: ComposerTheme.sectionFont,
              color: ComposerTheme.colorsOf(context).sectionTitle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(EmotePackage package) {
    final recent = widget.recent;
    final showsRecent = recent.isNotEmpty && package.id == widget.packages?.first.id;
    final emoteTop = (ComposerTheme.row - ComposerTheme.emote) / 2;
    return CustomScrollView(
      // Another package starts at its top.
      key: ValueKey('emote-grid-${package.id}'),
      slivers: [
        if (showsRecent) ...[
          _header('最近使用'),
          _grid(
            recent,
            columns: ComposerTheme.columns,
            rowHeight: ComposerTheme.recentRow,
            side: ComposerTheme.emote,
            top: emoteTop,
          ),
        ],
        _header('所有表情'),
        if (package.isText)
          _grid(package.emotes, columns: ComposerTheme.textColumns, rowHeight: ComposerTheme.textRow, side: 0, top: 0)
        else if (package.emotes.any((emote) => emote.large))
          _grid(
            package.emotes,
            columns: ComposerTheme.largeColumns,
            rowHeight: ComposerTheme.largeRow,
            side: ComposerTheme.largeEmote,
            top: (ComposerTheme.largeRow - ComposerTheme.largeEmote) / 2,
          )
        else
          _grid(
            package.emotes,
            columns: ComposerTheme.columns,
            rowHeight: ComposerTheme.row,
            side: ComposerTheme.emote,
            top: emoteTop,
          ),
      ],
    );
  }

  Widget _header(String title) => SliverToBoxAdapter(
    child: SizedBox(
      height: ComposerTheme.sectionHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: ComposerTheme.gutter, top: ComposerTheme.sectionTitleTop),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: TextStyle(
              fontFamily: BiliFonts.family,
              fontSize: ComposerTheme.sectionFont,
              color: ComposerTheme.colorsOf(context).sectionTitle,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _grid(
    List<Emote> emotes, {
    required int columns,
    required double rowHeight,
    required double side,
    required double top,
  }) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: ComposerTheme.gridSide),
    sliver: SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: rowHeight),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _cell(emotes[index], side: side, top: top),
        childCount: emotes.length,
      ),
    ),
  );

  Widget _cell(Emote emote, {required double side, required double top}) {
    final Widget picture;
    if (emote.url.isEmpty) {
      final style = TextStyle(
        fontFamily: BiliFonts.family,
        fontSize: ComposerTheme.kaomojiFont,
        color: ComposerTheme.colorsOf(context).kaomoji,
      );
      picture = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ComposerTheme.kaomojiPad),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              emote.token,
              maxLines: 1,
              softWrap: false,
              style: style,
              strutStyle: BiliFonts.strutOf(context, style),
            ),
          ),
        ),
      );
    } else {
      picture = Padding(
        padding: EdgeInsets.only(top: top),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox.square(
            dimension: side,
            child: RemoteImage(emote.url, fit: BoxFit.contain, placeholder: const SizedBox.shrink()),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: emote.token,
      onTap: () => widget.onPick(emote),
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => widget.onPick(emote), child: picture),
    );
  }

  Widget _tabs(EmotePackage selected) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final package in widget.packages ?? const <EmotePackage>[])
          Semantics(
            key: ValueKey('emote-tab-${package.id}'),
            button: true,
            selected: package.id == selected.id,
            label: package.name,
            onTap: () => setState(() => _selection = package.id),
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selection = package.id),
              child: Container(
                width: ComposerTheme.tabWidth,
                height: ComposerTheme.tabHeight,
                color: package.id == selected.id ? ComposerTheme.colorsOf(context).tabSelected : null,
                alignment: Alignment.center,
                child: _tabLabel(package),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _tabLabel(EmotePackage package) {
    if (!package.isText && package.icon.isNotEmpty) {
      return SizedBox.square(
        dimension: ComposerTheme.tabIcon,
        child: RemoteImage(package.icon, fit: BoxFit.contain, placeholder: const SizedBox.shrink()),
      );
    }
    final label = package.isText ? (package.emotes.firstOrNull?.token ?? package.name) : package.name;
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: ComposerTheme.kaomojiTabFont,
      color: ComposerTheme.colorsOf(context).kaomojiTab,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ComposerTheme.kaomojiTabPad),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: style,
          strutStyle: BiliFonts.strutOf(context, style),
        ),
      ),
    );
  }
}
