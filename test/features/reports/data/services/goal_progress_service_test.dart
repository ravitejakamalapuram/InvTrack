import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/reports/data/services/goal_progress_service.dart';

void main() {
  group('GoalProgressService', () {
    late GoalProgressService service;

    setUp(() {
      service = GoalProgressService();
    });

    test('should categorize goals by status', () {
      final now = DateTime.now();
      
      final onTrackGoal = GoalEntity(
        id: 'goal1',
        name: 'On Track Goal',
        type: GoalType.targetDate,
        targetAmount: 100000.0,
        targetDate: now.add(const Duration(days: 365)),
        trackingMode: GoalTrackingMode.all,
        icon: '🎯',
        colorValue: 0xFF4CAF50,
        createdAt: now,
        updatedAt: now,
      );

      final behindGoal = GoalEntity(
        id: 'goal2',
        name: 'Behind Goal',
        type: GoalType.targetDate,
        targetAmount: 50000.0,
        targetDate: now.add(const Duration(days: 180)),
        trackingMode: GoalTrackingMode.all,
        icon: '⚠️',
        colorValue: 0xFFFF9800,
        createdAt: now,
        updatedAt: now,
      );

      final progressMap = {
        'goal1': GoalProgress(
          goal: onTrackGoal,
          currentAmount: 60000.0,
          progressPercent: 60.0,
          monthlyVelocity: 5000.0,
          monthlyIncome: 0.0,
          status: GoalStatus.onTrack,
          currentMilestone: GoalMilestone.half,
          achievedMilestones: const [GoalMilestone.quarter, GoalMilestone.half],
          linkedInvestmentCount: 3,
          calculatedAt: now,
        ),
        'goal2': GoalProgress(
          goal: behindGoal,
          currentAmount: 10000.0,
          progressPercent: 20.0,
          monthlyVelocity: 1000.0,
          monthlyIncome: 0.0,
          status: GoalStatus.behind,
          currentMilestone: GoalMilestone.start,
          achievedMilestones: const [],
          linkedInvestmentCount: 1,
          calculatedAt: now,
        ),
      };

      final report = service.generateReport(
        allGoals: [onTrackGoal, behindGoal],
        progressMap: progressMap,
      );

      expect(report.onTrackGoals.length, 1);
      expect(report.atRiskGoals.length, 1);
      expect(report.onTrackGoals.first.goal.id, 'goal1');
      expect(report.atRiskGoals.first.goal.id, 'goal2');
    });

    test('should calculate aggregate stats correctly', () {
      final now = DateTime.now();
      
      final goals = List.generate(
        3,
        (i) => GoalEntity(
          id: 'goal$i',
          name: 'Goal $i',
          type: GoalType.targetAmount,
          targetAmount: 10000.0,
          trackingMode: GoalTrackingMode.all,
          icon: '🎯',
          colorValue: 0xFF4CAF50,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final progressMap = {
        'goal0': GoalProgress(
          goal: goals[0],
          currentAmount: 8000.0,
          progressPercent: 80.0,
          monthlyVelocity: 500.0,
          monthlyIncome: 0.0,
          status: GoalStatus.onTrack,
          currentMilestone: GoalMilestone.threeQuarters,
          achievedMilestones: const [],
          linkedInvestmentCount: 2,
          calculatedAt: now,
        ),
        'goal1': GoalProgress(
          goal: goals[1],
          currentAmount: 5000.0,
          progressPercent: 50.0,
          monthlyVelocity: 400.0,
          monthlyIncome: 0.0,
          status: GoalStatus.behind,
          currentMilestone: GoalMilestone.half,
          achievedMilestones: const [],
          linkedInvestmentCount: 1,
          calculatedAt: now,
        ),
        'goal2': GoalProgress(
          goal: goals[2],
          currentAmount: 3000.0,
          progressPercent: 30.0,
          monthlyVelocity: 300.0,
          monthlyIncome: 0.0,
          status: GoalStatus.behind,
          currentMilestone: GoalMilestone.quarter,
          achievedMilestones: const [],
          linkedInvestmentCount: 1,
          calculatedAt: now,
        ),
      };

      final report = service.generateReport(
        allGoals: goals,
        progressMap: progressMap,
      );

      expect(report.totalTargetAmount, 30000.0); // 3 * 10000
      expect(report.totalCurrentAmount, 16000.0); // 8000 + 5000 + 3000
      expect(report.overallProgress, closeTo(53.33, 0.01)); // 16000/30000 * 100
    });

    test('should handle empty data', () {
      final report = service.generateReport(
        allGoals: [],
        progressMap: {},
      );

      expect(report.allGoals, isEmpty);
      expect(report.onTrackGoals, isEmpty);
      expect(report.atRiskGoals, isEmpty);
      expect(report.achievedGoals, isEmpty);
      expect(report.totalTargetAmount, 0.0);
      expect(report.totalCurrentAmount, 0.0);
    });
  });
}
