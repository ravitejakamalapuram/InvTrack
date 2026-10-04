// A21 / ANLY-09: the Year over Year card compares the same days of each
// financial year and shows invested, received and net separately. Investing
// more is not shown as a red decline.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_analytics.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _PrivacyOff extends PrivacyModeNotifier {
  @override
  bool build() => false;
}

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

Future<void> _pump(WidgetTester tester, List<CashFlowEntity> flows) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        privacyModeProvider.overrideWith(_PrivacyOff.new),
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
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Net cash flow'), findsOneWidget);
    expect(
      find.text('Received +20.0% vs the same days last year'),
      findsOneWidget,
    );

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
      find.text('Received -25.0% vs the same days last year'),
      findsOneWidget,
    );
    final redTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.color == AppColors.errorLight);
    expect(redTexts, isEmpty);
  });
}
