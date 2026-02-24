import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';

void main() {
  testWidgets('StaggeredFadeIn should clamp delay for large indices to optimize scroll performance', (
    tester,
  ) async {
    // 1. Pump widget with large index (e.g., 50)
    // Default delay is 50ms. Uncapped delay would be 50 * 50 = 2500ms.
    // Old clamped delay (capped at 5) was 50 * 5 = 250ms.
    // OPTIMIZED delay (capped at 1) should be 50 * 1 = 50ms.
    await tester.pumpWidget(
      const MaterialApp(home: StaggeredFadeIn(index: 50, child: Text('Hello'))),
    );

    // 2. Initial state: Opacity 0
    expect(find.byType(Opacity), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.0);

    // 3. Advance time just enough to trigger the optimized delayed future (50ms)
    // We add a small buffer (10ms) to ensure the timer fires.
    // Total wait: 60ms.
    await tester.pump(const Duration(milliseconds: 60));

    // 4. Advance time to let animation progress significantly
    // Animation duration is 400ms.
    // If we wait another 100ms (total 160ms), the animation should be running.
    // If the old clamp (250ms) was in place, the animation would NOT have started yet (250ms > 160ms).
    await tester.pump(const Duration(milliseconds: 100));

    // 5. Verify opacity > 0
    final opacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;

    // With optimized clamping, animation starts at 50ms. At 160ms total, it's 110ms into the animation.
    // Without optimization (or with old 250ms clamp), it hasn't started.
    expect(
      opacity,
      greaterThan(0.0),
      reason: 'Animation should have started by 160ms for index 50, proving the optimization reduced latency',
    );
  });
}
