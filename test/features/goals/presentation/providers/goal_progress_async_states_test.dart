/// A28 / GAP1-08: the multi-currency goal progress providers must keep the
/// real loading and error states of their sources. Turning them into empty
/// lists made goals show '0%' and 'Not Started' on cold start and on errors.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

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
  bool productionRetry = false,
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
      // Everything is in the base currency, so no converter is needed. A12:
      // goal progress reads the converted snapshot, which needs the base
      // currency up front.
      currencyCodeProvider.overrideWith((ref) => 'INR'),
    ],
    // Production (main.dart) keeps Riverpod's default retry policy.
    retry: productionRetry ? null : (_, _) => null,
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

  // GoalCard, the goal details screen and GoalsDashboardCard read these
  // providers with `.when`, which takes the loading branch for an error that
  // Riverpod is retrying. Under the production retry policy a load failure
  // must still reach the error branch instead of spinning indefinitely.
  final shownWithWhen = <String, ProviderListenable<AsyncValue<Object?>>>{
    ...providers,
    'multiCurrencyGoalsSummaryProvider': multiCurrencyGoalsSummaryProvider,
  };
  for (final entry in shownWithWhen.entries) {
    group('${entry.key} under the default retry policy', () {
      for (final failGoal in [false, true]) {
        final source = failGoal ? 'the goal' : 'cash flows';
        testWidgets(
          'shows the error, not loading, when loading $source fails',
          (tester) async {
            final container = _container(
              productionRetry: true,
              goal: failGoal ? () => Stream.error(_loadError) : null,
              goals: failGoal ? () => Stream.error(_loadError) : null,
              investments: () => Stream.value([_investment]),
              cashFlows: failGoal
                  ? () => Stream.value(const [])
                  : () => Stream.error(_loadError),
            );
            final sub = container.listen(entry.value, (_, _) {});
            await tester.pump();

            // Sample once a second for two minutes, past every retry.
            final seen = <String>{};
            for (var second = 0; second < 120; second++) {
              await tester.pump(const Duration(seconds: 1));
              seen.add(
                sub.read().when(
                  data: (_) => 'data',
                  loading: () => 'loading',
                  error: (_, _) => 'error',
                ),
              );
            }

            expect(seen, {'error'});
            // Dispose now so Riverpod cancels its pending retry timers.
            container.dispose();
            await tester.pumpWidget(const SizedBox());
          },
        );
      }

      testWidgets('recovers once cash flows load after an error', (
        tester,
      ) async {
        // Broadcast: Riverpod's retries listen to the stream again.
        final cashFlows = StreamController<List<CashFlowEntity>>.broadcast();
        addTearDown(() => unawaited(cashFlows.close()));
        final container = _container(
          productionRetry: true,
          investments: () => Stream.value([_investment]),
          cashFlows: () => cashFlows.stream,
        );
        final sub = container.listen(entry.value, (_, _) {});
        cashFlows.addError(_loadError);
        await tester.pump(const Duration(seconds: 1));
        expect(sub.read().hasError, isTrue);

        cashFlows.add(const []);
        await tester.pump(const Duration(seconds: 1));

        expect(sub.read().hasError, isFalse);
        expect(sub.read().hasValue, isTrue);
        container.dispose();
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
