/// Provider for notification settings state management.
///
/// This provides a reactive state for notification settings that properly
/// rebuilds the UI when settings change, unlike directly reading from
/// SharedPreferences.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';

/// Enum representing all notification setting types.
///
/// This provides type-safe access to notification settings and prevents
/// string-based errors.
enum NotificationSettingType {
  weeklySummary,
  incomeReminders,
  maturityReminders,
  monthlySummary,
  milestones,
  goalMilestones,
  taxReminders,
  weeklyCheckIn,
  fySummary,
  goalAtRisk,
  goalStale,
}

/// State class holding all notification settings.
class NotificationSettingsState {
  final bool weeklySummaryEnabled;
  final bool incomeRemindersEnabled;
  final bool maturityRemindersEnabled;
  final bool monthlySummaryEnabled;
  final bool milestonesEnabled;
  final bool goalMilestonesEnabled;
  final bool taxRemindersEnabled;
  final bool weeklyCheckInEnabled;
  final bool fySummaryEnabled;
  final bool goalAtRiskEnabled;
  final bool goalStaleEnabled;

  const NotificationSettingsState({
    this.weeklySummaryEnabled = true,
    this.incomeRemindersEnabled = true,
    this.maturityRemindersEnabled = true,
    this.monthlySummaryEnabled = true,
    this.milestonesEnabled = true,
    this.goalMilestonesEnabled = true,
    this.taxRemindersEnabled = true,
    this.weeklyCheckInEnabled = true,
    this.fySummaryEnabled = true,
    this.goalAtRiskEnabled = true,
    this.goalStaleEnabled = true,
  });

  /// Get setting value by type
  bool getSetting(NotificationSettingType type) {
    switch (type) {
      case NotificationSettingType.weeklySummary:
        return weeklySummaryEnabled;
      case NotificationSettingType.incomeReminders:
        return incomeRemindersEnabled;
      case NotificationSettingType.maturityReminders:
        return maturityRemindersEnabled;
      case NotificationSettingType.monthlySummary:
        return monthlySummaryEnabled;
      case NotificationSettingType.milestones:
        return milestonesEnabled;
      case NotificationSettingType.goalMilestones:
        return goalMilestonesEnabled;
      case NotificationSettingType.taxReminders:
        return taxRemindersEnabled;
      case NotificationSettingType.weeklyCheckIn:
        return weeklyCheckInEnabled;
      case NotificationSettingType.fySummary:
        return fySummaryEnabled;
      case NotificationSettingType.goalAtRisk:
        return goalAtRiskEnabled;
      case NotificationSettingType.goalStale:
        return goalStaleEnabled;
    }
  }

  NotificationSettingsState copyWith({
    bool? weeklySummaryEnabled,
    bool? incomeRemindersEnabled,
    bool? maturityRemindersEnabled,
    bool? monthlySummaryEnabled,
    bool? milestonesEnabled,
    bool? goalMilestonesEnabled,
    bool? taxRemindersEnabled,
    bool? weeklyCheckInEnabled,
    bool? fySummaryEnabled,
    bool? goalAtRiskEnabled,
    bool? goalStaleEnabled,
  }) {
    return NotificationSettingsState(
      weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
      incomeRemindersEnabled:
          incomeRemindersEnabled ?? this.incomeRemindersEnabled,
      maturityRemindersEnabled:
          maturityRemindersEnabled ?? this.maturityRemindersEnabled,
      monthlySummaryEnabled:
          monthlySummaryEnabled ?? this.monthlySummaryEnabled,
      milestonesEnabled: milestonesEnabled ?? this.milestonesEnabled,
      goalMilestonesEnabled:
          goalMilestonesEnabled ?? this.goalMilestonesEnabled,
      taxRemindersEnabled: taxRemindersEnabled ?? this.taxRemindersEnabled,
      weeklyCheckInEnabled: weeklyCheckInEnabled ?? this.weeklyCheckInEnabled,
      fySummaryEnabled: fySummaryEnabled ?? this.fySummaryEnabled,
      goalAtRiskEnabled: goalAtRiskEnabled ?? this.goalAtRiskEnabled,
      goalStaleEnabled: goalStaleEnabled ?? this.goalStaleEnabled,
    );
  }
}

/// Provider for notification settings state.
///
/// This watches the NotificationService and creates a reactive state
/// that triggers UI rebuilds when settings change.
final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
      NotificationSettingsNotifier.new,
    );

/// Notifier that manages notification settings state.
///
/// Syncs with NotificationService for persistence while providing
/// reactive state updates for the UI.
class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    final service = ref.watch(notificationServiceProvider);
    return NotificationSettingsState(
      weeklySummaryEnabled: service.weeklySummaryEnabled,
      incomeRemindersEnabled: service.incomeRemindersEnabled,
      maturityRemindersEnabled: service.maturityRemindersEnabled,
      monthlySummaryEnabled: service.monthlySummaryEnabled,
      milestonesEnabled: service.milestonesEnabled,
      goalMilestonesEnabled: service.goalMilestonesEnabled,
      taxRemindersEnabled: service.taxRemindersEnabled,
      weeklyCheckInEnabled: service.weeklyCheckInEnabled,
      fySummaryEnabled: service.fySummaryEnabled,
      goalAtRiskEnabled: service.goalAtRiskEnabled,
      goalStaleEnabled: service.goalStaleEnabled,
    );
  }

  /// Update a notification setting.
  ///
  /// This updates both the persistent storage (via NotificationService)
  /// and the reactive state (for UI rebuilds).
  Future<void> setSetting(NotificationSettingType type, bool enabled) async {
    final service = ref.read(notificationServiceProvider);

    // Request permissions when enabling any notification type
    if (enabled) {
      await service.requestPermissions();
    }

    // Update the service (persists to SharedPreferences)
    switch (type) {
      case NotificationSettingType.weeklySummary:
        await service.setWeeklySummaryEnabled(enabled);
        state = state.copyWith(weeklySummaryEnabled: enabled);
      case NotificationSettingType.incomeReminders:
        await service.setIncomeRemindersEnabled(enabled);
        state = state.copyWith(incomeRemindersEnabled: enabled);
      case NotificationSettingType.maturityReminders:
        await service.setMaturityRemindersEnabled(enabled);
        state = state.copyWith(maturityRemindersEnabled: enabled);
      case NotificationSettingType.monthlySummary:
        await service.setMonthlySummaryEnabled(enabled);
        state = state.copyWith(monthlySummaryEnabled: enabled);
      case NotificationSettingType.milestones:
        await service.setMilestonesEnabled(enabled);
        state = state.copyWith(milestonesEnabled: enabled);
      case NotificationSettingType.goalMilestones:
        await service.setGoalMilestonesEnabled(enabled);
        state = state.copyWith(goalMilestonesEnabled: enabled);
      case NotificationSettingType.taxReminders:
        await service.setTaxRemindersEnabled(enabled);
        state = state.copyWith(taxRemindersEnabled: enabled);
      case NotificationSettingType.weeklyCheckIn:
        await service.setWeeklyCheckInEnabled(enabled);
        state = state.copyWith(weeklyCheckInEnabled: enabled);
      case NotificationSettingType.fySummary:
        await service.setFySummaryEnabled(enabled);
        state = state.copyWith(fySummaryEnabled: enabled);
      case NotificationSettingType.goalAtRisk:
        await service.setGoalAtRiskEnabled(enabled);
        state = state.copyWith(goalAtRiskEnabled: enabled);
      case NotificationSettingType.goalStale:
        await service.setGoalStaleEnabled(enabled);
        state = state.copyWith(goalStaleEnabled: enabled);
    }
  }
}
