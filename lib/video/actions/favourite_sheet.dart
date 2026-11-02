import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:bili_core/api.dart' show FavFolder;
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart'
    show Icons, InputBorder, InputDecoration, Material, MaterialType, TextField, Theme;
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter, TextInputAction;
import 'package:flutter/widgets.dart';

import '../../app/form_factor.dart';
import '../../player_ui/panels/episodes_panel.dart' show EpisodesSheetHeader;
import '../../player_ui/panels/panel_layer.dart' show PadSheetDim, PadSheetFrame, panelBackdrop;
import '../../player_ui/panels/panel_parts.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import 'video_actions.dart';

/// 收藏: the account's folders with ticks, 新建收藏夹 and 完成 (BiliNative `FavouriteSheet.swift`). A light sheet from
/// the bottom in portrait, its top where the small player ends as 19's; a dark panel from the right in landscape
/// ([dark]), as the player's own panels.
class FavouriteSheet extends StatefulWidget {
  const FavouriteSheet({
    super.key,
    required this.folders,
    required this.dark,
    required this.onClose,
    this.motion = kAlwaysCompleteAnimation,
    this.padFrame,
  });

  final FavouriteFolders folders;
  final bool dark;
  final VoidCallback onClose;

  /// How far in it is: [ActionOverlays] runs it forward to show and back to hide.
  final Animation<double> motion;

  /// The iPad page's, outside full screen: the sheet takes its column under its player, and all but the player dims.
  final PadSheetFrame? padFrame;

  @override
  State<FavouriteSheet> createState() => _FavouriteSheetState();
}

class _Palette {
  const _Palette({
    required this.text,
    required this.secondary,
    required this.divider,
    required this.ring,
    required this.field,
    required this.pressed,
  });

  final Color text;
  final Color secondary;
  final Color divider;
  final Color ring;
  final Color field;
  final Color pressed;

  static _Palette light(BuildContext context) => _Palette(
    text: BiliColors.colorsOf(context).text,
    secondary: BiliColors.colorsOf(context).secondaryText,
    divider: BiliColors.colorsOf(context).divider,
    ring: FavouriteTheme.colorsOf(context).ringLight,
    field: BiliColors.colorsOf(context).softGrey,
    pressed: BiliColors.colorsOf(context).pressedFill,
  );

  static const dark = _Palette(
    text: BiliColors.panelText,
    secondary: BiliColors.panelSecondary,
    divider: BiliColors.panelHairline,
    ring: FavouriteTheme.ringDark,
    field: FavouriteTheme.darkField,
    pressed: BiliColors.panelPressed,
  );
}

class _FavouriteSheetState extends State<FavouriteSheet> with SingleTickerProviderStateMixin {
  final _title = TextEditingController();
  final _focus = FocusNode();
  var _editing = false;
  var _private = false;
  var _creating = false;

  /// A grabber drag pulling the sheet down, and the spring back when it lets go short of closing.
  final _drag = ValueNotifier<double>(0);
  late final AnimationController _dragBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  double _dragFrom = 0;

  @override
  void initState() {
    super.initState();
    _dragBack.addListener(() => _drag.value = _dragFrom * (1 - Curves.easeOutCubic.transform(_dragBack.value)));
  }

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    _dragBack.dispose();
    _drag.dispose();
    super.dispose();
  }

  _Palette get _palette => widget.dark ? _Palette.dark : _Palette.light(context);

  Duration _time(int milliseconds) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: milliseconds);

  void _startEditing() => setState(() => _editing = true);

  void _cancelEditing() {
    _focus.unfocus();
    setState(() {
      _editing = false;
      _private = false;
      _title.clear();
    });
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _creating) return;
    setState(() => _creating = true);
    final failure = await widget.folders.create(title, isPrivate: _private);
    if (!mounted) return;
    setState(() {
      _creating = false;
      if (failure == null) {
        _editing = false;
        _private = false;
        _title.clear();
      }
    });
    if (failure != null) {
      if (failure.isNotEmpty) showToast(context, failure);
    } else {
      _focus.unfocus();
    }
  }

  void _done() {
    unawaited(widget.folders.commit());
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: TextStyle(
      fontFamily: BiliFonts.family,
      fontFamilyFallback: BiliFonts.fallback,
      fontSize: widget.dark ? BiliMetrics.panelTitleText : FavouriteTheme.titleText,
      color: _palette.text,
      decoration: TextDecoration.none,
    ),
    child: PanelScope(
      landscape: widget.dark,
      reveal: widget.motion,
      child: ListenableBuilder(
        listenable: widget.folders,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) => widget.dark ? _side(constraints.biggest) : _sheet(constraints.biggest),
        ),
      ),
    ),
  );

  /// Takes the touches that land on the sheet itself, so only those outside it close it.
  Widget _frame({required Widget child}) => GestureDetector(
    key: const ValueKey('favourite-frame'),
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: child,
  );

  Widget _outside({Widget? child}) => Semantics(
    button: true,
    label: '关闭',
    onTap: widget.onClose,
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('favourite-dismiss'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: child,
    ),
  );

  Widget _sheet(Size size) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final insets = media.padding;
    // From the screen, not the box: a page that shrinks for the keyboard must not shrink the sheet with it.
    final screen = media.size;
    final pad = FormFactor.of(context).isPad ? widget.padFrame : null;
    final playerBottom = pad?.player.bottom ?? insets.top + screen.width / BiliMetrics.videoAspect;
    final full = (screen.height - playerBottom).clamp(0.0, screen.height);
    final height = math.max(0.0, math.min(full, size.height - keyboard - insets.top));
    final hidden = height + keyboard;
    final motion = Listenable.merge([widget.motion, _drag]);
    final dim = AnimatedBuilder(
      animation: motion,
      builder: (context, child) => Opacity(
        opacity: (widget.motion.value * (1 - (hidden == 0 ? 0 : _drag.value / hidden))).clamp(0.0, 1.0),
        child: child,
      ),
      child: _outside(child: const ColoredBox(color: FavouriteTheme.dim)),
    );
    return Stack(
      children: [
        Positioned.fill(child: pad == null ? dim : PadSheetDim(player: pad.player, child: dim)),
        Positioned(
          key: const ValueKey('favourite-sheet'),
          left: 0,
          right: pad == null ? 0 : null,
          width: pad?.column,
          bottom: keyboard,
          height: height,
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, child) =>
                Transform.translate(offset: Offset(0, (1 - widget.motion.value) * hidden + _drag.value), child: child),
            child: _frame(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BiliColors.colorsOf(context).card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(BiliMetrics.sheetRadius)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _grabber(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
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
                          EpisodesSheetHeader(title: '选择收藏夹', close: widget.onClose),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_newFolder(), _content()],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        BiliMetrics.gutter,
                        FavouriteTheme.doneTop,
                        BiliMetrics.gutter,
                        math.max(insets.bottom, BiliMetrics.gutter),
                      ),
                      child: _doneButton(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _grabber({required Widget child}) => GestureDetector(
    key: const ValueKey('favourite-grabber'),
    behavior: HitTestBehavior.opaque,
    onVerticalDragStart: (_) => _dragBack.stop(),
    onVerticalDragUpdate: (details) => _drag.value = math.max(0, _drag.value + details.delta.dy),
    onVerticalDragEnd: (details) {
      if (_drag.value > BiliMetrics.panelDismissDrag ||
          (details.primaryVelocity ?? 0) > BiliMetrics.panelDismissVelocity) {
        widget.onClose();
      } else {
        _dragFrom = _drag.value;
        _dragBack.forward(from: 0);
      }
    },
    child: child,
  );

  Widget _side(Size size) {
    final media = MediaQuery.of(context);
    final insets = media.padding;
    final keyboard = media.viewInsets.bottom;
    final width = size.width * BiliMetrics.panelWidth;
    final reach = size.width * BiliMetrics.panelFadeFraction;
    return Stack(
      children: [
        Positioned.fill(child: _outside()),
        Positioned(
          key: const ValueKey('favourite-panel'),
          top: 0,
          bottom: 0,
          right: 0,
          width: width + reach,
          child: AnimatedBuilder(
            animation: widget.motion,
            builder: (context, child) =>
                Transform.translate(offset: Offset((1 - widget.motion.value) * (width + reach), 0), child: child),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
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
                  child: _frame(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: insets.top + BiliMetrics.panelHeaderTop,
                        right: insets.right + BiliMetrics.panelTrailing,
                        bottom: insets.bottom + keyboard + BiliMetrics.panelBottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PanelHeader(title: '选择收藏夹'),
                          const SizedBox(
                            height:
                                BiliMetrics.panelGap - (BiliMetrics.panelHitBox - BiliMetrics.panelHeaderHeight) / 2,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: BiliMetrics.panelGap,
                                children: [_newFolder(), _content()],
                              ),
                            ),
                          ),
                          const SizedBox(height: BiliMetrics.panelGap),
                          _doneButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _newFolder() {
    final dark = widget.dark;
    final Widget child;
    if (_editing) {
      child = KeyedSubtree(
        key: const ValueKey('favourite-form'),
        child: dark
            ? _card(
                padding: const EdgeInsets.symmetric(
                  horizontal: BiliMetrics.panelCardPadX,
                  vertical: FavouriteTheme.formGap,
                ),
                child: _form(),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(
                  BiliMetrics.gutter,
                  FavouriteTheme.formGap / 2,
                  BiliMetrics.gutter,
                  FavouriteTheme.formGap,
                ),
                child: _form(),
              ),
      );
    } else {
      final label = Row(
        children: [
          Icon(Icons.add, size: FavouriteTheme.plusIcon, color: BiliColors.colorsOf(context).pink),
          const SizedBox(width: FavouriteTheme.plusGap),
          Text(
            '新建收藏夹',
            style: TextStyle(fontFamily: BiliFonts.family, color: BiliColors.colorsOf(context).pink),
          ),
        ],
      );
      child = Semantics(
        key: const ValueKey('favourite-new'),
        button: true,
        label: '新建收藏夹',
        onTap: _startEditing,
        excludeSemantics: true,
        child: _Pressable(
          onTap: _startEditing,
          highlight: _palette.pressed,
          radius: dark ? BiliMetrics.panelRowRadius : 0,
          scale: dark,
          child: dark
              ? _card(
                  height: BiliMetrics.panelCardHeight,
                  padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.panelCardPadX),
                  child: label,
                )
              : Container(
                  height: FavouriteTheme.newRowHeight,
                  padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.gutter),
                  child: label,
                ),
        ),
      );
    }
    return PanelReveal(
      order: 0,
      child: AnimatedSize(
        duration: _time(240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: _time(180),
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
          child: child,
        ),
      ),
    );
  }

  Widget _card({required Widget child, required EdgeInsets padding, double? height}) => Container(
    height: height,
    padding: padding,
    decoration: BoxDecoration(
      color: BiliColors.panelCard,
      borderRadius: BorderRadius.circular(BiliMetrics.panelRowRadius),
    ),
    child: child,
  );

  Widget _form() {
    final palette = _palette;
    final textSize = widget.dark ? BiliMetrics.panelTitleText : FavouriteTheme.titleText;
    final fieldStyle = TextStyle(fontFamily: BiliFonts.family, fontSize: textSize, color: palette.text);
    // A TextField's text starts from the theme's bodyLarge, not the inherited style.
    final fieldStrut = BiliFonts.strut(Theme.of(context).textTheme.bodyLarge?.merge(fieldStyle) ?? fieldStyle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: FavouriteTheme.fieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: FavouriteTheme.fieldPad),
          decoration: BoxDecoration(color: palette.field, borderRadius: BorderRadius.circular(BiliMetrics.cardRadius)),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    key: const ValueKey('favourite-name'),
                    controller: _title,
                    focusNode: _focus,
                    autofocus: true,
                    enabled: !_creating,
                    inputFormatters: [LengthLimitingTextInputFormatter(FavouriteTheme.maxTitle)],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_create()),
                    cursorColor: BiliColors.colorsOf(context).pink,
                    style: fieldStyle,
                    strutStyle: fieldStrut,

                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '收藏夹名称',
                      hintStyle: TextStyle(fontFamily: BiliFonts.family, fontSize: textSize, color: palette.secondary),
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: _title,
                builder: (context, _) => Text(
                  '${_title.text.characters.length}/${FavouriteTheme.maxTitle}',
                  style: TextStyle(
                    fontFamily: BiliFonts.family,
                    fontSize: FavouriteTheme.countText,
                    color: palette.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FavouriteTheme.formGap),
        ListenableBuilder(
          listenable: _title,
          builder: (context, _) {
            final ready = _title.text.trim().isNotEmpty && !_creating;
            return Row(
              children: [
                _privateToggle(),
                const Spacer(),
                _formButton('取消', palette.secondary, _creating ? null : _cancelEditing),
                _formButton('确定', BiliColors.colorsOf(context).pink, ready ? () => unawaited(_create()) : null, busy: _creating),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _privateToggle() {
    void toggle() => setState(() => _private = !_private);
    return Semantics(
      key: const ValueKey('favourite-private'),
      toggled: _private,
      label: '私密',
      onTap: toggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: SizedBox(
          height: FavouriteTheme.formButtonHeight,
          child: Row(
            spacing: BiliMetrics.rowGap,
            children: [
              const Text('私密'),
              if (widget.dark) PanelSwitch(on: _private) else _LightSwitch(on: _private, duration: _time(200)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formButton(String label, Color color, VoidCallback? onTap, {bool busy = false}) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: ValueKey('favourite-form-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: FavouriteTheme.formButtonHeight,
        padding: const EdgeInsets.symmetric(horizontal: FavouriteTheme.formButtonPad),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: busy ? 0 : (onTap == null ? BiliMetrics.panelDisabledOpacity : 1),
              child: Text(
                label,
                style: TextStyle(fontFamily: BiliFonts.family, color: color),
              ),
            ),
            if (busy)
              CupertinoActivityIndicator(
                key: const ValueKey('favourite-creating'),
                radius: FavouriteTheme.formSpinnerRadius,
                color: _palette.secondary,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _content() {
    final folders = widget.folders;
    final palette = _palette;
    final Widget body;
    if (folders.loading) {
      body = Padding(
        key: const ValueKey('favourite-loading'),
        padding: const EdgeInsets.symmetric(vertical: FavouriteTheme.statePad),
        child: Center(
          child: CupertinoActivityIndicator(
            key: const ValueKey('favourite-spinner'),
            radius: FavouriteTheme.spinnerRadius,
            color: palette.secondary,
          ),
        ),
      );
    } else if (folders.error case final error?) {
      body = _failure(error);
    } else {
      body = Column(
        key: const ValueKey('favourite-rows'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: widget.dark ? BiliMetrics.panelGap : 0,
        children: [
          for (final (index, folder) in folders.folders.indexed)
            PanelReveal(
              order: index + 1,
              child: _FolderRow(
                folder: folder,
                ticked: folders.isTicked(folder.id),
                dark: widget.dark,
                palette: palette,
                duration: _time(320),
                onTap: () => folders.toggle(folder.id),
              ),
            ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: _time(200),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      child: body,
    );
  }

  Widget _failure(String error) {
    final palette = _palette;
    void retry() => unawaited(widget.folders.reload());
    return Padding(
      key: const ValueKey('favourite-failure'),
      padding: const EdgeInsets.symmetric(vertical: FavouriteTheme.statePad, horizontal: BiliMetrics.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: BiliFonts.family,
              fontSize: FavouriteTheme.stateText,
              color: palette.secondary,
            ),
          ),
          const SizedBox(height: FavouriteTheme.formGap),
          Semantics(
            button: true,
            label: '重试',
            onTap: retry,
            excludeSemantics: true,
            child: _Pressable(
              onTap: retry,
              highlight: palette.pressed,
              radius: FavouriteTheme.retryHeight / 2,
              scale: true,
              child: Container(
                key: const ValueKey('favourite-retry'),
                height: FavouriteTheme.retryHeight,
                padding: const EdgeInsets.symmetric(horizontal: FavouriteTheme.retryPad),
                decoration: BoxDecoration(
                  border: Border.all(color: BiliColors.colorsOf(context).pink, width: FavouriteTheme.retryBorder),
                  borderRadius: BorderRadius.circular(FavouriteTheme.retryHeight / 2),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '重试',
                    style: TextStyle(
                      fontFamily: BiliFonts.family,
                      fontSize: FavouriteTheme.stateText,
                      color: BiliColors.colorsOf(context).pink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneButton() => Semantics(
    button: true,
    label: '完成',
    onTap: _done,
    excludeSemantics: true,
    child: _Pressable(
      onTap: _done,
      highlight: BiliColors.colorsOf(context).pressedFill,
      radius: FavouriteTheme.doneHeight / 2,
      scale: true,
      child: Container(
        key: const ValueKey('favourite-done'),
        height: FavouriteTheme.doneHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BiliColors.colorsOf(context).pink,
          borderRadius: BorderRadius.circular(FavouriteTheme.doneHeight / 2),
        ),
        child: Text(
          '完成',
          style: TextStyle(
            fontFamily: BiliFonts.family,
            fontSize: FavouriteTheme.doneText,
            fontWeight: FontWeight.w500,
            color: BiliColors.onPink,
          ),
        ),
      ),
    ),
  );
}

/// One folder: its title, a lock when private and how many items it will hold, and the tick circle.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.ticked,
    required this.dark,
    required this.palette,
    required this.duration,
    required this.onTap,
  });

  final FavFolder folder;
  final bool ticked;
  final bool dark;
  final _Palette palette;
  final Duration duration;
  final VoidCallback onTap;

  /// The count follows the tick, as if 完成 had already been pressed.
  int get _count => math.max(0, folder.count + (ticked == folder.contains ? 0 : (ticked ? 1 : -1)));

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final countStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: dark ? BiliMetrics.panelDetailText : FavouriteTheme.countText,
      color: palette.secondary,
    );
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(folder.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        SizedBox(height: dark ? BiliMetrics.panelSubtitleGap : FavouriteTheme.countGap),
        Row(
          children: [
            if (folder.isPrivate) ...[
              Icon(
                Icons.lock_outline,
                key: ValueKey('favourite-lock-${folder.id}'),
                size: FavouriteTheme.lockIcon,
                color: palette.secondary,
              ),
              Text(' · ', style: countStyle),
            ],
            Text('$count个内容', style: countStyle),
          ],
        ),
      ],
    );
    final row = Row(
      children: [
        Expanded(child: text),
        const SizedBox(width: BiliMetrics.rowGap),
        _Tick(on: ticked, ring: palette.ring, duration: duration),
      ],
    );
    return Semantics(
      key: ValueKey('favourite-${folder.id}'),
      container: true,
      checked: ticked,
      label: folder.isPrivate ? '${folder.title}，私密' : folder.title,
      value: '$count个内容',
      onTap: onTap,
      excludeSemantics: true,
      child: _Pressable(
        onTap: onTap,
        highlight: palette.pressed,
        radius: dark ? BiliMetrics.panelRowRadius : 0,
        scale: dark,
        child: dark
            ? Container(
                height: BiliMetrics.panelCardHeight,
                padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.panelCardPadX),
                decoration: BoxDecoration(
                  color: BiliColors.panelCard,
                  borderRadius: BorderRadius.circular(BiliMetrics.panelRowRadius),
                ),
                child: row,
              )
            : Container(
                height: FavouriteTheme.rowHeight,
                margin: const EdgeInsets.only(left: BiliMetrics.gutter),
                padding: const EdgeInsets.only(right: BiliMetrics.gutter),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: palette.divider, width: BiliMetrics.panelHairline),
                  ),
                ),
                child: row,
              ),
      ),
    );
  }
}

/// An empty ring, or a pink disc that pops in with its white tick drawing itself.
class _Tick extends StatelessWidget {
  const _Tick({required this.on, required this.ring, required this.duration});

  final bool on;
  final Color ring;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: on ? 1 : 0),
    duration: duration,
    curve: Curves.easeOutBack,
    builder: (context, progress, _) => CustomPaint(
      size: const Size.square(FavouriteTheme.check),
      painter: _TickPainter(progress: progress, ring: ring, palette: BiliPalette.of(context)),
    ),
  );
}

class _TickPainter extends CustomPainter {
  final BiliPalette palette;
  _TickPainter({this.palette = const BiliPalette(Brightness.light), required this.progress, required this.ring});

  final double progress;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final shown = progress.clamp(0.0, 1.0);
    if (shown < 1) {
      canvas.drawCircle(
        centre,
        radius - FavouriteTheme.checkStroke / 2,
        Paint()
          ..color = ring.withValues(alpha: ring.a * (1 - shown))
          ..style = PaintingStyle.stroke
          ..strokeWidth = FavouriteTheme.checkStroke,
      );
    }
    if (progress <= 0) return;
    canvas.drawCircle(centre, radius * progress.clamp(0.0, 1.1), Paint()..color = BiliColorsColors(palette).pink);
    final drawn = ((progress - 0.3) / 0.7).clamp(0.0, 1.0);
    if (drawn <= 0) return;
    final w = size.width;
    final tick = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.37);
    final paint = Paint()
      ..color = FavouriteTheme.tick
      ..style = PaintingStyle.stroke
      ..strokeWidth = FavouriteTheme.tickStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final PathMetric metric = tick.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * drawn), paint);
  }

  @override
  bool shouldRepaint(_TickPainter old) => (old.progress != progress || old.ring != ring) || old.palette.brightness != palette.brightness;
}

/// The light sheet's switch: [PanelSwitch]'s shape on a grey track the white page can show.
class _LightSwitch extends StatelessWidget {
  const _LightSwitch({required this.on, required this.duration});

  final bool on;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    const inset = (BiliMetrics.panelSwitchHeight - BiliMetrics.panelSwitchKnob) / 2;
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: BiliMetrics.panelSwitchWidth,
      height: BiliMetrics.panelSwitchHeight,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: on ? BiliColors.colorsOf(context).pink : FavouriteTheme.colorsOf(context).switchOffLight,
        borderRadius: BorderRadius.circular(BiliMetrics.panelSwitchHeight / 2),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeOutBack,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: BiliMetrics.panelSwitchKnob,
          height: BiliMetrics.panelSwitchKnob,
          decoration: const BoxDecoration(
            color: BiliColors.panelKnob,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: FavouriteTheme.knobShadow, blurRadius: FavouriteTheme.knobShadowBlur)],
          ),
        ),
      ),
    );
  }
}

/// Lightens (or darkens, on the light sheet) under the finger, and shrinks a little when [scale].
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.highlight,
    required this.radius,
    required this.scale,
    required this.child,
  });

  final VoidCallback onTap;
  final Color highlight;
  final double radius;
  final bool scale;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  var _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    onTapDown: (_) => _press(true),
    onTapUp: (_) => _press(false),
    onTapCancel: () => _press(false),
    child: AnimatedScale(
      scale: _down && widget.scale ? BiliMetrics.pressedScale : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _down ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.highlight,
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
