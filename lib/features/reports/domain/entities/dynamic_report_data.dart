/// Dynamic Report Data Entity
///
/// Represents the unified data structure returned by the ReportBuilderService.
/// All report screens render from this unified model.
library;

import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';

/// Dynamic report data that can represent any report type
class DynamicReportData {
  /// Type of report
  final ReportType reportType;

  /// Report title (localized, can be customized)
  final String title;

  /// Report sections (KPIs, charts, lists, etc.)
  final List<ReportSection> sections;

  /// Optional date range the report covers
  final DateRangeFilter? dateRange;

  /// Filtered investment ID if report is scoped to specific investment
  final String? filteredInvestmentId;

  /// Filtered goal ID if report is scoped to specific goal
  final String? filteredGoalId;

  /// Original configuration used to build this report
  final ReportConfiguration configuration;

  /// When the report was generated
  final DateTime generatedAt;

  /// Whether this report has data to display
  final bool hasData;

  /// Empty state message if no data
  final String? emptyStateMessage;

  DynamicReportData({
    required this.reportType,
    required this.title,
    required this.sections,
    required this.configuration,
    this.dateRange,
    this.filteredInvestmentId,
    this.filteredGoalId,
    DateTime? generatedAt,
    this.hasData = true,
    this.emptyStateMessage,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Create an empty report (no data state)
  factory DynamicReportData.empty({
    required ReportType reportType,
    required String title,
    required ReportConfiguration configuration,
    String? emptyStateMessage,
  }) {
    return DynamicReportData(
      reportType: reportType,
      title: title,
      sections: [],
      configuration: configuration,
      hasData: false,
      emptyStateMessage: emptyStateMessage,
    );
  }
}

/// Represents a section in the report
class ReportSection {
  /// Section type determines how it's rendered
  final ReportSectionType type;

  /// Section title
  final String title;

  /// Section data (structure depends on type)
  final dynamic data;

  /// Optional subtitle or description
  final String? subtitle;

  /// Optional icon for the section
  final String? icon;

  const ReportSection({
    required this.type,
    required this.title,
    required this.data,
    this.subtitle,
    this.icon,
  });
}

/// Types of report sections
enum ReportSectionType {
  /// Key Performance Indicators (metrics grid)
  kpiGrid,

  /// Single key metric
  kpiCard,

  /// Line/bar chart
  chart,

  /// List of items (investments, transactions, etc.)
  itemList,

  /// Text-based summary
  textSummary,

  /// Action buttons/CTAs
  actionButtons,

  /// Custom widget (for special cases)
  custom,

  /// Top performer card
  topPerformer,

  /// Calendar view (for maturities)
  calendar,

  /// Progress indicator
  progress,
}

/// KPI (Key Performance Indicator) data
class KpiData {
  final String label;
  final String value;
  final String? icon;
  final String? trend;
  final bool? isTrendPositive;
  final String? subtitle;

  const KpiData({
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.isTrendPositive,
    this.subtitle,
  });
}

/// Chart data
class ChartData {
  final List<ChartDataPoint> dataPoints;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final ChartType chartType;

  const ChartData({
    required this.dataPoints,
    this.xAxisLabel,
    this.yAxisLabel,
    this.chartType = ChartType.bar,
  });
}

enum ChartType {
  bar,
  line,
  pie,
}

class ChartDataPoint {
  final String label;
  final double value;
  final DateTime? date;

  const ChartDataPoint({
    required this.label,
    required this.value,
    this.date,
  });
}
