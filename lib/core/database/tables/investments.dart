import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/tables/portfolios.dart';

class Investments extends Table {
  TextColumn get id => text()();
  TextColumn get portfolioId => text().references(Portfolios, #id)();
  TextColumn get name => text()();
  TextColumn get symbol => text().nullable()();
  TextColumn get type => text()(); // Enum stored as string
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
