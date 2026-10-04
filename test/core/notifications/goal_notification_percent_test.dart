// A12 (#756): one rounding rule for goal % everywhere. A goal at 99.6% has
// not been reached, so no screen or notification may call it 100%.
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
    plugin = FakeFlutterLocalNotificationsPlugin();
    SharedPreferences.setMockInitialValues({});
    service = NotificationService(
      plugin,
      await SharedPreferences.getInstance(),
    );
  });

  test('the at-risk alert shows 99.6% as 99%, like the goal screens', () async {
    await service.showGoalAtRiskNotification(
      goalId: 'goal',
      goalName: 'House',
      progressPercent: 99.6,
      targetDate: DateTime.now().add(const Duration(days: 30)),
      projectedDate: DateTime.now().add(const Duration(days: 90)),
    );

    expect(plugin.shownNotifications.single.body, contains('is 99% complete'));
  });

  // GAP3-07: milestones must never be announced backwards.
  Future<void> check(double percent, {bool firstCheck = false}) =>
      service.checkAndShowGoalMilestone(
        goalId: 'goal',
        goalName: 'House',
        progressPercent: percent,
        currentValue: percent * 10000,
        targetValue: 1000000,
        firstCheck: firstCheck,
      );

  test('after Goal Achieved, the lower milestones are not announced', () async {
    for (var i = 0; i < 4; i++) {
      await check(100);
    }

    expect(plugin.shownNotifications, hasLength(1));
    expect(plugin.shownNotifications.single.title, contains('Achieved'));
  });

  test('a goal first checked at 98% announces only reaching 100%', () async {
    // The milestones it had passed before it was first checked (here after
    // an update that measures goals differently) are recorded, not
    // announced.
    await check(98, firstCheck: true);
    await check(98.5);
    await check(99);
    await check(100);

    expect(plugin.shownNotifications, hasLength(1));
    expect(plugin.shownNotifications.single.title, contains('Achieved'));
  });

  test('a milestone crossed after the first check is announced', () async {
    await check(20, firstCheck: true);
    await check(26);

    expect(plugin.shownNotifications, hasLength(1));
    expect(plugin.shownNotifications.single.title, contains('25%'));
  });
}
