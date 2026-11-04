import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:flutter/foundation.dart';

import '../video/page_api.dart';
import 'comments_model.dart';
import 'emote_store.dart';

/// A picture picked for a comment, uploaded only when the comment is posted.
@immutable
class PickedPicture {
  const PickedPicture({required this.bytes, required this.name});

  final Uint8List bytes;

  /// The file name with its extension, which the upload needs.
  final String name;
}

/// One opening of the composer (14, BiliNative `ComposerModel`): the text for one reply target, kept as a draft
/// while it is unsent, the emote panel switch, @ mentions, pictures and 转到动态, and posting.
class ComposerModel extends ChangeNotifier {
  ComposerModel({
    required this.comments,
    required this.target,
    RecentEmotes? recent,
    EmoteCatalog? catalog,
    Logger? logger,
  }) : _recentEmotes = recent ?? RecentEmotes.shared,
       _catalog = catalog ?? EmoteCatalog.shared,
       _logger = logger ?? Logger.shared {
    _load(comments.drafts[_key]);
    _recent = _recentEmotes.list;
    comments.drafts.addListener(_draftsChanged);
  }

  /// PiliPlus's limit for one comment.
  static const maxPictures = 9;

  final CommentsModel comments;
  final ReplyTarget target;
  final RecentEmotes _recentEmotes;
  final EmoteCatalog _catalog;
  final Logger _logger;

  String _text = '';
  Map<String, int> _mentions = const {};
  List<PickedPicture> _pictures = const [];
  bool _syncToDynamic = false;
  bool _showingEmotes = false;
  bool _posting = false;
  late final List<Emote> _recent;
  bool _disposed = false;

  /// Drafts outlive a switch to another video of the page, so a comment on the video itself names the video.
  static String draftKey(ReplyTarget target, {required int aid}) => switch (target) {
    ReplyToVideo() => 'video.$aid',
    ReplyToComment(:final comment) => 'comment.${comment.rpid}',
    ReplyInThread(:final reply) => 'reply.${reply.rpid}',
  };

  String get _key => draftKey(target, aid: comments.aid);

  CommentDraft get _draft => CommentDraft(text: _text, mentions: _mentions, pictures: _pictures);

  void _load(CommentDraft draft) {
    _text = draft.text;
    _mentions = draft.mentions;
    _pictures = draft.pictures;
  }

  void _saveDraft() => comments.drafts.save(_key, _draft);

  String get text => _text;

  /// Saves the draft as it goes.
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _saveDraft();
    _notify();
  }

  bool get syncToDynamic => _syncToDynamic;
  set syncToDynamic(bool value) {
    _syncToDynamic = value;
    _notify();
  }

  bool get showingEmotes => _showingEmotes;
  set showingEmotes(bool value) {
    _showingEmotes = value;
    _notify();
  }

  bool get posting => _posting;

  /// Text is needed, as in PiliPlus: pictures alone don't make a comment.
  bool get canPost => _trimmed.isNotEmpty && !_posting && !comments.drafts.isPosting(_key);

  /// The comment section's prompt, as the bar shows it, or "回复 name :" for a reply.
  String get placeholder => switch (target) {
    ReplyToVideo() => comments.rootPrompt ?? CommentsModel.defaultPrompt,
    ReplyToComment(:final comment) => '回复 ${comment.member.name} :',
    ReplyInThread(:final reply) => '回复 ${reply.member.name} :',
  };

  /// 最近使用, read once when the composer opens so the row stays put while emotes are tapped.
  List<Emote> get recent => _recent;

  /// Records [emote] in 最近使用; the composer puts its token into the text at the cursor.
  void usedEmote(Emote emote) => _recentEmotes.record(emote);

  Future<List<EmotePackage>> emotePackages() => _catalog.load(comments.api);

  /// The @names in the text so far, with their mids; only names still in the text are sent.
  Map<String, int> get mentions => _mentionsIn(_text);

  Map<String, int> _mentionsIn(String text) => {
    for (final MapEntry(key: name, value: mid) in _mentions.entries)
      if (text.contains('@$name')) name: mid,
  };

  /// Records [who]; the composer puts "@name " into the text at the cursor.
  void mentioned(MentionCandidate who) {
    _mentions = {..._mentions, who.name: who.mid};
    _saveDraft();
    _notify();
  }

  /// Throws when the list can't be had; the picker says so.
  Future<List<MentionCandidate>> searchMentions(String query) async {
    try {
      return await comments.api.mentionCandidates(mid: comments.accountMid ?? 0, query: query);
    } catch (error) {
      _logger.warn(LogCategory.api, 'mention candidates failed', {'error': '$error'});
      rethrow;
    }
  }

  List<PickedPicture> get pictures => _pictures;

  /// Takes as many as there is room for, and says so when some don't fit.
  void addPictures(List<PickedPicture> picked) {
    if (picked.isEmpty) return;
    final room = maxPictures - _pictures.length;
    if (picked.length > room) comments.say('最多选择$maxPictures张图片');
    if (room <= 0) return;
    _pictures = [..._pictures, ...picked.take(room)];
    _saveDraft();
    _notify();
  }

  void removePicture(int index) {
    if (index < 0 || index >= _pictures.length) return;
    _pictures = [..._pictures]..removeAt(index);
    _saveDraft();
    _notify();
  }

  /// True once the comment is posted and shown; on failure the text stays and the reason is toasted.
  Future<bool> post() async {
    if (!canPost) return false;
    final key = _key;
    final sent = _draft;
    final (message, root, parent) = _postFields();
    final mentions = _mentionsIn(_trimmed);
    final syncToDynamic = _syncToDynamic;
    final drafts = comments.drafts;
    final api = comments.api;
    final generation = api is ClientPageApi ? api.sessionGeneration : null;
    _posting = true;
    drafts.setPosting(key, true);
    _notify();
    try {
      Future<Comment> send() async {
        final uploaded = <UploadedPicture>[];
        for (final picture in sent.pictures) {
          uploaded.add(await api.uploadCommentPicture(bytes: picture.bytes, filename: picture.name));
        }
        return api.postComment(
          aid: comments.aid,
          type: comments.type,
          message: message,
          root: root,
          parent: parent,
          syncToDynamic: syncToDynamic,
          mentions: mentions,
          pictures: uploaded,
        );
      }
      final posted = await (api is ClientPageApi ? api.runInSession(generation!, send) : send());
      comments.inserted(posted);
      // What was typed while it was out stays as the draft.
      if (_draft == sent) _load(CommentDraft.empty);
      if (drafts[key] == sent) drafts.clear(key);
      return true;
    } catch (error, stack) {
      comments.fail(error, stack);
      return false;
    } finally {
      _posting = false;
      drafts.setPosting(key, false);
      _notify();
    }
  }

  String get _trimmed => _text.trim();

  (String message, int root, int parent) _postFields() => switch (target) {
    ReplyToVideo() => (_trimmed, 0, 0),
    ReplyToComment(:final comment) => (_trimmed, comment.rpid, comment.rpid),
    // The server links the reply to its parent, but the thread only shows who it answers through this prefix.
    ReplyInThread(:final root, :final reply) => ('回复 @${reply.member.name} :$_trimmed', root.rpid, reply.rpid),
  };

  /// Another composer for the same target posted (the draft is gone) or finished posting (发布 may be pressed again).
  void _draftsChanged() {
    final saved = comments.drafts[_key];
    if (!_posting && saved != _draft) _load(saved);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    comments.drafts.removeListener(_draftsChanged);
    super.dispose();
  }
}
