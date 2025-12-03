import 'package:drift/drift.dart';
import 'package:inv_tracker/data/datasources/secure_token_storage.dart';

/// Stub implementation - should never be called.
/// Platform-specific implementations are in:
/// - database_connection_native.dart (iOS, Android, macOS)
/// - database_connection_web.dart (Web)
Future<QueryExecutor> createDatabaseExecutor(SecureTokenStorage tokenStorage) {
  throw UnsupportedError('Cannot create database on this platform');
}

Future<void> deleteDatabaseFile() async {
  throw UnsupportedError('Cannot delete database on this platform');
}

