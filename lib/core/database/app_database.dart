import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:inv_tracker/core/database/tables/portfolios.dart';
import 'package:inv_tracker/core/database/tables/investments.dart';
import 'package:inv_tracker/core/database/tables/transactions.dart';
import 'package:inv_tracker/core/database/tables/sync_queue.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Portfolios, Investments, Transactions, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; // Incrementing schema version
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'inv_tracker.sqlite'));

    // Encryption logic
    const secureStorage = FlutterSecureStorage();
    String? encryptionKey = await secureStorage.read(key: 'db_key');

    if (encryptionKey == null) {
      // Generate a new key if one doesn't exist
      encryptionKey = const Uuid().v4(); // Simple key generation for now, ideally use stronger random bytes
      await secureStorage.write(key: 'db_key', value: encryptionKey);
    }

    return NativeDatabase.createInBackground(
      file,
      logStatements: true,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$encryptionKey'");
      },
    );
  });
}
