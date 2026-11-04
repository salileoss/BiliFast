import 'package:bili_core/devlog.dart';
import 'package:bilifast/account/keychain_store.dart';
import 'package:bilifast/app/app_environment.dart';
import 'package:bilifast/app/app_scope.dart';
import 'package:bilifast/home/avatar_page.dart';
import 'package:bilifast/home/recent_store.dart';
import 'package:bilifast/offline/fake_offline_library.dart';
import 'package:bilifast/offline/offline_models.dart';
import 'package:bilifast/offline/offline_size.dart';
import 'package:bilifast/offline/pages/downloading_page.dart';
import 'package:bilifast/offline/pages/offline_group_page.dart';
import 'package:bilifast/offline/pages/offline_list_page.dart';
import 'package:bilifast/offline/pages/offline_shelf.dart';
import 'package:bilifast/offline/pages/offline_text.dart';
import 'package:bilifast/skin/skin.dart';
import 'package:bilifast/video/fake_page_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/fake_keychain.dart';
import '../home/fake_login_gate.dart';
import '../me/me_page_support.dart';
import '../playback/fakes.dart';

const _mb = 1024 * 1024;
final _added = DateTime(2026, 10, 30, 17);
const _season = OfflineCollection(id: 7, title: '测试合集');

OfflineItem _part(
  int cid, {
  OfflineState state = OfflineState.done,
  String? title,
  String bvid = '',
  int page = 1,
  String? partTitle,
  OfflineCollection? collection,
  String owner = '测试UP',
  int minute = 0,
  int bytes = 10 * _mb,
  int total = 10 * _mb,
  OfflineFailure? failure,
}) => OfflineItem(
  request: OfflineRequest(
    bvid: bvid.isEmpty ? 'BV1part$cid' : bvid,
    aid: cid,
    cid: cid,
    title: title ?? '视频$cid',
    duration: 120,
    cover: '',
    ownerMid: cid,
    ownerName: owner,
    page: page,
    partTitle: partTitle,
    collection: collection,
  ),
  state: state,
  failure: failure,
  addedAt: _added.add(Duration(minutes: minute)),
  bytes: bytes,
  totalBytes: total,
);

/// A library whose 查看缓存 dot is up, as after a part was added.
class _UnseenLibrary extends FakeOfflineLibrary {
  _UnseenLibrary({super.items});

  bool _dot = true;

  @override
  bool get unseen => _dot;

  @override
  void markSeen() {
    _dot = false;
    super.markSeen();
  }
}

final _noSkin = ValueNotifier<Skin?>(null);

class _OtherAccountLibrary extends FakeOfflineLibrary {
  _OtherAccountLibrary({super.items});
  @override
  bool canResume(int cid) => false;
}

void main() {
  Future<AppServices> services(FakeOfflineLibrary offline, {bool loggedIn = true}) async {
    final logger = Logger(session: 'test');
    final environment = await AppEnvironment.load(
      keychain: FakeKeychain(const StoredCookies(Canned.cookies)),
      http: Canned.http(loggedIn: loggedIn),
      logger: logger,
    );
    await environment.refreshAccount();
    final playback = AppPlayback(() async => throw UnimplementedError());
    addTearDown(playback.dispose);
    return AppServices(
      environment: environment,
      playback: playback,
      recents: await RecentStore.load(null, logger: logger),
      loginGate: FakeLoginGate(),
      pageApi: FakePageApi(),
      offline: offline,
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> show(WidgetTester tester, FakeOfflineLibrary offline, Widget page, {bool loggedIn = true}) async {
    tester.view
      ..physicalSize = const Size(440, 956)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 62, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    final app = await services(offline, loggedIn: loggedIn);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppScope(services: app, child: child!),
        home: page,
      ),
    );
    await settle(tester);
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  group('the shelf', () {
    test('a 合集 and a multi-part video are one line each; other parts stand alone, newest first', () {
      final library = FakeOfflineLibrary(
        items: [
          _part(1, collection: _season, minute: 1),
          _part(2, collection: _season, minute: 5),
          _part(3, bvid: 'BV1multi', page: 2, partTitle: 'P2', minute: 2),
          _part(4, bvid: 'BV1multi', page: 1, partTitle: 'P1', minute: 3),
          _part(5, minute: 4),
          _part(6, bvid: 'BV1lone', page: 3, partTitle: '只缓存了这一P', minute: 6),
          _part(7, state: OfflineState.downloading, collection: _season, minute: 7),
          _part(8, state: OfflineState.waiting, minute: 0),
        ],
      );
      final shelf = OfflineShelf.of(library);
      expect(shelf.queued, [8, 7], reason: 'unfinished parts in the order they were queued');
      expect(shelf.done.map((entry) => entry.key), ['p6', 'c7', 'p5', 'vBV1multi']);
      final season = shelf.done[1] as GroupEntry;
      expect(season.title, '测试合集');
      expect(season.cids, [1, 2], reason: 'a 合集 lists its parts as they were added');
      final multi = shelf.done[3] as GroupEntry;
      expect(multi.cids, [4, 3], reason: 'a video lists its parts by number');
      expect(OfflineShelf.of(library), shelf, reason: 'the same parts make an equal shelf');
    });

    test('search finds finished parts by title, part title and uploader', () {
      final library = FakeOfflineLibrary(
        items: [
          _part(1, title: '星铁前瞻'),
          _part(2, partTitle: '第二集 星铁'),
          _part(3, owner: '星铁官方'),
          _part(4, title: '星铁直播', state: OfflineState.downloading),
          _part(5, title: '原神'),
        ],
      );
      expect(searchFinished(library, '星铁').toSet(), {1, 2, 3});
      expect(searchFinished(library, '  '), isEmpty);
    });

    test('sizes, clocks and states read as the shots do', () {
      expect(formatBytes(82208358), '78.4MB');
      expect(formatBytes((74.4 * 1024 * 1024 * 1024).round()), '74.4GB');
      expect(formatBytes(512 * 1024), '512KB');
      expect(offlineClock(383), '06:23');
      expect(offlineClock(3723), '1:02:03');
      expect(
        stateLabel(_part(1, state: OfflineState.downloading, bytes: 15 * _mb, total: 128 * _mb)),
        '缓存中: 15.0MB/128.0MB',
      );
      expect(stateLabel(_part(1, state: OfflineState.waiting)), '等待缓存');
      expect(stateLabel(_part(1, state: OfflineState.paused)), '已暂停');
      expect(stateLabel(_part(1, state: OfflineState.failed, failure: OfflineFailure.disk)), '空间不足，点击重试');
      expect(spaceLabel(59 * _mb, null), '已使用59.0MB / 剩余-');
    });
  });

  group('离线缓存', () {
    testWidgets('opening it clears 查看缓存\'s dot', (tester) async {
      final library = _UnseenLibrary(items: [_part(1)]);
      await show(tester, library, OfflineListPage(skin: _noSkin));
      expect(library.unseen, isFalse);
    });

    testWidgets('a finished part opens its page; a 合集 opens its own list', (tester) async {
      final opened = <int>[];
      final library = FakeOfflineLibrary(
        items: [
          _part(1, minute: 1),
          _part(2, collection: _season, minute: 2),
          _part(3, collection: _season, minute: 3),
        ],
      );
      await show(tester, library, OfflineListPage(skin: _noSkin, openItem: (context, item) => opened.add(item.cid)));
      await tester.tap(key('offline-row-1'));
      expect(opened, [1]);

      await tester.tap(key('offline-row-c7'));
      await settle(tester);
      expect(find.byType(OfflineGroupPage), findsOneWidget);
      expect(find.descendant(of: find.byType(OfflineGroupPage), matching: find.text('测试合集')), findsOneWidget);
      await tester.tap(key('offline-row-3'));
      expect(opened, [1, 3]);
    });

    testWidgets('a download\'s progress redraws its row, not the list', (tester) async {
      final library = FakeOfflineLibrary(
        items: [
          _part(1, state: OfflineState.downloading, bytes: 10 * _mb, total: 100 * _mb),
          _part(2),
        ],
      );
      await show(tester, library, OfflineListPage(skin: _noSkin));
      expect(find.text('缓存中: 10.0MB/100.0MB'), findsOneWidget);
      final done = tester.element(key('offline-entry-p2'));

      library.put(library.item(1)!.copyWith(bytes: 55 * _mb));
      await tester.pump();
      expect(find.text('缓存中: 55.0MB/100.0MB'), findsOneWidget);
      expect(tester.element(key('offline-entry-p2')), same(done));
    });

    testWidgets('正在缓存\'s row opens 正在缓存', (tester) async {
      final library = FakeOfflineLibrary(items: [_part(1, state: OfflineState.waiting)]);
      await show(tester, library, OfflineListPage(skin: _noSkin));
      expect(find.text('1个内容'), findsOneWidget);
      expect(key('offline-edit'), findsNothing, reason: '☰ waits for a finished part (143)');
      await tester.tap(key('offline-row-queue'));
      await settle(tester);
      expect(find.byType(DownloadingPage), findsOneWidget);
    });

    testWidgets('🔍 filters the finished parts as one types, and 取消 leaves', (tester) async {
      final library = FakeOfflineLibrary(
        items: [
          _part(1, title: '星铁前瞻', minute: 1),
          _part(2, title: '原神', minute: 2),
          _part(3, owner: '星铁官方'),
        ],
      );
      await show(tester, library, OfflineListPage(skin: _noSkin));
      await tester.tap(key('offline-search'));
      await settle(tester);
      expect(key('offline-search-blank'), findsOneWidget);

      await tester.enterText(key('offline-search-field'), '星铁');
      await settle(tester);
      expect(key('offline-result-1'), findsOneWidget);
      expect(key('offline-result-3'), findsOneWidget);
      expect(key('offline-result-2'), findsNothing);

      await tester.enterText(key('offline-search-field'), '不存在');
      await settle(tester);
      expect(find.text(OfflineListPage.noResults), findsOneWidget);

      await tester.tap(key('offline-search-cancel'));
      await settle(tester);
      expect(key('offline-search-bar'), findsNothing);
      expect(key('offline-row-2'), findsOneWidget);
    });

    testWidgets('☰ chooses rows and groups; 删除 asks first and 确认 deletes every part chosen', (tester) async {
      final library = FakeOfflineLibrary(
        items: [
          _part(1, minute: 1),
          _part(2, collection: _season, minute: 2),
          _part(3, collection: _season, minute: 3),
          _part(4, minute: 4),
        ],
      );
      await show(tester, library, OfflineListPage(skin: _noSkin));
      await tester.tap(key('offline-edit'));
      await settle(tester);
      expect(key('offline-done'), findsOneWidget);
      expect(key('offline-edit-bar'), findsOneWidget);

      await tester.tap(key('offline-delete'));
      await settle(tester);
      expect(key('offline-confirm'), findsNothing, reason: '删除 does nothing until something is chosen');

      await tester.tap(key('offline-row-c7'));
      await tester.tap(key('offline-row-1'));
      await settle(tester);
      await tester.tap(key('offline-delete'));
      await settle(tester);
      expect(find.text('确定要删除吗？'), findsOneWidget);

      await tester.tap(key('offline-confirm-取消'));
      await settle(tester);
      expect(key('offline-confirm'), findsNothing);
      expect(library.deleted, isEmpty);

      await tester.tap(key('offline-delete'));
      await settle(tester);
      await tester.tap(key('offline-confirm-确认'));
      await settle(tester);
      expect(library.deleted.toSet(), {1, 2, 3});
      expect(key('offline-edit-bar'), findsNothing, reason: 'deleting leaves edit mode');
      expect(key('offline-row-4'), findsOneWidget);
    });
  });

  group('正在缓存', () {
    testWidgets('a download belonging to another account explains how to resume', (tester) async {
      final library = _OtherAccountLibrary(items: [_part(1, state: OfflineState.paused)]);
      await show(tester, library, DownloadingPage(skin: _noSkin));
      await tester.tap(key('offline-row-1'));
      await tester.pump();
      expect(find.text(DownloadingPage.otherAccount), findsOneWidget);
      expect(library.item(1)!.state, OfflineState.paused);
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
    });

    List<OfflineItem> queue() => [
      _part(1, state: OfflineState.downloading, minute: 1, bytes: 5 * _mb, total: 50 * _mb),
      _part(2, state: OfflineState.waiting, minute: 2, bytes: 0),
      _part(3, state: OfflineState.paused, minute: 3, bytes: 0),
      _part(4, state: OfflineState.failed, failure: OfflineFailure.network, minute: 4, bytes: 0),
    ];

    testWidgets('a tap pauses a running part, starts a paused one and retries a failed one', (tester) async {
      final library = FakeOfflineLibrary(items: queue());
      await show(tester, library, DownloadingPage(skin: _noSkin));
      expect(find.text('缓存失败，点击重试'), findsOneWidget);

      await tester.tap(key('offline-row-1'));
      await tester.tap(key('offline-row-2'));
      await tester.tap(key('offline-row-3'));
      await tester.tap(key('offline-row-4'));
      await tester.pump();
      expect(library.item(1)!.state, OfflineState.paused);
      expect(library.item(2)!.state, OfflineState.paused);
      expect(library.item(3)!.state, OfflineState.waiting);
      expect(library.item(4)!.state, OfflineState.waiting);
    });

    testWidgets('全部暂停 pauses everything, then reads 全部开始 and starts it again', (tester) async {
      final library = FakeOfflineLibrary(items: queue());
      await show(tester, library, DownloadingPage(skin: _noSkin));
      expect(find.text('全部暂停'), findsOneWidget);

      await tester.tap(key('offline-all'));
      await tester.pump();
      expect([
        for (final cid in [1, 2, 3, 4]) library.item(cid)!.state,
      ], everyElement(OfflineState.paused));
      expect(find.text('全部开始'), findsOneWidget);

      await tester.tap(key('offline-all'));
      await tester.pump();
      expect([
        for (final cid in [1, 2, 3, 4]) library.item(cid)!.state,
      ], everyElement(OfflineState.waiting));
      expect(find.text('全部暂停'), findsOneWidget);
    });

    testWidgets('a 大会员 picks 3 at once from 同时缓存数量\'s sheet', (tester) async {
      final library = FakeOfflineLibrary(items: queue());
      await show(tester, library, DownloadingPage(skin: _noSkin));
      await tester.tap(key('offline-concurrency'));
      await settle(tester);
      expect(key('offline-concurrency-sheet'), findsOneWidget);
      expect(find.text('(大会员专享)'), findsNWidgets(2));

      await tester.tap(key('offline-concurrency-3'));
      await settle(tester);
      expect(library.concurrency, 3);
      expect(key('offline-concurrency-sheet'), findsNothing);
      expect(find.text('同时缓存数量：3'), findsOneWidget);
    });

    testWidgets('without 大会员, 2 and 3 only toast', (tester) async {
      final library = FakeOfflineLibrary(items: queue());
      await show(tester, library, DownloadingPage(skin: _noSkin), loggedIn: false);
      await tester.tap(key('offline-concurrency'));
      await settle(tester);
      await tester.tap(key('offline-concurrency-2'));
      await tester.pump();
      expect(library.concurrency, 1);
      expect(find.text(DownloadingPage.vipOnly), findsOneWidget);

      await tester.tap(key('offline-concurrency-1'));
      await settle(tester);
      expect(key('offline-concurrency-sheet'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('back closes the sheet, then the confirm, then edit mode', (tester) async {
      final library = FakeOfflineLibrary(items: queue());
      await show(tester, library, DownloadingPage(skin: _noSkin));
      await tester.tap(key('offline-concurrency'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(key('offline-concurrency-sheet'), findsNothing);

      await tester.tap(key('offline-edit'));
      await settle(tester);
      await tester.tap(key('offline-select-all'));
      await tester.pump();
      await tester.tap(key('offline-delete'));
      await settle(tester);
      expect(key('offline-confirm'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(key('offline-confirm'), findsNothing);
      expect(key('offline-edit-bar'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(key('offline-edit-bar'), findsNothing);
      expect(find.byType(DownloadingPage), findsOneWidget);
    });

    testWidgets('全选 chooses every part, and 确认 deletes them', (tester) async {
      final library = FakeOfflineLibrary(items: queue());
      await show(tester, library, DownloadingPage(skin: _noSkin));
      await tester.tap(key('offline-edit'));
      await settle(tester);
      await tester.tap(key('offline-select-all'));
      await tester.pump();
      await tester.tap(key('offline-delete'));
      await settle(tester);
      await tester.tap(key('offline-confirm-确认'));
      await settle(tester);
      expect(library.deleted.toSet(), {1, 2, 3, 4});
      expect(find.text(DownloadingPage.emptyMessage), findsOneWidget);
    });

    testWidgets('the controls answer accessibility presses', (tester) async {
      final semantics = tester.ensureSemantics();
      final library = FakeOfflineLibrary(items: queue());
      await show(tester, library, DownloadingPage(skin: _noSkin));
      tester.semantics.tap(find.semantics.byLabel('全部暂停'));
      await tester.pump();
      expect(library.item(1)!.state, OfflineState.paused);
      tester.semantics.tap(find.semantics.byLabel('同时缓存数量：1'));
      await settle(tester);
      tester.semantics.tap(find.semantics.byLabel('3个，大会员专享'));
      await settle(tester);
      expect(library.concurrency, 3);
      tester.semantics.tap(find.semantics.byLabel('编辑'));
      await settle(tester);
      tester.semantics.tap(find.semantics.byLabel('全选'));
      await tester.pump();
      tester.semantics.tap(find.semantics.byLabel('删除'));
      await settle(tester);
      tester.semantics.tap(find.semantics.byLabel('确认'));
      await settle(tester);
      expect(library.deleted.toSet(), {1, 2, 3, 4});
      semantics.dispose();
    });
  });

  testWidgets('a 合集\'s page closes once its last part is deleted', (tester) async {
    final library = FakeOfflineLibrary(
      items: [
        _part(2, collection: _season, minute: 2),
        _part(3, collection: _season, minute: 3),
      ],
    );
    await show(
      tester,
      library,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            key: const ValueKey('open'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OfflineGroupPage(group: const ShelfGroup.collection(7), title: '测试合集', skin: _noSkin),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(key('open'));
    await settle(tester);
    await library.delete([2, 3]);
    await tester.pumpAndSettle();
    expect(find.byType(OfflineGroupPage), findsNothing);
  });

  group('the shortcuts', () {
    testWidgets('我的\'s 离线缓存 opens it', (tester) async {
      await showMe(tester);
      await tester.tap(key('me-offline'));
      await settle(tester);
      expect(find.byType(OfflineListPage), findsOneWidget);
    });

    testWidgets('the avatar page\'s 离线缓存 opens it', (tester) async {
      await show(tester, FakeOfflineLibrary(), const AvatarPage(), loggedIn: false);
      await tester.tap(key('avatar-offline'));
      await settle(tester);
      expect(find.byType(OfflineListPage), findsOneWidget);
    });
  });
}
