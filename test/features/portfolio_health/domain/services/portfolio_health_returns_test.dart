// A21 (#769): the health score's returns component is one XIRR over the
// merged base-currency cash flows plus current values (CALC-02), an empty
// portfolio has not enough data for a score, and having no goals is neutral
// rather than a free 100 (ANLY-07).
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

final _asOf = DateTime(2026, 10, 4);

InvestmentEntity _investment(
  String id,
  InvestmentType type, {
  InvestmentStatus status = InvestmentStatus.open,
  double? expectedRate,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  currency: 'INR',
  expectedRate: expectedRate,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

CashFlowEntity _flow(
  String investmentId,
  CashFlowType type,
  double amount,
  DateTime date,
) => CashFlowEntity(
  id: '$investmentId-${date.toIso8601String()}-${type.name}',
  investmentId: investmentId,
  type: type,
  amount: amount,
  currency: 'INR',
  date: date,
  createdAt: date,
);

/// Scores [investments] the way the app does: current values from the A10
/// calculator, stats from the one stats implementation.
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
  test('a single open 7% FD with no goals is not scored Poor by its returns '
      'or its goals', () {
    // ₹1,00,000 on 1 Jul 2026 at 7% compounding yearly: its accrued value on
    // 4 Oct 2026 gives an XIRR of exactly 7%.
    final score = _score(
      [_investment('fd', InvestmentType.fixedDeposit, expectedRate: 7)],
      [_flow('fd', CashFlowType.invest, 100000, DateTime(2026, 7, 1))],
    )!;

    // 7% is 1 point above 6% inflation: 60 + (0.01 / 0.05) × 20 = 64.
    expect(score.returnsPerformance.score, closeTo(64.0, 1e-6));
    // No goals: neutral, neither a penalty nor a free 100.
    expect(score.goalAlignment.score, 50.0);
    // 0.30 × 64 + 0.25 × 0 (one type) + 0.20 × 60 (nothing maturing soon)
    // + 0.15 × 50 + 0.10 × 100 = 48.7.
    expect(score.overallScore, closeTo(48.7, 1e-6));
    expect(score.tier, ScoreTier.fair);
  });

  test('returns use one XIRR over the merged cash flows, not an average of '
      'XIRRs weighted by amount invested', () {
    // CALC-02: A earns 8.000% for a year, B 43.28% for 30 days. Merged-flow
    // XIRR 8.0245734%; the invested-weighted average would be 8.3493091%.
    final score = _score(
      [
        _investment(
          'a',
          InvestmentType.fixedDeposit,
          status: InvestmentStatus.closed,
        ),
        _investment(
          'b',
          InvestmentType.p2pLending,
          status: InvestmentStatus.closed,
        ),
      ],
      [
        _flow('a', CashFlowType.invest, 1000000, DateTime(2025, 1, 1)),
        _flow('a', CashFlowType.returnFlow, 1080000, DateTime(2026, 1, 1)),
        _flow('b', CashFlowType.invest, 10000, DateTime(2025, 6, 1)),
        _flow('b', CashFlowType.returnFlow, 10300, DateTime(2025, 7, 1)),
      ],
    )!;

    // 60 + ((0.0802457339 − 0.06) / 0.05) × 20.
    expect(score.returnsPerformance.score, closeTo(68.09829356, 1e-6));
  });

  test('an empty portfolio has not enough data for a score', () {
    final score = PortfolioHealthCalculator.calculate(
      investments: [],
      investmentStats: {},
      allCashFlows: [],
      goalProgress: [],
      asOf: _asOf,
    );

    expect(score, isNull);
  });

  test('a portfolio whose only holding still needs a current value has not '
      'enough data for a score', () {
    // Gold has no estimate: until the user enters a value its return is
    // unknown (money rule 4), so there is nothing to score returns on.
    final score = _score(
      [_investment('gold', InvestmentType.gold)],
      [_flow('gold', CashFlowType.invest, 100000, DateTime(2026, 1, 15))],
    );

    expect(score, isNull);
  });
}
