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
  /// Uses efficient bulk operation in a single transaction.
  Future<void> _replaceLocalData(
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
  ) async {
    await _localRepository.replaceAllData(investments, cashFlows);
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
  Future<Result<void>> connectToGoogle({required bool uploadLocalData}) async {
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      return Result.failure('No internet connection');
    }

    try {
      // Store local data before sign-in (in case we need to upload)
      // IMPORTANT: Capture data BEFORE sign-in because _localRepository
      // points to the guest's database, which will become stale after sign-in
      final localInvestments = await _localRepository.getAllInvestments();
      final localCashFlows = await _localRepository.getAllCashFlows();

      // Sign in with Google
      // This creates a new user with a new database ID and emits to auth stream.
      // app.dart will catch the auth change and update currentUserIdProvider,
      // which triggers creation of a NEW database for the new user.
      final user = await _authRepository.signInWithGoogle();

      if (user == null || user.isGuest) {
        return Result.failure('Google sign-in was cancelled');
      }

      if (uploadLocalData) {
        // Upload local data to cloud
        // NOTE: We do NOT write to _localRepository here because it still points
        // to the OLD guest database. The app.dart auth listener will call
        // initialize() -> refreshFromCloud() which will fetch from cloud and
        // write to the NEW user's database.
        if (localInvestments.isNotEmpty || localCashFlows.isNotEmpty) {
          await _cloudRepository.uploadAll(localInvestments, localCashFlows);
          debugPrint('[DataController] Uploaded ${localInvestments.length} investments to cloud');
        }
      }
      // For both upload and download cases:
      // - app.dart's auth listener will update currentUserIdProvider
      // - This triggers creation of new database and new DataController instance
      // - app.dart then calls initialize() which calls refreshFromCloud()
      // - Cloud data (including just-uploaded data) will be synced to new local DB

      debugPrint('[DataController] Google sign-in complete. App will sync data on auth change.');
      return Result.success(null);
    } catch (e) {
      debugPrint('[DataController] Failed to connect to Google: $e');
      return Result.failure('Failed to connect to Google: $e');
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      // Clear local data on sign out using bulk operation
      await _localRepository.clearAllData();
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
    return await _localRepository.hasData();
  }

  @override
  Future<bool> hasCloudData() async {
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) return false;

    try {
      final count = await _cloudRepository.getInvestmentCount();
      return count > 0;
    } catch (e) {
      debugPrint('[DataController] Failed to check cloud data: $e');
      return false;
    }
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

