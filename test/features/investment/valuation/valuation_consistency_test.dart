// #941 (plan test 17): one 5,00,000 opening baseline reads the same in the
// detail stats, the cards, the portfolio total, the FIRE corpus, goal
// progress and the health score, while XIRR and MOIC leave it out and the
// disclosure count is 1. A portfolio of baselines returns its value with no
// performance, not empty stats. With the flag off nothing changes.
//
// Today is 2026-10-02. Expected values worked out by hand:
//   FD: 1,00,000 on 2025-10-02 at 7% quarterly -> 1,07,185.90 (CALC-01 S1)
//   baseline: 5,00,000 on 2026-10-02 (gold, a market value)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/goal_progress_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/planning_inputs_calculator.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

import '../../../mocks/mock_currency_conversion_service.dart';
import 'valuation_fixtures.dart';

final _today = DateTime(2026, 10, 2);

InvestmentValuationSnapshot _baseline({
  String investmentId = 'gold',
  double amount = 500000,
  String currency = 'INR',
}) => testSnapshot(
  'base-$investmentId',
  investmentId: investmentId,
  amount: amount,
  date: _today,
  currency: currency,
  kind: ValuationKind.marketValue,
  provenance: ValuationProvenance.openingBaseline,
);

final _gold = testInvestment('gold');
final _fd = testInvestment('fd', type: InvestmentType.fixedDeposit, rate: 7)
    .copyWith(
      compoundingFrequency: CompoundingFrequency.quarterly,
      interestPayoutMode: InterestPayoutMode.cumulative,
    );
final _fdFlows = [
  testFlow('fd', CashFlowType.invest, 100000, DateTime(2025, 10, 2)),
];

ProviderContainer _container({
  required List<InvestmentEntity> investments,
  List<CashFlowEntity> cashFlows = const [],
  List<InvestmentValuationSnapshot> snapshots = const [],
  bool enabled = true,
  String baseCurrency = 'INR',
}) {
  final container = ProviderContainer(
    overrides: [
      valuationDateProvider.overrideWithValue(_today),
      valuationSnapshotsActiveProvider.overrideWithValue(enabled),
      // What the stream would deliver; with the flag off it is not read.
      allValuationSnapshotsProvider.overrideWith(
        (ref) => ref.watch(valuationSnapshotsActiveProvider)
            ? Stream.value(snapshots)
            : Stream.value(const []),
      ),
      allInvestmentsProvider.overrideWith((ref) => Stream.value(investments)),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(cashFlows)),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
      for (final inv in investments)
        cashFlowsByInvestmentProvider(inv.id).overrideWith(
          (ref) => Stream.value([
            for (final cf in cashFlows)
              if (cf.investmentId == inv.id) cf,
          ]),
        ),
      currencyCodeProvider.overrideWith((ref) => baseCurrency),
      currencyConversionServiceProvider.overrideWithValue(
        MockCurrencyConversionService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Keeps a provider (and the streams it watches) alive for the test.
void _keep(ProviderContainer container, ProviderListenable<Object?> provider) {
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
}

void main() {
  group('one baseline, every consumer (plan test 17)', () {
    late ProviderContainer container;

    setUp(() {
      container = _container(investments: [_gold], snapshots: [_baseline()]);
    });

    void expectBaseline(InvestmentStats stats) {
      expect(stats.currentValue, 500000.00);
      expect(stats.currentValueDate, _today);
      expect(stats.hasData, isTrue);
      expect(stats.cashFlowCount, 0);
      expect(stats.returnsKnown, isFalse);
      expect(stats.xirr, isNull);
      expect(stats.limitedHistoryCount, 1);
      expect(stats.totalInvested, 0);
      expect(stats.totalReturned, 0);
    }

    test('the investment detail', () async {
      _keep(container, multiCurrencyInvestmentStatsProvider('gold'));
      expectBaseline(
        await container.read(
          multiCurrencyInvestmentStatsProvider('gold').future,
        ),
      );
    });

    test('the cards (per-investment stats)', () async {
      _keep(container, activeInvestmentBasicStatsMapProvider);
      final stats = await _until(
        container,
        activeInvestmentBasicStatsMapProvider,
      );
      expectBaseline(stats['gold']!);
    });

    test('the overview (portfolio totals)', () async {
      _keep(container, multiCurrencyGlobalStatsProvider);
      expectBaseline(
        await container.read(multiCurrencyGlobalStatsProvider.future),
      );
      _keep(container, multiCurrencyOpenStatsProvider);
      expectBaseline(
        await container.read(multiCurrencyOpenStatsProvider.future),
      );
    });

    test('the FIRE corpus', () async {
      _keep(container, firePortfolioInputsProvider);
      final inputs = await container.read(firePortfolioInputsProvider.future);
      expect(inputs.corpus.total, 500000.00);
      expect(inputs.corpus.valuedCount, 1);
    });

    test('goal progress', () async {
      final progress = await GoalProgressCalculator.calculateMultiCurrency(
        goal: GoalEntity(
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
        ),
        allInvestments: [_gold],
        allCashFlows: const [],
        batchConverter: BatchCurrencyConverter(MockCurrencyConversionService()),
        baseCurrency: 'INR',
        asOf: _today,
        snapshots: {
          'gold': [_baseline()],
        },
      );
      expect(progress.currentAmount, 500000.00);
      expect(progress.progressPercent, closeTo(50.0, 1e-9));
    });

    test('the value is the same everywhere', () async {
      _keep(container, multiCurrencyGlobalStatsProvider);
      _keep(container, convertedTerminalValuesProvider);
      final global = await container.read(
        multiCurrencyGlobalStatsProvider.future,
      );
      final converted = await container.read(
        convertedTerminalValuesProvider.future,
      );
      final corpus = PlanningInputsCalculator.corpus(
        investments: [_gold],
        cashFlows: converted.snapshot.cashFlows,
        terminalValues: converted.byInvestment,
      );
      expect(corpus.total, global.currentValue);
    });
  });

  group('a baseline next to ordinary investments', () {
    late ProviderContainer container;

    setUp(() {
      container = _container(
        investments: [_fd, _gold],
        cashFlows: _fdFlows,
        snapshots: [_baseline()],
      );
    });

    test(
      'XIRR and MOIC are the ordinary investments\', the value is both',
      () async {
        _keep(container, multiCurrencyGlobalStatsProvider);
        final stats = await container.read(
          multiCurrencyGlobalStatsProvider.future,
        );
        expect(stats.xirr, closeTo(0.071859031, 1e-6));
        expect(stats.moic, closeTo(1.071859031, 1e-6));
        expect(stats.returnsKnown, isTrue);
        expect(stats.limitedHistoryCount, 1);
        expect(stats.totalInvested, 100000);
        expect(stats.currentValue, closeTo(607185.90, 0.005));
      },
    );

    test(
      'the per-investment XIRR is undefined for the baseline (T24)',
      () async {
        _keep(container, activeInvestmentXirrResultMapProvider);
        final xirr = await container.read(
          activeInvestmentXirrResultMapProvider.future,
        );
        expect(xirr.keys, ['fd']);
        expect(xirr['fd']!.value, closeTo(0.071859031, 1e-6));

        _keep(container, investmentXirrProvider('gold'));
        final gold = await container.read(
          investmentXirrProvider('gold').future,
        );
        expect(gold.value, isNull);
      },
    );
  });

  group('limited history with cash flows after the baseline', () {
    test('its flows stay in the totals and out of XIRR and MOIC', () async {
      final topUp = testFlow(
        'gold',
        CashFlowType.invest,
        50000,
        DateTime(2026, 10, 1),
      );
      final container = _container(
        investments: [_fd, _gold],
        cashFlows: [..._fdFlows, topUp],
        snapshots: [_baseline()],
      );
      _keep(container, multiCurrencyGlobalStatsProvider);
      final stats = await container.read(
        multiCurrencyGlobalStatsProvider.future,
      );
      expect(stats.totalInvested, 150000);
      expect(stats.xirr, closeTo(0.071859031, 1e-6));
      expect(stats.paidInCapital, 100000);
      expect(stats.limitedHistoryCount, 1);

      _keep(container, activeInvestmentXirrResultMapProvider);
      final xirr = await container.read(
        activeInvestmentXirrResultMapProvider.future,
      );
      expect(xirr.keys, ['fd']);
    });
  });

  group('the health score', () {
    test('keeps limited investments out of the portfolio XIRR', () {
      final topUp = testFlow(
        'gold',
        CashFlowType.invest,
        50000,
        DateTime(2026, 10, 1),
      );
      final flows = [..._fdFlows, topUp];
      final snapshots = {
        'gold': [_baseline()],
      };
      final byInvestment = {
        for (final inv in [_fd, _gold])
          inv.id: CurrentValueCalculator.terminalValues(
            investments: [inv],
            cashFlows: flows,
            asOf: _today,
            snapshots: snapshots,
          ),
      };
      final stats = FinancialCalculatorModule().calculateStatsByInvestment(
        flows,
        includeXirr: false,
        terminalValues: byInvestment,
      );
      final score = PortfolioHealthCalculator.calculate(
        investments: [_fd, _gold],
        investmentStats: stats,
        allCashFlows: flows,
        goalProgress: const [],
        terminalValues: byInvestment,
        asOf: _today,
      );
      expect(score, isNotNull);
      // The returns component judges the FD alone: 7.19% against 6%.
      expect(score!.returnsPerformance.score, closeTo(64.74, 0.01));
    });
  });

  group('the flag off (plan test 19)', () {
    test('snapshots are not read: a portfolio of baselines is empty', () async {
      final container = _container(
        investments: [_gold],
        snapshots: [_baseline()],
        enabled: false,
      );
      _keep(container, multiCurrencyGlobalStatsProvider);
      final stats = await container.read(
        multiCurrencyGlobalStatsProvider.future,
      );
      expect(stats, InvestmentStats.empty());
    });

    test('ordinary investments read exactly as before', () async {
      final container = _container(
        investments: [_fd],
        cashFlows: _fdFlows,
        snapshots: [_baseline(investmentId: 'fd', amount: 1)],
        enabled: false,
      );
      _keep(container, multiCurrencyGlobalStatsProvider);
      final stats = await container.read(
        multiCurrencyGlobalStatsProvider.future,
      );
      expect(stats.currentValue, closeTo(107185.90, 0.005));
      expect(stats.currentValueIsEstimate, isTrue);
      expect(stats.limitedHistoryCount, 0);
      expect(stats.returnsKnown, isTrue);
    });
  });

  group('currency (plan test 12)', () {
    test(
      'a USD baseline is converted before it is shown under rupees',
      () async {
        final usdGold = testInvestment('gold', currency: 'USD');
        final container = _container(
          investments: [usdGold],
          snapshots: [_baseline(amount: 1000, currency: 'USD')],
        );
        _keep(container, multiCurrencyGlobalStatsProvider);
        final stats = await container.read(
          multiCurrencyGlobalStatsProvider.future,
        );
        // 1 USD = 83 INR in the test rates.
        expect(stats.currentValue, 83000);
      },
    );
  });
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
