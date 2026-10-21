// A29 part 4 (#780): every notification type has its own on/off preference
// per signed-in account, and privacy mode keeps amounts out of the text.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/notifications/notification_settings_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../mocks/mock_notification_service.dart';

void main() {
  late FakeFlutterLocalNotificationsPlugin plugin;
  late NotificationService service;
  late SharedPreferences prefs;

  Future<void> build([Map<String, Object> stored = const {}]) async {
    tz_data.initializeTimeZones();
    plugin = FakeFlutterLocalNotificationsPlugin();
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    service = NotificationService(
      plugin,
      prefs,
      clock: () => DateTime(2026, 2, 1, 12),
    );
  }

  setUp(build);

  group('per-account preferences', () {
    test('every type is on for an account that never chose', () {
      service.preferencesUid = 'a';

      expect(service.weeklySummaryEnabled, isTrue);
      expect(service.incomeRemindersEnabled, isTrue);
      expect(service.maturityRemindersEnabled, isTrue);
      expect(service.monthlySummaryEnabled, isTrue);
      expect(service.milestonesEnabled, isTrue);
      expect(service.goalMilestonesEnabled, isTrue);
      expect(service.taxRemindersEnabled, isTrue);
      expect(service.weeklyCheckInEnabled, isTrue);
      expect(service.fySummaryEnabled, isTrue);
      expect(service.goalAtRiskEnabled, isTrue);
      expect(service.goalStaleEnabled, isTrue);
    });

    test('a choice made by one account does not reach another', () async {
      service.preferencesUid = 'a';
      await service.setIncomeRemindersEnabled(false);
      await service.setGoalAtRiskEnabled(false);

      service.preferencesUid = 'b';
      expect(service.incomeRemindersEnabled, isTrue);
      expect(service.goalAtRiskEnabled, isTrue);

      service.preferencesUid = 'a';
      expect(service.incomeRemindersEnabled, isFalse);
      expect(service.goalAtRiskEnabled, isFalse);
    });

    test('a choice made before per-account storage still applies', () async {
      await build({NotificationPrefsKeys.weeklySummaryEnabled: false});

      service.preferencesUid = 'a';
      expect(service.weeklySummaryEnabled, isFalse);

      await service.setWeeklySummaryEnabled(true);
      expect(service.weeklySummaryEnabled, isTrue);
    });

    test('a reminder is not scheduled for an account that turned it off '
        'even if another account has it on', () async {
      service.preferencesUid = 'a';
      await service.setMaturityRemindersEnabled(false);
      service.preferencesUid = 'b';

      await service.scheduleMaturityReminders(
        investmentId: 'fd',
        investmentName: 'SBI FD',
        maturityDate: DateTime(2026, 6, 10),
      );
      expect(plugin.scheduledNotifications, isNotEmpty);

      plugin.scheduledNotifications.clear();
      service.preferencesUid = 'a';
      await service.scheduleMaturityReminders(
        investmentId: 'fd',
        investmentName: 'SBI FD',
        maturityDate: DateTime(2026, 6, 10),
      );
      expect(plugin.scheduledNotifications, isEmpty);
    });

    test(
      'goal at-risk and stale alerts have their own setting types',
      () async {
        final container = ProviderContainer(
          overrides: [notificationServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);
        service.preferencesUid = 'a';

        await container
            .read(notificationSettingsProvider.notifier)
            .setSetting(NotificationSettingType.goalAtRisk, false);
        await container
            .read(notificationSettingsProvider.notifier)
            .setSetting(NotificationSettingType.goalStale, false);

        final state = container.read(notificationSettingsProvider);
        expect(state.goalAtRiskEnabled, isFalse);
        expect(state.goalStaleEnabled, isFalse);
        expect(service.goalAtRiskEnabled, isFalse);
        expect(service.goalStaleEnabled, isFalse);
        expect(state.goalMilestonesEnabled, isTrue);
      },
    );
  });

  group('privacy mode keeps amounts out of notification text', () {
    String format(double v) => formatCurrencyForCode(v, 'INR');

    test('goal milestone', () async {
      await service.checkAndShowGoalMilestone(
        goalId: 'g',
        goalName: 'House',
        progressPercent: 50,
        currentValue: 500000,
        targetValue: 1000000,
      );
      final shown = plugin.shownNotifications.single.body!;
      expect(shown, contains(format(500000)));

      plugin.shownNotifications.clear();
      service.privacyModeActive = true;
      await service.checkAndShowGoalMilestone(
        goalId: 'g2',
        goalName: 'House',
        progressPercent: 100,
        currentValue: 1000000,
        targetValue: 1000000,
      );
      final hidden = plugin.shownNotifications.single.body!;
      expect(hidden, contains('House'));
      expect(hidden, isNot(contains(format(1000000))));
      expect(hidden, isNot(matches(RegExp(r'\d{2,}[,\d]*\d'))));
    });

    test('investment milestone', () async {
      service.privacyModeActive = true;
      await service.checkAndShowMilestone(
        investmentId: 'i',
        investmentName: 'SBI FD',
        moic: 2.1,
        gain: 123456,
      );
      final body = plugin.shownNotifications.single.body!;
      expect(body, contains('SBI FD'));
      expect(body, isNot(contains('profit')));
      expect(body, isNot(contains('1,23,456')));
    });

    test('maturity reminder shows the name and no value or return', () async {
      service.privacyModeActive = true;
      await service.scheduleMaturityReminders(
        investmentId: 'fd',
        investmentName: 'SBI FD',
        maturityDate: DateTime(2026, 6, 10),
        investedAmount: 100000,
        currentValue: 112345,
      );
      expect(plugin.scheduledNotifications, hasLength(2));
      for (final n in plugin.scheduledNotifications) {
        expect(n.body, contains('SBI FD'));
        expect(n.body, isNot(contains('Value')));
        expect(n.body, isNot(contains('return')));
        expect(n.body, isNot(contains('1,12,345')));
      }
    });

    test(
      'maturity reminder still shows the value when privacy is off',
      () async {
        await service.scheduleMaturityReminders(
          investmentId: 'fd',
          investmentName: 'SBI FD',
          maturityDate: DateTime(2026, 6, 10),
          investedAmount: 100000,
          currentValue: 112345,
        );
        expect(plugin.scheduledNotifications.first.body, contains('Value'));
      },
    );

    test('FY summary', () async {
      service.privacyModeActive = true;
      await service.showFYSummary(
        previousFY: 2025,
        totalIncome: 654321,
        totalTDS: 65432,
        topPerformer: 'SBI FD',
      );
      final body = plugin.shownNotifications.single.body!;
      expect(body, isNot(contains('Income:')));
      expect(body, isNot(contains('TDS')));
      expect(body, isNot(contains('6,54,321')));
      expect(body, isNot(contains('654321')));
    });
  });
}
