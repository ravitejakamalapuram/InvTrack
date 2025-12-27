import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';

/// Repository interface for Goals
///
/// Active and archived goals are stored in separate collections for complete isolation.
abstract class GoalRepository {
  // ============ ACTIVE GOALS ============

  /// Watch all active goals (reactive stream)
  Stream<List<GoalEntity>> watchAllGoals();

  /// Watch active (non-archived) goals - same as watchAllGoals since active collection only has active
  Stream<List<GoalEntity>> watchActiveGoals();

  /// Get all active goals
  Future<List<GoalEntity>> getAllGoals();

  /// Get goal by ID (searches active first, then archived)
  Future<GoalEntity?> getGoalById(String id);

  /// Watch a single goal by ID (reactive stream - searches both collections)
  Stream<GoalEntity?> watchGoalById(String id);

  /// Create a new goal
  Future<void> createGoal(GoalEntity goal);

  /// Update an existing goal
  Future<void> updateGoal(GoalEntity goal);

  /// Archive a goal (moves to archived collection)
  Future<void> archiveGoal(String id);

  /// Unarchive a goal (moves back to active collection)
  Future<void> unarchiveGoal(String id);

  /// Delete a goal permanently
  Future<void> deleteGoal(String id);

  /// Get active goals linked to a specific investment
  Future<List<GoalEntity>> getGoalsForInvestment(String investmentId);

  // ============ ARCHIVED GOALS ============

  /// Watch all archived goals (reactive stream)
  Stream<List<GoalEntity>> watchArchivedGoals();

  /// Get archived goal by ID
  Future<GoalEntity?> getArchivedGoalById(String id);

  /// Delete an archived goal permanently
  Future<void> deleteArchivedGoal(String id);
}

