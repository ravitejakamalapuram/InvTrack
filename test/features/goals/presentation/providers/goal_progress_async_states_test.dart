/// A28 / GAP1-08: the multi-currency goal progress providers must keep the
/// real loading and error states of their sources. Turning them into empty
/// lists made goals show '0%' and 'Not Started' on cold start and on errors.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart';

final _loadError = Exception('permission-denied');

final _goal = GoalEntity(
  id: 'goal-1',
  name: 'House',
  type: GoalType.targetAmount,
  targetAmount: 150000,
  currency: 'INR',
  trackingMode: GoalTrackingMode.all,
  icon: 'home',
  colorValue: 0xFF2196F3,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _investment = InvestmentEntity(
  id: 'inv-1',
  name: 'FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ProviderContainer _container({
  Stream<GoalEntity?> Function()? goal,
  Stream<List<GoalEntity>> Function()? goals,
  required Stream<List<InvestmentEntity>> Function() investments,
  required Stream<List<CashFlowEntity>> Function() cashFlows,
}) {
  final container = ProviderContainer(
    overrides: [
      watchGoalByIdProvider(
        _goal.id,
      ).overrideWith((ref) => goal?.call() ?? Stream.value(_goal)),
      activeGoalsProvider.overrideWith(
        (ref) => goals?.call() ?? Stream.value([_goal]),
      ),
      allInvestmentsProvider.overrideWith((ref) => investments()),
      allCashFlowsStreamProvider.overrideWith((ref) => cashFlows()),
      // No converter: the providers then resolve to zero progress, which is
      // what a swallowed loading or error state used to look like.
      batchCurrencyConverterProvider.overrideWithValue(null),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

Future<AsyncValue<Object?>> _settle(
  ProviderContainer container,
  ProviderListenable<AsyncValue<Object?>> provider,
) async {
  final sub = container.listen(provider, (_, _) {});
  await pumpEventQueue();
  return sub.read();
}

void main() {
  final providers = <String, ProviderListenable<AsyncValue<Object?>>>{
    'multiCurrencyGoalProgressProvider': multiCurrencyGoalProgressProvider(
      _goal.id,
    ),
    'multiCurrencyAllGoalsProgressProvider':
        multiCurrencyAllGoalsProgressProvider,
  };

  for (final entry in providers.entries) {
    group(entry.key, () {
      test('stays loading while the goal is loading', () async {
        final goalStream = StreamController<GoalEntity?>();
        final goalsStream = StreamController<List<GoalEntity>>();
        addTearDown(() => unawaited(goalStream.close()));
        addTearDown(() => unawaited(goalsStream.close()));
        final container = _container(
          goal: () => goalStream.stream,
          goals: () => goalsStream.stream,
          investments: () => Stream.value([_investment]),
          cashFlows: () => Stream.value(const []),
        );

        final state = await _settle(container, entry.value);

        expect(state.isLoading, isTrue);
        expect(state.hasValue, isFalse);
      });

      test('stays loading while cash flows are loading', () async {
        final cashFlows = StreamController<List<CashFlowEntity>>();
        addTearDown(() => unawaited(cashFlows.close()));
        final container = _container(
          investments: () => Stream.value([_investment]),
          cashFlows: () => cashFlows.stream,
        );

        final state = await _settle(container, entry.value);

        expect(state.isLoading, isTrue);
        expect(state.hasValue, isFalse);
      });

      test('reports the error when cash flows fail to load', () async {
        final container = _container(
          investments: () => Stream.value([_investment]),
          cashFlows: () => Stream.error(_loadError),
        );

        final state = await _settle(container, entry.value);

        expect(state.hasError, isTrue);
        expect(state.hasValue, isFalse);
        expect(state.error.toString(), contains('permission-denied'));
      });

      test('reports the error when the goal fails to load', () async {
        final container = _container(
          goal: () => Stream.error(_loadError),
          goals: () => Stream.error(_loadError),
          investments: () => Stream.value([_investment]),
          cashFlows: () => Stream.value(const []),
        );

        final state = await _settle(container, entry.value);

        expect(state.hasError, isTrue);
        expect(state.hasValue, isFalse);
      });
    });
  }
}
