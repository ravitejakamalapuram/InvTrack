// A29 (#780) part 3: routine nudges (summaries, milestones, onboarding tips)
// post at default importance, not maximum, and the day-14 tip no longer
// claims "thousands of investors".
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../mocks/mock_notification_service.dart';

void main() {
  late FakeFlutterLocalNotificationsPlugin plugin;
  late NotificationService service;

  setUp(() async {
    tz_data.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    plugin = FakeFlutterLocalNotificationsPlugin();
    service = NotificationService(
      plugin,
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 10, 2, 10),
    );
    await service.initialize();
    service.reportsRouteEnabled = true;
  });

  void expectDefaultImportance(NotificationDetails? details) {
    final android = details!.android!;
    expect(android.importance, Importance.defaultImportance);
    expect(android.priority, Priority.defaultPriority);
  }

  test('weekly, monthly and FY summaries use default importance', () async {
    await service.scheduleWeeklySummary();
    await service.scheduleMonthlySummary();
    await service.scheduleFYSummary();

    expect(plugin.scheduledNotifications, hasLength(3));
    for (final n in plugin.scheduledNotifications) {
      expectDefaultImportance(n.notificationDetails);
    }
  });

  test('an investment milestone uses default importance', () async {
    await service.checkAndShowMilestone(
      investmentId: 'inv-1',
      investmentName: 'P2P',
      moic: 1.5,
      gain: 500,
    );
    expectDefaultImportance(
      plugin.shownNotifications.single.notificationDetails,
    );
  });

  test('a goal milestone uses default importance', () async {
    await service.checkAndShowGoalMilestone(
      goalId: 'goal-1',
      goalName: 'House',
      progressPercent: 50,
      currentValue: 25000,
      targetValue: 50000,
    );
    expectDefaultImportance(
      plugin.shownNotifications.single.notificationDetails,
    );
  });

  test('activation tips use default importance and make no unverified '
      'claim', () async {
    await service.setUserSignupDate(DateTime.now());
    await service.scheduleActivationSequence();

    expect(plugin.scheduledNotifications, isNotEmpty);
    for (final n in plugin.scheduledNotifications) {
      expectDefaultImportance(n.notificationDetails);
      expect(n.body, isNot(contains('Thousands')));
    }
    final day14 = plugin.scheduledNotifications.firstWhere(
      (n) => n.id == NotificationIds.activationDay14,
    );
    expect(day14.title, isNot(contains('Join Smart Investors')));
  });
}
