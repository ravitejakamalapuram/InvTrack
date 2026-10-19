import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inv_tracker/core/notifications/notification_constants.dart';
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

  group('keeping a due recap', () {
    const recap = PendingNotificationRequest(
      NotificationIds.monthlySummary,
      'title',
      'body',
      'monthly_recap:2026-09',
    );
    const legacy = PendingNotificationRequest(
      NotificationIds.monthlySummary,
      'title',
      'body',
      'monthly_summary',
    );

    test('keeps last month\'s recap all day on the 1st, even after 10:00', () {
      for (final hour in [8, 10, 15]) {
        expect(
          ScheduledNotificationHandler.shouldKeepDueRecap(
            DateTime(2026, 10, 1, hour),
            [recap],
          ),
          isTrue,
          reason: 'hour $hour: an inexact alarm may not have fired yet',
        );
      }
    });

    test('replaces it on any other day', () {
      expect(
        ScheduledNotificationHandler.shouldKeepDueRecap(
          DateTime(2026, 10, 2, 8),
          [recap],
        ),
        isFalse,
      );
    });

    test('replaces a recap that is not the one due today', () {
      const thisMonths = PendingNotificationRequest(
        NotificationIds.monthlySummary,
        'title',
        'body',
        'monthly_recap:2026-10',
      );
      expect(
        ScheduledNotificationHandler.shouldKeepDueRecap(
          DateTime(2026, 10, 1, 8),
          [thisMonths],
        ),
        isFalse,
      );
    });

    test('is not fooled by the year boundary', () {
      const december = PendingNotificationRequest(
        NotificationIds.monthlySummary,
        'title',
        'body',
        'monthly_recap:2026-12',
      );
      expect(
        ScheduledNotificationHandler.shouldKeepDueRecap(
          DateTime(2027, 1, 1, 12),
          [december],
        ),
        isTrue,
      );
    });

    test('replaces a pending legacy summary or nothing', () {
      final early = DateTime(2026, 10, 1, 8);
      expect(
        ScheduledNotificationHandler.shouldKeepDueRecap(early, [legacy]),
        isFalse,
      );
      expect(
        ScheduledNotificationHandler.shouldKeepDueRecap(early, []),
        isFalse,
      );
    });
  });
}
