import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Repository for Cash Flow Investment Tracker
abstract class InvestmentRepository {
  // ============ INVESTMENTS ============

  /// Watch all investments (reactive stream)
  Stream<List<InvestmentEntity>> watchAllInvestments();

  /// Watch investments by status
  Stream<List<InvestmentEntity>> watchInvestmentsByStatus(InvestmentStatus status);

  /// Get all investments
  Future<List<InvestmentEntity>> getAllInvestments();

  /// Get investment by ID
  Future<InvestmentEntity?> getInvestmentById(String id);

  /// Create a new investment
  Future<void> createInvestment(InvestmentEntity investment);

  /// Update an existing investment
  Future<void> updateInvestment(InvestmentEntity investment);

  /// Close an investment
  Future<void> closeInvestment(String id);

  /// Reopen a closed investment
  Future<void> reopenInvestment(String id);

  /// Delete an investment and all its cash flows
  Future<void> deleteInvestment(String id);

  // ============ CASH FLOWS ============

  /// Watch cash flows for an investment (reactive stream)
  Stream<List<CashFlowEntity>> watchCashFlowsByInvestment(String investmentId);

  /// Get cash flows for an investment
  Future<List<CashFlowEntity>> getCashFlowsByInvestment(String investmentId);

  /// Get all cash flows across all investments
  Future<List<CashFlowEntity>> getAllCashFlows();

  /// Add a new cash flow
  Future<void> addCashFlow(CashFlowEntity cashFlow);

  /// Update an existing cash flow
  Future<void> updateCashFlow(CashFlowEntity cashFlow);

  /// Delete a cash flow
  Future<void> deleteCashFlow(String id);

  // ============ BULK CACHE OPERATIONS ============

  /// Replace all local data with the provided data (for cloud sync).
  /// Clears existing data and inserts new data in a single transaction.
  Future<void> replaceAllData(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  );

  /// Clear all local data (investments and cash flows).
  Future<void> clearAllData();

  /// Check if there is any local data.
  Future<bool> hasData();

  /// Get the count of investments.
  Future<int> getInvestmentCount();
}
