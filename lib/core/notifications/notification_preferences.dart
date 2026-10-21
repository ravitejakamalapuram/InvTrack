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

  /// The signed-in account whose on/off choices apply. Each account keeps its
  /// own, so another account on the same device is not changed. Null while
  /// nobody is signed in.
  String? preferencesUid;

  /// Whether privacy mode is on. Notification text then leaves out amounts.
  bool privacyModeActive = false;

  /// An account without a choice of its own uses the choice this device had
  /// before choices were kept per account, and otherwise is on.
  bool _flag(String key) =>
      prefs.getBool(_accountKey(key)) ?? prefs.getBool(key) ?? true;

  Future<void> _setFlag(String key, bool enabled) =>
      prefs.setBool(_accountKey(key), enabled);

  String _accountKey(String key) =>
      preferencesUid == null ? key : '${key}_$preferencesUid';

  // ============ Enabled/Disabled Preferences ============

  bool get weeklySummaryEnabled =>
      _flag(NotificationPrefsKeys.weeklySummaryEnabled);

  Future<void> setWeeklySummaryEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.weeklySummaryEnabled, enabled);
  }

  bool get incomeRemindersEnabled =>
      _flag(NotificationPrefsKeys.incomeRemindersEnabled);

  Future<void> setIncomeRemindersEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.incomeRemindersEnabled, enabled);
  }

  bool get maturityRemindersEnabled =>
      _flag(NotificationPrefsKeys.maturityRemindersEnabled);

  Future<void> setMaturityRemindersEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.maturityRemindersEnabled, enabled);
  }

  bool get monthlySummaryEnabled =>
      _flag(NotificationPrefsKeys.monthlySummaryEnabled);

  Future<void> setMonthlySummaryEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.monthlySummaryEnabled, enabled);
  }

  bool get milestonesEnabled => _flag(NotificationPrefsKeys.milestonesEnabled);

  Future<void> setMilestonesEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.milestonesEnabled, enabled);
  }

  /// Goal progress milestone notifications enabled
  bool get goalMilestonesEnabled =>
      _flag(NotificationPrefsKeys.goalMilestonesEnabled);

  Future<void> setGoalMilestonesEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.goalMilestonesEnabled, enabled);
  }

  bool get taxRemindersEnabled =>
      _flag(NotificationPrefsKeys.taxRemindersEnabled);

  Future<void> setTaxRemindersEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.taxRemindersEnabled, enabled);
  }

  /// Weekly check-in (Sunday prompt) enabled
  bool get weeklyCheckInEnabled =>
      _flag(NotificationPrefsKeys.weeklyCheckInEnabled);

  Future<void> setWeeklyCheckInEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.weeklyCheckInEnabled, enabled);
  }

  /// FY summary notification enabled
  bool get fySummaryEnabled => _flag(NotificationPrefsKeys.fySummaryEnabled);

  Future<void> setFySummaryEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.fySummaryEnabled, enabled);
  }

  /// Goal at-risk alerts enabled (when goal is behind schedule)
  bool get goalAtRiskEnabled => _flag(NotificationPrefsKeys.goalAtRiskEnabled);

  Future<void> setGoalAtRiskEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.goalAtRiskEnabled, enabled);
  }

  /// Goal stale alerts enabled (when no activity for X days)
  bool get goalStaleEnabled => _flag(NotificationPrefsKeys.goalStaleEnabled);

  Future<void> setGoalStaleEnabled(bool enabled) async {
    await _setFlag(NotificationPrefsKeys.goalStaleEnabled, enabled);
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
