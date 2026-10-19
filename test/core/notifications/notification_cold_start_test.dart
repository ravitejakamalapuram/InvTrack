// A29 / PLAT-11: a tap that starts the app from a killed state must reach its
// route, and a weekly check-in tap must land on a real screen.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../mocks/mock_notification_service.dart';

NotificationAppLaunchDetails _launchedBy(String? payload) =>
    NotificationAppLaunchDetails(
      true,
      notificationResponse: NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      ),
    );

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
    takeBufferedNotificationNavigation();
  });

  group('cold-start tap', () {
    test('is queued for the app once it starts listening', () async {
      plugin.launchDetails = _launchedBy('maturity_reminder:inv-1:7');

      await service.initialize();

      expect(takeBufferedNotificationNavigation(), [
        'maturity_reminder:inv-1:7',
      ]);
      expect(takeBufferedNotificationNavigation(), isEmpty);
    });

    test('is not buffered when someone is already listening', () async {
      final seen = <String>[];
      final sub = pendingNavigationStream.listen(seen.add);
      addTearDown(sub.cancel);

      queueNotificationNavigation('goal_milestone:g-1:50');
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['goal_milestone:g-1:50']);
      expect(takeBufferedNotificationNavigation(), isEmpty);
    });

    test('a normal start queues nothing', () async {
      await service.initialize();

      expect(takeBufferedNotificationNavigation(), isEmpty);
    });

    test('a launch without a payload queues nothing', () async {
      plugin.launchDetails = _launchedBy(null);

      await service.initialize();

      expect(takeBufferedNotificationNavigation(), isEmpty);
    });
  });

  group('deliverNotificationTap', () {
    test('waits for the router, then hands over the payload once', () async {
      var ready = false;
      final handled = <String>[];
      final done = deliverNotificationTap(
        'p',
        isReady: () => ready,
        handle: (p) async {
          handled.add(p);
          return true;
        },
        pollEvery: const Duration(milliseconds: 5),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(handled, isEmpty);

      ready = true;
      expect(await done, isTrue);
      expect(handled, ['p']);
    });

    test('hands over right away when already ready', () async {
      final handled = <String>[];
      await deliverNotificationTap(
        'p',
        isReady: () => true,
        handle: (p) async {
          handled.add(p);
          return true;
        },
      );
      expect(handled, ['p']);
    });

    test('tries once after the poll limit when never ready', () async {
      final handled = <String>[];
      await deliverNotificationTap(
        'p',
        isReady: () => false,
        handle: (p) async {
          handled.add(p);
          return false;
        },
        pollEvery: const Duration(milliseconds: 1),
        maxPolls: 3,
      );
      expect(handled, ['p']);
    });
  });

  test('weekly check-in tap opens the investment list', () {
    final parsed = NotificationPayload.parse(NotificationPayload.weeklyCheckIn);

    expect(parsed.type, NotificationPayloadType.investmentList);
  });
}
