import 'package:drift/drift.dart';

/// Investments table - stores investment records.
///
/// Each investment represents a single financial instrument or asset
/// such as stocks, mutual funds, fixed deposits, etc.
class Investments extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Name of the investment (e.g., "HDFC Bank", "Axis Mutual Fund").
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Category of investment (stock, mutualFund, fixedDeposit, etc.).
  TextColumn get category => text()();

  /// Date when the investment was started.
  DateTimeColumn get startDate => dateTime()();

  /// Optional notes about the investment.
  TextColumn get notes => text().nullable()();

  /// Timestamp when the record was created.
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when the record was last updated.
  DateTimeColumn get updatedAt => dateTime()();

  /// Whether this record has been synced to Google Sheets.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Entries table - stores individual transactions for investments.
///
/// Each entry represents a cash flow event: inflow (buy), outflow (sell),
/// dividend, interest, etc.
class Entries extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Reference to the parent investment.
  TextColumn get investmentId => text().references(Investments, #id)();

  /// Date of the transaction.
  DateTimeColumn get date => dateTime()();

  /// Type of entry (inflow, outflow, dividend, interest, maturity).
  TextColumn get type => text()();

  /// Amount of the transaction (always positive).
  RealColumn get amount => real()();

  /// Number of units (for stocks/mutual funds).
  RealColumn get units => real().nullable()();

  /// Price per unit at the time of transaction.
  RealColumn get pricePerUnit => real().nullable()();

  /// Optional note about this entry.
  TextColumn get note => text().nullable()();

  /// Timestamp when the record was created.
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when the record was last updated.
  DateTimeColumn get updatedAt => dateTime()();

  /// Whether this record has been synced to Google Sheets.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// SyncQueue table - stores pending sync operations.
///
/// When offline, changes are queued here and synced when online.
class SyncQueue extends Table {
  /// Auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Type of operation (create, update, delete).
  TextColumn get operation => text()();

  /// Name of the affected table (investments, entries).
  TextColumn get targetTable => text()();

  /// ID of the affected record.
  TextColumn get recordId => text()();

  /// JSON payload of the change.
  TextColumn get payload => text()();

  /// Timestamp when the operation was queued.
  DateTimeColumn get createdAt => dateTime()();

  /// Number of sync retry attempts.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

