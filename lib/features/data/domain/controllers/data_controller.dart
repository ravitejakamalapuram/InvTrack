import 'package:inv_tracker/core/utils/result.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Controller for orchestrating data operations between cloud and local storage.
/// 
/// This is the main entry point for all data operations in the app.
/// It handles:
/// - Cloud-first writes for Google users
/// - Local-only writes for Guest users  
/// - Connectivity checks before cloud operations
/// - Caching cloud data locally for fast reads
abstract class DataController {
  // ============ INITIALIZATION ============

  /// Initialize data on app start.
  /// - Guest: Load from local
  /// - Google: Fetch from cloud, cache locally
  /// 
  /// Returns Result.failure if cloud fetch fails (for Google users).
  Future<Result<void>> initialize();

  /// Refresh data from cloud (for Google users only).
  /// For guest users, this is a no-op.
  Future<Result<void>> refreshFromCloud();

  // ============ INVESTMENTS ============

  /// Get all investments (always from local cache).
  Future<List<InvestmentEntity>> getInvestments();

  /// Watch all investments as a stream (for reactive UI).
  Stream<List<InvestmentEntity>> watchInvestments();

  /// Get investment by ID.
  Future<InvestmentEntity?> getInvestmentById(String id);

  /// Add investment.
  /// - Guest: Local only
  /// - Google: Cloud first, then cache
  Future<Result<InvestmentEntity>> addInvestment(InvestmentEntity investment);

  /// Update investment.
  Future<Result<void>> updateInvestment(InvestmentEntity investment);

  /// Delete investment.
  Future<Result<void>> deleteInvestment(String investmentId);

  /// Close investment.
  Future<Result<void>> closeInvestment(String investmentId);

  /// Reopen investment.
  Future<Result<void>> reopenInvestment(String investmentId);

  // ============ CASH FLOWS ============

  /// Get all cash flows.
  Future<List<CashFlowEntity>> getAllCashFlows();

  /// Get cash flows for an investment.
  Future<List<CashFlowEntity>> getCashFlowsByInvestment(String investmentId);

  /// Watch cash flows for an investment as a stream.
  Stream<List<CashFlowEntity>> watchCashFlowsByInvestment(String investmentId);

  /// Add cash flow.
  Future<Result<CashFlowEntity>> addCashFlow(CashFlowEntity cashFlow);

  /// Update cash flow.
  Future<Result<void>> updateCashFlow(CashFlowEntity cashFlow);

  /// Delete cash flow.
  Future<Result<void>> deleteCashFlow(String cashFlowId);

  // ============ ACCOUNT OPERATIONS ============

  /// Connect guest account to Google.
  /// [uploadLocalData] - If true, uploads local data to cloud.
  ///                     If false, replaces local data with cloud data.
  Future<Result<void>> connectToGoogle({required bool uploadLocalData});

  /// Sign out and clear local data.
  Future<Result<void>> signOut();

  /// Check if local database has any data.
  Future<bool> hasLocalData();

  /// Check if cloud has any data (for the current signed-in user).
  /// Must be called after Google sign-in is initiated but before connect completes.
  Future<bool> hasCloudData();

  /// Get count of investments in cloud (without importing).
  /// Returns 0 for guest users.
  Future<int> getCloudInvestmentCount();

  // ============ STATUS ============

  /// Returns true if the current user is a Google user.
  bool get isGoogleUser;

  /// Returns true if we're currently offline (no internet).
  Future<bool> get isOffline;
}

