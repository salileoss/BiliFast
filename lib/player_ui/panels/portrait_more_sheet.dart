import 'dart:math' as math;

import 'package:bili_core/devlog.dart';
import 'package:bili_core/logic.dart' show QualityNames, TimeFormat;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../devtools/log_forwarder.dart';
import '../../device/orientation.dart';
import '../../offline/sheet/sheet_art.dart';
import '../../player/bili_player.dart';
import '../../shared/custom_icons.dart';
import '../../shared/theme.dart';
import '../../video/actions/video_actions.dart';
import '../../video/player_session.dart';
import '../end_screen_portrait.dart' show ShareLink, shareThroughSystem;
import '../player_ui.dart';
import 'more_panel.dart';
import 'panel_controller.dart';
import 'panel_glyphs.dart';

enum _Page { root, timer, custom, fit }

/// ⋮ in the small player and 竖屏 (42, 43): the official light sheet. Its squares, then a card of rows, each doing what
/// landscape's [MorePanel] does through [MoreRows]. KaiC's change: 42's row of share apps is one 分享 square that opens
/// the system's share sheet. Rows the app can't serve (不感兴趣, 投屏, 后台听视频, 字幕, 单双击手势, 自动上滑) toast.
class PortraitMoreSheet extends StatefulWidget {
  const PortraitMoreSheet({
    super.key,
    required this.ui,
    required this.toast,
    required this.close,
    this.devTools = devToolsEnabled,
    this.share = shareThroughSystem,
  });

  final PlayerUi ui;
  final ValueChanged<String> toast;

  /// Closes ⋮ if it is still the open panel.
  final VoidCallback close;
  final bool devTools;
  final ShareLink share;

  static const speeds = <(double, String)>[
    (0.5, '0.5'),
    (0.75, '0.75'),
    (1, '1.0'),
    (1.25, '1.25'),
    (1.5, '1.5'),
    (2, '2.0'),
    (3, '3.0'),
  ];

  @override
  State<PortraitMoreSheet> createState() => _PortraitMoreSheetState();
}

class _PortraitMoreSheetState extends State<PortraitMoreSheet> {
  var _page = _Page.root;
  var _customMinutes = 30;

  PlayerUi get _ui => widget.ui;
  PlayerSession get _session => widget.ui.session;
  MoreRows get _rows => MoreRows(session: _session, toast: widget.toast, close: widget.close);

  void _soon() => widget.toast('暂未开放');

  void _go(_Page page) => setState(() => _page = page);

  Future<void> _share() async {
    // Through the actions the page counts the share once the sheet completes it.
    if (_ui.details?.actions case final actions?) {
      widget.close();
      actions.ask(ActionPrompt.share);
      return;
    }
    final link = _session.shareLink;
    if (link == null) {
      widget.toast('视频还没有加载完');
      return;
    }
    widget.close();
    try {
      await widget.share(link);
    } catch (error) {
      Logger.shared.warn(LogCategory.ui, 'share failed', {'error': '${error.runtimeType}'});
      widget.toast('分享失败');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 220),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(
      key: ValueKey(_page),
      child: switch (_page) {
        _Page.root => _root(context),
        _Page.timer => _timer(),
        _Page.custom => _custom(),
        _Page.fit => _fit(),
      },
    ),
  );

  Widget _root(BuildContext context) {
    final vertical = _ui.presentation == Presentation.vertical;
    final session = _session;
    final rows = _rows;
    final remaining = session.sleepRemaining;
    final cards = <List<Widget>>[
      [
        _SheetRow(
          icon: PanelGlyph(PanelGlyphKind.speed, color: DownloadSheetTheme.colorsOf(context).ink),
          title: '倍速',
          overlay: _SpeedStrip(rate: session.rate, onSelect: rows.setRate),
        ),
        if (vertical)
          _ToggleRow(
            icon: PanelGlyph(PanelGlyphKind.autoplay, color: DownloadSheetTheme.colorsOf(context).ink),
            title: '自动上滑',
            value: false,
            onChanged: (_) => _soon(),
          )
        else ...[
          _ToggleRow(
            icon: PanelGlyph(PanelGlyphKind.autoplay, color: DownloadSheetTheme.colorsOf(context).ink),
            title: '自动连播',
            value: session.autoplayNext,
            onChanged: session.setAutoplayNext,
          ),
          _SheetRow(
            icon: PanelGlyph(PanelGlyphKind.loop, color: DownloadSheetTheme.colorsOf(context).ink),
            title: '循环播放',
            trailing: _Cells(
              items: [for (final mode in LoopMode.values) (mode, mode.label)],
              selected: session.loop,
              onSelect: session.setLoop,
            ),
          ),
        ],
        _SheetRow(
          key: const ValueKey('more-timer'),
          icon: PanelGlyph(PanelGlyphKind.timer, color: DownloadSheetTheme.colorsOf(context).ink),
          title: '定时关闭',
          onTap: () => _go(_Page.timer),
          trailing: ValueListenableBuilder(
            valueListenable: remaining,
            builder: (context, left, _) => _Disclosure(
              text: left == null ? null : '${TimeFormat.clock(left.inMilliseconds / 1000)} 后暂停',
              highlight: true,
            ),
          ),
        ),
        if (vertical)
          _SheetRow(
            icon: PanelGlyph(PanelGlyphKind.gesture, color: DownloadSheetTheme.colorsOf(context).ink),
            title: '单双击手势',
            onTap: _soon,
            trailing: const _Disclosure(text: '单击暂停'),
          ),
        _ToggleRow(
          icon: PanelGlyph(PanelGlyphKind.listen, color: DownloadSheetTheme.colorsOf(context).ink),
          title: '后台听视频',
          value: false,
          onChanged: (_) => _soon(),
        ),
        if (vertical)
          _SheetRow(
            key: const ValueKey('more-quality'),
            icon: PanelGlyph(PanelGlyphKind.quality, color: DownloadSheetTheme.colorsOf(context).ink),
            title: '清晰度',
            onTap: () => _ui.panels.open(PlayerPanel.quality),
            trailing: _Disclosure(
              text: QualityNames.full(
                qn: session.playingQuality,
                serverText: session.qualities.where((q) => q.id == session.playingQuality).firstOrNull?.name,
              ),
            ),
          )
        else
          _ToggleRow(
            icon: PanelGlyph(PanelGlyphKind.subtitle, color: DownloadSheetTheme.colorsOf(context).ink),
            title: '字幕',
            value: false,
            onChanged: (_) => _soon(),
          ),
        if (_ui.danmaku != null)
          _SheetRow(
            key: const ValueKey('more-danmaku-settings'),
            icon: Icon(
              CustomIcons.danmakuSettings,
              size: BiliMetrics.panelRowIcon,
              color: DownloadSheetTheme.colorsOf(context).ink,
            ),
            title: '弹幕设置',
            onTap: () => _ui.panels.open(PlayerPanel.danmakuSettings),
            trailing: const _Disclosure(),
          ),
        _ToggleRow(
          icon: PanelGlyph(PanelGlyphKind.mirror, color: DownloadSheetTheme.colorsOf(context).ink),
          title: '镜像翻转',
          value: session.mirrored,
          onChanged: rows.setMirrored,
        ),
        _SheetRow(
          key: const ValueKey('more-fit'),
          icon: PanelGlyph(PanelGlyphKind.fit, color: DownloadSheetTheme.colorsOf(context).ink),
          title: '画面尺寸',
          onTap: () => _go(_Page.fit),
          trailing: _Disclosure(text: session.fit.label),
        ),
      ],
      if (widget.devTools)
        [
          _ToggleRow(
            icon: Icon(Icons.bolt, size: BiliMetrics.panelRowIcon, color: DownloadSheetTheme.colorsOf(context).ink),
            title: 'BTR 加速',
            value: session.btr,
            onChanged: rows.setBtr,
          ),
          _ToggleRow(
            icon: Icon(Icons.bar_chart, size: BiliMetrics.panelRowIcon, color: DownloadSheetTheme.colorsOf(context).ink),
            title: '显示统计',
            value: session.showStats,
            onChanged: session.setShowStats,
          ),
        ],
    ];
    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.only(
        top: DownloadSheetTheme.tilesTop,
        bottom: MediaQuery.paddingOf(context).bottom + DownloadSheetTheme.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: DownloadSheetTheme.tileLead),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DownloadSheetTheme.tileGap,
              children: [
                _Tile(key: const ValueKey('more-dislike'), asset: SheetArt.dislike, title: '不感兴趣', onTap: _soon),
                _Tile(
                  key: const ValueKey('more-watch-later'),
                  asset: SheetArt.watchLater,
                  title: '稍后再看',
                  glyphWidth: DownloadSheetTheme.tileGlyphWide + 0.33,
                  onTap: rows.watchLater,
                ),
                // A cached video's own page plays the phone's copy: nothing to cache.
                if (!session.offline)
                  _Tile(
                    key: const ValueKey('more-download'),
                    asset: SheetArt.download,
                    title: '缓存',
                    onTap: () => _ui.panels.open(PlayerPanel.download),
                  ),
                _Tile(
                  key: const ValueKey('more-mini-player'),
                  asset: SheetArt.miniPlayer,
                  title: '小窗播放',
                  glyphWidth: DownloadSheetTheme.tileGlyphWide,
                  onTap: session.pictureInPictureSupported ? rows.pictureInPicture : null,
                ),
                _Tile(key: const ValueKey('more-cast'), asset: SheetArt.cast, title: '投屏', onTap: _soon),
                _Tile(key: const ValueKey('more-share'), asset: SheetArt.share, title: '分享', onTap: _share),
              ],
            ),
          ),
          const SizedBox(height: DownloadSheetTheme.tilesBottom - DownloadSheetTheme.tileLabelCentre * 2),
          for (final (index, rows) in cards.indexed) ...[
            if (index > 0) const SizedBox(height: DownloadSheetTheme.cardGap),
            _Card(children: rows),
          ],
        ],
      ),
    );
  }

  Widget _timer() {
    final timer = _session.sleepTimer;
    final chosen = MoreRows.sleepChoice(timer);
    return _SheetPage(
      title: '定时关闭',
      back: () => _go(_Page.root),
      rows: [
        for (final (choice, label) in MoreRows.sleepItems(timer))
          _PickRow(
            title: label,
            selected: choice == chosen,
            onTap: () {
              if (_rows.chooseSleep(choice)) {
                _go(_Page.root);
              } else {
                setState(() {
                  _customMinutes = _rows.customMinutes(_customMinutes);
                  _page = _Page.custom;
                });
              }
            },
          ),
      ],
    );
  }

  Widget _custom() => _SheetPage(
    title: '自定义定时关闭',
    back: () => _go(_Page.timer),
    rows: const [],
    below: [
      SleepWheel(initialMinutes: _customMinutes, light: true, onChanged: (minutes) => _customMinutes = minutes),
      const SizedBox(height: BiliMetrics.gutter),
      SheetTap(
        label: '确定',
        onTap: () {
          _rows.setCustomSleep(_customMinutes);
          _go(_Page.root);
        },
        child: Container(
          height: BiliMetrics.panelButtonHeight,
          margin: const EdgeInsets.symmetric(horizontal: DownloadSheetTheme.cardInset),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BiliColors.colorsOf(context).pink,
            borderRadius: BorderRadius.circular(BiliMetrics.panelButtonHeight / 2),
          ),
          child: const Text('确定', style: TextStyle(color: BiliColors.onPink)),
        ),
      ),
    ],
  );

  Widget _fit() => _SheetPage(
    title: '画面尺寸',
    back: () => _go(_Page.root),
    rows: [
      for (final mode in FitMode.values)
        _PickRow(
          title: mode.label,
          selected: _session.fit == mode,
          onTap: () {
            _rows.setFit(mode);
            _go(_Page.root);
          },
        ),
    ],
  );
}

/// A square of ⋮'s top row with its label under it.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.asset,
    required this.title,
    required this.onTap,
    this.glyphWidth = DownloadSheetTheme.tileGlyphWidth,
  });

  final String asset;
  final String title;

  /// Null greys it out, as 小窗播放 where picture in picture isn't available.
  final VoidCallback? onTap;
  final double glyphWidth;

  static TextStyle _label(BuildContext context) => TextStyle(fontSize: DownloadSheetTheme.tileLabelText, color: DownloadSheetTheme.colorsOf(context).grey);

  @override
  Widget build(BuildContext context) => SheetTap(
    label: title,
    enabled: onTap != null,
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? BiliMetrics.panelDisabledOpacity : 1,
      child: SizedBox(
        width: DownloadSheetTheme.tileSize,
        child: Column(
          children: [
            Container(
              height: DownloadSheetTheme.tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DownloadSheetTheme.colorsOf(context).card,
                borderRadius: BorderRadius.circular(DownloadSheetTheme.tileRadius),
              ),
              child: SheetIcon(asset, width: glyphWidth),
            ),
            SizedBox(
              height: DownloadSheetTheme.tileLabelCentre * 2,
              child: OverflowBox(
                maxWidth: DownloadSheetTheme.tileSize + DownloadSheetTheme.tileGap,
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    style: _label(context),
                    strutStyle: BiliFonts.strutOf(context, _label(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Rows sharing one white card, a hairline under each but the last from [inset] on.
class _Card extends StatelessWidget {
  const _Card({required this.children, this.inset = BiliMetrics.panelLabelInset});

  final List<Widget> children;
  final double inset;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: DownloadSheetTheme.cardInset),
    decoration: BoxDecoration(
      color: DownloadSheetTheme.colorsOf(context).card,
      borderRadius: BorderRadius.circular(DownloadSheetTheme.cardRadius),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, row) in children.indexed)
          index == children.length - 1
              ? row
              : DecoratedBox(position: DecorationPosition.foreground, decoration: _Hairline(inset, DownloadSheetTheme.colorsOf(context).hairline), child: row),
      ],
    ),
  );
}

/// An icon, a label and what sits at the right; a tap on the row when [onTap] is given. [overlay] fills the row from
/// beside the label (倍速's strip).
class _SheetRow extends StatelessWidget {
  const _SheetRow({super.key, required this.icon, required this.title, this.trailing, this.overlay, this.onTap});

  final Widget icon;
  final String title;
  final Widget? trailing;
  final Widget? overlay;
  final VoidCallback? onTap;

  static TextStyle _style(BuildContext context) => TextStyle(fontSize: DownloadSheetTheme.rowText, color: DownloadSheetTheme.colorsOf(context).ink);

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: DownloadSheetTheme.rowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: BiliMetrics.panelRowLead, right: BiliMetrics.panelRowTrailing),
              child: Row(
                children: [
                  SizedBox(
                    width: BiliMetrics.panelRowIcon,
                    child: Center(child: icon),
                  ),
                  const SizedBox(
                    width: BiliMetrics.panelLabelInset - BiliMetrics.panelRowLead - BiliMetrics.panelRowIcon,
                  ),
                  Text(title, maxLines: 1, style: _style(context), strutStyle: BiliFonts.strutOf(context, _style(context))),
                  Expanded(
                    child: Align(alignment: Alignment.centerRight, child: trailing),
                  ),
                ],
              ),
            ),
          ),
          if (overlay case final overlay?)
            Positioned(
              left: DownloadSheetTheme.speedStart,
              right: BiliMetrics.panelRowTrailing,
              top: 0,
              bottom: 0,
              child: overlay,
            ),
        ],
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return row;
    return SheetTap(label: title, onTap: onTap, child: row);
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.icon, required this.title, required this.value, required this.onChanged});

  final Widget icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SheetTap(
    label: title,
    toggled: value,
    onTap: () => onChanged(!value),
    child: _SheetRow(
      icon: icon,
      title: title,
      trailing: _Switch(on: value),
    ),
  );
}

/// The official switch on white: pink on, a light grey track off, the knob with a faint shadow.
class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    const inset = (BiliMetrics.panelSwitchHeight - BiliMetrics.panelSwitchKnob) / 2;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: BiliMetrics.panelSwitchWidth,
      height: BiliMetrics.panelSwitchHeight,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: on ? BiliColors.colorsOf(context).pink : DownloadSheetTheme.colorsOf(context).trackOff,
        borderRadius: BorderRadius.circular(BiliMetrics.panelSwitchHeight / 2),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: BiliMetrics.panelSwitchKnob,
          height: BiliMetrics.panelSwitchKnob,
          decoration: const BoxDecoration(
            color: BiliColors.panelKnob,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: DownloadSheetTheme.knobShadow, blurRadius: DownloadSheetTheme.knobShadowBlur)],
          ),
        ),
      ),
    );
  }
}

/// The grey detail and chevron at the right of a row that opens something; [highlight] draws the detail pink.
class _Disclosure extends StatelessWidget {
  const _Disclosure({this.text, this.highlight = false});

  final String? text;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (text case final text?) ...[
        Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: DownloadSheetTheme.detailText,
            color: highlight ? BiliColors.colorsOf(context).pink : BiliColors.colorsOf(context).secondaryText,
          ),
        ),
        const SizedBox(width: BiliMetrics.panelChevronGap),
      ],
      PanelGlyph(PanelGlyphKind.chevron, color: BiliColors.colorsOf(context).secondaryText),
      const SizedBox(width: BiliMetrics.panelChevronTrailing),
    ],
  );
}

/// Whole, since AnimatedDefaultTextStyle replaces the inherited style rather than merging into it.
TextStyle _cellStyle(BuildContext context, bool chosen) => TextStyle(
  fontFamily: BiliFonts.family,
  fontFamilyFallback: BiliFonts.fallback,
  decoration: TextDecoration.none,
  fontSize: DownloadSheetTheme.segmentText,
  color: chosen ? BiliColors.colorsOf(context).pink : DownloadSheetTheme.colorsOf(context).grey,
  fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
);

Widget _divider(BuildContext context) => Container(
  width: BiliMetrics.panelHairline,
  height: DownloadSheetTheme.segmentDivider,
  color: DownloadSheetTheme.colorsOf(context).hairline,
);

/// 循环播放's choices in cells of one width, packed to the right with hairlines between (42).
class _Cells<T> extends StatelessWidget {
  const _Cells({required this.items, required this.selected, required this.onSelect});

  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerRight,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, (value, label)) in items.indexed) ...[
          if (index > 0) _divider(context),
          SheetTap(
            label: label,
            selected: value == selected,
            onTap: () => onSelect(value),
            child: SizedBox(
              width: DownloadSheetTheme.loopCell,
              height: DownloadSheetTheme.rowHeight,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: _cellStyle(context, value == selected),
                  child: Text(label, maxLines: 1),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 倍速's values in a strip that scrolls sideways, opening at its fast end with 0.5 out of sight and 0.75 fading under
/// the label (42, 43). A slower speed chosen would be off screen there, so the strip then opens with it in view and
/// no value cut at either edge.
class _SpeedStrip extends StatefulWidget {
  const _SpeedStrip({required this.rate, required this.onSelect});

  final double rate;
  final ValueChanged<double> onSelect;

  @override
  State<_SpeedStrip> createState() => _SpeedStripState();
}

class _SpeedStripState extends State<_SpeedStrip> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  /// The offset from the fast end the strip opens at in a viewport [width] wide.
  double _opening(BuildContext context, List<(double, String)> speeds, double width) {
    const cell = DownloadSheetTheme.speedCell;
    final chosen = speeds.indexWhere((speed) => speed.$1 == widget.rate);
    if (chosen < 0) return 0;
    final scaler = MediaQuery.textScalerOf(context);
    final labels = [
      for (final (index, (value, label)) in speeds.indexed) _span(label, value == widget.rate, index, scaler),
    ];
    final clear = width - DownloadSheetTheme.speedFade;
    bool shows(double offset, (double, double) label) => label.$1 >= offset && label.$2 <= offset + clear;
    if (shows(0, labels[chosen])) return 0;
    bool cuts(double edge, (double, double) label) => label.$1 < edge && edge < label.$2;
    final extent = math.max(0.0, speeds.length * cell - width);
    final centred = ((chosen + 0.5) * cell - width / 2).clamp(0.0, extent);
    // Fewest values cut, then nearest to the chosen one centred.
    var best = centred;
    var bestScore = (cut: double.infinity, off: double.infinity);
    for (var offset = 0.0; offset <= extent; offset += 0.5) {
      if (!shows(offset, labels[chosen])) continue;
      final cut = labels.where((label) => cuts(offset, label) || cuts(offset + clear, label)).length.toDouble();
      final off = (offset - centred).abs();
      if (cut < bestScore.cut || (cut == bestScore.cut && off < bestScore.off)) {
        best = offset;
        bestScore = (cut: cut, off: off);
      }
    }
    return best;
  }

  /// Where the [index]th cell's label runs, measured from the fast end.
  (double, double) _span(String label, bool chosen, int index, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _cellStyle(context, chosen)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final centre = (index + 0.5) * DownloadSheetTheme.speedCell;
    final half = painter.width / 2;
    painter.dispose();
    return (centre - half, centre + half);
  }

  @override
  Widget build(BuildContext context) {
    final speeds = PortraitMoreSheet.speeds.reversed.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scroll = _scroll ??= ScrollController(
          initialScrollOffset: _opening(context, speeds, constraints.maxWidth),
        );
        final fade = constraints.maxWidth <= 0 ? 0.0 : DownloadSheetTheme.speedFade / constraints.maxWidth;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: const [Color(0x00000000), Color(0xFF000000)],
            stops: [0, fade.clamp(0.0, 1.0)],
          ).createShader(bounds),
          child: ListView(
            key: const ValueKey('more-speeds'),
            controller: scroll,
            primary: false,
            reverse: true,
            scrollDirection: Axis.horizontal,
            children: [
              for (final (index, (value, label)) in speeds.indexed)
                SheetTap(
                  label: '$label倍速',
                  selected: value == widget.rate,
                  onTap: () => widget.onSelect(value),
                  child: SizedBox(
                    width: DownloadSheetTheme.speedCell,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (index < speeds.length - 1) Align(alignment: Alignment.centerLeft, child: _divider(context)),
                        Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 160),
                            style: _cellStyle(context, value == widget.rate),
                            child: Text(label, maxLines: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A page inside the sheet (no screenshot): ‹ and its title, then a card of choices.
class _SheetPage extends StatelessWidget {
  const _SheetPage({required this.title, required this.back, required this.rows, this.below = const []});

  final String title;
  final VoidCallback back;
  final List<Widget> rows;
  final List<Widget> below;

  static TextStyle _title(BuildContext context) => TextStyle(fontSize: DownloadSheetTheme.pageTitleText, color: DownloadSheetTheme.colorsOf(context).ink);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    primary: false,
    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + DownloadSheetTheme.bottom),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: DownloadSheetTheme.pageHeader,
          child: Stack(
            children: [
              Center(
                child: Text(title, style: _title(context), strutStyle: BiliFonts.strutOf(context, _title(context))),
              ),
              Positioned(
                left: DownloadSheetTheme.cardInset - (BiliMetrics.panelHitBox - DownloadSheetTheme.pageBackGlyph) / 2,
                top: 0,
                bottom: 0,
                width: BiliMetrics.panelHitBox,
                child: SheetTap(
                  key: const ValueKey('more-page-back'),
                  label: '返回',
                  onTap: back,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: DownloadSheetTheme.pageBackGlyph,
                      color: DownloadSheetTheme.colorsOf(context).ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DownloadSheetTheme.cardGap),
        if (rows.isNotEmpty) _Card(inset: DownloadSheetTheme.pickerRowLead, children: rows),
        ...below,
      ],
    ),
  );
}

/// A choice on a page: its label 16 in, pink when chosen.
class _PickRow extends StatelessWidget {
  const _PickRow({required this.title, required this.selected, required this.onTap});

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: DownloadSheetTheme.rowText,
      color: selected ? BiliColors.colorsOf(context).pink : DownloadSheetTheme.colorsOf(context).ink,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );
    return SheetTap(
      label: title,
      selected: selected,
      onTap: onTap,
      child: Container(
        height: DownloadSheetTheme.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: DownloadSheetTheme.pickerRowLead),
        alignment: Alignment.centerLeft,
        child: Text(title, maxLines: 1, style: style, strutStyle: BiliFonts.strutOf(context, style)),
      ),
    );
  }
}

/// The card's hairline under a row, from [inset] to the card's right edge.
class _Hairline extends Decoration {
  const _Hairline(this.inset, this.color);

  final Color color;

  final double inset;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _HairlinePainter(inset, color);
}

class _HairlinePainter extends BoxPainter {
  _HairlinePainter(this.inset, this.color);

  final Color color;

  final double inset;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx + inset,
        offset.dy + size.height - BiliMetrics.panelHairline,
        size.width - inset,
        BiliMetrics.panelHairline,
      ),
      Paint()..color = color,
    );
  }
}
