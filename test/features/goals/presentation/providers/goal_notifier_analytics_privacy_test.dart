// #980 (rule 7): goal_updated, goal_archived and goal_deleted used to send the
// goal's id. Ids must not reach Analytics, so the events carry no parameters.
// Checked on the real AnalyticsService against a mocked Firebase, so what the
// plugin would receive is what is asserted.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/analytics_privacy.dart';
import '../../data/repositories/mock_goal_repository.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late FakeGoalRepository repository;
  late ProviderContainer container;
  final sent = <({String name, Map<String, Object>? parameters})>[];

  GoalEntity goal(String id) => GoalEntity(
    id: id,
    name: 'House fund $id',
    type: GoalType.targetAmount,
    targetAmount: 10000,
    trackingMode: GoalTrackingMode.all,
    icon: GoalIcons.defaultIcon,
    colorValue: GoalColors.defaultColor.toARGB32(),
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    sent.clear();
    final firebase = _MockFirebaseAnalytics();
    when(
      () => firebase.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((call) async {
      sent.add((
        name: call.namedArguments[#name] as String,
        parameters: call.namedArguments[#parameters] as Map<String, Object>?,
      ));
    });
    repository = FakeGoalRepository();
    container = ProviderContainer(
      overrides: [
        goalRepositoryProvider.overrideWithValue(repository),
        analyticsServiceProvider.overrideWithValue(
          AnalyticsService(analytics: firebase),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  GoalNotifier notifier() => container.read(goalNotifierProvider.notifier);

  /// The goal events were logged without waiting, so let them land.
  Future<void> expectOnly(String eventName, {required int count}) async {
    await pumpEventQueue();
    expect(sent.map((e) => e.name), List.filled(count, eventName));
    for (final event in sent) {
      expectPrivacySafe(event);
      expect(event.parameters, anyOf(isNull, isEmpty), reason: event.name);
    }
  }

  test('updating a goal logs goal_updated without its id', () async {
    repository.seed(goals: [goal('goal-1')]);

    await notifier().updateGoal(goal('goal-1'));

    await expectOnly('goal_updated', count: 1);
  });

  test('updating an archived goal logs goal_updated without its id', () async {
    repository.seed(archivedGoals: [goal('goal-1').copyWith(isArchived: true)]);

    await notifier().updateGoal(goal('goal-1').copyWith(isArchived: true));

    await expectOnly('goal_updated', count: 1);
  });

  test('archiving a goal logs goal_archived without its id', () async {
    repository.seed(goals: [goal('goal-1')]);

    await notifier().archiveGoal('goal-1');

    await expectOnly('goal_archived', count: 1);
  });

  test('deleting a goal logs goal_deleted without its id', () async {
    repository.seed(goals: [goal('goal-1')]);

    await notifier().deleteGoal('goal-1');

    await expectOnly('goal_deleted', count: 1);
  });

  test('deleting an archived goal logs goal_deleted without its id', () async {
    repository.seed(archivedGoals: [goal('goal-1').copyWith(isArchived: true)]);

    await notifier().deleteArchivedGoal('goal-1');

    await expectOnly('goal_deleted', count: 1);
  });

  test('bulk deleting logs one goal_deleted per goal, without ids', () async {
    repository.seed(goals: [goal('goal-1'), goal('goal-2')]);

    await notifier().bulkDelete(['goal-1', 'goal-2']);

    await expectOnly('goal_deleted', count: 2);
  });
}
