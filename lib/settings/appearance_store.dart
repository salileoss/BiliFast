import 'dart:convert';
import 'dart:io';

import 'package:bili_core/devlog.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';

/// The device's appearance choice, applied immediately and restored before the first app frame.
class AppearanceStore extends ChangeNotifier implements ValueListenable<ThemeMode> {
  AppearanceStore._(this._path, this._logger, this._mode);

  factory AppearanceStore.memory({ThemeMode mode = ThemeMode.light, Logger? logger}) =>
      AppearanceStore._(null, logger ?? Logger.shared, mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light);

  static Future<AppearanceStore> load(String? path, {Logger? logger}) async {
    final log = logger ?? Logger.shared;
    var mode = ThemeMode.light;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final json = jsonDecode(await file.readAsString());
          if (json is! Map<String, Object?>) throw const FormatException('not an object');
          mode = json['mode'] == 'dark' ? ThemeMode.dark : ThemeMode.light;
        }
      } catch (error) {
        log.warn(LogCategory.app, 'appearance unreadable, using light', {'error': '${error.runtimeType}'});
      }
    }
    return AppearanceStore._(path, log, mode);
  }

  final String? _path;
  final Logger _logger;
  ThemeMode _mode;
  Future<void> _writing = Future.value();

  ThemeMode get mode => _mode;
  @override
  ThemeMode get value => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() => select(isDark ? ThemeMode.light : ThemeMode.dark);

  void select(ThemeMode mode) {
    final next = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    final path = _path;
    if (path != null) {
      final text = jsonEncode({'mode': next.name});
      _writing = _writing.then((_) => _write(path, text));
    }
  }

  Future<void> _write(String path, String text) async {
    try {
      await File(path).parent.create(recursive: true);
      final temporary = File('$path.tmp');
      await temporary.writeAsString(text, flush: true);
      await temporary.rename(path);
    } catch (error) {
      _logger.warn(LogCategory.app, 'appearance not saved', {'error': '${error.runtimeType}'});
    }
  }

  Future<void> settle() => _writing;
}
