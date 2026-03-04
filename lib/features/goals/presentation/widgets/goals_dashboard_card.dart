/// Goals dashboard card for the overview screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_carousel_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// A card showing goals summary for the overview/dashboard screen.
class GoalsDashboardCard extends ConsumerStatefulWidget {
  const GoalsDashboardCard({super.key});

  @override
  ConsumerState<GoalsDashboardCard> createState() => _GoalsDashboardCardState();
}

class _GoalsDashboardCardState extends ConsumerState<GoalsDashboardCard> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.85, // Show 15% of next card (more visible peek)
    );
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;

      final summaryAsync = ref.read(goalsSummaryProvider);
      summaryAsync.whenData((summary) {
        if (summary.activeGoals.isEmpty) return;

        final nextPage = (_currentPage + 1) % summary.activeGoals.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(goalsSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return summaryAsync.when(
      data: (summary) {
        if (!summary.hasGoals) {
          return _buildEmptyState(context, isDark);
        }
        return _buildGoalsCarousel(context, summary, isDark);
      },
      loading: () => _buildLoadingState(isDark),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      onTap: () => context.push('/goals/create'),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.flag_outlined,
              color: AppColors.primaryLight,
              size: 28,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.setYourFirstGoal,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.trackProgressTowardsTargets,
                  style: AppTypography.small.copyWith(
                    color: isDark ? Colors.white70 : AppColors.neutral600Light,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white54 : AppColors.neutral400Light,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsCarousel(
    BuildContext context,
    GoalsSummary summary,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with achievement badge
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.goals,
                style: AppTypography.h4.copyWith(
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.goalsAchieved(summary.achievedGoals, summary.totalGoals),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.successLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sm), // Reduced from md to sm

        // PageView carousel with peek and scale animation
        if (summary.activeGoals.isNotEmpty)
          SizedBox(
            height: 110, // Compact height
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: summary.activeGoals.length,
              padEnds: false, // Allow peek effect
              clipBehavior: Clip.none, // Don't clip peeked cards
              itemBuilder: (context, index) {
                final progress = summary.activeGoals[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    // Calculate scale based on page position
                    double scale = 0.92; // Default scale for peeked cards
                    if (_pageController.hasClients && _pageController.position.haveDimensions) {
                      final page = _pageController.page ?? _currentPage.toDouble();
                      final diff = (page - index).abs();
                      // Active card: scale 1.0, peeked cards: scale 0.92
                      scale = 1.0 - (diff.clamp(0.0, 1.0) * 0.08);
                    } else if (index == _currentPage) {
                      scale = 1.0; // Current page is full scale
                    }

                    return Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                        child: GoalCarouselCard(
                          progress: progress,
                          width: double.infinity,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return GlassCard(
      child: SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? Colors.white54 : AppColors.neutral400Light,
          ),
        ),
      ),
    );
  }
}
