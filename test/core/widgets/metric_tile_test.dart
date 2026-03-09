import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/metric_tile.dart';

void main() {
  group('MetricTile Semantics', () {
    testWidgets('constructs semantic label with trend information', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              label: 'Total Return',
              value: '₹50,000',
              change: '5%',
              isPositive: true,
              onTap: () {},
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(MetricTile)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Total Return: ₹50,000, Trending up 5%',
        ),
      );
      handle.dispose();
    });

    testWidgets('handles negative trend semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              label: 'Loss',
              value: '₹1,000',
              change: '1%',
              isPositive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(MetricTile)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Loss: ₹1,000, Trending down 1%',
        ),
      );
      handle.dispose();
    });

    testWidgets('uses default semantics when change is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(label: 'Balance', value: '₹10,000', onTap: () {}),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(MetricTile)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Balance: ₹10,000',
        ),
      );
      handle.dispose();
    });

    testWidgets('is not a button when onTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricTile(label: 'Static Balance', value: '₹10,000'),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(MetricTile)),
        matchesSemantics(
          label: 'Static Balance: ₹10,000',
          // Implicitly verifies isButton is false (or at least doesn't check for it being true)
          // But to be stricter:
          isButton: false,
        ),
      );
      handle.dispose();
    });
  });
}
