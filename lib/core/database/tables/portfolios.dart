import 'package:drift/drift.dart';

class Portfolios extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
