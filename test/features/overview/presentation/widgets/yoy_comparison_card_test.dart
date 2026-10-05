// A21 / ANLY-09: the Year over Year card compares the same days of each
// financial year and shows invested, returned, income and net separately.
// Investing more is not shown as a red decline, and principal coming back is
// not shown as income growth. Screen readers hear each amount with its row
// and year, and nothing but "Hidden amount" in privacy mode.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_analytics.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

class _PrivacyOn extends PrivacyModeNotifier {
  @override
  bool build() => true;
}

/// An amount as the card reads it to a screen reader.
String _spoken(double amount) =>
    AccessibilityUtils.formatCurrencyForScreenReader(
      amount,
      '₹',
      locale: 'en_IN',
    ).trim();

CashFlowEntity _flow(CashFlowType type, double amount, DateTime date) =>
    CashFlowEntity(
      id: '${type.name}-${date.toIso8601String()}',
      investmentId: 'inv',
      type: type,
      amount: amount,
      currency: 'INR',
      date: date,
      createdAt: date,
    );

Future<void> _pump(
  WidgetTester tester,
  List<CashFlowEntity> flows, {
  bool privacy = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        privacyModeProvider.overrideWith(
          privacy ? _PrivacyOn.new : _PrivacyOff.new,
        ),
        convertedCashFlowsProvider.overrideWithValue(AsyncValue.data(flows)),
        valuationDateProvider.overrideWithValue(DateTime(2026, 10, 4)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: YoYComparisonCard(
              currencyFormat: NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹',
                decimalDigits: 0,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('investing more this year is not shown as a red decline', (
    tester,
  ) async {
    // checks.py section 10: last year 6L in and 50k back, this year 9L in
    // and 60k back, over the same days of each financial year.
    await _pump(tester, [
      _flow(CashFlowType.invest, 600000, DateTime(2025, 5, 10)),
      _flow(CashFlowType.returnFlow, 50000, DateTime(2025, 8, 1)),
      _flow(CashFlowType.invest, 900000, DateTime(2026, 5, 10)),
      _flow(CashFlowType.returnFlow, 60000, DateTime(2026, 8, 1)),
    ]);

    expect(find.text('Year over Year'), findsOneWidget);
    expect(
      find.text(
        'Financial year to date (Apr 1 – Oct 4) vs the same days '
        'last year',
      ),
      findsOneWidget,
    );
    expect(find.text('FY 2025-26'), findsOneWidget);
    expect(find.text('FY 2026-27'), findsOneWidget);
    expect(find.text('Invested'), findsOneWidget);
    expect(find.text('Returned'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Net cash flow'), findsOneWidget);
    // No income in either year: no change to highlight.
    expect(find.textContaining('Income +'), findsNothing);

    // No "-53% vs last year" in red.
    expect(find.textContaining('vs last year'), findsNothing);
    expect(find.byIcon(Icons.trending_down), findsNothing);
    final redTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.color == AppColors.errorLight);
    expect(redTexts, isEmpty);
  });

  testWidgets('receiving less is shown as a neutral change, not in red', (
    tester,
  ) async {
    await _pump(tester, [
      _flow(CashFlowType.invest, 100000, DateTime(2025, 5, 10)),
      _flow(CashFlowType.income, 8000, DateTime(2025, 8, 1)),
      _flow(CashFlowType.income, 6000, DateTime(2026, 8, 1)),
    ]);

    expect(
      find.text('Income -25.0% vs the same days last year'),
      findsOneWidget,
    );
    final redTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.color == AppColors.errorLight);
    expect(redTexts, isEmpty);
  });

  testWidgets('a maturity highlights the change in income, not in money '
      'received', (tester) async {
    await _pump(tester, [
      _flow(CashFlowType.income, 6000, DateTime(2025, 8, 1)),
      _flow(CashFlowType.returnFlow, 100000, DateTime(2026, 8, 1)),
      _flow(CashFlowType.income, 7000, DateTime(2026, 8, 1)),
    ]);

    expect(
      find.text('Income +16.7% vs the same days last year'),
      findsOneWidget,
    );
    expect(find.textContaining('1683'), findsNothing);
  });

  testWidgets('each amount is read with its row and financial year', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [
      _flow(CashFlowType.invest, 600000, DateTime(2025, 5, 10)),
      _flow(CashFlowType.income, 50000, DateTime(2025, 8, 1)),
      _flow(CashFlowType.invest, 900000, DateTime(2026, 5, 10)),
      _flow(CashFlowType.income, 60000, DateTime(2026, 8, 1)),
    ]);

    expect(
      find.bySemanticsLabel(
        'Invested: FY 2025-26 ${_spoken(600000)}, '
        'FY 2026-27 ${_spoken(900000)}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Income: FY 2025-26 ${_spoken(50000)}, FY 2026-27 ${_spoken(60000)}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Net cash flow: FY 2025-26 ${_spoken(-550000)}, '
        'FY 2026-27 ${_spoken(-840000)}',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('privacy mode reads every amount as hidden', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [
      _flow(CashFlowType.invest, 600000, DateTime(2025, 5, 10)),
      _flow(CashFlowType.income, 50000, DateTime(2025, 8, 1)),
      _flow(CashFlowType.invest, 900000, DateTime(2026, 5, 10)),
      _flow(CashFlowType.income, 60000, DateTime(2026, 8, 1)),
    ], privacy: true);

    for (final row in ['Invested', 'Returned', 'Income', 'Net cash flow']) {
      expect(
        find.bySemanticsLabel(
          '$row: FY 2025-26 Hidden amount, FY 2026-27 Hidden amount',
        ),
        findsOneWidget,
      );
    }
    expect(find.bySemanticsLabel(RegExp('rupees')), findsNothing);
    // The change is faded out and not read either.
    expect(find.bySemanticsLabel(RegExp(r'Income \+')), findsNothing);
    semantics.dispose();
  });
}
