/// Report types supported by InvTrack
///
/// Defines the different types of reports available:
/// - Dynamic reports: Generated on-demand from live data
/// - Static reports: Pre-generated snapshots stored in Firestore
library;

enum ReportType {
  /// Weekly investment activity summary (Dynamic)
  weeklySummary('weekly_summary', 'Weekly Summary', true),

  /// Monthly income report (Static + Dynamic)
  monthlyIncome('monthly_income', 'Monthly Income', false),

  /// Financial year report (Static)
  fyReport('fy_report', 'FY Report', false),

  /// Investment performance analysis (Dynamic)
  performance('performance', 'Performance', true),

  /// Goal progress tracking (Dynamic)
  goalProgress('goal_progress', 'Goal Progress', true),

  /// Maturity calendar (Dynamic)
  maturityCalendar('maturity_calendar', 'Maturity Calendar', true),

  /// Action required items (Dynamic)
  actionRequired('action_required', 'Action Required', true),

  /// Portfolio health assessment (Dynamic)
  portfolioHealth('portfolio_health', 'Portfolio Health', true);

  /// Report type identifier (used in Firestore, analytics)
  final String id;

  /// Display name for UI
  final String displayName;

  /// Whether this is a dynamic report (true) or static (false)
  final bool isDynamic;

  const ReportType(this.id, this.displayName, this.isDynamic);

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
