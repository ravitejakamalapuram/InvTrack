import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';

/// Repository interface for Goals
abstract class GoalRepository {
  /// Watch all goals (reactive stream)
  Stream<List<GoalEntity>> watchAllGoals();

  /// Watch active (non-archived) goals
  Stream<List<GoalEntity>> watchActiveGoals();

  /// Get all goals
  Future<List<GoalEntity>> getAllGoals();

  /// Get goal by ID
  Future<GoalEntity?> getGoalById(String id);

  /// Watch a single goal by ID (reactive stream)
  Stream<GoalEntity?> watchGoalById(String id);

  /// Create a new goal
  Future<void> createGoal(GoalEntity goal);

  /// Update an existing goal
  Future<void> updateGoal(GoalEntity goal);

  /// Archive a goal
  Future<void> archiveGoal(String id);

  /// Unarchive a goal
  Future<void> unarchiveGoal(String id);

  /// Delete a goal permanently
  Future<void> deleteGoal(String id);

  /// Get goals linked to a specific investment
  Future<List<GoalEntity>> getGoalsForInvestment(String investmentId);
}

