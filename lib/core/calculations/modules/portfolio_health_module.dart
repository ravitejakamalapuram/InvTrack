import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

/// Module for calculating portfolio health scores with proper multi-currency weighting.
class PortfolioHealthModule implements CalculationModule {
  final CalculationEngine _engine;

  PortfolioHealthModule(this._engine);

  @override
  String get name => 'PortfolioHealth';

  /// Calculates a unified health score (0-100) based on weighted components.
  ///
  /// Automatically converts any unconverted investment stats to the [baseCurrency]
  /// to ensure correct mathematical weightings (Returns XIRR, Diversification HHI, Liquidity ratios).
  Future<PortfolioHealthScore> calculate({
    required List<InvestmentEntity> investments,
    required Map<String, InvestmentStats> investmentStats,
    required List<CashFlowEntity> allCashFlows,
    required List<GoalProgress> goalProgress,
    required String baseCurrency,
    double benchmarkInflationRate = PortfolioHealthCalculator.defaultInflationRate,
  }) async {
    final convertedStats = <String, InvestmentStats>{};

    for (final inv in investments) {
      final stat = investmentStats[inv.id];
      if (stat == null) continue;

      if (inv.currency == baseCurrency) {
        convertedStats[inv.id] = stat;
      } else {
        // Convert monetary amounts to base currency.
        // Ratios and percentages (XIRR, CAGR, MOIC, absolute return) remain unchanged.
        final convertedInvested = await _engine.currency.convert(
          amount: stat.totalInvested,
          from: inv.currency,
          to: baseCurrency,
        );

        final convertedReturned = await _engine.currency.convert(
          amount: stat.totalReturned,
          from: inv.currency,
          to: baseCurrency,
        );

        convertedStats[inv.id] = InvestmentStats(
          totalInvested: convertedInvested,
          totalReturned: convertedReturned,
          netCashFlow: convertedReturned - convertedInvested,
          absoluteReturn: stat.absoluteReturn,
          moic: stat.moic,
          xirr: stat.xirr,
          cashFlowCount: stat.cashFlowCount,
          firstCashFlowDate: stat.firstCashFlowDate,
          lastCashFlowDate: stat.lastCashFlowDate,
        );
      }
    }

    return PortfolioHealthCalculator.calculate(
      investments: investments,
      investmentStats: convertedStats,
      allCashFlows: allCashFlows,
      goalProgress: goalProgress,
      benchmarkInflationRate: benchmarkInflationRate,
    );
  }
}
