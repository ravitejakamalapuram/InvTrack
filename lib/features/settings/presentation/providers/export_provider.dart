import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/settings/data/services/export_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  final settings = ref.watch(settingsProvider);
  return ExportService(
    ref.watch(investmentRepositoryProvider),
    settings.currency,
  );
});

/// State for CSV export operation
/// Uses .autoDispose to prevent memory leaks when screen is disposed
final exportStateProvider =
    NotifierProvider.autoDispose<ExportNotifier, AsyncValue<void>>(
      ExportNotifier.new,
    );

class ExportNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    // Initial state is null (no operation in progress)
    return const AsyncValue.data(null);
  }

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
