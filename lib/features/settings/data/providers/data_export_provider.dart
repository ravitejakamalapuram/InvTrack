import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/performance/performance_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

/// Provider for DataExportService
final dataExportServiceProvider = Provider<DataExportService?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return null;
  }

  final investmentRepository = ref.watch(investmentRepositoryProvider);
  final goalRepository = ref.watch(goalRepositoryProvider);
  final documentRepository = ref.watch(documentRepositoryProvider);
  final documentStorageService = ref.watch(documentStorageServiceProvider);
  final fireSettingsRepository = ref.watch(fireSettingsRepositoryProvider);
  final performanceService = ref.watch(performanceServiceProvider);
  final settings = ref.watch(settingsProvider);

  return DataExportService(
    investmentRepository: investmentRepository,
    goalRepository: goalRepository,
    documentRepository: documentRepository,
    documentStorageService: documentStorageService,
    fireSettingsRepository: fireSettingsRepository,
    performanceService: performanceService,
    baseCurrency: settings.currency,
  );
});

/// State for ZIP export operation
/// Uses .autoDispose to prevent memory leaks when screen is disposed
final zipExportStateProvider =
    NotifierProvider.autoDispose<ZipExportNotifier, AsyncValue<void>>(
      ZipExportNotifier.new,
    );

class ZipExportNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    // Initial state is null (no operation in progress)
    return const AsyncValue.data(null);
  }

  Future<void> exportAsZip() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(dataExportServiceProvider);
      if (service == null) {
        throw Exception('User not authenticated');
      }
      await service.exportAndShare();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
