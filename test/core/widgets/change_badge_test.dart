import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/change_badge.dart';

void main() {
  group('ChangeBadge', () {
    testWidgets('displays positive value with plus sign', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeBadge(value: 5.25),
          ),
        ),
      );

      expect(find.text('+5.25%'), findsOneWidget);
    });

    testWidgets('displays negative value without plus sign', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeBadge(value: -3.50),
          ),
        ),
      );

      expect(find.text('-3.50%'), findsOneWidget);
    });

    testWidgets('displays zero value without sign', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeBadge(value: 0),
          ),
        ),
      );

      expect(find.text('0.00%'), findsOneWidget);
    });

    testWidgets('shows upward icon for positive value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeBadge(value: 10, showIcon: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('shows downward icon for negative value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeBadge(value: -10, showIcon: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('hides icon when showIcon is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeBadge(value: 10, showIcon: false),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    });

    testWidgets('displays custom prefix', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeBadge(value: 5, prefix: 'XIRR: '),
          ),
        ),
      );

      expect(find.textContaining('XIRR:'), findsOneWidget);
    });

    testWidgets('displays custom suffix', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChangeBadge(value: 5, suffix: ' pts'),
          ),
        ),
      );

      expect(find.text('+5.00 pts'), findsOneWidget);
    });

    testWidgets('works with all sizes', (tester) async {
      for (final size in ChangeBadgeSize.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeBadge(value: 5, size: size),
            ),
          ),
        );

        expect(find.byType(ChangeBadge), findsOneWidget);
      }
    });
  });

  group('StatusBadge', () {
    testWidgets('displays label text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(label: 'Active', color: Colors.green),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders with outlined style', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(label: 'Test', color: Colors.blue, outlined: true),
          ),
        ),
      );

      expect(find.byType(StatusBadge), findsOneWidget);
    });
  });
}

