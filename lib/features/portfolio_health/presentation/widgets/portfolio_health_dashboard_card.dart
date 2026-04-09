import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/widgets/score_improvement_badge.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Dashboard card showing Portfolio Health Score
///
/// Displays overall health score (0-100) as a circular progress indicator
/// with color-coded tiers (green/yellow/orange/red)
class PortfolioHealthDashboardCard extends ConsumerWidget {
  const PortfolioHealthDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if feature is enabled
    final isEnabled = ref.watch(isPortfolioHealthEnabledProvider);

    if (!isEnabled) {
      return const SizedBox.shrink(); // Hide card if feature disabled
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scoreAsync = ref.watch(portfolioHealthProvider);

    return scoreAsync.when(
      data: (score) {
        if (score == null) {
          return _buildEmptyCard(context, isDark);
        }
        return _buildScoreCard(context, isDark, score);
      },
      loading: () => _buildLoadingCard(context, isDark),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyCard(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/portfolio-health');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_outline,
                color: isDark ? AppColors.accentDark : AppColors.accentLight,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.portfolioHealth,
                  style: AppTypography.h3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.addInvestmentsToSeeHealth,
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_outline,
                color: isDark ? AppColors.accentDark : AppColors.accentLight,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.portfolioHealth,
                style: AppTypography.h3.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.accentDark : AppColors.accentLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(
    BuildContext context,
    bool isDark,
    PortfolioHealthScore score,
  ) {
    final tier = score.tier;
    final color = _getTierColor(tier, isDark);

    return GlassCard(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/portfolio-health');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.portfolioHealth,
                  style: AppTypography.h3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Text(
                tier.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Circular progress ring
          Center(
            child: _HealthScoreRing(score: score.overallScore, color: color),
          ),
          const SizedBox(height: 16),
          // Score tier label and message
          Text(
            tier.label,
            style: AppTypography.h3.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Score improvement badge
          const Center(child: ScoreImprovementBadge()),
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
}

/// Circular progress ring showing health score
class _HealthScoreRing extends StatelessWidget {
  final double score; // 0-100
  final Color color;

  const _HealthScoreRing({
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (score / 100).clamp(0.0, 1.0);
    const size = 120.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 12,
              color: color.withValues(alpha: 0.2),
              backgroundColor: Colors.transparent,
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: Transform.rotate(
              angle: -math.pi / 2, // Start from top
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 12,
                color: color,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          // Score text with accessibility
          Semantics(
            label: AppLocalizations.of(context).healthScoreOutOf100(score.round()),
            readOnly: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.round().toString(),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '/ 100',
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

