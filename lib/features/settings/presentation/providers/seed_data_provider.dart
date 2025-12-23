import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/domain/services/seed_data_service.dart';

final seedDataServiceProvider = Provider<SeedDataService>((ref) {
  return SeedDataService(ref.watch(investmentRepositoryProvider));
});

/// Result of seeding demo data
typedef SeedResult = ({int investments, int cashFlows});

final seedDataStateProvider = StateNotifierProvider<SeedDataNotifier, AsyncValue<SeedResult?>>((ref) {
  return SeedDataNotifier(ref.watch(seedDataServiceProvider));
});

class SeedDataNotifier extends StateNotifier<AsyncValue<SeedResult?>> {
  final SeedDataService _service;

  SeedDataNotifier(this._service) : super(const AsyncValue.data(null));

  Future<SeedResult?> seedData() async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.seedDemoData();
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

