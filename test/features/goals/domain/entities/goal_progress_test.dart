import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';

void main() {
  group('GoalMilestone', () {
    test('forPercentage returns correct milestone', () {
      expect(GoalMilestone.forPercentage(0), GoalMilestone.start);
      expect(GoalMilestone.forPercentage(10), GoalMilestone.start);
      expect(GoalMilestone.forPercentage(25), GoalMilestone.quarter);
      expect(GoalMilestone.forPercentage(30), GoalMilestone.quarter);
      expect(GoalMilestone.forPercentage(50), GoalMilestone.half);
      expect(GoalMilestone.forPercentage(60), GoalMilestone.half);
      expect(GoalMilestone.forPercentage(75), GoalMilestone.threeQuarters);
      expect(GoalMilestone.forPercentage(80), GoalMilestone.threeQuarters);
      expect(GoalMilestone.forPercentage(90), GoalMilestone.ninety);
      expect(GoalMilestone.forPercentage(95), GoalMilestone.ninety);
      expect(GoalMilestone.forPercentage(100), GoalMilestone.complete);
      expect(GoalMilestone.forPercentage(150), GoalMilestone.complete);
    });

    test('achievedMilestones returns correct milestones', () {
      expect(GoalMilestone.achievedMilestones(0), isEmpty);
      expect(GoalMilestone.achievedMilestones(25), [GoalMilestone.quarter]);
      expect(GoalMilestone.achievedMilestones(50), [
        GoalMilestone.quarter,
        GoalMilestone.half,
      ]);
      expect(GoalMilestone.achievedMilestones(100), [
        GoalMilestone.quarter,
        GoalMilestone.half,
        GoalMilestone.threeQuarters,
        GoalMilestone.ninety,
        GoalMilestone.complete,
      ]);
    });

    test('displayName returns correct names', () {
      expect(GoalMilestone.start.displayName, 'Started');
      expect(GoalMilestone.quarter.displayName, '25% Complete');
      expect(GoalMilestone.half.displayName, 'Halfway There!');
      expect(GoalMilestone.complete.displayName, 'Goal Achieved! 🎉');
    });

    test('emoji returns correct emoji', () {
      expect(GoalMilestone.start.emoji, '🚀');
      expect(GoalMilestone.complete.emoji, '🏆');
    });
  });

  group('GoalProgress', () {
    final testGoal = GoalEntity(
      id: 'goal-1',
      name: 'Test Goal',
      type: GoalType.targetAmount,
      targetAmount: 10000,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: GoalColors.defaultColor.toARGB32(),
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    test('progressMessage shows correct format for amount goals', () {
      final progress = GoalProgress(
        goal: testGoal,
        currentAmount: 5000,
        progressPercent: 50,
        monthlyVelocity: 500,
        monthlyIncome: 0,
        projectedCompletionDate: DateTime(2025, 6, 1),
        status: GoalStatus.onTrack,
        currentMilestone: GoalMilestone.half,
        achievedMilestones: [GoalMilestone.quarter, GoalMilestone.half],
        linkedInvestmentCount: 5,
        calculatedAt: DateTime.now(),
      );

      // Uses K formatting (5.0K of 10.0K)
      expect(progress.progressMessage, contains('5.0K'));
      expect(progress.progressMessage, contains('10.0K'));
    });

    test('progressMessage shows correct format for income goals', () {
      final incomeGoal = testGoal.copyWith(
        type: GoalType.incomeTarget,
        targetMonthlyIncome: 1000,
      );

      final progress = GoalProgress(
        goal: incomeGoal,
        currentAmount: 0,
        progressPercent: 50,
        monthlyVelocity: 0,
        monthlyIncome: 500,
        projectedCompletionDate: null,
        status: GoalStatus.onTrack,
        currentMilestone: GoalMilestone.half,
        achievedMilestones: [GoalMilestone.quarter, GoalMilestone.half],
        linkedInvestmentCount: 3,
        calculatedAt: DateTime.now(),
      );

      expect(progress.progressMessage, contains('/mo'));
      expect(progress.progressMessage, contains('500'));
      expect(progress.progressMessage, contains('1.0K'));
    });

    test('statusMessage for ahead status shows encouragement', () {
      final progress = GoalProgress(
        goal: testGoal,
        currentAmount: 7500,
        progressPercent: 75,
        monthlyVelocity: 500,
        monthlyIncome: 0,
        projectedCompletionDate: DateTime(2025, 6, 1),
        status: GoalStatus.ahead,
        currentMilestone: GoalMilestone.threeQuarters,
        achievedMilestones: [
          GoalMilestone.quarter,
          GoalMilestone.half,
          GoalMilestone.threeQuarters,
        ],
        linkedInvestmentCount: 5,
        calculatedAt: DateTime.now(),
      );

      expect(progress.statusMessage.toLowerCase(), contains('ahead'));
      expect(progress.statusMessage.toLowerCase(), contains('keep'));
    });

    test('achieved status shows goal complete', () {
      final progress = GoalProgress(
        goal: testGoal,
        currentAmount: 10000,
        progressPercent: 100,
        monthlyVelocity: 500,
        monthlyIncome: 0,
        projectedCompletionDate: null,
        status: GoalStatus.achieved,
        currentMilestone: GoalMilestone.complete,
        achievedMilestones: GoalMilestone.values
            .where((m) => m.percentage > 0)
            .toList(),
        linkedInvestmentCount: 5,
        calculatedAt: DateTime.now(),
      );

      expect(progress.statusMessage.toLowerCase(), contains('achieved'));
    });
  });
}
