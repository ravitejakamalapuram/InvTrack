import 'package:drift/drift.dart';

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()(); // CREATE, UPDATE, DELETE
  TextColumn get entityType => text()(); // PORTFOLIO, INVESTMENT, TRANSACTION
  TextColumn get entityId => text()();
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING, FAILED
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}
