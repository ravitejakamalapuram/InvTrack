// A11 (#755): the FIRE screen's inputs come from the converted portfolio
// snapshot (A13) and the current values of open investments (A10), and FIRE
// amounts are converted from the currency they were entered in (GAP2-01).
// Today is pinned to 2026-10-02.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

import '../../../../mocks/mock_currency_conversion_service.dart';

InvestmentEntity _inv(String id, InvestmentType type) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
  currency: 'INR',
);

CashFlowEntity _cf(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date,
) => CashFlowEntity(
  id: '$investmentId-${date.toIso8601String()}-${type.name}',
  investmentId: investmentId,
  date: date,
  type: type,
  amount: amount,
  createdAt: date,
  currency: 'INR',
);

/// ₹10L FD renewed every April at 7% since 2020 (six INVEST flows,
/// ₹71,53,290.74 in total; ₹14,02,551.73 invested today).
final _rolloverFlows = () {
  final flows = <CashFlowEntity>[];
  var principal = 1000000.0;
  flows.add(_cf('fd', CashFlowType.invest, principal, DateTime(2020, 4, 1)));
  for (var year = 2021; year <= 2025; year++) {
    final date = DateTime(year, 4, 1);
    final interest = principal * 0.07;
    flows
      ..add(_cf('fd', CashFlowType.returnFlow, principal, date))
      ..add(_cf('fd', CashFlowType.income, interest, date))
      ..add(_cf('fd', CashFlowType.invest, principal + interest, date));
    principal += interest;
  }
  return flows;
}();

FireSettingsEntity _settings({
  String? currency = 'INR',
  double otherAssets = 0,
  double? monthlySip,
}) => FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: 1996,
  targetFireAge: 45,
  isSetupComplete: true,
  currency: currency,
  otherAssets: otherAssets,
  monthlySip: monthlySip,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ProviderContainer _container({
  required FireSettingsEntity settings,
  List<InvestmentEntity> investments = const [],
  List<CashFlowEntity> cashFlows = const [],
  String baseCurrency = 'INR',
  CurrencyConversionService? conversion,
}) {
  final container = ProviderContainer(
    overrides: [
      fireSettingsProvider.overrideWith((ref) => Stream.value(settings)),
      valuationDateProvider.overrideWithValue(DateTime(2026, 10, 2)),
      allInvestmentsProvider.overrideWith((ref) => Stream.value(investments)),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(cashFlows)),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
      currencyCodeProvider.overrideWith((ref) => baseCurrency),
      currencyConversionServiceProvider.overrideWithValue(
        conversion ?? MockCurrencyConversionService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<FireCalculationResult> _calculation(ProviderContainer container) async {
  final sub = container.listen(fireCalculationProvider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 100; i++) {
    final value = sub.read();
    if (value.hasError) throw value.error!;
    if (value.hasValue && !value.isLoading) return value.requireValue;
    await Future<void>.delayed(Duration.zero);
  }
  fail('FIRE calculation did not resolve');
}

void main() {
  test('rollover FD: corpus ₹14,02,552, progress 7.66%, behind', () async {
    final container = _container(
      settings: _settings(),
      investments: [_inv('fd', InvestmentType.fixedDeposit)],
      cashFlows: _rolloverFlows,
    );

    final result = await _calculation(container);

    // The app showed ₹71.5L, 39.1% and 'on track'.
    expect(result.currentPortfolioValue, closeTo(1402551.73, 0.005));
    expect(result.progressPercentage, closeTo(7.664217, 1e-6));
    expect(result.status, FireProgressStatus.behind);
    expect(result.inputs?.investmentsValue, closeTo(1402551.73, 0.005));
    expect(result.inputs?.savingsSource, MonthlySavingsSource.history);
    expect(result.currentMonthlySavingsRate, 0);
  });

  test('two INVEST flows 10 days apart show not enough history', () async {
    final container = _container(
      settings: _settings(),
      investments: [_inv('p2p', InvestmentType.p2pLending)],
      cashFlows: [
        _cf('p2p', CashFlowType.invest, 500000, DateTime(2026, 9, 20)),
        _cf('p2p', CashFlowType.invest, 500000, DateTime(2026, 9, 30)),
      ],
    );

    final result = await _calculation(container);

    // The app estimated ₹30,00,000 a month and FIRE at 31.
    expect(result.currentMonthlySavingsRate, 0);
    expect(result.inputs?.savingsSource, MonthlySavingsSource.notEnoughHistory);
    expect(result.currentPortfolioValue, closeTo(1000000.00, 0.005));
  });

  test('a declared SIP and other assets are used', () async {
    final container = _container(
      settings: _settings(otherAssets: 500000, monthlySip: 25000),
      investments: [_inv('fd', InvestmentType.fixedDeposit)],
      cashFlows: _rolloverFlows,
    );

    final result = await _calculation(container);

    expect(result.currentPortfolioValue, closeTo(1902551.73, 0.005));
    expect(result.inputs?.otherAssets, closeTo(500000.00, 0.005));
    expect(result.currentMonthlySavingsRate, 25000);
    expect(result.inputs?.savingsSource, MonthlySavingsSource.declared);
  });

  test('INR settings under a USD base are converted, not read as dollars', () {
    final container = _container(
      settings: _settings(otherAssets: 830000),
      baseCurrency: 'USD',
    );

    return _calculation(container).then((result) {
      // ₹1,83,00,000 at 83 INR/USD; the app showed $18,300,000.
      expect(result.fireNumber, closeTo(220481.93, 0.005));
      expect(result.currentPortfolioValue, closeTo(10000.00, 0.005));
    });
  });

  test('settings with no currency are read in the base currency', () async {
    final container = _container(
      settings: _settings(currency: null),
      baseCurrency: 'USD',
    );

    final result = await _calculation(container);

    expect(result.fireNumber, closeTo(18300000.00, 0.005));
  });
}
