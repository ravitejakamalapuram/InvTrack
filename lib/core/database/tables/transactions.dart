import 'package:drift/drift.dart';
import 'package:inv_tracker/core/database/tables/investments.dart';

/// CashFlows table - renamed from Transactions
/// Tracks money going out (INVEST, FEE) and coming back (RETURN, INCOME)
class CashFlows extends Table {
  TextColumn get id => text()();
  TextColumn get investmentId => text().references(Investments, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()(); // CashFlowType enum: INVEST, RETURN, INCOME, FEE
  RealColumn get amount => real()(); // Always positive, direction determined by type
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
