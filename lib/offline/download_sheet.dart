import 'package:bili_core/logic.dart' show QualityNames;
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../player_ui/player_ui.dart';
import '../shared/theme.dart';
import 'offline_library.dart';
import 'offline_models.dart';
import 'offline_size.dart';
import 'pages/offline_list_page.dart';
import 'sheet/download_entries.dart';
import 'sheet/download_rows.dart';
import 'sheet/quality_picker.dart';
import 'sheet/sheet_art.dart';

/// 缓存 (141, 144, 153, 154): 画质 with its picker (142), the part or the 合集's videos with each one's state, 缓存全部,
/// 查看缓存 and the space line.
class DownloadSheet extends StatefulWidget {
  const DownloadSheet({super.key, required this.ui, required this.toast, required this.close, this.cover});

  final PlayerUi ui;
  final void Function(String message) toast;
  final VoidCallback close;

  /// Puts a layer over the whole page (画质's picker dims the player too), or takes it off with null.
  final ValueChanged<Widget?>? cover;

  /// 已使用 78.6M / 剩余 74.4G: the sheet drops the B that 离线缓存 writes (144); nothing used, or unknown, is - (141).
  static String space(int? bytes) =>
      bytes == null || bytes <= 0 ? '-' : formatBytes(bytes).replaceFirst(RegExp(r'B$'), '');

  @override
  State<DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<DownloadSheet> {
  int? _quality;
  final _current = GlobalKey();
  var _revealed = false;

  OfflineLibrary? get _library => context.getInheritedWidgetOfExactType<AppScope>()?.services.offline;

  /// What the default quality was picked from; the session notifies far more often than these change.
  late Object? _streams = widget.ui.session.dash;
  late Object _offered = widget.ui.session.qualities;

  @override
  void initState() {
    super.initState();
    widget.ui.session.addListener(_sessionChanged);
  }

  @override
  void didUpdateWidget(DownloadSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ui.session != widget.ui.session) {
      oldWidget.ui.session.removeListener(_sessionChanged);
      widget.ui.session.addListener(_sessionChanged);
    }
  }

  @override
  void dispose() {
    widget.ui.session.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    final session = widget.ui.session;
    if (identical(session.dash, _streams) && identical(session.qualities, _offered)) return;
    setState(() {
      _streams = session.dash;
      _offered = session.qualities;
    });
  }

  void _revealCurrent() {
    if (_revealed) return;
    _revealed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current.currentContext case final current? when mounted) {
        Scrollable.ensureVisible(current, alignment: 0.5);
      }
    });
  }

  int? _selected() {
    final qualities = downloadQualities(widget.ui.session);
    final chosen = _quality;
    if (chosen != null && qualities.options.any((option) => option.id == chosen)) return chosen;
    return qualities.best;
  }

  int? _estimate(int? quality, int seconds) {
    final dash = widget.ui.session.dash;
    if (dash == null || quality == null) return null;
    return estimateBytes(dash, quality: quality, seconds: seconds, codecOrder: [widget.ui.session.codec]);
  }

  Future<void> _queue(OfflineLibrary library, List<DownloadEntry> entries, int? quality) async {
    final parts = [
      for (final entry in entries)
        if (library.item(entry.cid) == null) entry.request,
    ];
    if (parts.isEmpty) return;
    await library.enqueue(parts, quality: quality);
  }

  void _tap(OfflineLibrary library, DownloadEntry entry, int? quality) {
    final item = library.item(entry.cid);
    if (item == null) {
      _queue(library, [entry], quality);
      return;
    }
    switch (item.state) {
      case OfflineState.paused || OfflineState.failed:
        library.resume(entry.cid);
      case OfflineState.waiting || OfflineState.downloading || OfflineState.done:
        break;
    }
  }

  void _openPicker(int? selected) {
    final cover = widget.cover;
    if (cover == null) return;
    final session = widget.ui.session;
    final seconds = session.part?.duration ?? session.duration.value.round();
    final options = downloadQualities(session).options;
    cover(
      QualityPicker(
        options: options,
        selected: selected,
        sizes: {for (final option in options) option.id: ?_estimate(option.id, seconds)},
        onPick: (quality) {
          if (mounted) setState(() => _quality = quality);
        },
        dismissed: () => cover(null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    if (library == null) return const SizedBox.shrink();
    // Landscape's side panel lays its content out with unbounded height, where this Column can't size: draw nothing
    // there. 缓存 is portrait only, and PanelLayer closes it on the turn.
    return LayoutBuilder(
      builder: (context, constraints) => !constraints.hasBoundedHeight
          ? const SizedBox.shrink()
          : ListenableBuilder(listenable: library, builder: (context, _) => _sheet(context, library)),
    );
  }

  Widget _sheet(BuildContext context, OfflineLibrary library) {
    final session = widget.ui.session;
    final entries = downloadEntries(session);
    final quality = _selected();
    final collection = entries.any((entry) => entry.cover != null);
    if (collection) _revealCurrent();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          name: quality == null
              ? '-'
              : QualityNames.full(
                  qn: quality,
                  serverText: session.qualities.where((option) => option.id == quality).firstOrNull?.name,
                ),
          onTap: widget.cover == null || quality == null ? null : () => _openPicker(quality),
        ),
        Expanded(
          child: ListView(
            key: const ValueKey('download-list'),
            primary: false,
            padding: EdgeInsets.only(
              left: DownloadSheetTheme.cardInset,
              right: DownloadSheetTheme.cardInset,
              bottom: collection ? 0 : DownloadSheetTheme.rowGap,
            ),
            children: [
              for (final (index, entry) in entries.indexed) ...[
                if (index > 0) const SizedBox(height: DownloadSheetTheme.rowGap),
                DownloadRow(
                  key: entry.current ? _current : ValueKey(entry.cid),
                  entry: entry,
                  item: library.item(entry.cid),
                  estimate: _estimate(quality, entry.request.duration),
                  onTap: () => _tap(library, entry, quality),
                ),
              ],
              if (collection)
                SizedBox(
                  height: DownloadSheetTheme.footerCentre + DownloadSheetTheme.footerBottom,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: DownloadSheetTheme.footerCentre - _line / 2,
                        height: _line,
                        child: Center(child: Text('内容到底啦', style: _footer(context))),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _Bar(
          bottom: bottom,
          unseen: library.unseen,
          used: library.usedBytes,
          free: library.freeBytes,
          queueAll: () => _queue(library, entries, quality),
          openList: () => openOfflineList(context),
        ),
      ],
    );
  }

  static TextStyle _footer(BuildContext context) => TextStyle(fontSize: BiliMetrics.sheetFooterText, color: BiliColors.colorsOf(context).sheetHint);
}

/// A box a line of the sheet's small text is centred in.
const _line = 24.0;

/// 画质, the chosen quality's name and ⌄; a tap opens the picker.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onTap});

  final String name;
  final VoidCallback? onTap;

  static TextStyle _label(BuildContext context) => TextStyle(fontSize: DownloadSheetTheme.headerText, color: DownloadSheetTheme.colorsOf(context).grey);
  static TextStyle _name(BuildContext context) => TextStyle(fontSize: DownloadSheetTheme.headerText, color: BiliColors.colorsOf(context).text);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: DownloadSheetTheme.listTop,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          top: DownloadSheetTheme.headerCentre - BiliMetrics.panelHitBox / 2,
          height: BiliMetrics.panelHitBox,
          child: SheetTap(
            key: const ValueKey('download-quality'),
            label: '画质 $name',
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DownloadSheetTheme.cardInset),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('画质', style: _label(context), strutStyle: BiliFonts.strutOf(context, _label(context))),
                  const SizedBox(width: DownloadSheetTheme.headerGap),
                  Text(name, style: _name(context), strutStyle: BiliFonts.strutOf(context, _name(context))),
                  const SizedBox(width: DownloadSheetTheme.headerChevronGap),
                  CustomPaint(
                    size: Size(DownloadSheetTheme.headerChevronWidth, DownloadSheetTheme.headerChevronHeight),
                    painter: _ChevronPainter(BiliColors.colorsOf(context).text),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const half = 0.6;
    canvas.drawPath(
      Path()
        ..moveTo(half, half)
        ..lineTo(size.width / 2, size.height - half)
        ..lineTo(size.width - half, half),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = half * 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}

/// The white bar (141): 缓存全部 | 查看缓存 (its red dot while something is new) over 已使用 X / 剩余 Y.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.bottom,
    required this.unseen,
    required this.used,
    required this.free,
    required this.queueAll,
    required this.openList,
  });

  final double bottom;
  final bool unseen;
  final int used;
  final int? free;
  final VoidCallback queueAll;
  final VoidCallback openList;

  static TextStyle _button(BuildContext context) => TextStyle(fontSize: DownloadSheetTheme.barButtonText, color: BiliColors.colorsOf(context).text);
  static TextStyle _label(BuildContext context) => TextStyle(fontSize: DownloadSheetTheme.barSpaceText, color: BiliColors.colorsOf(context).secondaryText);
  static TextStyle _value(BuildContext context) => TextStyle(
    fontSize: DownloadSheetTheme.barSpaceValueText,
    fontWeight: DownloadSheetTheme.barSpaceValueWeight,
    color: BiliColors.colorsOf(context).text,
  );

  Widget _half(BuildContext context, String key, String title, VoidCallback onTap, {bool dot = false}) => Expanded(
    child: SheetTap(
      key: ValueKey(key),
      label: dot ? '$title，有新内容' : title,
      onTap: onTap,
      child: SizedBox(
        height: DownloadSheetTheme.barButtonCentre * 2,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(title, style: _button(context), strutStyle: BiliFonts.strutOf(context, _button(context))),
              if (dot)
                Positioned(
                  key: const ValueKey('download-unseen'),
                  right: -(DownloadSheetTheme.dotSize / 2 + DownloadSheetTheme.dotRing),
                  top: -DownloadSheetTheme.dotLift - DownloadSheetTheme.dotRing,
                  child: Container(
                    width: DownloadSheetTheme.dotSize + DownloadSheetTheme.dotRing * 2,
                    height: DownloadSheetTheme.dotSize + DownloadSheetTheme.dotRing * 2,
                    decoration: BoxDecoration(
                      color: DownloadSheetTheme.dot,
                      shape: BoxShape.circle,
                      border: Border.all(color: DownloadSheetTheme.colorsOf(context).card, width: DownloadSheetTheme.dotRing),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final space = Text.rich(
      key: const ValueKey('download-space'),
      TextSpan(
        children: [
          TextSpan(text: '已使用 ', style: _label(context)),
          TextSpan(text: DownloadSheet.space(used), style: _value(context)),
          TextSpan(text: ' / ', style: _label(context)),
          TextSpan(text: '剩余 ', style: _label(context)),
          TextSpan(text: DownloadSheet.space(free), style: _value(context)),
        ],
      ),
      strutStyle: BiliFonts.strutOf(context, _label(context)),
    );
    return Container(
      height: DownloadSheetTheme.barHeight + bottom,
      decoration: BoxDecoration(
        color: DownloadSheetTheme.colorsOf(context).card,
        border: Border(
          top: BorderSide(color: DownloadSheetTheme.colorsOf(context).hairline, width: BiliMetrics.panelHairline),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: DownloadSheetTheme.barButtonCentre * 2,
            child: Row(
              children: [
                _half(context, 'download-all', '缓存全部', queueAll),
                Container(
                  width: BiliMetrics.panelHairline,
                  height: DownloadSheetTheme.barDivider,
                  color: DownloadSheetTheme.colorsOf(context).hairline,
                ),
                _half(context, 'download-open-list', '查看缓存', openList, dot: unseen),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: DownloadSheetTheme.barSpaceCentre - _line / 2,
            height: _line,
            child: Center(child: space),
          ),
        ],
      ),
    );
  }
}
