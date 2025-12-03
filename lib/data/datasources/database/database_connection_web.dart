import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:inv_tracker/data/datasources/secure_token_storage.dart';

/// Create executor for web platform using WebAssembly SQLite.
Future<QueryExecutor> createDatabaseExecutor(
    SecureTokenStorage tokenStorage) async {
  // Use drift's WASM-based database for web
  final result = await WasmDatabase.open(
    databaseName: 'inv_tracker_db',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );

  return result.resolvedExecutor;
}

/// Delete database on web - not directly supported, data is in IndexedDB.
Future<void> deleteDatabaseFile() async {
  // On web, database is stored in IndexedDB
  // Deletion would require using the IndexedDB API directly
}

