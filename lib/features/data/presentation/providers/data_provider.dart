import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/services/connectivity_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/data/data/controllers/data_controller_impl.dart';
import 'package:inv_tracker/features/data/domain/controllers/data_controller.dart';
import 'package:inv_tracker/features/sync/data/repositories/cloud_repository_impl.dart';

/// Provider for the DataController.
///
/// This is the main entry point for all data operations in the app.
/// It automatically handles:
/// - Cloud-first writes for Google users
/// - Local-only writes for Guest users
/// - Connectivity checks before cloud operations
final dataControllerProvider = Provider<DataController>((ref) {
  final localRepository = ref.watch(investmentRepositoryProvider);
  final cloudRepository = ref.watch(cloudRepositoryProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  final authState = ref.watch(authStateProvider);

  // Get current user from auth state
  final currentUser = authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );

  return DataControllerImpl(
    localRepository: localRepository,
    cloudRepository: cloudRepository,
    connectivityService: connectivityService,
    authRepository: authRepository,
    currentUser: currentUser,
  );
});

/// Provider for initialization state.
/// Call this when the app starts or when user changes.
final dataInitializationProvider = FutureProvider<void>((ref) async {
  final dataController = ref.watch(dataControllerProvider);
  final result = await dataController.initialize();

  if (result.isFailure) {
    // Log but don't throw - we can still use cached data
    // The UI will show appropriate messages
    throw Exception(result.error);
  }
});

/// Provider to check if we're currently offline.
final isOfflineProvider = FutureProvider<bool>((ref) async {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return !(await connectivityService.hasInternetConnection());
});

/// Provider to check if current user is a Google user.
final isGoogleUserProvider = Provider<bool>((ref) {
  final dataController = ref.watch(dataControllerProvider);
  return dataController.isGoogleUser;
});

