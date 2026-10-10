// #941, owner decision of 2026-10-10 (option 1): a buy or a sale dated after
// the latest market value leaves the investment without a usable value. The
// screens that sum, rank or score investments all count it as missing until
// the user records a newer value.
//
// Gold, today 2026-10-10:
//   INVEST 1,00,000 on 2026-01-10, market value 1,10,000 on 2026-03-03,
//   INVEST 50,000 on 2026-06-05.
// The stale 1,10,000 is not used anywhere. What was put in (1,50,000) is.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/goal_progress_calculator.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';

import '../../../mocks/mock_currency_conversion_service.dart';
import 'valuation_fixtures.dart';

final _today = DateTime(2026, 10, 10);

final _gold = testInvestment('gold');
final _flows = [
  testFlow('gold', CashFlowType.invest, 100000, DateTime(2026, 1, 10)),
  testFlow('gold', CashFlowType.invest, 50000, DateTime(2026, 6, 5)),
];
final _market = testSnapshot(
  'm1',
  investmentId: 'gold',
  amount: 110000,
  date: DateTime(2026, 3, 3),
  kind: ValuationKind.marketValue,
);
final _newer = testSnapshot(
  'm2',
  investmentId: 'gold',
  amount: 175000,
  date: DateTime(2026, 6, 20),
  kind: ValuationKind.marketValue,
);

ProviderContainer _container(List<InvestmentValuationSnapshot> snapshots) {
  final container = ProviderContainer(
    overrides: [
      valuationDateProvider.overrideWithValue(_today),
      valuationSnapshotsActiveProvider.overrideWithValue(true),
      allValuationSnapshotsProvider.overrideWith(
        (ref) => Stream.value(snapshots),
      ),
      allInvestmentsProvider.overrideWith((ref) => Stream.value([_gold])),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(_flows)),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
      cashFlowsByInvestmentProvider(
        'gold',
      ).overrideWith((ref) => Stream.value(_flows)),
      currencyCodeProvider.overrideWith((ref) => 'INR'),
      currencyConversionServiceProvider.overrideWithValue(
        MockCurrencyConversionService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void _keep(ProviderContainer container, ProviderListenable<Object?> provider) {
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
}

/// Waits for an async value of a synchronous provider.
Future<T> _until<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  for (var i = 0; i < 100; i++) {
    final value = container.read(provider);
    if (value.hasError) throw value.error!;
    if (value.hasValue && !value.isLoading) return value.requireValue;
    await Future<void>.delayed(Duration.zero);
  }
  fail('provider did not resolve');
}

GoalEntity _goal() => GoalEntity(
  id: 'g',
  name: 'g',
  type: GoalType.targetAmount,
  targetAmount: 1000000,
  trackingMode: GoalTrackingMode.selected,
  linkedInvestmentIds: const ['gold'],
  icon: '🎯',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: 'INR',
);

void main() {
  group('portfolio totals, cards and XIRR', () {
    late ProviderContainer container;

    setUp(() => container = _container([_market]));

    test('the overview counts it as missing and shows no value', () async {
      _keep(container, multiCurrencyGlobalStatsProvider);
      final global = await container.read(
        multiCurrencyGlobalStatsProvider.future,
      );
      expect(global.currentValue, isNull);
      expect(global.missingValueCount, 1);
      expect(global.needsCurrentValue, isTrue);
      expect(global.totalInvested, 150000);

      _keep(container, multiCurrencyOpenStatsProvider);
      final open = await container.read(multiCurrencyOpenStatsProvider.future);
      expect(open.currentValue, isNull);
      expect(open.missingValueCount, 1);
    });

    test('the investment detail and its card say the same', () async {
      _keep(container, multiCurrencyInvestmentStatsProvider('gold'));
      final detail = await container.read(
        multiCurrencyInvestmentStatsProvider('gold').future,
      );
      expect(detail.currentValue, isNull);
      expect(detail.needsCurrentValue, isTrue);

      _keep(container, activeInvestmentBasicStatsMapProvider);
      final cards = await _until(
        container,
        activeInvestmentBasicStatsMapProvider,
      );
      expect(cards['gold']!.currentValue, isNull);
      expect(cards['gold']!.needsCurrentValue, isTrue);
    });

    test('the converted values list it and hold no flow for it', () async {
      _keep(container, convertedTerminalValuesProvider);
      final converted = await container.read(
        convertedTerminalValuesProvider.future,
      );
      final gold = converted.byInvestment['gold']!;
      expect(gold.flows, isEmpty);
      expect(gold.missingValueCount, 1);
      expect(gold.needsNewerValueIds, {'gold'});
    });

    test('its XIRR is undefined, not computed from the old price', () async {
      _keep(container, investmentXirrProvider('gold'));
      final xirr = await container.read(investmentXirrProvider('gold').future);
      expect(xirr.value, isNull);
    });

    test('a newer value brings the numbers back', () async {
      final fresh = _container([_market, _newer]);
      _keep(fresh, multiCurrencyGlobalStatsProvider);
      final global = await fresh.read(multiCurrencyGlobalStatsProvider.future);
      expect(global.currentValue, 175000.00);
      expect(global.missingValueCount, 0);
    });
  });

  group('goal progress and FIRE', () {
    Future<double> goalCurrent(
      List<InvestmentValuationSnapshot> snapshots,
    ) async {
      final progress = await GoalProgressCalculator.calculateMultiCurrency(
        goal: _goal(),
        allInvestments: [_gold],
        allCashFlows: _flows,
        batchConverter: BatchCurrencyConverter(MockCurrencyConversionService()),
        baseCurrency: 'INR',
        asOf: _today,
        snapshots: {'gold': snapshots},
      );
      return progress.currentAmount;
    }

    test('a goal counts what was put in, not the old price', () async {
      expect(await goalCurrent([_market]), 150000.00);
    });

    test('a goal uses a newer value once there is one', () async {
      expect(await goalCurrent([_market, _newer]), 175000.00);
    });

    test('the FIRE corpus counts what was put in, unvalued', () async {
      final container = _container([_market]);
      _keep(container, firePortfolioInputsProvider);
      final inputs = await container.read(firePortfolioInputsProvider.future);
      expect(inputs.corpus.total, 150000.00);
      expect(inputs.corpus.valuedCount, 0);
      expect(inputs.corpus.principalOnlyCount, 1);
    });
  });
}
