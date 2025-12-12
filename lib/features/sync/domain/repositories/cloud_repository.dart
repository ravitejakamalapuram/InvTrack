import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Repository for cloud (Google Sheets) operations.
/// 
/// This is the interface for all cloud data operations.
/// Cloud is the source of truth for Google users.
abstract class CloudRepository {
  // ============ INVESTMENTS ============

  /// Fetch all investments from Google Sheets.
  /// Returns empty list if spreadsheet doesn't exist or has no data.
  Future<List<InvestmentEntity>> fetchAllInvestments();

  /// Add investment to Google Sheets.
  /// Returns the investment (unchanged, as ID is generated locally).
  /// Throws exception on failure.
  Future<InvestmentEntity> addInvestment(InvestmentEntity investment);

  /// Update investment in Google Sheets (find by ID column).
  /// Throws exception if not found or on failure.
  Future<void> updateInvestment(InvestmentEntity investment);

  /// Delete investment from Google Sheets (find by ID column).
  /// Also deletes all associated cash flows.
  /// Throws exception on failure.
  Future<void> deleteInvestment(String investmentId);

  // ============ CASH FLOWS ============

  /// Fetch all cash flows from Google Sheets.
  /// Returns empty list if spreadsheet doesn't exist or has no data.
  Future<List<CashFlowEntity>> fetchAllCashFlows();

  /// Add cash flow to Google Sheets.
  /// Returns the cash flow (unchanged).
  /// Throws exception on failure.
  Future<CashFlowEntity> addCashFlow(CashFlowEntity cashFlow);

  /// Update cash flow in Google Sheets.
  /// Throws exception if not found or on failure.
  Future<void> updateCashFlow(CashFlowEntity cashFlow);

  /// Delete cash flow from Google Sheets.
  /// Throws exception on failure.
  Future<void> deleteCashFlow(String cashFlowId);

  // ============ BULK OPERATIONS ============

  /// Upload all local data to cloud (for guest upgrade).
  /// Clears existing cloud data and uploads all provided data.
  /// Throws exception on failure.
  Future<void> uploadAll(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  );

  /// Check if spreadsheet exists in Google Drive.
  Future<bool> hasSpreadsheet();

  /// Create spreadsheet if not exists, ensure sheets are set up.
  /// Returns spreadsheet ID.
  Future<String> ensureSpreadsheetExists();

  /// Get count of investments in cloud (without importing).
  Future<int> getInvestmentCount();
}

