/// Portfolio Health Score Details Screen
///
/// Shows complete breakdown of health score with:
/// - Overall score
/// - 5 component scores with drill-down
/// - Historical trend chart
/// - Top 3 action suggestions
/// - Social sharing
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/health_score_trend_chart.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/score_improvement_badge.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Portfolio Health Details Screen
class PortfolioHealthDetailsScreen extends ConsumerWidget {
  const PortfolioHealthDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Check if feature is enabled - if not, redirect to overview
    final isEnabled = ref.watch(isPortfolioHealthEnabledProvider);

    if (!isEnabled) {
      // Feature disabled - redirect to overview
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scoreAsync = ref.watch(portfolioHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.portfolioHealthDetails),
        leading: IconButton(
          tooltip: l10n.tooltipBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareScore(context, scoreAsync.value),
            tooltip: l10n.share,
          ),
        ],
      ),
      body: scoreAsync.when(
        data: (score) {
          if (score == null) {
            return _buildEmptyState(context, isDark);
          }
          return _buildContent(context, isDark, score);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          final appException = ErrorHandler.mapException(error, stackTrace);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  appException.userMessage,
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Trigger re-fetch by invalidating the provider
                    ref.invalidate(portfolioHealthProvider);
                  },
                  child: Text(AppLocalizations.of(context).retry),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noPortfolioData,
              style: AppTypography.h2.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.addInvestmentsToSeeHealth,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    PortfolioHealthScore score,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall Score Card
          _buildOverallScoreCard(isDark, score),
          const SizedBox(height: AppSpacing.xl),

          // Improvement Badge
          const Center(child: ScoreImprovementBadge()),
          const SizedBox(height: AppSpacing.xl),

          // Trend Chart
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).historicalTrend,
                  style: AppTypography.h3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                const HealthScoreTrendChart(height: 200),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Component Scores
          _buildComponentScoresSection(context, isDark, score),
          const SizedBox(height: AppSpacing.xl),

          // Top Suggestions
          _buildSuggestionsSection(context, isDark, score),
        ],
      ),
    );
  }

  Widget _buildOverallScoreCard(bool isDark, PortfolioHealthScore score) {
    final tier = score.tier;
    final color = _getTierColor(tier, isDark);

    return GlassCard(
      child: Column(
        children: [
          // Score Circle
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.0),
                ],
              ),
              border: Border.all(color: color, width: 8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    score.overallScore.round().toString(),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 16,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tier label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tier.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(tier.label, style: AppTypography.h2.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 8),
          // Tier message
          Text(
            tier.message,
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComponentScoresSection(
    BuildContext context,
    bool isDark,
    PortfolioHealthScore score,
  ) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.componentBreakdown,
          style: AppTypography.h3.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 16),
        _buildComponentCard(
          isDark,
          score.returnsPerformance,
          Icons.trending_up,
        ),
        const SizedBox(height: 12),
        _buildComponentCard(isDark, score.diversification, Icons.pie_chart),
        const SizedBox(height: 12),
        _buildComponentCard(isDark, score.liquidity, Icons.water_drop),
        const SizedBox(height: 12),
        _buildComponentCard(isDark, score.goalAlignment, Icons.flag),
        const SizedBox(height: 12),
        _buildComponentCard(isDark, score.actionReadiness, Icons.check_circle),
      ],
    );
  }

  Widget _buildComponentCard(
    bool isDark,
    ComponentScore component,
    IconData icon,
  ) {
    final color = _getScoreColor(component.score, isDark);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      style: AppTypography.h4.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      component.description,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${component.score.round()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          // Progress bar
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: component.score / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection(
    BuildContext context,
    bool isDark,
    PortfolioHealthScore score,
  ) {
    final l10n = AppLocalizations.of(context);
    final suggestions = score.topSuggestions;

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.topSuggestions,
          style: AppTypography.h3.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 16),
        ...suggestions.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildSuggestionCard(isDark, entry.key + 1, entry.value),
          );
        }),
      ],
    );
  }

  Widget _buildSuggestionCard(bool isDark, int number, String suggestion) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.accentDark : AppColors.accentLight,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              suggestion,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(ScoreTier tier, bool isDark) {
    switch (tier) {
      case ScoreTier.excellent:
        return isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
      case ScoreTier.good:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
      case ScoreTier.fair:
        return isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);
      case ScoreTier.poor:
        return isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    }
  }

  Color _getScoreColor(double score, bool isDark) {
    if (score >= 80) {
      return isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
    } else if (score >= 60) {
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
    } else if (score >= 40) {
      return isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);
    } else {
      return isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    }
  }

  Future<void> _shareScore(
    BuildContext context,
    PortfolioHealthScore? score,
  ) async {
    if (score == null) return;

    HapticFeedback.lightImpact();

    final l10n = AppLocalizations.of(context);

    // TODO(@ravitejakamalapuram, 2026-04-06, #322): Generate score card image and share
    // For now, share text using localized template
    final text = l10n.shareScoreText(
      score.overallScore.round(),
      score.tier.label,
      score.returnsPerformance.score.round(),
      score.diversification.score.round(),
      score.liquidity.score.round(),
      score.goalAlignment.score.round(),
      score.actionReadiness.score.round(),
    );

    // Use share package or clipboard
    await Clipboard.setData(ClipboardData(text: text));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).scoreCopiedToClipboard),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
