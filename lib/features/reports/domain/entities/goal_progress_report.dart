/// Goal Progress Report Entity
///
/// Tracks status of all financial goals including:
/// - Goals on track vs at risk
/// - Progress towards each goal
/// - Required monthly contributions
library;

import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';

// Re-export GoalStatus to avoid ambiguity
export 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart' show GoalStatus;

/// Goal progress report
class GoalProgressReport {
  /// All goals with their current progress
  final List<GoalWithProgress> allGoals;

  /// Goals that are on track (progress >= expected)
  final List<GoalWithProgress> onTrackGoals;

  /// Goals that are at risk (progress < expected)
  final List<GoalWithProgress> atRiskGoals;

  /// Goals that are completed (progress >= 100%)
  final List<GoalWithProgress> achievedGoals;

  /// Goals that are stale (no activity for 90+ days)
  final List<GoalWithProgress> staleGoals;

  /// Average progress across all goals
  final double averageProgress;

  /// Total target amount across all goals
  final double totalTargetAmount;

  /// Total current amount across all goals
  final double totalCurrentAmount;

  /// Report generation timestamp
  final DateTime generatedAt;

  const GoalProgressReport({
    required this.allGoals,
    required this.onTrackGoals,
    required this.atRiskGoals,
    required this.achievedGoals,
    required this.staleGoals,
    required this.averageProgress,
    required this.totalTargetAmount,
    required this.totalCurrentAmount,
    required this.generatedAt,
  });

  /// Total number of goals
  int get totalGoals => allGoals.length;

  /// Percentage of goals on track
  double get onTrackPercentage {
    if (totalGoals == 0) return 0;
    return (onTrackGoals.length / totalGoals) * 100;
  }

  /// Overall portfolio progress
  double get overallProgress {
    if (totalTargetAmount == 0) return 0;
    return (totalCurrentAmount / totalTargetAmount) * 100;
  }
}

/// Goal with its current progress details
class GoalWithProgress {
  final GoalEntity goal;
  final GoalProgress progress;
  final GoalStatus status;

  const GoalWithProgress({
    required this.goal,
    required this.progress,
    required this.status,
  });

  /// Returns true if goal is on track
  bool get isOnTrack => status == GoalStatus.onTrack;

  /// Returns true if goal is at risk (behind schedule)
  bool get isAtRisk => status == GoalStatus.behind;

  /// Returns true if goal is achieved
  bool get isAchieved => status == GoalStatus.achieved;

  /// Returns true if goal is archived
  bool get isArchived => status == GoalStatus.archived;
}
