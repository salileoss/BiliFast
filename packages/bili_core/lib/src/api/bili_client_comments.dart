part of 'bili_client.dart';

extension BiliClientComments on BiliClient {
  /// `offset` is the previous page's `nextOffset`; null or empty asks for the first page.
  Future<CommentPage> comments({required int aid, required CommentSort sort, String? offset, int type = 1}) async {
    final generation = _requestGeneration;
    final cursor = offset ?? '';
    final query = {
      'oid': '$aid',
      'type': '$type',
      'mode': '${sort.rawValue}',
      'pagination_str': jsonEncode({'offset': cursor}),
    };
    CommentPage page;
    try {
      page = await get('/x/v2/reply/wbi/main', query: query, signed: true, decode: decodeCommentList);
    } on BiliError catch (error) {
      if (!_isRiskControl(error)) rethrow;
      _checkSession(generation);
      page = await get('/x/v2/reply/main', query: query, signed: false, decode: decodeCommentList);
    }
    return cursor.isEmpty ? page : page.copyWith(pinned: () => null);
  }

  Future<ThreadPage> thread({
    required int aid,
    required int root,
    required int page,
    CommentSort sort = CommentSort.time,
    int type = 1,
  }) {
    final query = {
      'oid': '$aid',
      'type': '$type',
      'root': '$root',
      'pn': '$page',
      'ps': '20',
      'sort': '${sort.threadSort}',
    };
    return get('/x/v2/reply/reply', query: query, signed: false, decode: decodeCommentThread);
  }

  /// `root` and `parent` stay 0 for a top-level comment; a reply to a reply sets `parent` to that reply.
  Future<Comment> postComment({
    required int aid,
    required String message,
    int root = 0,
    int parent = 0,
    bool syncToDynamic = false,
    Map<String, int> mentions = const {},
    List<UploadedPicture> pictures = const [],
    int type = 1,
  }) {
    final form = {'oid': '$aid', 'type': '$type', 'message': message};
    if (root != 0) form['root'] = '$root';
    if (parent != 0) form['parent'] = '$parent';
    if (syncToDynamic) form['sync_to_dynamic'] = '1';
    if (mentions.isNotEmpty) form['at_name_to_mid'] = jsonEncode(mentions);
    if (pictures.isNotEmpty) form['pictures'] = jsonEncode([for (final picture in pictures) picture.toJson()]);
    return post(
      '/x/v2/reply/add',
      form: form,
      referer: type == 1 ? 'https://www.bilibili.com/video/av$aid' : 'https://t.bilibili.com/',
      decode: decodePostedComment,
    );
  }

  Future<void> likeComment({required int aid, required int rpid, required bool on, int type = 1}) =>
      postVoid('/x/v2/reply/action', form: _reaction(aid, rpid, on, type));

  Future<void> hateComment({required int aid, required int rpid, required bool on, int type = 1}) =>
      postVoid('/x/v2/reply/hate', form: _reaction(aid, rpid, on, type));

  Future<void> deleteComment({required int aid, required int rpid, int type = 1}) =>
      postVoid('/x/v2/reply/del', form: {'oid': '$aid', 'type': '$type', 'rpid': '$rpid'});

  /// The people [mid] follows whose names match [query]; an empty query lists the most recently followed.
  Future<List<MentionCandidate>> followings({required int mid, String query = ''}) async {
    if (mid <= 0) throw const BiliError.api(code: -101, message: '账号未登录');
    final name = query.trim();
    final List<MentionCandidate>? found;
    if (name.isEmpty) {
      found = await _getIfPresent(
        '/x/relation/followings',
        query: {'vmid': '$mid', 'pn': '1', 'ps': '50', 'order': 'desc', 'order_type': ''},
        signed: false,
        decode: (json) => decodeMentionCandidates(json, logger: _logger),
      );
    } else {
      // The search is signed and carries the website's own fields, as the website sends it.
      found = await _getIfPresent(
        '/x/relation/followings/search',
        query: {
          'vmid': '$mid',
          'pn': '1',
          'ps': '20',
          'order': 'desc',
          'order_type': 'attention',
          'gaia_source': 'main_web',
          'name': name,
          'web_location': '333.999',
        },
        signed: true,
        decode: (json) => decodeMentionCandidates(json, logger: _logger),
      );
    }
    return found ?? const [];
  }

  /// Uploads one picture for a comment; [bytes] is the file as picked, [filename] its name with the extension.
  Future<UploadedPicture> uploadCommentPicture({required List<int> bytes, required String filename}) => _postFile(
    '/x/dynamic/feed/draw/upload_bfs',
    form: {'biz': 'new_dyn', 'category': 'daily'},
    file: (field: 'file_up', filename: filename, contentType: _imageType(filename), bytes: bytes),
    decode: UploadedPicture.fromJson,
  );

  Future<List<EmotePackage>> emotePackages() =>
      get('/x/emote/user/panel/web', query: {'business': 'reply'}, signed: false, decode: decodeEmotePanel);

  Map<String, String> _reaction(int aid, int rpid, bool on, int type) => {
    'oid': '$aid',
    'type': '$type',
    'rpid': '$rpid',
    'action': on ? '1' : '0',
  };

  static String _imageType(String filename) {
    final dot = filename.lastIndexOf('.');
    return switch (dot < 0 ? '' : filename.substring(dot + 1).toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'application/octet-stream',
    };
  }

  /// The signed route is the newer one; risk control sometimes refuses it while the plain route still answers.
  static bool _isRiskControl(BiliError error) => switch (error) {
    BiliAPIError(:final code) => code == -352 || code == -403,
    BiliHTTPError(:final status) => status == 412,
    _ => false,
  };
}
