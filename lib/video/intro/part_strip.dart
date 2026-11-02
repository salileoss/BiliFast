import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../shared/menu.dart';
import '../../shared/theme.dart';
import '../player_session.dart' show Episode;
import 'collection_row.dart';

/// A video in parts: 选集 N/M > over a row of part chips; a chip plays its part, the header opens the 选集 sheet.
class PartStrip extends StatefulWidget {
  const PartStrip({super.key, required this.parts, required this.onChoose, required this.onOpenList});

  final List<Episode> parts;
  final ValueChanged<Episode> onChoose;
  final VoidCallback onOpenList;

  @override
  State<PartStrip> createState() => _PartStripState();
}

class _PartStripState extends State<PartStrip> {
  ScrollController? _scroll;

  int get _current => widget.parts.indexWhere((part) => part.current);

  /// Puts the playing chip in the middle of the strip where the strip can scroll that far.
  double _offsetFor(int index, double viewport) {
    const pitch = IntroListTheme.partChipWidth + IntroListTheme.partChipGap;
    final centre = BiliMetrics.gutter + index * pitch + IntroListTheme.partChipWidth / 2;
    final content = BiliMetrics.gutter * 2 + widget.parts.length * pitch - IntroListTheme.partChipGap;
    return math.max(0, math.min(centre - viewport / 2, content - viewport));
  }

  @override
  void didUpdateWidget(PartStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.parts.indexWhere((part) => part.current);
    final now = _current;
    if (now < 0 || now == before) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scroll = _scroll;
      if (!mounted || scroll == null || !scroll.hasClients) return;
      final position = scroll.position;
      final target = _offsetFor(now, position.viewportDimension).clamp(0.0, position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context)) {
        scroll.jumpTo(target);
      } else {
        scroll.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic).ignore();
      }
    });
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.parts;
    if (parts.isEmpty) return const SizedBox.shrink();
    final current = _current;
    final place = current < 0 ? '${parts.length}' : '${current + 1}/${parts.length}';
    return Padding(
      padding: const EdgeInsets.only(top: IntroListTheme.sectionTop, bottom: IntroListTheme.sectionBottom),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: '选集',
              value: place,
              onTap: widget.onOpenList,
              excludeSemantics: true,
              child: PressHighlight(
                onTap: widget.onOpenList,
                child: SizedBox(
                  height: IntroListTheme.partHeaderHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: BiliMetrics.gutter,
                      right: BiliMetrics.gutter + IntroListTheme.collectionTrailing - IntroListTheme.collectionLead,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '选集',
                            style: TextStyle(
                              fontFamily: BiliFonts.family,
                              fontSize: IntroListTheme.collectionTitleText,
                              color: BiliColors.colorsOf(context).text,
                            ),
                          ),
                        ),
                        Text(
                          place,
                          style: TextStyle(
                            fontFamily: BiliFonts.family,
                            fontSize: IntroListTheme.collectionPlaceText,
                            color: BiliColors.colorsOf(context).secondaryText,
                          ),
                        ),
                        const SizedBox(width: IntroListTheme.collectionChevronGap),
                        Chevron(
                          size: Size(IntroListTheme.collectionChevronWidth, IntroListTheme.collectionChevronHeight),
                          stroke: IntroListTheme.chevronStroke,
                          color: BiliColors.colorsOf(context).secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: IntroListTheme.partChipHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _scroll ??= ScrollController(
                    initialScrollOffset: current < 0 ? 0 : _offsetFor(current, constraints.maxWidth),
                  );
                  return ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: BiliMetrics.gutter),
                    itemCount: parts.length,
                    separatorBuilder: (context, index) => const SizedBox(width: IntroListTheme.partChipGap),
                    itemBuilder: (context, index) {
                      final part = parts[index];
                      return _PartChip(
                        key: ValueKey('part-${part.cid}'),
                        part: part,
                        onTap: () {
                          if (!part.current) widget.onChoose(part);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartChip extends StatefulWidget {
  const _PartChip({super.key, required this.part, required this.onTap});

  final Episode part;
  final VoidCallback onTap;

  @override
  State<_PartChip> createState() => _PartChipState();
}

class _PartChipState extends State<_PartChip> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.part.current;
    final still = MediaQuery.disableAnimationsOf(context);
    final colour = playing ? BiliColors.colorsOf(context).pink : BiliColors.colorsOf(context).text;
    final style = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: IntroListTheme.partChipText,
      height: IntroListTheme.partChipLine / IntroListTheme.partChipText,
      color: colour,
    );
    return Semantics(
      button: true,
      selected: playing,
      label: widget.part.title,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? BiliMetrics.pressedScale : 1,
          duration: still ? Duration.zero : const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: IntroListTheme.partChipWidth,
            padding: const EdgeInsets.symmetric(horizontal: IntroListTheme.partChipPad),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: BiliColors.colorsOf(context).softGrey,
              borderRadius: BorderRadius.circular(BiliMetrics.cardRadius),
              border: Border.all(
                color: playing ? BiliColors.colorsOf(context).pink : BiliColors.colorsOf(context).softGrey,
                width: IntroListTheme.partChipBorder,
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  if (playing)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: IntroListTheme.partPlayingGap),
                        child: PlayingBars(color: BiliColors.colorsOf(context).pink, height: IntroListTheme.partChipText * 0.85),
                      ),
                    ),
                  TextSpan(text: widget.part.title),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
              strutStyle: BiliFonts.strut(style),
            ),
          ),
        ),
      ),
    );
  }
}
