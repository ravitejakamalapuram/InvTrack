import 'package:inv_tracker/domain/entities/investment.dart';

/// Abstract repository interface for Investment operations.
/// 
/// This defines the contract that data layer implementations
/// must fulfill. Follows the Repository pattern from Clean Architecture.
abstract class InvestmentRepository {
  /// Get all investments.
  Future<List<Investment>> getAll();

  /// Get a single investment by ID.
  Future<Investment?> getById(String id);

  /// Create a new investment.
  Future<Investment> create(Investment investment);

  /// Update an existing investment.
  Future<Investment> update(Investment investment);

  /// Delete an investment by ID.
  Future<void> delete(String id);

  /// Search investments by name.
  Future<List<Investment>> searchByName(String query);

  /// Get investments by type.
  Future<List<Investment>> getByType(String type);

  /// Get the count of all investments.
  Future<int> count();
}

