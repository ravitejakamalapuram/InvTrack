// A10 (#754): the health score's returns component uses the XIRR that
// includes current values, and leaves out open investments that still need
// one instead of counting their fake −80% XIRR (money rule 4).
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

InvestmentEntity _inv(String id, InvestmentType type) => InvestmentEntity(
  id: id,
  name: id,
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

void main() {
  test('an open holding awaiting a current value is left out', () {
    final score = PortfolioHealthCalculator.calculate(
      investments: [
        _inv('fd', InvestmentType.fixedDeposit),
        _inv('gold', InvestmentType.gold),
      ],
      investmentStats: {
        // Payout FD valued at its principal (CALC-01 S2): 7.71%.
        'fd': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 15000,
          netCashFlow: -85000,
          absoluteReturn: 15,
          moic: 1.15,
          xirr: 0.077137789,
          cashFlowCount: 9,
          currentValue: 100000,
          currentValueIsEstimate: true,
        ),
        // Gold with no value: its cash-only XIRR is meaningless.
        'gold': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 0,
          netCashFlow: -100000,
          absoluteReturn: -100,
          moic: 0,
          xirr: -0.80,
          cashFlowCount: 1,
          missingValueCount: 1,
        ),
      },
      allCashFlows: [],
      goalProgress: [],
      benchmarkInflationRate: 0.06,
    );

    // Only the FD counts: 7.71% is between inflation (6%) and
    // inflation + 5% (11%), the same band as an FD-only portfolio.
    final fdOnly = PortfolioHealthCalculator.calculate(
      investments: [_inv('fd', InvestmentType.fixedDeposit)],
      investmentStats: {
        'fd': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 15000,
          netCashFlow: -85000,
          absoluteReturn: 15,
          moic: 1.15,
          xirr: 0.077137789,
          cashFlowCount: 9,
        ),
      },
      allCashFlows: [],
      goalProgress: [],
      benchmarkInflationRate: 0.06,
    );
    expect(score.returnsPerformance.score, fdOnly.returnsPerformance.score);
    expect(score.returnsPerformance.score, greaterThan(0));
  });
}
