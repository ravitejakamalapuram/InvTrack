import 'package:inv_tracker/domain/entities/entry.dart';

/// Abstract repository interface for Entry (ledger) operations.
///
/// This defines the contract that data layer implementations
/// must fulfill for managing investment entries/transactions.
abstract class EntryRepository {
  /// Get all entries for a specific investment.
  Future<List<Entry>> getByInvestmentId(String investmentId);

  /// Watch entries for an investment (reactive stream).
  Stream<List<Entry>> watchByInvestmentId(String investmentId);

  /// Get all entries.
  Future<List<Entry>> getAll();

  /// Get a single entry by ID.
  Future<Entry?> getById(String id);

  /// Create a new entry.
  Future<Entry> create(Entry entry);

  /// Update an existing entry.
  Future<Entry> update(Entry entry);

  /// Delete an entry by ID.
  Future<void> delete(String id);

  /// Delete all entries for an investment.
  Future<void> deleteByInvestmentId(String investmentId);

  /// Get entries within a date range.
  Future<List<Entry>> getByDateRange(
    String investmentId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Get entries by type.
  Future<List<Entry>> getByType(EntryType type);

  /// Get the count of entries for an investment.
  Future<int> countByInvestmentId(String investmentId);

  /// Get the total invested amount for an investment (sum of inflows).
  Future<double> getTotalInvested(String investmentId);

  /// Get the total withdrawn amount for an investment (sum of outflows).
  Future<double> getTotalWithdrawn(String investmentId);

  /// Get unsynced entries.
  Future<List<Entry>> getUnsynced();

  /// Mark entry as synced.
  Future<void> markSynced(String id);
}

