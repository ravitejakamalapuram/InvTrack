import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/tables/portfolios.dart';
import 'package:inv_tracker/core/database/tables/investments.dart';
import 'package:inv_tracker/core/database/tables/transactions.dart';
import 'package:inv_tracker/core/database/tables/sync_queue.dart';
import 'package:inv_tracker/core/database/database_connection.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Portfolios, Investments, Transactions, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 2;
}
