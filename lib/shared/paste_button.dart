import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// The link field's paste button. Reading the clipboard from code makes iOS ask "Allow Paste?" every time, so on
/// iOS this is the system's own paste control, which never asks (Swift's PasteButton); elsewhere it reads the
/// clipboard. [onText] gets the pasted text, trimmed, empty when there was none.
class PasteButton extends StatelessWidget {
  const PasteButton({super.key, required this.enabled, required this.onText});

  final bool enabled;
  final ValueChanged<String> onText;

  Future<void> _read() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    onText(data?.text?.trim() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      return _NativePasteControl(enabled: enabled, onText: onText);
    }
    return IconButton(
      onPressed: enabled ? _read : null,
      tooltip: '粘贴',
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.content_paste_rounded, size: BiliMetrics.iconSize, color: BiliColors.colorsOf(context).pink),
    );
  }
}

/// UIPasteControl in a platform view (PasteControl.swift), talking over its own `bilifast/paste_control/<id>`.
class _NativePasteControl extends StatefulWidget {
  const _NativePasteControl({required this.enabled, required this.onText});

  static const viewType = 'bilifast/paste_control';

  final bool enabled;
  final ValueChanged<String> onText;

  @override
  State<_NativePasteControl> createState() => _NativePasteControlState();
}

class _NativePasteControlState extends State<_NativePasteControl> {
  /// The control must get the touch itself: the system pastes only on a real tap on it.
  static final _gestures = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  };

  MethodChannel? _channel;

  void _created(int id) {
    if (!mounted) return;
    _channel?.setMethodCallHandler(null);
    _channel = MethodChannel('${_NativePasteControl.viewType}/$id')..setMethodCallHandler(_handle);
  }

  /// The control enables itself from what the clipboard holds, so a disabled button only refuses the touch here and
  /// drops a paste that lands late.
  Future<void> _handle(MethodCall call) async {
    switch (call.method) {
      case 'paste':
        if (mounted && widget.enabled) widget.onText((call.arguments as String? ?? '').trim());
      case 'layout':
        // A control given less room than it wants turns itself off without a word; this says whether it fits.
        final sizes = call.arguments as Map<Object?, Object?>? ?? const {};
        Logger.shared.info(LogCategory.ui, 'paste control', {
          for (final MapEntry(:key, :value) in sizes.entries) '$key': ?value,
        });
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.enabled,
    child: SizedBox(
      width: BiliMetrics.pasteControlWidth,
      height: BiliMetrics.pasteControlHeight,
      child: UiKitView(
        key: ValueKey(BiliPalette.of(context).brightness),
        viewType: _NativePasteControl.viewType,
        creationParams: <String, Object?>{
          'fill': BiliColors.colorsOf(context).pink.toARGB32(),
          'glyph': BiliColors.onPink.toARGB32(),
        },
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: _gestures,
        onPlatformViewCreated: _created,
      ),
    ),
  );
}
