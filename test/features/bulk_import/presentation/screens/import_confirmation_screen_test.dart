import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/import_confirmation_screen.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';

class _CapturingInvestmentNotifier extends InvestmentNotifier {
  List<InvestmentEntity> investments = [];
  List<CashFlowEntity> cashFlows = [];

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<({int investments, int cashFlows})> bulkImport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
  }) async {
    this.investments = investments;
    this.cashFlows = cashFlows;
    return (investments: investments.length, cashFlows: cashFlows.length);
  }
}

void main() {
  // A spreadsheet with no Currency column for the FD, plus one USD row.
  final parseResult = ParsedCsvResult(
    rows: [
      ParsedCashFlowRow(
        rowNumber: 2,
        date: DateTime(2024, 1, 15),
        investmentName: 'HDFC FD',
        type: CashFlowType.invest,
        amount: 100000,
      ),
      ParsedCashFlowRow(
        rowNumber: 3,
        date: DateTime(2024, 6, 15),
        investmentName: 'HDFC FD',
        type: CashFlowType.income,
        amount: 3500,
      ),
      ParsedCashFlowRow(
        rowNumber: 4,
        date: DateTime(2024, 2, 1),
        investmentName: 'US Treasury',
        type: CashFlowType.invest,
        amount: 1000,
        currency: 'USD',
      ),
    ],
    errors: const [],
    totalRows: 3,
    validRows: 3,
  );

  late _CapturingInvestmentNotifier notifier;

  Future<void> pumpScreen(WidgetTester tester) async {
    notifier = _CapturingInvestmentNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWithValue('INR'),
          investmentNotifierProvider.overrideWith(() => notifier),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ImportConfirmationScreen(
            parseResult: parseResult,
            fileName: 'portfolio.csv',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the resolved currency for every row', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('HDFC FD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('US Treasury'));
    await tester.pumpAndSettle();

    // Rows with no currency show the base currency, never USD.
    final inrRows = find.widgetWithText(ListTile, 'INR');
    final usdRows = find.widgetWithText(ListTile, 'USD');
    expect(inrRows, findsNWidgets(2));
    expect(usdRows, findsOneWidget);

    // Each row amount is formatted in its own currency.
    expect(
      find.descendant(of: usdRows, matching: find.textContaining('\$')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inrRows, matching: find.textContaining('₹')),
      findsNWidgets(2),
    );
  });

  testWidgets('imports with the resolved currency on flows and investments', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Import All'));
    await tester.pumpAndSettle();

    final byName = {for (final i in notifier.investments) i.name: i};
    expect(byName['HDFC FD']!.currency, 'INR');
    expect(byName['US Treasury']!.currency, 'USD');

    final flowCurrencies = {
      for (final cf in notifier.cashFlows) cf.amount: cf.currency,
    };
    expect(flowCurrencies, {100000.0: 'INR', 3500.0: 'INR', 1000.0: 'USD'});
  });
}
