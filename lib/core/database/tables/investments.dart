import 'package:drift/drift.dart';

/// Investment table for Cash Flow Tracker
/// Tracks investment lifecycle: OPEN -> CLOSED (can reopen)
class Investments extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // InvestmentType enum stored as string
  TextColumn get status => text().withDefault(const Constant('OPEN'))(); // OPEN, CLOSED
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
