import 'package:inv_tracker/data/datasources/database/app_database.dart';
import 'package:inv_tracker/data/datasources/google_sheets_service.dart';
import 'package:inv_tracker/data/datasources/secure_token_storage.dart';

/// Sync status enum.
enum SyncStatus { idle, syncing, success, error }

/// Service for syncing local data with Google Sheets.
class SyncService {
  final AppDatabase _database;
  final GoogleSheetsService _sheetsService;
  final SecureTokenStorage _tokenStorage;

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;

  SyncService(this._database, this._sheetsService, this._tokenStorage);

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Perform full sync with Google Sheets.
  Future<bool> sync(String accessToken) async {
    if (_status == SyncStatus.syncing) return false;

    _status = SyncStatus.syncing;
    _lastError = null;

    try {
      // 1. Process pending sync queue items
      await _processSyncQueue(accessToken);

      // 2. Sync all investments
      final investments = await _database.getAllInvestments();
      final investmentMaps = investments.map((inv) => {
        'id': inv.id,
        'name': inv.name,
        'category': inv.category,
        'notes': inv.notes,
        'startDate': inv.startDate.toIso8601String(),
        'createdAt': inv.createdAt.toIso8601String(),
        'updatedAt': inv.updatedAt.toIso8601String(),
        'isDeleted': inv.isDeleted,
      }).toList();
      await _sheetsService.syncInvestments(accessToken, investmentMaps);

      // 3. Sync all entries
      final entries = await _database.getAllEntries();
      final entryMaps = entries.map((e) => {
        'id': e.id,
        'investmentId': e.investmentId,
        'type': e.type,
        'amount': e.amount,
        'units': e.units,
        'pricePerUnit': e.pricePerUnit,
        'date': e.date.toIso8601String(),
        'note': e.note,
        'createdAt': e.createdAt.toIso8601String(),
        'updatedAt': e.updatedAt.toIso8601String(),
      }).toList();
      await _sheetsService.syncEntries(accessToken, entryMaps);

      // 4. Update last sync timestamp
      await _sheetsService.updateLastSync(accessToken);
      _lastSyncTime = DateTime.now();
      await _tokenStorage.saveLastSync(_lastSyncTime!);

      // 5. Clear sync queue
      await _database.clearSyncQueue();

      _status = SyncStatus.success;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _status = SyncStatus.error;
      return false;
    }
  }

  Future<void> _processSyncQueue(String accessToken) async {
    final queue = await _database.getPendingSyncOperations();
    for (final item in queue) {
      // For now, we do a full sync, so just remove from queue
      await _database.removeSyncOperation(item.id);
    }
  }

  /// Load last sync time from storage.
  Future<void> loadLastSyncTime() async {
    _lastSyncTime = await _tokenStorage.getLastSync();
  }
}

