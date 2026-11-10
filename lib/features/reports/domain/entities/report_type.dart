/// Report types supported by InvTrack
///
/// Defines the different types of reports available:
/// - Dynamic reports: Generated on-demand from live data
/// - Static reports: Pre-generated snapshots stored in Firestore
library;

enum ReportType {
  /// Weekly investment activity summary (Dynamic)
  weeklySummary('weekly_summary', true),

  /// Monthly income report (Static + Dynamic)
  monthlyIncome('monthly_income', false),

  /// Financial year report (Static)
  fyReport('fy_report', false),

  /// Investment performance analysis (Dynamic)
  performance('performance', true),

  /// Goal progress tracking (Dynamic)
  goalProgress('goal_progress', true),

  /// Maturity calendar (Dynamic)
  maturityCalendar('maturity_calendar', true),

  /// Action required items (Dynamic)
  actionRequired('action_required', true),

  /// Portfolio health assessment (Dynamic)
  portfolioHealth('portfolio_health', true);

  /// Report type identifier (used in Firestore, analytics)
  final String id;

  /// Whether this is a dynamic report (true) or static (false)
  final bool isDynamic;

  const ReportType(this.id, this.isDynamic);

  /// Get report type from string ID
  static ReportType fromId(String id) {
    return ReportType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => throw ArgumentError('Unknown report type: $id'),
    );
  }

  /// Get all static report types
  static List<ReportType> get staticReports =>
      ReportType.values.where((type) => !type.isDynamic).toList();

  /// Get all dynamic report types
  static List<ReportType> get dynamicReports =>
      ReportType.values.where((type) => type.isDynamic).toList();

  /// Get priority 0 reports (core reports shown first)
  static List<ReportType> get coreReports => [
        weeklySummary,
        monthlyIncome,
        fyReport,
        performance,
        goalProgress,
      ];
}
