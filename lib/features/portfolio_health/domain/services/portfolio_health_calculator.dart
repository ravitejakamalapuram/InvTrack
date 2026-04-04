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
  /// India inflation rate (approximate annual average)
  static const double _inflationRate = 0.06; // 6%

  /// Calculate portfolio health score
  static PortfolioHealthScore calculate({
    required List<InvestmentEntity> investments,
    required Map<String, InvestmentStats> investmentStats,
    required List<CashFlowEntity> allCashFlows,
    required List<GoalProgress> goalProgress,
  }) {
    // Calculate each component
    final returns = _calculateReturnsScore(investments, investmentStats);
    final diversification = _calculateDiversificationScore(investments);
    final liquidity = _calculateLiquidityScore(investments);
    final goals = _calculateGoalAlignmentScore(goalProgress);
    final actions = _calculateActionReadinessScore(investments, allCashFlows);

    // Calculate weighted overall score
    final overall = returns.weightedScore +
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
  ) {
    if (investments.isEmpty || stats.isEmpty) {
      return const ComponentScore(
        name: 'Returns Performance',
        score: 0,
        weight: 0.30,
        description: 'No investments to evaluate',
        suggestions: ['Add your first investment to track returns'],
      );
    }

    // Calculate weighted average XIRR (weighted by total invested)
    double totalInvested = 0;
    double weightedXirr = 0;

    for (final investment in investments) {
      final stat = stats[investment.id];
      if (stat != null && stat.totalInvested > 0) {
        totalInvested += stat.totalInvested;
        weightedXirr += stat.xirr * stat.totalInvested;
      }
    }

    final avgXirr = totalInvested > 0 ? weightedXirr / totalInvested : 0.0;

    // Score calculation:
    // XIRR >= Inflation + 10%: 100 points (excellent)
    // XIRR >= Inflation + 5%: 80 points (good)
    // XIRR >= Inflation: 60 points (fair)
    // XIRR >= 0: 40 points (poor but positive)
    // XIRR < 0: 0-20 points (losing money)

    double score;
    final suggestions = <String>[];

    if (avgXirr >= _inflationRate + 0.10) {
      score = 100;
      suggestions.add('Excellent returns! Keep up the good work');
    } else if (avgXirr >= _inflationRate + 0.05) {
      score = 80 + ((avgXirr - (_inflationRate + 0.05)) / 0.05) * 20;
      suggestions.add('Good returns, beating inflation comfortably');
    } else if (avgXirr >= _inflationRate) {
      score = 60 + ((avgXirr - _inflationRate) / 0.05) * 20;
      suggestions.add('Returns are just above inflation. Consider higher-yield options');
    } else if (avgXirr >= 0) {
      score = 40 + (avgXirr / _inflationRate) * 20;
      suggestions.add('Returns below inflation. Your money is losing value');
      suggestions.add('Explore P2P lending or equity funds for better returns');
    } else {
      // Negative returns: scale from 20 (0% XIRR) to 0 (-20% or worse XIRR)
      score = max(0.0, 20.0 + (avgXirr / 0.20) * 20.0).clamp(0.0, 100.0);
      suggestions.add('Negative returns detected. Review underperforming investments');
      suggestions.add('Consider cutting losses and reallocating');
    }

    return ComponentScore(
      name: 'Returns Performance',
      score: score.clamp(0.0, 100.0),
      weight: 0.30,
      description: 'XIRR: ${(avgXirr * 100).toStringAsFixed(1)}% vs Inflation: ${(_inflationRate * 100).toStringAsFixed(1)}%',
      suggestions: suggestions,
    );
  }

  /// Component 2: Diversification (25% weight)
  /// Score based on Herfindahl index (concentration)
  static ComponentScore _calculateDiversificationScore(
    List<InvestmentEntity> investments,
  ) {
    if (investments.isEmpty) {
      return const ComponentScore(
        name: 'Diversification',
        score: 0,
        weight: 0.25,
        description: 'No investments to evaluate',
        suggestions: ['Add multiple investment types for diversification'],
      );
    }

    // Calculate Herfindahl index for investment types
    final typeCounts = <InvestmentType, int>{};
    for (final inv in investments) {
      if (!inv.isArchived) {
        typeCounts[inv.type] = (typeCounts[inv.type] ?? 0) + 1;
      }
    }

    final totalActive = typeCounts.values.fold(0, (sum, count) => sum + count);
    if (totalActive == 0) {
      return const ComponentScore(
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
    for (final count in typeCounts.values) {
      final share = count / totalActive;
      herfindahl += share * share;
    }

    // Convert to score: HHI of 1.0 (monopoly) = 0 points, HHI of 0.2 (5 equal types) = 100 points
    // Score = max(0, 100 - (HHI - 0.2) * 125)
    final score = max(0.0, 100.0 - (herfindahl - 0.2) * 125).clamp(0.0, 100.0);

    final suggestions = <String>[];
    if (herfindahl > 0.5) {
      final dominantType = typeCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
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
      description: '${typeCounts.length} investment types',
      suggestions: suggestions,
    );
  }

  /// Component 3: Liquidity (20% weight)
  /// Score based on % of portfolio maturing in next 90 days
  static ComponentScore _calculateLiquidityScore(
    List<InvestmentEntity> investments,
  ) {
    if (investments.isEmpty) {
      return const ComponentScore(
        name: 'Liquidity',
        score: 0,
        weight: 0.20,
        description: 'No investments to evaluate',
        suggestions: ['Add investments to track liquidity'],
      );
    }

    final now = DateTime.now();
    final next90Days = now.add(const Duration(days: 90));

    int totalActive = 0;
    int maturingSoon = 0;

    for (final inv in investments) {
      if (!inv.isArchived && inv.status == InvestmentStatus.open) {
        totalActive++;
        final maturity = inv.calculatedMaturityDate;
        if (maturity != null &&
            maturity.isAfter(now) &&
            maturity.isBefore(next90Days)) {
          maturingSoon++;
        }
      }
    }

    if (totalActive == 0) {
      return const ComponentScore(
        name: 'Liquidity',
        score: 0,
        weight: 0.20,
        description: 'No active investments',
        suggestions: ['Add active investments'],
      );
    }

    final liquidityRatio = maturingSoon / totalActive;

    // Score calculation:
    // 10-30% maturing soon: 100 points (ideal)
    // 5-10% or 30-40%: 80 points (good)
    // <5% or >40%: Lower score (too illiquid or too much renewal work)

    double score;
    final suggestions = <String>[];

    if (liquidityRatio >= 0.10 && liquidityRatio <= 0.30) {
      score = 100;
      suggestions.add('Optimal liquidity balance');
    } else if (liquidityRatio >= 0.05 && liquidityRatio < 0.10) {
      score = 80;
      suggestions.add('Slightly low liquidity, but manageable');
    } else if (liquidityRatio > 0.30 && liquidityRatio <= 0.40) {
      score = 70;
      suggestions.add('$maturingSoon investments maturing soon - plan reinvestment');
    } else if (liquidityRatio > 0.40) {
      score = 40;
      suggestions.add('Too many investments maturing soon ($maturingSoon)');
      suggestions.add('Stagger maturity dates to avoid renewal cliff');
    } else {
      score = 60;
      suggestions.add('Low liquidity - consider adding short-term investments');
    }

    return ComponentScore(
      name: 'Liquidity',
      score: score.clamp(0.0, 100.0),
      weight: 0.20,
      description: '$maturingSoon of $totalActive maturing in 90 days',
      suggestions: suggestions,
    );
  }

  /// Component 4: Goal Alignment (15% weight)
  /// Score based on % of goals on-track vs behind
  static ComponentScore _calculateGoalAlignmentScore(
    List<GoalProgress> goalProgress,
  ) {
    if (goalProgress.isEmpty) {
      return const ComponentScore(
        name: 'Goal Alignment',
        score: 100, // No goals = no misalignment
        weight: 0.15,
        description: 'No goals tracked',
        suggestions: ['Set financial goals to track progress'],
      );
    }

    final activeGoals =
        goalProgress.where((g) => !g.goal.isArchived).toList();
    if (activeGoals.isEmpty) {
      return const ComponentScore(
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

    return ComponentScore(
      name: 'Goal Alignment',
      score: score,
      weight: 0.15,
      description: '$onTrack/$total goals on track',
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
      return const ComponentScore(
        name: 'Action Readiness',
        score: 100,
        weight: 0.10,
        description: 'No investments to evaluate',
        suggestions: ['Add investments to track'],
      );
    }

    final now = DateTime.now();
    int overdueRenewals = 0;
    int staleInvestments = 0;

    for (final inv in investments) {
      if (inv.isArchived) continue;

      // Check for overdue maturity
      final maturity = inv.calculatedMaturityDate;
      if (maturity != null && maturity.isBefore(now)) {
        overdueRenewals++;
      }

      // Check for stale investments (no activity in 6+ months)
      final cashFlows =
          allCashFlows.where((cf) => cf.investmentId == inv.id).toList();
      if (cashFlows.isNotEmpty) {
        final lastActivity = cashFlows
            .map((cf) => cf.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        final daysSinceActivity = now.difference(lastActivity).inDays;
        if (daysSinceActivity > 180) {
          staleInvestments++;
        }
      }
    }

    final totalIssues = overdueRenewals + staleInvestments;
    final totalActive = investments.where((i) => !i.isArchived).length;

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
