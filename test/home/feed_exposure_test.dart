import 'package:bilifast/home/feed_exposure.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('only continuous half-visible foreground exposure counts', (tester) async {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    var area = const Rect.fromLTWH(0, 0, 100, 100);
    var active = true;
    var seen = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: FeedExposure(
          viewport: () => area,
          visibilityChanges: changes,
          isActive: () => active,
          onSeen: () => seen++,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 900));
    expect(seen, 0);
    area = const Rect.fromLTWH(0, 0, 49, 100);
    changes.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(seen, 0);
    area = const Rect.fromLTWH(0, 0, 50, 100);
    changes.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(seen, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(seen, 1, reason: 'one signal per uninterrupted exposure');
    active = false;
    changes.notifyListeners();
    await tester.pump();
    active = true;
    changes.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    expect(seen, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(seen, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offscreen lazy children and disposed exposures record nothing', (tester) async {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);
    var seen = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: FeedExposure(
        viewport: () => const Rect.fromLTWH(0, -500, 100, 100),
        visibilityChanges: changes,
        onSeen: () => seen++,
        child: const SizedBox(width: 100, height: 100),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(seen, 0);
    await tester.pumpWidget(const SizedBox());
    changes.notifyListeners();
    await tester.pump(const Duration(seconds: 2));
    expect(seen, 0);
  });
}
