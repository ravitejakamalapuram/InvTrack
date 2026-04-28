/// Portfolio Health Report Entity
///
/// Provides health assessment of the investment portfolio
library;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Overall health score
enum HealthScore {
  excellent, // 80-100
  good, // 60-79
  fair, // 40-59
  poor; // 0-39

  String get displayName {
    switch (this) {
      case HealthScore.excellent:
        return 'Excellent';
      case HealthScore.good:
        return 'Good';
      case HealthScore.fair:
        return 'Fair';
      case HealthScore.poor:
        return 'Poor';
    }
  }

  String get emoji {
    switch (this) {
      case HealthScore.excellent:
        return '🌟';
      case HealthScore.good:
        return '✅';
      case HealthScore.fair:
        return '⚠️';
      case HealthScore.poor:
        return '❌';
    }
  }
}

/// Diversification breakdown by investment type
class DiversificationBreakdown {
  final InvestmentType type;
  final double percentage;
  final double amount;
  final int count;

  const DiversificationBreakdown({
    required this.type,
    required this.percentage,
    required this.amount,
    required this.count,
  });
}

/// Risk distribution across portfolio
class RiskDistribution {
  final double lowRiskPercentage;
  final double mediumRiskPercentage;
  final double highRiskPercentage;
  final double lowRiskAmount;
  final double mediumRiskAmount;
  final double highRiskAmount;

  const RiskDistribution({
    required this.lowRiskPercentage,
    required this.mediumRiskPercentage,
    required this.highRiskPercentage,
    required this.lowRiskAmount,
    required this.mediumRiskAmount,
    required this.highRiskAmount,
  });

  /// Whether risk is well balanced (no single category > 60%)
  bool get isBalanced =>
      lowRiskPercentage <= 60 &&
      mediumRiskPercentage <= 60 &&
      highRiskPercentage <= 60;
}

/// Health recommendation
class HealthRecommendation {
  final String title;
  final String description;
  final RecommendationPriority priority;

  const HealthRecommendation({
    required this.title,
    required this.description,
    required this.priority,
  });
}

enum RecommendationPriority { high, medium, low }

/// Portfolio Health Report
class PortfolioHealthReport {
  final HealthScore overallScore;
  final int scoreValue; // 0-100
  final List<DiversificationBreakdown> diversification;
  final RiskDistribution riskDistribution;
  final double diversificationScore; // 0-100
  final double performanceScore; // 0-100
  final double activityScore; // 0-100
  final int totalInvestments;
  final int activeInvestments;
  final int idleInvestments; // No activity in 90+ days
  final List<HealthRecommendation> recommendations;

  const PortfolioHealthReport({
    required this.overallScore,
    required this.scoreValue,
    required this.diversification,
    required this.riskDistribution,
    required this.diversificationScore,
    required this.performanceScore,
    required this.activityScore,
    required this.totalInvestments,
    required this.activeInvestments,
    required this.idleInvestments,
    required this.recommendations,
  });

  /// Whether portfolio is considered healthy (score >= 60)
  bool get isHealthy => scoreValue >= 60;

  /// Number of investment types in portfolio
  int get typeCount => diversification.length;

  /// Whether portfolio is well diversified (3+ types)
  bool get isWellDiversified => typeCount >= 3;
}
