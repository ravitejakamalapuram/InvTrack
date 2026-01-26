/// Notification preferences management.
///
/// This mixin provides preference getters/setters for all notification types.
library;

import 'package:inv_tracker/core/notifications/notification_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mixin that provides notification preference management.
///
/// Classes using this mixin must provide a [SharedPreferences] instance
/// via the [prefs] getter.
mixin NotificationPreferencesMixin {
  /// The SharedPreferences instance for storing preferences.
  SharedPreferences get prefs;

  // ============ Enabled/Disabled Preferences ============

  bool get weeklySummaryEnabled =>
      prefs.getBool(NotificationPrefsKeys.weeklySummaryEnabled) ?? true;

  Future<void> setWeeklySummaryEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.weeklySummaryEnabled, enabled);
  }

  bool get incomeRemindersEnabled =>
      prefs.getBool(NotificationPrefsKeys.incomeRemindersEnabled) ?? true;

  Future<void> setIncomeRemindersEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.incomeRemindersEnabled, enabled);
  }

  bool get maturityRemindersEnabled =>
      prefs.getBool(NotificationPrefsKeys.maturityRemindersEnabled) ?? true;

  Future<void> setMaturityRemindersEnabled(bool enabled) async {
    await prefs.setBool(
      NotificationPrefsKeys.maturityRemindersEnabled,
      enabled,
    );
  }

  bool get monthlySummaryEnabled =>
      prefs.getBool(NotificationPrefsKeys.monthlySummaryEnabled) ?? true;

  Future<void> setMonthlySummaryEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.monthlySummaryEnabled, enabled);
  }

  bool get milestonesEnabled =>
      prefs.getBool(NotificationPrefsKeys.milestonesEnabled) ?? true;

  Future<void> setMilestonesEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.milestonesEnabled, enabled);
  }

  /// Goal progress milestone notifications enabled
  bool get goalMilestonesEnabled =>
      prefs.getBool(NotificationPrefsKeys.goalMilestonesEnabled) ?? true;

  Future<void> setGoalMilestonesEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.goalMilestonesEnabled, enabled);
  }

  bool get taxRemindersEnabled =>
      prefs.getBool(NotificationPrefsKeys.taxRemindersEnabled) ?? true;

  Future<void> setTaxRemindersEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.taxRemindersEnabled, enabled);
  }

  bool get riskAlertsEnabled =>
      prefs.getBool(NotificationPrefsKeys.riskAlertsEnabled) ?? true;

  Future<void> setRiskAlertsEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.riskAlertsEnabled, enabled);
  }

  /// Weekly check-in (Sunday prompt) enabled
  bool get weeklyCheckInEnabled =>
      prefs.getBool(NotificationPrefsKeys.weeklyCheckInEnabled) ?? true;

  Future<void> setWeeklyCheckInEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.weeklyCheckInEnabled, enabled);
  }

  /// Idle investment alerts enabled
  bool get idleAlertsEnabled =>
      prefs.getBool(NotificationPrefsKeys.idleAlertsEnabled) ?? true;

  Future<void> setIdleAlertsEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.idleAlertsEnabled, enabled);
  }

  /// Number of days before an investment is considered "idle" (default: 90)
  int get idleAlertDays =>
      prefs.getInt(NotificationPrefsKeys.idleAlertDays) ?? 90;

  Future<void> setIdleAlertDays(int days) async {
    await prefs.setInt(NotificationPrefsKeys.idleAlertDays, days);
  }

  /// FY summary notification enabled
  bool get fySummaryEnabled =>
      prefs.getBool(NotificationPrefsKeys.fySummaryEnabled) ?? true;

  Future<void> setFySummaryEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.fySummaryEnabled, enabled);
  }

  /// Goal at-risk alerts enabled (when goal is behind schedule)
  bool get goalAtRiskEnabled =>
      prefs.getBool(NotificationPrefsKeys.goalAtRiskEnabled) ?? true;

  Future<void> setGoalAtRiskEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.goalAtRiskEnabled, enabled);
  }

  /// Goal stale alerts enabled (when no activity for X days)
  bool get goalStaleEnabled =>
      prefs.getBool(NotificationPrefsKeys.goalStaleEnabled) ?? true;

  Future<void> setGoalStaleEnabled(bool enabled) async {
    await prefs.setBool(NotificationPrefsKeys.goalStaleEnabled, enabled);
  }

  /// Number of days before a goal is considered "stale" (default: 60)
  int get goalStaleDays =>
      prefs.getInt(NotificationPrefsKeys.goalStaleDays) ?? 60;

  Future<void> setGoalStaleDays(int days) async {
    await prefs.setInt(NotificationPrefsKeys.goalStaleDays, days);
  }

  // ============ Milestone Tracking ============

  /// Check if a milestone has already been shown for an investment
  bool isMilestoneShown(String investmentId, double moic) =>
      prefs.getBool(NotificationPrefsKeys.milestoneShown(investmentId, moic)) ??
      false;

  /// Mark a milestone as shown
  Future<void> markMilestoneShown(String investmentId, double moic) async {
    await prefs.setBool(
      NotificationPrefsKeys.milestoneShown(investmentId, moic),
      true,
    );
  }

  /// Check if a goal milestone has already been shown
  bool isGoalMilestoneShown(String goalId, int milestonePercent) =>
      prefs.getBool(
        NotificationPrefsKeys.goalMilestoneShown(goalId, milestonePercent),
      ) ??
      false;

  /// Mark a goal milestone as shown
  Future<void> markGoalMilestoneShown(
    String goalId,
    int milestonePercent,
  ) async {
    await prefs.setBool(
      NotificationPrefsKeys.goalMilestoneShown(goalId, milestonePercent),
      true,
    );
  }

  // ============ Alert Tracking ============

  /// Get last time idle alert was shown for an investment (as ISO8601 string)
  DateTime? getIdleAlertLastShown(String investmentId) {
    final str = prefs.getString(
      NotificationPrefsKeys.idleAlertLastShown(investmentId),
    );
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Mark idle alert as shown for an investment
  Future<void> markIdleAlertShown(String investmentId) async {
    await prefs.setString(
      NotificationPrefsKeys.idleAlertLastShown(investmentId),
      DateTime.now().toIso8601String(),
    );
  }

  /// Get last time goal at-risk alert was shown
  DateTime? getGoalAtRiskLastShown(String goalId) {
    final str = prefs.getString(
      NotificationPrefsKeys.goalAtRiskLastShown(goalId),
    );
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Mark goal at-risk alert as shown
  Future<void> markGoalAtRiskShown(String goalId) async {
    await prefs.setString(
      NotificationPrefsKeys.goalAtRiskLastShown(goalId),
      DateTime.now().toIso8601String(),
    );
  }

  /// Get last time goal stale alert was shown
  DateTime? getGoalStaleLastShown(String goalId) {
    final str = prefs.getString(
      NotificationPrefsKeys.goalStaleLastShown(goalId),
    );
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Mark goal stale alert as shown
  Future<void> markGoalStaleShown(String goalId) async {
    await prefs.setString(
      NotificationPrefsKeys.goalStaleLastShown(goalId),
      DateTime.now().toIso8601String(),
    );
  }
}
