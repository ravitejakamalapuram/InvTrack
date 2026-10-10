// A17 / GAP1-13: pins what archiving does to the Overview totals and goals.
//
// Founder decision, 2026-10-02: archived investments stay EXCLUDED from
// totals, goals and FIRE. These tests assert the exclusion (and that the
// archived detail screen's own stats are converted), so a refactor cannot
// flip it without a test failing. Each value is checked before and after the
// archive. Today is pinned to 2026-10-04.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';

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
