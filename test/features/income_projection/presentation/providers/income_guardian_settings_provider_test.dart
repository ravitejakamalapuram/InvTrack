/// Unit tests for IncomeGuardianSettingsProvider
///
/// Tests:
/// - Initial state loads from SharedPreferences
/// - Setting changes persist to SharedPreferences
/// - Settings trigger analytics events
/// - Default values when no saved settings exist
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

void main() {
  group('IncomeGuardianSettingsProvider', () {
    late ProviderContainer container;
    late SharedPreferences prefs;
    late FakeAnalyticsService fakeAnalytics;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeAnalytics = FakeAnalyticsService();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      fakeAnalytics.reset();
    });

    group('Initial State', () {
      test('loads default values when no saved settings', () {
        final settings = container.read(incomeGuardianSettingsProvider);

        expect(settings.enabled, true);
        expect(settings.upcomingDaysBefore, 1);
        expect(settings.overdueDaysAfter, 1);
        expect(settings.amountTolerancePercent, 20);
        expect(settings.dateWindowDays, 30);
        expect(settings.confidenceThresholdPercent, 70);
      });

      test('loads saved values from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({
          'income_guardian_enabled': false,
          'income_guardian_upcoming_days_before': 3,
          'income_guardian_overdue_days_after': 5,
          'income_guardian_amount_tolerance_percent': 15,
          'income_guardian_date_window_days': 60,
          'income_guardian_confidence_threshold_percent': 80,
        });
        final newPrefs = await SharedPreferences.getInstance();

        final newContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(newPrefs),
            analyticsServiceProvider.overrideWithValue(fakeAnalytics),
          ],
        );
        addTearDown(newContainer.dispose);

        final settings = newContainer.read(incomeGuardianSettingsProvider);

        expect(settings.enabled, false);
        expect(settings.upcomingDaysBefore, 3);
        expect(settings.overdueDaysAfter, 5);
        expect(settings.amountTolerancePercent, 15);
        expect(settings.dateWindowDays, 60);
        expect(settings.confidenceThresholdPercent, 80);
      });
    });

    group('setEnabled', () {
      test('updates state and persists to SharedPreferences', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setEnabled(false);

        final settings = container.read(incomeGuardianSettingsProvider);
        expect(settings.enabled, false);
        expect(prefs.getBool('income_guardian_enabled'), false);
      });

      test('logs income_guardian_enabled analytics when enabled', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        // First disable
        await notifier.setEnabled(false);
        fakeAnalytics.reset();

        // Then enable
        await notifier.setEnabled(true);

        final events = fakeAnalytics.loggedEvents
            .where((e) => e.name == AnalyticsEvents.incomeGuardianEnabled)
            .toList();
        expect(events, hasLength(1));
      });

      test('logs income_guardian_disabled analytics when disabled', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setEnabled(false);

        final events = fakeAnalytics.loggedEvents
            .where((e) => e.name == AnalyticsEvents.incomeGuardianDisabled)
            .toList();
        expect(events, hasLength(1));
      });
    });

    group('setUpcomingDaysBefore', () {
      test('updates state and persists to SharedPreferences', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setUpcomingDaysBefore(7);

        final settings = container.read(incomeGuardianSettingsProvider);
        expect(settings.upcomingDaysBefore, 7);
        expect(prefs.getInt('income_guardian_upcoming_days_before'), 7);
      });

      test('logs setting_changed analytics', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setUpcomingDaysBefore(7);

        final events = fakeAnalytics.loggedEvents
            .where(
          (e) => e.name == AnalyticsEvents.incomeGuardianSettingChanged,
        )
            .toList();
        expect(events, hasLength(1));
        expect(events.first.parameters?['setting_name'], 'upcoming_days_before');
        expect(events.first.parameters?['new_value'], '7');
      });
    });

    group('setOverdueDaysAfter', () {
      test('updates state and persists to SharedPreferences', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setOverdueDaysAfter(14);

        final settings = container.read(incomeGuardianSettingsProvider);
        expect(settings.overdueDaysAfter, 14);
        expect(prefs.getInt('income_guardian_overdue_days_after'), 14);
      });

      test('logs setting_changed analytics', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setOverdueDaysAfter(14);

        final events = fakeAnalytics.loggedEvents
            .where(
          (e) => e.name == AnalyticsEvents.incomeGuardianSettingChanged,
        )
            .toList();
        expect(events, hasLength(1));
        expect(events.first.parameters?['setting_name'], 'overdue_days_after');
        expect(events.first.parameters?['new_value'], '14');
      });
    });

    group('setAmountTolerancePercent', () {
      test('updates state and persists to SharedPreferences', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setAmountTolerancePercent(25);

        final settings = container.read(incomeGuardianSettingsProvider);
        expect(settings.amountTolerancePercent, 25);
        expect(
          prefs.getInt('income_guardian_amount_tolerance_percent'),
          25,
        );
      });

      test('logs setting_changed analytics', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setAmountTolerancePercent(25);

        final events = fakeAnalytics.loggedEvents
            .where(
          (e) => e.name == AnalyticsEvents.incomeGuardianSettingChanged,
        )
            .toList();
        expect(events, hasLength(1));
        expect(
          events.first.parameters?['setting_name'],
          'amount_tolerance_percent',
        );
        expect(events.first.parameters?['new_value'], '25');
      });
    });

    group('setDateWindowDays', () {
      test('updates state and persists to SharedPreferences', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setDateWindowDays(45);

        final settings = container.read(incomeGuardianSettingsProvider);
        expect(settings.dateWindowDays, 45);
        expect(prefs.getInt('income_guardian_date_window_days'), 45);
      });

      test('logs setting_changed analytics', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setDateWindowDays(45);

        final events = fakeAnalytics.loggedEvents
            .where(
          (e) => e.name == AnalyticsEvents.incomeGuardianSettingChanged,
        )
            .toList();
        expect(events, hasLength(1));
        expect(events.first.parameters?['setting_name'], 'date_window_days');
        expect(events.first.parameters?['new_value'], '45');
      });
    });

    group('setConfidenceThresholdPercent', () {
      test('updates state and persists to SharedPreferences', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setConfidenceThresholdPercent(85);

        final settings = container.read(incomeGuardianSettingsProvider);
        expect(settings.confidenceThresholdPercent, 85);
        expect(
          prefs.getInt('income_guardian_confidence_threshold_percent'),
          85,
        );
      });

      test('logs setting_changed analytics', () async {
        final notifier =
            container.read(incomeGuardianSettingsProvider.notifier);

        await notifier.setConfidenceThresholdPercent(85);

        final events = fakeAnalytics.loggedEvents
            .where(
          (e) => e.name == AnalyticsEvents.incomeGuardianSettingChanged,
        )
            .toList();
        expect(events, hasLength(1));
        expect(
          events.first.parameters?['setting_name'],
          'confidence_threshold_percent',
        );
        expect(events.first.parameters?['new_value'], '85');
      });
    });
  });
}

