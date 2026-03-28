import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'mock_goal_repository.dart';

void main() {
  late FakeGoalRepository repository;

  setUp(() {
    repository = FakeGoalRepository();
  });

  tearDown(() {
    repository.reset();
  });

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

  group('FakeGoalRepository - Basic CRUD', () {
    test('createGoal adds goal to repository', () async {
      await repository.createGoal(testGoal);

      expect(repository.goals, hasLength(1));
      expect(repository.goals.first.id, 'goal-1');
      expect(repository.goals.first.name, 'Test Goal');
    });

    test('getAllGoals returns all goals', () async {
      await repository.createGoal(testGoal);
      await repository.createGoal(
        testGoal.copyWith(id: 'goal-2', name: 'Second'),
      );

      final goals = await repository.getAllGoals();

      expect(goals, hasLength(2));
    });

    test('getGoalById returns correct goal', () async {
      await repository.createGoal(testGoal);

      final result = await repository.getGoalById('goal-1');

      expect(result, isNotNull);
      expect(result!.name, 'Test Goal');
    });

    test('getGoalById returns null for non-existent id', () async {
      final result = await repository.getGoalById('non-existent');

      expect(result, isNull);
    });

    test('updateGoal modifies existing goal', () async {
      await repository.createGoal(testGoal);
      final updated = testGoal.copyWith(name: 'Updated Goal');

      await repository.updateGoal(updated);

      expect(repository.goals.first.name, 'Updated Goal');
    });

    test('deleteGoal removes goal', () async {
      await repository.createGoal(testGoal);

      await repository.deleteGoal('goal-1');

      expect(repository.goals, isEmpty);
    });
  });

  group('FakeGoalRepository - Archive/Unarchive', () {
    test('archiveGoal moves goal to archived collection', () async {
      await repository.createGoal(testGoal);

      await repository.archiveGoal('goal-1');

      // Goal should be removed from active goals
      expect(repository.goals, isEmpty);
      // Goal should be in archived goals with isArchived = true
      expect(repository.archivedGoals, hasLength(1));
      expect(repository.archivedGoals.first.isArchived, isTrue);
    });

    test('unarchiveGoal moves goal back to active collection', () async {
      // Seed with an archived goal
      repository.seed(archivedGoals: [testGoal.copyWith(isArchived: true)]);

      await repository.unarchiveGoal('goal-1');

      // Goal should be in active goals with isArchived = false
      expect(repository.goals, hasLength(1));
      expect(repository.goals.first.isArchived, isFalse);
      // Goal should be removed from archived goals
      expect(repository.archivedGoals, isEmpty);
    });
  });

  group('FakeGoalRepository - Streams', () {
    test('watchAllGoals returns stream with active goals only', () async {
      await repository.createGoal(testGoal);
      await repository.createGoal(testGoal.copyWith(id: 'goal-2'));

      final goals = await repository.watchAllGoals().first;

      expect(goals, hasLength(2));
    });

    test('watchActiveGoals returns only active goals', () async {
      await repository.createGoal(testGoal);
      await repository.createGoal(testGoal.copyWith(id: 'goal-2'));
      // Archive one goal
      await repository.archiveGoal('goal-2');

      final activeGoals = await repository.watchActiveGoals().first;

      expect(activeGoals, hasLength(1));
      expect(activeGoals.first.id, 'goal-1');
    });

    test('watchArchivedGoals returns only archived goals', () async {
      await repository.createGoal(testGoal);
      await repository.createGoal(testGoal.copyWith(id: 'goal-2'));
      // Archive one goal
      await repository.archiveGoal('goal-2');

      final archivedGoals = await repository.watchArchivedGoals().first;

      expect(archivedGoals, hasLength(1));
      expect(archivedGoals.first.id, 'goal-2');
      expect(archivedGoals.first.isArchived, isTrue);
    });

    test('watchGoalById returns stream for specific goal', () async {
      await repository.createGoal(testGoal);

      final goal = await repository.watchGoalById('goal-1').first;

      expect(goal, isNotNull);
      expect(goal!.name, 'Test Goal');
    });

    test('watchGoalById returns null for non-existent goal', () async {
      final goal = await repository.watchGoalById('non-existent').first;

      expect(goal, isNull);
    });
  });

  group('FakeGoalRepository - Linked Investments', () {
    test('getGoalsForInvestment returns goals linked to investment', () async {
      await repository.createGoal(
        testGoal.copyWith(linkedInvestmentIds: ['inv-1']),
      );
      await repository.createGoal(
        testGoal.copyWith(id: 'goal-2', linkedInvestmentIds: ['inv-2']),
      );

      final linkedGoals = await repository.getGoalsForInvestment('inv-1');

      expect(linkedGoals, hasLength(1));
      expect(linkedGoals.first.id, 'goal-1');
    });
  });
}
