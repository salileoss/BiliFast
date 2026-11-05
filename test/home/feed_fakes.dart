import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bili_core/api.dart';

import '../playback/fakes.dart';

const feedPath = '/x/web-interface/wbi/index/top/feed/rcmd';
const officialFeedPath = '/x/v2/feed/index';
const feedDislikePath = '/x/feed/dislike';
const feedDislikeCancelPath = '/x/feed/dislike/cancel';

/// A made-up app token; nothing here reaches the network.
final fakeAppToken = AppToken(
  accessToken: 'ACCESS',
  refreshToken: 'REFRESH',
  mid: 7,
  expiresAt: DateTime.utc(2027, 4, 1),
);

/// 92's 反馈 reasons, with made-up ids.
const officialFeedbacks = [
  (11, '色情低俗'),
  (12, '引战对立'),
  (13, '恐怖血腥'),
  (14, '恶心猎奇'),
  (15, '广告营销'),
  (16, '负能量'),
  (17, '搬运拼剪'),
  (18, '标题/封面党'),
  (19, '该内容已推荐过'),
];

/// One feed row as the web feed sends it.
Map<String, Object?> feedItem(String bvid, {String title = '视频', String? reason}) => {
  'goto': 'av',
  'id': bvid.hashCode.abs(),
  'bvid': bvid,
  'cid': 1,
  'title': '$title $bvid',
  'pic': 'https://i0.hdslb.com/bfs/archive/$bvid.jpg',
  'duration': 125,
  'owner': {'mid': 7, 'name': 'UP $bvid'},
  'stat': {'view': 12345, 'danmaku': 67},
  if (reason != null) 'rcmd_reason': {'content': reason},
};

/// One card as the official feed sends it, with ⋮'s 不感兴趣 data unless [reasons] is false. Its aid is made from
/// [bvid] the way [feedItem]'s is.
Map<String, Object?> officialItem(String bvid, {String title = '视频', bool reasons = true, String goto = 'av'}) {
  final aid = bvid.hashCode.abs();
  return {
    'card_goto': goto,
    'goto': goto,
    'param': '$aid',
    'bvid': bvid,
    'can_play': 1,
    'title': '$title $bvid',
    'cover': 'https://i0.hdslb.com/bfs/archive/$bvid.jpg',
    'args': {'up_id': 7, 'up_name': 'UP $bvid'},
    'player_args': {'aid': aid, 'cid': 1, 'duration': 125},
    'cover_left_text_1': '10.4万',
    'cover_left_text_2': '174',
    if (reasons)
      'three_point_v2': [
        {'type': 'watch_later', 'title': '添加至稍后再看'},
        {
          'type': 'feedback',
          'reasons': [
            for (final (id, name) in officialFeedbacks) {'id': id, 'name': name, 'toast': '将优化首页此类内容'},
          ],
        },
        {
          'type': 'dislike',
          'reasons': [
            {'id': 4, 'name': 'UP主:UP $bvid'},
            {'id': 1, 'name': '不感兴趣'},
          ],
        },
      ],
  };
}

/// The canned routes, and the feed's pages by `fresh_idx`: a page not set answers an empty list, and [failing]
/// pages answer HTTP 500. [gates] hold a page's answer until completed.
final class FeedHttp implements HTTPTransport {
  FeedHttp({bool loggedIn = true}) : canned = Canned.http(loggedIn: loggedIn);

  final CannedHttp canned;
  final pages = <int, List<Map<String, Object?>>>{};
  final failing = <int>{};
  final gates = <int, Completer<void>>{};
  final asked = <int>[];

  /// The official feed's pages by `idx`, the code it answers with, the `idx`es asked for, and gates holding a
  /// page's answer until completed.
  final officialPages = <int, List<Map<String, Object?>>>{};
  final officialGates = <int, Completer<void>>{};
  int officialCode = 0;
  final officialAsked = <int>[];

  /// The `mobi_app` each official page was asked as: the phone's `android`, the iPad's `android_i`.
  final officialApps = <String?>[];

  /// What 不感兴趣 and its 撤销 answer, each request's query, and a gate holding their answers.
  int dislikeCode = 0;
  final dislikes = <Map<String, String>>[];
  final cancels = <Map<String, String>>[];
  Completer<void>? dislikeGate;

  @override
  Future<HTTPResponse> send(HTTPRequest request) async {
    switch (request.url.path) {
      case officialFeedPath:
        final index = int.parse(request.url.queryParameters['idx']!);
        officialAsked.add(index);
        officialApps.add(request.url.queryParameters['mobi_app']);
        await officialGates[index]?.future;
        return _json(request, {
          'code': officialCode,
          'message': officialCode == 0 ? '0' : '账号未登录',
          if (officialCode == 0) 'data': {'items': officialPages[index] ?? const []},
        });
      case feedDislikePath || feedDislikeCancelPath:
        (request.url.path == feedDislikePath ? dislikes : cancels).add(request.url.queryParameters);
        await dislikeGate?.future;
        return _json(request, {'code': dislikeCode, 'message': dislikeCode == 0 ? '0' : '请求错误'});
    }
    if (request.url.path != feedPath) return canned.send(request);
    final index = int.parse(request.url.queryParameters['fresh_idx']!);
    asked.add(index);
    await gates[index]?.future;
    if (failing.contains(index)) {
      return HTTPResponse(status: 500, headers: {}, body: Uint8List(0), finalURL: request.url);
    }
    final body = jsonEncode({
      'code': 0,
      'data': {'item': pages[index] ?? const []},
    });
    return HTTPResponse(status: 200, headers: {}, body: utf8.encode(body), finalURL: request.url);
  }

  static HTTPResponse _json(HTTPRequest request, Object body) =>
      HTTPResponse(status: 200, headers: {}, body: utf8.encode(jsonEncode(body)), finalURL: request.url);
}

/// A big card (`large_cover_v9`) as the official feed's parser makes it, on the canned video's first part; [fullTitle]
/// replaces the made-up one.
FeedCard bigCard(
  String bvid, {
  int likes = 27999,
  bool showLikes = true,
  bool liked = false,
  String title = '大卡片',
  String? fullTitle,
  int published = 0,
}) =>
    FeedCard(
  aid: 80433022,
  bvid: bvid,
  cid: 137649199,
  title: fullTitle ?? '$title $bvid',
  cover: 'https://i0.hdslb.com/bfs/archive/$bvid.jpg',
  duration: 712,
  views: 549000,
  danmaku: 255,
  ownerName: 'UP $bvid',
  ownerMid: 7,
  reason: null,
  isVertical: false,
  viewsText: '54.9万',
  danmakuText: '255',
  big: FeedBig(likes: likes, showLikes: showLikes, liked: liked),
  published: published,
);

/// A small card, as the web feed's.
FeedCard smallCard(String bvid) => FeedCard(
  aid: bvid.hashCode.abs(),
  bvid: bvid,
  cid: 1,
  title: '视频 $bvid',
  cover: 'https://i0.hdslb.com/bfs/archive/$bvid.jpg',
  duration: 125,
  views: 12345,
  danmaku: 67,
  ownerName: 'UP $bvid',
  ownerMid: 7,
  reason: null,
  isVertical: false,
);

List<FeedCard> smalls(String prefix, int count) => [for (var i = 0; i < count; i++) smallCard('BV1$prefix$i')];
