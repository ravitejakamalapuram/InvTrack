/// Provider for Goal Progress Report
///
/// Generates goal progress analysis by fetching all goals and their current
/// progress status
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/reports/data/services/goal_progress_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/goal_progress_report.dart';

/// Provider for goal progress report, from the same converted goal progress
/// the Goals screen shows (money rules 2 and 3). It stays loading, or fails,
/// with its sources rather than report no goals.
final goalProgressReportProvider =
    FutureProvider.autoDispose<GoalProgressReport>((ref) async {
      final progressList = await ref.watch(
        multiCurrencyAllGoalsProgressProvider.future,
      );

      final service = ref.read(goalProgressServiceProvider);
      return service.generateReport(
        allGoals: [for (final progress in progressList) progress.goal],
        progressMap: {
          for (final progress in progressList) progress.goal.id: progress,
        },
      );
    });
