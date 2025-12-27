import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Mock implementation of GoalRepository for testing.
class MockGoalRepository extends Mock implements GoalRepository {}

/// Fake implementation of GoalRepository for testing.
/// Maintains in-memory state for integration-style tests.
class FakeGoalRepository implements GoalRepository {
  final List<GoalEntity> _goals = [];

  /// Access goals for test assertions
  List<GoalEntity> get goals => List.unmodifiable(_goals);

  /// Reset state between tests
  void reset() {
    _goals.clear();
  }

  /// Seed with test data
  void seed(List<GoalEntity> goals) {
    _goals.addAll(goals);
  }

  @override
  Stream<List<GoalEntity>> watchAllGoals() {
    return Stream.value(List.from(_goals));
  }

  @override
  Stream<List<GoalEntity>> watchActiveGoals() {
    return Stream.value(_goals.where((g) => !g.isArchived).toList());
  }

  @override
  Future<List<GoalEntity>> getAllGoals() async {
    return List.from(_goals);
  }

  @override
  Future<GoalEntity?> getGoalById(String id) async {
    try {
      return _goals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<GoalEntity?> watchGoalById(String id) {
    try {
      final goal = _goals.firstWhere((g) => g.id == id);
      return Stream.value(goal);
    } catch (_) {
      return Stream.value(null);
    }
  }

  @override
  Future<void> createGoal(GoalEntity goal) async {
    _goals.add(goal);
  }

  @override
  Future<void> updateGoal(GoalEntity goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index >= 0) {
      _goals[index] = goal;
    }
  }

  @override
  Future<void> archiveGoal(String id) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index >= 0) {
      _goals[index] = _goals[index].copyWith(isArchived: true);
    }
  }

  @override
  Future<void> unarchiveGoal(String id) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index >= 0) {
      _goals[index] = _goals[index].copyWith(isArchived: false);
    }
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
  }

  @override
  Future<List<GoalEntity>> getGoalsForInvestment(String investmentId) async {
    return _goals.where((g) => g.linkedInvestmentIds.contains(investmentId)).toList();
  }
}

