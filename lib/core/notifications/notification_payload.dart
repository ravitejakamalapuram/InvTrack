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

  const NotificationPayload({
    required this.type,
    this.investmentId,
    this.goalId,
    this.params = const {},
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
      case 'monthly_summary':
        return const NotificationPayload(
          type: NotificationPayloadType.overview,
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
        return const NotificationPayload(
          type: NotificationPayloadType.overview,
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

  @override
  String toString() =>
      'NotificationPayload(type: $type, investmentId: $investmentId, goalId: $goalId, params: $params)';
}
