/// Dynamic Report Configuration Entity
///
/// Defines the parameters and filters needed to build any report dynamically.
/// This is the core of the builder pattern - all report screens use this config.
library;

import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';

/// Report configuration for dynamic report building
class ReportConfiguration {
  /// Type of report to generate
  final ReportType reportType;

  /// Optional date range filter
  final DateRangeFilter? dateRange;

  /// Optional specific investment ID filter
  final String? investmentId;

  /// Optional specific goal ID filter
  final String? goalId;

  /// Custom filters as key-value pairs
  final Map<String, dynamic> customFilters;

  /// Additional parameters for report-specific logic
  final Map<String, dynamic> parameters;

  /// Report title override (optional, defaults to report type title)
  final String? titleOverride;

  /// Whether this report is from a notification
  final bool fromNotification;

  /// Notification context if applicable
  final NotificationContext? notificationContext;

  const ReportConfiguration({
    required this.reportType,
    this.dateRange,
    this.investmentId,
    this.goalId,
    this.customFilters = const {},
    this.parameters = const {},
    this.titleOverride,
    this.fromNotification = false,
    this.notificationContext,
  });

  /// Create a weekly summary report configuration
  factory ReportConfiguration.weeklySummary({
    DateTime? startDate,
    DateTime? endDate,
    NotificationContext? notificationContext,
  }) {
    final now = DateTime.now();
    final weekStart = startDate ?? _getWeekStart(now);
    final weekEnd = endDate ?? _getWeekEnd(now);

    return ReportConfiguration(
      reportType: ReportType.weeklySummary,
      dateRange: DateRangeFilter(start: weekStart, end: weekEnd),
      fromNotification: notificationContext != null,
      notificationContext: notificationContext,
    );
  }

  /// Create a monthly income report configuration
  factory ReportConfiguration.monthlyIncome({
    DateTime? month,
    NotificationContext? notificationContext,
  }) {
    final period = month ?? DateTime.now();
    final start = DateTime(period.year, period.month, 1);
    final end = DateTime(period.year, period.month + 1, 0);

    return ReportConfiguration(
      reportType: ReportType.monthlyIncome,
      dateRange: DateRangeFilter(start: start, end: end),
      fromNotification: notificationContext != null,
      notificationContext: notificationContext,
    );
  }

  /// Create an FY report configuration
  factory ReportConfiguration.fyReport({
    int? fyYear,
    NotificationContext? notificationContext,
  }) {
    final now = DateTime.now();
    final year = fyYear ?? (now.month >= 4 ? now.year : now.year - 1);
    final start = DateTime(year, 4, 1);
    final end = DateTime(year + 1, 3, 31);

    return ReportConfiguration(
      reportType: ReportType.fyReport,
      dateRange: DateRangeFilter(start: start, end: end),
      parameters: {'fyYear': year},
      fromNotification: notificationContext != null,
      notificationContext: notificationContext,
    );
  }

  /// Create a maturity calendar report configuration
  factory ReportConfiguration.maturityCalendar({
    String? investmentId,
    int? daysToMaturity,
    NotificationContext? notificationContext,
  }) {
    return ReportConfiguration(
      reportType: ReportType.maturityCalendar,
      investmentId: investmentId,
      parameters: {
        if (daysToMaturity != null) 'daysToMaturity': daysToMaturity,
      },
      fromNotification: notificationContext != null,
      notificationContext: notificationContext,
    );
  }

  /// Create a goal progress report configuration
  factory ReportConfiguration.goalProgress({
    String? goalId,
    int? milestonePercent,
    NotificationContext? notificationContext,
  }) {
    return ReportConfiguration(
      reportType: ReportType.goalProgress,
      goalId: goalId,
      parameters: {
        if (milestonePercent != null) 'milestonePercent': milestonePercent,
      },
      fromNotification: notificationContext != null,
      notificationContext: notificationContext,
    );
  }

  /// Create a performance report configuration
  factory ReportConfiguration.performance({
    NotificationContext? notificationContext,
  }) {
    return ReportConfiguration(
      reportType: ReportType.performance,
      fromNotification: notificationContext != null,
      notificationContext: notificationContext,
    );
  }

  /// Create an action required report configuration
  factory ReportConfiguration.actionRequired({
    NotificationContext? notificationContext,
  }) {
    return ReportConfiguration(
      reportType: ReportType.actionRequired,
      fromNotification: notificationContext != null,
      notificationContext: notificationContext,
    );
  }

  /// Create a portfolio health report configuration
  factory ReportConfiguration.portfolioHealth({
    NotificationContext? notificationContext,
  }) {
    return ReportConfiguration(
      reportType: ReportType.portfolioHealth,
      fromNotification: notificationContext != null,
      notificationContext: notificationContext,
    );
  }

  /// Copy with modifications
  ReportConfiguration copyWith({
    ReportType? reportType,
    DateRangeFilter? dateRange,
    String? investmentId,
    String? goalId,
    Map<String, dynamic>? customFilters,
    Map<String, dynamic>? parameters,
    String? titleOverride,
    bool? fromNotification,
    NotificationContext? notificationContext,
  }) {
    return ReportConfiguration(
      reportType: reportType ?? this.reportType,
      dateRange: dateRange ?? this.dateRange,
      investmentId: investmentId ?? this.investmentId,
      goalId: goalId ?? this.goalId,
      customFilters: customFilters ?? this.customFilters,
      parameters: parameters ?? this.parameters,
      titleOverride: titleOverride ?? this.titleOverride,
      fromNotification: fromNotification ?? this.fromNotification,
      notificationContext: notificationContext ?? this.notificationContext,
    );
  }

  /// Convert to query parameters for deep linking
  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'type': reportType.id,
    };

    if (investmentId != null) params['investmentId'] = investmentId!;
    if (goalId != null) params['goalId'] = goalId!;
    if (dateRange != null) {
      params['startDate'] = dateRange!.start.toIso8601String();
      params['endDate'] = dateRange!.end.toIso8601String();
    }

    // Add custom parameters
    parameters.forEach((key, value) {
      params[key] = value.toString();
    });

    if (fromNotification) {
      params['fromNotification'] = 'true';
      if (notificationContext != null) {
        params['notificationType'] = notificationContext!.notificationType;
      }
    }

    return params;
  }

  /// Parse from query parameters (for deep linking)
  factory ReportConfiguration.fromQueryParams(Map<String, String> params) {
    final reportType = ReportType.fromId(params['type'] ?? 'weekly_summary');
    final investmentId = params['investmentId'];
    final goalId = params['goalId'];

    DateRangeFilter? dateRange;
    if (params['startDate'] != null && params['endDate'] != null) {
      dateRange = DateRangeFilter(
        start: DateTime.parse(params['startDate']!),
        end: DateTime.parse(params['endDate']!),
      );
    }

    final fromNotification = params['fromNotification'] == 'true';
    NotificationContext? notificationContext;
    if (fromNotification && params['notificationType'] != null) {
      notificationContext = NotificationContext(
        notificationType: params['notificationType']!,
        timestamp: DateTime.now(),
      );
    }

    // Extract custom parameters
    final reservedKeys = {
      'type',
      'investmentId',
      'goalId',
      'startDate',
      'endDate',
      'fromNotification',
      'notificationType',
    };
    final customParams = Map<String, dynamic>.fromEntries(
      params.entries
          .where((e) => !reservedKeys.contains(e.key))
          .map((e) => MapEntry(e.key, e.value)),
    );

    return ReportConfiguration(
      reportType: reportType,
      investmentId: investmentId,
      goalId: goalId,
      dateRange: dateRange,
      parameters: customParams,
      fromNotification: fromNotification,
      notificationContext: notificationContext,
    );
  }

  @override
  String toString() =>
      'ReportConfiguration(type: $reportType, investmentId: $investmentId, '
      'goalId: $goalId, dateRange: $dateRange, fromNotification: $fromNotification)';

  // Helper methods
  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  static DateTime _getWeekEnd(DateTime date) {
    final weekday = date.weekday;
    return date.add(Duration(days: 7 - weekday));
  }
}

/// Date range filter for reports
class DateRangeFilter {
  final DateTime start;
  final DateTime end;

  const DateRangeFilter({
    required this.start,
    required this.end,
  });

  /// Duration between start and end
  Duration get duration => end.difference(start);

  /// Check if a date is within this range
  bool contains(DateTime date) {
    return date.isAfter(start.subtract(const Duration(days: 1))) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }

  @override
  String toString() => 'DateRangeFilter(${start.toIso8601String()} - ${end.toIso8601String()})';
}

/// Notification context for reports triggered by notifications
class NotificationContext {
  /// Type of notification that triggered this report
  final String notificationType;

  /// Timestamp when notification was sent
  final DateTime timestamp;

  /// Optional additional data from notification
  final Map<String, dynamic> additionalData;

  const NotificationContext({
    required this.notificationType,
    required this.timestamp,
    this.additionalData = const {},
  });

  @override
  String toString() => 'NotificationContext($notificationType at $timestamp)';
}

