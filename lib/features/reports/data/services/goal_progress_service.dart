/// Goal Progress Report Service
///
/// Generates goal progress reports by analyzing all goals and their current
/// status relative to deadlines and expected progress
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/reports/domain/entities/goal_progress_report.dart' hide GoalStatus;

/// Provider for goal progress service
final goalProgressServiceProvider = Provider<GoalProgressService>((ref) {
  return GoalProgressService();
});

class GoalProgressService {
  /// Generate goal progress report
  GoalProgressReport generateReport({
    required List<GoalEntity> allGoals,
    required Map<String, GoalProgress> progressMap,
  }) {
    final goalsWithProgress = <GoalWithProgress>[];
    final onTrack = <GoalWithProgress>[];
    final atRisk = <GoalWithProgress>[];
    final achieved = <GoalWithProgress>[];
    final stale = <GoalWithProgress>[];

    double totalTarget = 0;
    double totalCurrent = 0;
    double totalProgress = 0;

    for (final goal in allGoals) {
      final progress = progressMap[goal.id];
      if (progress == null) continue;

      // Use status from GoalProgress entity
      final status = progress.status;

      final goalWithProgress = GoalWithProgress(
        goal: goal,
        progress: progress,
        status: status,
      );

      goalsWithProgress.add(goalWithProgress);

      // Categorize by status
      switch (status) {
        case GoalStatus.onTrack:
        case GoalStatus.ahead:
          onTrack.add(goalWithProgress);
          break;
        case GoalStatus.behind:
          atRisk.add(goalWithProgress);
          break;
        case GoalStatus.achieved:
          achieved.add(goalWithProgress);
          break;
        case GoalStatus.notStarted:
        case GoalStatus.archived:
          stale.add(goalWithProgress);
          break;
      }

      // Accumulate totals
      totalTarget += goal.targetAmount;
      totalCurrent += progress.currentAmount;
      totalProgress += progress.progressPercent;
    }

    final avgProgress = goalsWithProgress.isEmpty
        ? 0.0
        : totalProgress / goalsWithProgress.length;

    return GoalProgressReport(
      allGoals: goalsWithProgress,
      onTrackGoals: onTrack,
      atRiskGoals: atRisk,
      achievedGoals: achieved,
      staleGoals: stale,
      averageProgress: avgProgress,
      totalTargetAmount: totalTarget,
      totalCurrentAmount: totalCurrent,
      generatedAt: DateTime.now(),
    );
  }
}
