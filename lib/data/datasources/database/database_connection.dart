import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:inv_tracker/data/datasources/database/app_database.dart';
import 'package:inv_tracker/data/datasources/secure_token_storage.dart';

// Conditional imports for platform-specific implementations
import 'database_connection_stub.dart'
    if (dart.library.io) 'database_connection_native.dart'
    if (dart.library.html) 'database_connection_web.dart' as platform;

/// Creates a database connection with optional encryption.
///
/// On mobile platforms (iOS/Android), uses SQLCipher for encryption.
/// On web, uses sqflite_common_ffi_web with IndexedDB persistence.
class DatabaseConnection {
  static AppDatabase? _instance;
  static final SecureTokenStorage _tokenStorage = SecureTokenStorage();

  /// Get the singleton database instance.
  static Future<AppDatabase> getInstance() async {
    if (_instance != null) return _instance!;

    final executor = await _createExecutor();
    _instance = AppDatabase(executor);
    return _instance!;
  }

  /// Create the appropriate query executor for the platform.
  static Future<QueryExecutor> _createExecutor() async {
    return platform.createDatabaseExecutor(_tokenStorage);
  }

  /// Close the database connection.
  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  /// Delete the database file and reset.
  /// Use with caution - all data will be lost.
  static Future<void> deleteDatabase() async {
    await close();
    if (!kIsWeb) {
      await platform.deleteDatabaseFile();
    }
  }
}

