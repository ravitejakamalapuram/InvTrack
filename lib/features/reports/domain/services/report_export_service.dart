/// Report Export Service Interface
///
/// Defines the contract for exporting reports to different formats
library;

/// Export format types
enum ExportFormat {
  csv,
  pdf;

  String get displayName {
    switch (this) {
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.pdf:
        return 'PDF';
    }
  }

  String get fileExtension {
    switch (this) {
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.pdf:
        return 'pdf';
    }
  }

  String get mimeType {
    switch (this) {
      case ExportFormat.csv:
        return 'text/csv';
      case ExportFormat.pdf:
        return 'application/pdf';
    }
  }
}

/// Report type identifier
enum ReportType {
  weeklySummary,
  monthlyIncome,
  fyReport,
  performance,
  goalProgress,
  maturityCalendar,
  actionRequired,
  portfolioHealth;

  String get displayName {
    switch (this) {
      case ReportType.weeklySummary:
        return 'Weekly Summary';
      case ReportType.monthlyIncome:
        return 'Monthly Income';
      case ReportType.fyReport:
        return 'Financial Year Report';
      case ReportType.performance:
        return 'Performance Report';
      case ReportType.goalProgress:
        return 'Goal Progress';
      case ReportType.maturityCalendar:
        return 'Maturity Calendar';
      case ReportType.actionRequired:
        return 'Action Required';
      case ReportType.portfolioHealth:
        return 'Portfolio Health';
    }
  }

  String get fileName {
    switch (this) {
      case ReportType.weeklySummary:
        return 'weekly_summary';
      case ReportType.monthlyIncome:
        return 'monthly_income';
      case ReportType.fyReport:
        return 'fy_report';
      case ReportType.performance:
        return 'performance_report';
      case ReportType.goalProgress:
        return 'goal_progress';
      case ReportType.maturityCalendar:
        return 'maturity_calendar';
      case ReportType.actionRequired:
        return 'action_required';
      case ReportType.portfolioHealth:
        return 'portfolio_health';
    }
  }
}

/// Base interface for report exporters
abstract class ReportExporter<T> {
  /// Export report data to file
  /// Returns the file path of the exported report
  Future<String> export({
    required T reportData,
    required ReportType reportType,
    String? currencySymbol,
    String? locale,
  });
}

/// Export result with metadata
class ExportResult {
  final String filePath;
  final ExportFormat format;
  final ReportType reportType;
  final int fileSizeBytes;
  final DateTime exportedAt;

  const ExportResult({
    required this.filePath,
    required this.format,
    required this.reportType,
    required this.fileSizeBytes,
    required this.exportedAt,
  });

  String get fileSizeKB => (fileSizeBytes / 1024).toStringAsFixed(1);
}
