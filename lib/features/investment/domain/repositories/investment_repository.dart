import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Repository for Cash Flow Investment Tracker
///
/// Active and archived data are stored in separate collections for complete isolation.
/// This ensures archived investments can never accidentally be included in calculations.
abstract class InvestmentRepository {
  // ============ ACTIVE INVESTMENTS ============

  /// Watch all active (non-archived) investments (reactive stream)
  Stream<List<InvestmentEntity>> watchAllInvestments();

  /// Watch investments by status (active only)
  Stream<List<InvestmentEntity>> watchInvestmentsByStatus(
    InvestmentStatus status,
  );

  /// Get all active investments
  Future<List<InvestmentEntity>> getAllInvestments();

  /// Get investment by ID (searches active first, then archived)
  Future<InvestmentEntity?> getInvestmentById(String id);

  /// Create a new investment
  Future<void> createInvestment(InvestmentEntity investment);

  /// Update an existing investment
  Future<void> updateInvestment(InvestmentEntity investment);

  /// Close an investment
  Future<void> closeInvestment(String id);

  /// Reopen a closed investment
  Future<void> reopenInvestment(String id);

  /// Archive an investment (moves to archived collection)
  Future<void> archiveInvestment(String id);

  /// Unarchive an investment (moves back to active collection)
  Future<void> unarchiveInvestment(String id);

  /// Delete an investment and all its cash flows permanently
  Future<void> deleteInvestment(String id);

  // ============ ARCHIVED INVESTMENTS ============

  /// Watch all archived investments (reactive stream)
  Stream<List<InvestmentEntity>> watchArchivedInvestments();

  /// Get archived investment by ID
  Future<InvestmentEntity?> getArchivedInvestmentById(String id);

  /// Delete an archived investment permanently
  Future<void> deleteArchivedInvestment(String id);

  // ============ ACTIVE CASH FLOWS ============

  /// Watch all active cash flows (reactive stream for global stats)
  Stream<List<CashFlowEntity>> watchAllCashFlows();

  /// Watch cash flows for an active investment (reactive stream)
  Stream<List<CashFlowEntity>> watchCashFlowsByInvestment(String investmentId);

  /// Get cash flows for an active investment
  Future<List<CashFlowEntity>> getCashFlowsByInvestment(String investmentId);

  /// Get all active cash flows across all investments
  Future<List<CashFlowEntity>> getAllCashFlows();

  /// Add a new cash flow
  Future<void> addCashFlow(CashFlowEntity cashFlow);

  /// Update an existing cash flow
  Future<void> updateCashFlow(CashFlowEntity cashFlow);

  /// Delete a cash flow
  Future<void> deleteCashFlow(String id);

  // ============ ARCHIVED CASH FLOWS ============

  /// Watch archived cash flows for an archived investment
  Stream<List<CashFlowEntity>> watchArchivedCashFlowsByInvestment(
    String investmentId,
  );

  /// Get archived cash flows for an archived investment
  Future<List<CashFlowEntity>> getArchivedCashFlowsByInvestment(
    String investmentId,
  );

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
