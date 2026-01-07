import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';

/// Compact FIRE progress card for the overview dashboard
class FireDashboardCard extends ConsumerWidget {
  const FireDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(fireSettingsProvider);
    final calculationAsync = ref.watch(fireCalculationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);

    return settingsAsync.when(
      data: (settings) {
        if (settings == null || !settings.isSetupComplete) {
          return _buildSetupCard(context, isDark);
        }

        return calculationAsync.when(
          data: (calculation) => _buildProgressCard(
            context,
            isDark,
            calculation,
            currencySymbol,
          ),
          loading: () => _buildLoadingCard(isDark),
          error: (_, st) => const SizedBox.shrink(),
        );
      },
      loading: () => _buildLoadingCard(isDark),
      error: (_, st) => const SizedBox.shrink(),
    );
  }

  Widget _buildSetupCard(BuildContext context, bool isDark) {
    final accentColor = isDark ? AppColors.accentDark : AppColors.accentLight;

    return GlassCard(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/fire/setup');
      },
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_fire_department,
              color: accentColor,
              size: 28,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculate Your FIRE Number',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Set up your financial independence goals',
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    bool isDark,
    FireCalculationResult calculation,
    String currencySymbol,
  ) {
    final progress = calculation.displayProgress;
    final status = calculation.status;

    return GlassCard(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/fire');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: status.color,
                size: 24,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'FIRE Progress',
                style: AppTypography.h4.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.displayName,
                  style: AppTypography.caption.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              valueColor: AlwaysStoppedAnimation<Color>(status.color),
              minHeight: 8,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatCompactIndian(calculation.currentPortfolioValue, symbol: currencySymbol),
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${progress.toStringAsFixed(1)}%',
                style: AppTypography.bodyMedium.copyWith(
                  color: status.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatCompactIndian(calculation.fireNumber, symbol: currencySymbol),
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(bool isDark) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
                    borderRadius: BorderRadius.circular(4),
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

