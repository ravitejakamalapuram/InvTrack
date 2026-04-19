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

  // ============ Notification Report Screens ============

  /// Navigate to weekly summary report screen
  weeklySummaryReport,

  /// Navigate to monthly summary report screen
  monthlySummaryReport,

  /// Navigate to maturity reminder report screen
  maturityReport,

  /// Navigate to income alert report screen
  incomeReport,

  /// Navigate to milestone report screen
  milestoneReport,

  /// Navigate to goal milestone report screen
  goalMilestoneReport,

  /// Navigate to goal at-risk report screen
  goalAtRiskReport,

  /// Navigate to goal stale report screen
  goalStaleReport,

  /// Navigate to risk alert report screen
  riskAlertReport,

  /// Navigate to idle alert report screen
  idleAlertReport,

  /// Navigate to FY summary report screen
  fySummaryReport,
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
          type: NotificationPayloadType.incomeReport,
          investmentId: parts.length > 1 ? parts[1] : null,
          params: {
            'flowType': 'income',
            'expectedIncome': parts.length > 2 ? parts[2] : '0',
          },
        );

      case 'maturity_reminder':
        return NotificationPayload(
          type: NotificationPayloadType.maturityReport,
          investmentId: parts.length > 1 ? parts[1] : null,
          params: {
            'daysToMaturity': parts.length > 2 ? parts[2] : '0',
            'expectedAmount': parts.length > 3 ? parts[3] : '0',
          },
        );

      case 'weekly_summary':
        return const NotificationPayload(
          type: NotificationPayloadType.weeklySummaryReport,
        );

      case 'monthly_summary':
        return const NotificationPayload(
          type: NotificationPayloadType.monthlySummaryReport,
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
          type: NotificationPayloadType.fySummaryReport,
        );

      case 'milestone':
        return NotificationPayload(
          type: NotificationPayloadType.milestoneReport,
          investmentId: parts.length > 1 ? parts[1] : null,
          params: {
            'milestonePercent': parts.length > 2 ? parts[2] : '0',
          },
        );

      case 'goal_milestone':
        return NotificationPayload(
          type: NotificationPayloadType.goalMilestoneReport,
          goalId: parts.length > 1 ? parts[1] : null,
          params: {
            'milestonePercent': parts.length > 2 ? parts[2] : '0',
          },
        );

      case 'goal_at_risk':
        return NotificationPayload(
          type: NotificationPayloadType.goalAtRiskReport,
          goalId: parts.length > 1 ? parts[1] : null,
        );

      case 'goal_stale':
        return NotificationPayload(
          type: NotificationPayloadType.goalStaleReport,
          goalId: parts.length > 1 ? parts[1] : null,
          params: {
            'daysSinceActivity': parts.length > 2 ? parts[2] : '0',
          },
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
  static String milestone(String investmentId, int milestonePercent) =>
      'milestone:$investmentId:$milestonePercent';

  /// Create a payload string for tax reminder
  static String taxReminder(String reminderId) => 'tax_reminder:$reminderId';

  /// Create a payload string for risk alert
  static String riskAlert(String alertType) => 'risk_alert:$alertType';

  /// Create a payload string for weekly check-in
  static String get weeklyCheckIn => 'weekly_check_in';

  /// Create a payload string for idle investment alert
  static String idleAlert(String investmentId, int daysSinceActivity) =>
      'idle_alert:$investmentId:$daysSinceActivity';

  /// Create a payload string for FY summary
  static String get fySummary => 'fy_summary';

  /// Create a payload string for goal milestone celebration
  static String goalMilestone(String goalId, int milestonePercent) =>
      'goal_milestone:$goalId:$milestonePercent';

  /// Create a payload string for goal at-risk alert
  static String goalAtRisk(String goalId) => 'goal_at_risk:$goalId';

  /// Create a payload string for goal stale alert
  static String goalStale(String goalId, int daysSinceActivity) =>
      'goal_stale:$goalId:$daysSinceActivity';

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

  @override
  String toString() =>
      'NotificationPayload(type: $type, investmentId: $investmentId, goalId: $goalId, params: $params)';
}
