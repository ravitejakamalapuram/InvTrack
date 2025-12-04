import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/tables/investments.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get investmentId => text().references(Investments, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()(); // Enum stored as string: BUY, SELL, DIVIDEND
  RealColumn get quantity => real()();
  RealColumn get pricePerUnit => real()();
  RealColumn get fees => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
