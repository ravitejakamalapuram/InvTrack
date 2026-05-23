/// Income Guardian settings provider for persistence and state management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Income Guardian settings state
class IncomeGuardianSettings {
  final bool enabled;
  final int upcomingDaysBefore; // Days before expected date to notify
  final int overdueDaysAfter; // Days after expected date to notify overdue
  final int amountTolerancePercent; // ±% for amount matching
  final int dateWindowDays; // ± days for date matching
  final int confidenceThresholdPercent; // Minimum match score %

  const IncomeGuardianSettings({
    this.enabled = true,
    this.upcomingDaysBefore = 1,
    this.overdueDaysAfter = 1,
    this.amountTolerancePercent = 20,
    this.dateWindowDays = 30,
    this.confidenceThresholdPercent = 70,
  });

  IncomeGuardianSettings copyWith({
    bool? enabled,
    int? upcomingDaysBefore,
    int? overdueDaysAfter,
    int? amountTolerancePercent,
    int? dateWindowDays,
    int? confidenceThresholdPercent,
  }) {
    return IncomeGuardianSettings(
      enabled: enabled ?? this.enabled,
      upcomingDaysBefore: upcomingDaysBefore ?? this.upcomingDaysBefore,
      overdueDaysAfter: overdueDaysAfter ?? this.overdueDaysAfter,
      amountTolerancePercent: amountTolerancePercent ?? this.amountTolerancePercent,
      dateWindowDays: dateWindowDays ?? this.dateWindowDays,
      confidenceThresholdPercent: confidenceThresholdPercent ?? this.confidenceThresholdPercent,
    );
  }
}

/// Income Guardian settings provider
final incomeGuardianSettingsProvider = NotifierProvider<IncomeGuardianSettingsNotifier, IncomeGuardianSettings>(
  IncomeGuardianSettingsNotifier.new,
);

/// Income Guardian settings notifier
class IncomeGuardianSettingsNotifier extends Notifier<IncomeGuardianSettings> {
  static const String _keyEnabled = 'income_guardian_enabled';
  static const String _keyUpcomingDaysBefore = 'income_guardian_upcoming_days_before';
  static const String _keyOverdueDaysAfter = 'income_guardian_overdue_days_after';
  static const String _keyAmountTolerancePercent = 'income_guardian_amount_tolerance_percent';
  static const String _keyDateWindowDays = 'income_guardian_date_window_days';
  static const String _keyConfidenceThresholdPercent = 'income_guardian_confidence_threshold_percent';

  @override
  IncomeGuardianSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _loadSettings(prefs);
  }

  IncomeGuardianSettings _loadSettings(SharedPreferences prefs) {
    return IncomeGuardianSettings(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      upcomingDaysBefore: prefs.getInt(_keyUpcomingDaysBefore) ?? 1,
      overdueDaysAfter: prefs.getInt(_keyOverdueDaysAfter) ?? 1,
      amountTolerancePercent: prefs.getInt(_keyAmountTolerancePercent) ?? 20,
      dateWindowDays: prefs.getInt(_keyDateWindowDays) ?? 30,
      confidenceThresholdPercent: prefs.getInt(_keyConfidenceThresholdPercent) ?? 70,
    );
  }

  Future<void> setEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_keyEnabled, value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setUpcomingDaysBefore(int value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_keyUpcomingDaysBefore, value);
    state = state.copyWith(upcomingDaysBefore: value);
  }

  Future<void> setOverdueDaysAfter(int value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_keyOverdueDaysAfter, value);
    state = state.copyWith(overdueDaysAfter: value);
  }

  Future<void> setAmountTolerancePercent(int value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_keyAmountTolerancePercent, value);
    state = state.copyWith(amountTolerancePercent: value);
  }

  Future<void> setDateWindowDays(int value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_keyDateWindowDays, value);
    state = state.copyWith(dateWindowDays: value);
  }

  Future<void> setConfidenceThresholdPercent(int value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_keyConfidenceThresholdPercent, value);
    state = state.copyWith(confidenceThresholdPercent: value);
  }
}
