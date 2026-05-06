/// Notification payload types and parsing for deep linking.
///
/// Payloads are encoded as strings in the format: `type:param1:param2`
/// This allows the app to navigate to specific screens when notifications are tapped.
library;

/// Notification action IDs for Android action buttons
class NotificationActionIds {
  // Income reminder actions
  static const String recordIncome = 'record_income';
  static const String snoozeOneDay = 'snooze_1day';
  static const String viewDetails = 'view_details';

  // Maturity reminder actions
  static const String viewMaturity = 'view_maturity';
  static const String markComplete = 'mark_complete';
}

/// Types of notification payloads for deep linking
enum NotificationPayloadType {
  /// Navigate to investment list
  investmentList,

  /// Navigate to specific investment detail
  investmentDetail,

  /// Navigate to add cash flow screen for specific investment
  addCashFlow,

  /// Navigate to overview/summary screen
  overview,

  /// Navigate to goal detail screen
  goalDetail,

  /// Navigate to dynamic report screen with filters
  dynamicReport,

  /// Snooze notification (reschedule for later)
  snooze,

  /// Generic/unknown payload (no navigation)
  unknown,
}

/// Parsed notification payload with type and parameters
class NotificationPayload {
  final NotificationPayloadType type;
  final String? investmentId;
  final String? goalId;
  final Map<String, String> params;

  /// Report configuration parameters (for dynamicReport type)
  /// Format: reportType, investmentId, goalId, startDate, endDate
  final Map<String, String> reportParams;

  const NotificationPayload({
    required this.type,
    this.investmentId,
    this.goalId,
    this.params = const {},
    this.reportParams = const {},
  });

  /// Parse a payload string into a structured payload
  ///
  /// Payload formats:
  /// - `income_reminder:investmentId` - Navigate to investment detail with add cash flow prompt
  /// - `maturity_reminder:investmentId:days` - Navigate to investment detail
  /// - `weekly_summary` - Navigate to overview
  /// - `monthly_summary` - Navigate to overview
  /// - `test_notification` - No navigation
  factory NotificationPayload.parse(String? payloadString) {
    if (payloadString == null || payloadString.isEmpty) {
      return const NotificationPayload(type: NotificationPayloadType.unknown);
    }

    final parts = payloadString.split(':');
    final type = parts[0];

    switch (type) {
      case 'income_reminder':
        return NotificationPayload(
          type: NotificationPayloadType.addCashFlow,
          investmentId: parts.length > 1 ? parts[1] : null,
          params: {'flowType': 'income'},
        );

      case 'maturity_reminder':
        return NotificationPayload(
          type: NotificationPayloadType.investmentDetail,
          investmentId: parts.length > 1 ? parts[1] : null,
          params: {
            'daysToMaturity': parts.length > 2 ? parts[2] : '0',
            'showMaturityAction': 'true',
          },
        );

      case 'weekly_summary':
        // New: Navigate to dynamic weekly summary report
        return NotificationPayload(
          type: NotificationPayloadType.dynamicReport,
          reportParams: {
            'reportType': 'weekly_summary',
            'notificationContext': 'true',
          },
        );

      case 'monthly_summary':
      case 'monthly_income':
        // New: Navigate to dynamic monthly income report
        return NotificationPayload(
          type: NotificationPayloadType.dynamicReport,
          reportParams: {
            'reportType': 'monthly_income',
            'notificationContext': 'true',
          },
        );

      case 'milestone':
        return NotificationPayload(
          type: NotificationPayloadType.investmentDetail,
          investmentId: parts.length > 1 ? parts[1] : null,
          params: {
            'moic': parts.length > 2 ? parts[2] : '0',
            'celebration': 'true',
          },
        );

      case 'tax_reminder':
        return const NotificationPayload(
          type: NotificationPayloadType.overview,
        );

      case 'risk_alert':
        return NotificationPayload(
          type: NotificationPayloadType.overview,
          params: {'alertType': parts.length > 1 ? parts[1] : 'unknown'},
        );

      case 'weekly_check_in':
        return NotificationPayload(
          type: NotificationPayloadType.addCashFlow,
          params: {'flowType': 'income', 'source': 'weekly_check_in'},
        );

      case 'idle_alert':
        return NotificationPayload(
          type: NotificationPayloadType.investmentDetail,
          investmentId: parts.length > 1 ? parts[1] : null,
          params: {'source': 'idle_alert'},
        );

      case 'fy_summary':
      case 'fy_report':
        // New: Navigate to dynamic FY report
        return NotificationPayload(
          type: NotificationPayloadType.dynamicReport,
          reportParams: {
            'reportType': 'fy_report',
            'notificationContext': 'true',
          },
        );

      case 'goal_milestone':
        return NotificationPayload(
          type: NotificationPayloadType.goalDetail,
          goalId: parts.length > 1 ? parts[1] : null,
          params: {
            'milestonePercent': parts.length > 2 ? parts[2] : '0',
            'celebration': 'true',
          },
        );

      case 'goal_at_risk':
        return NotificationPayload(
          type: NotificationPayloadType.goalDetail,
          goalId: parts.length > 1 ? parts[1] : null,
          params: {'source': 'at_risk'},
        );

      case 'goal_stale':
        return NotificationPayload(
          type: NotificationPayloadType.goalDetail,
          goalId: parts.length > 1 ? parts[1] : null,
          params: {'source': 'stale'},
        );

      case 'test_notification':
      case 'test_scheduled_notification':
        return const NotificationPayload(type: NotificationPayloadType.unknown);

      // New user activation sequence - all navigate to overview/add investment
      case 'activation_day_0':
      case 'activation_day_1':
      case 'activation_day_3':
      case 'activation_day_7':
      case 'activation_day_14':
        return NotificationPayload(
          type: NotificationPayloadType.overview,
          params: {'source': 'activation', 'day': type.split('_').last},
        );

      default:
        // Try to extract investment ID from unknown formats
        if (parts.length > 1 && parts[1].isNotEmpty) {
          return NotificationPayload(
            type: NotificationPayloadType.investmentDetail,
            investmentId: parts[1],
          );
        }
        return const NotificationPayload(type: NotificationPayloadType.unknown);
    }
  }

  /// Create a payload string for income reminder
  static String incomeReminder(String investmentId) =>
      'income_reminder:$investmentId';

  /// Create a payload string for maturity reminder
  static String maturityReminder(String investmentId, int daysToMaturity) =>
      'maturity_reminder:$investmentId:$daysToMaturity';

  /// Create a payload string for weekly summary
  static String get weeklySummary => 'weekly_summary';

  /// Create a payload string for monthly summary
  static String get monthlySummary => 'monthly_summary';

  /// Create a payload string for milestone celebration
  static String milestone(String investmentId, double moic) =>
      'milestone:$investmentId:${moic.toStringAsFixed(1)}';

  /// Create a payload string for tax reminder
  static String taxReminder(String reminderId) => 'tax_reminder:$reminderId';

  /// Create a payload string for risk alert
  static String riskAlert(String alertType) => 'risk_alert:$alertType';

  /// Create a payload string for weekly check-in
  static String get weeklyCheckIn => 'weekly_check_in';

  /// Create a payload string for idle investment alert
  static String idleAlert(String investmentId) => 'idle_alert:$investmentId';

  /// Create a payload string for FY summary
  static String get fySummary => 'fy_summary';

  /// Create a payload string for goal milestone celebration
  static String goalMilestone(String goalId, int milestonePercent) =>
      'goal_milestone:$goalId:$milestonePercent';

  /// Create a payload string for goal at-risk alert
  static String goalAtRisk(String goalId) => 'goal_at_risk:$goalId';

  /// Create a payload string for goal stale alert
  static String goalStale(String goalId) => 'goal_stale:$goalId';

  // ============ New User Activation Payloads ============

  /// Create a payload string for Day 0 activation (welcome)
  static String get activationDay0 => 'activation_day_0';

  /// Create a payload string for Day 1 activation (first investment nudge)
  static String get activationDay1 => 'activation_day_1';

  /// Create a payload string for Day 3 activation (import reminder)
  static String get activationDay3 => 'activation_day_3';

  /// Create a payload string for Day 7 activation (tips & benefits)
  static String get activationDay7 => 'activation_day_7';

  /// Create a payload string for Day 14 activation (social proof)
  static String get activationDay14 => 'activation_day_14';

  // ============ Dynamic Report Payloads ============

  /// Create a payload string for weekly summary report
  static String get weeklySummaryReport => 'weekly_summary';

  /// Create a payload string for monthly income report
  static String get monthlyIncomeReport => 'monthly_income';

  /// Create a payload string for FY report
  static String get fyReportPayload => 'fy_report';

  /// Create a payload string for performance report
  static String performanceReport({String? investmentId, String? goalId}) {
    final parts = ['performance'];
    if (investmentId != null) parts.add('investment:$investmentId');
    if (goalId != null) parts.add('goal:$goalId');
    return parts.join(':');
  }

  /// Create a payload string for goal progress report
  static String goalProgressReport(String goalId, {int? milestonePercent}) {
    final parts = ['goal_progress', goalId];
    if (milestonePercent != null) parts.add(milestonePercent.toString());
    return parts.join(':');
  }

  /// Create a payload string for maturity calendar report
  static String maturityCalendarReport({String? investmentId, int? daysAhead}) {
    final parts = ['maturity_calendar'];
    if (investmentId != null) parts.add('investment:$investmentId');
    if (daysAhead != null) parts.add('days:$daysAhead');
    return parts.join(':');
  }

  @override
  String toString() =>
      'NotificationPayload(type: $type, investmentId: $investmentId, goalId: $goalId, params: $params, reportParams: $reportParams)';
}
