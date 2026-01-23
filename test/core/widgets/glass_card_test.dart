import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard with blur: 0 has invisible shadows (unoptimized)', (tester) async {
    // Build GlassCard with blur: 0 (list mode)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassCard(
            blur: 0,
            child: const Text('Test'),
          ),
        ),
      ),
    );

    // Find the container that holds the decoration
    final containerFinder = find.descendant(
      of: find.byType(GlassCard),
      matching: find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration),
    );

    // Verify we found at least one container
    expect(containerFinder, findsWidgets);

    final containers = tester.widgetList<Container>(containerFinder);
    BoxDecoration? decoration;

    // Look for the container that matches the GlassCard structure.
    for (final container in containers) {
       if (container.decoration is BoxDecoration) {
         decoration = container.decoration as BoxDecoration;
         break;
       }
    }

    // OPTIMIZED STATE ASSERTION:
    // The decoration should exist (for color/border), but shadows must be empty/null.
    expect(decoration, isNotNull);
    expect(decoration!.boxShadow, anyOf(isNull, isEmpty), reason: 'Shadows should be removed for performance');
  });
}
