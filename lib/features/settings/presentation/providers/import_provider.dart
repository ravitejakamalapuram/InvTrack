import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/domain/services/import_service.dart';

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    ref.watch(investmentRepositoryProvider),
  );
});

final importStateProvider = StateNotifierProvider<ImportNotifier, AsyncValue<ImportResult?>>((ref) {
  return ImportNotifier(ref.watch(importServiceProvider));
});

class ImportNotifier extends StateNotifier<AsyncValue<ImportResult?>> {
  final ImportService _service;

  ImportNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> importCsv() async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.importFromCsv();
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
