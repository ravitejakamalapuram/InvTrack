// Follow-up to #996: a goal target amount gets the same 15-digit cap as every
// other amount. The notifier refuses a target of 16 digits or more, also one
// that rounds up to 16 digits in the goal's currency, and writes nothing.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';

import '../../data/repositories/mock_goal_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

const _tooLarge = <double>[1e15, 1e20];

/// The largest amount of 15 digits.
const _largest = 999999999999999.0;

/// 15 digits as typed; JPY has no minor units, so it rounds to 1e15.
const _roundsUp = 999999999999999.5;

final _saved = GoalEntity(
  id: 'goal-1',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 500000,
  trackingMode: GoalTrackingMode.all,
  icon: GoalIcons.defaultIcon,
  colorValue: GoalColors.defaultColor.toARGB32(),
  createdAt: DateTime(2026, 1, 15),
  updatedAt: DateTime(2026, 1, 15),
  currency: 'JPY',
);

void main() {
  late FakeGoalRepository repository;
  late FakeAnalyticsService analytics;
  late ProviderContainer container;

  setUp(() {
    repository = FakeGoalRepository();
    analytics = FakeAnalyticsService();
    container = ProviderContainer(
      overrides: [
        goalRepositoryProvider.overrideWithValue(repository),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
  });

  tearDown(() => container.dispose());

  GoalNotifier notifier() => container.read(goalNotifierProvider.notifier);

  Future<String> create(double target) => notifier().createGoal(
    name: 'House',
    type: GoalType.targetAmount,
    targetAmount: target,
    trackingMode: GoalTrackingMode.all,
    currency: 'JPY',
  );

  group('createGoal', () {
    for (final bad in [..._tooLarge, _roundsUp]) {
      test('$bad is refused, and nothing is written or logged', () async {
        await expectLater(
          create(bad),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.userMessage,
              'userMessage',
              'Amount is too large.',
            ),
          ),
        );
        expect(repository.goals, isEmpty);
        expect(analytics.loggedEvents, isEmpty);
      });
    }

    for (final bad in [-1.0, -1e16, double.nan, double.infinity]) {
      test('$bad is refused, and nothing is written', () async {
        await expectLater(create(bad), throwsA(isA<ValidationException>()));
        expect(repository.goals, isEmpty);
      });
    }

    test('zero is accepted: an income goal has no target amount', () async {
      await create(0);
      expect(repository.goals.single.targetAmount, 0);
    });

    test('the largest 15-digit amount is accepted', () async {
      await create(_largest);
      expect(repository.goals.single.targetAmount, _largest);
    });
  });

  group('updateGoal', () {
    setUp(() => repository.seed(goals: [_saved]));

    for (final bad in [..._tooLarge, _roundsUp]) {
      test('$bad is refused, and the saved goal is untouched', () async {
        await expectLater(
          notifier().updateGoal(_saved.copyWith(targetAmount: bad)),
          throwsA(isA<ValidationException>()),
        );
        expect(repository.goals.single.targetAmount, 500000);
        expect(analytics.loggedEvents, isEmpty);
      });
    }

    test(
      'a negative target is refused, and the saved goal is untouched',
      () async {
        await expectLater(
          notifier().updateGoal(_saved.copyWith(targetAmount: -1e16)),
          throwsA(isA<ValidationException>()),
        );
        expect(repository.goals.single.targetAmount, 500000);
      },
    );

    test('an archived goal is refused the same way', () async {
      final archived = _saved.copyWith(isArchived: true);
      repository.seed(archivedGoals: [archived]);
      await expectLater(
        notifier().updateGoal(archived.copyWith(targetAmount: _roundsUp)),
        throwsA(isA<ValidationException>()),
      );
      expect(repository.archivedGoals.single.targetAmount, 500000);
    });

    test('the largest 15-digit amount is accepted', () async {
      await notifier().updateGoal(_saved.copyWith(targetAmount: _largest));
      expect(repository.goals.single.targetAmount, _largest);
    });
  });
}
