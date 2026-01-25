import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';

void main() {
  testWidgets('StaggeredFadeIn limits delay for high index (optimization)', (
    tester,
  ) async {
    // Index 20 -> Should have 0 delay (optimization threshold is 15)
    await tester.pumpWidget(
      MaterialApp(
        home: StaggeredFadeIn(
          index: 20,
          child: Container(
            key: const Key('child'),
            width: 100,
            height: 100,
            color: Colors.red,
          ),
        ),
      ),
    );

    final opacityFinder = find.byType(Opacity);
    expect(opacityFinder, findsOneWidget);

    // Initial state: Opacity 0
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0.0);

    // Pump to trigger Future.delayed(0) callback
    await tester.pump(const Duration(milliseconds: 10));

    // Pump to advance animation
    await tester.pump(const Duration(milliseconds: 50));

    // Should be visible now because delay was skipped
    expect(tester.widget<Opacity>(opacityFinder).opacity, greaterThan(0.0));

    // Finish animation
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacityFinder).opacity, 1.0);
  });

  testWidgets('StaggeredFadeIn preserves delay for low index', (tester) async {
    // Index 2 -> 2 * 50ms = 100ms delay
    await tester.pumpWidget(
      MaterialApp(
        home: StaggeredFadeIn(
          index: 2,
          child: Container(width: 100, height: 100, color: Colors.blue),
        ),
      ),
    );

    final opacityFinder = find.byType(Opacity);

    // Pump 50ms (half delay)
    await tester.pump(const Duration(milliseconds: 50));
    // Should still be invisible (waiting for 100ms delay)
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0.0);

    // Pump past the delay (total 110ms)
    // This triggers the timer.
    await tester.pump(const Duration(milliseconds: 60));

    // Pump again to advance animation frame
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.widget<Opacity>(opacityFinder).opacity, greaterThan(0.0));
  });
}
