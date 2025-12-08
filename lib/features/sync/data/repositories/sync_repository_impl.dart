import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/app_database.dart';
import 'package:inv_tracker/features/sync/domain/repositories/sync_repository.dart';

class SyncRepositoryImpl implements SyncRepository {
  final AppDatabase _db;

  SyncRepositoryImpl(this._db);

  @override
  Future<void> addToQueue(String operation, String entityType, String entityId, String payload) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion(
            operation: Value(operation),
            entityType: Value(entityType),
            entityId: Value(entityId),
            payload: Value(payload),
            createdAt: Value(DateTime.now()),
            status: const Value('PENDING'),
            retryCount: const Value(0),
          ),
        );
  }

  @override
  Future<List<SyncQueueData>> getPendingItems() async {
    return (_db.select(_db.syncQueue)..where((tbl) => tbl.status.equals('PENDING'))).get();
  }

  @override
  Future<List<SyncQueueData>> getFailedItems() async {
    return (_db.select(_db.syncQueue)..where((tbl) => tbl.status.equals('FAILED'))).get();
  }

  @override
  Future<void> markAsFailed(int id) async {
    // Increment retry count and update status if needed
    // For now, just mark as failed. In real app, we might want to retry a few times.
    await (_db.update(_db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
      const SyncQueueCompanion(
        status: Value('FAILED'),
      ),
    );
  }

  @override
  Future<void> retryItem(int id) async {
    await (_db.update(_db.syncQueue)..where((tbl) => tbl.id.equals(id))).write(
      const SyncQueueCompanion(
        status: Value('PENDING'),
        retryCount: Value(0),
      ),
    );
  }

  @override
  Future<void> deleteItem(int id) async {
    await (_db.delete(_db.syncQueue)..where((tbl) => tbl.id.equals(id))).go();
  }
}
