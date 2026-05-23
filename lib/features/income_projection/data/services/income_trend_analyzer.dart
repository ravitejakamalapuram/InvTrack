/// Income Trend Analyzer Service
///
/// Generates comprehensive income trend analysis reports including:
/// - Monthly income trends (last 12 months)
/// - Growth metrics (MoM, QoQ, 6-month average)
/// - Platform reliability scoring
/// - Income diversification (HHI)
library;

import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/income_trend_report.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';

/// Income Trend Analyzer Service
class IncomeTrendAnalyzer {
  /// Generate income trend analysis report
  IncomeTrendReport generateReport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required List<ExpectedCashFlowEntity> expectedCashFlows,
    required String currency,
  }) {
    final now = DateTime.now();

    // 1. Calculate monthly data (last 12 months)
    final monthlyData = _calculateMonthlyData(cashFlows, currency);

    // 2. Calculate growth metrics
    final momGrowth = _calculateMoMGrowth(monthlyData);
    final qoqGrowth = _calculateQoQGrowth(monthlyData);
    final sixMonthAvg = _calculateSixMonthAverage(monthlyData);

    // 3. Calculate platform reliability
    final platformReliability = _calculatePlatformReliability(
      investments,
      expectedCashFlows,
    );

    // 4. Calculate income diversification (HHI)
    final incomeSources = _calculateIncomeSources(investments, cashFlows);
    final diversificationScore = _calculateHHI(incomeSources);

    // 5. Calculate totals
    final totalIncome = monthlyData.fold<double>(
      0.0,
      (sum, data) => sum + data.totalIncome,
    );
    final averageMonthlyIncome = monthlyData.isEmpty
        ? 0.0
        : totalIncome / monthlyData.length;

    // 6. Generate auto-insights
    final insights = _generateInsights(
      momGrowth: momGrowth,
      qoqGrowth: qoqGrowth,
      diversificationScore: diversificationScore,
      platformReliability: platformReliability,
      incomeSources: incomeSources,
    );

    return IncomeTrendReport(
      generatedAt: now,
      monthlyData: monthlyData,
      momGrowth: momGrowth,
      qoqGrowth: qoqGrowth,
      sixMonthAverage: sixMonthAvg,
      platformReliability: platformReliability,
      diversificationScore: diversificationScore,
      incomeSources: incomeSources,
      insights: insights,
      totalIncome: totalIncome,
      averageMonthlyIncome: averageMonthlyIncome,
      currency: currency,
    );
  }

  /// Calculate monthly income data for last 12 months
  List<MonthlyIncomeData> _calculateMonthlyData(
    List<CashFlowEntity> cashFlows,
    String currency,
  ) {
    final now = DateTime.now();
    final monthlyMap = <String, List<CashFlowEntity>>{};

    // Group income by month (last 12 months)
    for (final cf in cashFlows) {
      if (cf.type != CashFlowType.income) continue;

      final monthsDiff = (now.year - cf.date.year) * 12 + (now.month - cf.date.month);
      if (monthsDiff < 0 || monthsDiff >= 12) continue;

      final key = '${cf.date.year}-${cf.date.month.toString().padLeft(2, '0')}';
      monthlyMap.putIfAbsent(key, () => []).add(cf);
    }

    // Convert to MonthlyIncomeData (sorted oldest to newest)
    final monthlyData = <MonthlyIncomeData>[];
    for (int i = 11; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final key = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}';
      
      final payments = monthlyMap[key] ?? [];
      final totalIncome = payments.fold<double>(0.0, (sum, cf) => sum + cf.amount);

      monthlyData.add(MonthlyIncomeData(
        month: targetDate,
        totalIncome: totalIncome,
        paymentCount: payments.length,
        currency: currency,
      ));
    }

    return monthlyData;
  }

  /// Calculate Month-over-Month growth rate (%)
  double _calculateMoMGrowth(List<MonthlyIncomeData> monthlyData) {
    if (monthlyData.length < 2) return 0.0;

    final current = monthlyData.last.totalIncome;
    final previous = monthlyData[monthlyData.length - 2].totalIncome;

    if (previous == 0) return 0.0;

    return ((current - previous) / previous) * 100;
  }

  /// Calculate Quarter-over-Quarter growth rate (%)
  double _calculateQoQGrowth(List<MonthlyIncomeData> monthlyData) {
    if (monthlyData.length < 6) return 0.0;

    // Last quarter (last 3 months)
    final currentQ = monthlyData.skip(monthlyData.length - 3).fold<double>(
      0.0,
      (sum, data) => sum + data.totalIncome,
    );

    // Previous quarter (months 4-6 from end)
    final previousQ = monthlyData
        .skip(monthlyData.length - 6)
        .take(3)
        .fold<double>(0.0, (sum, data) => sum + data.totalIncome);

    if (previousQ == 0) return 0.0;

    return ((currentQ - previousQ) / previousQ) * 100;
  }

  /// Calculate 6-month rolling average
  double _calculateSixMonthAverage(List<MonthlyIncomeData> monthlyData) {
    if (monthlyData.isEmpty) return 0.0;

    final last6 = monthlyData.length >= 6
        ? monthlyData.skip(monthlyData.length - 6)
        : monthlyData;

    final total = last6.fold<double>(0.0, (sum, data) => sum + data.totalIncome);
    return total / last6.length;
  }

  /// Calculate platform reliability scores
  List<PlatformReliability> _calculatePlatformReliability(
    List<InvestmentEntity> investments,
    List<ExpectedCashFlowEntity> expectedCashFlows,
  ) {
    final platformMap = <String, ({int total, int onTime, List<int> delays})>{};

    // Group by platform
    for (final expected in expectedCashFlows) {
      if (expected.status != ExpectedCashFlowStatus.received) continue;

      final investment = investments.firstWhere(
        (inv) => inv.id == expected.investmentId,
        orElse: () => investments.first,
      );
      final platform = investment.platform ?? 'Unknown';

      final entry = platformMap.putIfAbsent(
        platform,
        () => (total: 0, onTime: 0, delays: <int>[]),
      );

      final isOnTime = expected.actualDate != null &&
          !expected.actualDate!.isAfter(
            expected.expectedDate.add(const Duration(days: 3)),
          );

      final delay = expected.actualDate != null
          ? expected.actualDate!.difference(expected.expectedDate).inDays
          : 0;

      platformMap[platform] = (
        total: entry.total + 1,
        onTime: entry.onTime + (isOnTime ? 1 : 0),
        delays: [...entry.delays, delay > 0 ? delay : 0],
      );
    }

    // Convert to PlatformReliability objects
    return platformMap.entries.map((e) {
      final avgDelay = e.value.delays.isEmpty
          ? 0.0
          : e.value.delays.reduce((a, b) => a + b) / e.value.delays.length;

      return PlatformReliability(
        platform: e.key,
        totalPayments: e.value.total,
        onTimePayments: e.value.onTime,
        averageDelayDays: avgDelay,
        onTimeRate: e.value.total > 0 ? e.value.onTime / e.value.total : 0.0,
      );
    }).toList()
      ..sort((a, b) => b.onTimeRate.compareTo(a.onTimeRate));
  }

  /// Calculate income sources breakdown
  List<IncomeSource> _calculateIncomeSources(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  ) {
    final investmentIncomeMap = <String, double>{};
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));

    // Sum income by investment (last 12 months)
    for (final cf in cashFlows) {
      if (cf.type != CashFlowType.income) continue;
      if (cf.date.isBefore(oneYearAgo)) continue;

      investmentIncomeMap[cf.investmentId] =
          (investmentIncomeMap[cf.investmentId] ?? 0.0) + cf.amount;
    }

    final totalIncome = investmentIncomeMap.values.fold<double>(0.0, (a, b) => a + b);
    if (totalIncome == 0) return [];

    // Convert to IncomeSource objects
    return investmentIncomeMap.entries.map((e) {
      final investment = investments.firstWhere(
        (inv) => inv.id == e.key,
        orElse: () => investments.first,
      );

      return IncomeSource(
        investmentId: e.key,
        investmentName: investment.name,
        platform: investment.platform ?? 'Unknown',
        totalIncome: e.value,
        percentage: (e.value / totalIncome) * 100,
      );
    }).toList()
      ..sort((a, b) => b.totalIncome.compareTo(a.totalIncome));
  }

  /// Calculate Herfindahl-Hirschman Index (HHI) for diversification
  ///
  /// Returns 0.0 to 1.0:
  /// - 0.0 to 0.15: Low concentration (well diversified)
  /// - 0.15 to 0.30: Moderate concentration
  /// - 0.30 to 0.50: High concentration
  /// - 0.50 to 1.0: Very high concentration (risky)
  double _calculateHHI(List<IncomeSource> sources) {
    if (sources.isEmpty) return 0.0;

    // HHI = sum of squared percentages (as decimals)
    final hhi = sources.fold<double>(
      0.0,
      (sum, source) {
        final decimal = source.percentage / 100;
        return sum + (decimal * decimal);
      },
    );

    return hhi;
  }

  /// Generate auto-insights based on analysis
  List<String> _generateInsights(
    {required double momGrowth,
    required double qoqGrowth,
    required double diversificationScore,
    required List<PlatformReliability> platformReliability,
    required List<IncomeSource> incomeSources}) {
    final insights = <String>[];

    // Growth insights
    if (momGrowth > 10) {
      insights.add('Strong growth! Your income grew ${momGrowth.toStringAsFixed(1)}% last month.');
    } else if (momGrowth > 0) {
      insights.add('Positive growth: ${momGrowth.toStringAsFixed(1)}% increase last month.');
    } else if (momGrowth < -10) {
      insights.add('Income declined ${momGrowth.abs().toStringAsFixed(1)}% last month. Review your investments.');
    }

    // Diversification insights
    if (diversificationScore > 0.50) {
      final topSource = incomeSources.isNotEmpty ? incomeSources.first : null;
      if (topSource != null) {
        insights.add('${topSource.percentage.toStringAsFixed(0)}% of income from ${topSource.investmentName}. Consider diversifying.');
      }
    } else if (diversificationScore < 0.15) {
      insights.add('Excellent diversification! Your income is well-balanced across investments.');
    }

    // Platform reliability insights
    if (platformReliability.isNotEmpty) {
      final unreliable = platformReliability.where((p) => p.onTimeRate < 0.80).toList();
      if (unreliable.isNotEmpty) {
        final platform = unreliable.first;
        insights.add('${platform.platform} is frequently late (${(platform.onTimeRate * 100).toStringAsFixed(0)}% on-time rate).');
      }

      final reliable = platformReliability.where((p) => p.onTimeRate >= 0.95).toList();
      if (reliable.isNotEmpty) {
        insights.add('${reliable.length} platforms with excellent reliability (95%+ on-time).');
      }
    }

    return insights;
  }
}
