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
    final before = [
      NotificationIds.incomeReminder('inv-a'),
      NotificationIds.maturityReminder7Days('inv-a'),
      NotificationIds.maturityReminder1Day('inv-a'),
    ];
    NotificationIds.incomeReminder('inv-b'); // allocated in between
    await startApp();
    expect([
      NotificationIds.incomeReminder('inv-a'),
      NotificationIds.maturityReminder7Days('inv-a'),
      NotificationIds.maturityReminder1Day('inv-a'),
    ], before);
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
