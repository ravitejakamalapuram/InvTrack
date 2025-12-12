import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/services/connectivity_service.dart';
import 'package:inv_tracker/core/utils/result.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/data/domain/controllers/data_controller.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/sync/domain/repositories/cloud_repository.dart';

/// Implementation of DataController that orchestrates cloud and local operations.
///
/// Key principles:
/// - Guest users: All operations are local-only
/// - Google users: Cloud-first with local cache
/// - No internet for Google users: Block write operations, show toast
class DataControllerImpl implements DataController {
  final InvestmentRepository _localRepository;
  final CloudRepository _cloudRepository;
  final ConnectivityService _connectivityService;
  final AuthRepository _authRepository;
  final UserEntity? _currentUser;

  DataControllerImpl({
    required InvestmentRepository localRepository,
    required CloudRepository cloudRepository,
    required ConnectivityService connectivityService,
    required AuthRepository authRepository,
    required UserEntity? currentUser,
  })  : _localRepository = localRepository,
        _cloudRepository = cloudRepository,
        _connectivityService = connectivityService,
        _authRepository = authRepository,
        _currentUser = currentUser;

  @override
  bool get isGoogleUser => _currentUser != null && !_currentUser.isGuest;

  @override
  Future<bool> get isOffline async => !(await _connectivityService.hasInternetConnection());

  // ============ INITIALIZATION ============

  @override
  Future<Result<void>> initialize() async {
    debugPrint('[DataController] Initializing for user: ${_currentUser?.email ?? "none"}');

    if (_currentUser == null) {
      return Result.success(null);
    }

    if (_currentUser.isGuest) {
      // Guest: Data is already in local DB, nothing to do
      debugPrint('[DataController] Guest user - using local data');
      return Result.success(null);
    }

    // Google user: Fetch from cloud and cache locally
    return await refreshFromCloud();
  }

  @override
  Future<Result<void>> refreshFromCloud() async {
    if (!isGoogleUser) {
      debugPrint('[DataController] Not a Google user - skipping cloud refresh');
      return Result.success(null);
    }

    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      debugPrint('[DataController] No internet - cannot refresh from cloud');
      return Result.failure('No internet connection');
    }

    try {
      debugPrint('[DataController] Fetching data from cloud...');

      // Fetch all data from cloud
      final investments = await _cloudRepository.fetchAllInvestments();
      final cashFlows = await _cloudRepository.fetchAllCashFlows();

      debugPrint('[DataController] Fetched ${investments.length} investments, ${cashFlows.length} cash flows');

      // Replace local cache with cloud data
      await _replaceLocalData(investments, cashFlows);

      debugPrint('[DataController] Local cache updated from cloud');
      return Result.success(null);
    } catch (e) {
      debugPrint('[DataController] Error refreshing from cloud: $e');
      return Result.failure('Failed to sync with cloud: $e');
    }
  }

  /// Replace all local data with the provided data.
  Future<void> _replaceLocalData(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  ) async {
    // Get existing data to delete
    final existingInvestments = await _localRepository.getAllInvestments();
    final existingCashFlows = await _localRepository.getAllCashFlows();

    // Delete all existing cash flows first (due to foreign key)
    for (final cf in existingCashFlows) {
      await _localRepository.deleteCashFlow(cf.id);
    }

    // Delete all existing investments
    for (final inv in existingInvestments) {
      // Use direct delete to avoid cascade (already deleted cash flows)
      await _localRepository.deleteInvestment(inv.id);
    }

    // Insert new investments
    for (final inv in investments) {
      await _localRepository.createInvestment(inv);
    }

    // Insert new cash flows
    for (final cf in cashFlows) {
      await _localRepository.addCashFlow(cf);
    }
  }

  // ============ INVESTMENTS - READ ============

  @override
  Future<List<InvestmentEntity>> getInvestments() async {
    return await _localRepository.getAllInvestments();
  }

  @override
  Stream<List<InvestmentEntity>> watchInvestments() {
    return _localRepository.watchAllInvestments();
  }

  @override
  Future<InvestmentEntity?> getInvestmentById(String id) async {
    return await _localRepository.getInvestmentById(id);
  }

  // ============ INVESTMENTS - WRITE ============

  @override
  Future<Result<InvestmentEntity>> addInvestment(InvestmentEntity investment) async {
    if (isGoogleUser) {
      // Cloud-first for Google users
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        return Result.failure('No internet connection');
      }

      try {
        // Write to cloud first
        await _cloudRepository.addInvestment(investment);
        // Then cache locally
        await _localRepository.createInvestment(investment);
        debugPrint('[DataController] Added investment to cloud and cache: ${investment.name}');
        return Result.success(investment);
      } catch (e) {
        debugPrint('[DataController] Failed to add investment to cloud: $e');
        return Result.failure('Failed to save: $e');
      }
    } else {
      // Guest: Local only
      try {
        await _localRepository.createInvestment(investment);
        debugPrint('[DataController] Added investment locally: ${investment.name}');
        return Result.success(investment);
      } catch (e) {
        debugPrint('[DataController] Failed to add investment locally: $e');
        return Result.failure('Failed to save: $e');
      }
    }
  }

  @override
  Future<Result<void>> updateInvestment(InvestmentEntity investment) async {
    if (isGoogleUser) {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        return Result.failure('No internet connection');
      }

      try {
        await _cloudRepository.updateInvestment(investment);
        await _localRepository.updateInvestment(investment);
        debugPrint('[DataController] Updated investment in cloud and cache: ${investment.name}');
        return Result.success(null);
      } catch (e) {
        debugPrint('[DataController] Failed to update investment: $e');
        return Result.failure('Failed to update: $e');
      }
    } else {
      try {
        await _localRepository.updateInvestment(investment);
        return Result.success(null);
      } catch (e) {
        return Result.failure('Failed to update: $e');
      }
    }
  }

  @override
  Future<Result<void>> deleteInvestment(String investmentId) async {
    if (isGoogleUser) {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        return Result.failure('No internet connection');
      }

      try {
        await _cloudRepository.deleteInvestment(investmentId);
        await _localRepository.deleteInvestment(investmentId);
        debugPrint('[DataController] Deleted investment from cloud and cache: $investmentId');
        return Result.success(null);
      } catch (e) {
        debugPrint('[DataController] Failed to delete investment: $e');
        return Result.failure('Failed to delete: $e');
      }
    } else {
      try {
        await _localRepository.deleteInvestment(investmentId);
        return Result.success(null);
      } catch (e) {
        return Result.failure('Failed to delete: $e');
      }
    }
  }

  @override
  Future<Result<void>> closeInvestment(String investmentId) async {
    final investment = await _localRepository.getInvestmentById(investmentId);
    if (investment == null) {
      return Result.failure('Investment not found');
    }

    final closedInvestment = InvestmentEntity(
      id: investment.id,
      name: investment.name,
      type: investment.type,
      status: InvestmentStatus.closed,
      notes: investment.notes,
      createdAt: investment.createdAt,
      closedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await updateInvestment(closedInvestment);
  }

  @override
  Future<Result<void>> reopenInvestment(String investmentId) async {
    final investment = await _localRepository.getInvestmentById(investmentId);
    if (investment == null) {
      return Result.failure('Investment not found');
    }

    final reopenedInvestment = InvestmentEntity(
      id: investment.id,
      name: investment.name,
      type: investment.type,
      status: InvestmentStatus.open,
      notes: investment.notes,
      createdAt: investment.createdAt,
      closedAt: null,
      updatedAt: DateTime.now(),
    );

    return await updateInvestment(reopenedInvestment);
  }

  // ============ CASH FLOWS ============

  @override
  Future<List<CashFlowEntity>> getAllCashFlows() async {
    return await _localRepository.getAllCashFlows();
  }

  @override
  Future<List<CashFlowEntity>> getCashFlowsByInvestment(String investmentId) async {
    return await _localRepository.getCashFlowsByInvestment(investmentId);
  }

  @override
  Stream<List<CashFlowEntity>> watchCashFlowsByInvestment(String investmentId) {
    return _localRepository.watchCashFlowsByInvestment(investmentId);
  }

  @override
  Future<Result<CashFlowEntity>> addCashFlow(CashFlowEntity cashFlow) async {
    if (isGoogleUser) {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        return Result.failure('No internet connection');
      }

      try {
        await _cloudRepository.addCashFlow(cashFlow);
        await _localRepository.addCashFlow(cashFlow);
        debugPrint('[DataController] Added cash flow to cloud and cache: ${cashFlow.id}');
        return Result.success(cashFlow);
      } catch (e) {
        debugPrint('[DataController] Failed to add cash flow: $e');
        return Result.failure('Failed to save: $e');
      }
    } else {
      try {
        await _localRepository.addCashFlow(cashFlow);
        return Result.success(cashFlow);
      } catch (e) {
        return Result.failure('Failed to save: $e');
      }
    }
  }

  @override
  Future<Result<void>> updateCashFlow(CashFlowEntity cashFlow) async {
    if (isGoogleUser) {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        return Result.failure('No internet connection');
      }

      try {
        await _cloudRepository.updateCashFlow(cashFlow);
        await _localRepository.updateCashFlow(cashFlow);
        return Result.success(null);
      } catch (e) {
        return Result.failure('Failed to update: $e');
      }
    } else {
      try {
        await _localRepository.updateCashFlow(cashFlow);
        return Result.success(null);
      } catch (e) {
        return Result.failure('Failed to update: $e');
      }
    }
  }

  @override
  Future<Result<void>> deleteCashFlow(String cashFlowId) async {
    if (isGoogleUser) {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        return Result.failure('No internet connection');
      }

      try {
        await _cloudRepository.deleteCashFlow(cashFlowId);
        await _localRepository.deleteCashFlow(cashFlowId);
        return Result.success(null);
      } catch (e) {
        return Result.failure('Failed to delete: $e');
      }
    } else {
      try {
        await _localRepository.deleteCashFlow(cashFlowId);
        return Result.success(null);
      } catch (e) {
        return Result.failure('Failed to delete: $e');
      }
    }
  }

  // ============ ACCOUNT OPERATIONS ============

  @override
  Future<Result<void>> connectToGoogle() async {
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      return Result.failure('No internet connection');
    }

    try {
      // Sign in with Google
      final user = await _authRepository.signInWithGoogle();

      if (user == null || user.isGuest) {
        return Result.failure('Google sign-in was cancelled');
      }

      // Upload local data to cloud
      final investments = await _localRepository.getAllInvestments();
      final cashFlows = await _localRepository.getAllCashFlows();

      if (investments.isNotEmpty || cashFlows.isNotEmpty) {
        await _cloudRepository.uploadAll(investments, cashFlows);
        debugPrint('[DataController] Uploaded ${investments.length} investments to cloud');
      }

      return Result.success(null);
    } catch (e) {
      debugPrint('[DataController] Failed to connect to Google: $e');
      return Result.failure('Failed to connect to Google: $e');
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      // Clear local data on sign out
      final investments = await _localRepository.getAllInvestments();
      for (final inv in investments) {
        await _localRepository.deleteInvestment(inv.id);
      }
      debugPrint('[DataController] Cleared local data on sign out');

      // Sign out from auth
      await _authRepository.signOut();

      return Result.success(null);
    } catch (e) {
      debugPrint('[DataController] Failed to sign out: $e');
      return Result.failure('Failed to sign out: $e');
    }
  }

  @override
  Future<bool> hasLocalData() async {
    final investments = await _localRepository.getAllInvestments();
    return investments.isNotEmpty;
  }

  @override
  Future<int> getCloudInvestmentCount() async {
    if (!isGoogleUser) return 0;

    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) return 0;

    try {
      return await _cloudRepository.getInvestmentCount();
    } catch (e) {
      debugPrint('[DataController] Failed to get cloud investment count: $e');
      return 0;
    }
  }
}

