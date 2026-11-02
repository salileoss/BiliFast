import 'package:flutter/widgets.dart';

import '../../shared/menu.dart';
import '../../shared/theme.dart';
import '../player_session.dart' show Episode;

/// 合集 · name, with the playing episode's place (⫴ 221/221 >) (03). Opens the 选集 sheet.
class CollectionRow extends StatelessWidget {
  const CollectionRow({super.key, required this.title, required this.episodes, required this.onOpen});

  final String title;
  final List<Episode> episodes;
  final VoidCallback onOpen;

  /// "2/3", or just the count when none of them is playing (a later part of a listed video).
  static String place(List<Episode> episodes) {
    final index = episodes.indexWhere((episode) => episode.current);
    return index < 0 ? '${episodes.length}' : '${index + 1}/${episodes.length}';
  }

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) return const SizedBox.shrink();
    final place = CollectionRow.place(episodes);
    final radius = BorderRadius.circular(BiliMetrics.cardRadius);
    final titleStyle = TextStyle(
      fontFamily: BiliFonts.family,
      fontSize: IntroListTheme.collectionTitleText,
      color: BiliColors.colorsOf(context).text,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BiliMetrics.gutter,
        IntroListTheme.sectionTop,
        BiliMetrics.gutter,
        IntroListTheme.sectionBottom,
      ),
      child: Semantics(
        button: true,
        label: '合集 · $title',
        value: place,
        onTap: onOpen,
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: radius,
          child: PressHighlight(
            onTap: onOpen,
            child: Container(
              height: IntroListTheme.collectionHeight,
              color: BiliColors.colorsOf(context).softGrey,
              padding: const EdgeInsets.only(
                left: IntroListTheme.collectionLead,
                right: IntroListTheme.collectionTrailing,
              ),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '合集 · $title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                        strutStyle: BiliFonts.strutOf(context, titleStyle),
                      ),
                    ),
                    const SizedBox(width: BiliMetrics.gutter),
                    PlayingBars(color: BiliColors.colorsOf(context).secondaryText),
                    const SizedBox(width: IntroListTheme.collectionBarsGap),
                    Text(
                      place,
                      maxLines: 1,
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
      ),
    );
  }
}

/// The official app's "now playing" mark: a short bar between two tall ones, centred on the line.
class PlayingBars extends StatelessWidget {
  const PlayingBars({super.key, required this.color, this.height = IntroListTheme.barsHeight});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(IntroListTheme.barsWidth * height / IntroListTheme.barsHeight, height),
    painter: _BarsPainter(color),
  );
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = IntroListTheme.barWidth * size.height / IntroListTheme.barsHeight;
    final step = (size.width - bar) / 2;
    final paint = Paint()..color = color;
    for (final (index, share) in IntroListTheme.barShares.indexed) {
      final h = size.height * share;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(index * step, (size.height - h) / 2, bar, h), Radius.circular(bar / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => oldDelegate.color != color;
}

/// A thin › with round ends, as at the end of the official app's rows and chips.
class Chevron extends StatelessWidget {
  const Chevron({super.key, required this.size, required this.stroke, required this.color});

  final Size size;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: size, painter: _ChevronPainter(stroke, color));
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.stroke, this.color);

  final double stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = stroke / 2;
    canvas.drawPath(
      Path()
        ..moveTo(inset, inset)
        ..lineTo(size.width - inset, size.height / 2)
        ..lineTo(inset, size.height - inset),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.stroke != stroke || oldDelegate.color != color;
}
