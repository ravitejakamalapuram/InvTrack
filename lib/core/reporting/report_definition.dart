/// What a report contains. Weekly, monthly and yearly reports are constants
/// of this type; there is no per-report code.
library;

enum ReportMetric {
  invested,
  returned,
  income,
  fees,
  netCashFlow,
  periodXirr,
  portfolioValueStart,
  portfolioValueEnd,
}

enum Breakdown { byInvestmentType, byCurrency, byMonth }

class ReportDefinition {
  /// Stable id, used for caching and analytics-free routing.
  final String id;
  final List<ReportMetric> metrics;
  final List<Breakdown> breakdowns;

  /// Also compute the flow metrics for the previous period of the same kind.
  final bool comparePrevious;

  const ReportDefinition({
    required this.id,
    required this.metrics,
    this.breakdowns = const [],
    this.comparePrevious = false,
  });
}
