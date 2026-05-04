// Unit tests for Portfolio Health Calculator
//
// Tests the core calculation logic for all 5 components:
// - Returns Performance (XIRR vs inflation)
// - Diversification (Herfindahl index)
// - Liquidity (% maturing in 90 days)
// - Goal Alignment (% goals on track)
// - Action Readiness (overdue renewals, stale investments)
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

void main() {
  group('PortfolioHealthCalculator', () {
    test('returns default scores for empty portfolio', () {
      final score = PortfolioHealthCalculator.calculate(
        investments: [],
        investmentStats: {},
        allCashFlows: [],
        goalProgress: [],
      );

      // Empty portfolio gets 25 points overall:
      // - Goal Alignment: 100 * 0.15 weight = 15
      // - Action Readiness: 100 * 0.10 weight = 10
      // - Total: 15 + 10 = 25
      expect(score.overallScore, 25.0);
      expect(score.returnsPerformance.score, 0.0);
      expect(score.diversification.score, 0.0);
      expect(score.liquidity.score, 0.0);
      expect(score.goalAlignment.score, 100.0); // No goals = no misalignment
      expect(score.actionReadiness.score, 100.0); // No investments = all up to date
    });

    test('validates benchmark inflation rate - replaces invalid values', () {
      final investment = InvestmentEntity(
        id: '1',
        name: 'Test',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stats = <String, InvestmentStats>{
        '1': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 0,
          netCashFlow: 100000,
          absoluteReturn: 0,
          moic: 1.0,
          xirr: 0.08, // 8%
          cashFlowCount: 1,
        ),
      };

      // Test with NaN inflation - should use default 6%
      final scoreNan = PortfolioHealthCalculator.calculate(
        investments: [investment],
        investmentStats: stats,
        allCashFlows: [],
        goalProgress: [],
        benchmarkInflationRate: double.nan,
      );

      expect(scoreNan.returnsPerformance.score, greaterThan(0));

      // Test with negative inflation - should use default 6%
      final scoreNegative = PortfolioHealthCalculator.calculate(
        investments: [investment],
        investmentStats: stats,
        allCashFlows: [],
        goalProgress: [],
        benchmarkInflationRate: -0.05,
      );

      expect(scoreNegative.returnsPerformance.score, greaterThan(0));
    });

    test('calculates weighted overall score correctly', () {
      final investment = InvestmentEntity(
        id: '1',
        name: 'Test',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stats = <String, InvestmentStats>{
        '1': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 0,
          netCashFlow: 100000,
          absoluteReturn: 0,
          moic: 1.0,
          xirr: 0.16, // 16% (Inflation + 10%) => 100 points
          cashFlowCount: 1,
        ),
      };

      final score = PortfolioHealthCalculator.calculate(
        investments: [investment],
        investmentStats: stats,
        allCashFlows: [],
        goalProgress: [],
        benchmarkInflationRate: 0.06,
      );

      // With 1 investment: diversification HHI = 1.0 => score = 0
      // No maturity date => liquidity = 60 points (<5%)
      // Expected: Returns 100 * 0.30 + Div 0 * 0.25 + Liquidity 60 * 0.20 + Goals 100 * 0.15 + Actions 100 * 0.10
      // = 30 + 0 + 12 + 15 + 10 = 67.0
      expect(score.overallScore, closeTo(67.0, 1.0));
      expect(score.returnsPerformance.score, 100.0);
      expect(score.diversification.score, 0.0);
      expect(score.liquidity.score, 60.0); // Low liquidity (<5%)
      expect(score.goalAlignment.score, 100.0);
      expect(score.actionReadiness.score, 100.0);
    });

    test('clamps overall score to 0-100 range', () {
      final investment = InvestmentEntity(
        id: '1',
        name: 'Test',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        maturityDate: DateTime.now().add(const Duration(days: 30)),
      );

      final stats = <String, InvestmentStats>{
        '1': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 0,
          netCashFlow: 100000,
          absoluteReturn: 0,
          moic: 1.0,
          xirr: 0.20, // Excellent XIRR
          cashFlowCount: 1,
        ),
      };

      final score = PortfolioHealthCalculator.calculate(
        investments: [investment],
        investmentStats: stats,
        allCashFlows: [],
        goalProgress: [],
        benchmarkInflationRate: 0.06,
      );

      expect(score.overallScore, greaterThanOrEqualTo(0.0));
      expect(score.overallScore, lessThanOrEqualTo(100.0));
    });

    test('all component weights sum to 1.0', () {
      final score = PortfolioHealthCalculator.calculate(
        investments: [],
        investmentStats: {},
        allCashFlows: [],
        goalProgress: [],
      );

      final totalWeight = score.returnsPerformance.weight +
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
      final investment = InvestmentEntity(
        id: '1',
        name: 'Great Return',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stats = <String, InvestmentStats>{
        '1': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 16000,
          netCashFlow: 16000,
          absoluteReturn: 16.0,
          moic: 1.16,
          xirr: 0.16, // 16% (6% inflation + 10%)
          cashFlowCount: 2,
        ),
      };

      final score = PortfolioHealthCalculator.calculate(
        investments: [investment],
        investmentStats: stats,
        allCashFlows: [],
        goalProgress: [],
        benchmarkInflationRate: 0.06,
      );

      expect(score.returnsPerformance.score, 100.0);
    });

    test('scores appropriately for XIRR between inflation and inflation+10%', () {
      final investment = InvestmentEntity(
        id: '1',
        name: 'Good Return',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stats = <String, InvestmentStats>{
        '1': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 11000,
          netCashFlow: 11000,
          absoluteReturn: 11.0,
          moic: 1.11,
          xirr: 0.11, // 11% (between 6% and 16%)
          cashFlowCount: 2,
        ),
      };

      final score = PortfolioHealthCalculator.calculate(
        investments: [investment],
        investmentStats: stats,
        allCashFlows: [],
        goalProgress: [],
        benchmarkInflationRate: 0.06,
      );

      expect(score.returnsPerformance.score, greaterThan(60.0));
      expect(score.returnsPerformance.score, lessThan(100.0));
    });

    test('scores low for negative XIRR', () {
      final investment = InvestmentEntity(
        id: '1',
        name: 'Loss Making',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stats = <String, InvestmentStats>{
        '1': const InvestmentStats(
          totalInvested: 100000,
          totalReturned: 0,
          netCashFlow: -5000,
          absoluteReturn: -5.0,
          moic: 0.95,
          xirr: -0.05, // -5% loss
          cashFlowCount: 2,
        ),
      };

      final score = PortfolioHealthCalculator.calculate(
        investments: [investment],
        investmentStats: stats,
        allCashFlows: [],
        goalProgress: [],
        benchmarkInflationRate: 0.06,
      );

      expect(score.returnsPerformance.score, lessThan(40.0));
      expect(score.returnsPerformance.suggestions, isNotEmpty);
      expect(
        score.returnsPerformance.suggestions.any((s) => s.contains('Negative returns')),
        isTrue,
      );
    });

    test('calculates weighted XIRR across multiple investments', () {
      final investments = [
        InvestmentEntity(
          id: '1',
          name: 'Large FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InvestmentEntity(
          id: '2',
          name: 'Small P2P',
          type: InvestmentType.p2pLending,
          status: InvestmentStatus.open,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final stats = <String, InvestmentStats>{
        '1': const InvestmentStats(
          totalInvested: 90000, // 90% weight
          totalReturned: 0,
          netCashFlow: 90000,
          absoluteReturn: 0,
          moic: 1.0,
          xirr: 0.07, // 7%
          cashFlowCount: 1,
        ),
        '2': const InvestmentStats(
          totalInvested: 10000, // 10% weight
          totalReturned: 0,
          netCashFlow: 10000,
          absoluteReturn: 0,
          moic: 1.0,
          xirr: 0.15, // 15%
          cashFlowCount: 1,
        ),
      };

      final score = PortfolioHealthCalculator.calculate(
        investments: investments,
        investmentStats: stats,
        allCashFlows: [],
        goalProgress: [],
        benchmarkInflationRate: 0.06,
      );

      // Weighted XIRR = (90000 * 0.07 + 10000 * 0.15) / 100000 = 7.8%
      // Should be scored between 60-80 (above inflation but below inflation+5%)
      expect(score.returnsPerformance.score, greaterThan(60.0));
      expect(score.returnsPerformance.score, lessThan(80.0));
    });
  });
}
