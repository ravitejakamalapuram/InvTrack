// A70 (#835): maturity reminders fire 7 days and 1 day before the maturity
// day, at 09:00 on the device. A maturity date saved in another time zone
// used to read as the day before, so both reminders fired a day early.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../mocks/mock_notification_service.dart';

void main() {
  late FakeFlutterLocalNotificationsPlugin plugin;
  late NotificationService service;
  late tz.Location newYork;

  setUpAll(() {
    tz_data.initializeTimeZones();
    newYork = tz.getLocation('America/New_York');
  });

  setUp(() async {
    plugin = FakeFlutterLocalNotificationsPlugin();
    SharedPreferences.setMockInitialValues({});
    service = NotificationService(
      plugin,
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 2, 1, 12),
    );
  });

  DateTime readMaturityInNewYork(Timestamp saved) =>
      FirestoreInvestmentRepository.investmentFromFirestore(
        {
          'name': 'SBI FD',
          'type': 'fixedDeposit',
          'status': 'OPEN',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2, 4, 12)),
          'maturityDate': saved,
          'currency': 'INR',
        },
        'inv-fd',
        baseCurrency: 'INR',
        offsetAt: (instant) =>
            newYork.timeZone(instant.millisecondsSinceEpoch).offset,
      ).maturityDate!;

  /// Fire times on this device's clock.
  Map<int, DateTime> fireTimes() => {
    for (final n in plugin.scheduledNotifications)
      n.id: DateTime.fromMillisecondsSinceEpoch(
        n.scheduledDate.millisecondsSinceEpoch,
      ),
  };

  test('a maturity of 10 Oct 2026 saved in India reminds on 3 Oct and 9 Oct '
      'at 09:00 on a device in New York', () async {
    final saved = Timestamp.fromDate(
      tz.TZDateTime(tz.getLocation('Asia/Kolkata'), 2026, 10, 10).toUtc(),
    );

    await service.scheduleMaturityReminders(
      investmentId: 'inv-fd',
      investmentName: 'SBI FD',
      maturityDate: readMaturityInNewYork(saved),
    );

    expect(fireTimes(), {
      NotificationIds.maturityReminder7Days('inv-fd'): DateTime(2026, 10, 3, 9),
      NotificationIds.maturityReminder1Day('inv-fd'): DateTime(2026, 10, 9, 9),
    });
  });

  test('the reminder days do not move when a DST change falls in the '
      'week before maturity', () async {
    // US clocks go forward on 8 Mar 2026. Subtracting 7 x 24 hours from a
    // local midnight on 10 Mar lands on 2 Mar 23:00 on a device in New York.
    // The handler takes the device's own DateTime, so this test can only
    // fail on a machine whose zone changes clocks that week: run it with
    // TZ=America/New_York. On a UTC machine (CI) it passes either way.
    await service.scheduleMaturityReminders(
      investmentId: 'inv-fd',
      investmentName: 'SBI FD',
      maturityDate: DateTime(2026, 3, 10),
    );

    expect(fireTimes(), {
      NotificationIds.maturityReminder7Days('inv-fd'): DateTime(2026, 3, 3, 9),
      NotificationIds.maturityReminder1Day('inv-fd'): DateTime(2026, 3, 9, 9),
    });
  });
}
