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

    // Optimization: Group cash flows by investment id to avoid O(N * M) nested loops
    final cashFlowsByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in allCashFlows) {
      cashFlowsByInvestment.putIfAbsent(cf.investmentId, () => []).add(cf);
    }

    for (final investment in allInvestments) {
      final investmentCFs = cashFlowsByInvestment[investment.id];

      if (investmentCFs == null || investmentCFs.isEmpty) continue;

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
    // Fix: Remove second .reversed - we want worst performers (lowest XIRR)
    final bottomPerformers = sortedByXIRR.reversed.take(5).toList();

    // Calculate recent milestones (last 30 days)
    final recentMilestones = _calculateMilestones(performances);

    // Optimization: Calculate stats in a single pass instead of multiple
    // .map().toList(), .reduce(), and .where().length calls
    double sumXirr = 0.0;
    int profitableCount = 0;

    for (final p in performances) {
      sumXirr += p.xirr;
      if (p.isProfitable) profitableCount++;
    }

    final averageXIRR = performances.isEmpty ? 0.0 : sumXirr / performances.length;

    // Calculate median using the already sorted sortedByXIRR array (O(1))
    // instead of allocating and sorting a new xirrValues list
    final medianXIRR = sortedByXIRR.isEmpty
        ? 0.0
        : sortedByXIRR.length.isOdd
            ? sortedByXIRR[sortedByXIRR.length ~/ 2].xirr
            : (sortedByXIRR[sortedByXIRR.length ~/ 2 - 1].xirr + sortedByXIRR[sortedByXIRR.length ~/ 2].xirr) / 2;

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
