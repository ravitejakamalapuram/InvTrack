/// Provider for managing sample data mode.
/// Tracks whether user is exploring with sample data and provides
/// actions to activate, keep, or clear sample data.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/settings/data/services/sample_data_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

// ============ SAMPLE DATA MODE STATE ============

/// State for sample data mode
class SampleDataState {
  /// Whether sample data mode is active
  final bool isActive;

  /// Whether sample data is currently being loaded
  final bool isLoading;

  /// Error message if sample data operation failed
  final String? error;

  /// IDs of sample investments (for cleanup)
  final List<String> sampleInvestmentIds;

  /// IDs of sample goals (for cleanup)
  final List<String> sampleGoalIds;

  const SampleDataState({
    this.isActive = false,
    this.isLoading = false,
    this.error,
    this.sampleInvestmentIds = const [],
    this.sampleGoalIds = const [],
  });

  SampleDataState copyWith({
    bool? isActive,
    bool? isLoading,
    String? error,
    List<String>? sampleInvestmentIds,
    List<String>? sampleGoalIds,
  }) {
    return SampleDataState(
      isActive: isActive ?? this.isActive,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sampleInvestmentIds: sampleInvestmentIds ?? this.sampleInvestmentIds,
      sampleGoalIds: sampleGoalIds ?? this.sampleGoalIds,
    );
  }
}

// ============ PROVIDERS ============

/// Provider for the sample data service
final sampleDataServiceProvider = Provider<SampleDataService>((ref) {
  return SampleDataService(
    ref.watch(investmentRepositoryProvider),
    ref.watch(goalRepositoryProvider),
  );
});

/// Provider for sample data mode state and actions
final sampleDataModeProvider =
    NotifierProvider<SampleDataModeNotifier, SampleDataState>(
      SampleDataModeNotifier.new,
    );

/// Notifier for managing sample data mode
class SampleDataModeNotifier extends Notifier<SampleDataState> {
  static const _prefKey = 'sample_data_mode_active';
  static const _investmentIdsKey = 'sample_data_investment_ids';
  static const _goalIdsKey = 'sample_data_goal_ids';

  @override
  SampleDataState build() {
    // Load persisted state
    final prefs = ref.watch(sharedPreferencesProvider);
    final isActive = prefs.getBool(_prefKey) ?? false;
    final investmentIds = prefs.getStringList(_investmentIdsKey) ?? [];
    final goalIds = prefs.getStringList(_goalIdsKey) ?? [];

    return SampleDataState(
      isActive: isActive,
      sampleInvestmentIds: investmentIds,
      sampleGoalIds: goalIds,
    );
  }

  /// Activate sample data mode by creating sample investments
  Future<bool> activateSampleData() async {
    if (state.isActive || state.isLoading) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(sampleDataServiceProvider);
      final result = await service.createSampleData();

      // Persist state
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_prefKey, true);
      await prefs.setStringList(_investmentIdsKey, result.investmentIds);
      await prefs.setStringList(_goalIdsKey, result.goalIds);

      state = SampleDataState(
        isActive: true,
        isLoading: false,
        sampleInvestmentIds: result.investmentIds,
        sampleGoalIds: result.goalIds,
      );

      // Track analytics
      ref
          .read(analyticsServiceProvider)
          .logSampleDataActivated(
            investmentCount: result.investmentIds.length,
            goalCount: result.goalIds.length,
          );

      LoggerService.info('Sample data activated', metadata: {
        'investmentCount': result.investmentIds.length,
        'goalCount': result.goalIds.length,
      });

      return true;
    } catch (e, st) {
      LoggerService.error('Sample data activation failed', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Keep sample data as real data (exit sample mode but keep data)
  Future<void> keepSampleData() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_prefKey, false);
    await prefs.remove(_investmentIdsKey);
    await prefs.remove(_goalIdsKey);

    ref
        .read(analyticsServiceProvider)
        .logSampleDataKept(
          investmentCount: state.sampleInvestmentIds.length,
          goalCount: state.sampleGoalIds.length,
        );

    state = const SampleDataState(isActive: false);

    LoggerService.info('Sample data kept as real data');
  }

  /// Clear sample data and exit sample mode
  Future<void> clearSampleData() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final service = ref.read(sampleDataServiceProvider);
      await service.clearSampleData(
        investmentIds: state.sampleInvestmentIds,
        goalIds: state.sampleGoalIds,
      );

      // Clear persisted state
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_prefKey, false);
      await prefs.remove(_investmentIdsKey);
      await prefs.remove(_goalIdsKey);

      ref
          .read(analyticsServiceProvider)
          .logSampleDataCleared(
            investmentCount: state.sampleInvestmentIds.length,
            goalCount: state.sampleGoalIds.length,
          );

      state = const SampleDataState(isActive: false);

      LoggerService.info('Sample data cleared');
    } catch (e, st) {
      LoggerService.error('Sample data clear failed', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
