import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';

import 'mock_notification_service.dart';

GoalEntity _makeGoal({
  String id = 'mock-goal-1',
  String name = 'Mock Goal',
  List<int> milestones = const [],
}) {
  return GoalEntity(
    id: id,
    name: name,
    type: GoalType.targetAmount,
    targetAmount: 100000,
    trackingMode: GoalTrackingMode.all,
    icon: GoalIcons.defaultIcon,
    colorValue: GoalColors.defaultColor.toARGB32(),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    notificationMilestonesSent: milestones,
  );
}

void main() {
  late FakeNotificationService fakeService;

  setUp(() {
    fakeService = FakeNotificationService();
  });

  tearDown(() {
    fakeService.reset();
  });

  group('FakeNotificationService.checkAndShowGoalMilestone', () {
    test('records goal id in shownGoalMilestones', () async {
      final goal = _makeGoal(id: 'test-goal-id');

      await fakeService.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakeService.shownGoalMilestones, contains('test-goal-id'));
    });

    test('returns the same goal object unchanged', () async {
      final goal = _makeGoal();

      final result = await fakeService.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(result, same(goal));
    });

    test('records goal id from goal.id property (not a separate parameter)', () async {
      final goal = _makeGoal(id: 'goal-from-entity');

      await fakeService.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 75,
        currentValue: 75000,
        targetValue: 100000,
      );

      expect(fakeService.shownGoalMilestones, equals(['goal-from-entity']));
    });

    test('accumulates multiple goal ids across calls', () async {
      final goal1 = _makeGoal(id: 'goal-A');
      final goal2 = _makeGoal(id: 'goal-B');

      await fakeService.checkAndShowGoalMilestone(
        goal: goal1,
        progressPercent: 25,
        currentValue: 25000,
        targetValue: 100000,
      );
      await fakeService.checkAndShowGoalMilestone(
        goal: goal2,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );

      expect(fakeService.shownGoalMilestones, containsAll(['goal-A', 'goal-B']));
      expect(fakeService.shownGoalMilestones.length, 2);
    });

    test('same goal id recorded multiple times for repeated calls', () async {
      final goal = _makeGoal(id: 'repeated-goal');

      await fakeService.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );
      await fakeService.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 75,
        currentValue: 75000,
        targetValue: 100000,
      );

      expect(fakeService.shownGoalMilestones.length, 2);
      expect(
        fakeService.shownGoalMilestones.where((id) => id == 'repeated-goal').length,
        2,
      );
    });

    test('returned goal has same notificationMilestonesSent as input', () async {
      final goal = _makeGoal(milestones: [25, 50]);

      final result = await fakeService.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 75,
        currentValue: 75000,
        targetValue: 100000,
      );

      final resultGoal = result as GoalEntity;
      expect(resultGoal.notificationMilestonesSent, equals([25, 50]));
    });
  });

  group('FakeNotificationService.reset', () {
    test('clears shownGoalMilestones', () async {
      final goal = _makeGoal(id: 'goal-to-clear');
      await fakeService.checkAndShowGoalMilestone(
        goal: goal,
        progressPercent: 50,
        currentValue: 50000,
        targetValue: 100000,
      );
      expect(fakeService.shownGoalMilestones, isNotEmpty);

      fakeService.reset();

      expect(fakeService.shownGoalMilestones, isEmpty);
    });

    test('clears all tracking lists on reset', () async {
      fakeService.shownGoalMilestones.add('before-reset');
      fakeService.shownMilestones.add('milestone-before');

      fakeService.reset();

      expect(fakeService.shownGoalMilestones, isEmpty);
      expect(fakeService.shownMilestones, isEmpty);
    });
  });
}