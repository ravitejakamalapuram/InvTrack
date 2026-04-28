/// Provider for Goal Progress Report
///
/// Generates goal progress analysis by fetching all goals and their current
/// progress status
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/reports/data/services/goal_progress_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/goal_progress_report.dart';

/// Provider for goal progress report
final goalProgressReportProvider =
    FutureProvider.autoDispose<GoalProgressReport>((ref) async {
  // Get all goals from stream
  final goalsStream = ref.watch(activeGoalsProvider);

  final goals = await goalsStream.when(
    data: (data) async => data,
    loading: () async => <GoalEntity>[],
    error: (e, st) => throw e,
  );

  // Get progress for each goal
  final progressMap = <String, GoalProgress>{};

  for (final goal in goals) {
    final progress = ref.read(goalProgressProvider(goal.id));

    if (progress != null) {
      progressMap[goal.id] = progress;
    }
  }

  // Generate report
  final service = ref.read(goalProgressServiceProvider);
  return service.generateReport(
    allGoals: goals,
    progressMap: progressMap,
  );
});
