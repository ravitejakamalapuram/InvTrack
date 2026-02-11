/// Providers for FIRE Number feature.
/// Handles FIRE settings, calculations, and projections.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/fire_number/data/repositories/firestore_fire_settings_repository.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

// ============ REPOSITORY PROVIDER ============

/// Provider for FIRE settings repository
final fireSettingsRepositoryProvider = Provider<FireSettingsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  final user = authState.value;
  if (user == null) {
    throw StateError('User not authenticated');
  }

  return FirestoreFireSettingsRepository(firestore: firestore, userId: user.id);
});

// ============ CALCULATION SERVICE ============

/// Provider for FIRE calculation service
final fireCalculationServiceProvider = Provider<FireCalculationService>((ref) {
  return FireCalculationService();
});

// ============ STREAM PROVIDERS ============

/// Watch FIRE settings (real-time updates)
/// Returns null if user hasn't set up FIRE settings yet
/// Uses autoDispose to clean up when no longer needed
/// Errors propagate to UI for proper error handling
final fireSettingsProvider = StreamProvider.autoDispose<FireSettingsEntity?>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return Stream.value(null);
  }
  // Let errors propagate to UI - FIRE dashboard handles AsyncValue.error properly
  return ref.watch(fireSettingsRepositoryProvider).watchSettings();
});

/// Check if FIRE setup is complete
final isFireSetupCompleteProvider = Provider<bool>((ref) {
  final settings = ref.watch(fireSettingsProvider).value;
  return settings?.isSetupComplete ?? false;
});

// ============ CALCULATION PROVIDERS ============

/// Calculate FIRE numbers based on settings and current portfolio
/// Uses autoDispose to clean up when no longer needed
final fireCalculationProvider = Provider.autoDispose<AsyncValue<FireCalculationResult>>((ref) {
  final settingsAsync = ref.watch(fireSettingsProvider);
  final portfolioStatsAsync = ref.watch(globalStatsProvider);

  return settingsAsync.when(
    data: (settings) {
      if (settings == null || !settings.isSetupComplete) {
        return AsyncValue.data(FireCalculationResult.empty());
      }

      return portfolioStatsAsync.when(
        data: (stats) {
          final service = ref.read(fireCalculationServiceProvider);
          // Use totalInvested as portfolio value since it represents
          // accumulated savings/capital, NOT netCashFlow which is profit/loss.
          // For FIRE calculation, we need total accumulated wealth.
          final currentPortfolioValue = stats.totalInvested;
          final result = service.calculate(
            settings: settings,
            currentPortfolioValue: currentPortfolioValue,
            currentMonthlySavings: _estimateMonthlySavings(stats),
          );
          return AsyncValue.data(result);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Estimate monthly savings from portfolio stats
double _estimateMonthlySavings(InvestmentStats stats) {
  if (stats.firstCashFlowDate == null || stats.lastCashFlowDate == null) {
    return 0;
  }
  final months = stats.lastCashFlowDate!
          .difference(stats.firstCashFlowDate!)
          .inDays /
      30;
  if (months <= 0) return 0;
  return stats.totalInvested / months;
}

/// Provider for FIRE progress percentage
final fireProgressProvider = Provider.autoDispose<double>((ref) {
  final calculation = ref.watch(fireCalculationProvider);
  return calculation.when(
    data: (result) => result.progressPercentage,
    loading: () => 0,
    error: (_, st) => 0,
  );
});

/// Provider for FIRE status
final fireStatusProvider = Provider.autoDispose<FireProgressStatus>((ref) {
  final calculation = ref.watch(fireCalculationProvider);
  return calculation.when(
    data: (result) => result.status,
    loading: () => FireProgressStatus.notStarted,
    error: (_, st) => FireProgressStatus.notStarted,
  );
});

/// Provider for projection points (for charts)
final fireProjectionsProvider = Provider.autoDispose<List<FireProjectionPoint>>((ref) {
  final settingsAsync = ref.watch(fireSettingsProvider);
  final calculationAsync = ref.watch(fireCalculationProvider);
  final portfolioStatsAsync = ref.watch(globalStatsProvider);

  final settings = settingsAsync.value;
  final calculation = calculationAsync.value;
  final stats = portfolioStatsAsync.value;

  if (settings == null || calculation == null || stats == null) {
    return [];
  }

  final service = ref.read(fireCalculationServiceProvider);
  return service.generateProjections(
    settings: settings,
    currentPortfolioValue: stats.totalInvested,
    monthlySavings: _estimateMonthlySavings(stats),
    fireNumber: calculation.fireNumber,
  );
});
