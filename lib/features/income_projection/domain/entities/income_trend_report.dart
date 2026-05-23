/// Income Trend Analysis Report Entity
///
/// Provides comprehensive income trend analytics including growth metrics,
/// platform reliability scoring, and income diversification analysis.
library;

/// Monthly income data point
class MonthlyIncomeData {
  final DateTime month;
  final double totalIncome;
  final int paymentCount;
  final String currency;

  const MonthlyIncomeData({
    required this.month,
    required this.totalIncome,
    required this.paymentCount,
    required this.currency,
  });

  @override
  String toString() => 'MonthlyIncomeData(month: $month, income: $totalIncome)';
}

/// Platform reliability metrics
class PlatformReliability {
  final String platform;
  final int totalPayments;
  final int onTimePayments;
  final double averageDelayDays;
  final double onTimeRate; // 0.0 to 1.0

  const PlatformReliability({
    required this.platform,
    required this.totalPayments,
    required this.onTimePayments,
    required this.averageDelayDays,
    required this.onTimeRate,
  });



  @override
  String toString() => 'PlatformReliability($platform: $onTimeRate)';
}

/// Income source breakdown for diversification analysis
class IncomeSource {
  final String investmentId;
  final String investmentName;
  final String platform;
  final double totalIncome;
  final double percentage; // % of total portfolio income

  const IncomeSource({
    required this.investmentId,
    required this.investmentName,
    required this.platform,
    required this.totalIncome,
    required this.percentage,
  });

  @override
  String toString() => 'IncomeSource($investmentName: $percentage%)';
}

/// Income Trend Report
class IncomeTrendReport {
  /// Report generation timestamp
  final DateTime generatedAt;

  /// Monthly income data (last 12 months)
  final List<MonthlyIncomeData> monthlyData;

  /// Month-over-month growth rate
  final double momGrowth;

  /// Quarter-over-quarter growth rate
  final double qoqGrowth;

  /// 6-month rolling average
  final double sixMonthAverage;

  /// Platform reliability scores
  final List<PlatformReliability> platformReliability;

  /// Income diversification score (0.0 to 1.0)
  /// 0.0 = perfect diversification, 1.0 = single source
  /// Based on Herfindahl-Hirschman Index (HHI)
  final double diversificationScore;

  /// Breakdown of income sources
  final List<IncomeSource> incomeSources;

  /// Auto-generated insights
  final List<String> insights;

  /// Total income (last 12 months)
  final double totalIncome;

  /// Average monthly income
  final double averageMonthlyIncome;

  /// Currency
  final String currency;

  const IncomeTrendReport({
    required this.generatedAt,
    required this.monthlyData,
    required this.momGrowth,
    required this.qoqGrowth,
    required this.sixMonthAverage,
    required this.platformReliability,
    required this.diversificationScore,
    required this.incomeSources,
    required this.insights,
    required this.totalIncome,
    required this.averageMonthlyIncome,
    required this.currency,
  });

  /// Diversification risk level
  String get diversificationRisk {
    if (diversificationScore < 0.15) return 'Low';
    if (diversificationScore < 0.30) return 'Moderate';
    if (diversificationScore < 0.50) return 'High';
    return 'Very High';
  }

  /// Growth trend description
  String get growthTrend {
    if (momGrowth > 5) return 'Strong Growth';
    if (momGrowth > 0) return 'Positive Growth';
    if (momGrowth > -5) return 'Stable';
    return 'Declining';
  }

  @override
  String toString() {
    return 'IncomeTrendReport(generatedAt: $generatedAt, '
        'totalIncome: $totalIncome, momGrowth: $momGrowth%, '
        'diversificationScore: $diversificationScore)';
  }
}
