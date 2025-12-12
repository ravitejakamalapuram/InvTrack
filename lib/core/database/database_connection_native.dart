import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

/// Key prefix in secure storage for per-user encryption keys
const String _dbKeyPrefix = 'db_encryption_key_';

/// Opens a native database connection with SQLCipher encryption for a specific user.
/// Each user gets their own database file: `inv_tracker_{userId}.sqlite`
///
/// [userId] is the unique identifier for the user:
/// - For Google users: their Google account ID
/// - For guest users: a generated UUID
///
/// This implementation handles the common SQLCipher key mismatch problem:
/// - If the encryption key in secure storage doesn't match the database file,
///   the database is automatically reset with a fresh key
LazyDatabase openConnection([String? userId]) {
  // If no userId provided, we're in a transitional state - use a temp database
  final effectiveUserId = userId ?? 'temp_uninitialized';

  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbFileName = 'inv_tracker_$effectiveUserId.sqlite';
    final file = File(p.join(dbFolder.path, dbFileName));
    final keyName = '$_dbKeyPrefix$effectiveUserId';

    debugPrint('[Database] Opening database for user: $effectiveUserId');
    debugPrint('[Database] Database file: ${file.path}');

    // For Android, we need to ensure sqlcipher is loaded
    if (Platform.isAndroid) {
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    }

    // Get or generate encryption key for this user
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );

    String? encryptionKey = await secureStorage.read(key: keyName);
    bool isNewDatabase = !file.existsSync();

    if (encryptionKey == null) {
      // Generate new key for this user
      encryptionKey = const Uuid().v4();
      await secureStorage.write(key: keyName, value: encryptionKey);

      // If database exists but key is missing, we need to delete the old database
      // because we can't open it without the original key
      if (file.existsSync()) {
        debugPrint('[Database] Key missing but database exists - resetting database for user: $effectiveUserId');
        await _deleteDatabase(file);
        isNewDatabase = true;
      }
    } else if (file.existsSync()) {
      // Both key and database exist - verify the key works
      final keyWorks = await _verifyEncryptionKey(file, encryptionKey);
      if (!keyWorks) {
        debugPrint('[Database] Encryption key mismatch detected - resetting database for user: $effectiveUserId');
        await _deleteDatabase(file);
        // Generate a completely new key to avoid any confusion
        encryptionKey = const Uuid().v4();
        await secureStorage.write(key: keyName, value: encryptionKey);
        isNewDatabase = true;
      }
    }

    if (isNewDatabase) {
      debugPrint('[Database] Creating new encrypted database for user: $effectiveUserId');
    }

    return NativeDatabase(
      file,
      logStatements: false,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$encryptionKey'");
      },
    );
  });
}

/// Opens a database connection for a specific user ID.
/// This is the preferred method to call when you have a user ID available.
LazyDatabase openConnectionForUser(String userId) {
  return openConnection(userId);
}

/// Verifies that the encryption key can open the database
Future<bool> _verifyEncryptionKey(File dbFile, String key) async {
  try {
    final db = sqlite3.sqlite3.open(dbFile.path);
    try {
      db.execute("PRAGMA key = '$key'");
      // Try a simple query to verify the key works
      db.select('SELECT count(*) FROM sqlite_master');
      return true;
    } catch (e) {
      debugPrint('[Database] Key verification failed: $e');
      return false;
    } finally {
      db.dispose();
    }
  } catch (e) {
    debugPrint('[Database] Could not open database for verification: $e');
    return false;
  }
}

/// Safely deletes the database file and any related files
Future<void> _deleteDatabase(File dbFile) async {
  try {
    if (await dbFile.exists()) {
      await dbFile.delete();
      debugPrint('[Database] Deleted database file: ${dbFile.path}');
    }

    // Also delete journal and WAL files if they exist
    final walFile = File('${dbFile.path}-wal');
    final shmFile = File('${dbFile.path}-shm');
    final journalFile = File('${dbFile.path}-journal');

    for (final f in [walFile, shmFile, journalFile]) {
      if (await f.exists()) {
        await f.delete();
        debugPrint('[Database] Deleted related file: ${f.path}');
      }
    }
  } catch (e) {
    debugPrint('[Database] Error deleting database: $e');
  }
}

