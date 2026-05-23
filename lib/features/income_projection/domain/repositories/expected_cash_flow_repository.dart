import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';

/// Repository for Expected Cash Flow data
///
/// Manages persistence of expected income projections with real-time updates
abstract class ExpectedCashFlowRepository {
  // ============ STREAM PROVIDERS ============

  /// Watch all expected cash flows (reactive stream)
  Stream<List<ExpectedCashFlowEntity>> watchAllExpectedCashFlows();

  /// Watch expected cash flows for a specific investment (reactive stream)
  Stream<List<ExpectedCashFlowEntity>> watchExpectedCashFlowsByInvestment(
    String investmentId,
  );

  /// Watch pending expected cash flows (reactive stream)
  /// Returns only cash flows with status PENDING
  Stream<List<ExpectedCashFlowEntity>> watchPendingExpectedCashFlows();

  /// Watch overdue expected cash flows (reactive stream)
  /// Returns only cash flows that are past their expected date and still PENDING
  Stream<List<ExpectedCashFlowEntity>> watchOverdueExpectedCashFlows();

  /// Watch upcoming expected cash flows (reactive stream)
  /// Returns cash flows within next [days] days (default: 7)
  Stream<List<ExpectedCashFlowEntity>> watchUpcomingExpectedCashFlows({
    int days = 7,
  });

  // ============ READ OPERATIONS ============

  /// Get all expected cash flows
  Future<List<ExpectedCashFlowEntity>> getAllExpectedCashFlows();

  /// Get expected cash flows for a specific investment
  Future<List<ExpectedCashFlowEntity>> getExpectedCashFlowsByInvestment(
    String investmentId,
  );

  /// Get a single expected cash flow by ID
  Future<ExpectedCashFlowEntity?> getExpectedCashFlowById(String id);

  /// Get pending expected cash flows
  Future<List<ExpectedCashFlowEntity>> getPendingExpectedCashFlows();

  /// Get overdue expected cash flows
  Future<List<ExpectedCashFlowEntity>> getOverdueExpectedCashFlows();

  // ============ WRITE OPERATIONS ============

  /// Create a new expected cash flow
  Future<void> createExpectedCashFlow(ExpectedCashFlowEntity expectedCashFlow);

  /// Update an existing expected cash flow
  Future<void> updateExpectedCashFlow(ExpectedCashFlowEntity expectedCashFlow);

  /// Delete an expected cash flow
  Future<void> deleteExpectedCashFlow(String id);

  /// Delete all expected cash flows for an investment
  Future<void> deleteExpectedCashFlowsByInvestment(String investmentId);

  // ============ STATUS UPDATE OPERATIONS ============

  /// Mark expected cash flow as received
  /// Updates status to RECEIVED and sets actualDate and actualAmount
  Future<void> markAsReceived({
    required String id,
    required DateTime actualDate,
    required double actualAmount,
  });

  /// Mark expected cash flow as missed
  /// Updates status to MISSED
  Future<void> markAsMissed(String id);

  // ============ BULK OPERATIONS ============

  /// Bulk create expected cash flows
  Future<void> bulkCreateExpectedCashFlows(
    List<ExpectedCashFlowEntity> expectedCashFlows,
  );

  /// Bulk delete expected cash flows
  Future<void> bulkDeleteExpectedCashFlows(List<String> ids);

  /// Delete all expected cash flows for a user (used in data lifecycle cleanup)
  Future<void> deleteAllExpectedCashFlows();
}
