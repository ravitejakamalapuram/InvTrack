import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/domain/services/seed_data_service.dart';

final seedDataServiceProvider = Provider<SeedDataService>((ref) {
  return SeedDataService(ref.watch(investmentRepositoryProvider));
});

final seedDataStateProvider = StateNotifierProvider<SeedDataNotifier, AsyncValue<void>>((ref) {
  return SeedDataNotifier(ref.watch(seedDataServiceProvider));
});

class SeedDataNotifier extends StateNotifier<AsyncValue<void>> {
  final SeedDataService _service;

  SeedDataNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> seedData() async {
    state = const AsyncValue.loading();
    try {
      await _service.seedDemoData();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

