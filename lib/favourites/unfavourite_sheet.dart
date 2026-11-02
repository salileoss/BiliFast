import 'package:flutter/widgets.dart';

import '../shared/theme.dart';
import 'favourite_rows.dart';
import 'favourites_glyphs.dart';
import 'favourites_model.dart';

/// A row's ⋮ (82): the page dims and a white sheet rises with 取消收藏 and 取消. The official sheet's row of other apps
/// to share to is left out (the app can't offer them). An in-page layer, not a route: [row] holds the row it is for,
/// and setting it to null (取消, a tap on the dim, back) closes it.
class UnfavouriteSheet extends StatefulWidget {
  const UnfavouriteSheet({super.key, required this.row, required this.onRemove});

  final ValueNotifier<FavouriteRow?> row;
  final ValueChanged<FavouriteRow> onRemove;

  @override
  State<UnfavouriteSheet> createState() => _UnfavouriteSheetState();
}

class _UnfavouriteSheetState extends State<UnfavouriteSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: FavouritesTheme.sheetIn,
    reverseDuration: FavouritesTheme.sheetOut,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The row shown: the open one, or the one going away after a close.
  FavouriteRow? _shown;

  @override
  void initState() {
    super.initState();
    widget.row.addListener(_changed);
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && widget.row.value == null && mounted) {
        setState(() => _shown = null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    _motion
      ..duration = still ? Duration.zero : FavouritesTheme.sheetIn
      ..reverseDuration = still ? Duration.zero : FavouritesTheme.sheetOut;
  }

  @override
  void didUpdateWidget(UnfavouriteSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.row, widget.row)) {
      oldWidget.row.removeListener(_changed);
      widget.row.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.row.removeListener(_changed);
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _changed() {
    final next = widget.row.value;
    if (next == null) {
      if (_shown != null) _motion.reverse();
      return;
    }
    setState(() => _shown = next);
    _motion.forward();
  }

  void _close() => widget.row.value = null;

  @override
  Widget build(BuildContext context) {
    final row = _shown;
    if (row == null) return const SizedBox.shrink();
    final open = widget.row.value != null;
    return IgnorePointer(
      ignoring: !open,
      child: ExcludeSemantics(
        excluding: !open,
        // Up, it is modal: VoiceOver reads only it, not the rows under it.
        child: BlockSemantics(
          blocking: open,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('fav-sheet-dim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: FadeTransition(
                    opacity: _curve,
                    child: const ColoredBox(color: FavouritesTheme.sheetDim),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(_curve),
                  child: _Sheet(onRemove: () => widget.onRemove(row), onCancel: _close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _text(String text, double size, Color color) => Transform.translate(
  offset: Offset(0, FavouritesTheme.sheetTextDrop),
  child: Text(text, style: favStyle(size, color, line: 1)),
);

class _Sheet extends StatelessWidget {
  const _Sheet({required this.onRemove, required this.onCancel});

  final VoidCallback onRemove;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('fav-sheet'),
    color: FavouritesTheme.colorsOf(context).sheetFill,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: FavouritesTheme.sheetRemoveHeight,
          child: Stack(
            children: [
              Positioned(
                left: FavouritesTheme.sheetItemCentre - FavouritesTheme.sheetItemWidth / 2,
                top: 0,
                bottom: 0,
                width: FavouritesTheme.sheetItemWidth,
                child: FavTap(
                  key: const ValueKey('fav-sheet-remove'),
                  label: '取消收藏',
                  onTap: onRemove,
                  child: Stack(
                    children: [
                      Positioned(
                        top: FavouritesTheme.sheetStarTop,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FavGlyphIcon(
                            FavGlyph.starOff,
                            width: FavouritesTheme.sheetStarWidth,
                            height: FavouritesTheme.sheetStarHeight,
                            color: FavouritesTheme.colorsOf(context).sheetRemoveInk,
                            stroke: FavouritesTheme.sheetStarStroke,
                          ),
                        ),
                      ),
                      Positioned(
                        top: FavouritesTheme.sheetLabelTop,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _text('取消收藏', FavouritesTheme.sheetLabelText, FavouritesTheme.colorsOf(context).sheetRemoveInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: FavouritesTheme.sheetBand,
          child: ColoredBox(color: FavouritesTheme.colorsOf(context).sheetBandFill),
        ),
        FavTap(
          key: const ValueKey('fav-sheet-cancel'),
          label: '取消',
          onTap: onCancel,
          child: SizedBox(
            height: FavouritesTheme.sheetCancelHeight,
            child: Center(child: _text('取消', FavouritesTheme.sheetCancelText, FavouritesTheme.colorsOf(context).sheetCancelInk)),
          ),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    ),
  );
}
