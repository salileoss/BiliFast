import 'package:bili_core/api.dart' hide RichText;
import 'package:bilifast/comments/rich_text_view.dart';
import 'package:bilifast/shared/remote_image.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/space_host.dart';

const _style = TextStyle(fontSize: 15, height: 25 / 15, color: BiliColors.text);
const _emoteUrl = 'https://i0.hdslb.com/bfs/emote/a.png';

final class Rig {
  final seeks = <int>[];
  final videos = <String>[];
  final links = <Uri>[];
  bool linkOpens = true;
  Object? linkThrows;

  Future<bool> openLink(Uri link) async {
    links.add(link);
    if (linkThrows case final error?) throw error;
    return linkOpens;
  }

  Future<void> mount(
    WidgetTester tester,
    List<RichRun> runs, {
    bool seeks = true,
    bool videos = true,
    InlineSpan? leading,
    int? maxLines,
    bool marksReplyTarget = true,
    bool linksOpen = true,
    TextStyle style = _style,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(440, 956)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay.wrap(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 372,
                child: CommentText(
                  runs: runs,
                  style: style,
                  leading: leading,
                  maxLines: maxLines,
                  onSeek: seeks ? this.seeks.add : null,
                  onOpenVideo: videos ? this.videos.add : null,
                  openLink: openLink,
                  marksReplyTarget: marksReplyTarget,
                  linksOpen: linksOpen,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// In the app, where a mention can open the space.
  Future<void> mountInApp(WidgetTester tester, List<RichRun> runs) => pumpSpaceHost(
    tester,
    SizedBox(
      width: 372,
      child: CommentText(runs: runs, style: _style, openLink: openLink),
    ),
  );
}

Finder get _paragraph => find.descendant(of: find.byType(CommentText), matching: find.byType(RichText));

Text _text(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(CommentText), matching: find.byType(Text)));

TextSpan _root(WidgetTester tester) => _text(tester).textSpan! as TextSpan;

TextSpan _span(WidgetTester tester, String text) =>
    _root(tester).children!.whereType<TextSpan>().singleWhere((span) => span.text == text);

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tapOnText(find.textRange.ofSubstring(text));
  await tester.pump();
}

/// The toast fades in, waits two seconds and fades out, each step starting a frame after the last ends.
Future<void> _expireToast(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('cached rich-text links follow an inherited appearance change', (tester) async {
    const comment = CommentText(
      runs: [RichRun.link(title: 'link', url: 'https://example.com')],
      style: _style,
    );
    Widget host(Brightness brightness) => Theme(
      data: biliTheme(brightness),
      child: const Directionality(textDirection: TextDirection.ltr, child: comment),
    );
    await tester.pumpWidget(host(Brightness.light));
    final element = tester.element(find.byType(CommentText));
    expect(_span(tester, 'link').style!.color, BiliColors.link);
    await tester.pumpWidget(host(Brightness.dark));
    expect(tester.element(find.byType(CommentText)), same(element));
    expect(_span(tester, 'link').style!.color, const Color(0xFF69B7E5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain text as it is, the leading span first, and an ellipsis once maxLines runs out', (tester) async {
    final rig = Rig();
    const leading = TextSpan(
      text: 'HYSSNH: ',
      style: TextStyle(color: BiliColors.secondaryText),
    );
    await rig.mount(tester, const [RichRun.text('但拳头关于这个规定是如果不符合回合中立即进行回溯的情况')], leading: leading);
    expect(_root(tester).children!.first, same(leading));
    expect(find.text('HYSSNH: 但拳头关于这个规定是如果不符合回合中立即进行回溯的情况', findRichText: true), findsOneWidget);
    expect(_root(tester).style, isNull);
    expect(_text(tester).style, _style);
    expect(_text(tester).overflow, isNull);

    await rig.mount(tester, [RichRun.text('回溯' * 60)], maxLines: 2);
    final paragraph = tester.renderObject<RenderParagraph>(_paragraph);
    expect(paragraph.maxLines, 2);
    expect(paragraph.overflow, TextOverflow.ellipsis);
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(tester.getSize(_paragraph).height, 50);
  });

  group('emotes', () {
    testWidgets('inline at 4/3 of the text size, twice that for a large one, the token as text without a url', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final rig = Rig();
      await rig.mount(tester, const [
        RichRun.text('也不能再重打了'),
        RichRun.emote(token: '[无语]', url: _emoteUrl, size: 1),
        RichRun.emote(token: '[热词系列_大]', url: _emoteUrl, size: 2),
        RichRun.emote(token: '[空]', url: '', size: 1),
      ]);
      final images = tester.widgetList<RemoteImage>(find.byType(RemoteImage)).toList();
      expect(images, hasLength(2));
      expect(images.map((image) => image.fit), everyElement(BoxFit.contain));
      expect(images.map((image) => image.placeholder), everyElement(isNotNull));
      expect(tester.getSize(find.byType(RemoteImage).first).width, moreOrLessEquals(20));
      expect(tester.getSize(find.byType(RemoteImage).last).width, moreOrLessEquals(40));
      expect(images.first.size!.width, moreOrLessEquals(20));
      expect(find.textContaining('[空]', findRichText: true), findsOneWidget);
      expect(find.textContaining('[无语]', findRichText: true), findsNothing);
      expect(find.bySemanticsLabel('[无语]'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('two emotes in a row stand 4 pt apart (24 pt between their lefts beside 15 pt text); one after text '
        'gets no gap', (tester) async {
      final rig = Rig();
      await rig.mount(tester, const [
        RichRun.text('吗？'),
        RichRun.emote(token: '[笑哭]', url: _emoteUrl, size: 1),
        RichRun.emote(token: '[笑哭]', url: _emoteUrl, size: 1),
      ]);
      final emotes = find.byType(RemoteImage);
      final first = tester.getRect(emotes.first);
      final second = tester.getRect(emotes.last);
      expect(first.left - tester.getTopLeft(_paragraph).dx, moreOrLessEquals(30));
      expect(second.left - first.left, moreOrLessEquals(24));
      expect(second.width, moreOrLessEquals(20));
    });

    testWidgets('an emote is centred on the Chinese glyphs beside it, and its line grows 2 pt below the text', (
      tester,
    ) async {
      final rig = Rig();
      await rig.mount(tester, const [RichRun.text('重打了')]);
      final plainHeight = tester.getSize(_paragraph).height;

      await rig.mount(tester, const [RichRun.text('重打了'), RichRun.emote(token: '[无语]', url: _emoteUrl, size: 1)]);
      expect(tester.getSize(_paragraph).height, moreOrLessEquals(plainHeight + CommentTextTheme.emoteLineGrowth));
      // The line grows below its text only, so its baseline is the text's.
      final painter = TextPainter(
        text: const TextSpan(text: '重打了', style: _style),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);
      final baseline =
          tester.getTopLeft(_paragraph).dy + painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final emote = tester.getRect(find.byType(RemoteImage));
      expect(emote.center.dy, moreOrLessEquals(baseline - 15 * CommentTextTheme.emoteRise));

      // A 40 pt emote reaches 25.25 above the baseline and 14.75 below it: the line grows to hold exactly it.
      await rig.mount(tester, const [RichRun.emote(token: '[大]', url: _emoteUrl, size: 2), RichRun.text('大')]);
      expect(tester.getRect(find.byType(RemoteImage)).top, moreOrLessEquals(tester.getTopLeft(_paragraph).dy));
      expect(tester.getSize(_paragraph).height, moreOrLessEquals(40));
    });

    testWidgets('only the line holding the emote grows; plain lines keep their height', (tester) async {
      final rig = Rig();
      final line = '回溯' * 10;
      // The first character of each line: 0, 21 and, after the emote's placeholder and the line break, 43.
      List<double> lineTops(List<int> starts) => [
        for (final start in starts)
          tester
              .renderObject<RenderParagraph>(_paragraph)
              .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + 1))
              .single
              .top,
      ];
      await rig.mount(tester, [RichRun.text('$line\n$line\n$line')]);
      final plain = tester.getSize(_paragraph).height;
      expect(plain, moreOrLessEquals(75));
      final plainTops = lineTops([0, 21, 42]);

      await rig.mount(tester, [
        RichRun.text('$line\n$line'),
        const RichRun.emote(token: '[无语]', url: _emoteUrl, size: 1),
        RichRun.text('\n$line'),
      ]);
      expect(tester.getSize(_paragraph).height, moreOrLessEquals(plain + CommentTextTheme.emoteLineGrowth));
      final tops = lineTops([0, 21, 43]);
      expect(tops[0], moreOrLessEquals(plainTops[0]));
      expect(tops[1], moreOrLessEquals(plainTops[1]));
      expect(tops[2], moreOrLessEquals(plainTops[2] + CommentTextTheme.emoteLineGrowth));

      await rig.mount(tester, [RichRun.text(line), const RichRun.emote(token: '[空]', url: '', size: 1)]);
      expect(tester.getSize(_paragraph).height, moreOrLessEquals(25));
    });
  });

  group('votes and notes', () {
    testWidgets('a vote is a 投票 link to its page; a 笔记 link reads [笔记] and opens the note', (tester) async {
      final rig = Rig();
      await rig.mount(tester, const [
        RichRun.link(title: '笔记标题', url: 'https://www.bilibili.com/h5/note-app/view?cvid=1234', note: true),
        RichRun.text('选一个'),
        RichRun.link(title: '投票: 选哪个', url: 'https://t.bilibili.com/vote/h5/index?vote_id=4321#/result'),
      ]);
      expect(find.text('[笔记] 选一个投票: 选哪个', findRichText: true), findsOneWidget);
      expect(_span(tester, '[笔记] ').style?.color, CommentTextTheme.link);
      expect(_span(tester, '投票: 选哪个').style?.color, CommentTextTheme.link);

      await _tapText(tester, '[笔记]');
      await _tapText(tester, '投票');
      expect(rig.links, [
        Uri.parse('https://www.bilibili.com/h5/note-app/view?cvid=1234'),
        Uri.parse('https://t.bilibili.com/vote/h5/index?vote_id=4321#/result'),
      ]);
    });
  });

  group('mentions', () {
    testWidgets('@name in the link blue opens the space in the app, not the browser', (tester) async {
      final rig = Rig();
      await rig.mountInApp(tester, const [RichRun.text('看 '), RichRun.mention(name: '小明', mid: 42)]);
      expect(_span(tester, '@小明').style?.color, CommentTextTheme.link);
      expect(_span(tester, '看 ').style, isNull);

      await _tapText(tester, '@小明');
      await pumpRoute(tester);
      final space = openSpaces(tester).single;
      expect(space.mid, 42);
      expect(space.name, '小明');
      expect(space.face, isNull);
      expect(rig.links, isEmpty);
      expect(rig.seeks, isEmpty);
      expect(rig.videos, isEmpty);
    });

    testWidgets('a mention with no mid stays blue and opens nothing', (tester) async {
      final rig = Rig();
      await rig.mountInApp(tester, const [RichRun.mention(name: '@某人', mid: 0)]);
      expect(_span(tester, '@某人').recognizer, isNull);
      await _tapText(tester, '@某人');
      await pumpRoute(tester);
      expect(openSpaces(tester), isEmpty);
      expect(rig.links, isEmpty);
    });

    testWidgets('a space address opens the space in the app; other addresses still go to the browser', (tester) async {
      final rig = Rig();
      await rig.mountInApp(tester, const [
        RichRun.link(title: '我的空间', url: 'https://space.bilibili.com/77/video'),
        RichRun.text(' 和 '),
        RichRun.link(title: '投票', url: 'https://t.bilibili.com/vote/h5/index?vote_id=1'),
      ]);
      await _tapText(tester, '我的空间');
      await pumpRoute(tester);
      expect(openSpaces(tester).single.mid, 77);
      expect(rig.links, isEmpty);

      await closeSpace(tester);
      await _tapText(tester, '投票');
      expect(rig.links, [Uri.parse('https://t.bilibili.com/vote/h5/index?vote_id=1')]);
      expect(openSpaces(tester), isEmpty);
    });

    test('spaceMid reads a space address only', () {
      expect(spaceMid(Uri.parse('https://space.bilibili.com/42')), 42);
      expect(spaceMid(Uri.parse('https://space.bilibili.com/42/dynamic?spm=1')), 42);
      expect(spaceMid(Uri.parse('https://m.bilibili.com/space/43')), 43);
      expect(spaceMid(Uri.parse('https://space.bilibili.com/')), isNull);
      expect(spaceMid(Uri.parse('https://space.bilibili.com/abc')), isNull);
      expect(spaceMid(Uri.parse('https://www.bilibili.com/space/42')), isNull);
      expect(spaceMid(Uri.parse('https://m.bilibili.com/video/BV1xx411c7mD')), isNull);
    });

    testWidgets('in a reply preview the blue runs open nothing, so the tap reaches the box', (tester) async {
      final rig = Rig();
      await rig.mount(tester, const [
        RichRun.mention(name: '小明', mid: 42),
        RichRun.link(title: '投票', url: 'https://t.bilibili.com/vote/h5/index?vote_id=1'),
        RichRun.link(title: '我的空间', url: 'https://space.bilibili.com/77'),
        RichRun.timestamp(label: '1:02', seconds: 62),
      ], linksOpen: false);
      for (final text in ['@小明', '投票', '我的空间', '1:02']) {
        expect(_span(tester, text).style?.color, CommentTextTheme.link, reason: text);
        expect(_span(tester, text).recognizer, isNull, reason: text);
      }
    });

    testWidgets('a reply\'s lead reads 回复 name: as on font-check 04: the name grey, no @, no link', (tester) async {
      final rig = Rig();
      for (final runs in const [
        [RichRun.text('回复 @小红 :说得对'), RichRun.timestamp(label: '1:02', seconds: 62)],
        [
          RichRun.text('回复 '),
          RichRun.mention(name: '小红', mid: 7),
          RichRun.text(' :说得对'),
          RichRun.timestamp(label: '1:02', seconds: 62),
        ],
      ]) {
        await rig.mount(tester, runs);
        expect(_root(tester).children!.whereType<TextSpan>().map((span) => span.text), [
          '回复 ',
          '小红',
          ': ',
          '说得对',
          '1:02',
        ]);
        final name = _span(tester, '小红');
        expect(name.style?.color, CommentTextTheme.replyTarget);
        expect(name.recognizer, isNull);
        expect(_span(tester, '回复 ').style, isNull);
        expect(_span(tester, ': ').style, isNull);
        await _tapText(tester, '小红');
        expect(rig.links, isEmpty);
        expect(_span(tester, '1:02').style?.color, CommentTextTheme.link, reason: 'the rest keeps its links');
      }

      await rig.mount(tester, const [RichRun.text('回复 @小红 :说得对')], marksReplyTarget: false);
      expect(_root(tester).children!.whereType<TextSpan>().map((span) => span.text), ['回复 @小红 :说得对']);
    });

    testWidgets('an emote straight after the colon follows the lead with no gap', (tester) async {
      final rig = Rig();
      await rig.mount(tester, const [RichRun.text('回复 @小红 :'), RichRun.emote(token: '[笑哭]', url: _emoteUrl, size: 1)]);
      expect(_root(tester).children!.whereType<TextSpan>().map((span) => span.text), ['回复 ', '小红', ': ']);
      // The test font draws every character 15 wide.
      final left = tester.getRect(find.byType(RemoteImage)).left - tester.getTopLeft(_paragraph).dx;
      expect(left, moreOrLessEquals(7 * 15));
    });

    test('replyLead', () {
      void lead(List<RichRun> runs, String name, List<RichRun> rest) {
        final found = replyLead(runs);
        expect(found?.name, name, reason: '$runs');
        expect(found?.rest, rest, reason: '$runs');
      }

      lead(
        const [RichRun.text('回复 @小红 :说得对'), RichRun.text('!')],
        '小红',
        const [RichRun.text('说得对'), RichRun.text('!')],
      );
      lead(const [RichRun.text('回复 @小红：好')], '小红', const [RichRun.text('好')]);
      lead(const [RichRun.text('回复 @Windows98es : 然后')], 'Windows98es', const [RichRun.text('然后')]);
      lead(const [RichRun.text('回复 @小红 :\n第二行')], '小红', const [RichRun.text('\n第二行')]);
      lead(const [RichRun.text('回复 @小红 :')], '小红', const []);
      lead(
        const [RichRun.text('回复 '), RichRun.mention(name: '小红', mid: 7), RichRun.text(' :好'), RichRun.text('!')],
        '小红',
        const [RichRun.text('好'), RichRun.text('!')],
      );
      lead(const [RichRun.text('回复 '), RichRun.mention(name: '@小红', mid: 7), RichRun.text('：')], '小红', const []);
      for (final runs in const [
        [RichRun.text('回复 @小红 没有冒号')],
        [RichRun.text('回复 @ :空名字')],
        [RichRun.text('看 @小红 :好')],
        [RichRun.text('回复 '), RichRun.mention(name: '小红', mid: 7), RichRun.text(' 没有冒号')],
        [RichRun.text('回复 '), RichRun.mention(name: '小红', mid: 7)],
        [RichRun.text('回复 '), RichRun.text('小红 :好')],
        <RichRun>[],
      ]) {
        expect(replyLead(runs), isNull, reason: '$runs');
      }
    });
  });

  group('links', () {
    const runs = [
      RichRun.text('看'),
      RichRun.link(title: '网页', url: 'https://example.com/a?b=1'),
      RichRun.text('、'),
      RichRun.link(title: '那个视频', url: 'https://www.bilibili.com/video/BV1GJ411x7h7?p=2'),
      RichRun.text('、'),
      RichRun.link(title: '老视频', url: 'https://www.bilibili.com/video/av2/'),
      RichRun.text('、'),
      RichRun.link(title: '搜索词', url: 'bilibili://search?keyword=x'),
    ];

    testWidgets('a video address opens in the app, anything else on the web in the browser', (tester) async {
      final rig = Rig();
      await rig.mount(tester, runs);
      for (final title in ['网页', '那个视频', '老视频']) {
        expect(_span(tester, title).style?.color, CommentTextTheme.link, reason: title);
      }
      final word = _span(tester, '搜索词');
      expect(word.style, isNull);
      expect(word.recognizer, isNull);

      await _tapText(tester, '网页');
      await _tapText(tester, '那个视频');
      await _tapText(tester, '老视频');
      await _tapText(tester, '搜索词');
      expect(rig.links, [Uri.parse('https://example.com/a?b=1')]);
      expect(rig.videos, ['BV1GJ411x7h7', 'av2']);
    });

    testWidgets('with nowhere to open videos, a video address goes to the browser', (tester) async {
      final rig = Rig();
      await rig.mount(tester, runs, videos: false);
      await _tapText(tester, '那个视频');
      expect(rig.links, [Uri.parse('https://www.bilibili.com/video/BV1GJ411x7h7?p=2')]);
    });

    testWidgets('a link nothing could open says so', (tester) async {
      final rig = Rig()..linkOpens = false;
      await rig.mount(tester, runs);
      await _tapText(tester, '网页');
      expect(find.text('无法打开链接'), findsOneWidget);
      await _expireToast(tester);
      expect(find.text('无法打开链接'), findsNothing);

      rig.linkThrows = PlatformException(code: 'ACTIVITY_NOT_FOUND');
      await _tapText(tester, '网页');
      expect(find.text('无法打开链接'), findsOneWidget);
      await _expireToast(tester);
      expect(rig.links, hasLength(2));
    });
  });

  testWidgets('video ids open the video; without a handler they stay plain', (tester) async {
    final rig = Rig();
    const runs = [
      RichRun.text('相关：'),
      RichRun.video(id: 'BV1AB411c7mD'),
      RichRun.text('、'),
      RichRun.video(id: 'av170001'),
    ];
    await rig.mount(tester, runs);
    expect(_span(tester, 'BV1AB411c7mD').style?.color, CommentTextTheme.link);
    await _tapText(tester, 'BV1AB411c7mD');
    await _tapText(tester, 'av170001');
    expect(rig.videos, ['BV1AB411c7mD', 'av170001']);

    await rig.mount(tester, runs, videos: false);
    final plain = _span(tester, 'BV1AB411c7mD');
    expect(plain.style, isNull);
    expect(plain.recognizer, isNull);
  });

  testWidgets('timestamps seek; without a handler they stay plain', (tester) async {
    final rig = Rig();
    const runs = [RichRun.text('名场面在'), RichRun.timestamp(label: '1:02:03', seconds: 3723)];
    await rig.mount(tester, runs);
    expect(_span(tester, '1:02:03').style?.color, CommentTextTheme.link);
    await _tapText(tester, '1:02:03');
    expect(rig.seeks, [3723]);

    await rig.mount(tester, runs, seeks: false);
    final plain = _span(tester, '1:02:03');
    expect(plain.style, isNull);
    expect(plain.recognizer, isNull);
  });

  testWidgets('recognizers are made once per runs list', (tester) async {
    final rig = Rig();
    TapGestureRecognizer recognizer() => _span(tester, '0:30').recognizer! as TapGestureRecognizer;
    await rig.mount(tester, const [RichRun.text('看'), RichRun.timestamp(label: '0:30', seconds: 30)]);
    final first = recognizer();

    await rig.mount(tester, [const RichRun.text('看'), const RichRun.timestamp(label: '0:30', seconds: 30)]);
    expect(recognizer(), same(first));

    await rig.mount(tester, const [RichRun.text('再看'), RichRun.timestamp(label: '0:30', seconds: 30)]);
    expect(recognizer(), isNot(same(first)));

    await rig.mount(tester, const [RichRun.text('再看'), RichRun.timestamp(label: '0:30', seconds: 30)], seeks: false);
    expect(_span(tester, '0:30').recognizer, isNull);
  });
}
