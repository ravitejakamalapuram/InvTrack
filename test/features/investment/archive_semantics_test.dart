// A17 / GAP1-13: pins what archiving does to the Overview totals, the FIRE
// corpus, year over year, the goals and the health goal alignment.
//
// Founder decision, 2026-10-02: archived investments stay EXCLUDED from
// totals, goals and FIRE. These tests assert the exclusion (and that the
// archived detail screen's own stats are converted), so a refactor cannot
// flip it without a test failing. Each value is checked before and after the
// archive, so that a zero after is not just an empty provider. The swipe and
// detail dialogs, the hero footnote and the all-archived card have their own
// widget tests. Today is pinned to 2026-10-04.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_analytics_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';
import 'package:inv_tracker/features/portfolio_health/data/services/health_score_auto_save_service.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';

import '../../mocks/mock_currency_conversion_service.dart';

CashFlowEntity _cf(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date, {
  String currency = 'INR',
}) => CashFlowEntity(
  id: '$investmentId-${type.name}-${date.toIso8601String()}',
  investmentId: investmentId,
  type: type,
  amount: amount,
  date: date,
  createdAt: date,
  currency: currency,
);

/// The FD of the review: INVEST ₹1,00,000 on 2024-04-01, INCOME ₹7,000 on
/// 2025-04-01 and 2026-04-01, RETURN ₹1,00,000 on 2026-04-01. Net ₹14,000,
/// MOIC 1.14, XIRR 7%.
final _fd = InvestmentEntity(
  id: 'fd',
  name: 'FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.closed,
  currency: 'INR',
  createdAt: DateTime(2024, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
  closedAt: DateTime(2026, 4, 1),
);
final _fdFlows = [
  _cf('fd', CashFlowType.invest, 100000, DateTime(2024, 4, 1)),
  _cf('fd', CashFlowType.income, 7000, DateTime(2025, 4, 1)),
  _cf('fd', CashFlowType.income, 7000, DateTime(2026, 4, 1)),
  _cf('fd', CashFlowType.returnFlow, 100000, DateTime(2026, 4, 1)),
];

/// An open fund worth ₹1,14,000 now, behind the 'House' goal (₹1,50,000).
final _fund = InvestmentEntity(
  id: 'fund',
  name: 'Fund',
  type: InvestmentType.stocks,
  status: InvestmentStatus.open,
  currency: 'INR',
  createdAt: DateTime(2024, 4, 1),
  updatedAt: DateTime(2024, 4, 1),
  currentValue: 114000,
  currentValueDate: DateTime(2026, 10, 1),
);
final _fundFlows = [
  _cf('fund', CashFlowType.invest, 100000, DateTime(2024, 4, 1)),
];
final _house = GoalEntity(
  id: 'house',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 150000,
  trackingMode: GoalTrackingMode.selected,
  linkedInvestmentIds: const ['fund'],
  icon: '🏠',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: 'INR',
);

/// Keeps the health score out of Firestore.
class _NoAutoSave implements HealthScoreAutoSaveService {
  @override
  void updateScore(PortfolioHealthScore score) {}

  @override
  void clearScore() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _fireSettings = FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: 1996,
  targetFireAge: 45,
  isSetupComplete: true,
  currency: 'INR',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// An open gold holding that stays active, so that a portfolio remains to be
/// scored after the fund is archived.
final _gold = InvestmentEntity(
  id: 'gold',
  name: 'Gold',
  type: InvestmentType.gold,
  status: InvestmentStatus.open,
  currency: 'INR',
  createdAt: DateTime(2025, 4, 1),
  updatedAt: DateTime(2025, 4, 1),
  currentValue: 50000,
  currentValueDate: DateTime(2026, 10, 1),
);
final _goldFlows = [
  _cf('gold', CashFlowType.invest, 40000, DateTime(2025, 4, 1)),
];

/// What the app shows once the investments are archived: the active streams
/// no longer hold them or their cash flows (archiving moves both to the
/// archived collections), and the archived streams do.
ProviderContainer _container({
  List<InvestmentEntity> active = const [],
  List<CashFlowEntity> activeFlows = const [],
  List<InvestmentEntity> archived = const [],
  Map<String, List<CashFlowEntity>> archivedFlows = const {},
  List<GoalEntity> goals = const [],
  String baseCurrency = 'INR',
}) {
  final container = ProviderContainer(
    overrides: [
      activeGoalsProvider.overrideWith((ref) => Stream.value(goals)),
      for (final goal in goals)
        watchGoalByIdProvider(
          goal.id,
        ).overrideWith((ref) => Stream.value(goal)),
      valuationDateProvider.overrideWithValue(DateTime(2026, 10, 4)),
      allInvestmentsProvider.overrideWith((ref) => Stream.value(active)),
      allCashFlowsStreamProvider.overrideWith(
        (ref) => Stream.value(activeFlows),
      ),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value(archived)),
      for (final entry in archivedFlows.entries)
        archivedCashFlowsByInvestmentProvider(
          entry.key,
        ).overrideWith((ref) => Stream.value(entry.value)),
      for (final inv in active)
        cashFlowsByInvestmentProvider(inv.id).overrideWith(
          (ref) => Stream.value([
            for (final cf in activeFlows)
              if (cf.investmentId == inv.id) cf,
          ]),
        ),
      fireSettingsProvider.overrideWith((ref) => Stream.value(_fireSettings)),
      isAuthenticatedProvider.overrideWith((ref) => true),
      healthScoreAutoSaveServiceProvider.overrideWithValue(_NoAutoSave()),
      currencyCodeProvider.overrideWith((ref) => baseCurrency),
      currencyConversionServiceProvider.overrideWithValue(
        MockCurrencyConversionService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<T> _resolve<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 100; i++) {
    final value = sub.read();
    if (value.hasError) throw value.error!;
    if (value.hasValue && !value.isLoading) return value.requireValue;
    await Future<void>.delayed(Duration.zero);
  }
  fail('$provider did not resolve');
}

void main() {
  group('Overview totals', () {
    test('before archive: the FD is in the global and closed totals', () async {
      final container = _container(active: [_fd], activeFlows: _fdFlows);

      final global = await _resolve(
        container,
        multiCurrencyGlobalStatsProvider,
      );
      final closed = await _resolve(
        container,
        multiCurrencyClosedStatsProvider,
      );

      expect(global.netCashFlow, closeTo(14000.00, 0.005));
      expect(global.moic, closeTo(1.14, 1e-6));
      expect(global.xirr, closeTo(0.07, 1e-6));
      expect(closed.netCashFlow, closeTo(14000.00, 0.005));
    });

    test('after archive: the FD is in none of them', () async {
      final container = _container(archived: [_fd.copyWith(isArchived: true)]);

      final global = await _resolve(
        container,
        multiCurrencyGlobalStatsProvider,
      );
      final closed = await _resolve(
        container,
        multiCurrencyClosedStatsProvider,
      );
      final open = await _resolve(container, multiCurrencyOpenStatsProvider);

      for (final stats in [global, closed, open]) {
        expect(stats.hasData, isFalse);
        expect(stats.netCashFlow, 0);
        expect(stats.totalInvested, 0);
        expect(stats.totalReturned, 0);
      }
    });

    test('archiving one of two leaves only the other in the totals', () async {
      final container = _container(
        active: [_fund],
        activeFlows: _fundFlows,
        archived: [_fd.copyWith(isArchived: true)],
        archivedFlows: {'fd': _fdFlows},
      );

      final global = await _resolve(
        container,
        multiCurrencyGlobalStatsProvider,
      );

      // Only the fund: ₹1,00,000 out, nothing back (its value is separate).
      expect(global.totalInvested, closeTo(100000.00, 0.005));
      expect(global.totalReturned, closeTo(0.00, 0.005));
    });
  });

  group('Goals', () {
    test('before archive: House counts the fund at 76%', () async {
      final container = _container(
        active: [_fund],
        activeFlows: _fundFlows,
        goals: [_house],
      );

      final progress = await _resolve(
        container,
        multiCurrencyGoalProgressProvider('house'),
      );

      expect(progress!.currentAmount, closeTo(114000.00, 0.005));
      expect(progress.progressPercent, closeTo(76.0, 1e-6));
    });

    test(
      'after archive: House no longer counts it and is not started',
      () async {
        final container = _container(
          archived: [_fund.copyWith(isArchived: true)],
          archivedFlows: {'fund': _fundFlows},
          goals: [_house],
        );

        final progress = await _resolve(
          container,
          multiCurrencyGoalProgressProvider('house'),
        );

        expect(progress!.currentAmount, closeTo(0.00, 0.005));
        expect(progress.progressPercent, closeTo(0.0, 1e-6));
        expect(progress.status, GoalStatus.notStarted);
      },
    );

    test(
      'the goal details still list the archived fund, as not counted',
      () async {
        final container = _container(
          archived: [_fund.copyWith(isArchived: true)],
          archivedFlows: {'fund': _fundFlows},
          goals: [_house],
        );

        final linked = await _resolve(
          container,
          goalLinkedInvestmentsProvider('house'),
        );

        expect(linked, hasLength(1));
        expect(linked.single.isArchived, isTrue);
        expect(linked.single.isCounted, isFalse);
      },
    );
  });

  group('FIRE corpus', () {
    test('before archive: the fund is in the corpus at its value', () async {
      final container = _container(active: [_fund], activeFlows: _fundFlows);

      final FireCalculationResult result = await _resolve(
        container,
        fireCalculationProvider,
      );

      expect(result.currentPortfolioValue, closeTo(114000.00, 0.005));
    });

    test('after archive: the fund is not in the corpus', () async {
      final container = _container(
        archived: [_fund.copyWith(isArchived: true)],
        archivedFlows: {'fund': _fundFlows},
      );

      final result = await _resolve(container, fireCalculationProvider);

      expect(result.currentPortfolioValue, closeTo(0.00, 0.005));
    });
  });

  group('Year over year', () {
    test('before archive: the FD is in this and last year', () async {
      final container = _container(active: [_fd], activeFlows: _fdFlows);

      final yoy = await _resolve(container, yoyComparisonProvider);

      // This FY to date (from 2026-04-01): the 7,000 payout and the
      // 1,00,000 back. Same days last FY: the 7,000 payout.
      expect(yoy.thisYearNet, closeTo(107000.00, 0.005));
      expect(yoy.lastYearNet, closeTo(7000.00, 0.005));
    });

    test('after archive: the FD is in neither', () async {
      final container = _container(archived: [_fd.copyWith(isArchived: true)]);

      final yoy = await _resolve(container, yoyComparisonProvider);

      expect(yoy.thisYearNet, 0);
      expect(yoy.lastYearNet, 0);
    });
  });

  group('Health goal alignment', () {
    test(
      'before archive: House is counted and the goals are aligned',
      () async {
        final container = _container(
          active: [_fund, _gold],
          activeFlows: [..._fundFlows, ..._goldFlows],
          goals: [_house],
        );

        final score = await _resolve(container, portfolioHealthProvider);

        expect(score!.goalAlignment.score, closeTo(100.0, 1e-6));
      },
    );

    test(
      'after archive: House no longer counts the fund, so none are aligned',
      () async {
        final container = _container(
          active: [_gold],
          activeFlows: _goldFlows,
          archived: [_fund.copyWith(isArchived: true)],
          archivedFlows: {'fund': _fundFlows},
          goals: [_house],
        );

        final score = await _resolve(container, portfolioHealthProvider);

        expect(score!.goalAlignment.score, closeTo(0.0, 1e-6));
      },
    );
  });

  group('Archived detail stats', () {
    test('a USD investment is converted to the base currency', () async {
      // INVEST $10,000, RETURN $11,500 at ₹83/$ (the test rate): ₹8,30,000
      // out, ₹9,54,500 back, net ₹1,24,500. Unconverted it read ₹1,500.
      final etf = InvestmentEntity(
        id: 'etf',
        name: 'US ETF',
        type: InvestmentType.stocks,
        status: InvestmentStatus.closed,
        isArchived: true,
        currency: 'USD',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final flows = [
        _cf(
          'etf',
          CashFlowType.invest,
          10000,
          DateTime(2024, 1, 1),
          currency: 'USD',
        ),
        _cf(
          'etf',
          CashFlowType.returnFlow,
          11500,
          DateTime(2025, 1, 1),
          currency: 'USD',
        ),
      ];
      final container = _container(
        archived: [etf],
        archivedFlows: {'etf': flows},
      );

      final InvestmentStats stats = await _resolve(
        container,
        multiCurrencyArchivedInvestmentStatsProvider('etf'),
      );

      expect(stats.totalInvested, closeTo(830000.00, 0.005));
      expect(stats.totalReturned, closeTo(954500.00, 0.005));
      expect(stats.netCashFlow, closeTo(124500.00, 0.005));
    });
  });
}
