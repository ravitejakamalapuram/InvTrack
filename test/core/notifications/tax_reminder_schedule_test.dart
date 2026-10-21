// A29 (#780) part 2: the India tax reminders fall on their fixed dates no
// matter which day the app was opened.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../mocks/mock_notification_service.dart';

void main() {
  late FakeFlutterLocalNotificationsPlugin plugin;

  setUp(() {
    tz_data.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    plugin = FakeFlutterLocalNotificationsPlugin();
  });

  Future<Map<int, DateTime>> scheduleAt(DateTime now) async {
    final service = NotificationService(
      plugin,
      await SharedPreferences.getInstance(),
      clock: () => now,
    );
    await service.initialize();
    service.baseCurrency = 'INR';
    await service.scheduleTaxReminders();
    return {
      for (final n in plugin.scheduledNotifications)
        n.id: DateTime.fromMillisecondsSinceEpoch(
          n.scheduledDate.millisecondsSinceEpoch,
        ),
    };
  }

  // Each deadline reminder fires at 09:00 on its next occurrence after now.
  final cases = <String, (DateTime, Map<int, DateTime>)>{
    'Jun 5 (before the Q1 reminder)': (
      DateTime(2026, 6, 5, 12),
      {
        NotificationIds.taxReminder80C: DateTime(2027, 3, 24, 9),
        NotificationIds.taxReminderAdvanceQ1: DateTime(2026, 6, 10, 9),
        NotificationIds.taxReminderAdvanceQ2: DateTime(2026, 9, 10, 9),
        NotificationIds.taxReminderAdvanceQ3: DateTime(2026, 12, 10, 9),
        NotificationIds.taxReminderAdvanceQ4: DateTime(2027, 3, 10, 9),
        NotificationIds.taxReminderITR: DateTime(2026, 7, 25, 9),
      },
    ),
    'Apr 2 (after the Q4 reminder)': (
      DateTime(2026, 4, 2, 12),
      {
        NotificationIds.taxReminder80C: DateTime(2027, 3, 24, 9),
        NotificationIds.taxReminderAdvanceQ1: DateTime(2026, 6, 10, 9),
        NotificationIds.taxReminderAdvanceQ2: DateTime(2026, 9, 10, 9),
        NotificationIds.taxReminderAdvanceQ3: DateTime(2026, 12, 10, 9),
        NotificationIds.taxReminderAdvanceQ4: DateTime(2027, 3, 10, 9),
        NotificationIds.taxReminderITR: DateTime(2026, 7, 25, 9),
      },
    ),
    'Jul 28 (after the ITR reminder)': (
      DateTime(2026, 7, 28, 12),
      {
        NotificationIds.taxReminder80C: DateTime(2027, 3, 24, 9),
        NotificationIds.taxReminderAdvanceQ1: DateTime(2027, 6, 10, 9),
        NotificationIds.taxReminderAdvanceQ2: DateTime(2026, 9, 10, 9),
        NotificationIds.taxReminderAdvanceQ3: DateTime(2026, 12, 10, 9),
        NotificationIds.taxReminderAdvanceQ4: DateTime(2027, 3, 10, 9),
        NotificationIds.taxReminderITR: DateTime(2027, 7, 25, 9),
      },
    ),
  };

  for (final entry in cases.entries) {
    test(
      'opened on ${entry.key}, every reminder is on its next date',
      () async {
        expect(await scheduleAt(entry.value.$1), entry.value.$2);
      },
    );
  }

  test('a user whose base currency is not INR gets no India tax reminders, '
      'and ones already scheduled are removed', () async {
    final service = NotificationService(
      plugin,
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 6, 5, 12),
    );
    await service.initialize();
    service.baseCurrency = 'INR';
    await service.scheduleTaxReminders();
    expect(plugin.scheduledNotifications, hasLength(6));

    service.baseCurrency = 'USD';
    await service.scheduleTaxReminders();
    expect(plugin.scheduledNotifications, isEmpty);
  });

  test(
    'no tax reminders are scheduled until the base currency is known',
    () async {
      final service = NotificationService(
        plugin,
        await SharedPreferences.getInstance(),
        clock: () => DateTime(2026, 6, 5, 12),
      );
      await service.initialize();
      await service.scheduleTaxReminders();
      expect(plugin.scheduledNotifications, isEmpty);
    },
  );
}
