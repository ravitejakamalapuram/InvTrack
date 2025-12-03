import 'package:drift/drift.dart';
import 'package:inv_tracker/data/datasources/database/tables.dart';

part 'app_database.g.dart';

/// The main application database.
///
/// Uses Drift ORM with SQLCipher encryption for secure local storage.
/// Contains tables for investments, entries, and sync queue.
@DriftDatabase(tables: [Investments, Entries, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
      },
    );
  }

  // ============ Investment Operations ============

  /// Get all investments.
  Future<List<Investment>> getAllInvestments() => select(investments).get();

  /// Watch all investments (reactive stream).
  Stream<List<Investment>> watchAllInvestments() => select(investments).watch();

  /// Get investment by ID.
  Future<Investment?> getInvestmentById(String id) =>
      (select(investments)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Insert a new investment.
  Future<int> insertInvestment(InvestmentsCompanion investment) =>
      into(investments).insert(investment);

  /// Update an investment.
  Future<bool> updateInvestment(Investment investment) =>
      update(investments).replace(investment);

  /// Delete an investment.
  Future<int> deleteInvestment(String id) =>
      (delete(investments)..where((t) => t.id.equals(id))).go();

  // ============ Entry Operations ============

  /// Get all entries for an investment.
  Future<List<Entry>> getEntriesForInvestment(String investmentId) =>
      (select(entries)..where((t) => t.investmentId.equals(investmentId))).get();

  /// Watch entries for an investment.
  Stream<List<Entry>> watchEntriesForInvestment(String investmentId) =>
      (select(entries)..where((t) => t.investmentId.equals(investmentId)))
          .watch();

  /// Get all entries.
  Future<List<Entry>> getAllEntries() => select(entries).get();

  /// Insert a new entry.
  Future<int> insertEntry(EntriesCompanion entry) => into(entries).insert(entry);

  /// Update an entry.
  Future<bool> updateEntry(Entry entry) => update(entries).replace(entry);

  /// Delete an entry.
  Future<int> deleteEntry(String id) =>
      (delete(entries)..where((t) => t.id.equals(id))).go();

  // ============ Sync Queue Operations ============

  /// Get all pending sync operations.
  Future<List<SyncQueueData>> getPendingSyncOperations() =>
      select(syncQueue).get();

  /// Add operation to sync queue.
  Future<int> addToSyncQueue(SyncQueueCompanion operation) =>
      into(syncQueue).insert(operation);

  /// Remove operation from sync queue.
  Future<int> removeSyncOperation(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  /// Increment retry count for a sync operation.
  Future<void> incrementRetryCount(int id) async {
    await customStatement(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  /// Clear all sync queue entries.
  Future<int> clearSyncQueue() => delete(syncQueue).go();

  // ============ Bulk Operations ============

  /// Mark all records as unsynced.
  Future<void> markAllUnsynced() async {
    await customStatement('UPDATE investments SET is_synced = 0');
    await customStatement('UPDATE entries SET is_synced = 0');
  }

  /// Get unsynced investments.
  Future<List<Investment>> getUnsyncedInvestments() =>
      (select(investments)..where((t) => t.isSynced.equals(false))).get();

  /// Get unsynced entries.
  Future<List<Entry>> getUnsyncedEntries() =>
      (select(entries)..where((t) => t.isSynced.equals(false))).get();
}

