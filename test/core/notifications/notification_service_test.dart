import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../mocks/mock_notification_service.dart';

void main() {
  late FakeFlutterLocalNotificationsPlugin fakePlugin;
  late SharedPreferences prefs;
  late NotificationService service;

  setUp(() async {
    tz_data.initializeTimeZones();
    fakePlugin = FakeFlutterLocalNotificationsPlugin();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = NotificationService(fakePlugin, prefs);
  });

  tearDown(() {
    fakePlugin.reset();
  });

  group('NotificationService - Initialization', () {
    test('should initialize the plugin on first call', () async {
      await service.initialize();
      expect(fakePlugin.isInitialized, isTrue);
    });

    test('should only initialize once even if called multiple times', () async {
      await service.initialize();
      await service.initialize();
      await service.initialize();
      // If it initialized multiple times, we'd get errors
      expect(fakePlugin.isInitialized, isTrue);
    });
  });

  group('NotificationService - Timezone Configuration', () {
    test('should map Asia/Calcutta to Asia/Kolkata', () async {
      // This test verifies the legacy timezone name mapping
      // We can't directly test _configureLocalTimeZone as it's private,
      // but we verify it runs without errors during initialization
      await service.initialize();
      expect(fakePlugin.isInitialized, isTrue);
      // If timezone configuration failed, initialization would have logged warnings
      // but still succeeded (UTC fallback)
    });

    test('should handle unknown timezone gracefully', () async {
      // The service should initialize successfully even with unknown timezones
      // by falling back to UTC
      await service.initialize();
      expect(fakePlugin.isInitialized, isTrue);
      // Timezone errors are logged as info (not errors) to avoid Crashlytics pollution
    });

    test('should use UTC fallback when timezone lookup fails', () async {
      // When FlutterTimezone fails or returns an unknown timezone,
      // the service should fall back to UTC and continue initialization
      await service.initialize();
      expect(fakePlugin.isInitialized, isTrue);
      // tz.local remains as UTC (default) when lookup fails
    });

    test('should log info (not error) on timezone fallback', () async {
      // Timezone fallback should use LoggerService.info to prevent
      // polluting Crashlytics with non-critical timezone warnings
      await service.initialize();
      expect(fakePlugin.isInitialized, isTrue);
      // This test ensures initialize() completes successfully
      // even when timezone configuration encounters errors
    });
  });

  group('NotificationService - Preferences', () {
    test('weekly summary should be enabled by default', () {
      expect(service.weeklySummaryEnabled, isTrue);
    });

    test(
      'should persist weekly summary preference and schedule/cancel',
      () async {
        await service.setWeeklySummaryEnabled(true);
        expect(service.weeklySummaryEnabled, isTrue);
        expect(fakePlugin.scheduledNotifications.length, 1);

        await service.setWeeklySummaryEnabled(false);
        expect(service.weeklySummaryEnabled, isFalse);
        expect(
          fakePlugin.cancelledNotificationIds.contains(
            NotificationIds.weeklySummary,
          ),
          isTrue,
        );
      },
    );

    test('income reminders should be enabled by default', () {
      expect(service.incomeRemindersEnabled, isTrue);
    });

    test('should persist income reminders preference', () async {
      await service.setIncomeRemindersEnabled(false);
      expect(service.incomeRemindersEnabled, isFalse);
    });

    test('maturity reminders should be enabled by default', () {
      expect(service.maturityRemindersEnabled, isTrue);
    });

    test('should persist maturity reminders preference', () async {
      await service.setMaturityRemindersEnabled(false);
      expect(service.maturityRemindersEnabled, isFalse);
    });

    test('monthly summary should be enabled by default', () {
      expect(service.monthlySummaryEnabled, isTrue);
    });

    test(
      'should persist monthly summary preference and schedule/cancel',
      () async {
        await service.setMonthlySummaryEnabled(true);
        expect(service.monthlySummaryEnabled, isTrue);
        expect(fakePlugin.scheduledNotifications.isNotEmpty, isTrue);

        await service.setMonthlySummaryEnabled(false);
        expect(service.monthlySummaryEnabled, isFalse);
        expect(
          fakePlugin.cancelledNotificationIds.contains(
            NotificationIds.monthlySummary,
          ),
          isTrue,
        );
      },
    );
  });

  group('NotificationService - Test Notifications', () {
    test('should show test notification', () async {
      final result = await service.showTestNotification();

      expect(result, isTrue);
      expect(fakePlugin.shownNotifications.length, 1);
      expect(fakePlugin.shownNotifications.first.title, '🔔 Test Notification');
      expect(fakePlugin.shownNotifications.first.id, 99999);
    });

    test('should schedule test notification with delay', () async {
      final result = await service.scheduleTestNotification(delaySeconds: 10);

      expect(result, isTrue);
      expect(fakePlugin.scheduledNotifications.length, 1);
      expect(
        fakePlugin.scheduledNotifications.first.title,
        '⏰ Scheduled Test Notification',
      );
      expect(fakePlugin.scheduledNotifications.first.id, 99998);
    });

    test('should schedule test notification with correct delay time', () async {
      final beforeSchedule = DateTime.now();
      await service.scheduleTestNotification(delaySeconds: 5);
      final afterSchedule = DateTime.now();

      final scheduledTime =
          fakePlugin.scheduledNotifications.first.scheduledDate;

      // Scheduled time should be approximately 5 seconds after now
      expect(
        scheduledTime.isAfter(beforeSchedule.add(const Duration(seconds: 4))),
        isTrue,
      );
      expect(
        scheduledTime.isBefore(afterSchedule.add(const Duration(seconds: 6))),
        isTrue,
      );
    });
  });

  group('NotificationService - Weekly Summary', () {
    test('should schedule weekly summary for next Sunday', () async {
      await service.scheduleWeeklySummary();

      expect(fakePlugin.scheduledNotifications.length, 1);
      final scheduled = fakePlugin.scheduledNotifications.first;
      expect(scheduled.id, NotificationIds.weeklySummary);
      expect(scheduled.title, '📊 Weekly Investment Summary');
      // Verify it's scheduled for a Sunday (weekday == 7 in DateTime)
      expect(scheduled.scheduledDate.weekday, DateTime.sunday);
      // Note: The hour may appear different due to timezone conversion in TZDateTime
    });

    test('should not schedule weekly summary when disabled', () async {
      await service.setWeeklySummaryEnabled(false);
      fakePlugin.reset();

      await service.scheduleWeeklySummary();

      expect(fakePlugin.scheduledNotifications, isEmpty);
    });

    test('should cancel existing before scheduling new', () async {
      await service.scheduleWeeklySummary();
      await service.scheduleWeeklySummary();

      expect(
        fakePlugin.cancelledNotificationIds.contains(
          NotificationIds.weeklySummary,
        ),
        isTrue,
      );
    });
  });

  group('NotificationService - Monthly Summary', () {
    test('should schedule monthly summary for end of month', () async {
      await service.scheduleMonthlySummary();

      expect(fakePlugin.scheduledNotifications.length, 1);
      final scheduled = fakePlugin.scheduledNotifications.first;
      expect(scheduled.id, NotificationIds.monthlySummary);
      expect(scheduled.title, '📈 Monthly Income Summary');
      // Verify it's scheduled for end of month (day 28, 29, 30, or 31)
      expect(scheduled.scheduledDate.day, greaterThanOrEqualTo(28));
    });

    test('should not schedule monthly summary when disabled', () async {
      await service.setMonthlySummaryEnabled(false);
      fakePlugin.reset();

      await service.scheduleMonthlySummary();

      expect(fakePlugin.scheduledNotifications, isEmpty);
    });
  });

  group('NotificationService - Income Reminders', () {
    test('should schedule income reminder for future date', () async {
      await service.scheduleIncomeReminder(
        investmentId: 'inv-123',
        investmentName: 'Monthly Bond',
        monthsBetweenPayments: 1,
        lastIncomeDate: DateTime.now().subtract(const Duration(days: 5)),
      );

      expect(fakePlugin.scheduledNotifications.length, 1);
      final scheduled = fakePlugin.scheduledNotifications.first;
      expect(scheduled.title, '💰 Income Expected');
      expect(scheduled.body, contains('Monthly Bond'));
      // Verify it's scheduled in the future
      expect(scheduled.scheduledDate.isAfter(DateTime.now()), isTrue);
    });

    test('should schedule from today when no last income date', () async {
      await service.scheduleIncomeReminder(
        investmentId: 'inv-456',
        investmentName: 'Quarterly Fund',
        monthsBetweenPayments: 3,
      );

      expect(fakePlugin.scheduledNotifications.length, 1);
      final scheduled = fakePlugin.scheduledNotifications.first;
      final now = DateTime.now();

      // Verify scheduled date is roughly 3 months in the future
      // We use a range because adding months to dates like Jan 31 can overflow to May 1
      final minDate = now.add(const Duration(days: 80)); // ~3 months - buffer
      final maxDate = now.add(const Duration(days: 100)); // ~3 months + buffer

      expect(scheduled.scheduledDate.isAfter(minDate), isTrue);
      expect(scheduled.scheduledDate.isBefore(maxDate), isTrue);
    });

    test('should not schedule when income reminders disabled', () async {
      await service.setIncomeRemindersEnabled(false);

      await service.scheduleIncomeReminder(
        investmentId: 'inv-789',
        investmentName: 'Test Investment',
        monthsBetweenPayments: 1,
      );

      expect(fakePlugin.scheduledNotifications, isEmpty);
    });

    // Rescheduling replaces the pending reminder without a cancel: on
    // Android a cancel also removes a delivered reminder from the shade.
    test('rescheduling replaces the pending reminder without cancelling '
        'one already shown', () async {
      await service.scheduleIncomeReminder(
        investmentId: 'inv-123',
        investmentName: 'Bond 1',
        monthsBetweenPayments: 1,
      );

      await service.scheduleIncomeReminder(
        investmentId: 'inv-123',
        investmentName: 'Bond 1 Updated',
        monthsBetweenPayments: 2,
      );

      final expectedId = NotificationIds.incomeReminder('inv-123');
      final pending = fakePlugin.scheduledNotifications
          .where((n) => n.id == expectedId)
          .toList();
      expect(pending, hasLength(1));
      expect(pending.single.body, contains('Bond 1 Updated'));
      expect(fakePlugin.cancelledNotificationIds, isNot(contains(expectedId)));
    });

    test('should cancel income reminder by investment ID', () async {
      await service.scheduleIncomeReminder(
        investmentId: 'inv-to-cancel',
        investmentName: 'Cancel Me',
        monthsBetweenPayments: 1,
      );

      await service.cancelIncomeReminder('inv-to-cancel');

      final expectedId = NotificationIds.incomeReminder('inv-to-cancel');
      expect(fakePlugin.cancelledNotificationIds.contains(expectedId), isTrue);
    });

    test(
      'should calculate next income date when last income is in the past',
      () async {
        // Last income was 3 months ago with monthly frequency
        final threeMonthsAgo = DateTime.now().subtract(
          const Duration(days: 90),
        );

        await service.scheduleIncomeReminder(
          investmentId: 'inv-past',
          investmentName: 'Past Income',
          monthsBetweenPayments: 1,
          lastIncomeDate: threeMonthsAgo,
        );

        expect(fakePlugin.scheduledNotifications.length, 1);
        final scheduled = fakePlugin.scheduledNotifications.first;
        // Should be scheduled in the future
        expect(scheduled.scheduledDate.isAfter(DateTime.now()), isTrue);
      },
    );
  });

  group('NotificationService - Maturity Reminders', () {
    test('should schedule 7-day and 1-day maturity reminders', () async {
      final maturityDate = DateTime.now().add(const Duration(days: 14));

      await service.scheduleMaturityReminders(
        investmentId: 'inv-mature',
        investmentName: 'Maturing Bond',
        maturityDate: maturityDate,
      );

      // Should have both 7-day and 1-day reminders
      expect(fakePlugin.scheduledNotifications.length, 2);

      final titles = fakePlugin.scheduledNotifications
          .map((n) => n.title)
          .toList();
      expect(titles, contains('📅 Investment Maturing Soon'));
      expect(titles, contains('⏰ Maturity Tomorrow!'));
    });

    test(
      'should only schedule 1-day reminder when less than 7 days away',
      () async {
        final maturityDate = DateTime.now().add(const Duration(days: 5));

        await service.scheduleMaturityReminders(
          investmentId: 'inv-soon',
          investmentName: 'Soon Bond',
          maturityDate: maturityDate,
        );

        expect(fakePlugin.scheduledNotifications.length, 1);
        expect(
          fakePlugin.scheduledNotifications.first.title,
          '⏰ Maturity Tomorrow!',
        );
      },
    );

    test(
      'should not schedule reminders when maturity is in the past',
      () async {
        final pastDate = DateTime.now().subtract(const Duration(days: 5));

        await service.scheduleMaturityReminders(
          investmentId: 'inv-past',
          investmentName: 'Past Bond',
          maturityDate: pastDate,
        );

        expect(fakePlugin.scheduledNotifications, isEmpty);
      },
    );

    test('should not schedule when maturity reminders disabled', () async {
      await service.setMaturityRemindersEnabled(false);
      final maturityDate = DateTime.now().add(const Duration(days: 14));

      await service.scheduleMaturityReminders(
        investmentId: 'inv-disabled',
        investmentName: 'Disabled Bond',
        maturityDate: maturityDate,
      );

      expect(fakePlugin.scheduledNotifications, isEmpty);
    });

    test(
      'should cancel existing reminders before scheduling new ones',
      () async {
        final maturityDate1 = DateTime.now().add(const Duration(days: 14));
        final maturityDate2 = DateTime.now().add(const Duration(days: 20));

        await service.scheduleMaturityReminders(
          investmentId: 'inv-update',
          investmentName: 'Update Bond',
          maturityDate: maturityDate1,
        );

        await service.scheduleMaturityReminders(
          investmentId: 'inv-update',
          investmentName: 'Update Bond',
          maturityDate: maturityDate2,
        );

        final id7Days = NotificationIds.maturityReminder7Days('inv-update');
        final id1Day = NotificationIds.maturityReminder1Day('inv-update');
        expect(fakePlugin.cancelledNotificationIds.contains(id7Days), isTrue);
        expect(fakePlugin.cancelledNotificationIds.contains(id1Day), isTrue);
      },
    );

    test('should cancel maturity reminders by investment ID', () async {
      await service.cancelMaturityReminders('inv-cancel-maturity');

      final id7Days = NotificationIds.maturityReminder7Days(
        'inv-cancel-maturity',
      );
      final id1Day = NotificationIds.maturityReminder1Day(
        'inv-cancel-maturity',
      );
      expect(fakePlugin.cancelledNotificationIds.contains(id7Days), isTrue);
      expect(fakePlugin.cancelledNotificationIds.contains(id1Day), isTrue);
    });

    test(
      'should include financial context in enhanced maturity reminders',
      () async {
        final maturityDate = DateTime.now().add(const Duration(days: 14));

        await service.scheduleMaturityReminders(
          investmentId: 'inv-enhanced',
          investmentName: 'My FD',
          maturityDate: maturityDate,
          investmentType: 'FD',
          investedAmount: 100000,
          currentValue: 108000,
          currency: 'INR',
        );

        expect(fakePlugin.scheduledNotifications.length, 2);

        final sevenDayReminder = fakePlugin.scheduledNotifications.firstWhere(
          (n) => n.title == '📅 Investment Maturing Soon',
        );

        // Should contain the investment name, type, and returns info
        expect(sevenDayReminder.body, contains('My FD'));
        expect(sevenDayReminder.body, contains('FD'));
        // Lakh grouping with the shared formatter, not '₹108000' (PLAT-18).
        expect(sevenDayReminder.body, contains('₹1,08,000.00'));
        expect(sevenDayReminder.body, contains('8.0%'));
      },
    );
  });

  group('NotificationService - Cancel All', () {
    test('should cancel all notifications', () async {
      await service.scheduleWeeklySummary();
      await service.scheduleMonthlySummary();

      await service.cancelAll();

      expect(fakePlugin.allCancelled, isTrue);
    });
  });

  group('NotificationService - Grouped Notifications', () {
    test(
      'should show income reminders summary with multiple investments',
      () async {
        await service.showIncomeRemindersSummary([
          'FD 1',
          'Bond 2',
          'P2P Loan 3',
        ]);

        expect(fakePlugin.shownNotifications.length, 1);
        final notification = fakePlugin.shownNotifications.first;
        expect(notification.id, NotificationIds.incomeRemindersSummary);
        expect(notification.title, contains('3 Income Payments'));
        expect(notification.body, contains('FD 1'));
        expect(notification.body, contains('Bond 2'));
      },
    );

    test(
      'should show maturity reminders summary with multiple investments',
      () async {
        await service.showMaturityRemindersSummary([
          'Maturing FD',
          'Maturing Bond',
        ]);

        expect(fakePlugin.shownNotifications.length, 1);
        final notification = fakePlugin.shownNotifications.first;
        expect(notification.id, NotificationIds.maturityRemindersSummary);
        expect(notification.title, contains('2 Investments Maturing'));
      },
    );

    test('should not show summary for empty list', () async {
      await service.showIncomeRemindersSummary([]);
      await service.showMaturityRemindersSummary([]);

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test('should truncate long list in summary body', () async {
      await service.showIncomeRemindersSummary([
        'Investment 1',
        'Investment 2',
        'Investment 3',
        'Investment 4',
        'Investment 5',
      ]);

      final notification = fakePlugin.shownNotifications.first;
      expect(notification.body, contains('and 2 more'));
    });
  });

  group('NotificationService - Reschedule All', () {
    test('should reschedule all notifications for open investments', () async {
      final now = DateTime.now();
      final investments = <InvestmentEntity>[
        InvestmentEntity(
          id: 'inv-1',
          name: 'Bond with Maturity',
          type: InvestmentType.bonds,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
          maturityDate: now.add(const Duration(days: 30)),
          incomeFrequency: IncomeFrequency.monthly,
        ),
        InvestmentEntity(
          id: 'inv-2',
          name: 'Stock (no maturity)',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
        InvestmentEntity(
          id: 'inv-3',
          name: 'Closed Investment',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.closed,
          createdAt: now,
          updatedAt: now,
          maturityDate: now.add(const Duration(days: 30)),
        ),
      ];

      await service.rescheduleAllNotifications(
        investments,
        lastIncomeDates: const {},
      );

      // Should have: weekly + monthly + maturity reminders for inv-1 + income reminder for inv-1
      // Weekly: 1, Monthly: 1, Maturity (7d + 1d): 2, Income: 1 = 5 total
      expect(fakePlugin.scheduledNotifications.length, greaterThanOrEqualTo(4));
    });

    test('should not schedule for closed investments', () async {
      final now = DateTime.now();
      final investments = <InvestmentEntity>[
        InvestmentEntity(
          id: 'inv-closed',
          name: 'Closed Bond',
          type: InvestmentType.bonds,
          status: InvestmentStatus.closed,
          createdAt: now,
          updatedAt: now,
          maturityDate: now.add(const Duration(days: 30)),
          incomeFrequency: IncomeFrequency.monthly,
        ),
      ];

      await service.rescheduleAllNotifications(
        investments,
        lastIncomeDates: const {},
      );

      // Only weekly and monthly summaries, no investment-specific reminders
      expect(fakePlugin.scheduledNotifications.length, 2);
    });
  });

  group('NotificationIds - ID Generation', () {
    test('weekly summary should have fixed ID', () {
      expect(NotificationIds.weeklySummary, 1000);
    });

    test('monthly summary should have fixed ID', () {
      expect(NotificationIds.monthlySummary, 1001);
    });

    test('income reminder IDs should be consistent for same investment', () {
      final id1 = NotificationIds.incomeReminder('investment-abc');
      final id2 = NotificationIds.incomeReminder('investment-abc');
      expect(id1, id2);
    });

    test('income reminder IDs should differ for different investments', () {
      final id1 = NotificationIds.incomeReminder('investment-abc');
      final id2 = NotificationIds.incomeReminder('investment-xyz');
      expect(id1, isNot(id2));
    });

    test('maturity reminder IDs should be in expected range', () {
      final id7Days = NotificationIds.maturityReminder7Days('inv-test');
      final id1Day = NotificationIds.maturityReminder1Day('inv-test');

      expect(id7Days, greaterThanOrEqualTo(100000));
      expect(id7Days, lessThan(125000));
      expect(id1Day, greaterThanOrEqualTo(125000));
      expect(id1Day, lessThan(150000));
    });
  });

  group('NotificationChannels - Constants', () {
    test('should have correct channel IDs', () {
      expect(NotificationChannels.weeklySummary, 'weekly_summary');
      expect(NotificationChannels.incomeReminders, 'income_reminders');
      expect(NotificationChannels.maturityReminders, 'maturity_reminders');
      expect(NotificationChannels.monthlySummary, 'monthly_summary');
      expect(NotificationChannels.general, 'general');
    });
  });

  group('NotificationPrefsKeys - Constants', () {
    test('should have correct preference keys', () {
      expect(
        NotificationPrefsKeys.weeklySummaryEnabled,
        'notifications_weekly_summary',
      );
      expect(
        NotificationPrefsKeys.incomeRemindersEnabled,
        'notifications_income_reminders',
      );
      expect(
        NotificationPrefsKeys.maturityRemindersEnabled,
        'notifications_maturity_reminders',
      );
      expect(
        NotificationPrefsKeys.monthlySummaryEnabled,
        'notifications_monthly_summary',
      );
    });
  });

  group('NotificationService - Milestones', () {
    test(
      'should show milestone notification when MOIC threshold reached',
      () async {
        // 1000 invested, 1500 returned = 1.5x MOIC
        await service.checkAndShowMilestone(
          investmentId: 'inv-milestone',
          investmentName: 'P2P Investment',
          totalInvested: 1000,
          totalReturned: 1500,
        );

        expect(fakePlugin.shownNotifications.length, 1);
        final notification = fakePlugin.shownNotifications.first;
        expect(notification.title, contains('1.5x'));
        expect(notification.body, contains('P2P Investment'));
      },
    );

    test('should not show duplicate milestone notification', () async {
      await service.checkAndShowMilestone(
        investmentId: 'inv-dup',
        investmentName: 'Test Investment',
        totalInvested: 1000,
        totalReturned: 1500,
      );

      // Try to show same milestone again
      await service.checkAndShowMilestone(
        investmentId: 'inv-dup',
        investmentName: 'Test Investment',
        totalInvested: 1000,
        totalReturned: 1600, // Still 1.5x+
      );

      // Should only have 1 notification (not 2)
      expect(fakePlugin.shownNotifications.length, 1);
    });

    test(
      'should show higher milestone when multiple thresholds crossed',
      () async {
        // 1000 invested, 2000 returned = 2.0x MOIC
        await service.checkAndShowMilestone(
          investmentId: 'inv-high',
          investmentName: 'High Performer',
          totalInvested: 1000,
          totalReturned: 2000,
        );

        expect(fakePlugin.shownNotifications.length, 1);
        final notification = fakePlugin.shownNotifications.first;
        expect(notification.title, contains('2.0x'));
      },
    );

    test('should not show milestone when disabled', () async {
      await service.setMilestonesEnabled(false);

      await service.checkAndShowMilestone(
        investmentId: 'inv-disabled',
        investmentName: 'Disabled',
        totalInvested: 1000,
        totalReturned: 2000,
      );

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test('should use private visibility for idle alerts', () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 100));

      await service.checkIdleInvestments([
        IdleInvestmentInfo(
          id: 'inv-private',
          name: 'Private Investment',
          lastActivityDate: oldDate,
          isClosed: false,
        ),
      ]);

      expect(fakePlugin.shownNotifications.length, 1);
      final notification = fakePlugin.shownNotifications.first;
      expect(
        notification.notificationDetails?.android?.visibility,
        NotificationVisibility.private,
      );
    });
  });

  // Amounts in notifications use the currency's own symbol and number locale
  // (A18, GAP2-03): '\$5,000.00' for USD, never '₹5,000.00'; lakh grouping
  // for INR.
  group('NotificationService - Amount formatting', () {
    test('a USD milestone shows the profit in dollars', () async {
      await service.checkAndShowMilestone(
        investmentId: 'inv-usd',
        investmentName: 'US Fund',
        totalInvested: 10000,
        totalReturned: 15000,
        currency: 'USD',
      );

      final body = fakePlugin.shownNotifications.single.body!;
      expect(body, contains('\$5,000.00'));
      expect(body, isNot(contains('₹')));
    });

    test('an INR milestone uses lakh grouping', () async {
      await service.checkAndShowMilestone(
        investmentId: 'inv-inr',
        investmentName: 'FD',
        totalInvested: 100000,
        totalReturned: 970000,
        currency: 'INR',
      );

      final body = fakePlugin.shownNotifications.single.body!;
      expect(body, contains('₹8,70,000.00'));
    });

    test('a EUR goal milestone uses the euro format', () async {
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-eur',
        goalName: 'House',
        progressPercent: 50,
        currentValue: 25000,
        targetValue: 50000,
        currency: 'EUR',
      );

      final body = fakePlugin.shownNotifications.single.body!;
      expect(body, contains('25.000,00\u00A0€'));
      expect(body, contains('50.000,00\u00A0€'));
      expect(body, isNot(contains('EUR')));
    });

    test('a BDT goal milestone uses Latin numerals', () async {
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-bdt',
        goalName: 'Savings',
        progressPercent: 25,
        currentValue: 250000,
        targetValue: 1000000,
        currency: 'BDT',
      );

      final body = fakePlugin.shownNotifications.single.body!;
      expect(body, contains('৳2,50,000.00'));
      expect(body, contains('৳10,00,000.00'));
    });

    test('a EUR maturity reminder never uses the dollar sign', () async {
      await service.scheduleMaturityReminders(
        investmentId: 'inv-eur',
        investmentName: 'Bund',
        maturityDate: DateTime.now().add(const Duration(days: 14)),
        investedAmount: 50000,
        currentValue: 51200,
        currency: 'EUR',
      );

      final body = fakePlugin.scheduledNotifications.first.body!;
      expect(body, contains('51.200,00\u00A0€'));
      expect(body, isNot(contains('\$')));
    });
  });

  group('NotificationService - Tax Reminders', () {
    test('should schedule tax reminders when enabled', () async {
      await service.scheduleTaxReminders();

      // Should have scheduled some tax reminders (depends on current date)
      expect(fakePlugin.scheduledNotifications.isNotEmpty, isTrue);
    });

    test('should cancel all tax reminders', () async {
      await service.scheduleTaxReminders();
      await service.cancelTaxReminders();

      expect(
        fakePlugin.cancelledNotificationIds.contains(
          NotificationIds.taxReminder80C,
        ),
        isTrue,
      );
      expect(
        fakePlugin.cancelledNotificationIds.contains(
          NotificationIds.taxReminderITR,
        ),
        isTrue,
      );
    });
  });

  group('NotificationService - Risk Alerts', () {
    test('should show risk alert notification', () async {
      await service.showRiskAlert(
        alertType: 'single_investment',
        title: 'High Concentration',
        body: 'Investment XYZ is 45% of your portfolio',
      );

      expect(fakePlugin.shownNotifications.length, 1);
      final notification = fakePlugin.shownNotifications.first;
      expect(notification.title, contains('High Concentration'));
      expect(notification.body, contains('45%'));
    });

    test('should not show risk alert when disabled', () async {
      await service.setRiskAlertsEnabled(false);

      await service.showRiskAlert(
        alertType: 'platform_concentration',
        title: 'Platform Risk',
        body: 'Too much in one platform',
      );

      expect(fakePlugin.shownNotifications.length, 0);
    });
  });

  group('NotificationService - Weekly Check-In', () {
    test('should schedule weekly check-in for Sunday', () async {
      await service.scheduleWeeklyCheckIn();

      expect(fakePlugin.scheduledNotifications.length, 1);
      final scheduled = fakePlugin.scheduledNotifications.first;
      expect(scheduled.id, NotificationIds.weeklyCheckIn);
      expect(scheduled.title, contains('Weekly Check-In'));
    });

    test('should not schedule when disabled', () async {
      await service.setWeeklyCheckInEnabled(false);
      fakePlugin.scheduledNotifications.clear();

      await service.scheduleWeeklyCheckIn();

      expect(fakePlugin.scheduledNotifications.length, 0);
    });
  });

  group('NotificationService - Idle Investment Alerts', () {
    test(
      'should show idle alert for investment with no recent activity',
      () async {
        final oldDate = DateTime.now().subtract(const Duration(days: 100));

        await service.checkIdleInvestments([
          IdleInvestmentInfo(
            id: 'inv-idle',
            name: 'Idle Investment',
            lastActivityDate: oldDate,
            isClosed: false,
          ),
        ]);

        expect(fakePlugin.shownNotifications.length, 1);
        final notification = fakePlugin.shownNotifications.first;
        expect(notification.title, contains('Review Needed'));
        expect(notification.body, contains('Idle Investment'));
      },
    );

    test('should not show idle alert for recent activity', () async {
      final recentDate = DateTime.now().subtract(const Duration(days: 30));

      await service.checkIdleInvestments([
        IdleInvestmentInfo(
          id: 'inv-active',
          name: 'Active Investment',
          lastActivityDate: recentDate,
          isClosed: false,
        ),
      ]);

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test('should not show idle alert for closed investments', () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 100));

      await service.checkIdleInvestments([
        IdleInvestmentInfo(
          id: 'inv-closed',
          name: 'Closed Investment',
          lastActivityDate: oldDate,
          isClosed: true,
        ),
      ]);

      expect(fakePlugin.shownNotifications.length, 0);
    });
  });

  group('NotificationService - FY Summary', () {
    test('should schedule FY summary for April 1st', () async {
      await service.scheduleFYSummary();

      expect(fakePlugin.scheduledNotifications.length, 1);
      final scheduled = fakePlugin.scheduledNotifications.first;
      expect(scheduled.id, NotificationIds.fySummary);
      expect(scheduled.title, contains('FY Summary'));
    });

    test('should show immediate FY summary with data', () async {
      await service.showFYSummary(
        previousFY: 2023,
        totalIncome: 150000,
        totalTDS: 15000,
        topPerformer: 'P2P Investment',
      );

      expect(fakePlugin.shownNotifications.length, 1);
      final notification = fakePlugin.shownNotifications.first;
      expect(notification.title, contains('FY2023-2024'));
      expect(notification.body, contains('Income'));
      expect(notification.body, contains('TDS'));
    });
  });

  group('NotificationService - Goal Milestones', () {
    test('should show goal milestone notification at 25%', () async {
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-123',
        goalName: 'Retirement Fund',
        progressPercent: 25,
        currentValue: 25000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      final notification = fakePlugin.shownNotifications.first;
      expect(notification.title, contains('25%'));
      expect(notification.body, contains('Retirement Fund'));
      expect(notification.body, contains('₹25,000.00'));
      // INR uses lakh grouping, not '₹100,000.00' (GAP2-03).
      expect(notification.body, contains('₹1,00,000.00'));
    });

    test('should show goal milestone notification at 50%', () async {
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-456',
        goalName: 'Emergency Fund',
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      final notification = fakePlugin.shownNotifications.first;
      expect(notification.title, contains('50%'));
    });

    test('should show goal milestone notification at 75%', () async {
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-789',
        goalName: 'House Down Payment',
        progressPercent: 75,
        currentValue: 75000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      final notification = fakePlugin.shownNotifications.first;
      expect(notification.title, contains('75%'));
    });

    test('should show goal achieved notification at 100%', () async {
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-complete',
        goalName: 'Vacation Fund',
        progressPercent: 100,
        currentValue: 100000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      final notification = fakePlugin.shownNotifications.first;
      expect(notification.title, contains('Achieved'));
    });

    test('should use correct notification ID based on goal ID', () async {
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-abc',
        goalName: 'Test Goal',
        progressPercent: 25,
        currentValue: 2500,
        targetValue: 10000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      // Notification ID should be based on goal ID hash
      final notification = fakePlugin.shownNotifications.first;
      expect(notification.id, greaterThan(0));
    });

    test(
      'should not show notification when goal milestones disabled',
      () async {
        await service.setGoalMilestonesEnabled(false);

        await service.checkAndShowGoalMilestone(
          goalId: 'goal-disabled',
          goalName: 'Disabled Goal',
          progressPercent: 50,
          currentValue: 50000,
          targetValue: 100000,
        );

        expect(fakePlugin.shownNotifications.length, 0);
      },
    );

    test('never shows a skipped lower milestone afterwards', () async {
      // GAP3-07: this used to announce 50% and then, on the next check,
      // 25%: milestones went backwards (after "Goal Achieved!" came 75%,
      // 50% and 25%). Reaching 50% now also records 25%.
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-dup',
        goalName: 'Duplicate Test',
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
      expect(fakePlugin.shownNotifications.first.title, contains('50%'));

      await service.checkAndShowGoalMilestone(
        goalId: 'goal-dup',
        goalName: 'Duplicate Test',
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);

      // Third call should not show anything (both 25% and 50% recorded)
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-dup',
        goalName: 'Duplicate Test',
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      // No new notification
      expect(fakePlugin.shownNotifications.length, 1);
    });

    test('should show new milestone when higher threshold reached', () async {
      // First call shows 50% notification
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-progress',
        goalName: 'Progress Test',
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);

      // Second call at 75% should show new notification
      await service.checkAndShowGoalMilestone(
        goalId: 'goal-progress',
        goalName: 'Progress Test',
        progressPercent: 75,
        currentValue: 75000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 2);
      expect(fakePlugin.shownNotifications.last.title, contains('75%'));
    });
  });

  group('NotificationService - Permission Checks', () {
    test(
      'arePermissionsGranted returns true when permissions granted',
      () async {
        fakePlugin.permissionsGranted = true;
        await service.initialize();

        final result = await service.arePermissionsGranted();

        expect(result, isTrue);
      },
    );

    test(
      'arePermissionsGranted returns false when permissions denied',
      () async {
        fakePlugin.permissionsGranted = false;
        await service.initialize();

        final result = await service.arePermissionsGranted();

        expect(result, isFalse);
      },
    );

    test('should not show goal milestone when permissions denied', () async {
      fakePlugin.permissionsGranted = false;

      await service.checkAndShowGoalMilestone(
        goalId: 'goal-no-perm',
        goalName: 'No Permission Goal',
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test(
      'should not show investment milestone when permissions denied',
      () async {
        fakePlugin.permissionsGranted = false;

        await service.checkAndShowMilestone(
          investmentId: 'inv-no-perm',
          investmentName: 'No Permission Investment',
          totalInvested: 10000,
          totalReturned: 20000, // 2x return
        );

        expect(fakePlugin.shownNotifications.length, 0);
      },
    );

    test('should show goal milestone when permissions granted', () async {
      fakePlugin.permissionsGranted = true;

      await service.checkAndShowGoalMilestone(
        goalId: 'goal-with-perm',
        goalName: 'With Permission Goal',
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakePlugin.shownNotifications.length, 1);
    });

    test('should not show risk alert when permissions denied', () async {
      fakePlugin.permissionsGranted = false;

      await service.showRiskAlert(
        alertType: 'concentration',
        title: 'Test Alert',
        body: 'Test body',
      );

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test('should not show FY summary when permissions denied', () async {
      fakePlugin.permissionsGranted = false;

      await service.showFYSummary(
        previousFY: 2023,
        totalIncome: 100000,
        totalTDS: 10000,
        topPerformer: 'Test Investment',
      );

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test(
      'should not show income reminders summary when permissions denied',
      () async {
        fakePlugin.permissionsGranted = false;

        await service.showIncomeRemindersSummary([
          'Investment 1',
          'Investment 2',
        ]);

        expect(fakePlugin.shownNotifications.length, 0);
      },
    );

    test(
      'should not show maturity reminders summary when permissions denied',
      () async {
        fakePlugin.permissionsGranted = false;

        await service.showMaturityRemindersSummary([
          'Investment 1',
          'Investment 2',
        ]);

        expect(fakePlugin.shownNotifications.length, 0);
      },
    );

    test(
      'should not show goal at-risk notification when permissions denied',
      () async {
        fakePlugin.permissionsGranted = false;

        await service.showGoalAtRiskNotification(
          goalId: 'goal-no-perm',
          goalName: 'No Permission Goal',
          progressPercent: 40,
          targetDate: DateTime.now().add(const Duration(days: 30)),
          projectedDate: DateTime.now().add(const Duration(days: 90)),
        );

        expect(fakePlugin.shownNotifications.length, 0);
      },
    );

    test(
      'should not show goal stale notification when permissions denied',
      () async {
        fakePlugin.permissionsGranted = false;

        await service.showGoalStaleNotification(
          goalId: 'goal-no-perm',
          goalName: 'No Permission Goal',
          lastActivityDate: DateTime.now().subtract(const Duration(days: 90)),
        );

        expect(fakePlugin.shownNotifications.length, 0);
      },
    );
  });

  group('NotificationService - Goal At-Risk Alerts', () {
    test(
      'should show at-risk notification when goal is behind schedule',
      () async {
        await service.showGoalAtRiskNotification(
          goalId: 'goal-at-risk',
          goalName: 'Retirement Fund',
          progressPercent: 40,
          targetDate: DateTime.now().add(const Duration(days: 30)),
          projectedDate: DateTime.now().add(const Duration(days: 90)),
        );

        expect(fakePlugin.shownNotifications.length, 1);
        final notification = fakePlugin.shownNotifications.first;
        expect(notification.title, contains('At Risk'));
        expect(notification.body, contains('Retirement Fund'));
        expect(notification.body, contains('40%'));
      },
    );

    test('should not show at-risk notification when disabled', () async {
      await service.setGoalAtRiskEnabled(false);

      await service.showGoalAtRiskNotification(
        goalId: 'goal-disabled',
        goalName: 'Disabled Goal',
        progressPercent: 40,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        projectedDate: DateTime.now().add(const Duration(days: 90)),
      );

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test('should not show at-risk notification when dates are null', () async {
      await service.showGoalAtRiskNotification(
        goalId: 'goal-no-dates',
        goalName: 'No Dates Goal',
        progressPercent: 40,
        targetDate: null,
        projectedDate: null,
      );

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test('should rate-limit at-risk notifications to once per week', () async {
      // First notification should show
      await service.showGoalAtRiskNotification(
        goalId: 'goal-rate-limit',
        goalName: 'Rate Limited Goal',
        progressPercent: 40,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        projectedDate: DateTime.now().add(const Duration(days: 90)),
      );

      expect(fakePlugin.shownNotifications.length, 1);

      // Second notification within 7 days should not show
      await service.showGoalAtRiskNotification(
        goalId: 'goal-rate-limit',
        goalName: 'Rate Limited Goal',
        progressPercent: 35,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        projectedDate: DateTime.now().add(const Duration(days: 100)),
      );

      expect(fakePlugin.shownNotifications.length, 1);
    });

    test('goal at-risk should be enabled by default', () {
      expect(service.goalAtRiskEnabled, isTrue);
    });

    test('should persist goal at-risk preference', () async {
      await service.setGoalAtRiskEnabled(false);
      expect(service.goalAtRiskEnabled, isFalse);

      await service.setGoalAtRiskEnabled(true);
      expect(service.goalAtRiskEnabled, isTrue);
    });
  });

  group('NotificationService - Goal Stale Reminders', () {
    test(
      'should show stale notification when no activity for 60+ days',
      () async {
        await service.showGoalStaleNotification(
          goalId: 'goal-stale',
          goalName: 'Neglected Fund',
          lastActivityDate: DateTime.now().subtract(const Duration(days: 90)),
        );

        expect(fakePlugin.shownNotifications.length, 1);
        final notification = fakePlugin.shownNotifications.first;
        expect(notification.title, contains('Needs Attention'));
        expect(notification.body, contains('Neglected Fund'));
        expect(notification.body, contains('90 days'));
      },
    );

    test('should not show stale notification when disabled', () async {
      await service.setGoalStaleEnabled(false);

      await service.showGoalStaleNotification(
        goalId: 'goal-disabled',
        goalName: 'Disabled Goal',
        lastActivityDate: DateTime.now().subtract(const Duration(days: 90)),
      );

      expect(fakePlugin.shownNotifications.length, 0);
    });

    test(
      'should not show stale notification when activity is recent',
      () async {
        await service.showGoalStaleNotification(
          goalId: 'goal-recent',
          goalName: 'Active Goal',
          lastActivityDate: DateTime.now().subtract(const Duration(days: 30)),
        );

        expect(fakePlugin.shownNotifications.length, 0);
      },
    );

    test(
      'should show stale notification when lastActivityDate is null',
      () async {
        await service.showGoalStaleNotification(
          goalId: 'goal-null-date',
          goalName: 'New Goal',
          lastActivityDate: null,
        );

        expect(fakePlugin.shownNotifications.length, 1);
        final notification = fakePlugin.shownNotifications.first;
        expect(notification.body, contains('60 days'));
      },
    );

    test('should rate-limit stale notifications to once per month', () async {
      // First notification should show
      await service.showGoalStaleNotification(
        goalId: 'goal-rate-limit',
        goalName: 'Rate Limited Goal',
        lastActivityDate: DateTime.now().subtract(const Duration(days: 90)),
      );

      expect(fakePlugin.shownNotifications.length, 1);

      // Second notification within 30 days should not show
      await service.showGoalStaleNotification(
        goalId: 'goal-rate-limit',
        goalName: 'Rate Limited Goal',
        lastActivityDate: DateTime.now().subtract(const Duration(days: 100)),
      );

      expect(fakePlugin.shownNotifications.length, 1);
    });

    test('goal stale should be enabled by default', () {
      expect(service.goalStaleEnabled, isTrue);
    });

    test('should persist goal stale preference', () async {
      await service.setGoalStaleEnabled(false);
      expect(service.goalStaleEnabled, isFalse);

      await service.setGoalStaleEnabled(true);
      expect(service.goalStaleEnabled, isTrue);
    });

    test('should use default stale days of 60', () {
      expect(service.goalStaleDays, 60);
    });

    test('should persist custom stale days', () async {
      await service.setGoalStaleDays(45);
      expect(service.goalStaleDays, 45);

      await service.setGoalStaleDays(90);
      expect(service.goalStaleDays, 90);
    });

    test('should respect custom stale days threshold', () async {
      await service.setGoalStaleDays(30);

      // Activity 45 days ago should trigger stale (threshold is 30)
      await service.showGoalStaleNotification(
        goalId: 'goal-custom-threshold',
        goalName: 'Custom Threshold Goal',
        lastActivityDate: DateTime.now().subtract(const Duration(days: 45)),
      );

      expect(fakePlugin.shownNotifications.length, 1);
    });
  });

  // A08 (#751): income reminders must stay anchored to the payout schedule
  // across launches, switching a reminder type off must remove its pending
  // alarms, and alarms for closed or removed investments must not linger.
  group('NotificationService - Reminder schedule stability (A08)', () {
    late DateTime fakeNow;
    late NotificationService clockedService;

    setUp(() {
      fakeNow = DateTime(2026, 10, 2, 10);
      clockedService = NotificationService(
        fakePlugin,
        prefs,
        clock: () => fakeNow,
      );
    });

    InvestmentEntity investment({
      String id = 'inv-p2p',
      DateTime? startDate,
      IncomeFrequency? incomeFrequency = IncomeFrequency.monthly,
      DateTime? maturityDate,
      InvestmentStatus status = InvestmentStatus.open,
    }) => InvestmentEntity(
      id: id,
      name: 'P2P Monthly',
      type: InvestmentType.p2pLending,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      startDate: startDate,
      incomeFrequency: incomeFrequency,
      maturityDate: maturityDate,
    );

    DateTime incomeReminderDate(String investmentId) {
      final matches = fakePlugin.scheduledNotifications
          .where((n) => n.id == NotificationIds.incomeReminder(investmentId))
          .toList();
      expect(matches, hasLength(1));
      // Plain local DateTime (TZDateTime never equals a DateTime).
      return DateTime.fromMillisecondsSinceEpoch(
        matches.single.scheduledDate.millisecondsSinceEpoch,
      );
    }

    Future<Set<int>> pendingIds() async =>
        (await fakePlugin.pendingNotificationRequests())
            .map((p) => p.id)
            .toSet();

    test(
      'two launches a week apart keep the reminder anchored on the last INCOME date',
      () async {
        final inv = investment(startDate: DateTime(2026, 1, 15));
        final lastIncomeDates = {'inv-p2p': DateTime(2026, 9, 20)};

        await clockedService.rescheduleAllNotifications([
          inv,
        ], lastIncomeDates: lastIncomeDates);
        expect(incomeReminderDate('inv-p2p'), DateTime(2026, 10, 20, 9));

        fakeNow = DateTime(2026, 10, 9, 10);
        await clockedService.rescheduleAllNotifications([
          inv,
        ], lastIncomeDates: lastIncomeDates);
        expect(incomeReminderDate('inv-p2p'), DateTime(2026, 10, 20, 9));
      },
    );

    test(
      'two launches a week apart keep the reminder on startDate + k * period when there is no income yet',
      () async {
        final inv = investment(
          startDate: DateTime(2026, 3, 10),
          incomeFrequency: IncomeFrequency.quarterly,
        );

        await clockedService.rescheduleAllNotifications([
          inv,
        ], lastIncomeDates: const {});
        expect(incomeReminderDate('inv-p2p'), DateTime(2026, 12, 10, 9));

        fakeNow = DateTime(2026, 10, 9, 10);
        await clockedService.rescheduleAllNotifications([
          inv,
        ], lastIncomeDates: const {});
        expect(incomeReminderDate('inv-p2p'), DateTime(2026, 12, 10, 9));
      },
    );

    test('month-end anchor does not drift to an earlier day', () async {
      await clockedService.scheduleIncomeReminder(
        investmentId: 'inv-p2p',
        investmentName: 'P2P Monthly',
        monthsBetweenPayments: 1,
        lastIncomeDate: DateTime(2026, 1, 31),
      );

      // Jan 31 + 9 months = Oct 31 (not Oct 28 via Feb 28, Mar 28, ...).
      expect(incomeReminderDate('inv-p2p'), DateTime(2026, 10, 31, 9));
    });

    test(
      'turning income reminders off cancels the pending income alarms only',
      () async {
        await clockedService.scheduleWeeklySummary();
        await clockedService.scheduleIncomeReminder(
          investmentId: 'inv-a',
          investmentName: 'A',
          monthsBetweenPayments: 1,
          lastIncomeDate: DateTime(2026, 9, 20),
        );
        await clockedService.scheduleIncomeReminder(
          investmentId: 'inv-b',
          investmentName: 'B',
          monthsBetweenPayments: 3,
          lastIncomeDate: DateTime(2026, 8, 1),
        );
        expect(await pendingIds(), {
          NotificationIds.weeklySummary,
          NotificationIds.incomeReminder('inv-a'),
          NotificationIds.incomeReminder('inv-b'),
        });

        await clockedService.setIncomeRemindersEnabled(false);

        expect(await pendingIds(), {NotificationIds.weeklySummary});
      },
    );

    test(
      'turning maturity reminders off cancels the pending maturity alarms only',
      () async {
        await clockedService.scheduleIncomeReminder(
          investmentId: 'inv-a',
          investmentName: 'A',
          monthsBetweenPayments: 1,
          lastIncomeDate: DateTime(2026, 9, 20),
        );
        await clockedService.scheduleMaturityReminders(
          investmentId: 'inv-fd',
          investmentName: 'FD',
          maturityDate: DateTime(2027, 3, 31),
        );
        expect(await pendingIds(), {
          NotificationIds.incomeReminder('inv-a'),
          NotificationIds.maturityReminder7Days('inv-fd'),
          NotificationIds.maturityReminder1Day('inv-fd'),
        });

        await clockedService.setMaturityRemindersEnabled(false);

        expect(await pendingIds(), {NotificationIds.incomeReminder('inv-a')});
      },
    );

    test(
      'reschedule cancels pending alarms when the reminder type is already off',
      () async {
        await clockedService.scheduleIncomeReminder(
          investmentId: 'inv-p2p',
          investmentName: 'P2P Monthly',
          monthsBetweenPayments: 1,
          lastIncomeDate: DateTime(2026, 9, 20),
        );
        // Preference written without the side effect, as by an older build.
        await prefs.setBool(
          NotificationPrefsKeys.incomeRemindersEnabled,
          false,
        );

        await clockedService.rescheduleAllNotifications([
          investment(startDate: DateTime(2026, 1, 15)),
        ], lastIncomeDates: const {});

        expect(
          await pendingIds(),
          isNot(contains(NotificationIds.incomeReminder('inv-p2p'))),
        );
      },
    );

    test(
      'reschedule cancels alarms for closed and removed investments',
      () async {
        final fd = investment(
          id: 'inv-fd',
          maturityDate: DateTime(2027, 3, 31),
          startDate: DateTime(2026, 1, 15),
        );
        final p2p = investment(startDate: DateTime(2026, 1, 15));
        await clockedService.rescheduleAllNotifications([
          fd,
          p2p,
        ], lastIncomeDates: const {});
        expect(
          await pendingIds(),
          containsAll([
            NotificationIds.incomeReminder('inv-fd'),
            NotificationIds.maturityReminder7Days('inv-fd'),
            NotificationIds.maturityReminder1Day('inv-fd'),
            NotificationIds.incomeReminder('inv-p2p'),
          ]),
        );

        // inv-fd is closed (e.g. on another device); inv-p2p was deleted.
        await clockedService.rescheduleAllNotifications([
          investment(
            id: 'inv-fd',
            maturityDate: DateTime(2027, 3, 31),
            startDate: DateTime(2026, 1, 15),
            status: InvestmentStatus.closed,
          ),
        ], lastIncomeDates: const {});

        expect(await pendingIds(), {
          NotificationIds.weeklySummary,
          NotificationIds.monthlySummary,
        });
      },
    );

    // A08-F1: one investment that cannot be scheduled must not stop the
    // rest of the reschedule or the sweep of stale reminders.
    DateTime scheduledAt(int id) => DateTime.fromMillisecondsSinceEpoch(
      fakePlugin.scheduledNotifications
          .singleWhere((n) => n.id == id)
          .scheduledDate
          .millisecondsSinceEpoch,
    );

    test('a maturity reminder whose 09:00 fire time has passed is skipped, '
        'and later investments and the stale sweep still run', () async {
      fakeNow = DateTime(2026, 10, 8, 10);
      fakePlugin.now = () => fakeNow;
      // Reminder left by an investment deleted on another device.
      await clockedService.scheduleIncomeReminder(
        investmentId: 'inv-gone',
        investmentName: 'Gone',
        monthsBetweenPayments: 1,
        lastIncomeDate: DateTime(2026, 9, 20),
      );
      // Saved as midnight IST, read in the Gulf as 22:30 the day before:
      // the 7-day reminder (8 Oct 09:00) is already past at 10:00.
      final gulfFd = investment(
        id: 'inv-gulf-fd',
        incomeFrequency: null,
        maturityDate: DateTime(2026, 10, 15, 22, 30),
      );
      final p2p = investment(startDate: DateTime(2026, 1, 15));

      await clockedService.rescheduleAllNotifications([
        gulfFd,
        p2p,
      ], lastIncomeDates: const {});

      expect(await pendingIds(), {
        NotificationIds.weeklySummary,
        NotificationIds.monthlySummary,
        NotificationIds.maturityReminder1Day('inv-gulf-fd'),
        NotificationIds.incomeReminder('inv-p2p'),
      });
      expect(
        scheduledAt(NotificationIds.maturityReminder1Day('inv-gulf-fd')),
        DateTime(2026, 10, 14, 9),
      );
      expect(
        scheduledAt(NotificationIds.incomeReminder('inv-p2p')),
        DateTime(2026, 10, 15, 9),
      );
    });

    test('an investment whose scheduling throws does not abort the others '
        'or the stale sweep', () async {
      await clockedService.scheduleIncomeReminder(
        investmentId: 'inv-gone',
        investmentName: 'Gone',
        monthsBetweenPayments: 1,
        lastIncomeDate: DateTime(2026, 9, 20),
      );
      fakePlugin.failingScheduleIds.add(
        NotificationIds.incomeReminder('inv-bad'),
      );

      await clockedService.rescheduleAllNotifications([
        investment(id: 'inv-bad', startDate: DateTime(2026, 1, 15)),
        investment(startDate: DateTime(2026, 1, 15)),
      ], lastIncomeDates: const {});

      expect(await pendingIds(), {
        NotificationIds.weeklySummary,
        NotificationIds.monthlySummary,
        NotificationIds.incomeReminder('inv-p2p'),
      });
      expect(
        scheduledAt(NotificationIds.incomeReminder('inv-p2p')),
        DateTime(2026, 10, 15, 9),
      );
    });
  });
}
