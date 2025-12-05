import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens a web database connection using IndexedDB with SQL.js
/// Used for web platform
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'inv_tracker',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      // Log missing features but continue - the database will still work
      // ignore: avoid_print
      print('Missing web features: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  });
}

