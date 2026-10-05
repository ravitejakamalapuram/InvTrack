// A121 (#895): only the new-account decision waits for the server. Screens
// fed by the investment streams, offline with a genuinely empty collection,
// must still reach their content from the cache instead of loading forever.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_list_state_provider.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';

import '../../data/repositories/investment_snapshot_mocks.dart';

void main() {
  setUpAll(registerInvestmentSnapshotFallbacks);

  for (final filter in [InvestmentFilter.archived, InvestmentFilter.all]) {
    test('offline, the ${filter.name} filter shows an empty list from an '
        'empty cache, not a loading state', () async {
      final firestore = InvestmentFirestoreMock();
      addTearDown(firestore.close);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          investmentRepositoryProvider.overrideWithValue(
            firestore.repository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(investmentListStateProvider.notifier).setFilter(filter);
      final subscription = container.listen(
        filteredInvestmentsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      firestore.activeSnapshots.add(querySnapshot(fromCache: true));
      firestore.archivedSnapshots.add(querySnapshot(fromCache: true));
      await pumpEventQueue();

      final list = container.read(filteredInvestmentsProvider);
      expect(list.isLoading, isFalse);
      expect(list.value, isEmpty);
    });
  }

  test('offline, a goal lists its linked active investment although the '
      'archived cache is empty (Goal details, #914)', () async {
    final firestore = InvestmentFirestoreMock();
    addTearDown(firestore.close);
    final goal = GoalEntity(
      id: 'goal-1',
      name: 'Retirement',
      type: GoalType.targetAmount,
      targetAmount: 1000000,
      trackingMode: GoalTrackingMode.all,
      icon: GoalIcons.defaultIcon,
      colorValue: 0xFF4CAF50,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      currency: 'INR',
    );
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        isAuthenticatedProvider.overrideWithValue(true),
        investmentRepositoryProvider.overrideWithValue(firestore.repository()),
        watchGoalByIdProvider.overrideWith((ref, id) => Stream.value(goal)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      goalLinkedInvestmentsProvider('goal-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    firestore.activeSnapshots.add(
      querySnapshot(docs: {'inv-1': investmentDoc('HDFC FD')}, fromCache: true),
    );
    firestore.archivedSnapshots.add(querySnapshot(fromCache: true));
    await pumpEventQueue();

    final linked = container.read(goalLinkedInvestmentsProvider('goal-1'));
    expect(linked.isLoading, isFalse);
    expect(linked.value?.map((l) => l.investment.name), ['HDFC FD']);
  });
}
