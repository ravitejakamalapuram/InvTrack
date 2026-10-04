// A10 (#754): the health score's returns component uses the XIRR that
// includes current values, and leaves out open investments that still need
// one instead of counting their fake −80% XIRR (money rule 4).
//
// A21: the returns XIRR is solved over the portfolio's cash flows and
// current values, so this test gives cash flows rather than per-investment
// XIRRs.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

final _asOf = DateTime(2026, 10, 4);

final _payoutFd = InvestmentEntity(
  id: 'fd',
  name: 'fd',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  interestPayoutMode: InterestPayoutMode.periodic,
  currency: 'INR',
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

final _gold = InvestmentEntity(
  id: 'gold',
  name: 'gold',
  type: InvestmentType.gold,
  status: InvestmentStatus.open,
  currency: 'INR',
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

CashFlowEntity _flow(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date,
) => CashFlowEntity(
  id: '$investmentId-${type.name}-${date.toIso8601String()}',
  investmentId: investmentId,
  type: type,
  amount: amount,
  currency: 'INR',
  date: date,
  createdAt: date,
);

// Payout FD valued at its principal (CALC-01 S2): ₹1,00,000 paying ₹1,750 a
// quarter.
final _fdFlows = [
  _flow('fd', CashFlowType.invest, 100000, DateTime(2025, 10, 4)),
  _flow('fd', CashFlowType.income, 1750, DateTime(2026, 1, 4)),
  _flow('fd', CashFlowType.income, 1750, DateTime(2026, 4, 4)),
  _flow('fd', CashFlowType.income, 1750, DateTime(2026, 7, 4)),
  _flow('fd', CashFlowType.income, 1750, DateTime(2026, 10, 4)),
];

// Gold with no value: its cash-only XIRR is meaningless.
final _goldFlows = [
  _flow('gold', CashFlowType.invest, 100000, DateTime(2026, 1, 15)),
];

PortfolioHealthScore? _score(
  List<InvestmentEntity> investments,
  List<CashFlowEntity> flows,
) {
  final terminalValues = <String, TerminalValues>{
    for (final inv in investments)
      inv.id: CurrentValueCalculator.terminalValues(
        investments: [inv],
        cashFlows: [
          for (final cf in flows)
            if (cf.investmentId == inv.id) cf,
        ],
        asOf: _asOf,
      ),
  };
  return PortfolioHealthCalculator.calculate(
    investments: investments,
    investmentStats: FinancialCalculatorModule().calculateStatsByInvestment(
      flows,
      terminalValues: terminalValues,
    ),
    allCashFlows: flows,
    goalProgress: const [],
    terminalValues: terminalValues,
    asOf: _asOf,
    benchmarkInflationRate: 0.06,
  );
}

void main() {
  test('an open holding awaiting a current value is left out', () {
    final score = _score([_payoutFd, _gold], [..._fdFlows, ..._goldFlows])!;

    // Only the FD counts: the same returns score as an FD-only portfolio.
    final fdOnly = _score([_payoutFd], _fdFlows)!;
    expect(score.returnsPerformance.score, fdOnly.returnsPerformance.score);
    expect(score.returnsPerformance.score, greaterThan(0));
  });
}
