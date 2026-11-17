/// Notification payload types and parsing for deep linking.
///
/// Payloads are encoded as strings in the format: `type:param1:param2`
/// This allows the app to navigate to specific screens when notifications are tapped.
///
/// ## Supported Payload Types
///
/// ### Legacy Navigation (Phase 1)
/// - `income_reminder:investmentId` - Add cash flow screen
/// - `maturity_reminder:investmentId:days` - Investment detail with maturity context
/// - `milestone:investmentId:moic` - Investment detail with celebration
///
/// ### Dynamic Reports (Phase 2 - Current)
/// - `weekly_summary` - Weekly summary report
/// - `monthly_summary` - Monthly summary report
/// - `monthly_income` - Monthly income report
/// - `fy_summary` / `fy_report` - Financial year report
/// - `performance:investment:id` / `performance:goal:id` - Performance report
/// - `goal_progress:goalId:milestone%` - Goal progress report
/// - `maturity_calendar:investment:id:days:N` - Maturity calendar report
/// - `action_required` - Action items report
/// - `portfolio_health` - Portfolio health report
///
/// ### Future Notifications (Phase 3+)
/// - `tax_reminder`, `weekly_check_in`
/// - `goal_milestone`, `goal_at_risk`, `goal_stale`
/// - Activation campaigns (day_0, day_1, day_3, day_7, day_14)
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

  /// Navigate to the monthly recap of the month in params['month']
  monthlyRecap,

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

      case 'monthly_recap':
        return NotificationPayload(
          type: NotificationPayloadType.monthlyRecap,
          params: {if (parts.length > 1) 'month': parts[1]},
        );

      // Report notifications from before the Reports tab was removed: opening
      // one lands on Overview, because there is no report to show.
      case 'weekly_summary':
      case 'monthly_summary':
      case 'monthly_income':
      case 'fy_summary':
      case 'fy_report':
      case 'performance':
      case 'goal_progress':
      case 'maturity_calendar':
      case 'action_required':
      case 'portfolio_health':
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

      case 'weekly_check_in':
        // No investment is named, so open the list to pick one.
        return NotificationPayload(
          type: NotificationPayloadType.investmentList,
          params: {'flowType': 'income', 'source': 'weekly_check_in'},
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

      // Income Guardian was removed; an alert scheduled by an older version
      // opens Overview.
      case 'income_guardian_overdue':
      case 'income_guardian_upcoming':
      case 'income_guardian_received':
        return const NotificationPayload(
          type: NotificationPayloadType.overview,
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

  /// Create a payload string for the monthly recap of [monthKey] (yyyy-MM)
  static String monthlyRecap(String monthKey) => 'monthly_recap:$monthKey';

  // ============ Legacy/Phase 3 Notification Payloads ============

  /// Create a payload string for milestone celebration
  static String milestone(String investmentId, double moic) =>
      'milestone:$investmentId:${moic.toStringAsFixed(1)}';

  /// Create a payload string for tax reminder
  static String taxReminder(String reminderId) => 'tax_reminder:$reminderId';

  /// Create a payload string for weekly check-in
  static String get weeklyCheckIn => 'weekly_check_in';

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

  @override
  String toString() =>
      'NotificationPayload(type: $type, investmentId: $investmentId, goalId: $goalId, params: $params)';
}
