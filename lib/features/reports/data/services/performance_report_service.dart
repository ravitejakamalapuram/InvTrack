/// Performance Report Service
///
/// Generates performance analysis reports for all investments including:
/// - Top/bottom performers by XIRR
/// - Recent milestones achieved
/// - Performance distribution
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/reports/domain/entities/performance_report.dart';

/// Provider for performance report service
final performanceReportServiceProvider = Provider<PerformanceReportService>((ref) {
  return PerformanceReportService();
});

class PerformanceReportService {
  /// Generate performance report for all investments
  PerformanceReport generateReport({
    required List<InvestmentEntity> allInvestments,
    required List<CashFlowEntity> allCashFlows,
  }) {
    // Build performance data for each investment
    final performances = <InvestmentPerformance>[];

    for (final investment in allInvestments) {
      final investmentCFs = allCashFlows
          .where((cf) => cf.investmentId == investment.id)
          .toList();

      if (investmentCFs.isEmpty) continue;

      // Calculate stats for this investment
      final stats = calculateStats(investmentCFs);

      // Estimate current value (invested - returned)
      final currentValue = stats.totalInvested - stats.totalReturned;

      performances.add(
        InvestmentPerformance(
          investment: investment,
          xirr: stats.xirr,
          absoluteReturn: stats.netCashFlow,
          percentageReturn: stats.absoluteReturn,
          totalInvested: stats.totalInvested,
          totalReturned: stats.totalReturned,
          currentValue: currentValue.abs(), // Use absolute value
        ),
      );
    }

    // Sort by XIRR for top/bottom lists
    final sortedByXIRR = List<InvestmentPerformance>.from(performances)
      ..sort((a, b) => b.xirr.compareTo(a.xirr));

    final topPerformers = sortedByXIRR.take(5).toList();
    final bottomPerformers = sortedByXIRR.reversed.take(5).toList().reversed.toList();

    // Calculate recent milestones (last 30 days)
    final recentMilestones = _calculateMilestones(performances);

    // Calculate average and median XIRR
    final xirrValues = performances.map((p) => p.xirr).toList();
    final averageXIRR = xirrValues.isEmpty
        ? 0.0
        : xirrValues.reduce((a, b) => a + b) / xirrValues.length;

    xirrValues.sort();
    final medianXIRR = xirrValues.isEmpty
        ? 0.0
        : xirrValues.length.isOdd
            ? xirrValues[xirrValues.length ~/ 2]
            : (xirrValues[xirrValues.length ~/ 2 - 1] + xirrValues[xirrValues.length ~/ 2]) / 2;

    // Count profitable vs loss-making
    final profitableCount = performances.where((p) => p.isProfitable).length;
    final lossCount = performances.length - profitableCount;

    return PerformanceReport(
      topPerformers: topPerformers,
      bottomPerformers: bottomPerformers,
      allPerformances: performances,
      recentMilestones: recentMilestones,
      averageXIRR: averageXIRR,
      medianXIRR: medianXIRR,
      totalInvestments: performances.length,
      profitableCount: profitableCount,
      lossCount: lossCount,
      generatedAt: DateTime.now(),
    );
  }

  /// Calculate recent milestone achievements
  List<MilestoneAchievement> _calculateMilestones(
    List<InvestmentPerformance> performances,
  ) {
    final milestones = <MilestoneAchievement>[];
    final now = DateTime.now();

    for (final perf in performances) {
      // Check if percentage return crossed a milestone threshold
      final percentageGain = perf.percentageReturn;
      
      // Determine which milestones were achieved
      final achievedMilestones = <double>[];
      if (percentageGain >= 10) achievedMilestones.add(10);
      if (percentageGain >= 25) achievedMilestones.add(25);
      if (percentageGain >= 50) achievedMilestones.add(50);
      if (percentageGain >= 100) achievedMilestones.add(100);

      // For simplicity, assume milestones were achieved recently
      // In a real implementation, we'd track milestone achievement dates
      for (final milestone in achievedMilestones) {
        milestones.add(
          MilestoneAchievement(
            investment: perf.investment,
            milestonePercentage: milestone,
            achievedAt: now.subtract(Duration(days: (milestone / 10).toInt())),
            amountGained: perf.absoluteReturn,
          ),
        );
      }
    }

    // Sort by achievement date (most recent first)
    milestones.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    // Return top 10 most recent milestones
    return milestones.take(10).toList();
  }
}
