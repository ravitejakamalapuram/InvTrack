import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/portfolio_health/data/models/health_score_snapshot_model.dart';
import 'package:inv_tracker/features/portfolio_health/data/repositories/health_score_repository.dart';
import 'package:inv_tracker/features/portfolio_health/data/services/health_score_auto_save_service.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/domain/services/portfolio_health_calculator.dart';

part 'portfolio_health_provider.g.dart';

/// Provider for Health Score Repository
@Riverpod(keepAlive: true)
HealthScoreRepository healthScoreRepository(ref) {
  return HealthScoreRepository();
}

/// Provider for auto-save service
@Riverpod(keepAlive: true)
HealthScoreAutoSaveService healthScoreAutoSaveService(ref) {
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
@riverpod
class PortfolioHealth extends _$PortfolioHealth {
  @override
  Future<PortfolioHealthScore?> build() async {
    // Watch all dependencies
    final investmentsAsync = ref.watch(allInvestmentsProvider);
    final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);
    final goalProgressAsync = ref.watch(allGoalsProgressProvider);

    // Wait for all data to load
    if (!investmentsAsync.hasValue ||
        !cashFlowsAsync.hasValue ||
        !goalProgressAsync.hasValue) {
      return null;
    }

    final investments = investmentsAsync.value ?? [];
    final cashFlows = cashFlowsAsync.value ?? [];
    final goalProgress = goalProgressAsync.value ?? [];

    // Build stats map for each investment
    final statsMap = <String, InvestmentStats>{};
    for (final inv in investments) {
      final invStats = ref.read(multiCurrencyInvestmentStatsProvider(inv.id));
      if (invStats.hasValue && invStats.value != null) {
        statsMap[inv.id] = invStats.value!;
      }
    }

    // Calculate health score
    final score = PortfolioHealthCalculator.calculate(
      investments: investments,
      investmentStats: statsMap,
      allCashFlows: cashFlows,
      goalProgress: goalProgress,
    );

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
Stream<List<HealthScoreSnapshotModel>> historicalHealthScores(ref) {
  final repository = ref.watch(healthScoreRepositoryProvider);
  return repository.watchHistoricalSnapshots(weeks: 12);
}

/// Provider for chart data (simplified for trend visualization)
@riverpod
Stream<List<Map<String, dynamic>>> healthScoreChartData(ref) {
  final snapshotsStream = ref.watch(historicalHealthScoresProvider);

  return snapshotsStream.when(
    data: (snapshots) {
      return Stream.value(
        snapshots.map((s) => s.toChartData()).toList(),
      );
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
}

/// Provider for latest health score value (for quick access)
@riverpod
double? latestHealthScoreValue(ref) {
  final scoreAsync = ref.watch(portfolioHealthProvider);
  return scoreAsync.whenOrNull(data: (score) => score?.overallScore);
}

/// Provider for latest health score tier (for color coding)
@riverpod
ScoreTier? latestHealthScoreTier(ref) {
  final scoreAsync = ref.watch(portfolioHealthProvider);
  return scoreAsync.whenOrNull(data: (score) => score?.tier);
}
