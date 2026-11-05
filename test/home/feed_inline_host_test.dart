import 'package:bilifast/home/feed_inline_player.dart';
import 'package:bilifast/video/pip_keeper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  @override
  Rect videoRect() => box;

  @override
  void inlinePlay() => playing = true;

  @override
  void inlinePause() => playing = false;
}
