import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';

void main() {
  testWidgets('StaggeredFadeIn works correctly for low indices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StaggeredFadeIn(index: 0, child: Text('Item 0'))),
    );

    // Initial state: opacity 0
    // Wait for delay (0 * 50 = 0ms) + small buffer
    await tester.pump(const Duration(milliseconds: 10));
    // Animation started?
    // Duration is 400ms.

    // Pump half way through animation
    await tester.pump(const Duration(milliseconds: 200));

    // Should be partially visible
    final opacityFinder = find.descendant(
      of: find.byType(StaggeredFadeIn),
      matching: find.byType(Opacity),
    );
    expect(opacityFinder, findsOneWidget);
    final Opacity opacity = tester.widget(opacityFinder);
    expect(opacity.opacity, greaterThan(0.0));
    expect(opacity.opacity, lessThan(1.0));

    // Pump to completion
    await tester.pump(const Duration(milliseconds: 300)); // Total 500ms
    final Opacity opacityEnd = tester.widget(opacityFinder);
    expect(opacityEnd.opacity, equals(1.0));
  });

  testWidgets('StaggeredFadeIn clamps delay for large indices (Performance Fix)', (
    tester,
  ) async {
    // This test verifies that items deep in the list (large index) do not wait
    // excessively long to appear.
    // Without optimization: index 100 * 50ms = 5000ms delay.
    // With optimization (cap at 5): 5 * 50ms = 250ms delay.

    await tester.pumpWidget(
      const MaterialApp(
        home: StaggeredFadeIn(index: 100, child: Text('Item 100')),
      ),
    );

    // Pump to trigger the delayed start.
    // Optimized delay is 250ms. Unoptimized is 5000ms.
    // Pumping 300ms should trigger the optimized timer but NOT the unoptimized one.
    await tester.pump(const Duration(milliseconds: 300));

    // Now pump to advance the animation (duration 400ms).
    await tester.pump(const Duration(milliseconds: 500));

    final opacityFinder = find.descendant(
      of: find.byType(StaggeredFadeIn),
      matching: find.byType(Opacity),
    );

    final Opacity opacity = tester.widget(opacityFinder);

    // Check expectation.
    // Before fix: Timer (5000ms) hasn't fired yet. Opacity 0.
    // After fix: Timer (250ms) fired at 300ms pump. Animation finished. Opacity 1.
    expect(
      opacity.opacity,
      equals(1.0),
      reason: 'Item 100 should be visible after < 1 second',
    );
  });
}
