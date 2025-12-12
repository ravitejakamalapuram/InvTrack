import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/sync/domain/services/sync_service.dart';

/// Keys for storing sync metadata
const String _lastSyncedKey = 'invtracker_last_synced';
const String _lastModifiedKey = 'invtracker_last_modified';

/// Debounce duration - wait this long after last change before syncing
const Duration _debounceDuration = Duration(minutes: 1);

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, AsyncValue<DateTime?>>((ref) {
  return SyncStatusNotifier(ref);
});

class SyncStatusNotifier extends StateNotifier<AsyncValue<DateTime?>> {
  final Ref _ref;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isSyncing = false;
  Timer? _debounceTimer;

  SyncStatusNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _loadLastSynced();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Load last synced timestamp from storage on init
  Future<void> _loadLastSynced() async {
    final stored = await _storage.read(key: _lastSyncedKey);
    if (stored != null) {
      state = AsyncValue.data(DateTime.parse(stored));
    }
  }

  /// Mark data as modified and trigger debounced sync.
  /// Call this after any local data change.
  Future<void> markDataModified() async {
    await _storage.write(key: _lastModifiedKey, value: DateTime.now().toIso8601String());
    _scheduleDebouncedSync();
  }

  /// Schedule a debounced sync - waits for user to stop making changes
  void _scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      sync();
    });
  }

  /// Get last modified timestamp
  Future<DateTime?> _getLastModified() async {
    final stored = await _storage.read(key: _lastModifiedKey);
    return stored != null ? DateTime.parse(stored) : null;
  }

  /// Get last synced timestamp
  Future<DateTime?> _getLastSynced() async {
    final stored = await _storage.read(key: _lastSyncedKey);
    return stored != null ? DateTime.parse(stored) : null;
  }

  /// Push local data to Google Sheets.
  /// Only syncs if user is signed in and data has been modified since last sync.
  ///
  /// [force] - If true, syncs regardless of lastModified vs lastSynced.
  Future<void> sync({bool force = false}) async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      debugPrint('Sync already in progress, skipping');
      return;
    }

    // Check if user is signed in with Google
    final googleSignIn = _ref.read(googleSignInProvider);
    final currentUser = googleSignIn.currentUser;
    if (currentUser == null) {
      debugPrint('Sync skipped: User not signed in with Google');
      return;
    }

    // Check if sync is needed (unless forced)
    if (!force) {
      final lastModified = await _getLastModified();
      final lastSynced = await _getLastSynced();

      if (lastModified == null) {
        debugPrint('Sync skipped: No data modifications recorded');
        return;
      }

      if (lastSynced != null && lastModified.isBefore(lastSynced)) {
        debugPrint('Sync skipped: Data already synced (modified: $lastModified, synced: $lastSynced)');
        return;
      }
    }

    _isSyncing = true;
    state = const AsyncValue.loading();

    try {
      await _ref.read(syncServiceProvider).pushToSheet();
      final now = DateTime.now();
      await _storage.write(key: _lastSyncedKey, value: now.toIso8601String());
      state = AsyncValue.data(now);
      debugPrint('Sync completed at $now');
    } catch (e, st) {
      debugPrint('Sync failed: $e');
      state = AsyncValue.error(e, st);
    } finally {
      _isSyncing = false;
    }
  }

  /// Import data from Google Sheets on first login.
  /// Returns true if data was imported.
  ///
  /// [force] - if true, bypasses the "already imported" check (used for Connect Guest to Google)
  Future<bool> importOnLogin({bool force = false}) async {
    try {
      final imported = await _ref.read(syncServiceProvider).importFromSheetOnLogin(force: force);
      if (imported) {
        debugPrint('Data imported from Google Sheets');
      }
      return imported;
    } catch (e) {
      debugPrint('Import failed: $e');
      return false;
    }
  }

  /// Check if Google account has existing sheet data.
  Future<bool> checkForExistingSheetData() async {
    try {
      return await _ref.read(syncServiceProvider).checkForExistingSheetData();
    } catch (e) {
      debugPrint('Check for existing data failed: $e');
      return false;
    }
  }

  /// Check for cloud data and import it atomically.
  /// Returns a record with (hasCloudData, importedCount).
  /// Use this for Connect Guest to Google flow.
  Future<({bool hasCloudData, int importedCount})> checkAndImportCloudData() async {
    try {
      return await _ref.read(syncServiceProvider).checkAndImportCloudData();
    } catch (e) {
      debugPrint('Check and import failed: $e');
      return (hasCloudData: false, importedCount: 0);
    }
  }

  /// Get count of investments in cloud (without importing).
  Future<int> getCloudDataCount() async {
    try {
      return await _ref.read(syncServiceProvider).getCloudDataCount();
    } catch (e) {
      debugPrint('Get cloud count failed: $e');
      return 0;
    }
  }

  /// Import cloud data (after confirming with user).
  Future<int> importCloudData() async {
    try {
      return await _ref.read(syncServiceProvider).importCloudData();
    } catch (e) {
      debugPrint('Import cloud data failed: $e');
      return 0;
    }
  }
}
