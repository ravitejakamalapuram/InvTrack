// A29 (#780) part 3: income and maturity notification IDs never collide.
// They used to be `hashCode % 50000` / `% 25000`, so at 1,000 investments a
// collision (one reminder replacing or cancelling another) was near certain.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/mock_notification_service.dart';

void main() {
  late SharedPreferences prefs;

  Future<void> startApp() async {
    // Constructing the service is what the app does at start.
    NotificationService(FakeFlutterLocalNotificationsPlugin(), prefs);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await startApp();
  });

  final investmentIds = [for (var i = 0; i < 1000; i++) 'inv-$i'];

  test('1,000 investments get 1,000 different income IDs', () {
    final ids = investmentIds.map(NotificationIds.incomeReminder).toSet();
    expect(ids, hasLength(1000));
    expect(ids.every(NotificationIds.isIncomeReminderId), isTrue);
  });

  test('1,000 investments get 2,000 different maturity IDs', () {
    final ids = {
      for (final id in investmentIds) ...[
        NotificationIds.maturityReminder7Days(id),
        NotificationIds.maturityReminder1Day(id),
      ],
    };
    expect(ids, hasLength(2000));
    expect(ids.every(NotificationIds.isMaturityReminderId), isTrue);
  });

  test('an investment keeps its IDs across app restarts', () async {
    final a = [
      NotificationIds.incomeReminder('inv-a'),
      NotificationIds.maturityReminder7Days('inv-a'),
      NotificationIds.maturityReminder1Day('inv-a'),
    ];
    final b = NotificationIds.incomeReminder('inv-b');
    await startApp();

    // Asked in the opposite order: if the slots were not saved, inv-b would
    // be handed inv-a's old slot.
    expect(NotificationIds.incomeReminder('inv-b'), b);
    expect([
      NotificationIds.incomeReminder('inv-a'),
      NotificationIds.maturityReminder7Days('inv-a'),
      NotificationIds.maturityReminder1Day('inv-a'),
    ], a);
    expect(prefs.getString('notification_id_slots'), contains('inv-b'));
  });

  group('reminders scheduled under the old hash IDs', () {
    FakeScheduledNotification pending(int id) =>
        FakeScheduledNotification(id: id, scheduledDate: DateTime(2027));

    test('are cancelled once when the app first starts with slot IDs, '
        'so none can fire for a deleted investment', () async {
      final plugin = FakeFlutterLocalNotificationsPlugin();
      plugin.scheduledNotifications.addAll([
        pending(NotificationIds.weeklySummary),
        pending(50123), // income, old hash ID
        pending(100456), // 7-day maturity, old hash ID
        pending(125789), // 1-day maturity, old hash ID
      ]);
      final service = NotificationService(plugin, prefs);
      await service.initialize();

      expect(plugin.scheduledNotifications.map((n) => n.id), [
        NotificationIds.weeklySummary,
      ]);

      // Reminders scheduled after the migration are left alone on the next
      // start.
      plugin.scheduledNotifications.add(pending(50123));
      await NotificationService(plugin, prefs).initialize();
      expect(plugin.scheduledNotifications.map((n) => n.id), contains(50123));
    });
  });

  test('goal milestone IDs never reach the goal at-risk range', () {
    for (var i = 0; i < 2000; i++) {
      for (final percent in [25, 50, 75, 100]) {
        expect(
          NotificationIds.goalMilestone('goal-$i', percent),
          lessThan(240000), // goalAtRisk starts at 240000
        );
      }
    }
  });
}
