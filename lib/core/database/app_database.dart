import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/tables/investments.dart';
import 'package:inv_tracker/core/database/tables/transactions.dart';
import 'package:inv_tracker/core/database/tables/sync_queue.dart';
import 'package:inv_tracker/core/database/database_connection.dart';

part 'app_database.g.dart';

/// Cash Flow Tracker Database
/// Schema v3: Fresh start with Investment + CashFlow model
@DriftDatabase(tables: [Investments, CashFlows, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Fresh start - drop old tables and recreate
        if (from < 3) {
          // Drop old tables if they exist
          await m.deleteTable('transactions');
          await m.deleteTable('investments');
          await m.deleteTable('portfolios');
          // Create new schema
          await m.createAll();
        }
      },
    );
  }
}
