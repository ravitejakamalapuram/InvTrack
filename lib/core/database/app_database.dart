import 'dart:io';
import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/isolate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:inv_tracker/core/database/tables/portfolios.dart';
import 'package:inv_tracker/core/database/tables/investments.dart';
import 'package:inv_tracker/core/database/tables/transactions.dart';
import 'package:inv_tracker/core/database/tables/sync_queue.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Portfolios, Investments, Transactions, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 2; // Incrementing schema version
}

// Helper class to pass data to background isolate
class _IsolateStartData {
  final String dbPath;
  final String encryptionKey;
  final SendPort sendPort;

  _IsolateStartData(this.dbPath, this.encryptionKey, this.sendPort);
}

// This function runs in a background isolate
@pragma('vm:entry-point')
void _startBackground(_IsolateStartData data) {
  // Override sqlite3 to use sqlcipher in this isolate
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

  final driftIsolate = DriftIsolate.inCurrent(
    () => LazyDatabase(() async {
      return NativeDatabase(
        File(data.dbPath),
        logStatements: true,
        setup: (rawDb) {
          rawDb.execute("PRAGMA key = '${data.encryptionKey}'");
        },
      );
    }),
  );
  data.sendPort.send(driftIsolate);
}

LazyDatabase _openConnection() {
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
