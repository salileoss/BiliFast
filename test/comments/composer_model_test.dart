import 'dart:async';
import 'dart:typed_data';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/comments/comments_model.dart';
import 'package:bilifast/comments/composer_model.dart';
import 'package:bilifast/comments/emote_store.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:bilifast/video/page_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'comment_fixtures.dart';
import '../playback/fakes.dart';

Comment named(int rpid, String name, {int root = 0}) => Comment(
  rpid: rpid,
  oid: testAid,
  mid: 3000 + rpid,
  root: root,
  parent: root,
  member: CommentMember(mid: 3000 + rpid, name: name),
  message: '第$rpid条',
);

PickedPicture picture(String name) => PickedPicture(bytes: Uint8List.fromList([1, 2, 3]), name: name);

/// [FakePageApi] that notes the mid each @ search asks for.
class _MentionApi extends FakePageApi {
  final mids = <int>[];

  @override
  Future<List<MentionCandidate>> mentionCandidates({required int mid, String query = ''}) {
    mids.add(mid);
    return super.mentionCandidates(mid: mid, query: query);
  }
}

void main() {
  late RecentEmotes recent;
  late EmoteCatalog catalog;

  setUp(() {
    recent = RecentEmotes.memory(logger: Logger(session: 'test'));
    catalog = EmoteCatalog(logger: Logger(session: 'test'));
  });

  ComposerModel composer(CommentsRig rig, ReplyTarget target) => ComposerModel(
    comments: rig.model,
    target: target,
    recent: recent,
    catalog: catalog,
    logger: Logger(session: 'test'),
  );

  group('posting', () {
    test('switching accounts during picture upload cancels the following uploads and post', () async {
      const uploadPath = '/x/dynamic/feed/draw/upload_bfs';
      final http = CannedHttp()
        ..routes[uploadPath] = (200, '{"code":0,"data":{"image_url":"https://i0.hdslb.com/test.png","image_width":10,"image_height":10}}');
      final upload = http.gates[uploadPath] = Completer<void>();
      final client = BiliClient(transport: http, cookies: CookieJar({'SESSDATA': 'session-a', 'bili_jct': 'csrf-a'}));
      final drafts = CommentDrafts();
      final comments = CommentsModel(aid: testAid, upMid: 1, api: ClientPageApi(client), drafts: drafts,
          isLoggedIn: () => true, accountMid: () => 1, requestLogin: () {}, toast: (_) {});
      final model = ComposerModel(comments: comments, target: const ReplyToVideo(), recent: recent, catalog: catalog);
      addTearDown(model.dispose);
      addTearDown(comments.dispose);
      model.text = 'comment from A';
      model.addPictures([picture('one.png'), picture('two.png')]);
      final posted = model.post();
      await pumpEventQueue();
      expect(http.to(uploadPath), hasLength(1));
      client.invalidateSession();
      client.cookies.replaceAll({'SESSDATA': 'session-b', 'bili_jct': 'csrf-b'});
      client.invalidateSession();
      client.cookies.replaceAll({'SESSDATA': 'session-a', 'bili_jct': 'csrf-a'});
      upload.complete();
      expect(await posted, isFalse);
      expect(http.requests, hasLength(1), reason: 'no second upload or comment under a later session');
      expect(comments.comments, isEmpty);
      expect(model.text, 'comment from A');
    });

    test('a comment on the video sends no root or parent and goes to the top of the list', () async {
      final rig = CommentsRig();
      final model = composer(rig, const ReplyToVideo());
      expect(model.placeholder, '哎呦，不错哦，发条评论吧');
      expect(model.canPost, isFalse);

      model.text = '  第一条 & 1+1=2 😀\n';
      expect(model.canPost, isTrue);
      expect(await model.post(), isTrue);

      final sent = rig.api.posts.single;
      expect(sent.message, '第一条 & 1+1=2 😀');
      expect((sent.root, sent.parent, sent.syncToDynamic), (0, 0, false));
      expect(sent.mentions, isEmpty);
      expect(sent.pictures, isEmpty);
      expect(rig.model.comments.first.message, '第一条 & 1+1=2 😀', reason: 'the new comment goes to the top of the list');
      expect(rig.model.comments.first.member, FakePageApi.accountMember);
      expect(model.text, '', reason: 'the draft is cleared');
      expect(rig.drafts[ComposerModel.draftKey(const ReplyToVideo(), aid: testAid)].isEmpty, isTrue);
    });

    test('a comment on the video is prompted with the section\'s own words once the list has sent them', () async {
      final api = ScriptedApi()..pages = (_, _) => const CommentPage(comments: [], rootPrompt: '随便聊聊吧～');
      final rig = CommentsRig(api: api);
      await rig.model.loadMore();
      expect(composer(rig, const ReplyToVideo()).placeholder, '随便聊聊吧～');
      expect(composer(rig, ReplyToComment(named(10, '小红'))).placeholder, '回复 小红 :', reason: 'a reply keeps its own');
    });

    test('a reply to a comment uses it for root and parent, and can go to 动态', () async {
      final rig = CommentsRig();
      final model = composer(rig, ReplyToComment(named(10, '小红')));
      expect(model.placeholder, '回复 小红 :');

      model
        ..text = '好'
        ..syncToDynamic = true;
      expect(await model.post(), isTrue);
      final sent = rig.api.posts.single;
      expect((sent.message, sent.root, sent.parent, sent.syncToDynamic), ('好', 10, 10, true));
    });

    test('a reply inside a thread names who it answers and splits root and parent', () async {
      final rig = CommentsRig();
      final root = named(10, '小红');
      final reply = named(11, '小明', root: 10);
      rig.api
        ..commentList = [root.copyWith(replyCount: 1)]
        ..threadReplies = {
          10: [reply],
        };
      await rig.model.openThread(root);
      final model = composer(rig, ReplyInThread(root: root, reply: rig.model.thread!.replies.first));
      expect(model.placeholder, '回复 小明 :');

      model.text = '好';
      expect(await model.post(), isTrue);
      final sent = rig.api.posts.single;
      expect((sent.message, sent.root, sent.parent), ('回复 @小明 :好', 10, 11));
      expect(rig.model.thread!.replies.first.message, '回复 @小明 :好', reason: 'the reply goes to the top of the thread');
      expect(rig.model.thread!.root.replyCount, 2);
    });

    test('a failed post keeps the draft for this target alone', () async {
      final rig = CommentsRig();
      rig.api.failures['postComment'] = const BiliError.api(code: 12015, message: '评论发送过于频繁');
      final model = composer(rig, const ReplyToVideo());

      model.text = '留着我';
      expect(await model.post(), isFalse);
      expect(model.text, '留着我');
      expect(model.posting, isFalse);
      expect(model.canPost, isTrue);
      expect(rig.toasts, ['评论发送过于频繁']);
      expect(rig.model.comments, isEmpty);
      expect(rig.logins, 0);

      expect(composer(rig, const ReplyToVideo()).text, '留着我', reason: 'closing and reopening brings the draft back');
      expect(composer(rig, ReplyToComment(named(10, '小红'))).text, '');
    });

    test('whitespace, or pictures without text, can\'t be posted', () async {
      final rig = CommentsRig();
      final model = composer(rig, const ReplyToVideo())
        ..text = ' \n '
        ..addPictures([picture('a.jpg')]);
      expect(model.canPost, isFalse);
      expect(await model.post(), isFalse);
      expect(rig.api.calls, isEmpty);
    });

    test('closed while posting and opened again, the draft is back but 发布 waits for the first post', () async {
      final rig = CommentsRig();
      final hold = rig.api.holds['postComment'] = Completer<void>();
      final first = composer(rig, const ReplyToVideo())..text = '只发一次';
      final posting = first.post();
      expect(first.posting, isTrue);
      first.dispose();

      final second = composer(rig, const ReplyToVideo());
      var notified = 0;
      second.addListener(() => notified++);
      expect(second.text, '只发一次');
      expect(second.canPost, isFalse);
      expect(await second.post(), isFalse);

      hold.complete();
      expect(await posting, isTrue);
      expect(rig.api.posts, hasLength(1));
      expect(second.text, '', reason: 'the draft it showed was posted');
      expect(second.canPost, isFalse);
      expect(notified, greaterThan(0));
    });

    test('what is typed while the post is out stays as the draft', () async {
      final rig = CommentsRig();
      final hold = rig.api.holds['postComment'] = Completer<void>();
      final model = composer(rig, const ReplyToVideo())..text = '第一句';
      final posting = model.post();
      model.text = '第二句';
      hold.complete();
      expect(await posting, isTrue);
      expect(rig.api.posts.single.message, '第一句');
      expect(model.text, '第二句');
      expect(composer(rig, const ReplyToVideo()).text, '第二句');
    });

    test('drafts outlive a switch to another video of the page and back', () {
      final drafts = CommentDrafts();
      final first = CommentsRig(drafts: drafts);
      composer(first, const ReplyToVideo()).text = '视频草稿';
      composer(first, ReplyToComment(named(10, '小红'))).text = '回复草稿';

      final next = CommentsRig(drafts: drafts, aid: testAid + 1);
      expect(composer(next, const ReplyToVideo()).text, '', reason: 'another video\'s own comment starts empty');

      final back = CommentsRig(drafts: drafts);
      expect(composer(back, const ReplyToVideo()).text, '视频草稿');
      expect(composer(back, ReplyToComment(named(10, '小红'))).text, '回复草稿');
    });

    test('draft keys follow Swift\'s', () {
      expect(ComposerModel.draftKey(const ReplyToVideo(), aid: 5), 'video.5');
      expect(ComposerModel.draftKey(ReplyToComment(named(10, 'a')), aid: 5), 'comment.10');
      expect(ComposerModel.draftKey(ReplyInThread(root: named(10, 'a'), reply: named(11, 'b')), aid: 5), 'reply.11');
    });

    test('tells its listeners as the text changes and as the post starts and ends', () async {
      final rig = CommentsRig();
      final model = composer(rig, const ReplyToVideo());
      final seen = <bool>[];
      model.addListener(() => seen.add(model.posting));
      model.text = '好';
      await model.post();
      expect(seen.first, isFalse);
      expect(seen, contains(true));
      expect(seen.last, isFalse);
    });

    test('a post finishing after its composer was let go of changes nothing there', () async {
      final rig = CommentsRig();
      final hold = rig.api.holds['postComment'] = Completer<void>();
      final model = composer(rig, const ReplyToVideo())..text = '好';
      final posting = model.post();
      model.dispose();
      hold.complete();
      expect(await posting, isTrue);
      expect(rig.model.comments.single.message, '好');
    });
  });

  group('mentions', () {
    test('kept with the draft, and only names still in the text are sent', () async {
      final rig = CommentsRig();
      final model = composer(rig, const ReplyToVideo())
        ..mentioned(const MentionCandidate(mid: 3003, name: '小明'))
        ..mentioned(const MentionCandidate(mid: 3004, name: '小红'))
        ..text = '@小明 @小红 看这个';
      expect(model.mentions, {'小明': 3003, '小红': 3004});
      expect(composer(rig, const ReplyToVideo()).mentions, {'小明': 3003, '小红': 3004});

      model.text = '@小明 看这个';
      expect(model.mentions, {'小明': 3003});
      await model.post();
      expect(rig.api.posts.single.mentions, {'小明': 3003});
      expect(rig.model.comments.first.runs, contains(const RichRun.mention(name: '小明', mid: 3003)));
    });

    test('the search asks for the people the account follows', () async {
      final api = _MentionApi()
        ..followed = const [MentionCandidate(mid: 3003, name: '小明'), MentionCandidate(mid: 3004, name: '小红')];
      final rig = CommentsRig(api: api, mid: 77);
      final model = composer(rig, const ReplyToVideo());
      expect(await model.searchMentions('红'), const [MentionCandidate(mid: 3004, name: '小红')]);
      expect(await model.searchMentions(''), hasLength(2));
      rig.mid = null;
      await model.searchMentions('');
      expect(api.mids, [77, 77, 0]);
      expect(rig.callsTo('mentionCandidates'), [
        'mentionCandidates query=红',
        'mentionCandidates query=',
        'mentionCandidates query=',
      ]);
    });

    test('a failed search reaches the picker', () async {
      final rig = CommentsRig();
      rig.api.failures['mentionCandidates'] = const BiliError.http(500);
      await expectLater(composer(rig, const ReplyToVideo()).searchMentions(''), throwsA(isA<BiliHTTPError>()));
    });
  });

  group('pictures', () {
    test('uploaded in order when posting, then sent with the comment', () async {
      final rig = CommentsRig();
      final model = composer(rig, const ReplyToVideo())
        ..addPictures([picture('1.jpg'), picture('2.png')])
        ..addPictures([picture('3.gif')])
        ..text = '看图';
      expect(composer(rig, const ReplyToVideo()).pictures, hasLength(3), reason: 'kept with the draft');

      expect(await model.post(), isTrue);
      expect(rig.api.calls, [
        'uploadCommentPicture 1.jpg',
        'uploadCommentPicture 2.png',
        'uploadCommentPicture 3.gif',
        'postComment root=0 parent=0 message=看图',
      ]);
      expect([for (final sent in rig.api.posts.single.pictures) sent.url.split('/').last], ['1.jpg', '2.png', '3.gif']);
      expect(rig.model.comments.first.pictures, hasLength(3));
      expect(model.pictures, isEmpty);
    });

    test('a failed upload posts nothing and keeps everything', () async {
      final rig = CommentsRig();
      rig.api.failures['uploadCommentPicture'] = const BiliError.api(code: 1, message: '图片上传失败');
      final model = composer(rig, const ReplyToVideo())
        ..addPictures([picture('1.jpg')])
        ..text = '看图';
      expect(await model.post(), isFalse);
      expect(rig.api.posts, isEmpty);
      expect(model.pictures, hasLength(1));
      expect(model.text, '看图');
      expect(rig.toasts, ['图片上传失败']);
    });

    test('at most nine, with a toast for those that don\'t fit; ✕ takes one out', () {
      final rig = CommentsRig();
      final model = composer(rig, const ReplyToVideo())
        ..addPictures([for (var index = 0; index < 7; index++) picture('$index.jpg')]);
      model.addPictures([picture('a.jpg'), picture('b.jpg'), picture('c.jpg')]);
      expect(model.pictures, hasLength(ComposerModel.maxPictures));
      expect(model.pictures.last.name, 'b.jpg');
      expect(rig.toasts, ['最多选择9张图片']);

      model.removePicture(0);
      expect(model.pictures.first.name, '1.jpg');
      expect(model.pictures, hasLength(8));
      model.removePicture(20);
      expect(model.pictures, hasLength(8));
    });
  });

  group('emotes', () {
    test('a used emote goes to 最近使用, which each composer reads once when it opens', () {
      final rig = CommentsRig();
      const doge = Emote(token: '[doge]', url: 'https://example.invalid/doge.png', large: false);
      final model = composer(rig, const ReplyToVideo());
      model.usedEmote(doge);
      expect(model.recent, isEmpty, reason: 'the row stays put while emotes are tapped');
      expect(recent.list, [doge]);
      expect(composer(rig, const ReplyToVideo()).recent, [doge]);
    });

    test('the packages are asked for once for every composer', () async {
      final rig = CommentsRig();
      rig.api.emotes = const [EmotePackage(id: 1, name: '小黄脸', icon: '', isText: false, emotes: [])];
      final packages = await Future.wait([
        composer(rig, const ReplyToVideo()).emotePackages(),
        composer(rig, ReplyToComment(named(10, '小红'))).emotePackages(),
      ]);
      expect(packages.first.single.name, '小黄脸');
      expect(rig.callsTo('emotePackages'), hasLength(1));
    });
  });
}
