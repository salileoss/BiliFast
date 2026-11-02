import 'package:bili_core/danmaku.dart' show DanmakuFilterOptions;
import 'package:flutter/widgets.dart';

import '../../danmaku/danmaku_settings.dart';
import '../../danmaku/danmaku_settings_store.dart';
import '../../shared/theme.dart';
import '../player_ui.dart';
import 'danmaku_panel_glyphs.dart';
import 'panel_controller.dart';
import 'panel_parts.dart';

/// A question a panel asks before it acts (33), which the panel layer draws over the whole screen.
@immutable
final class PanelConfirm {
  const PanelConfirm({required this.title, required this.cancel, required this.confirm, required this.onConfirm});

  final String title;
  final String cancel;
  final String confirm;
  final VoidCallback onConfirm;
}

/// 弹幕设置 (port of BiliNative `DanmakuSettingsPanel.swift`): a right-side strip in landscape (07, 08, 24, 29), the
/// light sheet in portrait (40, 41), each change showing at once through `ui.danmaku.settings`.
class DanmakuSettingsPanel extends StatefulWidget {
  const DanmakuSettingsPanel({
    super.key,
    required this.ui,
    required this.light,
    required this.toast,
    required this.close,
    required this.confirm,
  });

  final PlayerUi ui;

  /// Portrait's light sheet.
  final bool light;
  final ValueChanged<String> toast;
  final VoidCallback close;

  /// Asks before 重置弹幕设置.
  final ValueChanged<PanelConfirm> confirm;

  static const portraitSoon = '人像防挡将在后续版本推出';

  @override
  State<DanmakuSettingsPanel> createState() => _DanmakuSettingsPanelState();
}

/// The colours of the dark strip or the light sheet.
@immutable
final class _Look {
  const _Look.dark()
    : card = DanmakuPanelTheme.card,
      square = DanmakuPanelTheme.square,
      track = DanmakuPanelTheme.track,
      fill = BiliColors.pink,
      thumb = DanmakuPanelTheme.text,
      dot = DanmakuPanelTheme.text,
      hairline = DanmakuPanelTheme.hairline,
      text = DanmakuPanelTheme.text,
      value = DanmakuPanelTheme.value,
      secondary = DanmakuPanelTheme.secondary,
      reset = DanmakuPanelTheme.reset,
      switchOff = BiliColors.panelTrackOff,
      knobShadow = null;

  _Look.light(BuildContext context)
    : card = DanmakuPanelTheme.colorsOf(context).lightCard,
      square = DanmakuPanelTheme.colorsOf(context).lightSquare,
      track = DanmakuPanelTheme.colorsOf(context).lightTrack,
      fill = DanmakuPanelTheme.colorsOf(context).lightFill,
      thumb = BiliColors.colorsOf(context).pink,
      dot = BiliColors.colorsOf(context).pink,
      hairline = DanmakuPanelTheme.colorsOf(context).lightHairline,
      text = DanmakuPanelTheme.colorsOf(context).lightText,
      value = DanmakuPanelTheme.colorsOf(context).lightText,
      secondary = DanmakuPanelTheme.colorsOf(context).lightSecondary,
      reset = DanmakuPanelTheme.colorsOf(context).lightReset,
      switchOff = DanmakuPanelTheme.colorsOf(context).lightSwitchOff,
      knobShadow = DanmakuPanelTheme.lightKnobShadow;

  final Color card;
  final Color square;
  final Color track;
  final Color fill;
  final Color thumb;
  final Color dot;
  final Color hairline;
  final Color text;
  final Color value;
  final Color secondary;
  final Color reset;
  final Color switchOff;
  final Color? knobShadow;
}

enum _BlockType {
  fixed('固定', DanmakuGlyphKind.fixed),
  scroll('滚动', DanmakuGlyphKind.scroll),
  colored('彩色', DanmakuGlyphKind.colored),
  advanced('高级', DanmakuGlyphKind.advanced),
  count('计数', DanmakuGlyphKind.count);

  const _BlockType(this.title, this.glyph);

  final String title;
  final DanmakuGlyphKind glyph;

  bool of(DanmakuFilterOptions filter) => switch (this) {
    fixed => filter.blockFixed,
    scroll => filter.blockScroll,
    colored => filter.blockColored,
    advanced => filter.blockAdvanced,
    count => filter.blockCount,
  };

  DanmakuFilterOptions set(DanmakuFilterOptions filter, bool on) => switch (this) {
    fixed => filter.copyWith(blockFixed: on),
    scroll => filter.copyWith(blockScroll: on),
    colored => filter.copyWith(blockColored: on),
    advanced => filter.copyWith(blockAdvanced: on),
    count => filter.copyWith(blockCount: on),
  };
}

class _DanmakuSettingsPanelState extends State<DanmakuSettingsPanel> {
  /// 查看更多 adds 字体大小 and 弹幕速度 to the landscape card until the panel closes.
  bool _expanded = false;

  bool get _light => widget.light;

  _Look get _look => _light ? _Look.light(context) : const _Look.dark();

  @override
  Widget build(BuildContext context) {
    final danmaku = widget.ui.danmaku;
    if (danmaku == null) return const SizedBox.shrink();
    final body = ValueListenableBuilder(
      valueListenable: danmaku.settings,
      builder: (context, settings, _) => _page(context, danmaku.settings, settings),
    );
    if (!_light) {
      return Padding(
        padding: const EdgeInsets.only(left: DanmakuPanelTheme.inset),
        child: body,
      );
    }
    final insets = MediaQuery.paddingOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: DanmakuPanelTheme.sheetTop),
      child: SingleChildScrollView(
        key: const ValueKey('danmaku-settings-scroll'),
        padding: EdgeInsets.only(
          left: insets.left + DanmakuPanelTheme.inset,
          right: insets.right + DanmakuPanelTheme.inset,
          bottom: insets.bottom,
        ),
        child: body,
      ),
    );
  }

  Widget _page(BuildContext context, DanmakuSettingsStore store, DanmakuSettings settings) {
    final look = _look;
    void filter(DanmakuFilterOptions next) => store.update(settings.copyWith(filter: next));
    final options = settings.filter;
    final full = !_light;
    const areas = DanmakuSettings.areas;
    const speeds = DanmakuSettings.speedNames;
    double area(double position) => areas[(position * (areas.length - 1)).round()];
    double opacity(double position) => _hundredths(DanmakuSettings.minOpacity, DanmakuSettings.maxOpacity, position);
    double scale(double position) => _hundredths(DanmakuSettings.minScale, DanmakuSettings.maxScale, position);
    int speed(double position) => (position * (speeds.length - 1)).round();
    final sliders = <Widget>[
      if (full)
        _SliderRow(
          title: '显示区域',
          describe: (position) => _percent(area(position)),
          look: look,
          stops: areas.length,
          position: _nearest(areas, settings.area) / (areas.length - 1),
          onChanged: (position) {
            if (area(position) != settings.area) store.update(settings.copyWith(area: area(position)));
          },
        ),
      _SliderRow(
        title: '不透明度',
        describe: (position) => _percent(opacity(position)),
        look: look,
        divider: _light || _expanded,
        position: _share(settings.opacity, DanmakuSettings.minOpacity, DanmakuSettings.maxOpacity),
        onChanged: (position) {
          if (opacity(position) != settings.opacity) store.update(settings.copyWith(opacity: opacity(position)));
        },
      ),
      if (_light || _expanded) ...[
        _Appear(
          animate: !_light,
          child: _SliderRow(
            title: '字体大小',
            describe: (position) => _percent(scale(position)),
            look: look,
            divider: true,
            position: _share(settings.scale, DanmakuSettings.minScale, DanmakuSettings.maxScale),
            onChanged: (position) {
              if (scale(position) != settings.scale) store.update(settings.copyWith(scale: scale(position)));
            },
          ),
        ),
        _Appear(
          animate: !_light,
          child: _SliderRow(
            title: '弹幕速度',
            describe: (position) => speeds[speed(position)],
            look: look,
            stops: speeds.length,
            position: settings.speed.clamp(0, speeds.length - 1) / (speeds.length - 1),
            onChanged: (position) {
              if (speed(position) != settings.speed) store.update(settings.copyWith(speed: speed(position)));
            },
          ),
        ),
      ],
    ];
    final sliderColumn = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sliders);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelReveal(order: 0, child: _header(context, look)),
        PanelReveal(
          order: 1,
          child: _Card(
            look: look,
            // AnimatedSize throws on a zero duration, so Reduce Motion leaves it out.
            child: MediaQuery.disableAnimationsOf(context)
                ? sliderColumn
                : AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: sliderColumn,
                  ),
          ),
        ),
        PanelReveal(order: 2, child: _Section('画面防挡', look: look)),
        PanelReveal(
          order: 3,
          child: _Card(
            look: look,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _typeBlock(look, options, filter),
                _ToggleRow(
                  title: '重复弹幕隐藏',
                  subtitle: '大量内容相同的弹幕会被隐藏',
                  look: look,
                  on: options.dedupe,
                  onTap: () => filter(options.copyWith(dedupe: !options.dedupe)),
                ),
                if (full)
                  _ToggleRow(
                    title: '底部字幕区域防挡',
                    subtitle: '底部弹幕会被隐藏',
                    look: look,
                    on: options.hideBottom,
                    onTap: () => filter(options.copyWith(hideBottom: !options.hideBottom)),
                  ),
                _ToggleRow(
                  title: '人像防挡',
                  subtitle: '人像不被弹幕遮挡，部分视频生效',
                  look: look,
                  on: false,
                  divider: false,
                  onTap: () => widget.toast(DanmakuSettingsPanel.portraitSoon),
                ),
              ],
            ),
          ),
        ),
        PanelReveal(order: 4, child: _Section('更多工具', look: look)),
        PanelReveal(
          order: 5,
          child: _Card(
            look: look,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToggleRow(
                  title: '弹幕观看屏蔽词',
                  subtitle: '仅对我不展示特定弹幕',
                  look: look,
                  on: options.applyRules,
                  divider: false,
                  onTap: () => filter(options.copyWith(applyRules: !options.applyRules)),
                ),
                if (full) ...[
                  _blockWordsButton(look),
                  Container(
                    height: DanmakuPanelTheme.buttonGap,
                    foregroundDecoration: _HairlineDecoration(look.hairline),
                  ),
                  _listRow(look),
                ],
              ],
            ),
          ),
        ),
        PanelReveal(order: 6, child: _resetRow(look, store)),
      ],
    );
  }

  Widget _header(BuildContext context, _Look look) {
    final style = TextStyle(fontSize: DanmakuPanelTheme.titleText, fontWeight: FontWeight.w600, color: look.text);
    return SizedBox(
      height: DanmakuPanelTheme.headerHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: DanmakuPanelTheme.headerCentre - BiliMetrics.panelHitBox / 2,
            height: BiliMetrics.panelHitBox,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('弹幕设置', style: style),
            ),
          ),
          if (!_light)
            Positioned(
              right: 0,
              top: DanmakuPanelTheme.headerCentre - BiliMetrics.panelHitBox / 2,
              height: BiliMetrics.panelHitBox,
              child: AnimatedSwitcher(
                duration: _motion(context, const Duration(milliseconds: 200)),
                child: _expanded ? const SizedBox.shrink() : _more(look),
              ),
            ),
        ],
      ),
    );
  }

  Widget _more(_Look look) => Semantics(
    button: true,
    label: '查看更多',
    onTap: _expand,
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('danmaku-more'),
      behavior: HitTestBehavior.opaque,
      onTap: _expand,
      child: Padding(
        padding: const EdgeInsets.only(left: DanmakuPanelTheme.inset, right: DanmakuPanelTheme.moreTrailing),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '查看更多',
              style: TextStyle(fontSize: DanmakuPanelTheme.detailText, color: look.secondary),
            ),
            const SizedBox(width: DanmakuPanelTheme.moreGap),
            DanmakuPanelGlyph(DanmakuGlyphKind.chevronDown, color: look.secondary),
          ],
        ),
      ),
    ),
  );

  void _expand() => setState(() => _expanded = true);

  Widget _typeBlock(_Look look, DanmakuFilterOptions options, ValueChanged<DanmakuFilterOptions> filter) => Container(
    height: DanmakuPanelTheme.typeBlock,
    foregroundDecoration: _HairlineDecoration(look.hairline),
    child: Stack(
      children: [
        Positioned(
          left: DanmakuPanelTheme.inset,
          right: DanmakuPanelTheme.inset,
          top: DanmakuPanelTheme.typeLabelCentre - DanmakuPanelTheme.labelBox / 2,
          height: DanmakuPanelTheme.labelBox,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '按弹幕类型屏蔽',
              style: TextStyle(fontSize: DanmakuPanelTheme.detailText, color: look.text),
            ),
          ),
        ),
        Positioned(
          left: DanmakuPanelTheme.inset,
          right: DanmakuPanelTheme.inset,
          top: DanmakuPanelTheme.squareTop,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DanmakuPanelTheme.squareGap,
            children: [
              for (final type in _BlockType.values)
                Expanded(
                  child: _TypeButton(
                    type: type,
                    look: look,
                    blocked: type.of(options),
                    onTap: () => filter(type.set(options, !type.of(options))),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _blockWordsButton(_Look look) {
    void open() {
      final danmaku = widget.ui.danmaku;
      if (danmaku == null) return;
      if (!danmaku.loggedIn) {
        danmaku.requestLogin();
        return;
      }
      widget.ui.panels.open(PlayerPanel.blockWords);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DanmakuPanelTheme.inset),
      child: Semantics(
        button: true,
        label: '添加屏蔽词',
        onTap: open,
        excludeSemantics: true,
        child: PanelPressable(
          key: const ValueKey('danmaku-block-words'),
          onTap: open,
          radius: DanmakuPanelTheme.buttonRadius,
          child: Container(
            height: DanmakuPanelTheme.buttonHeight,
            decoration: BoxDecoration(
              color: look.square,
              borderRadius: BorderRadius.circular(DanmakuPanelTheme.buttonRadius),
            ),
            child: Row(
              children: [
                const SizedBox(width: DanmakuPanelTheme.buttonTextInset),
                Text(
                  '添加屏蔽词',
                  style: TextStyle(fontSize: DanmakuPanelTheme.detailText, color: look.text),
                ),
                const Spacer(),
                DanmakuPanelGlyph(DanmakuGlyphKind.buttonChevron, color: look.secondary),
                const SizedBox(width: DanmakuPanelTheme.buttonChevronTrailing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _listRow(_Look look) {
    void open() => widget.ui.panels.open(PlayerPanel.danmakuList);
    return Semantics(
      button: true,
      label: '当前弹幕列表',
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('danmaku-list'),
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: SizedBox(
          height: DanmakuPanelTheme.listRow,
          child: Row(
            children: [
              const SizedBox(width: DanmakuPanelTheme.inset),
              Text(
                '当前弹幕列表',
                style: TextStyle(fontSize: DanmakuPanelTheme.titleText, color: look.text),
              ),
              const Spacer(),
              DanmakuPanelGlyph(DanmakuGlyphKind.listChevron, color: look.secondary),
              const SizedBox(width: DanmakuPanelTheme.listChevronTrailing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resetRow(_Look look, DanmakuSettingsStore store) {
    void ask() => widget.confirm(PanelConfirm(title: '重置弹幕设置', cancel: '我再想想', confirm: '确定', onConfirm: store.reset));
    return Padding(
      padding: const EdgeInsets.only(
        top: DanmakuPanelTheme.resetCentre - DanmakuPanelTheme.resetHeight / 2,
        bottom: DanmakuPanelTheme.endGap,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Semantics(
          button: true,
          label: '重置弹幕设置',
          onTap: ask,
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('danmaku-reset'),
            behavior: HitTestBehavior.opaque,
            onTap: ask,
            child: SizedBox(
              height: DanmakuPanelTheme.resetHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DanmakuPanelGlyph(DanmakuGlyphKind.reset, color: look.reset),
                  const SizedBox(width: DanmakuPanelTheme.resetGap),
                  Text(
                    '重置弹幕设置',
                    style: TextStyle(
                      fontSize: DanmakuPanelTheme.detailText,
                      letterSpacing: DanmakuPanelTheme.resetSpacing,
                      color: look.reset,
                    ),
                  ),
                  const SizedBox(width: DanmakuPanelTheme.resetTrailing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _percent(double value) => '${(value * 100).round()}%';

  static int _nearest(List<double> stops, double value) {
    var best = 0;
    for (var index = 1; index < stops.length; index++) {
      if ((stops[index] - value).abs() < (stops[best] - value).abs()) best = index;
    }
    return best;
  }

  static double _share(double value, double low, double high) => ((value - low) / (high - low)).clamp(0.0, 1.0);

  static double _hundredths(double low, double high, double position) =>
      ((low + position * (high - low)) * 100).round() / 100;
}

Duration _motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

/// Fades a row in when 查看更多 adds it.
class _Appear extends StatelessWidget {
  const _Appear({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.look, required this.child});

  final _Look look;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: look.card, borderRadius: BorderRadius.circular(DanmakuPanelTheme.cardRadius)),
    child: child,
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.look});

  final String title;
  final _Look look;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: DanmakuPanelTheme.sectionHeight,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: DanmakuPanelTheme.sectionCentre - DanmakuPanelTheme.labelBox / 2,
          height: DanmakuPanelTheme.labelBox,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(fontSize: DanmakuPanelTheme.titleText, fontWeight: FontWeight.w600, color: look.text),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The hairline at the foot of a block, from the rows' inset to the card's right edge.
class _HairlineDecoration extends Decoration {
  const _HairlineDecoration(this.color);

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _HairlinePainter(color);
}

class _HairlinePainter extends BoxPainter {
  _HairlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx + DanmakuPanelTheme.inset,
        offset.dy + size.height - BiliMetrics.panelHairline,
        size.width - DanmakuPanelTheme.inset,
        BiliMetrics.panelHairline,
      ),
      Paint()..color = color,
    );
  }
}

/// A label and its value over the official slider: a 6 pt track, pink up to the thumb, and a dot per stop when it
/// snaps.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.describe,
    required this.look,
    required this.position,
    required this.onChanged,
    this.stops,
    this.divider = false,
  });

  final String title;

  /// The value shown for a position along the track.
  final String Function(double position) describe;
  final _Look look;
  final double position;
  final ValueChanged<double> onChanged;
  final int? stops;

  /// The hairline at its foot, when another slider follows.
  final bool divider;

  double get _step => switch (stops) {
    final stops? when stops > 1 => 1 / (stops - 1),
    _ => 0.05,
  };

  double _nudged(double by) => (position + by).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => Container(
    height: DanmakuPanelTheme.sliderRow,
    foregroundDecoration: divider ? _HairlineDecoration(look.hairline) : null,
    child: Stack(
      children: [
        Positioned(
          left: DanmakuPanelTheme.inset,
          right: DanmakuPanelTheme.inset,
          top: DanmakuPanelTheme.sliderLabelCentre - DanmakuPanelTheme.labelBox / 2,
          height: DanmakuPanelTheme.labelBox,
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: DanmakuPanelTheme.titleText, color: look.text),
              ),
              const Spacer(),
              Text(
                describe(position),
                style: TextStyle(fontSize: DanmakuPanelTheme.detailText, color: look.value),
              ),
            ],
          ),
        ),
        Positioned(
          left: DanmakuPanelTheme.sliderTrackInset,
          right: DanmakuPanelTheme.sliderTrackInset,
          top: DanmakuPanelTheme.sliderTrackCentre - BiliMetrics.panelHitBox / 2,
          height: BiliMetrics.panelHitBox,
          child: Semantics(
            slider: true,
            label: title,
            value: describe(position),
            increasedValue: describe(_nudged(_step)),
            decreasedValue: describe(_nudged(-_step)),
            onIncrease: () => onChanged(_nudged(_step)),
            onDecrease: () => onChanged(_nudged(-_step)),
            child: _Slider(
              key: ValueKey('danmaku-slider-$title'),
              position: position,
              stops: stops,
              look: look,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Slider extends StatelessWidget {
  const _Slider({super.key, required this.position, required this.look, required this.onChanged, this.stops});

  final double position;
  final int? stops;
  final _Look look;
  final ValueChanged<double> onChanged;

  double _snap(double raw) {
    final stops = this.stops;
    if (stops == null || stops < 2) return raw;
    return (raw * (stops - 1)).round() / (stops - 1);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      const inset = DanmakuPanelTheme.sliderThumbInset;
      void at(double x) => onChanged(_snap(((x - inset) / (width - 2 * inset)).clamp(0.0, 1.0)));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => at(details.localPosition.dx),
        onHorizontalDragStart: (details) => at(details.localPosition.dx),
        onHorizontalDragUpdate: (details) => at(details.localPosition.dx),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: position),
          duration: stops == null ? Duration.zero : _motion(context, const Duration(milliseconds: 150)),
          curve: Curves.easeOutCubic,
          builder: (context, shown, _) => CustomPaint(
            size: Size(width, BiliMetrics.panelHitBox),
            painter: _SliderPainter(position: shown, stops: stops, look: look),
          ),
        ),
      );
    },
  );
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({required this.position, required this.stops, required this.look});

  final double position;
  final int? stops;
  final _Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    const track = DanmakuPanelTheme.sliderTrack;
    const inset = DanmakuPanelTheme.sliderThumbInset;
    final thumb = inset + position * (size.width - 2 * inset);
    final bar = Rect.fromLTWH(0, middle - track / 2, size.width, track);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(track / 2)), Paint()..color = look.track);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(0, bar.top, thumb, bar.bottom), const Radius.circular(track / 2)),
      Paint()..color = look.fill,
    );
    if (stops case final stops? when stops > 1) {
      const dotInset = DanmakuPanelTheme.sliderDotInset;
      final dot = Paint()..color = look.dot;
      for (var index = 0; index < stops; index++) {
        final x = dotInset + index / (stops - 1) * (size.width - 2 * dotInset);
        canvas.drawCircle(Offset(x, middle), DanmakuPanelTheme.sliderDot / 2, dot);
      }
    }
    canvas.drawCircle(Offset(thumb, middle), DanmakuPanelTheme.sliderThumb / 2, Paint()..color = look.thumb);
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.stops != stops || oldDelegate.look != look;
}

/// One of 按弹幕类型屏蔽's squares: its glyph pink with the ⊘ while that type is blocked (29), the label under it.
class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.type, required this.look, required this.blocked, required this.onTap});

  final _BlockType type;
  final _Look look;
  final bool blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: blocked,
    label: type.title,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: ValueKey('danmaku-type-${type.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          PanelPressable(
            onTap: onTap,
            radius: DanmakuPanelTheme.squareRadius,
            child: Container(
              height: DanmakuPanelTheme.squareHeight,
              decoration: BoxDecoration(
                color: look.square,
                borderRadius: BorderRadius.circular(DanmakuPanelTheme.squareRadius),
              ),
              alignment: Alignment.center,
              child: DanmakuPanelGlyph(type.glyph, color: blocked ? BiliColors.colorsOf(context).pink : look.text, blocked: blocked),
            ),
          ),
          SizedBox(
            height: 2 * DanmakuPanelTheme.squareLabelCentre,
            child: Center(
              child: Text(
                type.title,
                style: TextStyle(fontSize: DanmakuPanelTheme.detailText, color: look.text),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.look,
    required this.on,
    required this.onTap,
    this.divider = true,
  });

  final String title;
  final String subtitle;
  final _Look look;
  final bool on;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: on,
    label: title,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: ValueKey('danmaku-toggle-$title'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: DanmakuPanelTheme.toggleRow,
        foregroundDecoration: divider ? _HairlineDecoration(look.hairline) : null,
        child: Stack(
          children: [
            Positioned(
              left: DanmakuPanelTheme.inset,
              top: DanmakuPanelTheme.toggleTitleCentre - DanmakuPanelTheme.labelBox / 2,
              height: DanmakuPanelTheme.labelBox,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(fontSize: DanmakuPanelTheme.titleText, color: look.text),
                ),
              ),
            ),
            Positioned(
              left: DanmakuPanelTheme.inset,
              top: DanmakuPanelTheme.toggleSubtitleCentre - DanmakuPanelTheme.labelBox / 2,
              height: DanmakuPanelTheme.labelBox,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: DanmakuPanelTheme.detailText, color: look.secondary),
                ),
              ),
            ),
            Positioned(
              right: BiliMetrics.panelRowTrailing,
              top: 0,
              bottom: 0,
              child: Center(
                child: _Switch(on: on, look: look),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// ⋮'s switch, with the light sheet's grey track and shadowed knob when off.
class _Switch extends StatelessWidget {
  const _Switch({required this.on, required this.look});

  final bool on;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    const inset = (BiliMetrics.panelSwitchHeight - BiliMetrics.panelSwitchKnob) / 2;
    final shadow = look.knobShadow;
    final motion = _motion(context, const Duration(milliseconds: 200));
    return AnimatedContainer(
      duration: motion,
      curve: Curves.easeOutCubic,
      width: BiliMetrics.panelSwitchWidth,
      height: BiliMetrics.panelSwitchHeight,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: on ? BiliColors.colorsOf(context).pink : look.switchOff,
        borderRadius: BorderRadius.circular(BiliMetrics.panelSwitchHeight / 2),
      ),
      child: AnimatedAlign(
        duration: motion,
        curve: Curves.easeOutBack,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: BiliMetrics.panelSwitchKnob,
          height: BiliMetrics.panelSwitchKnob,
          decoration: BoxDecoration(
            color: BiliColors.panelKnob,
            shape: BoxShape.circle,
            boxShadow: [
              if (shadow != null)
                BoxShadow(
                  color: shadow,
                  blurRadius: DanmakuPanelTheme.lightKnobShadowBlur,
                  offset: DanmakuPanelTheme.lightKnobShadowOffset,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 33's confirm: the whole screen dimmed, a dark box in the middle with the question over 我再想想 | 确定.
class PanelConfirmDialog extends StatelessWidget {
  const PanelConfirmDialog({super.key, required this.request, required this.dismiss});

  final PanelConfirm request;
  final VoidCallback dismiss;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    void confirm() {
      dismiss();
      request.onConfirm();
    }

    Widget button(String title, Color color, VoidCallback onTap, double shift, Key key) => Expanded(
      child: Semantics(
        button: true,
        label: title,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Transform.translate(
            offset: Offset(shift, 0),
            child: Center(
              child: Text(
                title,
                style: base.copyWith(fontSize: DanmakuPanelTheme.dialogButtonText, color: color),
              ),
            ),
          ),
        ),
      ),
    );

    // Each half's text sits [dialogButtonSpread] from the middle, a little in from the halves' own centres.
    const shift = DanmakuPanelTheme.dialogWidth / 4 - DanmakuPanelTheme.dialogButtonSpread;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('panel-confirm-dim'),
            behavior: HitTestBehavior.opaque,
            onTap: dismiss,
            child: const ColoredBox(color: DanmakuPanelTheme.dialogDim),
          ),
        ),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              key: const ValueKey('panel-confirm'),
              width: DanmakuPanelTheme.dialogWidth,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: DanmakuPanelTheme.dialog,
                borderRadius: BorderRadius.circular(DanmakuPanelTheme.dialogRadius),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: DanmakuPanelTheme.dialogTitleHeight,
                    child: Center(
                      child: Text(
                        request.title,
                        style: base.copyWith(
                          fontSize: DanmakuPanelTheme.dialogTitleText,
                          fontWeight: FontWeight.w500,
                          color: DanmakuPanelTheme.dialogText,
                        ),
                      ),
                    ),
                  ),
                  Container(height: BiliMetrics.panelHairline, color: DanmakuPanelTheme.dialogDivider),
                  SizedBox(
                    height: DanmakuPanelTheme.dialogButtonHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        button(
                          request.cancel,
                          DanmakuPanelTheme.dialogText,
                          dismiss,
                          shift,
                          const ValueKey('panel-confirm-cancel'),
                        ),
                        button(
                          request.confirm,
                          DanmakuPanelTheme.dialogConfirm,
                          confirm,
                          -shift,
                          const ValueKey('panel-confirm-ok'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
