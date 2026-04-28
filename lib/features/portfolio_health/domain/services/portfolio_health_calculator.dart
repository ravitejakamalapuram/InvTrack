import 'dart:math';

import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';

/// Portfolio Health Score Calculator
///
/// Calculates a unified health score (0-100) based on 5 weighted components:
/// - Returns Performance (30%): XIRR vs inflation/benchmarks
/// - Diversification (25%): Herfindahl index across types/platforms
/// - Liquidity (20%): % maturing in next 90 days
/// - Goal Alignment (15%): On-track vs behind goals
/// - Action Readiness (10%): Overdue renewals, stale investments
class PortfolioHealthCalculator {
  /// Default benchmark inflation rate (India annual average)
  static const double defaultInflationRate = 0.06; // 6%

  /// Calculate portfolio health score
  static PortfolioHealthScore calculate({
    required List<InvestmentEntity> investments,
    required Map<String, InvestmentStats> investmentStats,
    required List<CashFlowEntity> allCashFlows,
    required List<GoalProgress> goalProgress,
    double benchmarkInflationRate = defaultInflationRate,
  }) {
    // Validate benchmarkInflationRate to prevent NaN/Infinity propagation
    // Replace invalid values with defaultInflationRate
    double validatedInflationRate = benchmarkInflationRate;
    if (!benchmarkInflationRate.isFinite || benchmarkInflationRate <= 0.0) {
      validatedInflationRate = defaultInflationRate;
    }

    // Calculate each component
    final returns = _calculateReturnsScore(
      investments,
      investmentStats,
      validatedInflationRate,
    );
    final diversification = _calculateDiversificationScore(
      investments,
      investmentStats,
    );
    final liquidity = _calculateLiquidityScore(investments, investmentStats);
    final goals = _calculateGoalAlignmentScore(goalProgress);
    final actions = _calculateActionReadinessScore(investments, allCashFlows);

    // Calculate weighted overall score
    final overall =
        returns.weightedScore +
        diversification.weightedScore +
        liquidity.weightedScore +
        goals.weightedScore +
        actions.weightedScore;

    return PortfolioHealthScore(
      overallScore: overall.clamp(0.0, 100.0),
      returnsPerformance: returns,
      diversification: diversification,
      liquidity: liquidity,
      goalAlignment: goals,
      actionReadiness: actions,
      calculatedAt: DateTime.now(),
    );
  }

  /// Component 1: Returns Performance (30% weight)
  /// Score based on portfolio XIRR vs inflation
  static ComponentScore _calculateReturnsScore(
    List<InvestmentEntity> investments,
    Map<String, InvestmentStats> stats,
    double benchmarkInflationRate,
  ) {
    if (investments.isEmpty || stats.isEmpty) {
      return ComponentScore(
        name: 'Returns Performance',
        score: 0,
        weight: 0.30,
        description: 'No investments to evaluate',
        suggestions: ['Add your first investment to track returns'],
      );
    }

    // Calculate weighted average XIRR (weighted by total invested)
    // TODO(@ravitejakamalapuram, 2026-04-09, #TBD): Convert each stat.totalInvested
    // to a canonical/base currency before summing to fix multi-currency weighting.
    // Currently, this sums stat.totalInvested across different currencies which breaks
    // the avgXirr calculation. Need to:
    // 1. Determine a base currency (e.g., user's default currency)
    // 2. Obtain exchange rate for stat.currency using CurrencyConversionService.convert()
    // 3. Compute convertedInvested = stat.totalInvested * rateToBase
    // 4. Use convertedInvested when updating totalInvested and weightedXirr
    // This ensures avgXirr = weightedXirr / totalInvested uses consistent currency units.
    double totalInvested = 0;
    double weightedXirr = 0;

    for (final investment in investments) {
      final stat = stats[investment.id];
      if (stat != null && stat.totalInvested > 0 && stat.xirr.isFinite) {
        totalInvested += stat.totalInvested;
        weightedXirr += stat.xirr * stat.totalInvested;
      }
    }

    // Return no-data result if no valid XIRR data
    if (totalInvested == 0) {
      return ComponentScore(
        name: 'Returns Performance',
        score: 0,
        weight: 0.30,
        description: 'No return data available',
        suggestions: ['Add investments with cash flows to track returns'],
      );
    }

    final avgXirr = weightedXirr / totalInvested;

    // Score calculation:
    // XIRR >= Inflation + 10%: 100 points (excellent)
    // XIRR >= Inflation + 5%: 80 points (good)
    // XIRR >= Inflation: 60 points (fair)
    // XIRR >= 0: 40 points (poor but positive)
    // XIRR < 0: 0-20 points (losing money)

    double score;
    final suggestions = <String>[];

    if (avgXirr >= benchmarkInflationRate + 0.10) {
      score = 100;
      suggestions.add('Excellent returns! Keep up the good work');
    } else if (avgXirr >= benchmarkInflationRate + 0.05) {
      score = 80 + ((avgXirr - (benchmarkInflationRate + 0.05)) / 0.05) * 20;
      suggestions.add('Good returns, beating inflation comfortably');
    } else if (avgXirr >= benchmarkInflationRate) {
      score = 60 + ((avgXirr - benchmarkInflationRate) / 0.05) * 20;
      suggestions.add(
        'Returns are just above inflation. Consider higher-yield options',
      );
    } else if (avgXirr >= 0) {
      score = 40 + (avgXirr / benchmarkInflationRate) * 20;
      suggestions.add('Returns below inflation. Your money is losing value');
      suggestions.add('Explore P2P lending or equity funds for better returns');
    } else {
      // Negative returns: scale from 20 (0% XIRR) to 0 (-20% or worse XIRR)
      score = max(0.0, 20.0 + (avgXirr / 0.20) * 20.0).clamp(0.0, 100.0);
      suggestions.add(
        'Negative returns detected. Review underperforming investments',
      );
      suggestions.add('Consider cutting losses and reallocating');
    }

    return ComponentScore(
      name: 'Returns Performance',
      score: score.clamp(0.0, 100.0),
      weight: 0.30,
      description: 'XIRR vs Inflation',
      suggestions: suggestions,
    );
  }

  /// Component 2: Diversification (25% weight)
  /// Score based on Herfindahl index (concentration)
  static ComponentScore _calculateDiversificationScore(
    List<InvestmentEntity> investments,
    Map<String, InvestmentStats> stats,
  ) {
    if (investments.isEmpty) {
      return ComponentScore(
        name: 'Diversification',
        score: 0,
        weight: 0.25,
        description: 'No investments to evaluate',
        suggestions: ['Add multiple investment types for diversification'],
      );
    }

    // Calculate Herfindahl index using investment values (totalInvested) by type
    final typeValues = <InvestmentType, double>{};
    double totalValue = 0.0;

    // Optimization: Calculate totalValue within the same loop to avoid .fold() closure overhead
    for (final inv in investments) {
      if (!inv.isArchived) {
        final stat = stats[inv.id];
        if (stat != null && stat.totalInvested > 0) {
          typeValues[inv.type] =
              (typeValues[inv.type] ?? 0.0) + stat.totalInvested;
          totalValue += stat.totalInvested;
        }
      }
    }

    if (totalValue == 0) {
      return ComponentScore(
        name: 'Diversification',
        score: 0,
        weight: 0.25,
        description: 'No active investments',
        suggestions: ['Add investments across different types'],
      );
    }

    // Herfindahl index: Sum of squared market shares (0-1)
    // Lower is better (more diversified)
    double herfindahl = 0;
    for (final value in typeValues.values) {
      final share = value / totalValue;
      herfindahl += share * share;
    }

    // Convert to score: HHI of 1.0 (monopoly) = 0 points, HHI of 0.2 (5 equal types) = 100 points
    // Score = max(0, 100 - (HHI - 0.2) * 125)
    final score = max(0.0, 100.0 - (herfindahl - 0.2) * 125).clamp(0.0, 100.0);

    final suggestions = <String>[];
    if (herfindahl > 0.5) {
      // Optimization: Replace .reduce() with a standard loop to avoid closure overhead
      var maxEntry = typeValues.entries.first;
      for (final entry in typeValues.entries) {
        if (entry.value > maxEntry.value) {
          maxEntry = entry;
        }
      }
      final dominantType = maxEntry.key;
      suggestions.add('Over-concentrated in ${dominantType.displayName}');
      suggestions.add('Diversify across at least 3 investment types');
    } else if (herfindahl > 0.3) {
      suggestions.add('Consider adding 1-2 more investment types');
    } else {
      suggestions.add('Good diversification across investment types');
    }

    return ComponentScore(
      name: 'Diversification',
      score: score,
      weight: 0.25,
      description: '${typeValues.length} investment types',
      suggestions: suggestions,
    );
  }

  /// Component 3: Liquidity (20% weight)
  /// Score based on % of portfolio value maturing in next 90 days
  static ComponentScore _calculateLiquidityScore(
    List<InvestmentEntity> investments,
    Map<String, InvestmentStats> stats,
  ) {
    if (investments.isEmpty) {
      return ComponentScore(
        name: 'Liquidity',
        score: 0,
        weight: 0.20,
        description: 'No investments to evaluate',
        suggestions: ['Add investments to track liquidity'],
      );
    }

    final now = DateTime.now();
    final next90Days = now.add(const Duration(days: 90));

    double totalActiveValue = 0;
    double maturingSoonValue = 0;
    int maturingSoonCount = 0;

    for (final inv in investments) {
      if (!inv.isArchived && inv.status == InvestmentStatus.open) {
        final stat = stats[inv.id];
        if (stat != null && stat.totalInvested > 0) {
          totalActiveValue += stat.totalInvested;

          final maturity = inv.calculatedMaturityDate;
          if (maturity != null &&
              maturity.isAfter(now) &&
              (maturity.isBefore(next90Days) ||
                  maturity.isAtSameMomentAs(next90Days))) {
            maturingSoonValue += stat.totalInvested;
            maturingSoonCount++;
          }
        }
      }
    }

    if (totalActiveValue == 0) {
      return ComponentScore(
        name: 'Liquidity',
        score: 0,
        weight: 0.20,
        description: 'No active investments',
        suggestions: ['Add active investments'],
      );
    }

    final liquidityRatio = maturingSoonValue / totalActiveValue;

    // Score calculation:
    // 10-30% maturing soon: 100 points (ideal)
    // 5-10% or 30-40%: 80 points (good)
    // <5% or >40%: Lower score (too illiquid or too much renewal work)

    double score;
    final suggestions = <String>[];
    final liquidityPercent = (liquidityRatio * 100).round();

    if (liquidityRatio >= 0.10 && liquidityRatio <= 0.30) {
      score = 100;
      suggestions.add('Optimal liquidity balance');
    } else if (liquidityRatio >= 0.05 && liquidityRatio < 0.10) {
      score = 80;
      suggestions.add('Slightly low liquidity, but manageable');
    } else if (liquidityRatio > 0.30 && liquidityRatio <= 0.40) {
      score = 80; // Fixed: 30-40% band should be 80 points (good)
      suggestions.add(
        '$liquidityPercent% of portfolio maturing soon - plan reinvestment',
      );
    } else if (liquidityRatio > 0.40) {
      score = 40;
      suggestions.add(
        '$liquidityPercent% of portfolio maturing soon ($maturingSoonCount investments)',
      );
      suggestions.add('Stagger maturity dates to avoid renewal cliff');
    } else {
      score = 60;
      suggestions.add('Low liquidity - consider adding short-term investments');
    }

    return ComponentScore(
      name: 'Liquidity',
      score: score.clamp(0.0, 100.0),
      weight: 0.20,
      description: '$liquidityPercent% maturing in 90 days',
      suggestions: suggestions,
    );
  }

  /// Component 4: Goal Alignment (15% weight)
  /// Score based on % of goals on-track vs behind
  static ComponentScore _calculateGoalAlignmentScore(
    List<GoalProgress> goalProgress,
  ) {
    if (goalProgress.isEmpty) {
      return ComponentScore(
        name: 'Goal Alignment',
        score: 100, // No goals = no misalignment
        weight: 0.15,
        description: 'No goals tracked',
        suggestions: ['Set financial goals to track progress'],
      );
    }

    // Optimization: Replace .where().toList() with a standard loop to avoid closure overhead
    final activeGoals = <GoalProgress>[];
    for (final g in goalProgress) {
      if (!g.goal.isArchived) {
        activeGoals.add(g);
      }
    }
    if (activeGoals.isEmpty) {
      return ComponentScore(
        name: 'Goal Alignment',
        score: 100,
        weight: 0.15,
        description: 'No active goals',
        suggestions: ['Add active goals to improve focus'],
      );
    }

    int onTrack = 0;
    int ahead = 0;
    int behind = 0;
    int achieved = 0;
    int notStarted = 0;

    for (final progress in activeGoals) {
      switch (progress.status) {
        case GoalStatus.achieved:
          achieved++;
          break;
        case GoalStatus.ahead:
          ahead++;
          break;
        case GoalStatus.onTrack:
          onTrack++;
          break;
        case GoalStatus.behind:
          behind++;
          break;
        case GoalStatus.notStarted:
          notStarted++;
          break;
        case GoalStatus.archived:
          break;
      }
    }

    final total = activeGoals.length;
    final successRate = (achieved + ahead + onTrack) / total;

    // Score: % of goals on-track or better
    final score = (successRate * 100).clamp(0.0, 100.0);

    final suggestions = <String>[];
    if (behind > 0) {
      suggestions.add('$behind goals behind schedule');
      suggestions.add('Increase contributions or adjust targets');
    }
    if (achieved > 0) {
      suggestions.add('$achieved goals achieved - great work!');
    }
    if (ahead > 0) {
      suggestions.add('$ahead goals ahead of schedule!');
    }
    // Add notStarted suggestion even when other goals exist
    if (notStarted > 0 && (achieved == 0 && ahead == 0 && onTrack == 0)) {
      suggestions.add('$notStarted goals not started yet');
      suggestions.add('Begin allocating funds to your goals');
    } else if (notStarted > 0) {
      suggestions.add('$notStarted goals not yet started');
    }

    return ComponentScore(
      name: 'Goal Alignment',
      score: score,
      weight: 0.15,
      description:
          '${achieved + ahead + onTrack}/$total goals on track or better',
      suggestions: suggestions.isEmpty
          ? ['All goals progressing well']
          : suggestions,
    );
  }

  /// Component 5: Action Readiness (10% weight)
  /// Score based on stale investments and overdue actions
  static ComponentScore _calculateActionReadinessScore(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> allCashFlows,
  ) {
    if (investments.isEmpty) {
      return ComponentScore(
        name: 'Action Readiness',
        score: 100,
        weight: 0.10,
        description: 'No investments to evaluate',
        suggestions: ['Add investments to track'],
      );
    }

    // Filter to only actionable open investments
    // Optimization: Replace .where().toList() with a standard loop
    final openInvestments = <InvestmentEntity>[];
    for (final i in investments) {
      if (!i.isArchived && i.status == InvestmentStatus.open) {
        openInvestments.add(i);
      }
    }

    final totalActive = openInvestments.length;
    if (totalActive == 0) {
      return ComponentScore(
        name: 'Action Readiness',
        score: 100,
        weight: 0.10,
        description: 'No active investments',
        suggestions: ['All investments up to date!'],
      );
    }

    final now = DateTime.now();
    int overdueRenewals = 0;
    int staleInvestments = 0;

    // Pre-index cash flows by investment ID to avoid O(n*m) complexity
    final cashFlowsByInvestmentId = <String, List<CashFlowEntity>>{};
    for (final cashFlow in allCashFlows) {
      cashFlowsByInvestmentId
          .putIfAbsent(cashFlow.investmentId, () => <CashFlowEntity>[])
          .add(cashFlow);
    }

    for (final inv in openInvestments) {
      // Check for overdue maturity
      final maturity = inv.calculatedMaturityDate;
      if (maturity != null && maturity.isBefore(now)) {
        overdueRenewals++;
      }

      // Check for stale investments (no activity in 6+ months)
      final cashFlows =
          cashFlowsByInvestmentId[inv.id] ?? const <CashFlowEntity>[];
      if (cashFlows.isNotEmpty) {
        // Optimization: Replace .map().reduce() with a standard loop
        var lastActivity = cashFlows.first.date;
        for (var i = 1; i < cashFlows.length; i++) {
          if (cashFlows[i].date.isAfter(lastActivity)) {
            lastActivity = cashFlows[i].date;
          }
        }
        final daysSinceActivity = now.difference(lastActivity).inDays;
        if (daysSinceActivity > 180) {
          staleInvestments++;
        }
      }
    }

    final totalIssues = overdueRenewals + staleInvestments;

    // Score: Deduct points for each issue
    final score = max(0.0, 100.0 - (totalIssues / totalActive) * 100);

    final suggestions = <String>[];
    if (overdueRenewals > 0) {
      suggestions.add('$overdueRenewals overdue renewals - take action now');
    }
    if (staleInvestments > 0) {
      suggestions.add('$staleInvestments stale investments (6+ months)');
      suggestions.add('Review and update inactive investments');
    }
    if (totalIssues == 0) {
      suggestions.add('All investments up to date!');
    }

    return ComponentScore(
      name: 'Action Readiness',
      score: score.clamp(0.0, 100.0),
      weight: 0.10,
      description: '$totalIssues pending actions',
      suggestions: suggestions,
    );
  }
}
