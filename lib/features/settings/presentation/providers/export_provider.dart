import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/data/services/export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    ref.watch(investmentRepositoryProvider),
  );
});

final exportStateProvider = NotifierProvider<ExportNotifier, AsyncValue<void>>(
  ExportNotifier.new,
);

class ExportNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> exportCsv() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(exportServiceProvider).exportToCsv();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
