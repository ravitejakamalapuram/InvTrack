import 'package:inv_tracker/domain/entities/investment.dart';

/// Sort order for investment lists.
enum SortOrder { nameAsc, nameDesc, dateAsc, dateDesc, createdAsc, createdDesc }

/// Abstract repository interface for Investment operations.
///
/// This defines the contract that data layer implementations
/// must fulfill. Follows the Repository pattern from Clean Architecture.
abstract class InvestmentRepository {
  /// Get all investments (excluding soft-deleted).
  Future<List<Investment>> getAll({SortOrder sort = SortOrder.nameAsc});

  /// Watch all investments (reactive stream).
  Stream<List<Investment>> watchAll();

  /// Get a single investment by ID.
  Future<Investment?> getById(String id);

  /// Create a new investment.
  Future<Investment> create(Investment investment);

  /// Update an existing investment.
  Future<Investment> update(Investment investment);

  /// Delete an investment by ID (soft delete).
  Future<void> delete(String id);

  /// Permanently delete an investment.
  Future<void> hardDelete(String id);

  /// Search investments by name.
  Future<List<Investment>> searchByName(String query);

  /// Get investments by category.
  Future<List<Investment>> getByCategory(String category);

  /// Get the count of all investments.
  Future<int> count();

  /// Get unsynced investments.
  Future<List<Investment>> getUnsynced();

  /// Mark investment as synced.
  Future<void> markSynced(String id);
}

