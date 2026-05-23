/// Income Guardian Dashboard Card
///
/// Displays upcoming income payments summary on the main dashboard:
/// - Next expected payment (date, amount, investment)
/// - Count of pending/overdue payments
/// - Platform reliability score
/// - Quick link to income calendar
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Dashboard card showing Income Guardian summary
class IncomeGuardianDashboardCard extends ConsumerWidget {
  const IncomeGuardianDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);
    
    final expectedAsync = ref.watch(allExpectedCashFlowsProvider);

    return expectedAsync.when(
      data: (allExpected) {
        // Filter for upcoming payments (not received, not dismissed)
        final upcoming = allExpected.where((e) =>
          e.status == ExpectedCashFlowStatus.upcoming ||
          e.status == ExpectedCashFlowStatus.dueSoon ||
          e.status == ExpectedCashFlowStatus.overdue ||
          e.status == ExpectedCashFlowStatus.gracePeriod
        ).toList();

        // Sort by expected date (earliest first)
        upcoming.sort((a, b) => a.expectedDate.compareTo(b.expectedDate));

        final nextPayment = upcoming.isNotEmpty ? upcoming.first : null;
        final overdueCount = upcoming.where((e) => e.status == ExpectedCashFlowStatus.overdue).length;
        final totalPending = upcoming.length;

        return GlassCard(
          onTap: () => context.push('/income-calendar'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, l10n),
              SizedBox(height: AppSpacing.md),
              
              if (nextPayment != null)
                _buildNextPayment(context, ref, nextPayment, currencySymbol, locale, isDark)
              else
                _buildEmptyState(isDark, l10n),
              
              SizedBox(height: AppSpacing.md),
              _buildMetrics(totalPending, overdueCount, isDark, l10n),
            ],
          ),
        );
      },
      loading: () => const GlassCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildHeader(bool isDark, AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.successLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.schedule_rounded,
            color: AppColors.successLight,
            size: 20,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Income Guardian',
            style: AppTypography.h3,
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
        ),
      ],
    );
  }

  Widget _buildNextPayment(
    BuildContext context,
    WidgetRef ref,
    ExpectedCashFlowEntity payment,
    String currencySymbol,
    String locale,
    bool isDark,
  ) {
    final isOverdue = payment.status == ExpectedCashFlowStatus.overdue;
    final statusColor = isOverdue ? AppColors.errorLight : AppColors.successLight;

    // Get investment name asynchronously
    final investmentAsync = ref.watch(investmentByIdProvider(payment.investmentId));
    final investmentName = investmentAsync.when(
      data: (inv) => inv?.platform ?? inv?.name ?? 'Unknown',
      loading: () => 'Loading...',
      error: (error, stack) => 'Unknown',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next Expected',
          style: AppTypography.small.copyWith(
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: PrivacyMask(
                child: Text(
                  formatCompactCurrency(
                    payment.expectedAmount,
                    symbol: currencySymbol,
                    locale: locale,
                  ),
                  style: AppTypography.h2.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          '${DateFormat.MMMd().format(payment.expectedDate)} • $investmentName',
          style: AppTypography.small.copyWith(
            color: isDark ? AppColors.neutral300Dark : AppColors.neutral600Light,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n) {
    return Column(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 48,
          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          'All caught up!',
          style: AppTypography.body.copyWith(
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMetrics(
    int totalPending,
    int overdueCount,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            icon: Icons.pending_actions_rounded,
            label: 'Pending',
            value: totalPending.toString(),
            color: AppColors.primaryLight,
            isDark: isDark,
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildMetricItem(
            icon: Icons.error_outline_rounded,
            label: 'Overdue',
            value: overdueCount.toString(),
            color: overdueCount > 0 ? AppColors.errorLight : AppColors.successLight,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.h3.copyWith(color: color),
                ),
                Text(
                  label,
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
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
