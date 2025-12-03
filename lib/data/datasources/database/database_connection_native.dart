import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:inv_tracker/data/datasources/secure_token_storage.dart';

/// Create executor for native platforms (iOS, Android, macOS).
Future<QueryExecutor> createDatabaseExecutor(
    SecureTokenStorage tokenStorage) async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'inv_tracker.db'));

  // Get or create encryption key
  final encryptionKey = await tokenStorage.getOrCreateDbEncryptionKey();

  // Use SQLCipher for encryption on native platforms
  return NativeDatabase.createInBackground(
    file,
    setup: (db) {
      // Set the encryption key using SQLCipher pragma
      db.execute("PRAGMA key = '$encryptionKey'");
    },
  );
}

/// Delete the database file on native platforms.
Future<void> deleteDatabaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'inv_tracker.db'));
  if (await file.exists()) {
    await file.delete();
  }
}

