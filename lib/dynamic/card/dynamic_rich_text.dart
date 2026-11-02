import 'dart:async';
import 'dart:ui' as ui;

import 'package:bili_core/api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../shared/remote_image.dart';
import '../../shared/theme.dart';
import '../../shared/toast.dart';
import '../../space/uploader_tap.dart';
import '../../video/video_route.dart';
import 'dynamic_open.dart';

/// A post's text: topics and links blue, emotes inline, @names opening the space, a video link (▶) opening the video,
/// badges (🎁 互动抽奖) toasting. Past [maxLines], or always when [folded], it ends in ... [moreLabel] (全文 / 展开),
/// tapped to [onMore].
class DynamicRichText extends StatefulWidget {
  const DynamicRichText({
    super.key,
    required this.nodes,
    required this.style,
    this.maxLines,
    this.folded = false,
    this.moreLabel = '全文',
    this.onMore,
  });

  final List<DynamicNode> nodes;
  final TextStyle style;
  final int? maxLines;

  /// The server cut the text, so … [moreLabel] shows even when it fits.
  final bool folded;
  final String moreLabel;
  final VoidCallback? onMore;

  /// What the text ends with when cut: three periods and a space before [moreLabel] (127, 128).
  static const ellipsis = '... ';

  @override
  State<DynamicRichText> createState() => _DynamicRichTextState();
}

class _DynamicRichTextState extends State<DynamicRichText> {
  final _recognizers = <TapGestureRecognizer>[];
  TapGestureRecognizer? _more;
  late List<_Run> _runs;
  late int _units;
  bool _large = false;

  /// The last cut, kept while nothing that decides it changes.
  Object? _cutFor;
  int? _cut;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _build();
  }

  @override
  void didUpdateWidget(DynamicRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.nodes, widget.nodes) ||
        oldWidget.style.fontSize != widget.style.fontSize ||
        (oldWidget.onMore == null) != (widget.onMore == null)) {
      _build();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _more?.dispose();
    _more = null;
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  void _build() {
    _disposeRecognizers();
    _cutFor = null;
    _more = widget.onMore == null ? null : (TapGestureRecognizer()..onTap = () => widget.onMore?.call());
    final linked = TextStyle(color: DynamicCardTheme.colorsOf(context).linkInk);
    final runs = <_Run>[];
    _large = false;
    for (final node in widget.nodes) {
      switch (node) {
        case DynamicTextNode(:final text):
          runs.add(_TextRun(text));
        case DynamicEmojiNode(:final text, :final url) when url.isEmpty:
          runs.add(_TextRun(text));
        case DynamicEmojiNode(:final text, :final url, :final large):
          if (large) _large = true;
          final side = large ? DynamicCardTheme.emoteLarge : DynamicCardTheme.emote;
          runs.add(
            _WidgetRun(
              Size.square(side),
              Semantics(
                label: text,
                image: true,
                child: RemoteImage(
                  url,
                  size: Size.square(side),
                  fit: BoxFit.contain,
                  placeholder: const SizedBox.shrink(),
                ),
              ),
            ),
          );
        case DynamicMentionNode(:final text, :final mid):
          final name = text.startsWith('@') ? text : '@$text';
          runs.add(_TextRun(name, linked, mid > 0 ? _tap(() => _openSpace(mid, name)) : null));
        case DynamicTopicNode(:final text):
          runs.add(_TextRun(text, linked, _tap(_soon)));
        case DynamicLinkNode(:final text, :final url):
          runs.add(_TextRun(text, linked, _tap(() => unawaited(openDynamicLink(context, url)))));
        case DynamicVideoLinkNode(:final text, :final bvid):
          void open() => unawaited(DynamicOpen.video(context, VideoRoute(bvid: bvid)));
          runs
            ..add(
              _WidgetRun(
                const Size(
                  DynamicCardTheme.videoLinkBefore + DynamicCardTheme.videoLinkSide + DynamicCardTheme.videoLinkAfter,
                  DynamicCardTheme.videoLinkSide,
                ),
                _IconTap(
                  onTap: open,
                  before: DynamicCardTheme.videoLinkBefore,
                  child: DynamicIcon(
                    DynamicArt.videoLink,
                    width: DynamicCardTheme.videoLinkSide,
                    color: DynamicCardTheme.colorsOf(context).linkInk,
                  ),
                ),
              ),
            )
            ..add(_TextRun(text, linked, _tap(open)));
        case DynamicBadgeNode(:final text, :final kind):
          if (kind == 'lottery') {
            runs.add(
              _WidgetRun(
                const Size(
                  DynamicCardTheme.giftBefore + DynamicCardTheme.giftWidth + DynamicCardTheme.giftAfter,
                  DynamicCardTheme.giftHeight,
                ),
                _IconTap(
                  onTap: _soon,
                  before: DynamicCardTheme.giftBefore,
                  child: DynamicIcon(
                    DynamicArt.gift,
                    width: DynamicCardTheme.giftWidth,
                    height: DynamicCardTheme.giftHeight,
                    color: DynamicCardTheme.colorsOf(context).linkInk,
                  ),
                ),
              ),
            );
          }
          runs.add(_TextRun(text, linked, _tap(_soon)));
      }
    }
    _runs = runs;
    _units = runs.fold(0, (sum, run) => sum + run.length);
  }

  void _soon() => showToast(context, notBuilt);

  void _openSpace(int mid, String name) {
    final bare = name.startsWith('@') ? name.substring(1) : name;
    unawaited(DynamicOpen.space(context, UploaderRef(mid: mid, name: bare.isEmpty ? null : bare)));
  }

  /// The runs' first [units] as spans, the placeholders' sizes in their order into [sizes].
  List<InlineSpan> _spans(int units, List<Size> sizes) {
    final spans = <InlineSpan>[];
    var left = units;
    for (final run in _runs) {
      if (left <= 0) break;
      final take = run.length < left ? run.length : left;
      spans.add(run.span(take, sizes));
      left -= take;
    }
    return spans;
  }

  List<InlineSpan> _suffix() => [
    const TextSpan(text: DynamicRichText.ellipsis),
    TextSpan(
      text: widget.moreLabel,
      style: TextStyle(color: DynamicCardTheme.colorsOf(context).linkInk),
      recognizer: _more,
    ),
  ];

  /// How many units show before … [DynamicRichText.moreLabel], or null when the whole text shows as it is.
  int? _cutAt(BuildContext context, double width, TextStyle style, StrutStyle? strut) {
    final maxLines = widget.maxLines;
    if (maxLines == null || !width.isFinite) return null;
    final defaults = DefaultTextStyle.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final key = (width, style, maxLines, widget.folded, widget.moreLabel, scaler);
    if (key == _cutFor) return _cut;

    bool fits(int units, {required bool withSuffix}) {
      final sizes = <Size>[];
      final spans = _spans(units, sizes);
      final painter =
          TextPainter(
            text: TextSpan(style: style, children: [...spans, if (withSuffix) ..._suffix()]),
            textDirection: TextDirection.ltr,
            maxLines: maxLines,
            strutStyle: strut,
            textScaler: scaler,
            locale: locale,
            textHeightBehavior: defaults.textHeightBehavior,
            textWidthBasis: defaults.textWidthBasis,
          )..setPlaceholderDimensions([
            for (final size in sizes) PlaceholderDimensions(size: size, alignment: ui.PlaceholderAlignment.middle),
          ]);
      painter.layout(maxWidth: width);
      final fit = !painter.didExceedMaxLines;
      painter.dispose();
      return fit;
    }

    int? cut;
    if (widget.folded || !fits(_units, withSuffix: false)) {
      if (fits(_units, withSuffix: true)) {
        cut = _units;
      } else {
        var low = 0, high = _units;
        while (low < high) {
          final middle = (low + high + 1) ~/ 2;
          if (fits(middle, withSuffix: true)) {
            low = middle;
          } else {
            high = middle - 1;
          }
        }
        cut = low;
      }
      cut = _trimmed(cut);
    }
    _cutFor = key;
    _cut = cut;
    return cut;
  }

  /// [units] less the spaces and line breaks they end with, so … follows the last word.
  int _trimmed(int units) {
    var at = units;
    while (at > 0) {
      final (run, offset) = _locate(at - 1);
      if (run is! _TextRun) break;
      final unit = run.text.codeUnitAt(offset);
      if (unit != 0x20 && unit != 0x0A && unit != 0x3000 && unit != 0x09) break;
      at -= 1;
    }
    return at;
  }

  (_Run, int) _locate(int unit) {
    var left = unit;
    for (final run in _runs) {
      if (left < run.length) return (run, left);
      left -= run.length;
    }
    return (_runs.last, _runs.last.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final strut = _large ? null : BiliFonts.strut(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cut = _cutAt(context, constraints.maxWidth, style, strut);
        final spans = cut == null ? _spans(_units, []) : [..._spans(cut, []), ..._suffix()];
        return Text.rich(
          TextSpan(children: spans),
          style: widget.style,
          strutStyle: strut,
          maxLines: widget.maxLines,
          overflow: widget.maxLines == null ? null : TextOverflow.clip,
        );
      },
    );
  }
}

sealed class _Run {
  int get length;

  InlineSpan span(int units, List<Size> sizes);
}

final class _TextRun extends _Run {
  _TextRun(this.text, [this.style, this.recognizer]);

  final String text;
  final TextStyle? style;
  final GestureRecognizer? recognizer;

  @override
  int get length => text.length;

  @override
  InlineSpan span(int units, List<Size> sizes) {
    var end = units;
    // Never between the halves of a surrogate pair.
    if (end < text.length && end > 0 && _isHighSurrogate(text.codeUnitAt(end - 1))) end -= 1;
    return TextSpan(text: end >= text.length ? text : text.substring(0, end), style: style, recognizer: recognizer);
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
}

final class _WidgetRun extends _Run {
  _WidgetRun(this.size, this.child);

  final Size size;
  final Widget child;

  @override
  int get length => 1;

  @override
  InlineSpan span(int units, List<Size> sizes) {
    sizes.add(size);
    return WidgetSpan(
      alignment: ui.PlaceholderAlignment.middle,
      child: SizedBox.fromSize(size: size, child: child),
    );
  }
}

/// An icon inside the text, [before] in from its box's left, tapped as the words after it.
class _IconTap extends StatelessWidget {
  const _IconTap({required this.onTap, required this.before, required this.child});

  final VoidCallback onTap;
  final double before;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.only(left: before),
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );
}
