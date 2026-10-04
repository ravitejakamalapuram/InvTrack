// A11 (#755, PLAN-01, PLAN-02, CALC-03, ARCH-03, MKT-V-03): the FIRE corpus
// is what the open investments are worth today, not the money ever put in,
// and monthly savings are the net new money of the last 12 months.
//
// Expected values were computed independently in Python with
// today = 2026-10-02.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/planning_inputs_calculator.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

final _today = DateTime(2026, 10, 2);

InvestmentEntity _inv(
  String id,
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
  double? rate,
  InterestPayoutMode? payout,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
  expectedRate: rate,
  compoundingFrequency: CompoundingFrequency.quarterly,
  interestPayoutMode: payout,
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

/// A ₹10L FD renewed every April at 7% since 2020: each renewal returns the
/// principal, pays the interest as INCOME and reinvests both, so there are
/// six INVEST flows (₹71,53,290.74 in total) and ₹14,02,551.73 is invested
/// today.
final _rolloverFd = _inv('fd', InvestmentType.fixedDeposit);
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

Map<String, TerminalValues> _terminalValues(
  List<InvestmentEntity> investments,
  List<CashFlowEntity> flows,
) => {
  for (final inv in investments)
    inv.id: CurrentValueCalculator.terminalValues(
      investments: [inv],
      cashFlows: flows,
      asOf: _today,
    ),
};

void main() {
  group('PlanningInputsCalculator.corpus', () {
    test('a rolled-over FD counts once, at the principal invested today', () {
      final corpus = PlanningInputsCalculator.corpus(
        investments: [_rolloverFd],
        cashFlows: _rolloverFlows,
        terminalValues: _terminalValues([_rolloverFd], _rolloverFlows),
      );

      // The app counted every INVEST: ₹71,53,290.74.
      expect(corpus.total, closeTo(1402551.73, 0.005));
      expect(corpus.currentValues, closeTo(1402551.73, 0.005));
      expect(corpus.principalWithoutValue, 0);
      expect(corpus.valuedCount, 1);
      expect(corpus.principalOnlyCount, 0);
    });

    test('uses current values, falls back to principal still invested, and '
        'leaves out closed investments', () {
      // Cumulative FD ₹5L @7% quarterly from 2026-04-01 (184 days):
      // V = 5,00,000 × 1.0175^(4·184/365) = 5,17,800.771973 (A10 S4).
      final fd = _inv(
        'fd',
        InvestmentType.fixedDeposit,
        rate: 7,
        payout: InterestPayoutMode.cumulative,
      );
      // Gold has no estimate: ₹2L bought, ₹50k sold → ₹1.5L still invested.
      // The ₹1,000 fee is not capital.
      final gold = _inv('gold', InvestmentType.gold);
      // Fully repaid P2P loan: none of its capital is still invested.
      final p2p = _inv(
        'p2p',
        InvestmentType.p2pLending,
        status: InvestmentStatus.closed,
      );
      final investments = [fd, gold, p2p];
      final flows = [
        _cf('fd', CashFlowType.invest, 500000, DateTime(2026, 4, 1)),
        _cf('gold', CashFlowType.invest, 200000, DateTime(2025, 1, 10)),
        _cf('gold', CashFlowType.fee, 1000, DateTime(2025, 1, 10)),
        _cf('gold', CashFlowType.returnFlow, 50000, DateTime(2026, 2, 1)),
        _cf('p2p', CashFlowType.invest, 1000000, DateTime(2024, 1, 1)),
        _cf('p2p', CashFlowType.returnFlow, 1120000, DateTime(2025, 1, 1)),
      ];

      final corpus = PlanningInputsCalculator.corpus(
        investments: investments,
        cashFlows: flows,
        terminalValues: _terminalValues(investments, flows),
      );

      expect(corpus.currentValues, closeTo(517800.77, 0.005));
      expect(corpus.principalWithoutValue, closeTo(150000.00, 0.005));
      expect(corpus.total, closeTo(667800.77, 0.005));
      expect(corpus.valuedCount, 1);
      expect(corpus.principalOnlyCount, 1);
    });

    test('an open investment that returned more than it cost counts as 0', () {
      final gold = _inv('gold', InvestmentType.gold);
      final flows = [
        _cf('gold', CashFlowType.invest, 100000, DateTime(2024, 1, 1)),
        _cf('gold', CashFlowType.returnFlow, 150000, DateTime(2025, 1, 1)),
      ];

      final corpus = PlanningInputsCalculator.corpus(
        investments: [gold],
        cashFlows: flows,
        terminalValues: _terminalValues([gold], flows),
      );

      expect(corpus.total, 0);
    });
  });

  group('PlanningInputsCalculator.monthlySavings', () {
    test('two INVEST flows 10 days apart are not enough history', () {
      // PLAN-02 S2: the app divided ₹10L by 0.333 months = ₹30L/month.
      final flows = [
        _cf('a', CashFlowType.invest, 500000, DateTime(2026, 9, 20)),
        _cf('a', CashFlowType.invest, 500000, DateTime(2026, 9, 30)),
      ];

      final savings = PlanningInputsCalculator.monthlySavings(
        cashFlows: flows,
        asOf: _today,
      );

      expect(savings.amount, isNull);
      expect(savings.hasEnoughHistory, isFalse);
      expect(savings.monthsOfHistory, 0);
    });

    test('is the net new money of the last 12 months, divided by 12', () {
      final flows = [
        // Before the window: history only.
        _cf('a', CashFlowType.invest, 100000, DateTime(2025, 1, 15)),
        // 2 Oct 2025 is exactly 12 months back and is outside the window.
        _cf('a', CashFlowType.invest, 70000, DateTime(2025, 10, 2)),
        _cf('a', CashFlowType.invest, 240000, DateTime(2026, 3, 1)),
        _cf('a', CashFlowType.returnFlow, 60000, DateTime(2026, 6, 1)),
        // Income and fees are not new money.
        _cf('a', CashFlowType.income, 9000, DateTime(2026, 6, 1)),
        _cf('a', CashFlowType.fee, 500, DateTime(2026, 6, 1)),
        // Not yet happened.
        _cf('a', CashFlowType.invest, 999999, DateTime(2026, 12, 1)),
      ];

      final savings = PlanningInputsCalculator.monthlySavings(
        cashFlows: flows,
        asOf: _today,
      );

      // (2,40,000 − 60,000) ÷ 12
      expect(savings.amount, closeTo(15000.00, 0.005));
      expect(savings.monthsOfHistory, 20);
    });

    test('a rollover adds no new money', () {
      final savings = PlanningInputsCalculator.monthlySavings(
        cashFlows: _rolloverFlows,
        asOf: _today,
      );

      expect(savings.amount, 0);
      expect(savings.monthsOfHistory, 78);
    });

    test('with 3 to 12 months of history, still divides by 12', () {
      // Trailing-12-month net new money (A11): ₹1,20,000 ÷ 12. Dividing by
      // the 6 months of history (₹20,000) treated money put in once as a
      // monthly saving.
      final flows = [
        _cf('a', CashFlowType.invest, 60000, DateTime(2026, 4, 2)),
        _cf('a', CashFlowType.invest, 60000, DateTime(2026, 7, 2)),
      ];

      final savings = PlanningInputsCalculator.monthlySavings(
        cashFlows: flows,
        asOf: _today,
      );

      expect(savings.monthsOfHistory, 6);
      expect(savings.amount, closeTo(10000.00, 0.005));
    });

    test('a lump sum is not a monthly saving once 3 months have passed', () {
      // ₹10L put in over 10 days in September, nothing since: ₹83,333.33 a
      // month over 12 months, not ₹3,33,333.33 over the 3 months of history.
      final flows = [
        _cf('a', CashFlowType.invest, 500000, DateTime(2026, 9, 20)),
        _cf('a', CashFlowType.invest, 500000, DateTime(2026, 9, 30)),
      ];

      final savings = PlanningInputsCalculator.monthlySavings(
        cashFlows: flows,
        asOf: DateTime(2026, 12, 20),
      );

      expect(savings.monthsOfHistory, 3);
      expect(savings.amount, closeTo(83333.33, 0.005));
    });

    test('money taken out is never negative savings', () {
      final flows = [
        _cf('a', CashFlowType.invest, 100000, DateTime(2024, 1, 1)),
        _cf('a', CashFlowType.returnFlow, 100000, DateTime(2026, 5, 1)),
      ];

      final savings = PlanningInputsCalculator.monthlySavings(
        cashFlows: flows,
        asOf: _today,
      );

      expect(savings.amount, 0);
    });
  });

  group('PlanningInputsCalculator.addMonths', () {
    test('adds calendar months and clamps the day', () {
      expect(
        PlanningInputsCalculator.addMonths(DateTime(2026, 10, 2), 13),
        DateTime(2027, 11, 2),
      );
      expect(
        PlanningInputsCalculator.addMonths(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
      expect(
        PlanningInputsCalculator.addMonths(DateTime(2027, 12, 31), 2),
        DateTime(2028, 2, 29),
      );
    });

    test('counts whole months between two dates', () {
      expect(
        PlanningInputsCalculator.wholeMonthsBetween(
          DateTime(2026, 4, 2),
          DateTime(2026, 10, 2),
        ),
        6,
      );
      expect(
        PlanningInputsCalculator.wholeMonthsBetween(
          DateTime(2026, 4, 3),
          DateTime(2026, 10, 2),
        ),
        5,
      );
    });
  });
}
