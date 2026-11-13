import 'dart:async';

import 'package:bili_core/api.dart';
import 'package:bili_core/devlog.dart';
import 'package:bilifast/home/feed_model.dart';
import 'package:bilifast/home/feed_preferences.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../playback/fakes.dart';
import 'feed_fakes.dart';

void main() {
  late FeedHttp http;
  late BiliClient client;
  late FeedPreferences preferences;
  late MemorySink logs;
  int? owner = 7;

  setUp(() {
    http = FeedHttp();
    client = BiliClient(transport: http, cookies: CookieJar(Canned.cookies), logger: Logger(session: 'test'));
    preferences = FeedPreferences.memory();
    logs = MemorySink();
    owner = 7;
  });

  FeedModel make({bool official = false, Duration minimumRefresh = Duration.zero}) {
    if (official) client.appToken = fakeAppToken;
    final feed = FeedModel(
      client: client,
      preferences: preferences,
      accountMid: () => owner,
      officialWanted: () => official,
      minimumRefresh: minimumRefresh,
      logger: Logger(session: 'test')..add(logs),
    );
    addTearDown(feed.dispose);
    return feed;
  }

  void seen(Iterable<String> ids) {
    for (final id in ids) {
      preferences.recordSeen(accountMid: owner, bvid: id, ownerMid: 7);
    }
  }

  List<String> ids(FeedModel feed) => [for (final card in feed.cards) card.bvid];

  test('publishing a refresh does not apply uploader affinity twice', () async {
    for (var index = 0; index < 2; index++) {
      preferences.recordWatch(accountMid: owner, bvid: 'seed$index', ownerMid: 99, seconds: 35);
    }
    http.pages[1] = [
      for (var index = 0; index < 4; index++) {...feedItem('BV$index'), 'owner': {'mid': 10 + index, 'name': 'Uploader'}},
      {...feedItem('BVpreferred'), 'owner': {'mid': 99, 'name': 'Uploader'}},
    ];
    final feed = make();
    await feed.refresh();
    expect(ids(feed).indexOf('BVpreferred'), 2);
    expect(http.asked, [1]);
  });

  test('watched candidates never fill a batch and lookahead has a fixed request cap', () async {
    for (var index = 1; index <= 5; index++) {
      http.pages[index] = [feedItem('BV$index')];
      preferences.recordWatch(accountMid: owner, bvid: 'BV$index', ownerMid: 7, seconds: 35);
    }
    final feed = make();
    await feed.refresh();
    expect(ids(feed), isEmpty);
    expect(feed.error, FeedModel.emptyMessage);
    expect(http.asked, [1, 2, 3, 4]);
  });

  test('successive refreshes search beyond the same prefix even when no fresh page was found', () async {
    for (var index = 1; index <= 4; index++) {
      http.pages[index] = [feedItem('BVold')];
    }
    http.pages[5] = [feedItem('BVnew')];
    seen(['BVold']);
    final feed = make();
    await feed.refresh();
    expect(ids(feed), isEmpty);
    await feed.refresh();
    expect(ids(feed), ['BVnew']);
    expect(http.asked, [1, 2, 3, 4, 1, 5]);
  });

  test('search continuation is isolated across account sessions', () async {
    http.pages[1] = [feedItem('BVold')];
    http.pages[2] = [feedItem('BVnew')];
    seen(['BVold']);
    final feed = make();
    await feed.refresh();
    owner = 8;
    seen(['BVold']);
    await feed.refresh(replace: true);
    expect(ids(feed), ['BVnew']);
    expect(http.asked, [1, 2, 1, 2]);
    client.invalidateSession();
    await feed.refresh(replace: true);
    expect(http.asked, [1, 2, 1, 2, 1, 2]);
  });

  test('load more rechecks surplus candidates watched since the refresh', () async {
    http.pages[1] = [feedItem('BVold')];
    http.pages[2] = [feedItem('BVnew'), feedItem('BVlater')];
    http.pages[3] = [feedItem('BVnext')];
    seen(['BVold']);
    final feed = make();
    await feed.refresh();
    preferences.recordWatch(accountMid: owner, bvid: 'BVlater', ownerMid: 7, seconds: 35);
    await feed.loadMore();
    expect(ids(feed), ['BVnew', 'BVnext']);
    expect(http.asked, [1, 2, 3]);
  });

  test('refresh removes watched cards from the retained previous batch', () async {
    http.pages[1] = [feedItem('BVwatched'), feedItem('BVkeep')];
    final feed = make();
    await feed.refresh();
    preferences.recordWatch(accountMid: owner, bvid: 'BVwatched', ownerMid: 7, seconds: 35);
    http.pages[1] = [feedItem('BVnew')];
    await feed.refresh();
    expect(ids(feed), ['BVnew', 'BVkeep']);
    expect(feed.newest.map((card) => card.bvid), ['BVnew']);
    expect(feed.dividerAt, 1);
  });

  test('an armed result rechecks exposure before publishing', () async {
    http.pages[1] = [feedItem('BV1')];
    final feed = make();
    feed.pullArmed();
    await pumpEventQueue();
    seen(['BV1']);
    await feed.refresh(pulled: true);
    expect(ids(feed), isEmpty);
    expect(feed.error, FeedModel.emptyMessage);
    expect(http.asked, [1]);
  });

  test('a mostly repeated refresh selects unseen candidates and retains the rest for load more', () async {
    http.pages[1] = [feedItem('BV1'), feedItem('BV2')];
    http.pages[2] = [feedItem('BV3'), feedItem('BV4'), feedItem('BV5')];
    http.pages[3] = [feedItem('BV6')];
    seen(['BV1', 'BV2']);
    final feed = make();
    await feed.refresh();
    expect(ids(feed), ['BV3', 'BV4']);
    expect(http.asked, [1, 2]);
    await feed.loadMore();
    expect(ids(feed).toSet(), {'BV3', 'BV4', 'BV5'});
    expect(http.asked, [1, 2], reason: 'unselected candidates are used before another request');
    await feed.loadMore();
    expect(http.asked, [1, 2, 3]);
    expect(ids(feed).last, 'BV6');
  });

  test('a half-unseen refresh searches for a full batch without padding repeats or recording exposure', () async {
    http.pages[1] = [feedItem('BV1'), feedItem('BV2')];
    seen(['BV1']);
    final feed = make();
    await feed.refresh();
    expect(ids(feed), ['BV2']);
    expect(http.asked, [1, 2]);
    expect(preferences.recentlySeen('BV2', accountMid: owner), isFalse);
  });

  test('repeats on two pages do not hide fresh videos further down', () async {
    http.pages[1] = [feedItem('BV1'), feedItem('BV2')];
    http.pages[2] = [feedItem('BV2'), feedItem('BV1')];
    http.pages[3] = [feedItem('BV3')];
    seen(['BV1', 'BV2']);
    final feed = make();
    await feed.refresh();
    expect(ids(feed), ['BV3']);
    expect(http.asked, [1, 2, 3, 4]);
    expect(feed.error, isNull);
  });

  test('an unavailable extra page preserves the first batch and its next-page retry', () async {
    http.pages[1] = [feedItem('BV1'), feedItem('BVfresh')];
    http.failing.add(2);
    seen(['BV1']);
    final feed = make();
    expect(await feed.refresh(), isNull);
    expect(ids(feed), ['BVfresh']);
    expect(feed.error, isNull);
    http.failing.clear();
    http.pages[2] = [feedItem('BV2')];
    await feed.loadMore();
    expect(http.asked, [1, 2, 2]);
    expect(ids(feed), ['BVfresh', 'BV2']);
  });

  test('a slow optional page times out without losing the successful first batch', () {
    fakeAsync((async) {
      http.pages[1] = [feedItem('BV1'), feedItem('BVfresh')];
      http.pages[2] = [feedItem('BV2')];
      http.gates[2] = Completer<void>();
      seen(['BV1']);
      final feed = make();
      var finished = false;
      unawaited(feed.refresh().then((_) => finished = true));
      async.flushMicrotasks();
      expect(http.asked, [1, 2]);
      expect(finished, isFalse);
      async.elapse(FeedModel.extraPageTimeout);
      async.flushMicrotasks();
      expect(finished, isTrue);
      expect(ids(feed), ['BVfresh']);
      http.gates[2]!.complete();
      async.flushMicrotasks();
      expect(ids(feed), ['BVfresh'], reason: 'the late optional response cannot alter the accepted batch');
    });
  });

  test('the official extra page stays official and advances its own cursor', () async {
    http.officialPages[0] = [officialItem('BV1')];
    http.officialPages[1] = [officialItem('BV2')];
    http.officialPages[2] = [officialItem('BV3')];
    seen(['BV1']);
    final feed = make(official: true);
    await feed.refresh();
    expect(ids(feed), ['BV2']);
    expect(http.officialAsked, [0, 1]);
    expect(http.asked, isEmpty);
    await feed.loadMore();
    expect(http.officialAsked, [0, 1, 2]);
    expect(ids(feed), ['BV2', 'BV3']);
  });

  test('a refused optional official page never starts a web fallback', () async {
    http.officialPages[0] = [officialItem('BV1'), officialItem('BVfresh')];
    http.officialGates[1] = Completer<void>();
    seen(['BV1']);
    final feed = make(official: true);
    final refreshing = feed.refresh();
    await pumpEventQueue();
    expect(http.officialAsked, [0, 1]);
    http.officialCode = -101;
    http.officialGates[1]!.complete();
    await refreshing;
    expect(ids(feed), ['BVfresh']);
    expect(http.asked, isEmpty);
    expect(feed.error, isNull);
  });

  test('a refused first official page can use the web source for its one extra page', () async {
    http.officialCode = -101;
    http.pages[1] = [feedItem('BV1')];
    http.pages[2] = [feedItem('BV2')];
    seen(['BV1']);
    final feed = make(official: true);
    await feed.refresh();
    expect(http.officialAsked, [0]);
    expect(http.asked, [1, 2]);
    expect(ids(feed), ['BV2']);
    expect(feed.source, FeedSource.web);
  });

  test('an account owner changed during a fetch prevents extra calls and late display', () async {
    http.pages[1] = [feedItem('BV1')];
    http.gates[1] = Completer<void>();
    seen(['BV1']);
    final feed = make();
    final refreshing = feed.refresh();
    await pumpEventQueue();
    owner = 8;
    http.gates[1]!.complete();
    await refreshing;
    expect(http.asked, [1]);
    expect(feed.cards, isEmpty);
    expect(feed.loading, isFalse);
    expect(feed.error, isNull);
  });

  test('a new session for the same owner cannot continue an old fetch', () async {
    http.pages[1] = [feedItem('BV1')];
    http.gates[1] = Completer<void>();
    seen(['BV1']);
    final feed = make();
    final refreshing = feed.refresh();
    await pumpEventQueue();
    client.invalidateSession();
    http.gates[1]!.complete();
    await refreshing;
    expect(http.asked, [1]);
    expect(feed.cards, isEmpty);
    expect(feed.loading, isFalse);
  });

  test('a refresh superseded during its optional page cannot display or retain its candidates', () async {
    http.pages[1] = [feedItem('BV1')];
    http.pages[2] = [feedItem('BV2')];
    http.gates[2] = Completer<void>();
    seen(['BV1']);
    final feed = make();
    final stale = feed.refresh();
    await pumpEventQueue();
    http.pages[1] = [feedItem('BV9')];
    await feed.refresh();
    http.gates[2]!.complete();
    await stale;
    expect(ids(feed), ['BV9']);
    http.gates.clear();
    http.pages[2] = [feedItem('BV10')];
    await feed.loadMore();
    expect(ids(feed), ['BV9', 'BV10']);
  });

  test('an armed pull shares its single optional fetch with the release', () async {
    http.pages[1] = [feedItem('BV1')];
    http.pages[2] = [feedItem('BV2')];
    http.gates[2] = Completer<void>();
    seen(['BV1']);
    final feed = make();
    feed.pullArmed();
    await pumpEventQueue();
    expect(http.asked, [1, 2]);
    expect(feed.cards, isEmpty);
    final release = feed.refresh(pulled: true);
    http.gates[2]!.complete();
    await release;
    expect(http.asked, [1, 2]);
    expect(ids(feed), ['BV2']);
    expect(preferences.recentlySeen('BV2', accountMid: owner), isFalse);
  });

  test('cancelling an armed pull does not publish its candidates or pending queue', () async {
    http.pages[1] = [feedItem('BV1')];
    http.pages[2] = [feedItem('BV2')];
    seen(['BV1']);
    final feed = make();
    feed.pullArmed();
    await pumpEventQueue();
    feed.pullDisarmed();
    expect(feed.cards, isEmpty);
    http.pages[1] = [feedItem('BV9')];
    await feed.refresh();
    expect(ids(feed), ['BV9']);
    http.pages[2] = [feedItem('BV10')];
    await feed.loadMore();
    expect(ids(feed), ['BV9', 'BV10']);
  });

  test('a pull armed while load more runs can join its own early page', () async {
    http.pages[1] = [feedItem('BV1')];
    final feed = make();
    await feed.refresh();
    http.pages[2] = [feedItem('BV2')];
    http.gates[2] = Completer<void>();
    final more = feed.loadMore();
    await pumpEventQueue();
    http.pages[1] = [feedItem('BV9')];
    feed.pullArmed();
    await pumpEventQueue();
    await feed.refresh(pulled: true);
    http.gates[2]!.complete();
    await more;
    expect(ids(feed), ['BV9', 'BV1']);
    expect(http.asked, [1, 2, 1]);
    expect(feed.loading, isFalse);
  });

  test('refresh metrics count overlap rather than calling resurfaced cards new', () async {
    http.pages[1] = [feedItem('BV1'), feedItem('BV2')];
    final feed = make();
    await feed.refresh();
    http.pages[1] = [feedItem('BV2'), feedItem('BV3')];
    await feed.refresh();
    final line = logs.events.lastWhere((event) => event.msg == 'feed page');
    expect(line.f['new']?.toJson(), 1);
    expect(line.f['overlap']?.toJson(), 1);
    expect(line.f['uploaders']?.toJson(), 1);
    expect(line.f.values.map((value) => value.toJson()), isNot(contains('BV2')));
  });
}
