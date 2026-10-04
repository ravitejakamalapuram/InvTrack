// A12 (#756): every goal provider reads the converted snapshot (A13) and the
// current values of open investments (A10), converts the goal's target to the
// base currency, and says how many other goals count the same investments.
// Today is pinned to 2026-10-04.
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

import '../../../../mocks/mock_currency_conversion_service.dart';

GoalEntity _goal(
  String id, {
  double target = 1000000,
  GoalTrackingMode mode = GoalTrackingMode.selected,
  List<String> linked = const ['fd'],
  String currency = 'INR',
}) => GoalEntity(
  id: id,
  name: id,
  type: GoalType.targetAmount,
  targetAmount: target,
  trackingMode: mode,
  linkedInvestmentIds: linked,
  icon: '🎯',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: currency,
);

InvestmentEntity _inv(
  String id,
  InvestmentType type, {
  String currency = 'INR',
  double? currentValue,
  DateTime? currentValueDate,
  bool isArchived = false,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  interestPayoutMode: InterestPayoutMode.periodic,
  expectedRate: 7.5,
  currency: currency,
  currentValue: currentValue,
  currentValueDate: currentValueDate,
  isArchived: isArchived,
);

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

/// G1: a ₹10L FD paying ₹18,750 a quarter, seven payouts so far.
final _fd = _inv('fd', InvestmentType.fixedDeposit);
final _fdFlows = [
  _cf('fd', CashFlowType.invest, 1000000, DateTime(2024, 12, 4)),
  for (var quarter = 1; quarter <= 7; quarter++)
    _cf('fd', CashFlowType.income, 18750, DateTime(2024, 12 + 3 * quarter, 4)),
];

ProviderContainer _container({
  required List<GoalEntity> goals,
  List<InvestmentEntity> investments = const [],
  List<InvestmentEntity> archived = const [],
  List<CashFlowEntity> cashFlows = const [],
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
      allInvestmentsProvider.overrideWith((ref) => Stream.value(investments)),
      allCashFlowsStreamProvider.overrideWith((ref) => Stream.value(cashFlows)),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value(archived)),
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
  test('G1 through the providers: a ₹10L FD funds a ₹10L goal fully', () async {
    final container = _container(
      goals: [_goal('house')],
      investments: [_fd],
      cashFlows: _fdFlows,
    );

    final progress = await _resolve(
      container,
      multiCurrencyGoalProgressProvider('house'),
    );

    expect(progress!.currentAmount, closeTo(1000000.00, 0.005));
    expect(progress.progressPercent, closeTo(100.0, 1e-9));
    expect(progress.status, GoalStatus.achieved);
  });

  test('a USD goal target is converted to the base currency', () async {
    // \$24,096.39 at ₹83/\$ is ₹20,00,000, so the ₹10L FD is 50% of it.
    final container = _container(
      goals: [_goal('usd', target: 24096.385542168675, currency: 'USD')],
      investments: [_fd],
      cashFlows: _fdFlows,
    );

    final progress = await _resolve(
      container,
      multiCurrencyGoalProgressProvider('usd'),
    );

    expect(progress!.targetAmount, closeTo(2000000.00, 0.005));
    expect(progress.progressPercent, closeTo(50.0, 1e-6));
  });

  test('a USD investment counts at its converted current value', () async {
    final stocks = _inv(
      'us',
      InvestmentType.stocks,
      currency: 'USD',
      currentValue: 1000,
      currentValueDate: DateTime(2026, 10, 1),
    );
    final container = _container(
      goals: [
        _goal('g', target: 166000, linked: const ['us']),
      ],
      investments: [stocks],
      cashFlows: [
        _cf(
          'us',
          CashFlowType.invest,
          800,
          DateTime(2026, 4, 1),
          currency: 'USD',
        ),
      ],
    );

    final progress = await _resolve(
      container,
      multiCurrencyGoalProgressProvider('g'),
    );

    expect(progress!.currentAmount, closeTo(83000.00, 0.005));
    expect(progress.progressPercent, closeTo(50.0, 1e-6));
  });

  test('goals that count the same investment say so', () async {
    final container = _container(
      goals: [
        _goal('house'),
        _goal('all', mode: GoalTrackingMode.all, linked: const []),
        _goal('other', linked: const ['p2p']),
      ],
      investments: [_fd, _inv('p2p', InvestmentType.p2pLending)],
      cashFlows: [
        ..._fdFlows,
        _cf('p2p', CashFlowType.invest, 100000, DateTime(2026, 1, 4)),
      ],
    );

    final all = await _resolve(
      container,
      multiCurrencyAllGoalsProgressProvider,
    );
    final counts = {for (final p in all) p.goal.id: p.otherGoalsCount};

    expect(counts, {'house': 1, 'all': 2, 'other': 1});
  });

  test(
    'linked investments include archived ones, which are not counted',
    () async {
      final archivedFd = _inv(
        'old-fd',
        InvestmentType.fixedDeposit,
        isArchived: true,
      );
      final container = _container(
        goals: [
          _goal('house', linked: const ['fd', 'old-fd']),
        ],
        investments: [_fd],
        archived: [archivedFd],
        cashFlows: _fdFlows,
      );

      final linked = await _resolve(
        container,
        goalLinkedInvestmentsProvider('house'),
      );

      expect([for (final l in linked) l.investment.id], ['fd', 'old-fd']);
      expect([for (final l in linked) l.isArchived], [false, true]);
      expect([for (final l in linked) l.isCounted], [true, false]);
    },
  );
}
