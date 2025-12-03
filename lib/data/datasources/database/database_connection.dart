import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:inv_tracker/data/datasources/database/app_database.dart';
import 'package:inv_tracker/data/datasources/secure_token_storage.dart';

/// Creates a database connection with optional encryption.
///
/// On mobile platforms (iOS/Android), uses SQLCipher for encryption.
/// On web, uses an in-memory database (data persisted via IndexedDB by drift).
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
    if (kIsWeb) {
      // For web, use driftDatabase with IndexedDB
      // This requires additional setup with drift_dev
      return _createWebExecutor();
    } else {
      return await _createNativeExecutor();
    }
  }

  /// Create executor for web platform.
  static QueryExecutor _createWebExecutor() {
    // For now, use in-memory database on web
    // TODO: Configure IndexedDB persistence with drift_dev
    return NativeDatabase.memory();
  }

  /// Create executor for native platforms (iOS, Android, macOS).
  static Future<QueryExecutor> _createNativeExecutor() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'inv_tracker.db'));

    // Get or create encryption key
    final encryptionKey = await _tokenStorage.getOrCreateDbEncryptionKey();

    // Use SQLCipher for encryption on native platforms
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Set the encryption key using SQLCipher pragma
        db.execute("PRAGMA key = '$encryptionKey'");
      },
    );
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
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'inv_tracker.db'));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

