import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

/// Opens a native database connection with SQLCipher encryption
/// Used for Android, iOS, macOS, Linux, Windows
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'inv_tracker.sqlite'));

    // Encryption logic
    const secureStorage = FlutterSecureStorage();
    String? encryptionKey = await secureStorage.read(key: 'db_key');

    if (encryptionKey == null) {
      encryptionKey = const Uuid().v4();
      await secureStorage.write(key: 'db_key', value: encryptionKey);
    }

    // For Android, we need to ensure sqlcipher is loaded in this isolate
    if (Platform.isAndroid) {
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    }

    // Use NativeDatabase directly (not in background isolate)
    // This ensures the sqlcipher override is respected
    return NativeDatabase(
      file,
      logStatements: false,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$encryptionKey'");
      },
    );
  });
}

