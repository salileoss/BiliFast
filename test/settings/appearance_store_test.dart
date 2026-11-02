import 'dart:io';

import 'package:bili_core/devlog.dart';
import 'package:bilifast/settings/appearance_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory folder;
  late String path;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('appearance_test');
    path = '${folder.path}/appearance.json';
  });

  tearDown(() => folder.deleteSync(recursive: true));

  test('first launch and unavailable support folder use light', () async {
    final store = await AppearanceStore.load(path);
    expect(store.mode, ThemeMode.light);
    expect(await File(path).exists(), isFalse);
    store.dispose();
    final memory = await AppearanceStore.load(null);
    memory.toggle();
    expect(memory.isDark, isTrue);
    memory.dispose();
  });

  test('choice changes immediately and survives reloading', () async {
    final store = await AppearanceStore.load(path);
    var notifications = 0;
    store.addListener(() => notifications++);
    store.toggle();
    expect(store.mode, ThemeMode.dark);
    expect(notifications, 1);
    store.select(ThemeMode.dark);
    expect(notifications, 1);
    await store.settle();
    final restored = await AppearanceStore.load(path);
    expect(restored.mode, ThemeMode.dark);
    store.dispose();
    restored.dispose();
  });

  test('rapid choices save in order, with the latest one restored', () async {
    final store = await AppearanceStore.load(path);
    store.toggle();
    store.toggle();
    store.toggle();
    await store.settle();
    final restored = await AppearanceStore.load(path);
    expect(restored.mode, ThemeMode.dark);
    store.dispose();
    restored.dispose();
  });

  test('malformed, unknown and non-object data fall back to light', () async {
    for (final content in ['broken', '[]', '{"mode":"future"}', '{"mode":false}']) {
      await File(path).writeAsString(content);
      final store = await AppearanceStore.load(path);
      expect(store.mode, ThemeMode.light, reason: content);
      store.dispose();
    }
  });

  test('failed writes keep the live choice and do not poison later writes', () async {
    final sink = MemorySink();
    final logger = Logger(session: 'appearance-test')..add(sink);
    await Directory(path).create();
    final store = await AppearanceStore.load(path, logger: logger);
    store.toggle();
    await store.settle();
    expect(store.mode, ThemeMode.dark);
    await Directory(path).delete();
    store.toggle();
    await store.settle();
    final restored = await AppearanceStore.load(path);
    expect(restored.mode, ThemeMode.light);
    store.dispose();
    restored.dispose();
  });
}
