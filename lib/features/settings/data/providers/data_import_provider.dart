import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';

/// Provider for DataImportService
final dataImportServiceProvider = Provider<DataImportService?>((ref) {
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

  return DataImportService(
    investmentRepository: investmentRepository,
    goalRepository: goalRepository,
    documentRepository: documentRepository,
    documentStorageService: documentStorageService,
    fireSettingsRepository: fireSettingsRepository,
  );
});

/// State for ZIP import operation
/// Uses .autoDispose to prevent memory leaks when screen is disposed
final zipImportStateProvider =
    AsyncNotifierProvider.autoDispose<ZipImportNotifier, ZipImportResult?>(
  ZipImportNotifier.new,
);

class ZipImportNotifier extends AutoDisposeAsyncNotifier<ZipImportResult?> {
  @override
  Future<ZipImportResult?> build() async => null;

  /// Import data from a ZIP file
  Future<ZipImportResult> importFromZip(
    Uint8List zipBytes,
    ImportStrategy strategy,
  ) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(dataImportServiceProvider);
      if (service == null) {
        throw Exception('User not authenticated');
      }
      final result = await service.importFromZip(zipBytes, strategy);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Reset the import state
  void reset() {
    state = const AsyncValue.data(null);
  }
}
