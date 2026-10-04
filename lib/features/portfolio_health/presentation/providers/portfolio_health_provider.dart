import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/portfolio_health/data/models/health_score_snapshot_model.dart';
import 'package:inv_tracker/features/portfolio_health/data/repositories/health_score_repository.dart';
import 'package:inv_tracker/features/portfolio_health/data/services/health_score_auto_save_service.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';

part 'portfolio_health_provider.g.dart';

/// Provider for Health Score Repository
@Riverpod(keepAlive: true)
HealthScoreRepository healthScoreRepository(
  Ref ref,
) {
  return HealthScoreRepository();
}

/// Provider for auto-save service
@Riverpod(keepAlive: true)
HealthScoreAutoSaveService healthScoreAutoSaveService(
  Ref ref,
) {
  final repository = ref.watch(healthScoreRepositoryProvider);
  final service = HealthScoreAutoSaveService(repository: repository);

  // Start auto-save when service is created
  service.start();

  // Stop auto-save when service is disposed
  ref.onDispose(() => service.dispose());

  return service;
}

/// Provider for Portfolio Health Score
///
/// Calculates health score based on:
/// - Returns Performance (30%): XIRR vs inflation
/// - Diversification (25%): Herfindahl index
/// - Liquidity (20%): % maturing in 90 days
/// - Goal Alignment (15%): % goals on-track
/// - Action Readiness (10%): Overdue renewals, stale investments
///
/// Worked out from one complete converted snapshot of the active portfolio
/// (amounts in the base currency, with current values): it stays loading
/// until that snapshot and the goals have loaded, so a partial score is
/// never shown or saved. Null means there is not enough data for a score.
@riverpod
class PortfolioHealth extends _$PortfolioHealth {
  @override
  Future<PortfolioHealthScore?> build() async {
    // Watch every dependency before the first await.
    final convertedFuture = ref.watch(convertedTerminalValuesProvider.future);
    final investmentsAsync = ref.watch(activeInvestmentsProvider);
    final goalProgressAsync = ref.watch(allGoalsProgressProvider);
    final asOf = ref.watch(valuationDateProvider);
    final engine = ref.watch(calculationEngineProvider);

    final converted = await convertedFuture;
    final investments = await dataOf(investmentsAsync);
    final goalProgress = await dataOf(goalProgressAsync);

    final cashFlows = converted.snapshot.cashFlows;
    final statsMap = engine.financial.calculateStatsByInvestment(
      cashFlows,
      // The returns component solves one portfolio XIRR instead.
      includeXirr: false,
      terminalValues: converted.byInvestment,
    );

    // Calculate health score using the unified calculation engine
    final score = engine.health.calculate(
      investments: investments,
      investmentStats: statsMap,
      allCashFlows: cashFlows,
      goalProgress: goalProgress,
      terminalValues: converted.byInvestment,
      asOf: asOf,
    );

    if (score == null) {
      // Not enough data: nothing to save, and an older score must not be
      // saved again either.
      try {
        ref.read(healthScoreAutoSaveServiceProvider).clearScore();
      } catch (e) {
        // Ignore - auto-save service issues shouldn't break the score
      }
      return null;
    }

    // Log analytics - score calculated (non-blocking, privacy-safe)
    try {
      final analytics = AnalyticsService();
      await analytics.logHealthScoreCalculated(
        scoreTier: getScoreTier(score.displayScore.toDouble()),
        investmentCount: investments.length,
        hasGoals: goalProgress.isNotEmpty,
      );
    } catch (e) {
      // Ignore - analytics failures shouldn't break score calculation
    }

    // Update auto-save service with latest score (non-blocking)
    try {
      final autoSaveService = ref.read(healthScoreAutoSaveServiceProvider);
      autoSaveService.updateScore(score);
    } catch (e) {
      // Ignore - auto-save service issues shouldn't break score calculation
    }

    return score;
  }
}

/// Provider for historical health score snapshots (last 12 weeks)
@riverpod
Stream<List<HealthScoreSnapshotModel>> historicalHealthScores(
  Ref ref,
) {
  final repository = ref.watch(healthScoreRepositoryProvider);
  return repository.watchHistoricalSnapshots(weeks: 12);
}

/// Provider for chart data (simplified for trend visualization)
@riverpod
Stream<List<Map<String, dynamic>>> healthScoreChartData(
  Ref ref,
) {
  final snapshotsStream = ref.watch(historicalHealthScoresProvider);

  return snapshotsStream.when(
    data: (snapshots) {
      return Stream.value(
        snapshots.map((s) => s.toChartData()).toList(),
      );
    },
    loading: () => Stream.value([]),
    error: (error, stackTrace) => Stream.value([]),
  );
}

/// Provider for latest health score value (for quick access)
@riverpod
double? latestHealthScoreValue(
  Ref ref,
) {
  final scoreAsync = ref.watch(portfolioHealthProvider);
  return scoreAsync.whenOrNull(data: (score) => score?.overallScore);
}

/// Provider for latest health score tier (for color coding)
@riverpod
ScoreTier? latestHealthScoreTier(
  Ref ref,
) {
  final scoreAsync = ref.watch(portfolioHealthProvider);
  return scoreAsync.whenOrNull(data: (score) => score?.tier);
}
