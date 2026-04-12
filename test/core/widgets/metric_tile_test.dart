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

  group('HeroMetric Semantics', () {
    testWidgets('constructs semantic label with label and value only', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroMetric(label: 'Portfolio Value', value: '₹1,00,000'),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(HeroMetric)),
        matchesSemantics(label: 'Portfolio Value: ₹1,00,000'),
      );
      handle.dispose();
    });

    testWidgets('includes subtitle in semantic label when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroMetric(
              label: 'Total Returns',
              value: '₹50,000',
              subtitle: '+5.2% this year',
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(HeroMetric)),
        matchesSemantics(label: 'Total Returns: ₹50,000, +5.2% this year'),
      );
      handle.dispose();
    });

    testWidgets('omits subtitle from semantic label when subtitle is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroMetric(label: 'Net P&L', value: '-₹2,000'),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      final semantics = tester.getSemantics(find.byType(HeroMetric));
      expect(semantics.label, 'Net P&L: -₹2,000');
      expect(semantics.label, isNot(contains(',')));
      handle.dispose();
    });

    testWidgets('excludeSemantics prevents child text widgets from being read', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroMetric(
              label: 'XIRR',
              value: '12.4%',
              subtitle: 'annualised',
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      // The parent Semantics node with excludeSemantics:true should be the
      // only semantic node for this widget - child Text nodes should not
      // appear as separate semantic nodes under HeroMetric.
      final heroNode = tester.getSemantics(find.byType(HeroMetric));
      expect(heroNode.label, 'XIRR: 12.4%, annualised');
      // Child Text widgets should NOT produce additional semantic children
      // when excludeSemantics is true.
      expect(heroNode.children, isEmpty);
      handle.dispose();
    });

    testWidgets('renders label and value text visually', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroMetric(label: 'MOIC', value: '2.5x'),
          ),
        ),
      );

      expect(find.text('MOIC'), findsOneWidget);
      expect(find.text('2.5x'), findsOneWidget);
    });

    testWidgets('renders subtitle text visually when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroMetric(
              label: 'Balance',
              value: '₹10,000',
              subtitle: 'as of today',
            ),
          ),
        ),
      );

      expect(find.text('as of today'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroMetric(label: 'Balance', value: '₹10,000'),
          ),
        ),
      );

      // Only label and value should be rendered as Text
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('₹10,000'), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeroMetric(
              label: 'Status',
              value: 'Open',
              trailing: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('semantic label is correct with trailing widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeroMetric(
              label: 'Invested',
              value: '₹5,00,000',
              trailing: const Icon(Icons.trending_up),
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(HeroMetric)),
        matchesSemantics(label: 'Invested: ₹5,00,000'),
      );
      handle.dispose();
    });
  });
}