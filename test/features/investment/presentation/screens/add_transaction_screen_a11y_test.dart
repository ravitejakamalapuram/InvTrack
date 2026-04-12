/// Accessibility tests for add_transaction_screen.dart
///
/// Covers the Semantics changes from this PR:
/// - The date picker Semantics label now includes the formatted date:
///   "Select transaction date, <formatted date>"
/// - excludeSemantics: true is set to suppress child widget semantics
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_transaction_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';

/// Mock InvestmentNotifier that does nothing — prevents Firebase access in tests.
class MockInvestmentNotifier extends InvestmentNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);
}

/// Helper: builds the AddTransactionScreen widget under test.
Widget buildTestWidget({
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      currencyCodeProvider.overrideWithValue('USD'),
      currencySymbolProvider.overrideWithValue('\$'),
      currencyLocaleProvider.overrideWithValue('en_US'),
      investmentNotifierProvider.overrideWith(MockInvestmentNotifier.new),
      analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
      ...extraOverrides,
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AddTransactionScreen(investmentId: 'test-investment-id'),
    ),
  );
}

void main() {
  testWidgets(
    'date picker Semantics has button flag and tap action',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find the Semantics widget that wraps the date picker GlassCard.
      // The label starts with "Select transaction date"
      final semanticsWidget = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith(
              'Select transaction date',
            ),
      );

      expect(
        semanticsWidget,
        findsOneWidget,
        reason: 'Semantics widget for date picker should exist',
      );

      final semanticsData = tester.getSemantics(semanticsWidget);

      // ignore: deprecated_member_use
      expect(
        semanticsData.hasFlag(SemanticsFlag.isButton),
        isTrue,
        reason: 'Date picker should have the button flag',
      );

      expect(
        semanticsData.hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'Date picker should be tappable',
      );
    },
  );

  testWidgets(
    'date picker Semantics label includes formatted date string',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The default selected date is DateTime.now().
      // We verify the label pattern rather than an exact date to avoid
      // flakiness across test runs.
      final semanticsWidget = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith(
              'Select transaction date, ',
            ),
      );

      expect(
        semanticsWidget,
        findsOneWidget,
        reason:
            'Semantics label should include "Select transaction date, <date>"',
      );

      // Verify the label ends with a non-empty date portion.
      final semantics = semanticsWidget.evaluate().first.widget as Semantics;
      final label = semantics.properties.label ?? '';
      final prefix = 'Select transaction date, ';
      expect(
        label.startsWith(prefix),
        isTrue,
        reason: 'Label should start with expected prefix',
      );
      final datePart = label.substring(prefix.length);
      expect(
        datePart,
        isNotEmpty,
        reason: 'Label should include non-empty formatted date',
      );
    },
  );

  testWidgets(
    'date picker Semantics label contains AppDateUtils.formatLong formatted date',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The widget initialises with DateTime.now(). Format it here for comparison.
      final now = DateTime.now();
      final expectedDatePart = AppDateUtils.formatLong(now);
      final expectedLabel = 'Select transaction date, $expectedDatePart';

      final semanticsWidget = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == expectedLabel,
      );

      expect(
        semanticsWidget,
        findsOneWidget,
        reason: 'Semantics label should equal "$expectedLabel"',
      );
    },
  );

  testWidgets(
    'date picker Semantics has excludeSemantics: true to suppress child semantics',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find the specific Semantics widget wrapping the date picker.
      final semanticsWidget = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith(
              'Select transaction date',
            ),
      );

      expect(semanticsWidget, findsOneWidget);

      final semanticsNode =
          semanticsWidget.evaluate().first.widget as Semantics;

      // excludeSemantics: true prevents child text from being announced twice
      // by screen readers (the label already conveys the date).
      expect(
        semanticsNode.excludeSemantics,
        isTrue,
        reason:
            'excludeSemantics should be true so children do not duplicate the label announcement',
      );
    },
  );

  testWidgets(
    'date picker Semantics label is accessible via bySemanticsLabel finder',
    (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final expectedLabel =
          'Select transaction date, ${AppDateUtils.formatLong(now)}';

      // Verify the label is discoverable by screen-reader-style semantic search
      expect(
        find.bySemanticsLabel(expectedLabel),
        findsOneWidget,
        reason:
            'The exact semantic label should be findable by accessibility tools',
      );
    },
  );
}