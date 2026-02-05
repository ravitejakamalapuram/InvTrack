import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/metric_tile.dart';

void main() {
  group('MetricTile Semantics', () {
    testWidgets('should provide cohesive semantics including trend direction', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              label: 'Total Return',
              value: '₹50,000',
              change: '10%',
              isPositive: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // Current behavior: The widget is likely composed of multiple semantic nodes
      // (Text: "Total Return", Text: "₹50,000", Text: "10%")
      // The icon for "up" is purely visual and ignored by default semantics.

      // Expected semantic label: "Total Return: ₹50,000. Trending up by 10%"
      final expectedLabel = 'Total Return: ₹50,000. Trending up by 10%';

      final metricTileFinder = find.byType(MetricTile);
      final semanticsNode = tester.getSemantics(metricTileFinder);
      final semanticsData = semanticsNode.getSemanticsData();

      expect(semanticsData.label, expectedLabel);
      expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);

      // Verify that individual text children are excluded from semantics
      // (The test environment might still find the Text widgets, but they should not expose semantics up)
      // Actually, since we wrapped with Semantics(excludeSemantics: true),
      // the children semantics should be merged or hidden.

      // Find by semantics label should return the single node
      expect(find.bySemanticsLabel(expectedLabel), findsOneWidget);
    });
  });
}
