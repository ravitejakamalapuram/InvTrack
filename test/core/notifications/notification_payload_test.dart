import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_payload.dart';

void main() {
  group('NotificationPayload - Parsing', () {
    test('should parse null payload as unknown', () {
      final payload = NotificationPayload.parse(null);

      expect(payload.type, NotificationPayloadType.unknown);
      expect(payload.investmentId, isNull);
    });

    test('should parse empty payload as unknown', () {
      final payload = NotificationPayload.parse('');

      expect(payload.type, NotificationPayloadType.unknown);
    });

    test('should parse income_reminder with investment ID', () {
      final payload = NotificationPayload.parse('income_reminder:inv-456');

      expect(payload.type, NotificationPayloadType.incomeReport);
      expect(payload.investmentId, 'inv-456');
      expect(payload.params['flowType'], 'income');
    });

    test('should parse maturity_reminder with investment ID and days', () {
      final payload = NotificationPayload.parse('maturity_reminder:inv-789:7');

      expect(payload.type, NotificationPayloadType.maturityReport);
      expect(payload.investmentId, 'inv-789');
      expect(payload.params['daysToMaturity'], '7');
    });

    test('should parse maturity_reminder with 1 day', () {
      final payload = NotificationPayload.parse('maturity_reminder:inv-abc:1');

      expect(payload.type, NotificationPayloadType.maturityReport);
      expect(payload.investmentId, 'inv-abc');
      expect(payload.params['daysToMaturity'], '1');
    });

    test('should parse weekly_summary as weeklySummaryReport', () {
      final payload = NotificationPayload.parse('weekly_summary');

      expect(payload.type, NotificationPayloadType.weeklySummaryReport);
      expect(payload.investmentId, isNull);
    });

    test('should parse monthly_summary as monthlySummaryReport', () {
      final payload = NotificationPayload.parse('monthly_summary');

      expect(payload.type, NotificationPayloadType.monthlySummaryReport);
    });

    test('should parse test_notification as unknown', () {
      final payload = NotificationPayload.parse('test_notification');

      expect(payload.type, NotificationPayloadType.unknown);
    });

    test('should parse test_scheduled_notification as unknown', () {
      final payload = NotificationPayload.parse('test_scheduled_notification');

      expect(payload.type, NotificationPayloadType.unknown);
    });
  });

  group('NotificationPayload - Factory Methods', () {
    test('incomeReminder should create correct payload string', () {
      final payload = NotificationPayload.incomeReminder('test-id');

      expect(payload, 'income_reminder:test-id');
    });

    test('maturityReminder should create correct payload string with days', () {
      final payload7 = NotificationPayload.maturityReminder('test-id', 7);
      final payload1 = NotificationPayload.maturityReminder('test-id', 1);

      expect(payload7, 'maturity_reminder:test-id:7');
      expect(payload1, 'maturity_reminder:test-id:1');
    });

    test('weeklySummary should return correct string', () {
      expect(NotificationPayload.weeklySummary, 'weekly_summary');
    });

    test('monthlySummary should return correct string', () {
      expect(NotificationPayload.monthlySummary, 'monthly_summary');
    });
  });

  group('NotificationPayload - Round Trip', () {
    test('should round-trip income_reminder payload', () {
      final payloadString = NotificationPayload.incomeReminder('reminder-id');
      final parsed = NotificationPayload.parse(payloadString);

      expect(parsed.type, NotificationPayloadType.incomeReport);
      expect(parsed.investmentId, 'reminder-id');
    });

    test('should round-trip maturity_reminder payload', () {
      final payloadString = NotificationPayload.maturityReminder(
        'maturity-id',
        7,
      );
      final parsed = NotificationPayload.parse(payloadString);

      expect(parsed.type, NotificationPayloadType.maturityReport);
      expect(parsed.investmentId, 'maturity-id');
      expect(parsed.params['daysToMaturity'], '7');
    });
  });

  group('NotificationPayload - toString', () {
    test('should provide readable string representation', () {
      final payload = NotificationPayload.parse('income_reminder:test-id');

      expect(payload.toString(), contains('incomeReport'));
      expect(payload.toString(), contains('test-id'));
    });
  });

  group('NotificationActionIds', () {
    test('should have correct action IDs for income reminders', () {
      expect(NotificationActionIds.recordIncome, 'record_income');
      expect(NotificationActionIds.snoozeOneDay, 'snooze_1day');
      expect(NotificationActionIds.viewDetails, 'view_details');
    });

    test('should have correct action IDs for maturity reminders', () {
      expect(NotificationActionIds.viewMaturity, 'view_maturity');
      expect(NotificationActionIds.markComplete, 'mark_complete');
    });
  });

  group('NotificationPayload - Phase 2 Types', () {
    test('milestone should create correct payload string', () {
      final payload = NotificationPayload.milestone('inv-123', 1.5);
      expect(payload, 'milestone:inv-123:1.5');
    });

    test('should parse milestone payload correctly', () {
      final parsed = NotificationPayload.parse('milestone:inv-123:2.0');

      expect(parsed.type, NotificationPayloadType.milestoneReport);
      expect(parsed.investmentId, 'inv-123');
      expect(parsed.params['milestonePercent'], '2.0');
    });

    test('taxReminder should create correct payload string', () {
      final payload = NotificationPayload.taxReminder('80c');
      expect(payload, 'tax_reminder:80c');
    });

    test('should parse tax_reminder payload correctly', () {
      final parsed = NotificationPayload.parse('tax_reminder:advance_q1');

      expect(parsed.type, NotificationPayloadType.overview);
    });

    test('riskAlert should create correct payload string', () {
      final payload = NotificationPayload.riskAlert('single_investment');
      expect(payload, 'risk_alert:single_investment');
    });

    test('should parse risk_alert payload correctly', () {
      final parsed = NotificationPayload.parse('risk_alert:concentration');

      expect(parsed.type, NotificationPayloadType.overview);
      expect(parsed.params['alertType'], 'concentration');
    });

    test('weeklyCheckIn should create correct payload string', () {
      expect(NotificationPayload.weeklyCheckIn, 'weekly_check_in');
    });

    test('should parse weekly_check_in payload correctly', () {
      final parsed = NotificationPayload.parse('weekly_check_in');

      expect(parsed.type, NotificationPayloadType.addCashFlow);
      expect(parsed.params['source'], 'weekly_check_in');
    });

    test('idleAlert should create correct payload string', () {
      final payload = NotificationPayload.idleAlert('inv-123');
      expect(payload, 'idle_alert:inv-123');
    });

    test('should parse idle_alert payload correctly', () {
      final parsed = NotificationPayload.parse('idle_alert:inv-456');

      expect(parsed.type, NotificationPayloadType.investmentDetail);
      expect(parsed.investmentId, 'inv-456');
      expect(parsed.params['source'], 'idle_alert');
    });

    test('fySummary should create correct payload string', () {
      expect(NotificationPayload.fySummary, 'fy_summary');
    });

    test('should parse fy_summary payload correctly', () {
      final parsed = NotificationPayload.parse('fy_summary');

      expect(parsed.type, NotificationPayloadType.fySummaryReport);
    });

    test('goalMilestone should create correct payload string', () {
      final payload = NotificationPayload.goalMilestone('goal-123', 50);
      expect(payload, 'goal_milestone:goal-123:50');
    });

    test('should parse goal_milestone payload correctly', () {
      final parsed = NotificationPayload.parse('goal_milestone:goal-456:75');

      expect(parsed.type, NotificationPayloadType.goalMilestoneReport);
      expect(parsed.goalId, 'goal-456');
      expect(parsed.params['milestonePercent'], '75');
    });

    test('should parse goal_milestone with 100% correctly', () {
      final parsed = NotificationPayload.parse('goal_milestone:goal-789:100');

      expect(parsed.type, NotificationPayloadType.goalMilestoneReport);
      expect(parsed.goalId, 'goal-789');
      expect(parsed.params['milestonePercent'], '100');
    });

    test('goal_milestone should round-trip correctly', () {
      final payloadString = NotificationPayload.goalMilestone('test-goal', 25);
      final parsed = NotificationPayload.parse(payloadString);

      expect(parsed.type, NotificationPayloadType.goalMilestoneReport);
      expect(parsed.goalId, 'test-goal');
      expect(parsed.params['milestonePercent'], '25');
    });
  });
}
