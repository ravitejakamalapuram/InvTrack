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

  /// Watch all cash flows (reactive stream for global stats)
  Stream<List<CashFlowEntity>> watchAllCashFlows();

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

  // ============ BULK OPERATIONS ============

  /// Bulk import investments with their cash flows in a single batch operation.
  /// This is optimized for importing large amounts of data quickly.
  /// Returns the number of successfully imported items.
  Future<({int investments, int cashFlows})> bulkImport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
  });

  /// Bulk delete multiple investments and their cash flows.
  /// This is optimized for deleting multiple items efficiently using batches.
  /// Returns the number of successfully deleted investments.
  Future<int> bulkDelete(List<String> investmentIds);
}
