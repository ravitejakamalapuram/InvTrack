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
}
