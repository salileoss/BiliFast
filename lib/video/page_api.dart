import 'package:bili_core/api.dart';
import 'package:bili_core/danmaku.dart';

/// The calls the page body makes besides playback: its side loads and the actions. The app asks Bilibili
/// ([ClientPageApi]); tests and `--fake-account` runs on the PC answer from memory (`FakePageApi`).
abstract interface class PageApi {
  Future<VideoRelation> relation({required int aid, required String bvid});

  Future<UploaderCard> uploaderCard({required int mid});

  Future<List<VideoTag>> tags({required String bvid, required int cid});

  /// N人正在看's N as the server words it ("53", "1000+").
  Future<String> onlineCount({required int aid, required String bvid, required int cid});

  Future<void> like({required int aid, required String bvid, required bool on});

  Future<TripleResult> triple({required int aid, required String bvid});

  /// The official API's, so it needs the app token; `on: false` takes the 不喜欢 back.
  Future<void> dislike({required int aid, required bool on});

  Future<void> coin({required int aid, required String bvid, required int multiply, required bool alsoLike});

  Future<double> coinBalance();

  Future<List<FavFolder>> favouriteFolders({required int mid, required int aid});

  Future<void> updateFavourites({required int aid, required List<int> add, required List<int> remove});

  Future<FavFolder> createFolder({required String title, required bool isPrivate});

  Future<void> countShare({required int aid});

  Future<void> follow({required int mid, required bool on});

  Future<void> favSeason({required int seasonId, required bool on});

  Future<void> addToWatchLater({required int aid});

  /// 评论's pages: [offset] is the last page's `nextOffset`, null for the first. [aid] is the comment area's oid and
  /// [type] its kind: 1 for a video, a 动态's own (11, 12, 17) for a post.
  Future<CommentPage> comments({required int aid, required CommentSort sort, String? offset, int type = 1});

  Future<ThreadPage> thread({
    required int aid,
    required int root,
    required int page,
    required CommentSort sort,
    int type = 1,
  });

  /// [root] and [parent] stay 0 for a comment on the video; [mentions] maps each @name in [message] to its mid.
  Future<Comment> postComment({
    required int aid,
    required String message,
    int root = 0,
    int parent = 0,
    bool syncToDynamic = false,
    Map<String, int> mentions = const {},
    List<UploadedPicture> pictures = const [],
    int type = 1,
  });

  Future<void> likeComment({required int aid, required int rpid, required bool on, int type = 1});

  Future<void> hateComment({required int aid, required int rpid, required bool on, int type = 1});

  Future<void> deleteComment({required int aid, required int rpid, int type = 1});

  Future<List<EmotePackage>> emotePackages();

  /// The composer's @ picker: people [mid] follows, matching [query] when it isn't empty.
  Future<List<MentionCandidate>> mentionCandidates({required int mid, String query = ''});

  Future<UploadedPicture> uploadCommentPicture({required List<int> bytes, required String filename});

  /// The account's 弹幕屏蔽词.
  Future<List<BlockRule>> danmakuBlockRules();

  Future<BlockRule> addBlockRule(BlockRuleKind kind, {required String filter});

  Future<void> deleteBlockRule({required int id});

  /// The new danmaku's id, or 0 when the server accepted it without one.
  Future<int> postDanmaku(DanmakuDraft draft);

  Future<void> likeDanmaku({required int cid, required int dmid, required bool on});

  Future<Map<int, DanmakuLikeStat>> danmakuLikes({required int cid, required List<int> dmids});

  /// 历史记录, newest first; [after] continues from the previous page's cursor.
  Future<HistoryPage> history({HistoryCursor? after});

  /// Removes [item] from 历史记录.
  Future<void> deleteHistory(HistoryItem item);
}

class ClientPageApi implements PageApi {
  ClientPageApi(this._client);

  final BiliClient _client;

  int get sessionGeneration => _client.sessionGeneration;

  /// Uploads and the comment they accompany belong to one initiating login.
  Future<T> runInSession<T>(int generation, Future<T> Function() action) => _client.runInSession(generation, action);

  @override
  Future<VideoRelation> relation({required int aid, required String bvid}) => _client.relation(aid: aid, bvid: bvid);

  @override
  Future<UploaderCard> uploaderCard({required int mid}) => _client.uploaderCard(mid: mid);

  @override
  Future<List<VideoTag>> tags({required String bvid, required int cid}) => _client.tags(bvid: bvid, cid: cid);

  @override
  Future<String> onlineCount({required int aid, required String bvid, required int cid}) =>
      _client.onlineCount(aid: aid, bvid: bvid, cid: cid);

  @override
  Future<void> like({required int aid, required String bvid, required bool on}) => _officialFirst(
    () => _client.officialLike(aid: aid, on: on),
    () => _client.like(aid: aid, bvid: bvid, on: on),
  );

  @override
  Future<TripleResult> triple({required int aid, required String bvid}) => _client.triple(aid: aid, bvid: bvid);

  @override
  Future<void> dislike({required int aid, required bool on}) => _client.officialDislike(aid: aid, on: on);

  @override
  Future<void> coin({required int aid, required String bvid, required int multiply, required bool alsoLike}) =>
      _officialFirst(
        () => _client.officialCoin(aid: aid, multiply: multiply, alsoLike: alsoLike),
        () => _client.coin(aid: aid, bvid: bvid, multiply: multiply, alsoLike: alsoLike),
      );

  /// The official call while the app token is held, as PiliPlus does, else the web's. A token Bilibili turns down
  /// (the client's -101 and -2) has just been reported and is being dropped, and the call did nothing, so it goes out
  /// once on the web instead: the web login is a different one, and a -101 there still asks for it.
  Future<void> _officialFirst(Future<void> Function() official, Future<void> Function() web) =>
      runInSession(sessionGeneration, () async {
    if (_client.appToken == null) return web();
    try {
      return await official();
    } on BiliAPIError catch (error) {
      if (!_tokenRefused.contains(error.code)) rethrow;
      return web();
    }
  });

  static const _tokenRefused = {-101, -2};

  @override
  Future<double> coinBalance() => _client.coinBalance();

  @override
  Future<List<FavFolder>> favouriteFolders({required int mid, required int aid}) =>
      _client.favouriteFolders(mid: mid, aid: aid);

  @override
  Future<void> updateFavourites({required int aid, required List<int> add, required List<int> remove}) =>
      _client.updateFavourites(aid: aid, add: add, remove: remove);

  @override
  Future<FavFolder> createFolder({required String title, required bool isPrivate}) =>
      _client.createFolder(title: title, isPrivate: isPrivate);

  @override
  Future<void> countShare({required int aid}) => _client.countShare(aid: aid);

  @override
  Future<void> follow({required int mid, required bool on}) => _client.follow(mid: mid, on: on);

  @override
  Future<void> favSeason({required int seasonId, required bool on}) => _client.favSeason(seasonId: seasonId, on: on);

  @override
  Future<void> addToWatchLater({required int aid}) => _client.addToWatchLater(aid: aid);

  @override
  Future<CommentPage> comments({required int aid, required CommentSort sort, String? offset, int type = 1}) =>
      _client.comments(aid: aid, sort: sort, offset: offset, type: type);

  @override
  Future<ThreadPage> thread({
    required int aid,
    required int root,
    required int page,
    required CommentSort sort,
    int type = 1,
  }) => _client.thread(aid: aid, root: root, page: page, sort: sort, type: type);

  @override
  Future<Comment> postComment({
    required int aid,
    required String message,
    int root = 0,
    int parent = 0,
    bool syncToDynamic = false,
    Map<String, int> mentions = const {},
    List<UploadedPicture> pictures = const [],
    int type = 1,
  }) => _client.postComment(
    aid: aid,
    type: type,
    message: message,
    root: root,
    parent: parent,
    syncToDynamic: syncToDynamic,
    mentions: mentions,
    pictures: pictures,
  );

  @override
  Future<void> likeComment({required int aid, required int rpid, required bool on, int type = 1}) =>
      _client.likeComment(aid: aid, rpid: rpid, on: on, type: type);

  @override
  Future<void> hateComment({required int aid, required int rpid, required bool on, int type = 1}) =>
      _client.hateComment(aid: aid, rpid: rpid, on: on, type: type);

  @override
  Future<void> deleteComment({required int aid, required int rpid, int type = 1}) =>
      _client.deleteComment(aid: aid, rpid: rpid, type: type);

  @override
  Future<List<EmotePackage>> emotePackages() => _client.emotePackages();

  @override
  Future<List<MentionCandidate>> mentionCandidates({required int mid, String query = ''}) =>
      _client.followings(mid: mid, query: query);

  @override
  Future<UploadedPicture> uploadCommentPicture({required List<int> bytes, required String filename}) =>
      _client.uploadCommentPicture(bytes: bytes, filename: filename);

  @override
  Future<List<BlockRule>> danmakuBlockRules() => _client.danmakuBlockRules();

  @override
  Future<BlockRule> addBlockRule(BlockRuleKind kind, {required String filter}) =>
      _client.addBlockRule(kind, filter: filter);

  @override
  Future<void> deleteBlockRule({required int id}) => _client.deleteBlockRule(id: id);

  @override
  Future<int> postDanmaku(DanmakuDraft draft) => _client.postDanmaku(draft);

  @override
  Future<void> likeDanmaku({required int cid, required int dmid, required bool on}) =>
      _client.likeDanmaku(cid: cid, dmid: dmid, on: on);

  @override
  Future<Map<int, DanmakuLikeStat>> danmakuLikes({required int cid, required List<int> dmids}) =>
      _client.danmakuLikes(cid: cid, dmids: dmids);

  @override
  Future<HistoryPage> history({HistoryCursor? after}) => _client.history(after: after);

  @override
  Future<void> deleteHistory(HistoryItem item) => _client.deleteHistory(aid: item.aid);
}
