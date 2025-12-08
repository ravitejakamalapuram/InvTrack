import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/domain/services/export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    ref.watch(investmentRepositoryProvider),
    ref.watch(portfolioRepositoryProvider),
  );
});

final exportStateProvider = StateNotifierProvider<ExportNotifier, AsyncValue<void>>((ref) {
  return ExportNotifier(ref.watch(exportServiceProvider));
});

class ExportNotifier extends StateNotifier<AsyncValue<void>> {
  final ExportService _service;

  ExportNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> exportCsv() async {
    state = const AsyncValue.loading();
    try {
      await _service.exportToCsv();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
