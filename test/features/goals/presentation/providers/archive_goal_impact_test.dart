// A17 / GAP1-02: archiving an investment silently dropped goal progress,
// often to 0% / 'Not Started'. Before archiving, the user is told which goals
// change and by how much. The numbers come from the same
// GoalProgressCalculator as the goal screens, with and without the
// investment. Today is pinned to 2026-10-04.
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
  required double target,
  required GoalTrackingMode mode,
  List<String> linked = const [],
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
  required double currentValue,
  InvestmentStatus status = InvestmentStatus.open,
  String currency = 'INR',
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  currency: currency,
  currentValue: currentValue,
  currentValueDate: DateTime(2026, 10, 1),
);

CashFlowEntity _invest(String investmentId, double amount, DateTime date) =>
    CashFlowEntity(
      id: '$investmentId-invest',
      investmentId: investmentId,
      type: CashFlowType.invest,
      amount: amount,
      date: date,
      createdAt: date,
      currency: 'INR',
    );

/// Worth ₹1,14,000 now, from ₹1,00,000 paid in.
final _fund = _inv('fund', InvestmentType.stocks, currentValue: 114000);

/// Worth ₹50,000 now.
final _gold = _inv('gold', InvestmentType.gold, currentValue: 50000);

final _flows = [
  _invest('fund', 100000, DateTime(2024, 4, 1)),
  _invest('gold', 40000, DateTime(2025, 4, 1)),
];

// 114000 / 150000 = 76%.
final _house = _goal(
  'house',
  target: 150000,
  mode: GoalTrackingMode.selected,
  linked: const ['fund'],
);
// (114000 + 50000) / 400000 = 41%; without the fund 50000 / 400000 = 12.5%.
final _wealth = _goal('wealth', target: 400000, mode: GoalTrackingMode.all);
// Only the gold: archiving the fund does not touch it.
final _jewellery = _goal(
  'jewellery',
  target: 100000,
  mode: GoalTrackingMode.selected,
  linked: const ['gold'],
);

ProviderContainer _container({
  required List<GoalEntity> goals,
  required List<InvestmentEntity> investments,
  List<CashFlowEntity>? flows,
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
      allCashFlowsStreamProvider.overrideWith(
        (ref) => Stream.value(flows ?? _flows),
      ),
      archivedInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
      currencyCodeProvider.overrideWith((ref) => 'INR'),
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
  test(
    'lists the goals the investment feeds, with progress before and after',
    () async {
      final container = _container(
        goals: [_house, _wealth, _jewellery],
        investments: [_fund, _gold],
      );

      final impacts = await _resolve(
        container,
        archiveGoalImpactProvider('fund'),
      );

      expect([for (final i in impacts) i.goal.id], ['house', 'wealth']);

      final house = impacts[0];
      expect(house.before.currentAmount, closeTo(114000.00, 0.005));
      expect(house.before.progressPercent, closeTo(76.0, 1e-6));
      expect(house.after.currentAmount, closeTo(0.00, 0.005));
      expect(house.after.progressPercent, closeTo(0.0, 1e-6));
      expect(house.after.status, GoalStatus.notStarted);

      final wealth = impacts[1];
      expect(wealth.before.progressPercent, closeTo(41.0, 1e-6));
      expect(wealth.after.currentAmount, closeTo(50000.00, 0.005));
      expect(wealth.after.progressPercent, closeTo(12.5, 1e-6));
    },
  );

  test('a goal that does not count the investment is not listed', () async {
    final container = _container(
      goals: [_jewellery],
      investments: [_fund, _gold],
    );

    final impacts = await _resolve(
      container,
      archiveGoalImpactProvider('fund'),
    );

    expect(impacts, isEmpty);
  });

  test('archiving a closed investment changes no goal', () async {
    // Goals count the value of open investments only, so a closed one has
    // nothing to lose.
    final closedFund = _inv(
      'fund',
      InvestmentType.stocks,
      currentValue: 114000,
      status: InvestmentStatus.closed,
    );
    final container = _container(
      goals: [_house, _wealth],
      investments: [closedFund, _gold],
    );

    final impacts = await _resolve(
      container,
      archiveGoalImpactProvider('fund'),
    );

    expect([for (final i in impacts) i.goal.id], isNot(contains('house')));
    expect(impacts, isEmpty);
  });

  test('an unknown investment changes no goal', () async {
    final container = _container(
      goals: [_house, _wealth],
      investments: [_fund, _gold],
    );

    final impacts = await _resolve(
      container,
      archiveGoalImpactProvider('missing'),
    );

    expect(impacts, isEmpty);
  });

  test(
    'a goal already past its target is not listed: it stays at 100%',
    () async {
      // 1,80,000 of a 1,00,000 target is 100% (clamped); without the gold it is
      // 1,20,000, still 100%. The amount differs but the goal does not, so the
      // dialog must not list 'done: 100% to 100%'.
      final done = _goal('done', target: 100000, mode: GoalTrackingMode.all);
      final bigFund = _inv('fund', InvestmentType.stocks, currentValue: 120000);
      final bigGold = _inv('gold', InvestmentType.gold, currentValue: 60000);
      final container = _container(
        goals: [done],
        investments: [bigFund, bigGold],
      );

      final impacts = await _resolve(
        container,
        archiveGoalImpactProvider('gold'),
      );

      expect(impacts, isEmpty);
    },
  );

  test('a holding too small to move the whole percent is not listed', () async {
    // 5,01,000 of 10,00,000 is 50.1%; without the 1,000 holding it is 50.0%.
    // Both show as 50%, so there is nothing to tell the user.
    final goal = _goal('half', target: 1000000, mode: GoalTrackingMode.all);
    final big = _inv('fund', InvestmentType.stocks, currentValue: 500000);
    final tiny = _inv('gold', InvestmentType.gold, currentValue: 1000);
    final container = _container(goals: [goal], investments: [big, tiny]);

    final impacts = await _resolve(
      container,
      archiveGoalImpactProvider('gold'),
    );

    expect(impacts, isEmpty);
  });

  test(
    'a goal whose whole percent changes is listed even by a little',
    () async {
      // 50.1% -> 49.9% crosses a whole percent (50 -> 49), so it is listed.
      final goal = _goal('half', target: 1000000, mode: GoalTrackingMode.all);
      final big = _inv('fund', InvestmentType.stocks, currentValue: 499500);
      final small = _inv('gold', InvestmentType.gold, currentValue: 1000);
      final container = _container(goals: [goal], investments: [big, small]);

      final impacts = await _resolve(
        container,
        archiveGoalImpactProvider('gold'),
      );

      expect([for (final i in impacts) i.goal.id], ['half']);
      expect(impacts.single.before.displayPercent, 50);
      expect(impacts.single.after.displayPercent, 49);
    },
  );

  test(
    'archiving a closed investment is previewed by progress percent only',
    () async {
      // The preview compares the progress percent. A closed investment adds
      // nothing to it, but its INVEST/RETURN flows do feed the goal's net new
      // money, so archiving it moves the projected date and velocity. Those
      // are not previewed (the dialog says what changes in percent only);
      // this pins that scope so a change to it is a decision, not an accident.
      final closed = _inv(
        'old',
        InvestmentType.stocks,
        currentValue: 0,
        status: InvestmentStatus.closed,
      );
      final goal = _goal(
        'house',
        target: 300000,
        mode: GoalTrackingMode.selected,
        linked: const ['fund', 'old'],
      );
      final closedFlows = [
        _invest('old', 60000, DateTime(2026, 2, 1)),
        CashFlowEntity(
          id: 'old-return',
          investmentId: 'old',
          type: CashFlowType.returnFlow,
          amount: 20000,
          date: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
          currency: 'INR',
        ),
      ];
      final withClosed = _container(
        goals: [goal],
        investments: [_fund, closed],
        flows: [..._flows, ...closedFlows],
      );
      final withoutClosed = _container(
        goals: [goal],
        investments: [_fund],
        flows: _flows,
      );

      final impacts = await _resolve(
        withClosed,
        archiveGoalImpactProvider('old'),
      );
      final before = await _resolve(
        withClosed,
        multiCurrencyGoalProgressProvider('house'),
      );
      final after = await _resolve(
        withoutClosed,
        multiCurrencyGoalProgressProvider('house'),
      );

      // The premise: the percent is the same, the velocity is not.
      expect(before!.displayPercent, 38);
      expect(after!.displayPercent, 38);
      expect(before.monthlyVelocity, closeTo(3333.33, 0.005));
      expect(after.monthlyVelocity, closeTo(0.0, 0.005));
      // The pinned scope: nothing is listed.
      expect(impacts, isEmpty);
    },
  );

  test('archiving does not change the goals themselves', () async {
    final container = _container(goals: [_house], investments: [_fund, _gold]);

    await _resolve(container, archiveGoalImpactProvider('fund'));
    final progress = await _resolve(
      container,
      multiCurrencyGoalProgressProvider('house'),
    );

    // The preview is a what-if: the real progress still counts the fund.
    expect(progress!.progressPercent, closeTo(76.0, 1e-6));
  });
}
