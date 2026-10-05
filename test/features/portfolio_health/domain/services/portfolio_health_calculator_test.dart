// Unit tests for Portfolio Health Calculator
//
// Tests the core calculation logic for all 5 components:
// - Returns Performance (portfolio XIRR vs inflation)
// - Diversification (Herfindahl index)
// - Liquidity (% maturing in 90 days)
// - Goal Alignment (% goals on track)
// - Action Readiness (overdue renewals, stale investments)
//
// A21: the returns component is one XIRR over the portfolio's cash flows and
// current values, so these tests give cash flows rather than per-investment
// XIRRs. Every XIRR below is exact: one INVEST and one RETURN 365 days apart.
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
  InvestmentStatus status = InvestmentStatus.closed,
  double? expectedRate,
  DateTime? maturityDate,
}) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: status,
  currency: 'INR',
  expectedRate: expectedRate,
  maturityDate: maturityDate,
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

/// ₹1,00,000 in on 1 Oct 2025 and [returned] back on 1 Oct 2026: an XIRR of
/// exactly returned / 1,00,000 − 1.
List<CashFlowEntity> _yearFlows(String investmentId, double returned) => [
  _flow(investmentId, CashFlowType.invest, 100000, DateTime(2025, 10, 1)),
  _flow(investmentId, CashFlowType.returnFlow, returned, DateTime(2026, 10, 1)),
];

PortfolioHealthScore? _score(
  List<InvestmentEntity> investments,
  List<CashFlowEntity> flows, {
  double benchmarkInflationRate = 0.06,
}) {
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
    benchmarkInflationRate: benchmarkInflationRate,
  );
}

void main() {
  group('PortfolioHealthCalculator', () {
    // Previously an empty portfolio scored 25 "Poor": goals 100 and actions
    // 100 for having nothing to judge (ANLY-07). It has no score now.
    test('has no score for an empty portfolio', () {
      final score = PortfolioHealthCalculator.calculate(
        investments: [],
        investmentStats: {},
        allCashFlows: [],
        goalProgress: [],
        asOf: _asOf,
      );

      expect(score, isNull);
    });

    test('validates benchmark inflation rate - replaces invalid values', () {
      final investments = [_investment('1', InvestmentType.fixedDeposit)];
      final flows = _yearFlows('1', 108000); // 8%

      // 8% against the default 6%: 60 + (0.02 / 0.05) × 20 = 68.
      final scoreNan = _score(
        investments,
        flows,
        benchmarkInflationRate: double.nan,
      )!;
      expect(scoreNan.returnsPerformance.score, closeTo(68.0, 1e-6));

      final scoreNegative = _score(
        investments,
        flows,
        benchmarkInflationRate: -0.05,
      )!;
      expect(scoreNegative.returnsPerformance.score, closeTo(68.0, 1e-6));
    });

    test('calculates weighted overall score correctly', () {
      // An open FD at 16% from 1 Jul 2026, valued by accrual on 4 Oct 2026:
      // an XIRR of exactly 16%.
      final score = _score(
        [
          _investment(
            '1',
            InvestmentType.fixedDeposit,
            status: InvestmentStatus.open,
            expectedRate: 16,
          ),
        ],
        [_flow('1', CashFlowType.invest, 100000, DateTime(2026, 7, 1))],
      )!;

      // With 1 investment: diversification HHI = 1.0 => score = 0
      // No maturity date => liquidity = 60 points (<5%)
      // No goals => neutral 50
      // Returns 100 * 0.30 + Div 0 * 0.25 + Liquidity 60 * 0.20
      // + Goals 50 * 0.15 + Actions 100 * 0.10 = 30 + 0 + 12 + 7.5 + 10
      // = 59.5
      expect(score.overallScore, closeTo(59.5, 1e-6));
      expect(score.returnsPerformance.score, closeTo(100.0, 1e-6));
      expect(score.diversification.score, 0.0);
      expect(score.liquidity.score, 60.0); // Low liquidity (<5%)
      expect(score.goalAlignment.score, 50.0);
      expect(score.actionReadiness.score, 100.0);
    });

    test('clamps overall score to 0-100 range', () {
      final score = _score(
        [
          _investment(
            '1',
            InvestmentType.fixedDeposit,
            status: InvestmentStatus.open,
            expectedRate: 20,
            maturityDate: DateTime(2026, 11, 3),
          ),
        ],
        [_flow('1', CashFlowType.invest, 100000, DateTime(2026, 7, 1))],
      )!;

      expect(score.overallScore, greaterThanOrEqualTo(0.0));
      expect(score.overallScore, lessThanOrEqualTo(100.0));
    });

    test('all component weights sum to 1.0', () {
      final score = _score([
        _investment('1', InvestmentType.fixedDeposit),
      ], _yearFlows('1', 108000))!;

      final totalWeight =
          score.returnsPerformance.weight +
          score.diversification.weight +
          score.liquidity.weight +
          score.goalAlignment.weight +
          score.actionReadiness.weight;

      expect(totalWeight, 1.0);
      expect(score.returnsPerformance.weight, 0.30);
      expect(score.diversification.weight, 0.25);
      expect(score.liquidity.weight, 0.20);
      expect(score.goalAlignment.weight, 0.15);
      expect(score.actionReadiness.weight, 0.10);
    });
  });

  group('Returns Performance Component', () {
    test('scores 100 for XIRR >= Inflation + 10%', () {
      final score = _score(
        [_investment('1', InvestmentType.p2pLending)],
        _yearFlows('1', 116000), // 16% (6% inflation + 10%)
      )!;

      expect(score.returnsPerformance.score, closeTo(100.0, 1e-6));
    });

    test(
      'scores appropriately for XIRR between inflation and inflation+5%',
      () {
        final score = _score(
          [_investment('1', InvestmentType.fixedDeposit)],
          _yearFlows('1', 109000), // 9%
        )!;

        // 60 + (0.03 / 0.05) × 20 = 72.
        expect(score.returnsPerformance.score, closeTo(72.0, 1e-6));
      },
    );

    test('scores low for negative XIRR', () {
      final score = _score(
        [_investment('1', InvestmentType.p2pLending)],
        _yearFlows('1', 95000), // −5%
      )!;

      // 20 + (−0.05 / 0.20) × 20 = 15.
      expect(score.returnsPerformance.score, closeTo(15.0, 1e-6));
      expect(score.returnsPerformance.suggestions, isNotEmpty);
      expect(
        score.returnsPerformance.suggestions.any(
          (s) => s.contains('Negative returns'),
        ),
        isTrue,
      );
    });

    test('solves one XIRR over the flows of several investments', () {
      // Same dates: ₹90,000 at 7% and ₹10,000 at 15% return ₹1,07,800 on
      // ₹1,00,000, an XIRR of 7.8%.
      final score = _score(
        [
          _investment('1', InvestmentType.fixedDeposit),
          _investment('2', InvestmentType.p2pLending),
        ],
        [
          _flow('1', CashFlowType.invest, 90000, DateTime(2025, 10, 1)),
          _flow('1', CashFlowType.returnFlow, 96300, DateTime(2026, 10, 1)),
          _flow('2', CashFlowType.invest, 10000, DateTime(2025, 10, 1)),
          _flow('2', CashFlowType.returnFlow, 11500, DateTime(2026, 10, 1)),
        ],
      )!;

      // 60 + (0.018 / 0.05) × 20 = 67.2.
      expect(score.returnsPerformance.score, closeTo(67.2, 1e-6));
    });
  });
}
