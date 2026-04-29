/// Performance Report Entity
///
/// Tracks top performers, underperformers, milestones, and risk-return matrix
/// for all active investments
library;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Performance report for all investments
class PerformanceReport {
  /// Top performing investments (sorted by XIRR desc)
  final List<InvestmentPerformance> topPerformers;

  /// Bottom performing investments (sorted by XIRR asc)
  final List<InvestmentPerformance> bottomPerformers;

  /// All investments sorted by XIRR
  final List<InvestmentPerformance> allPerformances;

  /// Recent milestone achievements
  final List<MilestoneAchievement> recentMilestones;

  /// Average portfolio XIRR (weighted by amount invested)
  final double averageXIRR;

  /// Median portfolio XIRR
  final double medianXIRR;

  /// Total investments analyzed
  final int totalInvestments;

  /// Profitab investments count
  final int profitableCount;

  /// Loss-making investments count
  final int lossCount;

  /// Report generation timestamp
  final DateTime generatedAt;

  const PerformanceReport({
    required this.topPerformers,
    required this.bottomPerformers,
    required this.allPerformances,
    required this.recentMilestones,
    required this.averageXIRR,
    required this.medianXIRR,
    required this.totalInvestments,
    required this.profitableCount,
    required this.lossCount,
    required this.generatedAt,
  });

  /// Percentage of profitable investments
  double get profitabilityRate {
    if (totalInvestments == 0) return 0;
    return (profitableCount / totalInvestments) * 100;
  }
}

/// Individual investment performance data
class InvestmentPerformance {
  final InvestmentEntity investment;
  final double xirr;
  final double absoluteReturn;
  final double percentageReturn;
  final double totalInvested;
  final double totalReturned;
  final double currentValue;

  const InvestmentPerformance({
    required this.investment,
    required this.xirr,
    required this.absoluteReturn,
    required this.percentageReturn,
    required this.totalInvested,
    required this.totalReturned,
    required this.currentValue,
  });

  /// Returns true if this investment is profitable
  bool get isProfitable => absoluteReturn > 0;

  /// Performance category based on XIRR
  PerformanceCategory get category {
    if (xirr >= 0.15) return PerformanceCategory.excellent;
    if (xirr >= 0.10) return PerformanceCategory.good;
    if (xirr >= 0.05) return PerformanceCategory.moderate;
    if (xirr >= 0) return PerformanceCategory.poor;
    return PerformanceCategory.loss;
  }
}

/// Milestone achievement record
class MilestoneAchievement {
  final InvestmentEntity investment;
  final double milestonePercentage; // 10, 25, 50, 100
  final DateTime achievedAt;
  final double amountGained;

  const MilestoneAchievement({
    required this.investment,
    required this.milestonePercentage,
    required this.achievedAt,
    required this.amountGained,
  });

  /// Milestone icon based on percentage
  String get emoji {
    if (milestonePercentage >= 100) return '💎'; // Diamond
    if (milestonePercentage >= 50) return '🚀'; // Rocket
    if (milestonePercentage >= 25) return '🏆'; // Trophy
    return '🎉'; // Party
  }

  /// Milestone label
  String get label {
    return '${milestonePercentage.toInt()}% Gain';
  }
}

/// Performance category enum
enum PerformanceCategory {
  excellent, // >= 15%
  good, // 10-15%
  moderate, // 5-10%
  poor, // 0-5%
  loss, // < 0%
}

/// Extension for category colors and labels
extension PerformanceCategoryExtension on PerformanceCategory {
  String get label {
    switch (this) {
      case PerformanceCategory.excellent:
        return 'Excellent';
      case PerformanceCategory.good:
        return 'Good';
      case PerformanceCategory.moderate:
        return 'Moderate';
      case PerformanceCategory.poor:
        return 'Poor';
      case PerformanceCategory.loss:
        return 'Loss';
    }
  }
}
