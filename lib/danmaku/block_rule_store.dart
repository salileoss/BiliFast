import 'package:bili_core/api.dart';
import 'package:bili_core/danmaku.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';

import '../video/page_api.dart';

/// The account's 弹幕屏蔽词 (BiliNative `BlockRuleStore.swift`), shared by every page: fetched from the server and
/// kept for 10 minutes, added to and deleted from there, so the official app sees the same list.
class BlockRuleStore extends ChangeNotifier {
  BlockRuleStore({required this._api, required this._isLoggedIn, DateTime Function()? now, Logger? logger})
    : _now = now ?? DateTime.now,
      _logger = logger ?? Logger.shared;

  static const cacheAge = Duration(minutes: 10);

  /// The answer when the account is missing or Bilibili no longer takes it; the views send it to the page's login
  /// rather than showing it.
  static const needLogin = '请先登录';
  static const emptyMessage = '请输入内容';
  static const invalidUserMessage = '请输入正确的用户 UID';
  static const duplicateMessage = '已经在屏蔽列表里了';
  static const invalidRegexMessage = '正则表达式有误';
  static const addFailed = '添加失败，请稍后重试';
  static const removeFailed = '删除失败，请稍后重试';
  static const syncFailed = '同步失败，请稍后重试';

  final PageApi _api;
  final bool Function() _isLoggedIn;
  final DateTime Function() _now;
  final Logger _logger;

  List<BlockRule> _rules = const [];
  bool _loading = false;
  DateTime? _lastSuccess;
  Future<String?>? _inflight;

  /// Bumped when the account goes away, so an answer already on its way for the old one is dropped.
  int _generation = 0;

  /// Bumped by every add and remove that lands, so a list fetched while one landed doesn't undo it.
  int _mutations = 0;

  List<BlockRule> get rules => _rules;

  bool get loading => _loading;

  /// Asks the server unless the list is younger than 10 minutes; [force] (同步) always asks. The message to show
  /// when it failed (同步 shows it; the page's own refresh ignores it), else null.
  Future<String?> refresh({bool force = false}) async {
    if (!_isLoggedIn()) {
      _clear();
      return needLogin;
    }
    if (_inflight case final inflight?) return inflight;
    final last = _lastSuccess;
    if (!force && last != null && _now().difference(last) < cacheAge) return null;
    final fetch = _fetch();
    _inflight = fetch;
    try {
      return await fetch;
    } finally {
      if (identical(_inflight, fetch)) _inflight = null;
    }
  }

  Future<String?> _fetch() async {
    final started = _generation;
    final mutations = _mutations;
    _setLoading(true);
    try {
      final fetched = await _api.danmakuBlockRules();
      // Left uncached, so the next refresh asks again.
      if (started != _generation || mutations != _mutations) return null;
      _rules = List.unmodifiable(fetched);
      _lastSuccess = _now();
      return null;
    } catch (error, stack) {
      if (started != _generation) return null;
      if (error is BiliError && error.needsLogin) {
        // The cookies exist but Bilibili no longer accepts them.
        _rules = const [];
        _lastSuccess = null;
      }
      return _failed('block rules failed', error, stack, syncFailed);
    } finally {
      if (started == _generation) _setLoading(false);
    }
  }

  /// The message to show, or null once it is added. A user rule's text is a uid, stored as the CRC-32 that rides on
  /// each danmaku, or that hash typed directly; a regex rule keeps the slashes it was typed with, as BiliNative sends it and the matcher expects.
  Future<String?> add(BlockRuleKind kind, String filter) async {
    if (!_isLoggedIn()) return needLogin;
    final text = filter.trim();
    if (text.isEmpty) return emptyMessage;
    final String stored;
    switch (kind) {
      case BlockRuleKind.user:
        final uid = int.tryParse(text);
        if (uid != null && uid > 0) {
          stored = MidHash.of(uid);
        } else if (text.length <= 8 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
          stored = text.toLowerCase();
        } else {
          return invalidUserMessage;
        }
      case BlockRuleKind.regex:
        var pattern = text;
        if (pattern.length >= 2 && pattern.startsWith('/') && pattern.endsWith('/')) {
          pattern = pattern.substring(1, pattern.length - 1);
        }
        // The feed compiles rules with Dart's RegExp; one it can't compile would block nothing here.
        if (pattern.isEmpty || !_compiles(pattern)) return invalidRegexMessage;
        stored = text;
      case BlockRuleKind.keyword:
        stored = text;
    }
    if (_rules.any((rule) => rule.kind == kind && rule.filter == stored)) return duplicateMessage;
    final generation = _generation;
    try {
      final rule = await _api.addBlockRule(kind, filter: stored);
      if (generation != _generation) return null;
      _mutations++;
      _rules = List.unmodifiable([
        for (final each in _rules)
          if (each.id != rule.id) each,
        rule,
      ]);
      notifyListeners();
      return null;
    } catch (error, stack) {
      return _failed('block rule add failed', error, stack, addFailed, kind);
    }
  }

  /// The message to show, or null once it is gone.
  Future<String?> remove(BlockRule rule) async {
    if (!_isLoggedIn()) return needLogin;
    final generation = _generation;
    try {
      await _api.deleteBlockRule(id: rule.id);
      if (generation != _generation) return null;
      _mutations++;
      _rules = List.unmodifiable([
        for (final each in _rules)
          if (each.id != rule.id) each,
      ]);
      notifyListeners();
      return null;
    } catch (error, stack) {
      return _failed('block rule delete failed', error, stack, removeFailed, rule.kind);
    }
  }

  /// Bilibili words its refusals for the user (too many rules, already there); those are shown word for word.
  String _failed(String what, Object error, StackTrace stack, String fallback, [BlockRuleKind? kind]) {
    _logger.warn(LogCategory.api, what, {
      'kind': ?kind?.name,
      'error': '$error',
      if (error is! BiliError) 'stack': '$stack',
    });
    if (error is BiliError && error.needsLogin) return needLogin;
    if (error case BiliAPIError(:final message) when message.isNotEmpty) return message;
    return fallback;
  }

  static bool _compiles(String pattern) {
    try {
      RegExp(pattern);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Invalidates old reads before the next account fetches its own synced rules.
  void resetAccount() {
    _inflight = null;
    _clear();
  }

  void _clear() {
    _generation++;
    _lastSuccess = null;
    if (_rules.isEmpty && !_loading) return;
    _rules = const [];
    _loading = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }
}
