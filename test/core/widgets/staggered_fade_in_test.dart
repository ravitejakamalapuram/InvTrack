import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';

void main() {
  testWidgets('StaggeredFadeIn should clamp delay for large indices', (
    tester,
  ) async {
    // 1. Pump widget with large index (e.g., 50)
    // Default delay is 50ms. Uncapped delay would be 50 * 50 = 2500ms.
    // Clamped delay (capped at 5) would be 50 * 5 = 250ms.
    await tester.pumpWidget(
      const MaterialApp(home: StaggeredFadeIn(index: 50, child: Text('Hello'))),
    );

    // 2. Initial state: Opacity 0
    expect(find.byType(Opacity), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.0);

    // 3. Advance time to trigger the delayed future (250ms max delay)
    // We add a small buffer (10ms) to ensure the timer fires.
    await tester.pump(const Duration(milliseconds: 260));

    // 4. Advance time to let animation progress (e.g. 100ms into the 400ms duration)
    await tester.pump(const Duration(milliseconds: 100));

    // 5. Verify opacity > 0
    final opacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;

    // With clamping, animation starts at 250ms. At 360ms total, it's well under way.
    // Without clamping, animation starts at 2500ms. At 360ms, it hasn't started.
    expect(
      opacity,
      greaterThan(0.0),
      reason: 'Animation should have started by 360ms even for index 50',
    );
  });
}
