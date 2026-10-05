// A121 (#895): only the new-account decision waits for the server. The
// Investments list, offline with a genuinely empty collection, must still
// reach its empty state from the cache instead of loading forever.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
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
}
