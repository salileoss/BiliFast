import 'dart:async';

import 'package:bili_core/api.dart' hide RichText;
import 'package:bili_core/api.dart' as bili show RichText;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../shared/theme.dart';
import '../../space/space_route.dart';
import '../../space/uploader_tap.dart';

/// Mentions come from `desc_v2`'s typed parts; web addresses, timestamps and video ids are found in the plain parts
/// (BiliNative `TitleBlock.descriptionRuns`).
List<RichRun> descriptionRuns(List<DescPart> parts) => [
  for (final part in parts)
    if (part.mentionMid case final mid?) RichRun.mention(name: part.text, mid: mid) else ..._plainRuns(part.text),
];

/// The view API sends no jump links for a description, only its text: web addresses written out in it are the
/// links. They are cut out before [bili.RichText] looks for ids and timestamps, so a BV id inside an address stays part
/// of the address.
List<RichRun> _plainRuns(String text) {
  final runs = <RichRun>[];
  var start = 0;
  for (final match in _webAddress.allMatches(text)) {
    var written = match.group(0)!;
    final trailing = _trailingPunctuation.firstMatch(written)?.group(0) ?? '';
    written = written.substring(0, written.length - trailing.length);
    if (written.length <= 'www.'.length) continue;
    final url = written.toLowerCase().startsWith('www.') ? 'http://$written' : written;
    if (start < match.start) runs.addAll(_noLinks(text.substring(start, match.start)));
    runs.add(RichRun.link(title: written, url: url));
    start = match.start + written.length;
  }
  if (start < text.length) runs.addAll(_noLinks(text.substring(start)));
  return runs;
}

List<RichRun> _noLinks(String text) => bili.RichText.runs(text, emotes: const {}, mentions: const {}, links: const {});

/// Stops at whitespace and at the full-width punctuation Chinese text puts right after an address.
final _webAddress = RegExp(r'(?:https?://|www\.)[^\s，。！？、；：（）【】《》「」『』“”‘’<>"]+', caseSensitive: false);
final _trailingPunctuation = RegExp(r'''[.,;:!?)\]}'"]+$''');

/// What a tap on a link run does: a bilibili.com video address, BV or av, opens the video in the app, anything else
/// goes to the browser. Null for a run that is not a link.
({String? video, Uri? web})? linkTarget(RichRun run) {
  if (run is! LinkRun) return null;
  final uri = Uri.tryParse(run.url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;
  if (uri.host.endsWith('bilibili.com') && uri.path.startsWith('/video/')) {
    switch (LinkParser.parse(run.url)) {
      case BvidLink(:final id):
        return (video: id, web: null);
      case AidLink(:final id):
        return (video: 'av$id', web: null);
      default:
        break;
    }
  }
  return (video: null, web: uri);
}

/// Flutter draws a tab as one space, where the official app moves to the next of iOS's tab stops. Only tabs that open a
/// line are placed: there the stop is known without measuring the line. Leading spaces stay as written.
List<InlineSpan> _tabbed(String text, {required bool lineStart}) {
  final spans = <InlineSpan>[];
  var start = 0;
  for (final match in _leadingTabs.allMatches(text)) {
    if (match.start == 0 && !lineStart) continue;
    if (start < match.start) spans.add(TextSpan(text: text.substring(start, match.start)));
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(width: match[0]!.length * IntroTheme.descTabStop),
      ),
    );
    start = match.end;
  }
  if (start < text.length || spans.isEmpty) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}

final _leadingTabs = RegExp(r'(?<=^|\n)\t+');

/// The description as one paragraph: timestamps, links, video ids and mentions in the link colour and tappable (a
/// mention opens that uploader's space), the rest in [style].
class DescriptionText extends StatefulWidget {
  const DescriptionText({
    super.key,
    required this.runs,
    required this.style,
    required this.onSeek,
    required this.onOpenVideo,
    required this.onOpenLink,
  });

  final List<RichRun> runs;
  final TextStyle style;
  final ValueChanged<double> onSeek;
  final ValueChanged<String> onOpenVideo;
  final ValueChanged<Uri> onOpenLink;

  @override
  State<DescriptionText> createState() => _DescriptionTextState();
}

class _DescriptionTextState extends State<DescriptionText> {
  final _recognizers = <TapGestureRecognizer>[];
  late List<InlineSpan> _spans;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _spans = _build();
  }

  @override
  void didUpdateWidget(DescriptionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.runs, widget.runs)) _spans = _build();
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
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  /// Taps read the callbacks from [widget] when they happen, so only new runs need new spans.
  List<InlineSpan> _build() {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var lineStart = true;
    for (final run in widget.runs) {
      if (run case TextRun(:final text)) {
        spans.addAll(_tabbed(text, lineStart: lineStart));
        if (text.isNotEmpty) lineStart = text.endsWith('\n');
      } else {
        spans.add(_span(run));
        lineStart = false;
      }
    }
    return spans;
  }

  InlineSpan _span(RichRun run) {
    final linked = TextStyle(color: BiliColors.colorsOf(context).link);
    return switch (run) {
      TextRun(:final text) => TextSpan(text: text),
      EmoteRun(:final token) => TextSpan(text: token),
      MentionRun(:final name, :final mid) => TextSpan(
        text: name.startsWith('@') ? name : '@$name',
        style: linked,
        recognizer: mid > 0
            ? _tap(() => unawaited(openSpace(context, UploaderRef(mid: mid, name: name.replaceFirst('@', '')))))
            : null,
      ),
      TimestampRun(:final label, :final seconds) => TextSpan(
        text: label,
        style: linked,
        recognizer: _tap(() => widget.onSeek(seconds.toDouble())),
      ),
      VideoRun(:final id) => TextSpan(text: id, style: linked, recognizer: _tap(() => widget.onOpenVideo(id))),
      LinkRun(:final title) => switch (linkTarget(run)) {
        (video: final String id, web: _) => TextSpan(
          text: title,
          style: linked,
          recognizer: _tap(() => widget.onOpenVideo(id)),
        ),
        (video: _, web: final Uri uri) => TextSpan(
          text: title,
          style: linked,
          recognizer: _tap(() => widget.onOpenLink(uri)),
        ),
        _ => TextSpan(text: title),
      },
    };
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(style: widget.style, children: _spans),
    strutStyle: BiliFonts.strutOf(context, widget.style),
  );
}
