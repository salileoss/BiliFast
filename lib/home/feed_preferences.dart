import 'package:bili_core/api.dart';

/// Local, account-scoped feed exposure and deliberate viewing. No data is sent to a server.
class FeedPreferences {
  FeedPreferences.memory({DateTime Function()? now});

  static Future<FeedPreferences> load(String? path, {DateTime Function()? now}) async =>
      FeedPreferences.memory(now: now);

  void recordSeen({required int? accountMid, required String bvid, required int ownerMid}) {}

  /// [seconds] is newly watched time, excluding seeks and replayed intervals.
  void recordWatch({
    required int? accountMid,
    required String bvid,
    required int ownerMid,
    required double seconds,
    bool completed = false,
  }) {}

  bool recentlySeen(String bvid, {required int? accountMid}) => false;

  int unseenCount(List<FeedCard> cards, {required int? accountMid}) =>
      cards.where((card) => !recentlySeen(card.bvid, accountMid: accountMid)).length;

  /// Prefer unseen videos, then spread creators while retaining the server's relevance order.
  List<FeedCard> select(List<FeedCard> cards, {required int? accountMid, required int limit}) =>
      cards.take(limit).toList();

  Future<void> flush() async {}

  void dispose() {}
}
