import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show CheckedState, Tristate;

import 'package:bili_core/api.dart';
import 'package:bilifast/comments/comments_model.dart';
import 'package:bilifast/comments/composer.dart';
import 'package:bilifast/comments/composer_model.dart';
import 'package:bilifast/comments/emote_panel.dart';
import 'package:bilifast/comments/mention_picker.dart';
import 'package:bilifast/comments/picture_attach.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const screen = Size(440, 956);
const safeTop = 62.0;
const safeBottom = 34.0;
const keyboard = 336.0;

/// What the composer asks of its model, with the calls it makes recorded in order.
class FakeComposerModel extends ComposerModel {
  FakeComposerModel({
    String text = '',
    bool emotes = false,
    this.hint = '发条评论',
    this.recentEmotes = const [],
    this._packages = const [],
    super.target = const ReplyToVideo(),
    List<PickedPicture> pictures = const [],
  }) : _pictures = [...pictures],
       super(
         comments: CommentsModel(
           aid: 1,
           upMid: 2,
           api: FakePageApi(),
           drafts: CommentDrafts(),
           isLoggedIn: () => true,
           accountMid: () => 3,
           requestLogin: () {},
           toast: (_) {},
         ),
       ) {
    this.text = text;
    showingEmotes = emotes;
  }

  final String hint;
  final List<Emote> recentEmotes;
  final List<EmotePackage> _packages;
  final List<PickedPicture> _pictures;
  final calls = <String>[];
  bool _postable = false;
  bool _posting = false;
  Completer<bool>? pending;

  set postable(bool value) {
    _postable = value;
    notifyListeners();
  }

  @override
  bool get canPost => _postable;

  @override
  bool get posting => _posting;

  @override
  String get placeholder => hint;

  @override
  List<Emote> get recent => recentEmotes;

  @override
  void usedEmote(Emote emote) => calls.add('used ${emote.token}');

  @override
  Future<List<EmotePackage>> emotePackages() async => _packages;

  @override
  void mentioned(MentionCandidate who) => calls.add('mentioned ${who.name}');

  @override
  Future<List<MentionCandidate>> searchMentions(String query) async => const [];

  @override
  List<PickedPicture> get pictures => List.unmodifiable(_pictures);

  @override
  void addPictures(List<PickedPicture> picked) {
    calls.add('add ${picked.length}');
    _pictures.addAll(picked);
    notifyListeners();
  }

  @override
  Future<bool> post() async {
    calls.add('post');
    _posting = true;
    notifyListeners();
    final posted = await (pending = Completer<bool>()).future;
    _posting = false;
    notifyListeners();
    return posted;
  }
}

class Rig {
  Rig(this.model);

  final FakeComposerModel model;
  int closes = 0;
  final pickLimits = <int>[];
  PicturePick toPick = const PicturePick([]);
}

Widget app(Rig rig, {double inset = 0, bool still = false, double? top, ThemeMode? appearance}) => MaterialApp(
  theme: appearance == null ? null : biliTheme(Brightness.light),
  darkTheme: appearance == null ? null : biliTheme(Brightness.dark),
  themeMode: appearance,
  themeAnimationDuration: Duration.zero,
  home: MediaQuery(
    data: MediaQueryData(
      size: screen,
      padding: EdgeInsets.only(top: safeTop, bottom: inset > 0 ? 0 : safeBottom),
      viewPadding: const EdgeInsets.only(top: safeTop, bottom: safeBottom),
      viewInsets: EdgeInsets.only(bottom: inset),
      disableAnimations: still,
    ),
    child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: Composer(
        model: rig.model,
        onClose: () => rig.closes++,
        top: top,
        pick: ({required limit}) async {
          rig.pickLimits.add(limit);
          return rig.toPick;
        },
      ),
    ),
  ),
);

Future<Rig> pumpComposer(
  WidgetTester tester,
  FakeComposerModel model, {
  double inset = 0,
  bool still = false,
  double? top,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(model.dispose);
  final rig = Rig(model);
  await tester.pumpWidget(app(rig, inset: inset, still: still, top: top));
  await tester.pump(const Duration(milliseconds: 300));
  return rig;
}

/// Lets a toast run out, so no timer outlives the test.
Future<void> outlastToast(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Finder get field => find.byKey(const ValueKey('composer-field'));

TextEditingController controllerOf(WidgetTester tester) => tester.widget<TextField>(field).controller!;

bool focused(WidgetTester tester) => tester.widget<TextField>(field).focusNode!.hasFocus;

Rect sheet(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey('composer-sheet')));

Future<void> press(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pump();
}

const doge = Emote(token: '[doge]', url: 'https://i0.hdslb.com/doge.png', large: false);
const laugh = Emote(token: '[笑哭]', url: 'https://i0.hdslb.com/laugh.png', large: false);
const kaomoji = Emote(token: '(⌒▽⌒)', url: '', large: false);
const faces = EmotePackage(
  id: 1,
  name: '小黄脸',
  icon: 'https://i0.hdslb.com/icon.png',
  isText: false,
  emotes: [doge, laugh],
);
const words = EmotePackage(id: 4, name: '颜文字', icon: '', isText: true, emotes: [kaomoji]);

PickedPicture picture(String name) => PickedPicture(bytes: Uint8List(4), name: name);

void main() {
  setUp(Composer.debugForgetKeyboard);

  testWidgets('dark composer keeps its draft and controller when appearance changes', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final model = FakeComposerModel(text: 'draft');
    addTearDown(model.dispose);
    final rig = Rig(model);
    await tester.pumpWidget(app(rig, appearance: ThemeMode.dark, still: true));
    await tester.pump();
    final controller = controllerOf(tester);
    expect(tester.widget<TextField>(field).keyboardAppearance, Brightness.dark);
    expect(tester.widget<TextField>(field).style!.color, const Color(0xFFE3E5E7));
    await tester.enterText(field, 'retained draft');
    await tester.pumpWidget(app(rig, appearance: ThemeMode.light, still: true));
    await tester.pump();
    expect(controllerOf(tester), same(controller));
    expect(controllerOf(tester).text, 'retained draft');
    expect(tester.widget<TextField>(field).keyboardAppearance, Brightness.light);
    expect(tester.widget<TextField>(field).style!.color, ComposerTheme.text);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens on the keyboard: the draft in a focused field', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel(text: '草稿'));
    expect(focused(tester), isTrue);
    expect(controllerOf(tester).text, '草稿');
    expect(controllerOf(tester).selection, const TextSelection.collapsed(offset: 2));
    expect(find.byType(EmotePanel), findsNothing);
    expect(rig.model.showingEmotes, isFalse);
  });

  testWidgets('the placeholder is the field\'s hint while it is empty', (tester) async {
    await pumpComposer(tester, FakeComposerModel(hint: '回复 殇泪丶丿 :'));
    expect(find.text('回复 殇泪丶丿 :'), findsOneWidget);
  });

  testWidgets('with Reduce Motion the sheet is up on the first frame, with no slide', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final model = FakeComposerModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(app(Rig(model), still: true));
    expect(sheet(tester).bottom, screen.height);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('without Reduce Motion the sheet slides up', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final model = FakeComposerModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(app(Rig(model)));
    expect(sheet(tester).top, screen.height);
    await tester.pump(ComposerTheme.rise);
    expect(sheet(tester).bottom, screen.height);
  });

  testWidgets('the field and model.text follow each other', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel());
    await tester.enterText(field, '你好');
    expect(rig.model.text, '你好');
    rig.model.text = '换了';
    await tester.pump();
    expect(controllerOf(tester).text, '换了');
  });

  testWidgets('opens on emotes: unfocused, with the panel at 14\'s height before the keyboard has been seen', (
    tester,
  ) async {
    final rig = await pumpComposer(tester, FakeComposerModel(emotes: true, packages: const [faces]));
    expect(focused(tester), isFalse);
    expect(rig.model.showingEmotes, isTrue);
    final panel = tester.getRect(find.byType(EmotePanel));
    expect(panel.height, ComposerTheme.panelHeight + ComposerTheme.tabHeight + safeBottom);
    expect(panel.bottom, screen.height);
    // 14: the panel's grey starts at 652 pt and the sheet at 537 pt.
    expect(panel.top, 652);
    expect(sheet(tester).top, 537);
  });

  testWidgets('rides on the keyboard: the sheet\'s bottom is the inset, or the home indicator\'s strip without one', (
    tester,
  ) async {
    final rig = await pumpComposer(tester, FakeComposerModel());
    final strip = tester.getRect(find.byKey(const ValueKey('composer-keyboard')));
    expect(strip.top, screen.height - safeBottom);
    expect(sheet(tester).bottom, screen.height);

    await tester.pumpWidget(app(rig, inset: keyboard));
    expect(tester.getRect(find.byKey(const ValueKey('composer-keyboard'))).top, screen.height - keyboard);
    expect(sheet(tester).top, screen.height - keyboard - ComposerTheme.editorHeight - ComposerTheme.toolbarHeight);

    await tester.pumpWidget(app(rig, inset: 120));
    expect(tester.getRect(find.byKey(const ValueKey('composer-keyboard'))).top, screen.height - 120);
  });

  testWidgets('表情 puts the keyboard down and the panel up at the keyboard\'s height; 键盘 brings it back', (
    tester,
  ) async {
    final rig = await pumpComposer(tester, FakeComposerModel(packages: const [faces]), inset: keyboard);
    final top = sheet(tester).top;
    await press(tester, '表情');
    expect(rig.model.showingEmotes, isTrue);
    expect(focused(tester), isFalse);
    expect(tester.getRect(find.byType(EmotePanel)).height, keyboard);
    expect(find.bySemanticsLabel('键盘'), findsOneWidget);

    // The keyboard goes down behind the panel; the sheet stays where it was.
    await tester.pumpWidget(app(rig));
    await tester.pump();
    expect(sheet(tester).top, top);

    await press(tester, '键盘');
    expect(focused(tester), isTrue);
    expect(rig.model.showingEmotes, isTrue, reason: 'the panel waits for the keyboard');
    await tester.pumpWidget(app(rig, inset: 200));
    expect(rig.model.showingEmotes, isTrue, reason: 'the keyboard is still on its way up');
    await tester.pumpWidget(app(rig, inset: keyboard));
    await tester.pump();
    expect(rig.model.showingEmotes, isFalse);
    expect(find.byType(EmotePanel), findsNothing);
    expect(sheet(tester).top, top);
    expect(find.bySemanticsLabel('表情'), findsOneWidget);
  });

  testWidgets('键盘 pressed through accessibility refocuses the field, and the panel gives way to the keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final rig = await pumpComposer(tester, FakeComposerModel(emotes: true, packages: const [faces]));
    expect(focused(tester), isFalse);
    tester.semantics.tap(find.semantics.byLabel('键盘'));
    await tester.pump();
    expect(focused(tester), isTrue);
    await tester.pumpWidget(app(rig, inset: keyboard));
    await tester.pump();
    expect(rig.model.showingEmotes, isFalse);
    expect(find.byType(EmotePanel), findsNothing);
    expect(tester.getRect(find.byKey(const ValueKey('composer-keyboard'))).height, keyboard);
    semantics.dispose();
  });

  testWidgets('the panel remembers the keyboard\'s height for the next composer', (tester) async {
    final first = await pumpComposer(tester, FakeComposerModel(), inset: 300);
    await press(tester, '表情');
    expect(tester.getRect(find.byType(EmotePanel)).height, 300);
    await tester.pumpWidget(const SizedBox());
    first.model.showingEmotes = false;

    await pumpComposer(tester, FakeComposerModel(emotes: true));
    expect(tester.getRect(find.byType(EmotePanel)).height, 300);
  });

  testWidgets('with no software keyboard coming, the panel gives way after a while', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel(emotes: true));
    await press(tester, '键盘');
    expect(focused(tester), isTrue);
    await tester.pump(ComposerTheme.keyboardWait - const Duration(milliseconds: 100));
    expect(rig.model.showingEmotes, isTrue);
    await tester.pump(const Duration(milliseconds: 150));
    expect(rig.model.showingEmotes, isFalse);
    expect(find.byType(EmotePanel), findsNothing);
  });

  testWidgets('an emote goes in at the cursor and is recorded; a kaomoji goes in as itself', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel(text: 'ab', packages: const [faces, words]));
    controllerOf(tester).selection = const TextSelection.collapsed(offset: 1);
    await press(tester, '表情');
    await tester.pump();
    await press(tester, '[doge]');
    expect(rig.model.text, 'a[doge]b');
    await press(tester, '[笑哭]');
    expect(rig.model.text, 'a[doge][笑哭]b');
    expect(controllerOf(tester).selection, const TextSelection.collapsed(offset: 11));

    await press(tester, '颜文字');
    await press(tester, '(⌒▽⌒)');
    expect(rig.model.text, 'a[doge][笑哭](⌒▽⌒)b');
    expect(rig.model.calls, ['used [doge]', 'used [笑哭]', 'used (⌒▽⌒)']);
  });

  testWidgets('an emote replaces a selection', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel(text: 'abcd', emotes: true, packages: const [faces]));
    controllerOf(tester).selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    await press(tester, '[doge]');
    expect(rig.model.text, 'a[doge]d');
  });

  testWidgets('发布 is light pink and does nothing until there is something to post', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel());
    Color pill() =>
        (tester
                    .widget<Container>(
                      find.descendant(
                        of: find.byKey(const ValueKey('composer-publish')),
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as ShapeDecoration)
            .color!;
    bool enabled() =>
        tester
            .getSemantics(find.byKey(const ValueKey('composer-publish')))
            .getSemanticsData()
            .flagsCollection
            .isEnabled ==
        Tristate.isTrue;

    expect(pill(), ComposerTheme.accentFaded);
    expect(enabled(), isFalse);
    await tester.tap(find.text('发布'));
    await tester.pump();
    expect(rig.model.calls, isEmpty);

    rig.model.postable = true;
    await tester.pump();
    expect(pill(), ComposerTheme.accent);
    expect(enabled(), isTrue);
    await tester.tap(find.text('发布'));
    await tester.pump();
    expect(rig.model.calls, ['post']);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(enabled(), isFalse, reason: 'busy while posting');
    await tester.tap(find.byKey(const ValueKey('composer-publish')));
    await tester.pump();
    expect(rig.model.calls, ['post']);
    rig.model.pending!.complete(false);
    await tester.pump();
  });

  testWidgets('closes after a post that went through, and only then', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel(text: '评论'))
      ..model.postable = true;
    await tester.pump();
    await press(tester, '发布');
    rig.model.pending!.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(rig.closes, 0);
    expect(controllerOf(tester).text, '评论');

    await press(tester, '发布');
    rig.model.pending!.complete(true);
    await tester.pump();
    expect(rig.closes, 0, reason: 'the sheet goes down first');
    await tester.pump(const Duration(milliseconds: 300));
    expect(rig.closes, 1);
    expect(focused(tester), isFalse);
  });

  testWidgets('a tap on the dimmed page closes, but not while posting', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel(text: '评论'))
      ..model.postable = true;
    await tester.pump();
    await press(tester, '发布');
    await tester.tapAt(const Offset(220, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(rig.closes, 0);

    rig.model.pending!.complete(false);
    await tester.pump();
    await tester.tapAt(const Offset(220, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(rig.closes, 1);
    await tester.tapAt(const Offset(220, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(rig.closes, 1, reason: 'closes once');
  });

  testWidgets('⤢ makes the field tall, and back', (tester) async {
    await pumpComposer(tester, FakeComposerModel());
    expect(tester.getRect(field).height, ComposerTheme.editorHeight);
    await press(tester, '展开');
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(field).height, ComposerTheme.expandedEditorHeight);
    await press(tester, '收起');
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(field).height, ComposerTheme.editorHeight);
  });

  testWidgets('转到动态 flips the model\'s switch and reads as checked', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel());
    CheckedState checked() =>
        tester.getSemantics(find.byKey(const ValueKey('composer-sync'))).getSemanticsData().flagsCollection.isChecked;
    expect(checked(), CheckedState.isFalse);
    await press(tester, '转到动态');
    expect(rig.model.syncToDynamic, isTrue);
    expect(checked(), CheckedState.isTrue);
    await press(tester, '转到动态');
    expect(rig.model.syncToDynamic, isFalse);
  });

  testWidgets('@ puts the picker up below the player and clear of the keyboard; a pick goes in at the cursor', (
    tester,
  ) async {
    final rig = await pumpComposer(tester, FakeComposerModel(text: '你好'), inset: keyboard);
    controllerOf(tester).selection = const TextSelection.collapsed(offset: 1);
    await press(tester, '提及好友');
    final picker = find.byType(MentionPicker);
    expect(picker, findsOneWidget);
    final box = tester.getRect(picker);
    expect(box.top, safeTop + screen.width / BiliMetrics.videoAspect);
    expect(box.bottom, screen.height - keyboard);

    tester.widget<MentionPicker>(picker).onPick(const MentionCandidate(mid: 7, name: '二乃'));
    await tester.pump();
    expect(rig.model.text, '你@二乃 好');
    expect(rig.model.calls, ['mentioned 二乃']);
    expect(find.byType(MentionPicker), findsNothing);
    expect(focused(tester), isTrue, reason: 'back on the keyboard it came from');
  });

  testWidgets('the picker starts at the live player edge it is given', (tester) async {
    await pumpComposer(tester, FakeComposerModel(), inset: keyboard, top: 130);
    await press(tester, '提及好友');
    final box = tester.getRect(find.byType(MentionPicker));
    expect(box.top, 130);
    expect(box.bottom, screen.height - keyboard);
  });

  testWidgets('closing the picker from emotes stays on emotes', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel(emotes: true));
    await press(tester, '提及好友');
    tester.widget<MentionPicker>(find.byType(MentionPicker)).onClose();
    await tester.pump();
    expect(find.byType(MentionPicker), findsNothing);
    expect(focused(tester), isFalse);
    expect(rig.model.showingEmotes, isTrue);
  });

  testWidgets('⊕ picks as many as there is room for and attaches them over the toolbar', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel(pictures: [picture('a.jpg')]));
    expect(find.byType(AttachedPictures), findsOneWidget);
    rig.toPick = PicturePick([picture('b.jpg'), picture('c.png')]);
    await press(tester, '添加图片');
    await tester.pump();
    expect(rig.pickLimits, [ComposerModel.maxPictures - 1]);
    expect(rig.model.calls, ['add 2']);
    expect(rig.model.pictures, hasLength(3));
  });

  testWidgets('⊕ with no room left says so and picks nothing', (tester) async {
    final rig = await pumpComposer(
      tester,
      FakeComposerModel(pictures: [for (var i = 0; i < ComposerModel.maxPictures; i++) picture('$i.jpg')]),
    );
    await press(tester, '添加图片');
    expect(rig.pickLimits, isEmpty);
    expect(find.text('最多添加9张图片'), findsOneWidget);
    await outlastToast(tester);
  });

  testWidgets('a cancelled pick adds nothing and says nothing', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel());
    await press(tester, '添加图片');
    await tester.pump();
    expect(rig.pickLimits, [ComposerModel.maxPictures]);
    expect(rig.model.calls, isEmpty);
    expect(find.byKey(const ValueKey('toast')), findsNothing);
  });

  testWidgets('a pick without photo access says to allow it in 设置', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel());
    rig.toPick = const PicturePick.failed(PickFailure.noAccess);
    await press(tester, '添加图片');
    await tester.pump();
    expect(rig.model.calls, isEmpty);
    expect(find.text('无法访问照片，请在设置中允许BiliFast访问照片'), findsOneWidget);
    await outlastToast(tester);
  });

  testWidgets('a pick that fails says so; one that fails part way keeps what it read', (tester) async {
    final rig = await pumpComposer(tester, FakeComposerModel());
    rig.toPick = const PicturePick.failed(PickFailure.failed);
    await press(tester, '添加图片');
    await tester.pump();
    expect(rig.model.calls, isEmpty);
    expect(find.text('图片读取失败，请重试'), findsOneWidget);
    await outlastToast(tester);

    rig.toPick = PicturePick([picture('a.jpg')], failure: PickFailure.failed);
    await press(tester, '添加图片');
    await tester.pump();
    expect(rig.model.calls, ['add 1']);
    expect(find.text('部分图片读取失败'), findsOneWidget);
    await outlastToast(tester);
  });

  testWidgets('a failed pick\'s toast shows over the keyboard', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    final rig = await pumpComposer(tester, FakeComposerModel(), inset: keyboard);
    rig.toPick = const PicturePick.failed(PickFailure.failed);
    await press(tester, '添加图片');
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey('toast'))).bottom, lessThanOrEqualTo(screen.height - keyboard));
    await outlastToast(tester);
  });

  testWidgets('replies have ⊕ too, as on 14', (tester) async {
    final comment = Comment(
      rpid: 5,
      member: const CommentMember(mid: 6, name: '殇泪丶丿'),
      message: '拳头的规则',
    );
    await pumpComposer(tester, FakeComposerModel(target: ReplyToComment(comment)));
    expect(find.bySemanticsLabel('添加图片'), findsOneWidget);
    expect(find.bySemanticsLabel('提及好友'), findsOneWidget);
    // 14: ⊕ spans 174-194 pt.
    expect(tester.getCenter(find.byKey(const ValueKey('composer-pictures'))).dx, 184);
  });

  testWidgets('every control is a button with a Chinese label', (tester) async {
    await pumpComposer(tester, FakeComposerModel());
    for (final label in const ['转到动态', '表情', '提及好友', '添加图片', '发布', '展开', '关闭']) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue, reason: label);
    }
  });

  testWidgets('the emote panel\'s failure asks again on a tap', (tester) async {
    final model = _FlakyModel();
    await pumpComposer(tester, model);
    expect(find.text('表情加载失败，点击重试'), findsOneWidget);
    await press(tester, '表情加载失败，点击重试');
    await tester.pump();
    expect(model.asked, 2);
    expect(find.bySemanticsLabel('[doge]'), findsOneWidget);
  });
}

/// Fails the first time the packages are asked for.
class _FlakyModel extends FakeComposerModel {
  _FlakyModel() : super(emotes: true);

  int asked = 0;

  @override
  Future<List<EmotePackage>> emotePackages() async {
    asked++;
    if (asked == 1) throw StateError('offline');
    return const [faces];
  }
}
