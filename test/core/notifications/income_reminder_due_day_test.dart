// A91 (#856): an income reminder is an inexact alarm for 09:00 on the due
// day, and every launch reschedules it. Opening the app on the due day after
// 09:00, before Android has delivered the alarm, must not move the payout
// reminder to the next period. It must not be shown twice either.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../mocks/mock_notification_service.dart';

void main() {
  late FakeFlutterLocalNotificationsPlugin fakePlugin;
  late NotificationService service;
  late SharedPreferences prefs;
  late DateTime fakeNow;

  // A monthly payout anchored on 3 Sep 2026: due 3 Oct, then 3 Nov.
  final anchor = DateTime(2026, 9, 3);
  const investmentId = 'inv-p2p';
  final reminderId = NotificationIds.incomeReminder(investmentId);

  setUp(() async {
    tz_data.initializeTimeZones();
    fakePlugin = FakeFlutterLocalNotificationsPlugin();
    // The plugin reads the clock after the handler has, so a fire time equal
    // to the handler's "now" is already in the past when the plugin checks.
    fakePlugin.now = () => fakeNow.add(const Duration(milliseconds: 1));
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = NotificationService(fakePlugin, prefs, clock: () => fakeNow);
  });

  Future<void> schedule() => service.scheduleIncomeReminder(
    investmentId: investmentId,
    investmentName: 'P2P Monthly',
    monthsBetweenPayments: 1,
    lastIncomeDate: anchor,
  );

  /// The pending income alarm, as a plain local DateTime.
  DateTime pendingReminderDate() {
    final matches = fakePlugin.scheduledNotifications
        .where((n) => n.id == reminderId)
        .toList();
    expect(matches, hasLength(1));
    return DateTime.fromMillisecondsSinceEpoch(
      matches.single.scheduledDate.millisecondsSinceEpoch,
    );
  }

  /// Income reminders shown immediately by the app.
  List<FakeNotification> shownReminders() =>
      fakePlugin.shownNotifications.where((n) => n.id == reminderId).toList();

  /// Android delivers the alarm: it leaves the pending list.
  void deliverPendingReminder() {
    fakePlugin.scheduledNotifications.removeWhere((n) => n.id == reminderId);
  }

  /// Android delivers the alarm and the reminder sits in the notification
  /// shade (kept in the fake's shown list, which a cancel clears).
  void deliverPendingReminderToShade() {
    final alarm = fakePlugin.scheduledNotifications.singleWhere(
      (n) => n.id == reminderId,
    );
    deliverPendingReminder();
    fakePlugin.shownNotifications.add(
      FakeNotification(
        id: alarm.id,
        title: alarm.title,
        body: alarm.body,
        payload: alarm.payload,
      ),
    );
  }

  group('Income reminder on the due day (A91)', () {
    test(
      'opened at 10:30 on the due day before the 09:00 alarm arrived: '
      'the reminder is shown now and the next one is set for 3 Nov',
      () async {
        fakeNow = DateTime(2026, 9, 20, 10);
        await schedule();
        expect(pendingReminderDate(), DateTime(2026, 10, 3, 9));

        fakeNow = DateTime(2026, 10, 3, 10, 30);
        await schedule();

        final shown = shownReminders();
        expect(shown, hasLength(1));
        expect(
          shown.single.payload,
          NotificationPayload.incomeReminder(investmentId),
        );
        expect(shown.single.body, contains('P2P Monthly'));
        expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
      },
    );

    test('a second launch the same day does not show it twice', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();

      fakeNow = DateTime(2026, 10, 3, 10, 30);
      await schedule();
      fakeNow = DateTime(2026, 10, 3, 10, 45);
      await schedule();
      fakeNow = DateTime(2026, 10, 3, 23, 59);
      await schedule();

      expect(shownReminders(), hasLength(1));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('already delivered by Android: nothing is shown and the next one is '
        'set for 3 Nov', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();
      deliverPendingReminder();

      fakeNow = DateTime(2026, 10, 3, 10, 30);
      await schedule();

      expect(shownReminders(), isEmpty);
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('app not opened since the September payout: the October one was '
        'never scheduled, so it is shown on the due day', () async {
      fakeNow = DateTime(2026, 8, 20, 10);
      // Anchored on 3 Aug: due 3 Sep, then 3 Oct.
      await service.scheduleIncomeReminder(
        investmentId: investmentId,
        investmentName: 'P2P Monthly',
        monthsBetweenPayments: 1,
        lastIncomeDate: DateTime(2026, 8, 3),
      );
      expect(pendingReminderDate(), DateTime(2026, 9, 3, 9));
      deliverPendingReminder();

      fakeNow = DateTime(2026, 10, 3, 10, 30);
      await service.scheduleIncomeReminder(
        investmentId: investmentId,
        investmentName: 'P2P Monthly',
        monthsBetweenPayments: 1,
        lastIncomeDate: DateTime(2026, 8, 3),
      );

      expect(shownReminders(), hasLength(1));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test(
      'at 08:59 on the due day the reminder is scheduled for 09:00',
      () async {
        fakeNow = DateTime(2026, 10, 3, 8, 59);
        await schedule();

        expect(shownReminders(), isEmpty);
        expect(pendingReminderDate(), DateTime(2026, 10, 3, 9));
      },
    );

    test('at exactly 09:00:00.000 nothing is scheduled in the past and the '
        'reminder is not lost', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();

      fakeNow = DateTime(2026, 10, 3, 9);
      await schedule();

      expect(shownReminders(), hasLength(1));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('the day after the due day the reminder moves on', () async {
      fakeNow = DateTime(2026, 10, 4, 8);
      await schedule();

      expect(shownReminders(), isEmpty);
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('with income reminders off nothing is shown or scheduled', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();
      await service.setIncomeRemindersEnabled(false);

      fakeNow = DateTime(2026, 10, 3, 10, 30);
      await schedule();

      expect(shownReminders(), isEmpty);
      expect(
        fakePlugin.scheduledNotifications.where((n) => n.id == reminderId),
        isEmpty,
      );
    });

    test('without notification permission nothing is shown, and the next '
        'reminder is still set', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();
      fakePlugin.permissionsGranted = false;

      fakeNow = DateTime(2026, 10, 3, 10, 30);
      await schedule();

      expect(shownReminders(), isEmpty);
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('cancelling the reminder (investment closed or removed) forgets '
        'its due date', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();
      final key = NotificationPrefsKeys.incomeReminderDue(investmentId);
      expect(prefs.getString(key), '2026-10-03');

      await service.cancelIncomeReminder(investmentId);

      expect(prefs.containsKey(key), isFalse);
    });

    test('a reminder delivered at 09:05 stays in the shade when the app '
        'opens at 10:30 and again at 15:00', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();

      fakeNow = DateTime(2026, 10, 3, 9, 5);
      deliverPendingReminderToShade();

      fakeNow = DateTime(2026, 10, 3, 10, 30);
      await schedule();
      fakeNow = DateTime(2026, 10, 3, 15);
      await schedule();

      expect(shownReminders(), hasLength(1));
      expect(fakePlugin.cancelledNotificationIds, isNot(contains(reminderId)));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('the reminder shown at 10:30 stays in the shade through later '
        'syncs that day (a cash-flow edit, another launch)', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();

      fakeNow = DateTime(2026, 10, 3, 10, 30);
      await schedule();
      expect(shownReminders(), hasLength(1));

      fakeNow = DateTime(2026, 10, 3, 10, 45);
      await schedule();
      fakeNow = DateTime(2026, 10, 3, 18);
      await schedule();

      expect(shownReminders(), hasLength(1));
      expect(fakePlugin.cancelledNotificationIds, isNot(contains(reminderId)));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('a clock read 5 ms before 09:00 never hands the plugin a time that '
        'has passed by the time it checks', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();

      // The plugin checks 10 ms after the handler read the clock.
      fakePlugin.now = () => fakeNow.add(const Duration(milliseconds: 10));
      fakeNow = DateTime(2026, 10, 3, 8, 59, 59, 995);
      await schedule();

      expect(shownReminders(), hasLength(1));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('signing out and back in on the due day, before the 09:00 alarm '
        'arrived, still shows the reminder', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();

      fakeNow = DateTime(2026, 10, 3, 10);
      await service.cancelAll();

      fakeNow = DateTime(2026, 10, 3, 12);
      await schedule();

      expect(shownReminders(), hasLength(1));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('signing out and back in after the reminder was delivered does not '
        'show it again', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();
      fakeNow = DateTime(2026, 10, 3, 9, 5);
      deliverPendingReminderToShade();

      fakeNow = DateTime(2026, 10, 3, 10);
      await service.cancelAll();

      fakeNow = DateTime(2026, 10, 3, 12);
      await schedule();

      expect(shownReminders(), isEmpty);
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('signing out before the due day and back in on it after 09:00 shows '
        'the reminder', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();
      await service.cancelAll();

      fakeNow = DateTime(2026, 10, 3, 12);
      await schedule();

      expect(shownReminders(), hasLength(1));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('reminders dropped because the investment list was briefly empty '
        'are still shown on the due day', () async {
      fakeNow = DateTime(2026, 9, 20, 10);
      await schedule();

      fakeNow = DateTime(2026, 10, 3, 10);
      await service.cancelInvestmentReminders();

      fakeNow = DateTime(2026, 10, 3, 12);
      await schedule();

      expect(shownReminders(), hasLength(1));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });

    test('the launch reschedule shows the due reminder too', () async {
      final investment = InvestmentEntity(
        id: investmentId,
        name: 'P2P Monthly',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        startDate: DateTime(2026, 1, 3),
        incomeFrequency: IncomeFrequency.monthly,
      );
      final lastIncomeDates = {investmentId: anchor};

      fakeNow = DateTime(2026, 9, 20, 10);
      await service.rescheduleAllNotifications([
        investment,
      ], lastIncomeDates: lastIncomeDates);
      expect(pendingReminderDate(), DateTime(2026, 10, 3, 9));

      fakeNow = DateTime(2026, 10, 3, 10, 30);
      await service.rescheduleAllNotifications([
        investment,
      ], lastIncomeDates: lastIncomeDates);

      expect(shownReminders(), hasLength(1));
      expect(pendingReminderDate(), DateTime(2026, 11, 3, 9));
    });
  });
}
