import 'package:bilifast/home/feed_inline_player.dart';
import 'package:bilifast/shared/theme.dart';
import 'package:bilifast/video/pip_keeper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scrolling retains the current visible player but never starts passing tiles', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final pip = PipKeeper();
    final host = FeedInlineHost(viewport: () => const Rect.fromLTWH(0, 0, 300, 300), pip: pip);
    addTearDown(() {
      host.dispose();
      pip.dispose();
    });
    final first = _Card(const Rect.fromLTWH(0, 0, 300, 300));
    final next = _Card(const Rect.fromLTWH(0, 300, 300, 300));
    host
      ..register(first)
      ..register(next)
      ..shown = true;
    await tester.pump();
    final context = tester.element(find.byType(SizedBox));
    host.onScroll(ScrollStartNotification(metrics: _metrics, context: context));
    first.box = const Rect.fromLTWH(0, -160, 300, 300);
    next.box = const Rect.fromLTWH(0, 140, 300, 300);
    host.settleSoon();
    await tester.pump();
    expect(first.playing, isTrue, reason: 'small movements do not interrupt an existing player');
    expect(next.plays, 0, reason: 'no handoff while scrolling');
    first.box = const Rect.fromLTWH(0, -200, 300, 300);
    host.settleSoon();
    await tester.pump(const Duration(seconds: 2));
    expect(first.playing, isFalse);
    expect(next.plays, 0, reason: 'a long drag or fling is still scrolling');
    host.onScroll(ScrollEndNotification(metrics: _metrics, context: context));
    await tester.pump(FeedBigCardTheme.autoplayAfterScroll - const Duration(milliseconds: 1));
    expect(next.plays, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(next.playing, isTrue);
  });

  testWidgets('another swipe cancels the idle wait and only the final tile starts', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final pip = PipKeeper();
    final host = FeedInlineHost(viewport: () => const Rect.fromLTWH(0, 0, 300, 300), pip: pip);
    addTearDown(() {
      host.dispose();
      pip.dispose();
    });
    final first = _Card(const Rect.fromLTWH(0, -300, 300, 300));
    final next = _Card(const Rect.fromLTWH(0, 0, 300, 300));
    final context = tester.element(find.byType(SizedBox));
    host.onScroll(ScrollStartNotification(metrics: _metrics, context: context));
    host
      ..register(first)
      ..register(next)
      ..shown = true;
    await tester.pump();
    host.onScroll(ScrollEndNotification(metrics: _metrics, context: context));
    await tester.pump(const Duration(milliseconds: 200));
    host.onScroll(ScrollStartNotification(metrics: _metrics, context: context));
    await tester.pump(const Duration(seconds: 1));
    expect(next.plays, 0);
    first.box = const Rect.fromLTWH(0, 0, 300, 300);
    next.box = const Rect.fromLTWH(0, 300, 300, 300);
    host.onScroll(ScrollEndNotification(metrics: _metrics, context: context));
    await tester.pump(FeedBigCardTheme.autoplayAfterScroll);
    expect(first.playing, isTrue);
    expect(next.plays, 0);
  });

  testWidgets('idle callbacks cannot start hidden, backgrounded or disposed hosts', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final pip = PipKeeper();
    final host = FeedInlineHost(viewport: () => const Rect.fromLTWH(0, 0, 300, 300), pip: pip);
    addTearDown(pip.dispose);
    final card = _Card(const Rect.fromLTWH(0, 0, 300, 300));
    final context = tester.element(find.byType(SizedBox));
    host.onScroll(ScrollStartNotification(metrics: _metrics, context: context));
    host
      ..register(card)
      ..shown = true;
    host.onScroll(ScrollEndNotification(metrics: _metrics, context: context));
    host.shown = false;
    await tester.pump(FeedBigCardTheme.autoplayAfterScroll);
    expect(card.plays, 0);
    host.onScroll(ScrollStartNotification(metrics: _metrics, context: context));
    host.shown = true;
    host.onScroll(ScrollEndNotification(metrics: _metrics, context: context));
    host.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(FeedBigCardTheme.autoplayAfterScroll);
    expect(card.plays, 0);
    host.onScroll(ScrollStartNotification(metrics: _metrics, context: context));
    host.onScroll(ScrollEndNotification(metrics: _metrics, context: context));
    host.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(card.plays, 0);
  });

  testWidgets('scrolling back does not resume until idle; nested scroll notifications leave focus alone', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final pip = PipKeeper();
    final host = FeedInlineHost(viewport: () => const Rect.fromLTWH(0, 0, 300, 300), pip: pip);
    addTearDown(() {
      host.dispose();
      pip.dispose();
    });
    final card = _Card(const Rect.fromLTWH(0, 0, 300, 300));
    host
      ..register(card)
      ..shown = true;
    await tester.pump();
    final context = tester.element(find.byType(SizedBox));
    host.onScroll(ScrollStartNotification(metrics: _metrics, context: context));
    card.box = const Rect.fromLTWH(0, -300, 300, 300);
    host.settleSoon();
    await tester.pump();
    expect(card.playing, isFalse);
    card.box = const Rect.fromLTWH(0, 0, 300, 300);
    host.settleSoon();
    await tester.pump(const Duration(seconds: 1));
    expect(card.playing, isFalse, reason: 'returning during a drag cannot resume a paused player');
    host.onScroll(ScrollEndNotification(metrics: _metrics, context: context));
    await tester.pump(FeedBigCardTheme.autoplayAfterScroll);
    expect(card.playing, isTrue);
    host.onScroll(_NestedScrollStart(metrics: _metrics, context: context));
    card.box = const Rect.fromLTWH(0, -300, 300, 300);
    host.settleSoon();
    await tester.pump();
    card.box = const Rect.fromLTWH(0, 0, 300, 300);
    host.settleSoon();
    await tester.pump();
    expect(card.playing, isTrue, reason: 'a nested scroll must not block the outer host');
  });

  testWidgets('equally visible tiles focus the upper video regardless of registration order', (tester) async {
    final pip = PipKeeper();
    final host = FeedInlineHost(viewport: () => const Rect.fromLTWH(0, 0, 300, 600), pip: pip);
    addTearDown(() {
      host.dispose();
      pip.dispose();
    });
    final upper = _Card(const Rect.fromLTWH(0, 0, 300, 250));
    final lower = _Card(const Rect.fromLTWH(0, 300, 300, 250));
    host
      ..register(lower)
      ..register(upper)
      ..shown = true;
    await tester.pump();
    expect(upper.playing, isTrue);
    expect(lower.playing, isFalse);
  });

  testWidgets('focus uses the visible video area, retaining above one third and pausing at the boundary', (
    tester,
  ) async {
    final pip = PipKeeper();
    final host = FeedInlineHost(viewport: () => const Rect.fromLTWH(0, 0, 300, 300), pip: pip);
    addTearDown(() {
      host.dispose();
      pip.dispose();
    });
    final card = _Card(const Rect.fromLTWH(0, 0, 300, 300));
    host
      ..register(card)
      ..shown = true;
    await tester.pump();
    expect(card.playing, isTrue);

    for (final offset in [const Offset(0, -199), const Offset(0, 199), const Offset(-199, 0)]) {
      card.box = offset & const Size(300, 300);
      host.settle();
      expect(card.playing, isTrue, reason: 'more than one third visible');
    }
    card.box = const Rect.fromLTWH(-200, 0, 300, 300);
    host.settle();
    expect(card.playing, isFalse, reason: 'exactly two thirds outside the viewport');
    card.box = const Rect.fromLTWH(0, -199, 300, 300);
    host.settle();
    expect(card.playing, isFalse, reason: 'regaining focus requires half visible');
    card.box = const Rect.fromLTWH(0, -150, 300, 300);
    host.settle();
    expect(card.playing, isTrue);
    card.box = const Rect.fromLTWH(0, -200, 300, 300);
    host.settle();
    expect(card.playing, isFalse);
    card.box = const Rect.fromLTWH(0, 0, 300, 300);
    host.settle();
    expect(card.playing, isTrue);
    card.box = const Rect.fromLTWH(0, 200, 300, 300);
    host.settle();
    expect(card.playing, isFalse);
  });
}

class _Card implements FeedInlineCard {
  _Card(this.box);

  Rect box;
  bool playing = false;
  int plays = 0;

  @override
  Rect videoRect() => box;

  @override
  void inlinePlay() {
    playing = true;
    plays++;
  }

  @override
  void inlinePause() => playing = false;
}

final _metrics = FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: 2000,
  pixels: 0,
  viewportDimension: 300,
  axisDirection: AxisDirection.down,
  devicePixelRatio: 1,
);

class _NestedScrollStart extends ScrollStartNotification {
  _NestedScrollStart({required super.metrics, required super.context});

  @override
  int get depth => 1;
}
