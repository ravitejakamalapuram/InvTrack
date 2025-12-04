import 'package:inv_tracker/core/database/app_database.dart';

abstract class SyncRepository {
  Future<void> addToQueue(String operation, String entityType, String entityId, String payload);
  Future<List<SyncQueueData>> getPendingItems();
  Future<List<SyncQueueData>> getFailedItems();
  Future<void> markAsFailed(int id);
  Future<void> retryItem(int id);
  Future<void> deleteItem(int id);
}
