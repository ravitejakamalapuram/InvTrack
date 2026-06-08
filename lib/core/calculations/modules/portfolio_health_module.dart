import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/models/cash_flow_interface.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

/// Module for calculating portfolio health scores with proper weighting.
class PortfolioHealthModule implements CalculationModule {
  @override
  String get name => 'PortfolioHealth';

  /// Calculates a unified health score (0-100) based on weighted components.
  ///
  /// Expects pre-converted stats (amounts converted to a base currency)
  /// to ensure correct mathematical weightings (Returns XIRR, Diversification HHI, Liquidity ratios).
  PortfolioHealthScore calculate({
    required List<InvestmentEntity> investments,
    required Map<String, InvestmentStats> investmentStats,
    required List<ICashFlow> allCashFlows,
    required List<GoalProgress> goalProgress,
    double benchmarkInflationRate = PortfolioHealthCalculator.defaultInflationRate,
  }) {
    return PortfolioHealthCalculator.calculate(
      investments: investments,
      investmentStats: investmentStats,
      allCashFlows: allCashFlows,
      goalProgress: goalProgress,
      benchmarkInflationRate: benchmarkInflationRate,
    );
  }
}
