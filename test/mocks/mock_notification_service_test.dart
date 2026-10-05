// The notification fakes report a goal milestone as shown only when the real
// service would show one. A silent check (announce: false) records the
// milestone in production but shows nothing, so the fakes must not list it.
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/mocks/mock_notification_service.dart'
    as integration;
import 'mock_notification_service.dart' as unit;

void main() {
  group('goal milestone fakes', () {
    Future<void> check(
      Future<void> Function({
        required String goalId,
        required String goalName,
        required double progressPercent,
        required double currentValue,
        required double targetValue,
        String currency,
        bool announce,
      })
      checkAndShow, {
      required bool announce,
    }) => checkAndShow(
      goalId: 'goal-1',
      goalName: 'House',
      progressPercent: 30,
      currentValue: 300000,
      targetValue: 1000000,
      announce: announce,
    );

    test('the unit-test fake shows nothing for a silent check', () async {
      final fake = unit.FakeNotificationService();

      await check(fake.checkAndShowGoalMilestone, announce: false);
      expect(fake.shownGoalMilestones, isEmpty);

      await check(fake.checkAndShowGoalMilestone, announce: true);
      expect(fake.shownGoalMilestones, ['goal-1']);
    });

    test(
      'the integration-test fake shows nothing for a silent check',
      () async {
        final fake = integration.FakeNotificationService();

        await check(fake.checkAndShowGoalMilestone, announce: false);
        expect(fake.shownNotifications, isEmpty);

        await check(fake.checkAndShowGoalMilestone, announce: true);
        expect(fake.shownNotifications, ['goal_milestone_goal-1']);
      },
    );
  });
}
