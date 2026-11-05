import 'dart:io';

import 'package:bili_core/api.dart' hide VideoPage;
import 'package:bili_core/devlog.dart';
import 'package:bili_core/shared.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/feed_big_card.dart';
import 'package:bilifast/home/feed_inline_player.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/home_page.dart';
import 'package:bilifast/home/main_shell.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/playback/playback_controller.dart';
import 'package:bilifast/player/bili_player.dart';
import 'package:bilifast/player_ui/player_gestures.dart';
import 'package:bilifast/search/fake_search_api.dart';
import 'package:bilifast/settings/font_store.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../playback/fakes.dart';
import '../support/fake_player.dart';
import '../support/look_alike.dart';
import '../support/stand_in_fonts.dart';
import '../video/mixed_lines.dart' show appTheme;
import 'feed_fakes.dart';

const _screen = ValueKey('screen');

/// The big card playing as KaiC's iPhone draws it (123, 126), under the system font. With BILIFAST_SHOTS naming a folder
/// outside the repo, the 3× shot is saved there for tools/screen_diff.py and the measuring scripts.
void main() {
  setUp(() {
    FeedInlineChoices.reset();
    HomePage.feedMinimumRefresh = Duration.zero;
    HomePage.precacheCover = (context, url, size) async => true;
    HomePage.precacheBigCover = (context, url, size) async => true;
    addTearDown(() {
      HomePage.feedMinimumRefresh = FeedModel.minimumRefresh;
      HomePage.feedPages = null;
    });
  });

  Future<FakePlayer> showPlaying(WidgetTester tester, FeedCard big, {bool playing = true, bool dark = false}) async {
    HomePage.feedPages = (index) async => index == 1 ? [big, ...smalls('a', 6)] : const [];
    final saved = BiliFonts.family;
    addTearDown(() => BiliFonts.family = saved);
    await tester.runAsync(loadSystemFontStandIns);
    showAsPhone(tester);
    final logger = Logger(session: 'test');
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(StoredCookies(Canned.cookies)),
      http: FeedHttp(),
      logger: logger,
    );
    await environment.refreshAccount();
    final now = DateTime.fromMillisecondsSinceEpoch((Canned.deadline - 1000) * 1000);
    final players = <FakePlayer>[];
    final playback = AppPlayback(() async {
      final player = FakePlayer();
      players.add(player);
      return PlaybackController(
        client: environment.client,
        engine: FakeEngine(),
        player: player,
        clock: ManualClock(10000).clock,
        now: () => now,
        startTimer: FakeTimers().start,
        logger: logger,
      );
    });
    addTearDown(playback.dispose);
    final services = AppServices(
      environment: environment,
      playback: playback,
      recents: await RecentStore.load(null, logger: logger),
      fonts: FontStore.memory()..select(FontChoice.system),
      searchApi: FakeSearchApi(defaultWord: '本次复刻先祖'),
    );
    BiliFonts.family = BiliFonts.system;
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? biliTheme(Brightness.dark) : appTheme(),
        builder: (context, child) => RepaintBoundary(
          key: _screen,
          child: AppScope(services: services, child: child!),
        ),
        home: const MainShell(),
      ),
    );
    await tester.runAsync(() async {
      await loadIconFonts();
      final context = tester.element(find.byType(MainShell));
      for (final asset in [
        'assets/images/card/stat_play.png',
        'assets/images/card/stat_danmaku.png',
        FeedBigCardView.mutedAsset,
        FeedBigCardView.soundAsset,
        FeedBigCardView.likeAsset,
        FeedBigCardView.playAsset,
      ]) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (playing) {
      players.single.emit(const StatusChanged(PlayerStatus.playing));
    } else {
      // In the background it pauses, before its first frame: the cover with its ▶.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return players.single;
  }

  Rect inCard(WidgetTester tester, String bvid, Key key) =>
      tester.getRect(find.descendant(of: find.byKey(ValueKey('feed-card-$bvid')), matching: find.byKey(key)));

  for (final dark in [false, true]) {
    testWidgets('focused tile gesture HUDs fit the ${dark ? 'dark' : 'light'} phone feed', (tester) async {
      const bvid = 'BV1GJ411x7h7';
      final player = await showPlaying(tester, bigCard(bvid, fullTitle: '视频播放手势'), dark: dark);
      player.emit(const DurationChanged(600));
      final video = inCard(tester, bvid, const ValueKey('big-card-open'));
      var gesture = await tester.startGesture(video.center);
      await gesture.moveBy(Offset(video.width / 4, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final seek = tester.getRect(find.byKey(const ValueKey('hud-seek')));
      expect(video.contains(seek.center), isTrue);
      final shots = Platform.environment['BILIFAST_SHOTS'];
      if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/feed-seek-${dark ? 'dark' : 'light'}.png');
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 500));
      gesture = await tester.startGesture(video.center);
      await tester.pump(PlayerGestureLayer.holdDelay + const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      final speed = tester.getRect(find.byKey(const ValueKey('hud-speed-pill')));
      expect(video.contains(speed.topLeft), isTrue);
      expect(video.contains(speed.bottomRight), isTrue);
      if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/feed-speed-${dark ? 'dark' : 'light'}.png');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("123's two-line title: the card 428 pt wide, the video 16:9, the band 59.67 pt, 👍 and ⋮ where 123 has "
      'them', (tester) async {
    const bvid = 'BV1GJ411x7h7';
    await showPlaying(tester, bigCard(bvid, fullTitle: '在夜晚东京街头唱了《真夜中のドア～stay with me》会穿越回泡沫经济时代吗?', likes: 28000));
    final card = tester.getRect(find.byKey(const ValueKey('feed-card-$bvid')));
    final video = inCard(tester, bvid, const ValueKey('big-card-open'));
    expect(card.left, 16);
    expect(card.width, 408);
    expect(video.height, moreOrLessEquals(229.5));
    expect(card.bottom - video.bottom, moreOrLessEquals(74, epsilon: 0.5), reason: "123's band, 456.33 to 516");
    final like = inCard(tester, bvid, const ValueKey('big-card-like'));
    expect(like.center.dx, moreOrLessEquals(card.right - FeedBigCardTheme.likeRight));
    final more = inCard(tester, bvid, const ValueKey('big-card-more'));
    expect(more.center.dx, moreOrLessEquals(card.right - FeedBigCardTheme.moreRight));
    final sound = inCard(tester, bvid, const ValueKey('big-card-sound'));
    expect(sound.center.dx, moreOrLessEquals(card.right - FeedBigCardTheme.speakerRight));
    expect(video.bottom - sound.center.dy, moreOrLessEquals(FeedBigCardTheme.buttonCentre));

    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/123-big-card-ours.png');
  });

  testWidgets("126's one-line title: the band 40.33 pt", (tester) async {
    const bvid = 'BV1GJ411x7h7';
    await showPlaying(tester, bigCard(bvid, fullTitle: '科学家们用物理智斗爱因斯坦?', likes: 429000));
    final card = tester.getRect(find.byKey(const ValueKey('feed-card-$bvid')));
    final video = inCard(tester, bvid, const ValueKey('big-card-open'));
    expect(card.bottom - video.bottom, moreOrLessEquals(55, epsilon: 0.5), reason: "126's band, 388.67 to 429");

    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/126-big-card-ours.png');
  });

  testWidgets('the dark phone feed shows uploader and upload time under the video', (tester) async {
    const bvid = 'BV1GJ411x7h7';
    final published = DateTime.now().subtract(const Duration(hours: 10)).millisecondsSinceEpoch ~/ 1000;
    await showPlaying(tester, bigCard(bvid, fullTitle: '2万多能买满改咬地鲨？', likes: 465, published: published), dark: true);
    expect(find.text('UP $bvid · 10小时前'), findsOneWidget);
    final video = inCard(tester, bvid, const ValueKey('big-card-open'));
    final avatar = inCard(tester, bvid, const ValueKey('feed-uploader-avatar'));
    final byline = inCard(tester, bvid, const ValueKey('feed-uploader-byline'));
    expect(avatar.top, video.bottom + FeedBigCardTheme.titlePad);
    expect(byline.left, avatar.right + FeedBigCardTheme.avatarGap);
    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/feed-dark-with-date.png');
  });

  testWidgets("122's cover: the ▶'s body 46.67 pt wide on the video's middle, the counts and the duration", (
    tester,
  ) async {
    const bvid = 'BV1GJ411x7h7';
    await showPlaying(tester, bigCard(bvid, fullTitle: '【EVA-明日香】耗时一年，自制CG动画【手搓动画大赛】'), playing: false);
    final video = inCard(tester, bvid, const ValueKey('big-card-open'));
    final play = inCard(tester, bvid, const ValueKey('big-card-play'));
    expect(play.width * 204 / 240, moreOrLessEquals(46.67, epsilon: 0.01), reason: "the file's body, 204 of 240 px");
    expect(play.center.dx, moreOrLessEquals(video.center.dx));
    expect(play.center.dy, moreOrLessEquals(video.center.dy));
    final duration = inCard(tester, bvid, const ValueKey('big-card-duration'));
    expect(duration.right, moreOrLessEquals(video.right - FeedBigCardTheme.durationTrail));
    expect(find.text('11:52'), findsOneWidget, reason: 'the card says 712 s');

    final shots = Platform.environment['BILIFAST_SHOTS'];
    if (shots != null) await saveShot(tester, find.byKey(_screen), '$shots/122-big-card-cover-ours.png');
  });
}
