import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';

/// The official icon font's glyphs the sheets draw (assets/README.md), white at 3× for tinting.
abstract final class SheetArt {
  static const dislike = 'assets/images/offline/sheet_dislike.png';
  static const watchLater = 'assets/images/offline/sheet_watch_later.png';
  static const download = 'assets/images/offline/sheet_download.png';
  static const miniPlayer = 'assets/images/offline/sheet_mini_player.png';
  static const cast = 'assets/images/offline/sheet_cast.png';
  static const share = 'assets/images/offline/sheet_share.png';
  static const done = 'assets/images/offline/sheet_done.png';
}

/// [asset] tinted [color], [width] wide at its own shape.
class SheetIcon extends StatelessWidget {
  const SheetIcon(this.asset, {super.key, required this.width, this.color});

  final String asset;
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: width,
    fit: BoxFit.contain,
    color: color ?? DownloadSheetTheme.colorsOf(context).ink,
    colorBlendMode: BlendMode.srcIn,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}

/// A press in the light sheets: dims under the finger and answers accessibility presses under [label].
class SheetTap extends StatefulWidget {
  const SheetTap({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected,
    this.toggled,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool? selected;
  final bool? toggled;
  final bool enabled;

  @override
  State<SheetTap> createState() => _SheetTapState();
}

class _SheetTapState extends State<SheetTap> {
  var _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.enabled ? widget.onTap : null;
    return Semantics(
      button: widget.toggled == null,
      enabled: widget.enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onTapDown: onTap == null ? null : (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedOpacity(
          opacity: _down ? 0.6 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}
