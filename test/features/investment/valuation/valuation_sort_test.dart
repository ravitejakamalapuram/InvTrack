// #941 (plan test 25): an investment with limited history has no known return
// percent, so the return-percent sort puts it last in both directions; it is
// never ranked as 0%.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';

import '../../../mocks/mock_currency_conversion_service.dart';
import 'valuation_fixtures.dart';

final _today = DateTime(2026, 10, 2);

Future<List<String>> _sortedIds(InvestmentSort sort) async {
  final investments = [
    // +20% and -10%, both closed; and a baseline with no cash flows.
    testInvestment('gain', status: InvestmentStatus.closed),
    testInvestment('loss', status: InvestmentStatus.closed),
    testInvestment('limited'),
  ];
  final flows = [
    testFlow('gain', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
    testFlow('gain', CashFlowType.returnFlow, 120000, DateTime(2026, 10, 1)),
    testFlow('loss', CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
    testFlow('loss', CashFlowType.returnFlow, 90000, DateTime(2026, 10, 1)),
  ];
  final baseline = testSnapshot(
    'b',
    investmentId: 'limited',
    amount: 500000,
    date: _today,
    kind: ValuationKind.marketValue,
    provenance: ValuationProvenance.openingBaseline,
  );
  final container = ProviderContainer(
    overrides: [
      valuationDateProvider.overrideWithValue(_today),
      valuationSnapshotsActiveProvider.overrideWithValue(true),
      allValuationSnapshotsProvider.overrideWith(
        (ref) => Stream.value([baseline]),
      ),
      isAuthenticatedProvider.overrideWith((ref) => true),
      allInvestmentsProvider.overrideWith((ref) => Stream.value(investments)),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value([])),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(flows)),
      for (final inv in investments)
        cashFlowsByInvestmentProvider(inv.id).overrideWith(
          (ref) => Stream.value([
            for (final cf in flows)
              if (cf.investmentId == inv.id) cf,
          ]),
        ),
      currencyCodeProvider.overrideWith((ref) => 'INR'),
      currencyConversionServiceProvider.overrideWith(
        (ref) => MockCurrencyConversionService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(filteredInvestmentsProvider, (_, _) {});
  addTearDown(sub.close);
  container.read(investmentListStateProvider.notifier).setSort(sort);
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return [for (final inv in sub.read().requireValue) inv.id];
}

void main() {
  test('return percent, highest first: unknown returns are last', () async {
    expect(await _sortedIds(InvestmentSort.returnPercentDesc), [
      'gain',
      'loss',
      'limited',
    ]);
  });

  test('return percent, lowest first: unknown returns are last', () async {
    expect(await _sortedIds(InvestmentSort.returnPercentAsc), [
      'loss',
      'gain',
      'limited',
    ]);
  });
}
