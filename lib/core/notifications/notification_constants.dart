/// Notification constants, IDs, and preference keys.
///
/// This file contains all the constant values used by the notification system,
/// extracted from notification_service.dart for better organization.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Notification channel IDs.
///
/// Android fixes a channel's importance when it is first created, so channels
/// whose importance was lowered (A29) carry a `_v2` suffix to get a new one.
class NotificationChannels {
  static const String weeklySummary = 'weekly_summary_v2';
  static const String incomeReminders = 'income_reminders';
  static const String maturityReminders = 'maturity_reminders';
  static const String monthlySummary = 'monthly_summary_v2';
  static const String monthlyRecap = 'monthly_recap';
  static const String milestones = 'milestones_v2';
  static const String goalMilestones = 'goal_milestones_v2';
  static const String taxReminders = 'tax_reminders';
  static const String weeklyCheckIn = 'weekly_check_in';
  static const String fySummary = 'fy_summary_v2';
  static const String general = 'general'; // For test notifications
  static const String activation = 'activation_v2'; // New user activation nudges
  static const String incomeGuardian =
      'income_guardian'; // Income Guardian alerts
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

  /// Notification ID for an investment's income reminder, in [50000, 100000).
  /// One investment, one ID, never shared (see [NotificationIdSlots]).
  static int incomeReminder(String investmentId) =>
      50000 + NotificationIdSlots.slot('income', investmentId, 50000);

  /// Notification IDs for an investment's maturity reminders (7-day in
  /// [100000, 125000), 1-day in [125000, 150000)).
  static int maturityReminder7Days(String investmentId) =>
      100000 + NotificationIdSlots.slot('maturity', investmentId, 25000);
  static int maturityReminder1Day(String investmentId) =>
      125000 + NotificationIdSlots.slot('maturity', investmentId, 25000);

  /// Whether [id] lies in the income-reminder range (see [incomeReminder]).
  static bool isIncomeReminderId(int id) => id >= 50000 && id < 100000;

  /// Whether [id] lies in the maturity-reminder ranges (7-day and 1-day).
  static bool isMaturityReminderId(int id) => id >= 100000 && id < 150000;

  /// Milestone notification ID based on investment ID and milestone type
  static int milestone(String investmentId, double moic) =>
      (investmentId.hashCode.abs() % 20000) + 150000 + (moic * 100).toInt();

  /// Weekly check-in notification
  static const int weeklyCheckIn = 2000;

  /// FY summary notification
  static const int fySummary = 2001;

  /// Goal milestone notification ID based on goal ID and milestone percentage
  static int goalMilestone(String goalId, int milestonePercent) =>
      (goalId.hashCode.abs() % 10000) + 220000 + milestonePercent;

  /// Goal at-risk alert notification ID
  static int goalAtRisk(String goalId) =>
      (goalId.hashCode.abs() % 10000) + 240000;

  /// Goal stale alert notification ID
  static int goalStale(String goalId) =>
      (goalId.hashCode.abs() % 10000) + 250000;

  /// New user activation sequence IDs (Day 0, 1, 3, 7, 14)
  static const int activationDay0 = 3000; // Welcome, 1 hour after signup
  static const int activationDay1 = 3001; // First investment nudge
  static const int activationDay3 = 3002; // Import reminder
  static const int activationDay7 = 3003; // Tips & benefits
  static const int activationDay14 = 3004; // Social proof / last chance

  /// Income Guardian notification IDs
  /// Overdue payment notification ID (per investment)
  static int incomeGuardianOverdue(String investmentId) =>
      260000 + investmentId.hashCode.abs() % 10000;

  /// Upcoming payment reminder notification ID (per investment)
  static int incomeGuardianUpcoming(String investmentId) =>
      270000 + investmentId.hashCode.abs() % 10000;

  /// Payment received confirmation notification ID
  static int incomeGuardianReceived(String expectedCashFlowId) =>
      280000 + expectedCashFlowId.hashCode.abs() % 10000;
}

/// Hands out notification ID slots: the first time an (kind, key) pair is
/// seen it gets the next free number of its kind, saved in SharedPreferences.
/// Unlike `hashCode % range`, two investments never share an ID and an
/// investment keeps its ID across app updates and Dart SDK changes.
class NotificationIdSlots {
  static const String _prefsKey = 'notification_id_slots';

  static SharedPreferences? _prefs;
  static String? _cachedRaw;
  static Map<String, int> _cached = {};

  /// Called by [NotificationService] when the app starts.
  static void bind(SharedPreferences prefs) => _prefs = prefs;

  /// The slot (0 up to [capacity] - 1) of [key] within [kind].
  static int slot(String kind, String key, int capacity) {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('NotificationIdSlots used before NotificationService');
    }
    final raw = prefs.getString(_prefsKey);
    if (raw != _cachedRaw || raw == null) {
      _cached = raw == null
          ? {}
          : (jsonDecode(raw) as Map<String, dynamic>).cast<String, int>();
      _cachedRaw = raw;
    }
    final entry = '$kind:$key';
    final existing = _cached[entry];
    if (existing != null) return existing;

    final counter = '#$kind';
    final next = _cached[counter] ?? 0;
    if (next >= capacity) {
      throw StateError('Out of notification ID slots for $kind');
    }
    final updated = {..._cached, entry: next, counter: next + 1};
    final encoded = jsonEncode(updated);
    // SharedPreferences updates its in-memory copy at once, so the next call
    // sees this slot even before the write to disk finishes.
    prefs.setString(_prefsKey, encoded);
    _cached = updated;
    _cachedRaw = encoded;
    return next;
  }
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
  static const String weeklyCheckInEnabled = 'notifications_weekly_check_in';
  static const String fySummaryEnabled = 'notifications_fy_summary';
  static const String goalAtRiskEnabled = 'notifications_goal_at_risk';
  static const String goalStaleEnabled = 'notifications_goal_stale';
  static const String goalStaleDays = 'notifications_goal_stale_days';

  /// Uid of the account whose reminders are scheduled on this device.
  static const String remindersOwnerUid = 'notifications_reminders_owner_uid';

  /// Track which milestones have been shown (to avoid duplicates)
  static String milestoneShown(String investmentId, double moic) =>
      'milestone_shown_${investmentId}_${moic.toStringAsFixed(1)}';

  /// Track which goal milestones have been shown (to avoid duplicates)
  static String goalMilestoneShown(String goalId, int milestonePercent) =>
      'goal_milestone_shown_${goalId}_$milestonePercent';

  /// Due date (yyyy-MM-dd) of the latest income reminder for an investment
  /// that was shown or handed to the OS, so a reminder for a due day that
  /// has already been delivered is not shown again.
  static String incomeReminderDue(String investmentId) =>
      'income_reminder_due_$investmentId';

  /// The day the app itself last showed an investment's income reminder,
  /// so a retry after a failed reschedule does not show it twice.
  static String incomeReminderShown(String investmentId) =>
      'income_reminder_shown_$investmentId';

  /// Track when at-risk alert was last shown for a goal (show max once per week)
  static String goalAtRiskLastShown(String goalId) =>
      'goal_at_risk_last_shown_$goalId';

  /// Track when stale alert was last shown for a goal (show max once per month)
  static String goalStaleLastShown(String goalId) =>
      'goal_stale_last_shown_$goalId';

  // ============ New User Activation Sequence Keys ============

  /// Whether activation notifications are enabled (default: true for new users)
  static const String activationNotificationsEnabled =
      'notifications_activation_enabled';

  /// User signup date (ISO8601 string) - used to calculate notification timing
  static const String userSignupDate = 'user_signup_date';

  /// Track which activation notifications have been sent
  static const String activationDay0Sent = 'activation_day_0_sent';
  static const String activationDay1Sent = 'activation_day_1_sent';
  static const String activationDay3Sent = 'activation_day_3_sent';
  static const String activationDay7Sent = 'activation_day_7_sent';
  static const String activationDay14Sent = 'activation_day_14_sent';
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
