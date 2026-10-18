import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/handlers/scheduled_notification_handler.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';

void main() {
  group('monthly recap notification text', () {
    final october = DateTime(2026, 10);

    test('states the counts for next month, never an amount', () {
      final text = ScheduledNotificationHandler.monthlyRecapText(
        month: october,
        maturingNextMonth: 1,
        needingValue: 2,
      );

      expect(text.title, 'Your October recap is ready');
      expect(
        text.body,
        '1 investment matures in November. 2 need a current value.',
      );
      expect(text.body, isNot(contains('₹')));
    });

    test('uses plural and singular forms', () {
      final text = ScheduledNotificationHandler.monthlyRecapText(
        month: october,
        maturingNextMonth: 3,
        needingValue: 1,
      );

      expect(
        text.body,
        '3 investments mature in November. 1 needs a current value.',
      );
    });

    test('falls back to a plain line when there is nothing to state', () {
      final text = ScheduledNotificationHandler.monthlyRecapText(
        month: DateTime(2026, 12),
        maturingNextMonth: 0,
        needingValue: 0,
      );

      expect(text.title, 'Your December recap is ready');
      expect(text.body, 'See what came in last month.');
    });
  });

  test('the recap payload opens the recap of its month', () {
    final payload = NotificationPayload.parse(
      NotificationPayload.monthlyRecap('2026-10'),
    );

    expect(payload.type, NotificationPayloadType.monthlyRecap);
    expect(payload.params['month'], '2026-10');
  });
}
