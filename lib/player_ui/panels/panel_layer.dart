import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/form_factor.dart';
import '../../device/orientation.dart';
import '../../offline/download_sheet.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../player_ui.dart';
import 'episodes_panel.dart';
import 'more_panel.dart';
import 'panel_controller.dart';
import 'panel_parts.dart';
import 'portrait_more_sheet.dart';
import '../../danmaku/block_words_view.dart';
import '../../danmaku/danmaku_list_view.dart';
import 'danmaku_settings_panel.dart';
import 'quality_panel.dart';
import 'speed_panel.dart';

/// How a panel sits: its width as a share of the screen in landscape (or a column with no panel behind it), and its
/// height as a share of the screen in the portrait sheet. 清晰度 and 高级设置 share one frame, so moving between them
/// swaps the content without sliding again.
@immutable
final class PanelFrame {
  const PanelFrame({
    required this.width,
    required this.sheetHeight,
    this.column = false,
    this.light = false,
    this.full = false,
    this.solid = false,
    this.sheetColor = BiliColors.card,
    this.points,
    this.shade,
    this.lead,
    this.trailing,
    this.top = 0,
  });

  final double width;
  final double sheetHeight;
  final bool column;

  /// The portrait 选集 list is the official app's light sheet, its top at the player's bottom.
  final bool light;

  /// Over the whole screen, drawing its own backdrop (添加屏蔽词, 30).
  final bool full;

  /// 弹幕设置's strip (07): a hard edge with no ramp into the video, and the content ending its own scroll.
  final bool solid;

  /// The light sheet's ground.
  final Color sheetColor;

  /// The iPad's strips: a width in points instead of [width]'s share, and a hard edge in this shade.
  final double? points;
  final Color? shade;

  /// Where the content starts in from the strip's left and ends before the safe area; null keeps the phone's.
  final double? lead;
  final double? trailing;

  /// Added under the safe area at the strip's top.
  final double top;

  static PanelFrame of(PlayerPanel panel, {bool pad = false}) => pad ? _pad(panel) : _phone(panel);

  static PanelFrame _phone(PlayerPanel panel) => switch (panel) {
    PlayerPanel.quality || PlayerPanel.codec => const PanelFrame(
      width: BiliMetrics.panelQualityWidth,
      sheetHeight: BiliMetrics.panelSheetHeight,
    ),
    PlayerPanel.speed => const PanelFrame(
      width: BiliMetrics.panelSpeedWidth,
      sheetHeight: BiliMetrics.panelSpeedSheetHeight,
      column: true,
    ),
    // Portrait's ⋮ is the light sheet of 42 and 43, and 缓存 takes its place in the same frame.
    PlayerPanel.more || PlayerPanel.download => PanelFrame(
      width: BiliMetrics.panelMoreWidth,
      sheetHeight: DownloadSheetTheme.verticalHeight,
      light: true,
      sheetColor: DownloadSheetTheme.sheet,
    ),
    PlayerPanel.episodes => const PanelFrame(
      width: BiliMetrics.panelWidth,
      sheetHeight: BiliMetrics.panelSheetHeight,
      light: true,
    ),
    // Portrait's 弹幕设置 is the light sheet of 40.
    PlayerPanel.danmakuSettings => PanelFrame(
      width: DanmakuPanelTheme.width,
      sheetHeight: DanmakuPanelTheme.sheetHeight,
      light: true,
      solid: true,
      sheetColor: DanmakuPanelTheme.lightBackground,
    ),
    PlayerPanel.blockWords => const PanelFrame(width: 1, sheetHeight: 1, full: true),
    PlayerPanel.danmakuList => const PanelFrame(width: BiliMetrics.panelWidth, sheetHeight: BiliMetrics.panelSheetHeight),
  };

  /// Full screen on the iPad (ipad/10-13): every strip hard-edged and as wide in points sideways as upright. 选集 and
  /// 当前弹幕列表 have no screenshot and take 弹幕设置's.
  static PanelFrame _pad(PlayerPanel panel) {
    final phone = _phone(panel);
    return switch (panel) {
      PlayerPanel.quality || PlayerPanel.codec => PanelFrame(
        width: phone.width,
        sheetHeight: phone.sheetHeight,
        points: PadPanelTheme.narrowWidth,
        shade: PadPanelTheme.shade,
        lead: 0,
        trailing: 0,
      ),
      PlayerPanel.speed => PanelFrame(
        width: phone.width,
        sheetHeight: phone.sheetHeight,
        column: true,
        points: PadPanelTheme.narrowWidth,
        shade: PadPanelTheme.darkShade,
        lead: 0,
        trailing: 0,
      ),
      PlayerPanel.more => PanelFrame(
        width: phone.width,
        sheetHeight: phone.sheetHeight,
        points: PadPanelTheme.wideWidth,
        shade: PadPanelTheme.shade,
        lead: PadPanelTheme.moreInset,
        trailing: PadPanelTheme.moreInset,
      ),
      PlayerPanel.danmakuSettings => PanelFrame(
        width: phone.width,
        sheetHeight: phone.sheetHeight,
        light: true,
        solid: true,
        sheetColor: phone.sheetColor,
        points: PadPanelTheme.wideWidth,
        shade: PadPanelTheme.darkShade,
        trailing: PadPanelTheme.trailing,
        top: PadPanelTheme.danmakuTop,
      ),
      PlayerPanel.episodes || PlayerPanel.danmakuList || PlayerPanel.download => PanelFrame(
        width: phone.width,
        sheetHeight: phone.sheetHeight,
        light: phone.light,
        points: PadPanelTheme.wideWidth,
        shade: PadPanelTheme.darkShade,
        trailing: PadPanelTheme.trailing,
      ),
      PlayerPanel.blockWords => phone,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PanelFrame &&
      other.width == width &&
      other.sheetHeight == sheetHeight &&
      other.column == column &&
      other.light == light &&
      other.full == full &&
      other.solid == solid &&
      other.sheetColor == sheetColor &&
      other.points == points &&
      other.shade == shade &&
      other.lead == lead &&
      other.trailing == trailing &&
      other.top == top;

  @override
  int get hashCode =>
      Object.hash(width, sheetHeight, column, light, full, solid, sheetColor, points, shade, lead, trailing, top);
}

/// Where the iPad page's sheets and the danmaku send bar sit (no screenshot, a guess): [column] wide from the page's
/// left edge, under [player], which alone stays undimmed. In the page's own coordinates.
@immutable
final class PadSheetFrame {
  const PadSheetFrame({required this.player, required this.column});

  final Rect player;
  final double column;

  @override
  bool operator ==(Object other) => other is PadSheetFrame && other.player == player && other.column == column;

  @override
  int get hashCode => Object.hash(player, column);
}

/// [child] everywhere in its box but [player], for painting and touches alike: what an open iPad sheet dims, the
/// related column and the status band included, as the phone's dims everything below its player.
class PadSheetDim extends StatelessWidget {
  const PadSheetDim({super.key, required this.player, required this.child});

  final Rect player;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipPath(clipper: _OutsideClip(player), child: child);
}

class _OutsideClip extends CustomClipper<Path> {
  _OutsideClip(this.hole);

  final Rect hole;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRect(hole);

  @override
  bool shouldReclip(_OutsideClip oldClipper) => oldClipper.hole != hole;
}

/// The open panel, if any (BiliNative `PanelLayer.swift` and `SidePanel.swift`): from the right in landscape, a
/// bottom sheet in portrait, closed by a tap outside it. The page puts it over everything, filling the page. It is
/// part of the page rather than a route, so rotation, swipe back and picture in picture never see it.
class PanelLayer extends StatefulWidget {
  const PanelLayer({super.key, required this.ui, this.playerBottom, this.padFrame});

  final PlayerUi ui;

  /// Where the small player ends on the page as it is now, shrunk or not; the portrait 合集 sheet starts there. Null
  /// takes the full 16:9 player under the status bar.
  final double? playerBottom;

  /// The iPad page's, outside full screen: the sheets take its column and dim all but its player.
  final PadSheetFrame? padFrame;

  @override
  State<PanelLayer> createState() => _PanelLayerState();
}

class _PanelLayerState extends State<PanelLayer> with TickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _slide = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// A grabber drag pulling the sheet down, and the spring back when it lets go short of closing.
  final _drag = ValueNotifier<double>(0);
  late final AnimationController _dragBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  /// What shows: the open panel, or the one sliding out after a close.
  PlayerPanel? _shown;

  /// A confirm the open panel asked for, over everything; it goes with the panel.
  final _confirm = ValueNotifier<PanelConfirm?>(null);

  /// A layer the open panel put over the whole page (缓存's 画质 picker); it goes with the panel.
  final _cover = ValueNotifier<Widget?>(null);

  /// Whether the last build was the iPad's full screen, for comparing frames outside a build.
  bool _padStrip = false;

  @override
  void initState() {
    super.initState();
    _listen(widget.ui);
    _dragBack.addListener(() => _drag.value = _dragFrom * (1 - Curves.easeOutCubic.transform(_dragBack.value)));
    _panelChanged();
  }

  double _dragFrom = 0;

  void _listen(PlayerUi ui) {
    ui.panels.addListener(_panelChanged);
    ui.presentationChanges.addListener(_presentationChanged);
  }

  void _unlisten(PlayerUi ui) {
    ui.panels.removeListener(_panelChanged);
    ui.presentationChanges.removeListener(_presentationChanged);
  }

  @override
  void didUpdateWidget(PanelLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.ui.panels, widget.ui.panels) &&
        identical(oldWidget.ui.presentationChanges, widget.ui.presentationChanges)) {
      return;
    }
    _unlisten(oldWidget.ui);
    _listen(widget.ui);
    _panelChanged();
  }

  @override
  void dispose() {
    _unlisten(widget.ui);
    _slide.dispose();
    _motion.dispose();
    _dragBack.dispose();
    _drag.dispose();
    _confirm.dispose();
    _cover.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// 添加屏蔽词 and 当前弹幕列表 are laid out for landscape only; turned upright they give way to 弹幕设置's sheet.
  /// 缓存 is portrait only, as landscape's ⋮ (20, 21) has no way to it.
  void _presentationChanged() {
    final panels = widget.ui.panels;
    final landscape = widget.ui.presentation == Presentation.landscape;
    if (!landscape && (panels.value == PlayerPanel.blockWords || panels.value == PlayerPanel.danmakuList)) {
      panels.open(PlayerPanel.danmakuSettings);
    } else if (landscape && panels.value == PlayerPanel.download) {
      panels.close();
    }
    _rebuild();
  }

  void _panelChanged() {
    _confirm.value = null;
    _cover.value = null;
    final next = widget.ui.panels.value;
    if (next == null) {
      if (_shown == null) return;
      setState(() {});
      _motion.reverse().whenCompleteOrCancel(() {
        if (mounted && _motion.isDismissed && widget.ui.panels.value == null) setState(() => _shown = null);
      });
      return;
    }
    final previous = _shown;
    final slideIn =
        previous == null || PanelFrame.of(previous, pad: _padStrip) != PanelFrame.of(next, pad: _padStrip);
    setState(() => _shown = next);
    if (slideIn) {
      _dragBack.stop();
      _drag.value = 0;
      _motion.forward(from: 0);
    } else {
      // Reopened while sliding out: it turns around where it is.
      _motion.forward();
    }
  }

  void _close() => widget.ui.panels.close();

  /// For what a panel does once a call comes back: by then the user may have closed it or opened another.
  void _closeIf(PlayerPanel panel) {
    if (widget.ui.panels.value == panel) _close();
  }

  void _toast(String message) {
    if (mounted) showToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final landscape = widget.ui.presentation == Presentation.landscape;
    final pad = FormFactor.of(context).isPad;
    _padStrip = pad && landscape;
    final frame = PanelFrame.of(shown, pad: _padStrip);
    final light = frame.light && !landscape;
    return IgnorePointer(
      ignoring: widget.ui.panels.value == null,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: BiliFonts.family,
          fontFamilyFallback: BiliFonts.fallback,
          fontSize: BiliMetrics.panelTitleText,
          color: light ? BiliColors.colorsOf(context).text : BiliColors.panelText,
          decoration: TextDecoration.none,
        ),
        child: PanelScope(
          landscape: landscape,
          reveal: _motion,
          pad: pad,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final insets = MediaQuery.paddingOf(context);
              final content = _content(shown, light: light);
              return Stack(
                children: [
                  Positioned.fill(
                    child: Semantics(
                      button: true,
                      label: '关闭',
                      child: GestureDetector(
                        key: const ValueKey('panel-dismiss'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _close,
                      ),
                    ),
                  ),
                  if (frame.full)
                    _full(content)
                  else if (!landscape && light)
                    ..._lightSheet(size, insets, frame, content, pad: pad)
                  else if (!landscape)
                    ..._sheet(size, insets, frame, content, pad: pad)
                  else if (frame.column)
                    _column(size, insets, frame, content)
                  else
                    _side(size, insets, frame, content),
                  Positioned.fill(
                    child: ValueListenableBuilder(
                      valueListenable: _cover,
                      builder: (context, cover, _) => cover ?? const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fill(
                    child: ValueListenableBuilder(
                      valueListenable: _confirm,
                      builder: (context, request, _) => AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: request == null
                            ? const SizedBox.shrink()
                            : PanelConfirmDialog(
                                key: ValueKey(request),
                                request: request,
                                dismiss: () => _confirm.value = null,
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(PlayerPanel panel, {required bool light}) {
    final session = widget.ui.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey(panel),
          child: switch (panel) {
            PlayerPanel.quality => QualityPanel(
              session: session,
              openCodec: () => widget.ui.panels.open(PlayerPanel.codec),
              toast: _toast,
              close: _close,
            ),
            PlayerPanel.codec => CodecPanel(
              session: session,
              back: () => widget.ui.panels.open(PlayerPanel.quality),
              toast: _toast,
              close: _close,
            ),
            PlayerPanel.speed => SpeedPanel(session: session, toast: _toast, close: _close),
            PlayerPanel.more when light => PortraitMoreSheet(
              ui: widget.ui,
              toast: _toast,
              close: () => _closeIf(PlayerPanel.more),
            ),
            PlayerPanel.more => MorePanel(
              session: session,
              toast: _toast,
              close: () => _closeIf(PlayerPanel.more),
              // Landscape's bar has its own 弹幕设置 button, and its ⋮ (20, 21) has no such row.
              openDanmakuSettings: widget.ui.danmaku == null || widget.ui.presentation == Presentation.landscape
                  ? null
                  : () => widget.ui.panels.open(PlayerPanel.danmakuSettings),
            ),
            PlayerPanel.episodes => EpisodesPanel(
              session: session,
              details: widget.ui.details,
              close: _close,
              light: light,
            ),
            PlayerPanel.danmakuSettings => DanmakuSettingsPanel(
              ui: widget.ui,
              light: light,
              toast: _toast,
              close: _close,
              confirm: (request) => _confirm.value = request,
            ),
            PlayerPanel.blockWords => BlockWordsView(
              ui: widget.ui,
              toast: _toast,
              back: () => widget.ui.panels.open(PlayerPanel.danmakuSettings),
              close: _close,
            ),
            PlayerPanel.danmakuList => DanmakuListView(
              ui: widget.ui,
              toast: _toast,
              back: () => widget.ui.panels.open(PlayerPanel.danmakuSettings),
              close: _close,
            ),
            PlayerPanel.download => DownloadSheet(
              ui: widget.ui,
              toast: _toast,
              close: _close,
              cover: (layer) => _cover.value = layer,
            ),
          },
        ),
      ),
    );
  }

  /// Takes the touches that land on the panel itself, so only those outside it close it.
  Widget _body({required Widget child}) =>
      GestureDetector(key: const ValueKey('panel-frame'), behavior: HitTestBehavior.opaque, onTap: () {}, child: child);

  Widget _side(Size size, EdgeInsets insets, PanelFrame frame, Widget content) {
    final width = frame.points ?? size.width * frame.width;
    final hard = frame.solid || frame.shade != null;
    final reach = hard ? 0.0 : size.width * BiliMetrics.panelFadeFraction;
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: width + reach,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) =>
            Transform.translate(offset: Offset((1 - _slide.value) * (width + reach), 0), child: child),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: hard
                    ? ColoredBox(color: frame.shade ?? DanmakuPanelTheme.shade)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: panelBackdrop(reach: reach, length: width + reach),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: width,
              child: _body(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: insets.top + frame.top,
                    bottom: frame.solid ? 0 : insets.bottom + BiliMetrics.panelBottom,
                    left: frame.lead ?? 0,
                    right: insets.right + (frame.trailing ?? BiliMetrics.panelTrailing),
                  ),
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Over the whole screen; the content draws its own backdrop and takes every touch.
  Widget _full(Widget content) => Positioned.fill(
    child: FadeTransition(opacity: _slide, child: _body(child: content)),
  );

  /// 倍速: no panel, a column of values on a dark strip at the right edge.
  Widget _column(Size size, EdgeInsets insets, PanelFrame frame, Widget content) => Positioned(
    top: 0,
    bottom: 0,
    right: 0,
    width: frame.points ?? size.width * frame.width,
    child: AnimatedBuilder(
      animation: _slide,
      builder: (context, child) => Opacity(
        opacity: _slide.value,
        child: Transform.translate(offset: Offset((1 - _slide.value) * BiliMetrics.panelRevealShift, 0), child: child),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: frame.shade ?? BiliColors.panelShade)),
          ),
          Positioned.fill(
            child: _body(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: frame.lead ?? BiliMetrics.panelSpeedLead,
                  right: insets.right + (frame.trailing ?? BiliMetrics.panelTrailing),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height),
                  child: Center(child: content),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  double _sheetOffset(double hidden) => (1 - _slide.value) * hidden + _drag.value;

  /// Across the screen, or [width] from its left edge.
  Widget _slidingSheet({required double height, required double hidden, required Widget child, double? width}) {
    return Positioned(
      left: 0,
      right: width == null ? 0 : null,
      width: width,
      bottom: 0,
      height: height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_slide, _drag]),
        builder: (context, child) => Transform.translate(offset: Offset(0, _sheetOffset(hidden)), child: child),
        child: child,
      ),
    );
  }

  /// The iPad's page has no screenshot of an open sheet: it keeps the phone's height in points, never reaching over
  /// the player, in the player's column.
  double _padSheetHeight(Size size, EdgeInsets insets, double share) =>
      math.max(0.0, math.min(share * PadPanelTheme.phoneHeight, size.height - (widget.playerBottom ?? insets.top)));

  PadSheetFrame? _padFrame({required bool pad}) => pad ? widget.padFrame : null;

  double _sheetFade(double hidden) => (_slide.value * (1 - (hidden == 0 ? 0 : _drag.value / hidden))).clamp(0.0, 1.0);

  Widget _padDim(PadSheetFrame frame, double hidden) => Positioned.fill(
    key: const ValueKey('panel-sheet-dim'),
    child: IgnorePointer(
      child: PadSheetDim(
        player: frame.player,
        child: AnimatedBuilder(
          animation: Listenable.merge([_slide, _drag]),
          builder: (context, child) => Opacity(opacity: _sheetFade(hidden), child: child),
          child: const ColoredBox(color: BiliColors.sheetDim),
        ),
      ),
    ),
  );

  Widget _grabber({required Widget child}) => GestureDetector(
    key: const ValueKey('panel-grabber'),
    behavior: HitTestBehavior.opaque,
    onVerticalDragStart: (_) => _dragBack.stop(),
    onVerticalDragUpdate: (details) => _drag.value = math.max(0, _drag.value + details.delta.dy),
    onVerticalDragEnd: (details) {
      if (_drag.value > BiliMetrics.panelDismissDrag ||
          (details.primaryVelocity ?? 0) > BiliMetrics.panelDismissVelocity) {
        _close();
      } else {
        _dragFrom = _drag.value;
        _dragBack.forward(from: 0);
      }
    },
    child: child,
  );

  List<Widget> _sheet(Size size, EdgeInsets insets, PanelFrame frame, Widget content, {required bool pad}) {
    final height = pad ? _padSheetHeight(size, insets, frame.sheetHeight) : size.height * frame.sheetHeight;
    const reach = BiliMetrics.panelFadeHeight;
    final padFrame = _padFrame(pad: pad);
    final hidden = height + reach + insets.bottom;
    return [
      if (padFrame != null) _padDim(padFrame, hidden),
      _slidingSheet(
        height: height + reach,
        hidden: hidden,
        width: padFrame?.column,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: panelBackdrop(reach: reach, length: height + reach, vertical: true),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height,
              child: _body(
                child: Column(
                  children: [
                    _grabber(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: BiliMetrics.panelGrabberPad),
                        alignment: Alignment.center,
                        child: Container(
                          width: BiliMetrics.panelGrabberWidth,
                          height: BiliMetrics.panelGrabberHeight,
                          decoration: BoxDecoration(
                            color: BiliColors.panelGrabber,
                            borderRadius: BorderRadius.circular(BiliMetrics.panelGrabberHeight / 2),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: insets.left + BiliMetrics.gutter,
                          right: insets.right + BiliMetrics.gutter,
                          bottom: insets.bottom + BiliMetrics.gutter,
                        ),
                        child: content,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// The official 合集 list (19): white, rounded at the top, from the player's bottom down; [EpisodesPanel] fills it
  /// below the grabber. The page under it dims, the player above it doesn't.
  List<Widget> _lightSheet(Size size, EdgeInsets insets, PanelFrame frame, Widget content, {required bool pad}) {
    final padFrame = _padFrame(pad: pad);
    final width = padFrame?.column;
    final height = widget.ui.presentation == Presentation.inline
        ? math.max(
            0.0,
            size.height - (widget.playerBottom ?? insets.top + (width ?? size.width) / BiliMetrics.videoAspect),
          )
        : pad
        ? _padSheetHeight(size, insets, frame.sheetHeight)
        : size.height * frame.sheetHeight;
    final hidden = height + insets.bottom;
    return [
      if (padFrame != null)
        _padDim(padFrame, hidden)
      else
        Positioned(
          key: const ValueKey('panel-sheet-dim'),
          left: 0,
          right: 0,
          bottom: 0,
          height: height,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_slide, _drag]),
              builder: (context, child) =>
                  Opacity(opacity: (_slide.value * (1 - _drag.value / hidden)).clamp(0.0, 1.0), child: child),
              child: const ColoredBox(color: BiliColors.sheetDim),
            ),
          ),
        ),
      _slidingSheet(
        height: height,
        hidden: hidden,
        width: width,
        child: _body(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: BiliPalette.of(context).choose(frame.sheetColor,
                  frame.sheetColor == BiliColors.card ? BiliPalette.of(context).surface : BiliPalette.of(context).raised),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(BiliMetrics.sheetRadius)),
            ),
            child: Column(
              children: [
                _grabber(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: BiliMetrics.sheetGrabberTop),
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: BiliMetrics.sheetGrabberWidth,
                      height: BiliMetrics.sheetGrabberHeight,
                      decoration: BoxDecoration(
                        color: BiliColors.colorsOf(context).sheetGrabber,
                        borderRadius: BorderRadius.circular(BiliMetrics.sheetGrabberHeight / 2),
                      ),
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// The dark layer behind a panel: a ramp from clear over [reach] towards the video, then the panel shade. The
/// portrait sheet ramps all the way to full shade before its content starts, since the light page behind it would
/// ghost through its heading at the landscape ramp's end.
Gradient panelBackdrop({required double reach, required double length, bool vertical = false}) {
  const shade = BiliColors.panelShade;
  if (reach <= 0 || length <= reach) return const LinearGradient(colors: [shade, shade]);
  final ramp = reach / length;
  final end = BiliColors.panelFade.last.$2;
  final scale = vertical ? BiliColors.panelShadeOpacity / end : 1.0;
  final colors = <Color>[], stops = <double>[];
  for (final (at, black) in BiliColors.panelFade) {
    colors.add(shade.withValues(alpha: black * scale));
    stops.add(at * ramp);
  }
  colors.addAll([shade, shade]);
  stops.addAll([ramp + (1 - ramp) * 0.2, 1]);
  return LinearGradient(
    begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
    end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
    colors: colors,
    stops: stops,
  );
}
