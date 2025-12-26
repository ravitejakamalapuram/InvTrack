import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/data/services/seed_data_service.dart';

final seedDataServiceProvider = Provider<SeedDataService>((ref) {
  return SeedDataService(ref.watch(investmentRepositoryProvider));
});

/// Result of seeding demo data
typedef SeedResult = ({int investments, int cashFlows});

final seedDataStateProvider = NotifierProvider<SeedDataNotifier, AsyncValue<SeedResult?>>(
  SeedDataNotifier.new,
);

class SeedDataNotifier extends Notifier<AsyncValue<SeedResult?>> {
  @override
  AsyncValue<SeedResult?> build() => const AsyncValue.data(null);

  Future<SeedResult?> seedData() async {
    state = const AsyncValue.loading();
    try {
      final result = await ref.read(seedDataServiceProvider).seedDemoData();
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

