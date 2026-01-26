/// Notification constants, IDs, and preference keys.
///
/// This file contains all the constant values used by the notification system,
/// extracted from notification_service.dart for better organization.
library;

/// Notification channel IDs
class NotificationChannels {
  static const String weeklySummary = 'weekly_summary';
  static const String incomeReminders = 'income_reminders';
  static const String maturityReminders = 'maturity_reminders';
  static const String monthlySummary = 'monthly_summary';
  static const String milestones = 'milestones';
  static const String goalMilestones = 'goal_milestones';
  static const String taxReminders = 'tax_reminders';
  static const String riskAlerts = 'risk_alerts';
  static const String weeklyCheckIn = 'weekly_check_in';
  static const String idleAlerts = 'idle_alerts';
  static const String fySummary = 'fy_summary';
  static const String general = 'general'; // For test notifications
}

/// Notification group keys for Android grouping
class NotificationGroups {
  static const String incomeReminders = 'com.invtracker.INCOME_REMINDERS';
  static const String maturityReminders = 'com.invtracker.MATURITY_REMINDERS';
  static const String milestones = 'com.invtracker.MILESTONES';
  static const String goalMilestones = 'com.invtracker.GOAL_MILESTONES';
}

/// Notification IDs for scheduled notifications
class NotificationIds {
  static const int weeklySummary = 1000;
  static const int monthlySummary = 1001;

  /// Summary notification IDs for grouped notifications
  static const int incomeRemindersSummary = 1002;
  static const int maturityRemindersSummary = 1003;

  /// Tax reminder IDs (fixed dates throughout the year)
  static const int taxReminder80C = 1010;
  static const int taxReminderAdvanceQ1 = 1011;
  static const int taxReminderAdvanceQ2 = 1012;
  static const int taxReminderAdvanceQ3 = 1013;
  static const int taxReminderAdvanceQ4 = 1014;
  static const int taxReminderITR = 1015;

  /// Generate a unique notification ID for income reminders based on investment ID
  static int incomeReminder(String investmentId) =>
      (investmentId.hashCode.abs() % 50000) + 50000;

  /// Generate unique notification IDs for maturity reminders (7-day and 1-day before)
  static int maturityReminder7Days(String investmentId) =>
      (investmentId.hashCode.abs() % 25000) + 100000;
  static int maturityReminder1Day(String investmentId) =>
      (investmentId.hashCode.abs() % 25000) + 125000;

  /// Milestone notification ID based on investment ID and milestone type
  static int milestone(String investmentId, double moic) =>
      (investmentId.hashCode.abs() % 20000) + 150000 + (moic * 100).toInt();

  /// Risk alert notification ID
  static int riskAlert(String alertType) =>
      200000 + alertType.hashCode.abs() % 1000;

  /// Weekly check-in notification
  static const int weeklyCheckIn = 2000;

  /// Idle investment alert ID (per investment)
  static int idleAlert(String investmentId) =>
      210000 + investmentId.hashCode.abs() % 10000;

  /// FY summary notification
  static const int fySummary = 2001;

  /// Goal milestone notification ID based on goal ID and milestone percentage
  static int goalMilestone(String goalId, int milestonePercent) =>
      (goalId.hashCode.abs() % 20000) + 220000 + milestonePercent;

  /// Goal at-risk alert notification ID
  static int goalAtRisk(String goalId) =>
      (goalId.hashCode.abs() % 10000) + 240000;

  /// Goal stale alert notification ID
  static int goalStale(String goalId) =>
      (goalId.hashCode.abs() % 10000) + 250000;
}

/// Settings keys for notification preferences
class NotificationPrefsKeys {
  static const String weeklySummaryEnabled = 'notifications_weekly_summary';
  static const String incomeRemindersEnabled = 'notifications_income_reminders';
  static const String maturityRemindersEnabled =
      'notifications_maturity_reminders';
  static const String monthlySummaryEnabled = 'notifications_monthly_summary';
  static const String milestonesEnabled = 'notifications_milestones';
  static const String goalMilestonesEnabled = 'notifications_goal_milestones';
  static const String taxRemindersEnabled = 'notifications_tax_reminders';
  static const String riskAlertsEnabled = 'notifications_risk_alerts';
  static const String weeklyCheckInEnabled = 'notifications_weekly_check_in';
  static const String idleAlertsEnabled = 'notifications_idle_alerts';
  static const String idleAlertDays = 'notifications_idle_alert_days';
  static const String fySummaryEnabled = 'notifications_fy_summary';
  static const String goalAtRiskEnabled = 'notifications_goal_at_risk';
  static const String goalStaleEnabled = 'notifications_goal_stale';
  static const String goalStaleDays = 'notifications_goal_stale_days';

  /// Track which milestones have been shown (to avoid duplicates)
  static String milestoneShown(String investmentId, double moic) =>
      'milestone_shown_${investmentId}_${moic.toStringAsFixed(1)}';

  /// Track which goal milestones have been shown (to avoid duplicates)
  static String goalMilestoneShown(String goalId, int milestonePercent) =>
      'goal_milestone_shown_${goalId}_$milestonePercent';

  /// Track when idle alert was last shown for an investment
  static String idleAlertLastShown(String investmentId) =>
      'idle_alert_last_shown_$investmentId';

  /// Track when at-risk alert was last shown for a goal (show max once per week)
  static String goalAtRiskLastShown(String goalId) =>
      'goal_at_risk_last_shown_$goalId';

  /// Track when stale alert was last shown for a goal (show max once per month)
  static String goalStaleLastShown(String goalId) =>
      'goal_stale_last_shown_$goalId';
}

/// Helper class for tax reminders
class TaxReminder {
  final int id;
  final String title;
  final String body;
  final DateTime date;

  const TaxReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
  });
}

/// Info about an investment for idle checking
class IdleInvestmentInfo {
  final String id;
  final String name;
  final DateTime? lastActivityDate;
  final bool isClosed;

  const IdleInvestmentInfo({
    required this.id,
    required this.name,
    this.lastActivityDate,
    this.isClosed = false,
  });
}
