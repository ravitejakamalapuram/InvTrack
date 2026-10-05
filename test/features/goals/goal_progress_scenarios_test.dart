// A12 (#756, PLAN-08, PLAN-09): what a goal has reached.
//
// A corpus goal holds the current value of its open investments (A10), not
// the coupons and returns they paid out. An income goal earns the INCOME of
// its open investments over the last 12 months, per month held, not the
// payouts divided by the span between the first and the last of them.
//
// These scenarios go through GoalProgressCalculator.calculateMultiCurrency,
// the path the goal notifications use. Dates are relative to today because
// that path values investments as of today.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/planning_inputs_calculator.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import '../../mocks/mock_currency_conversion_service.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
DateTime _monthsAgo(int months) =>
    PlanningInputsCalculator.addMonths(_today, -months);

GoalEntity _goal({
  GoalType type = GoalType.targetAmount,
  double target = 1000000,
  double? monthlyIncome,
  List<String> linked = const ['inv'],
  String currency = 'INR',
}) => GoalEntity(
  id: 'goal',
  name: 'Goal',
  type: type,
  targetAmount: target,
  targetMonthlyIncome: monthlyIncome,
  trackingMode: GoalTrackingMode.selected,
  linkedInvestmentIds: linked,
  icon: '🎯',
  colorValue: 0xFF3B82F6,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  currency: currency,
);

InvestmentEntity _inv(
  String id,
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
  InterestPayoutMode? payout,
  double? rate,
  String currency = 'INR',
  double? currentValue,
  DateTime? currentValueDate,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  interestPayoutMode: payout,
  expectedRate: rate,
  currency: currency,
  currentValue: currentValue,
  currentValueDate: currentValueDate,
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

void main() {
  final converter = BatchCurrencyConverter(MockCurrencyConversionService());

  Future<GoalProgress> progressOf(
    GoalEntity goal,
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  ) => GoalProgressCalculator.calculateMultiCurrency(
    goal: goal,
    allInvestments: investments,
    allCashFlows: cashFlows,
    batchConverter: converter,
    baseCurrency: 'INR',
  );

  group('G1: corpus goal funded by a payout FD', () {
    // ₹10L FD at 7.5% paying ₹18,750 every quarter, seven payouts so far
    // (₹1,31,250, which the old calculation showed as 13.1%).
    final fd = _inv(
      'inv',
      InvestmentType.fixedDeposit,
      payout: InterestPayoutMode.periodic,
      rate: 7.5,
    );
    final flows = [
      _cf('inv', CashFlowType.invest, 1000000, _monthsAgo(22)),
      for (var quarter = 1; quarter <= 7; quarter++)
        _cf('inv', CashFlowType.income, 18750, _monthsAgo(22 - 3 * quarter)),
    ];

    test('a ₹10L goal shows 100% and achieved, not 13.1%', () async {
      final progress = await progressOf(_goal(), [fd], flows);

      expect(progress.currentAmount, closeTo(1000000.00, 0.005));
      expect(progress.progressPercent, closeTo(100.0, 1e-9));
      expect(progress.status, GoalStatus.achieved);
    });

    test('a closed investment holds nothing for the goal', () async {
      final closed = _inv(
        'inv',
        InvestmentType.fixedDeposit,
        status: InvestmentStatus.closed,
        payout: InterestPayoutMode.periodic,
        rate: 7.5,
      );
      final closedFlows = [
        ...flows,
        _cf('inv', CashFlowType.returnFlow, 1000000, _monthsAgo(1)),
      ];

      final progress = await progressOf(_goal(), [closed], closedFlows);

      expect(progress.currentAmount, 0.0);
      expect(progress.progressPercent, 0.0);
      expect(progress.status, GoalStatus.notStarted);
    });
  });

  group('G2/G3: income goal', () {
    final incomeGoal = _goal(
      type: GoalType.incomeTarget,
      target: 120000,
      monthlyIncome: 10000,
    );

    test(
      'G2: one ₹75,000 annual coupon is ₹6,250 a month, not achieved',
      () async {
        final bond = _inv('inv', InvestmentType.bonds);
        final flows = [
          _cf('inv', CashFlowType.invest, 1000000, _monthsAgo(14)),
          _cf('inv', CashFlowType.income, 75000, _monthsAgo(2)),
        ];

        final progress = await progressOf(incomeGoal, [bond], flows);

        expect(progress.monthlyIncome, closeTo(6250.00, 0.005));
        expect(progress.currentAmount, closeTo(6250.00, 0.005));
        expect(progress.progressPercent, closeTo(62.5, 1e-6));
        expect(progress.status, isNot(GoalStatus.achieved));
      },
    );

    test(
      'G3: two quarterly ₹18,750 payouts are ₹6,250 a month, not ₹9,375',
      () async {
        final fd = _inv(
          'inv',
          InvestmentType.fixedDeposit,
          payout: InterestPayoutMode.periodic,
          rate: 7.5,
        );
        final flows = [
          _cf('inv', CashFlowType.invest, 1000000, _monthsAgo(6)),
          _cf('inv', CashFlowType.income, 18750, _monthsAgo(3)),
          _cf('inv', CashFlowType.income, 18750, _today),
        ];

        final progress = await progressOf(incomeGoal, [fd], flows);

        expect(progress.monthlyIncome, closeTo(6250.00, 0.005));
      },
    );

    test(
      'income older than 12 months and from closed investments is left out',
      () async {
        final bond = _inv('inv', InvestmentType.bonds);
        final closed = _inv(
          'old',
          InvestmentType.bonds,
          status: InvestmentStatus.closed,
        );
        final flows = [
          _cf('inv', CashFlowType.invest, 1000000, _monthsAgo(26)),
          _cf('inv', CashFlowType.income, 75000, _monthsAgo(14)),
          _cf('inv', CashFlowType.income, 75000, _monthsAgo(2)),
          _cf('old', CashFlowType.invest, 500000, _monthsAgo(20)),
          _cf('old', CashFlowType.income, 40000, _monthsAgo(4)),
          _cf('old', CashFlowType.returnFlow, 500000, _monthsAgo(4)),
        ];

        final progress = await progressOf(
          _goal(
            type: GoalType.incomeTarget,
            target: 120000,
            monthlyIncome: 10000,
            linked: const ['inv', 'old'],
          ),
          [bond, closed],
          flows,
        );

        expect(progress.monthlyIncome, closeTo(6250.00, 0.005));
      },
    );
  });

  group('currency', () {
    test('a USD investment counts at its converted current value', () async {
      // \$800 invested, worth \$1,000 today: ₹83,000 at ₹83/\$ of a
      // ₹1,66,000 goal is 50%. The old calculation counted only RETURN and
      // INCOME, so it showed 0%.
      final stocks = _inv(
        'inv',
        InvestmentType.stocks,
        currency: 'USD',
        currentValue: 1000,
        currentValueDate: _today,
      );
      final flows = [
        _cf('inv', CashFlowType.invest, 800, _monthsAgo(6), currency: 'USD'),
      ];

      final progress = await progressOf(_goal(target: 166000), [stocks], flows);

      expect(progress.currentAmount, closeTo(83000.00, 0.005));
      expect(progress.progressPercent, closeTo(50.0, 1e-6));
    });
  });
}
