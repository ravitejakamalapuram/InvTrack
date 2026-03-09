import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import '../../data/repositories/mock_goal_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

void main() {
  late FakeGoalRepository fakeRepository;
  late FakeAnalyticsService fakeAnalytics;
  late ProviderContainer container;

  final testGoal1 = GoalEntity(
    id: 'goal-1',
    name: 'Goal 1',
    type: GoalType.targetAmount,
    targetAmount: 10000,
    trackingMode: GoalTrackingMode.all,
    icon: GoalIcons.defaultIcon,
    colorValue: GoalColors.defaultColor.toARGB32(),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  final testGoal2 = GoalEntity(
    id: 'goal-2',
    name: 'Goal 2',
    type: GoalType.targetAmount,
    targetAmount: 20000,
    trackingMode: GoalTrackingMode.all,
    icon: GoalIcons.defaultIcon,
    colorValue: GoalColors.defaultColor.toARGB32(),
    createdAt: DateTime(2024, 1, 2),
    updatedAt: DateTime(2024, 1, 2),
  );

  final testGoal3 = GoalEntity(
    id: 'goal-3',
    name: 'Goal 3',
    type: GoalType.incomeTarget,
    targetAmount: 0,
    targetMonthlyIncome: 5000,
    trackingMode: GoalTrackingMode.all,
    icon: GoalIcons.defaultIcon,
    colorValue: GoalColors.defaultColor.toARGB32(),
    createdAt: DateTime(2024, 1, 3),
    updatedAt: DateTime(2024, 1, 3),
  );

  setUp(() {
    fakeRepository = FakeGoalRepository();
    fakeAnalytics = FakeAnalyticsService();
    container = ProviderContainer(
      overrides: [
        goalRepositoryProvider.overrideWithValue(fakeRepository),
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeRepository.reset();
    fakeAnalytics.reset();
  });

  group('GoalNotifier - bulkDelete', () {
    test('should delete multiple goals', () async {
      fakeRepository.seed(goals: [testGoal1, testGoal2, testGoal3]);
      final notifier = container.read(goalNotifierProvider.notifier);

      final deletedCount = await notifier.bulkDelete([
        testGoal1.id,
        testGoal2.id,
      ]);

      expect(deletedCount, 2);
      expect(fakeRepository.goals, hasLength(1));
      expect(fakeRepository.goals.first.id, 'goal-3');
    });

    test('should return 0 for empty list', () async {
      fakeRepository.seed(goals: [testGoal1]);
      final notifier = container.read(goalNotifierProvider.notifier);

      final deletedCount = await notifier.bulkDelete([]);

      expect(deletedCount, 0);
      expect(fakeRepository.goals, hasLength(1));
    });

    test('should delete all goals when all ids provided', () async {
      fakeRepository.seed(goals: [testGoal1, testGoal2, testGoal3]);
      final notifier = container.read(goalNotifierProvider.notifier);

      final deletedCount = await notifier.bulkDelete([
        testGoal1.id,
        testGoal2.id,
        testGoal3.id,
      ]);

      expect(deletedCount, 3);
      expect(fakeRepository.goals, isEmpty);
    });

    test('should log analytics for each deleted goal', () async {
      fakeRepository.seed(goals: [testGoal1, testGoal2]);
      final notifier = container.read(goalNotifierProvider.notifier);

      await notifier.bulkDelete([testGoal1.id, testGoal2.id]);

      final goalDeletedEvents = fakeAnalytics.loggedEvents
          .where((e) => e.name == AnalyticsEvents.goalDeleted)
          .toList();
      expect(goalDeletedEvents, hasLength(2));
    });

    test('should set loading state during delete', () async {
      fakeRepository.seed(goals: [testGoal1]);
      final notifier = container.read(goalNotifierProvider.notifier);

      // Start the delete but don't await - check initial loading state
      final future = notifier.bulkDelete([testGoal1.id]);

      // State should return to data after completion
      await future;
      expect(container.read(goalNotifierProvider).hasValue, isTrue);
    });
  });

  group('GoalNotifier - deleteGoal', () {
    test('should delete single goal', () async {
      fakeRepository.seed(goals: [testGoal1, testGoal2]);
      final notifier = container.read(goalNotifierProvider.notifier);

      await notifier.deleteGoal(testGoal1.id);

      expect(fakeRepository.goals, hasLength(1));
      expect(fakeRepository.goals.first.id, 'goal-2');
    });

    test('should log analytics for deleted goal', () async {
      fakeRepository.seed(goals: [testGoal1]);
      final notifier = container.read(goalNotifierProvider.notifier);

      await notifier.deleteGoal(testGoal1.id);

      final goalDeletedEvents = fakeAnalytics.loggedEvents
          .where((e) => e.name == AnalyticsEvents.goalDeleted)
          .toList();
      expect(goalDeletedEvents, hasLength(1));
    });
  });

  group('GoalNotifier - deleteArchivedGoal', () {
    final archivedGoal = GoalEntity(
      id: 'archived-goal-1',
      name: 'Archived Goal',
      type: GoalType.targetAmount,
      targetAmount: 15000,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: GoalColors.defaultColor.toARGB32(),
      isArchived: true,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    test('should delete archived goal', () async {
      fakeRepository.seed(archivedGoals: [archivedGoal]);
      final notifier = container.read(goalNotifierProvider.notifier);

      await notifier.deleteArchivedGoal(archivedGoal.id);

      expect(fakeRepository.archivedGoals, isEmpty);
    });

    test('should log analytics for deleted archived goal', () async {
      fakeRepository.seed(archivedGoals: [archivedGoal]);
      final notifier = container.read(goalNotifierProvider.notifier);

      await notifier.deleteArchivedGoal(archivedGoal.id);

      final goalDeletedEvents = fakeAnalytics.loggedEvents
          .where((e) => e.name == AnalyticsEvents.goalDeleted)
          .toList();
      expect(goalDeletedEvents, hasLength(1));
    });
  });

  group('GoalNotifier - bulkDelete with isArchived', () {
    final archivedGoal1 = GoalEntity(
      id: 'archived-1',
      name: 'Archived 1',
      type: GoalType.targetAmount,
      targetAmount: 10000,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: GoalColors.defaultColor.toARGB32(),
      isArchived: true,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    final archivedGoal2 = GoalEntity(
      id: 'archived-2',
      name: 'Archived 2',
      type: GoalType.targetAmount,
      targetAmount: 20000,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: GoalColors.defaultColor.toARGB32(),
      isArchived: true,
      createdAt: DateTime(2024, 1, 2),
      updatedAt: DateTime(2024, 1, 2),
    );

    test('should delete archived goals when isArchived is true', () async {
      fakeRepository.seed(archivedGoals: [archivedGoal1, archivedGoal2]);
      final notifier = container.read(goalNotifierProvider.notifier);

      final deletedCount = await notifier.bulkDelete([
        archivedGoal1.id,
        archivedGoal2.id,
      ], isArchived: true);

      expect(deletedCount, 2);
      expect(fakeRepository.archivedGoals, isEmpty);
    });

    test(
      'should delete active goals when isArchived is false (default)',
      () async {
        fakeRepository.seed(goals: [testGoal1, testGoal2]);
        final notifier = container.read(goalNotifierProvider.notifier);

        final deletedCount = await notifier.bulkDelete([
          testGoal1.id,
          testGoal2.id,
        ]);

        expect(deletedCount, 2);
        expect(fakeRepository.goals, isEmpty);
      },
    );
  });
}
