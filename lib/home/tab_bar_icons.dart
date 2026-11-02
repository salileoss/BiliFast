import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:bili_core/devlog.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../shared/theme.dart';
import '../skin/skin.dart';
import '../skin/svga_view.dart';
import 'home_tab_bar.dart';

/// A bottom-bar glyph, drawn as 01 (首页 selected, the rest not) and 02 (首页 not selected, 我的 selected) show it.
/// [HomeTab.post] is the + on its pink rounded square, [TabIconTheme.postSquare] across; the others are line glyphs
/// in a [TabIconTheme.size] square.
class HomeTabIcon extends StatelessWidget {
  const HomeTabIcon(this.tab, {super.key, this.selected = false});

  final HomeTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: tab == HomeTab.post
        ? SizedBox.square(
            dimension: TabIconTheme.postSquare,
            child: CustomPaint(painter: PostButtonPainter(palette: BiliPalette.of(context))),
          )
        : SizedBox.square(
            dimension: TabIconTheme.size,
            child: CustomPaint(
              painter: HomeTabGlyphPainter(
                tab,
                selected: selected,
                color: selected ? TabIconTheme.colorsOf(context).selectedInk : TabIconTheme.colorsOf(context).ink,
              ),
            ),
          ),
  );
}

/// An iPad bar icon (ipad/01, 02): the APK's own tab bar art, tinted grey, or pink while [selected].
class PadTabIcon extends StatelessWidget {
  const PadTabIcon(this.tab, {super.key, this.selected = false});

  final PadTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) => Image.asset(
    tab.art(selected: selected),
    width: tab.iconWidth,
    color: selected ? PadHomeTheme.colorsOf(context).pink : PadHomeTheme.colorsOf(context).barIconInk,
    colorBlendMode: BlendMode.srcIn,
    excludeFromSemantics: true,
  );
}

/// The line glyphs, laid out in a 22 pt square as measured on 01 and 02 and scaled to the square they get.
class HomeTabGlyphPainter extends CustomPainter {
  HomeTabGlyphPainter(this.tab, {required this.selected, required this.color});

  final HomeTab tab;
  final bool selected;
  final Color color;

  static const _design = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    canvas
      ..save()
      ..translate((size.width - side) / 2, (size.height - side) / 2)
      ..scale(side / _design);
    switch (tab) {
      case HomeTab.home:
        _home(canvas);
      case HomeTab.follow:
        _pinwheel(canvas);
      case HomeTab.messages:
        _bubble(canvas);
      case HomeTab.mine:
        _tv(canvas);
      case HomeTab.post:
        break;
    }
    canvas.restore();
  }

  Paint _line(double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// The roof overhangs both walls; the right wall runs up into it, the left stops short.
  void _home(Canvas canvas) {
    const corner = Radius.circular(3.67);
    final roof = Path()
      ..moveTo(2, 9.29)
      ..lineTo(11, 2)
      ..lineTo(20, 9.29);
    final walls = Path()
      ..moveTo(4, 11.33)
      ..lineTo(4, 19.5 - corner.x)
      ..arcToPoint(Offset(4 + corner.x, 19.5), radius: corner, clockwise: false)
      ..lineTo(18 - corner.x, 19.5)
      ..arcToPoint(Offset(18, 19.5 - corner.x), radius: corner, clockwise: false)
      ..lineTo(18, 7.67);
    final line = _line(TabIconTheme.line);
    canvas
      ..drawPath(roof, line)
      ..drawPath(walls, line);
    final face = _line(TabIconTheme.faceLine);
    if (selected) {
      const startDegrees = 32.3;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(11, 13.05), radius: 3.43),
        startDegrees * math.pi / 180,
        (180 - 2 * startDegrees) * math.pi / 180,
        false,
        face,
      );
    } else {
      canvas.drawLine(const Offset(8.42, 15.5), const Offset(13.58, 15.5), face);
    }
  }

  /// A cross whose four arms each carry a half circle on their anticlockwise side, from the tip back to the middle.
  void _pinwheel(Canvas canvas) {
    const centre = Offset(11, 11);
    const arm = 9.67;
    final line = _line(TabIconTheme.fanLine);
    canvas
      ..drawLine(const Offset(11 - arm, 11), const Offset(11 + arm, 11), line)
      ..drawLine(const Offset(11, 11 - arm), const Offset(11, 11 + arm), line);
    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + i * math.pi / 2;
      final middle = centre + Offset(math.cos(angle), math.sin(angle)) * (arm / 2);
      canvas.drawArc(Rect.fromCircle(center: middle, radius: arm / 2), angle, -math.pi, false, line);
    }
  }

  /// A round bubble a little flatter below, its tail a point at the lower left with a short flick inwards, two dots.
  void _bubble(Canvas canvas) {
    final outline = Path()
      ..moveTo(6, 16.8)
      ..lineTo(2, 17.3)
      ..quadraticBezierTo(3.6, 19.4, 6.5, 19.4)
      ..lineTo(11, 19.46)
      ..cubicTo(15.5, 19.46, 20, 15.23, 20, 11)
      ..cubicTo(20, 6.32, 15.97, 2.52, 11, 2.52)
      ..cubicTo(6.03, 2.52, 2, 6.32, 2, 11)
      ..cubicTo(2, 13, 3.8, 15.4, 5.2, 16.85);
    canvas.drawPath(outline, _line(TabIconTheme.line));
    final dot = Paint()..color = color;
    canvas
      ..drawCircle(const Offset(8.5, 10.75), 1.5, dot)
      ..drawCircle(const Offset(14.5, 10.75), 1.5, dot);
  }

  /// The TV: closed eyes (two dashes) when not selected, open (two upright strokes) when selected.
  void _tv(Canvas canvas) {
    canvas.drawRRect(RRect.fromLTRBR(1.5, 5.5, 20.5, 19.75, const Radius.circular(4)), _line(TabIconTheme.line));
    final face = _line(TabIconTheme.faceLine);
    canvas
      ..drawLine(const Offset(4.8, 1.75), const Offset(8.7, 5.5), face)
      ..drawLine(const Offset(17.2, 1.75), const Offset(13.3, 5.5), face);
    if (selected) {
      canvas
        ..drawLine(const Offset(8, 10.75), const Offset(8, 14.92), face)
        ..drawLine(const Offset(14, 10.75), const Offset(14, 14.92), face);
    } else {
      canvas
        ..drawLine(const Offset(4.75, 12.23), const Offset(9.25, 12.23), face)
        ..drawLine(const Offset(12.75, 12.23), const Offset(17.25, 12.23), face);
    }
  }

  @override
  bool shouldRepaint(HomeTabGlyphPainter old) => old.tab != tab || old.selected != selected || old.color != color;
}

/// 发布's pink square, lighter at the top, with its white +.
class PostButtonPainter extends CustomPainter {
  const PostButtonPainter({this.palette = const BiliPalette(Brightness.light)});

  final BiliPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final scale = side / TabIconTheme.postSquare;
    final square = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(square, Radius.circular(TabIconTheme.postRadius * scale)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.choose(TabIconTheme.postTop, palette.accent), palette.choose(TabIconTheme.postBottom, palette.accent)],
        ).createShader(square),
    );
    final line = TabIconTheme.postPlusLine * scale;
    final reach = (TabIconTheme.postPlus * scale - line) / 2;
    final plus = Paint()
      ..color = TabIconTheme.postPlusInk
      ..strokeWidth = line
      ..strokeCap = StrokeCap.round;
    final centre = square.center;
    canvas
      ..drawLine(centre.translate(-reach, 0), centre.translate(reach, 0), plus)
      ..drawLine(centre.translate(0, -reach), centre.translate(0, reach), plus);
  }

  @override
  bool shouldRepaint(PostButtonPainter old) => old.palette.brightness != palette.brightness;
}

/// A place's icon in a bar dressed by the 装扮 (109, 110): its picture, or its selected one while [selected]. A
/// selected animation plays from its first frame each time the place is selected, looping with [loop]. With [rise]
/// every change fades the incoming picture in, rising [HomeTabBarTheme.skinIconRise] into place.
class SkinTabIcon extends StatefulWidget {
  const SkinTabIcon({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    this.loop = false,
    this.rise = false,
  });

  final SkinIcon icon;
  final SkinIcon selectedIcon;
  final bool selected;
  final bool loop;
  final bool rise;

  @override
  State<SkinTabIcon> createState() => _SkinTabIconState();
}

class _SkinTabIconState extends State<SkinTabIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: HomeTabBarTheme.skinIconMotion,
    value: 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(parent: _motion, curve: Curves.easeOut);

  /// Counts the selections, so each one starts a selected animation afresh.
  int _plays = 0;

  @override
  void didUpdateWidget(SkinTabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;
    if (widget.selected) _plays++;
    if (widget.rise && !MediaQuery.disableAnimationsOf(context)) {
      unawaited(_motion.forward(from: 0));
    } else {
      _motion.value = 1;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = widget.selected
        ? SkinPicture(
            widget.selectedIcon,
            key: ValueKey('skin-play-$_plays'),
            play: !MediaQuery.disableAnimationsOf(context),
            loop: widget.loop,
            fallback: SkinPicture(widget.icon),
          )
        : SkinPicture(widget.icon);
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, HomeTabBarTheme.skinIconRise * (1 - _curve.value)), child: child),
        child: picture,
      ),
    );
  }
}

/// One of the 装扮's pictures, fit centre in its box: a still picture, or an animation that stays on its first frame
/// unless [play]. [fallback] shows while an animation decodes or when it can't be read.
class SkinPicture extends StatelessWidget {
  const SkinPicture(this.icon, {super.key, this.play = false, this.loop = false, this.fallback});

  final SkinIcon icon;
  final bool play;
  final bool loop;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => icon.animated
      ? SvgaView(file: icon.file, play: play, loop: loop, fallback: fallback)
      : SkinDecodeGate.image(icon.file, fit: BoxFit.contain);
}

/// Holds a 装扮 back until its still [pictures] have decoded, as 我的's header waits for its picture: [builder] gets
/// false until every one has, and again for good once one fails, here or later while [image] draws it. So the skin's
/// colours never come without the pictures they were chosen for.
class SkinDecodeGate extends StatefulWidget {
  const SkinDecodeGate({super.key, required this.pictures, required this.builder});

  final List<File> pictures;
  final Widget Function(BuildContext context, bool decoded) builder;

  /// One of the gate's pictures; one that fails to draw drops the gate around it back to stock.
  static Widget image(File file, {Key? key, BoxFit fit = BoxFit.cover, Alignment alignment = Alignment.center}) =>
      Image.file(
        file,
        key: key,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (context, error, _) {
          context.findAncestorStateOfType<_SkinDecodeGateState>()?._drawFailed(file, error);
          return const SizedBox.shrink();
        },
      );

  @override
  State<SkinDecodeGate> createState() => _SkinDecodeGateState();
}

class _SkinDecodeGateState extends State<SkinDecodeGate> {
  final _decoded = <String>{};
  final _failed = <String>{};
  final _pending = <String, (ImageStream, ImageStreamListener)>{};

  /// A picture already in the image cache answers while it is asked for, before this build: no setState then.
  bool _asking = false;

  bool get _ready => widget.pictures.every((file) => _decoded.contains(file.path) && !_failed.contains(file.path));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ask();
  }

  @override
  void didUpdateWidget(SkinDecodeGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ask();
  }

  @override
  void dispose() {
    for (final (stream, listener) in _pending.values) {
      stream.removeListener(listener);
    }
    _pending.clear();
    super.dispose();
  }

  void _ask() {
    final wanted = {for (final file in widget.pictures) file.path};
    _pending.removeWhere((path, entry) {
      if (wanted.contains(path)) return false;
      entry.$1.removeListener(entry.$2);
      return true;
    });
    _asking = true;
    for (final file in widget.pictures) {
      final path = file.path;
      if (_decoded.contains(path) || _failed.contains(path) || _pending.containsKey(path)) continue;
      final stream = FileImage(file).resolve(createLocalImageConfiguration(context));
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (image, _) {
          image.dispose();
          _answered(path, failed: false);
        },
        onError: (error, _) {
          _log(file, error);
          _answered(path, failed: true);
        },
      );
      _pending[path] = (stream, listener);
      stream.addListener(listener);
    }
    _asking = false;
  }

  void _answered(String path, {required bool failed}) {
    final entry = _pending.remove(path);
    if (entry == null) return;
    final (stream, listener) = entry;
    if (failed) {
      _failed.add(path);
      stream.removeListener(listener);
    } else {
      _decoded.add(path);
      // As precacheImage does: the picture's Image subscribes in the frame this brings, before it can be let go.
      SchedulerBinding.instance.addPostFrameCallback((_) => stream.removeListener(listener));
    }
    if (!_asking && mounted) setState(() {});
  }

  /// Called while the picture's Image builds, so the gate rebuilds after this frame.
  void _drawFailed(File file, Object error) {
    if (!_failed.add(file.path)) return;
    _log(file, error);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) setState(() {});
      })
      ..ensureVisualUpdate();
  }

  static void _log(File file, Object error) => Logger.shared.error(LogCategory.ui, 'skin picture failed', {
    'file': file.uri.pathSegments.last,
    'error': '${error.runtimeType}',
  });

  @override
  Widget build(BuildContext context) => widget.builder(context, _ready);
}
