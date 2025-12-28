import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';

/// Skeleton loader for the hero card on overview screen
class HeroCardSkeleton extends StatelessWidget {
  const HeroCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: GlassHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: 120, height: 14),
            const SizedBox(height: 12),
            _SkeletonBox(width: 180, height: 36),
            const SizedBox(height: 8),
            _SkeletonBox(width: 100, height: 14),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for quick stats cards
class QuickStatsSkeleton extends StatelessWidget {
  const QuickStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerEffect(
      child: Row(
        children: [
          Expanded(child: _QuickStatCardSkeleton(isDark: isDark)),
          const SizedBox(width: 12),
          Expanded(child: _QuickStatCardSkeleton(isDark: isDark)),
        ],
      ),
    );
  }
}

class _QuickStatCardSkeleton extends StatelessWidget {
  final bool isDark;
  const _QuickStatCardSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.neutral700Dark
                  : AppColors.neutral200Light,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: 50, height: 12, isDark: isDark),
              const SizedBox(height: 6),
              _SkeletonBox(width: 70, height: 18, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for section cards (Net Position, Monthly Trend, etc.)
class SectionCardSkeleton extends StatelessWidget {
  final double height;
  const SectionCardSkeleton({super.key, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerEffect(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: 140, height: 16, isDark: isDark),
            const SizedBox(height: 16),
            _SkeletonBox(
              width: double.infinity,
              height: height - 60,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for investment list items
class InvestmentCardSkeleton extends StatelessWidget {
  const InvestmentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerEffect(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 140, height: 16, isDark: isDark),
                  const SizedBox(height: 8),
                  _SkeletonBox(width: 100, height: 12, isDark: isDark),
                ],
              ),
            ),
            // Right side placeholder
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _SkeletonBox(width: 80, height: 16, isDark: isDark),
                const SizedBox(height: 8),
                _SkeletonBox(width: 50, height: 12, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for investment list screen
class InvestmentListSkeleton extends StatelessWidget {
  const InvestmentListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: const InvestmentCardSkeleton(),
          ),
          childCount: 5,
        ),
      ),
    );
  }
}

/// Skeleton loader for cash flow list items
class CashFlowCardSkeleton extends StatelessWidget {
  const CashFlowCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerEffect(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 80, height: 14, isDark: isDark),
                  const SizedBox(height: 6),
                  _SkeletonBox(width: 100, height: 12, isDark: isDark),
                ],
              ),
            ),
            _SkeletonBox(width: 70, height: 18, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for stats cards in investment detail screen
class StatsCardsSkeleton extends StatelessWidget {
  const StatsCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerEffect(
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: index > 0 ? 12 : 0),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.neutral700Dark
                            : AppColors.neutral200Light,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SkeletonBox(width: 60, height: 20, isDark: isDark),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 50, height: 12, isDark: isDark),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Reusable skeleton box for placeholders
class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final bool isDark;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final actualIsDark =
        isDark || Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: actualIsDark
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.neutral200Light,
        borderRadius: BorderRadius.circular(height / 3),
      ),
    );
  }
}

/// Full screen loading overlay with animated logo
class FullScreenLoading extends StatelessWidget {
  final String? message;
  const FullScreenLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated loading icon
            PulseAnimation(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.2),
                      primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 48,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Loading indicator
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
