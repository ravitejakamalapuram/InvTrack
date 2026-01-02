import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Mock implementation of GoalRepository for testing.
class MockGoalRepository extends Mock implements GoalRepository {}

/// Fake implementation of GoalRepository for integration tests.
class FakeGoalRepository implements GoalRepository {
  final List<GoalEntity> _goals = [];
  final List<GoalEntity> _archivedGoals = [];

  /// Access active goals for test assertions
  List<GoalEntity> get goals => List.unmodifiable(_goals);

  /// Access archived goals for test assertions
  List<GoalEntity> get archivedGoals => List.unmodifiable(_archivedGoals);

  /// Reset state between tests
  void reset() {
    _goals.clear();
    _archivedGoals.clear();
  }

  /// Seed with test data
  void seed({
    List<GoalEntity>? goals,
    List<GoalEntity>? archivedGoals,
  }) {
    if (goals != null) _goals.addAll(goals);
    if (archivedGoals != null) _archivedGoals.addAll(archivedGoals);
  }

  // ============ ACTIVE GOALS ============

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
    return _goals.cast<GoalEntity?>().firstWhere(
          (g) => g?.id == id,
          orElse: () => _archivedGoals.cast<GoalEntity?>().firstWhere(
                (g) => g?.id == id,
                orElse: () => null,
              ),
        );
  }

  @override
  Stream<GoalEntity?> watchGoalById(String id) {
    return Stream.value(
      _goals.cast<GoalEntity?>().firstWhere(
            (g) => g?.id == id,
            orElse: () => _archivedGoals.cast<GoalEntity?>().firstWhere(
                  (g) => g?.id == id,
                  orElse: () => null,
                ),
          ),
    );
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
      final goal = _goals.removeAt(index);
      _archivedGoals.add(goal.copyWith(isArchived: true));
    }
  }

  @override
  Future<void> unarchiveGoal(String id) async {
    final index = _archivedGoals.indexWhere((g) => g.id == id);
    if (index >= 0) {
      final goal = _archivedGoals.removeAt(index);
      _goals.add(goal.copyWith(isArchived: false));
    }
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
  }

  @override
  Future<List<GoalEntity>> getGoalsForInvestment(String investmentId) async {
    return _goals
        .where((g) => g.linkedInvestmentIds.contains(investmentId))
        .toList();
  }

  // ============ ARCHIVED GOALS ============

  @override
  Stream<List<GoalEntity>> watchArchivedGoals() {
    return Stream.value(List.from(_archivedGoals));
  }

  @override
  Future<GoalEntity?> getArchivedGoalById(String id) async {
    return _archivedGoals.cast<GoalEntity?>().firstWhere(
          (g) => g?.id == id,
          orElse: () => null,
        );
  }

  @override
  Future<void> deleteArchivedGoal(String id) async {
    _archivedGoals.removeWhere((g) => g.id == id);
  }
}

