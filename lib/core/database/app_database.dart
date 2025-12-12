import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/tables/investments.dart';
import 'package:inv_tracker/core/database/tables/transactions.dart';
import 'package:inv_tracker/core/database/database_connection.dart';

part 'app_database.g.dart';

/// Cash Flow Tracker Database
/// Schema v4: Removed SyncQueue table (using full sync strategy)
///
/// Each user gets their own database file for complete data isolation.
/// Database file naming: `inv_tracker_{userId}.sqlite`
@DriftDatabase(tables: [Investments, CashFlows])
class AppDatabase extends _$AppDatabase {
  /// Creates a database for a specific user.
  /// [userId] is required for data isolation between users.
  AppDatabase.forUser(String userId) : super(openConnectionForUser(userId));

  /// Default constructor - only use for backwards compatibility or testing.
  /// Prefer [AppDatabase.forUser] for production use.
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v2 -> v3: Drop old tables and recreate
          if (from < 3) {
            await m.deleteTable('transactions');
            await m.deleteTable('investments');
            await m.deleteTable('portfolios');
            await m.createAll();
          }
          // v3 -> v4: Remove SyncQueue table
          if (from < 4) {
            await customStatement('DROP TABLE IF EXISTS sync_queue');
          }
        },
      );

  /// Clear all data from the database.
  /// Used on logout to ensure user data isolation.
  Future<void> clearAllData() async {
    await delete(cashFlows).go();
    await delete(investments).go();
  }
}
