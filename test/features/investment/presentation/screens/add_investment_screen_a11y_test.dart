import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockAnalyticsService = MockAnalyticsService();
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(mockAnalyticsService),
      ],
      child: const MaterialApp(home: AddInvestmentScreen()),
    );
  }

  testWidgets('AddInvestmentScreen should have accessible tooltips', (
    tester,
  ) async {
    // Set surface size to avoid overflow issues as per memory guidelines
    await tester.binding.setSurfaceSize(const Size(800, 1200));

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // 1. Verify AppBar Close Button Tooltip
    final closeButtonFinder = find.byIcon(Icons.close_rounded);
    expect(closeButtonFinder, findsOneWidget);

    expect(
      find.byTooltip('Close'),
      findsOneWidget,
      reason: 'AppBar close button should have a tooltip',
    );
  });

  testWidgets(
    'Start Date picker clear button should have tooltip and accessible size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Find and tap "Start Date" (When did you invest?)
      final startDateFinder = find.text('When did you invest?').first;
      // With 1200 height, it should be visible or close to it.
      // Ensure visibility just in case
      await tester.ensureVisible(startDateFinder);
      await tester.pumpAndSettle();

      await tester.tap(startDateFinder);
      await tester.pumpAndSettle(); // Open dialog

      // Select a date (OK button confirms current selection)
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Verify tooltip
      expect(find.byTooltip('Clear start date'), findsOneWidget);
    },
  );

  testWidgets('Maturity Date picker clear button should have tooltip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Find and tap "Maturity Date"
    // It says "No maturity date set" initially
    final maturityDateFinder = find.text('No maturity date set').first;
    await tester.ensureVisible(maturityDateFinder);
    await tester.pumpAndSettle();

    await tester.tap(maturityDateFinder);
    await tester.pumpAndSettle(); // Open dialog

    // Select a date
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Check tooltip
    expect(find.byTooltip('Clear maturity date'), findsOneWidget);
  });
}
