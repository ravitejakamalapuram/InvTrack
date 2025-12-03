import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/data/datasources/google_sheets_service.dart';
import 'package:inv_tracker/data/datasources/sync_service.dart';
import 'package:inv_tracker/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/presentation/providers/database_provider.dart';

/// Provider for Google Sheets service.
final googleSheetsServiceProvider = Provider<GoogleSheetsService?>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  if (tokenStorage == null) return null;
  return GoogleSheetsService(tokenStorage);
});

/// Provider for sync service.
final syncServiceProvider = Provider<SyncService?>((ref) {
  final database = ref.watch(databaseProvider);
  final sheetsService = ref.watch(googleSheetsServiceProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  if (database == null || sheetsService == null || tokenStorage == null) return null;
  return SyncService(database, sheetsService, tokenStorage);
});

/// Sync state notifier.
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    _loadLastSync();
    return const SyncState();
  }

  Future<void> _loadLastSync() async {
    final syncService = ref.read(syncServiceProvider);
    if (syncService != null) {
      await syncService.loadLastSyncTime();
      state = state.copyWith(lastSyncTime: syncService.lastSyncTime);
    }
  }

  Future<bool> sync() async {
    final syncService = ref.read(syncServiceProvider);
    final accessToken = ref.read(accessTokenProvider);
    if (syncService == null || accessToken == null) {
      state = state.copyWith(status: SyncStatus.error, error: 'Not authenticated');
      return false;
    }

    state = state.copyWith(status: SyncStatus.syncing, error: null);

    final success = await syncService.sync(accessToken);
    if (success) {
      state = state.copyWith(status: SyncStatus.success, lastSyncTime: syncService.lastSyncTime);
    } else {
      state = state.copyWith(status: SyncStatus.error, error: syncService.lastError);
    }
    return success;
  }
}

/// Sync state.
class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final String? error;

  const SyncState({this.status = SyncStatus.idle, this.lastSyncTime, this.error});

  SyncState copyWith({SyncStatus? status, DateTime? lastSyncTime, String? error}) {
    return SyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      error: error,
    );
  }
}

/// Provider for sync notifier.
final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Provider for access token.
final accessTokenProvider = Provider<String?>((ref) {
  // This would come from the auth service
  // For now, return null - will be implemented when auth is connected
  return null;
});

