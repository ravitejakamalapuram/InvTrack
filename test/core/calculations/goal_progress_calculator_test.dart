// A12 (#756, PLAN-08..11): goal progress, the one implementation every goal
// screen, alert and report reads (money rule 3).
//
// Today is pinned to 2026-10-04. Expected values were computed
// independently in Python: PMT = (FV − PV·(1+r)ⁿ)·r / ((1+r)ⁿ − 1) and
// n = ln((FV·r + PMT) / (PV·r + PMT)) / ln(1 + r), with r = 8% / 12.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/goal_progress_calculator.dart';
import 'package:inv_tracker/core/calculations/planning_inputs_calculator.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

final _today = DateTime(2026, 10, 4);

GoalEntity _goal({
  String id = 'goal',
  GoalType type = GoalType.targetAmount,
  double target = 1000000,
  double? monthlyIncome,
  DateTime? targetDate,
  GoalTrackingMode mode = GoalTrackingMode.selected,
  List<String> linked = const ['fd'],
  List<InvestmentType> types = const [],
  bool isArchived = false,
}) => GoalEntity(
  id: id,
  name: id,
  type: type,
  targetAmount: target,
  targetMonthlyIncome: monthlyIncome,
  targetDate: targetDate,
  trackingMode: mode,
  linkedInvestmentIds: linked,
  linkedTypes: types,
  icon: '🎯',
  colorValue: 0xFF3B82F6,
  isArchived: isArchived,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  currency: 'INR',
);

InvestmentEntity _inv(
  String id,
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  interestPayoutMode: InterestPayoutMode.periodic,
  expectedRate: 7.5,
  currency: 'INR',
);

CashFlowEntity _cf(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date,
) => CashFlowEntity(
  id: '$investmentId-${type.name}-${date.toIso8601String()}',
  investmentId: investmentId,
  type: type,
  amount: amount,
  date: date,
  createdAt: date,
  currency: 'INR',
);

GoalProgress _progress(
  GoalEntity goal,
  List<InvestmentEntity> investments,
  List<CashFlowEntity> flows, {
  double? target,
  int otherGoalsCount = 0,
}) => GoalProgressCalculator.calculate(
  goal: goal,
  investments: investments,
  cashFlows: flows,
  terminalValues: {
    for (final inv in investments)
      inv.id: CurrentValueCalculator.terminalValues(
        investments: [inv],
        cashFlows: flows,
        asOf: _today,
      ),
  },
  targetAmount:
      target ??
      (goal.isIncomeGoal ? goal.targetMonthlyIncome! : goal.targetAmount),
  asOf: _today,
  otherGoalsCount: otherGoalsCount,
);

void main() {
  group('required per month', () {
    test('₹10L in 36 months at 8% with ₹2L saved is ₹18,402.43', () {
      expect(
        PlanningInputsCalculator.requiredMonthlyContribution(
          target: 1000000,
          current: 200000,
          months: 36,
          annualRatePercent: 8,
        ),
        closeTo(18402.43, 0.005),
      );
    });

    test('is nothing once growth alone reaches the target', () {
      expect(
        PlanningInputsCalculator.requiredMonthlyContribution(
          target: 1000000,
          current: 900000,
          months: 36,
          annualRatePercent: 8,
        ),
        0.0,
      );
    });

    test('without growth it is the gap spread over the months', () {
      expect(
        PlanningInputsCalculator.requiredMonthlyContribution(
          target: 1000000,
          current: 200000,
          months: 40,
          annualRatePercent: 0,
        ),
        closeTo(20000.00, 0.005),
      );
    });
  });

  group('corpus goal with a deadline', () {
    // ₹2L in a payout FD since 2026-04-04, nothing else. The deadline is
    // 36 months away and ₹2L of net new money over 6 months is
    // ₹33,333.33 a month.
    final goal = _goal(targetDate: DateTime(2029, 10, 4));
    final fd = _inv('fd', InvestmentType.fixedDeposit);
    final flows = [
      _cf('fd', CashFlowType.invest, 200000, DateTime(2026, 4, 4)),
    ];

    test('needs ₹18,402.43 a month and is projected with compounding', () {
      final progress = _progress(goal, [fd], flows);

      expect(progress.currentAmount, closeTo(200000.00, 0.005));
      expect(progress.targetAmount, 1000000.0);
      expect(progress.progressPercent, closeTo(20.0, 1e-9));
      expect(progress.requiredMonthly, closeTo(18402.43, 0.005));
      expect(progress.monthlyVelocity, closeTo(33333.33, 0.005));
      // n = 21.5366 months, rounded up: 2028-08-04, 14 months early.
      expect(progress.projectedCompletionDate, DateTime(2028, 8, 4));
      expect(progress.status, GoalStatus.ahead);
    });

    test('without savings the corpus still compounds', () {
      // n = ln(5) / ln(1 + 0.08/12) = 242.2 months: after the deadline.
      final old = [
        _cf('fd', CashFlowType.invest, 200000, DateTime(2024, 4, 4)),
      ];
      final progress = _progress(goal, [fd], old);

      expect(progress.monthlyVelocity, 0.0);
      expect(
        progress.projectedCompletionDate,
        PlanningInputsCalculator.addMonths(_today, 243),
      );
      expect(progress.status, GoalStatus.behind);
    });

    test('a passed deadline is behind and needs no monthly amount', () {
      final progress = _progress(_goal(targetDate: DateTime(2026, 9, 1)), [
        fd,
      ], flows);

      expect(progress.status, GoalStatus.behind);
      expect(progress.requiredMonthly, isNull);
    });

    test('a goal without a deadline has no required monthly amount', () {
      expect(_progress(_goal(), [fd], flows).requiredMonthly, isNull);
    });

    test('progress is measured against the converted target', () {
      // A goal entered as \$12,048.19 is ₹10,00,000 at ₹83/\$.
      final progress = _progress(goal, [fd], flows, target: 1000000);
      expect(progress.targetAmount, 1000000.0);
      expect(progress.progressPercent, closeTo(20.0, 1e-9));
    });
  });

  group('income goal', () {
    test('compares monthly income with the monthly income target', () {
      final goal = _goal(
        type: GoalType.incomeTarget,
        target: 1200000,
        monthlyIncome: 10000,
        linked: const ['bond'],
      );
      final bond = _inv('bond', InvestmentType.bonds);
      final flows = [
        _cf('bond', CashFlowType.invest, 1000000, DateTime(2025, 1, 4)),
        _cf('bond', CashFlowType.income, 75000, DateTime(2026, 1, 4)),
      ];

      final progress = _progress(goal, [bond], flows);

      expect(progress.monthlyIncome, closeTo(6250.00, 0.005));
      expect(progress.currentAmount, closeTo(6250.00, 0.005));
      expect(progress.targetAmount, 10000.0);
      expect(progress.progressPercent, closeTo(62.5, 1e-9));
      expect(progress.status, GoalStatus.onTrack);
      expect(progress.requiredMonthly, isNull);
    });
  });

  group('monthly income', () {
    test('G3: two quarterly payouts over 6 months held are ₹6,250 a month', () {
      final fd = _inv('fd', InvestmentType.fixedDeposit);
      expect(
        PlanningInputsCalculator.monthlyIncome(
          investments: [fd],
          cashFlows: [
            _cf('fd', CashFlowType.invest, 1000000, DateTime(2026, 4, 4)),
            _cf('fd', CashFlowType.income, 18750, DateTime(2026, 7, 4)),
            _cf('fd', CashFlowType.income, 18750, DateTime(2026, 10, 4)),
          ],
          asOf: _today,
        ),
        closeTo(6250.00, 0.005),
      );
    });

    test('each investment is spread over the months it has been held', () {
      // ₹75,000 over 12 months plus ₹9,000 over 3 months.
      final bond = _inv('bond', InvestmentType.bonds);
      final p2p = _inv('p2p', InvestmentType.p2pLending);
      expect(
        PlanningInputsCalculator.monthlyIncome(
          investments: [bond, p2p],
          cashFlows: [
            _cf('bond', CashFlowType.invest, 1000000, DateTime(2024, 1, 4)),
            _cf('bond', CashFlowType.income, 75000, DateTime(2025, 10, 5)),
            _cf('bond', CashFlowType.income, 75000, DateTime(2025, 10, 4)),
            _cf('p2p', CashFlowType.invest, 300000, DateTime(2026, 7, 4)),
            _cf('p2p', CashFlowType.income, 9000, DateTime(2026, 9, 30)),
          ],
          asOf: _today,
        ),
        closeTo(6250.00 + 3000.00, 0.005),
      );
    });

    test('income after today has not been earned yet', () {
      final bond = _inv('bond', InvestmentType.bonds);
      expect(
        PlanningInputsCalculator.monthlyIncome(
          investments: [bond],
          cashFlows: [
            _cf('bond', CashFlowType.invest, 1000000, DateTime(2024, 1, 4)),
            _cf('bond', CashFlowType.income, 75000, DateTime(2026, 10, 5)),
          ],
          asOf: _today,
        ),
        0.0,
      );
    });
  });

  group('linked investments', () {
    final fd = _inv('fd', InvestmentType.fixedDeposit);
    final bond = _inv('bond', InvestmentType.bonds);
    final closedFd = _inv(
      'closed',
      InvestmentType.fixedDeposit,
      status: InvestmentStatus.closed,
    );
    final all = [fd, bond, closedFd];

    test('follow the tracking mode', () {
      List<String> ids(GoalEntity goal) => [
        for (final inv in GoalProgressCalculator.linkedInvestments(goal, all))
          inv.id,
      ];

      expect(ids(_goal(mode: GoalTrackingMode.all)), ['fd', 'bond', 'closed']);
      expect(
        ids(
          _goal(
            mode: GoalTrackingMode.byType,
            types: const [InvestmentType.fixedDeposit],
          ),
        ),
        ['fd', 'closed'],
      );
      expect(ids(_goal(linked: const ['bond', 'gone'])), ['bond']);
    });

    test('count the other active goals that also count them', () {
      final selected = _goal(id: 'a', linked: const ['fd']);
      final byType = _goal(
        id: 'b',
        mode: GoalTrackingMode.byType,
        types: const [InvestmentType.fixedDeposit],
      );
      final bondOnly = _goal(id: 'c', linked: const ['bond']);
      final closedOnly = _goal(id: 'd', linked: const ['closed']);
      final archived = _goal(id: 'e', linked: const ['fd'], isArchived: true);
      final goals = [selected, byType, bondOnly, closedOnly, archived];

      int shared(GoalEntity goal) =>
          GoalProgressCalculator.otherGoalsSharing(goal, goals, all);

      expect(shared(selected), 1); // b also counts the FD
      expect(shared(byType), 1); // a; the closed FD counts in no goal
      expect(shared(bondOnly), 0);
      expect(shared(closedOnly), 0);
      expect(shared(archived), 2); // a and b, but not itself
    });

    test('the count is carried on the progress', () {
      final progress = _progress(
        _goal(),
        [fd],
        [_cf('fd', CashFlowType.invest, 200000, DateTime(2026, 4, 4))],
        otherGoalsCount: 2,
      );
      expect(progress.otherGoalsCount, 2);
    });
  });

  group('one rounding rule for goal %', () {
    test('whole percent rounds down and stays within 0–100', () {
      expect(GoalProgress.wholePercent(99.6), 99);
      expect(GoalProgress.wholePercent(25), 25);
      expect(GoalProgress.wholePercent(100), 100);
      expect(GoalProgress.wholePercent(130), 100);
      expect(GoalProgress.wholePercent(-4), 0);
      expect(GoalProgress.wholePercent(double.nan), 0);
      expect(GoalProgress.wholePercent(double.infinity), 0);
    });
  });
}
