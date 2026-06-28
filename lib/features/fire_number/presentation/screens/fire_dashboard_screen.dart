import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/extensions/fire_entity_ui_extensions.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_milestone_card.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_progress_ring.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_stats_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Main FIRE Number dashboard screen
class FireDashboardScreen extends ConsumerWidget {
  const FireDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(fireSettingsProvider);
    final calculationAsync = ref.watch(fireCalculationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(l10n.fireJourney),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
          tooltip: l10n.tooltipBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/fire/settings'),
            tooltip: l10n.tooltipFireSettings,
          ),
        ],
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (settings == null || !settings.isSetupComplete) {
            return _buildSetupPrompt(context, isDark);
          }

          return calculationAsync.when(
            data: (calculation) =>
                _buildDashboard(context, ref, isDark, settings, calculation),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _buildErrorState(isDark, () {
              ref.invalidate(fireSettingsProvider);
              ref.invalidate(fireCalculationProvider);
            }, context),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(isDark, () {
          ref.invalidate(fireSettingsProvider);
        }, context),
      ),
    );
  }

  Widget _buildSetupPrompt(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 80,
              color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Calculate Your FIRE Number',
              style: AppTypography.h1.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Set up your financial independence goals and track your progress towards early retirement.',
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.push('/fire/setup'),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: Text(l10n.getStarted),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    FireSettingsEntity settings,
    FireCalculationResult calculation,
  ) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium hero card with centered progress ring
          _buildPremiumHeroCard(
            context,
            isDark,
            calculation,
            settings,
            currencySymbol,
            locale,
          ),
          SizedBox(height: AppSpacing.lg),

          // Quick insights row
          _buildQuickInsightsRow(
            context,
            isDark,
            calculation,
            settings,
            currencySymbol,
            locale,
          ),
          SizedBox(height: AppSpacing.lg),

          // Actionable insight card
          _buildActionableInsightCard(
            context,
            isDark,
            calculation,
            currencySymbol,
            locale,
          ),
          SizedBox(height: AppSpacing.lg),

          // FIRE Numbers breakdown
          Text(
            'Your FIRE Numbers',
            style: AppTypography.h3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          FireStatsCard(
            calculation: calculation,
            currencySymbol: currencySymbol,
          ),
          SizedBox(height: AppSpacing.lg),

          // Milestones
          Text(
            'Milestones',
            style: AppTypography.h3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          FireMilestoneCard(
            milestones: calculation.milestones,
            currencySymbol: currencySymbol,
          ),
          SizedBox(height: AppSpacing.lg),

          // Gap analysis
          _buildGapAnalysis(
            context,
            isDark,
            calculation,
            currencySymbol,
            locale,
          ),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildPremiumHeroCard(
    BuildContext context,
    bool isDark,
    FireCalculationResult calculation,
    FireSettingsEntity settings,
    String currencySymbol,
    String locale,
  ) {
    final statusColor = calculation.status.colorForBrightness(
      isDark ? Brightness.dark : Brightness.light,
    );
    final motivationalMessage = _getMotivationalMessage(calculation, settings);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.heroGradientDark : AppColors.heroGradient,
        borderRadius: BorderRadius.circular(
          FireUiConstants.heroCardBorderRadius,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: FireUiConstants.decorativeCircleLarge,
              height: FireUiConstants.decorativeCircleLarge,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: FireUiConstants.decorativeCircleSmall,
              height: FireUiConstants.decorativeCircleSmall,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered progress ring
                Center(
                  child: FireProgressRing(
                    progress: calculation.displayProgress,
                    fireNumber: calculation.fireNumber,
                    currentValue: calculation.currentPortfolioValue,
                    currencySymbol: currencySymbol,
                    status: calculation.status,
                    size: FireUiConstants.heroRingSize,
                    strokeWidth: FireUiConstants.heroRingStrokeWidth,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                // Status badge
                _buildStatusBadge(calculation.status, isDark),
                SizedBox(height: AppSpacing.md),
                // Motivational message
                Text(
                  motivationalMessage,
                  style: AppTypography.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(FireProgressStatus status, bool isDark) {
    final statusColor = status.colorForBrightness(
      isDark ? Brightness.dark : Brightness.light,
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: statusColor, size: 18),
          SizedBox(width: AppSpacing.xs),
          Text(
            status.displayName,
            style: AppTypography.bodyMedium.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMotivationalMessage(
    FireCalculationResult calculation,
    FireSettingsEntity settings,
  ) {
    switch (calculation.status) {
      case FireProgressStatus.notStarted:
        return 'Every journey begins with a single step. Start investing today!';
      case FireProgressStatus.behind:
        final monthlyNeeded =
            calculation.requiredMonthlySavings -
            calculation.currentMonthlySavingsRate;
        if (monthlyNeeded > 0) {
          return 'Boost your monthly investments to get back on track.';
        }
        return 'Keep pushing! You\'re building your financial freedom.';
      case FireProgressStatus.onTrack:
        return 'Excellent progress! Stay consistent and you\'ll reach FIRE at ${settings.targetFireAge}.';
      case FireProgressStatus.ahead:
        return 'Amazing! You\'re ahead of schedule. Keep up the momentum!';
      case FireProgressStatus.achieved:
        return '🎉 Congratulations! You\'ve achieved financial independence!';
      case FireProgressStatus.coasting:
        return 'You can now coast to FIRE! Your investments will do the heavy lifting.';
    }
  }

  Widget _buildQuickInsightsRow(
    BuildContext context,
    bool isDark,
    FireCalculationResult calculation,
    FireSettingsEntity settings,
    String currencySymbol,
    String locale,
  ) {
    final yearsToFire = settings.targetFireAge - settings.currentAge;
    final projectedDate = calculation.projectedFireDate;
    // Use locale-aware date formatting
    final locale = Localizations.localeOf(context).languageCode;

    return Row(
      children: [
        Expanded(
          child: _buildInsightCard(
            context,
            isDark,
            icon: Icons.calendar_today_outlined,
            iconColor: isDark ? AppColors.accentDark : AppColors.accentLight,
            label: 'Target Age',
            value: '${settings.targetFireAge}',
            subtitle: '$yearsToFire years left',
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildInsightCard(
            context,
            isDark,
            icon: Icons.flag_outlined,
            iconColor: calculation.status.colorForBrightness(
              isDark ? Brightness.dark : Brightness.light,
            ),
            label: 'Projected',
            value: projectedDate != null
                ? AppDateUtils.formatYearMonth(projectedDate, locale: locale)
                : 'N/A',
            subtitle: calculation.status.shortSubtitle,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildInsightCard(
            context,
            isDark,
            icon: Icons.savings_outlined,
            iconColor: isDark ? AppColors.warningDark : AppColors.warningLight,
            label: 'Need/Month',
            value: formatCompactCurrency(
              calculation.requiredMonthlySavings,
              symbol: currencySymbol,
              locale: locale,
            ),
            subtitle: 'To reach FIRE',
            isSensitive: true,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    bool isSensitive = false,
  }) {
    final valueStyle = AppTypography.bodyMedium.copyWith(
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      fontWeight: FontWeight.w700,
    );

    return GlassCard(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          isSensitive
              ? MaskedAmountText(text: value, style: valueStyle)
              : Text(value, style: valueStyle),
          Text(
            subtitle,
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral500Dark
                  : AppColors.neutral400Light,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionableInsightCard(
    BuildContext context,
    bool isDark,
    FireCalculationResult calculation,
    String currencySymbol,
    String locale,
  ) {
    final monthlyGap = calculation.monthlyGap;
    final status = calculation.status;
    final isPositive = status.isPositive;
    final statusColor = status.colorForBrightness(
      isDark ? Brightness.dark : Brightness.light,
    );
    final nextMilestone = calculation.nextMilestone;

    return GlassCard(
      backgroundColor: isDark
          ? statusColor.withValues(alpha: 0.1)
          : statusColor.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPositive
                      ? Icons.check_circle_outline
                      : Icons.lightbulb_outline,
                  color: statusColor,
                  size: 24,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPositive
                          ? 'You\'re ${status.shortSubtitle.toLowerCase()}!'
                          : 'Action Needed',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    isPositive
                        ? Text(
                            'Keep up your current investment rate.',
                            style: AppTypography.small.copyWith(
                              color: isDark
                                  ? AppColors.neutral400Dark
                                  : AppColors.neutral500Light,
                            ),
                          )
                        : PrivacyMask(
                            child: Text(
                              'Invest ${formatCompactCurrency(monthlyGap.abs(), symbol: currencySymbol, locale: locale)}/month more to stay on track.',
                              style: AppTypography.small.copyWith(
                                color: isDark
                                    ? AppColors.neutral400Dark
                                    : AppColors.neutral500Light,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
          if (nextMilestone != null) ...[
            SizedBox(height: AppSpacing.md),
            Builder(
              builder: (context) {
                final milestoneColor = isDark
                    ? AppColors.warningDark
                    : AppColors.warningLight;
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.neutral800Dark
                        : AppColors.neutral100Light,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        color: milestoneColor,
                        size: 20,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next Milestone: ${nextMilestone.label}',
                              style: AppTypography.small.copyWith(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            MaskedAmountText(
                              text:
                                  '${formatCompactCurrency(nextMilestone.targetAmount - calculation.currentPortfolioValue, symbol: currencySymbol, locale: locale)} to go',
                              style: AppTypography.small.copyWith(
                                color: isDark
                                    ? AppColors.neutral400Dark
                                    : AppColors.neutral500Light,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Mini progress
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: nextMilestone.currentProgress / 100,
                              strokeWidth: 4,
                              backgroundColor: isDark
                                  ? AppColors.neutral700Dark
                                  : AppColors.neutral200Light,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                milestoneColor,
                              ),
                            ),
                            Text(
                              '${nextMilestone.currentProgress.toInt()}%',
                              style: AppTypography.small.copyWith(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGapAnalysis(
    BuildContext context,
    bool isDark,
    FireCalculationResult calculation,
    String currencySymbol,
    String locale,
  ) {
    final gap = calculation.portfolioGap;
    // portfolioGap = fireNumber - currentPortfolioValue
    // Positive gap = shortfall (need more money) → show as negative (red)
    // Negative gap = surplus (ahead of target) → show as positive (green)
    final hasShortfall = gap > 0;
    // Display: shortfall as negative, surplus as positive
    final gapLabel = hasShortfall
        ? '-${formatCompactCurrency(gap, symbol: currencySymbol, locale: locale)}'
        : '+${formatCompactCurrency(gap.abs(), symbol: currencySymbol, locale: locale)}';
    // Label changes based on whether user has shortfall or surplus
    final gapDescription = hasShortfall ? 'Shortfall' : 'Surplus';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gap Analysis',
            style: AppTypography.h4.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                gapDescription,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
              MaskedAmountText(
                text: gapLabel,
                style: AppTypography.bodyMedium.copyWith(
                  color: hasShortfall
                      ? (isDark ? AppColors.dangerDark : AppColors.dangerLight)
                      : (isDark
                            ? AppColors.successDark
                            : AppColors.successLight),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Projected FIRE Age',
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
              Text(
                'Age ${calculation.projectedFireAge}',
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    bool isDark,
    VoidCallback onRetry,
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: AppSizes.iconXl,
                color: AppColors.errorLight,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              l10n.connectionError,
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              l10n.failedToLoadFireData,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
