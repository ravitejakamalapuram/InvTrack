/// Portfolio Health Service
///
/// Generates portfolio health assessment reports
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/reports/domain/entities/portfolio_health_report.dart';

/// Provider for portfolio health service
final portfolioHealthServiceProvider = Provider<PortfolioHealthService>((ref) {
  return PortfolioHealthService();
});

/// Service for generating portfolio health reports
class PortfolioHealthService {
  /// Generate portfolio health report
  PortfolioHealthReport generateReport({
    required List<InvestmentEntity> investments,
    required Map<String, InvestmentStats> statsMap,
    required List<CashFlowEntity> cashFlows,
  }) {
    final activeInvestments =
        investments.where((i) => i.status == InvestmentStatus.open).toList();

    // 1. Calculate diversification
    final diversification = _calculateDiversification(activeInvestments, statsMap);
    final diversificationScore = _calculateDiversificationScore(diversification);

    // 2. Calculate risk distribution
    final riskDistribution = _calculateRiskDistribution(activeInvestments, statsMap);

    // 3. Calculate performance score
    final performanceScore = _calculatePerformanceScore(statsMap);

    // 4. Calculate activity score
    final idleCount = _calculateIdleInvestments(activeInvestments, cashFlows);
    final activityScore = activeInvestments.isEmpty
        ? 0.0
        : ((activeInvestments.length - idleCount) / activeInvestments.length) * 100;

    // 5. Calculate overall score (weighted average)
    final overallScoreValue = (
      (diversificationScore * 0.3) +
      (performanceScore * 0.4) +
      (activityScore * 0.3)
    ).round();

    final overallScore = _getHealthScore(overallScoreValue);

    // 6. Generate recommendations
    final recommendations = _generateRecommendations(
      diversification: diversification,
      riskDistribution: riskDistribution,
      idleCount: idleCount,
      performanceScore: performanceScore,
    );

    return PortfolioHealthReport(
      overallScore: overallScore,
      scoreValue: overallScoreValue,
      diversification: diversification,
      riskDistribution: riskDistribution,
      diversificationScore: diversificationScore,
      performanceScore: performanceScore,
      activityScore: activityScore,
      totalInvestments: investments.length,
      activeInvestments: activeInvestments.length,
      idleInvestments: idleCount,
      recommendations: recommendations,
    );
  }

  List<DiversificationBreakdown> _calculateDiversification(
    List<InvestmentEntity> investments,
    Map<String, InvestmentStats> statsMap,
  ) {
    final typeMap = <InvestmentType, List<InvestmentEntity>>{};
    
    for (final investment in investments) {
      typeMap.putIfAbsent(investment.type, () => []).add(investment);
    }

    double totalValue = 0;
    for (final investment in investments) {
      final stats = statsMap[investment.id];
      totalValue += stats?.totalInvested ?? 0;
    }

    if (totalValue == 0) return [];

    return typeMap.entries.map((entry) {
      double typeValue = 0;
      for (final inv in entry.value) {
        final stats = statsMap[inv.id];
        typeValue += stats?.totalInvested ?? 0;
      }

      return DiversificationBreakdown(
        type: entry.key,
        percentage: (typeValue / totalValue) * 100,
        amount: typeValue,
        count: entry.value.length,
      );
    }).toList()..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  double _calculateDiversificationScore(List<DiversificationBreakdown> breakdown) {
    if (breakdown.isEmpty) return 0;
    if (breakdown.length == 1) return 20; // Poor diversification

    // Penalize concentration (any type > 50%)
    final hasConcentration = breakdown.any((b) => b.percentage > 50);
    if (hasConcentration) return 40;

    // Good diversification: 3+ types, no type > 40%
    if (breakdown.length >= 3 && breakdown.every((b) => b.percentage <= 40)) {
      return 90;
    }

    // Fair diversification: 2-3 types
    return 60;
  }

  RiskDistribution _calculateRiskDistribution(
    List<InvestmentEntity> investments,
    Map<String, InvestmentStats> statsMap,
  ) {
    double lowRiskAmount = 0, mediumRiskAmount = 0, highRiskAmount = 0;
    double total = 0;

    for (final investment in investments) {
      final stats = statsMap[investment.id];
      final amount = stats?.totalInvested ?? 0;
      total += amount;

      switch (investment.riskLevel) {
        case RiskLevel.low:
          lowRiskAmount += amount;
          break;
        case RiskLevel.medium:
          mediumRiskAmount += amount;
          break;
        case RiskLevel.high:
        case RiskLevel.veryHigh:
          // Both high and very high go into high risk category
          highRiskAmount += amount;
          break;
        case null:
          // Assume medium if not specified
          mediumRiskAmount += amount;
      }
    }

    if (total == 0) {
      return const RiskDistribution(
        lowRiskPercentage: 0,
        mediumRiskPercentage: 0,
        highRiskPercentage: 0,
        lowRiskAmount: 0,
        mediumRiskAmount: 0,
        highRiskAmount: 0,
      );
    }

    return RiskDistribution(
      lowRiskPercentage: (lowRiskAmount / total) * 100,
      mediumRiskPercentage: (mediumRiskAmount / total) * 100,
      highRiskPercentage: (highRiskAmount / total) * 100,
      lowRiskAmount: lowRiskAmount,
      mediumRiskAmount: mediumRiskAmount,
      highRiskAmount: highRiskAmount,
    );
  }

  double _calculatePerformanceScore(Map<String, InvestmentStats> statsMap) {
    if (statsMap.isEmpty) return 0;

    int positiveCount = 0;
    for (final stats in statsMap.values) {
      if (stats.absoluteReturn > 0) positiveCount++;
    }

    return (positiveCount / statsMap.length) * 100;
  }

  int _calculateIdleInvestments(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  ) {
    final now = DateTime.now();
    final cashFlowsByInvestment = <String, List<CashFlowEntity>>{};
    
    for (final cf in cashFlows) {
      cashFlowsByInvestment.putIfAbsent(cf.investmentId, () => []).add(cf);
    }

    int idleCount = 0;
    for (final investment in investments) {
      final flows = cashFlowsByInvestment[investment.id] ?? [];
      if (flows.isEmpty) continue;

      flows.sort((a, b) => b.date.compareTo(a.date));
      final daysSinceLastActivity = now.difference(flows.first.date).inDays;

      if (daysSinceLastActivity >= 90) {
        idleCount++;
      }
    }

    return idleCount;
  }

  HealthScore _getHealthScore(int score) {
    if (score >= 80) return HealthScore.excellent;
    if (score >= 60) return HealthScore.good;
    if (score >= 40) return HealthScore.fair;
    return HealthScore.poor;
  }

  List<HealthRecommendation> _generateRecommendations({
    required List<DiversificationBreakdown> diversification,
    required RiskDistribution riskDistribution,
    required int idleCount,
    required double performanceScore,
  }) {
    final recommendations = <HealthRecommendation>[];

    // Diversification recommendations
    if (diversification.length < 3) {
      recommendations.add(const HealthRecommendation(
        title: 'Improve Diversification',
        description: 'Consider adding more investment types to reduce risk.',
        priority: RecommendationPriority.high,
      ));
    } else if (diversification.any((d) => d.percentage > 50)) {
      recommendations.add(const HealthRecommendation(
        title: 'Reduce Concentration',
        description: 'One investment type dominates your portfolio. Consider rebalancing.',
        priority: RecommendationPriority.medium,
      ));
    }

    // Risk recommendations
    if (!riskDistribution.isBalanced) {
      recommendations.add(const HealthRecommendation(
        title: 'Balance Risk',
        description: 'Your portfolio is heavily weighted in one risk category.',
        priority: RecommendationPriority.medium,
      ));
    }

    // Idle investment recommendations
    if (idleCount > 0) {
      recommendations.add(HealthRecommendation(
        title: 'Review Idle Investments',
        description: '$idleCount investments have had no activity in 90+ days.',
        priority: RecommendationPriority.high,
      ));
    }

    // Performance recommendations
    if (performanceScore < 40) {
      recommendations.add(const HealthRecommendation(
        title: 'Review Performance',
        description: 'Many investments are underperforming. Consider rebalancing.',
        priority: RecommendationPriority.high,
      ));
    }

    return recommendations;
  }
}
