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
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/security/presentation/widgets/privacy_protection_wrapper.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Dashboard card showing Income Guardian summary
class IncomeGuardianDashboardCard extends ConsumerWidget {
  final VoidCallback? onCalendarTap;

  const IncomeGuardianDashboardCard({
    super.key,
    this.onCalendarTap,
  });

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
          onTap: onCalendarTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, l10n),
              SizedBox(height: AppSpacing.md),
              
              if (nextPayment != null)
                _buildNextPayment(context, ref, nextPayment, currencySymbol, locale, isDark, l10n)
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
      error: (error, stack) => GlassCard(
        onTap: onCalendarTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark, l10n),
            SizedBox(height: AppSpacing.md),
            _buildErrorState(isDark, l10n, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, AppLocalizations l10n) {
    return Row(
      children: [
        // Enhanced Shield Icon with Glow
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow Effect
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.successLight.withValues(alpha: 0.3),
                    AppColors.successLight.withValues(alpha: 0.0),
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
            // Icon Container
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.successLight.withValues(alpha: 0.25),
                    AppColors.successLight.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.successLight.withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.successLight.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.shield_rounded,
                color: AppColors.successLight,
                size: 28,
              ),
            ),
          ],
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.dashboardIncomeGuardian,
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6),
                  // "BETA" Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryLight.withValues(alpha: 0.2),
                          AppColors.primaryLight.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'BETA',
                      style: AppTypography.small.copyWith(
                        color: AppColors.primaryLight,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'AI-powered income tracking',
                    style: AppTypography.small.copyWith(
                      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Enhanced Arrow with Hover Effect Styling
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (isDark ? AppColors.neutral700Dark : AppColors.neutral200Light)
                    .withValues(alpha: 0.6),
                (isDark ? AppColors.neutral700Dark : AppColors.neutral200Light)
                    .withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? AppColors.neutral600Dark : AppColors.neutral300Light)
                  .withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: isDark ? AppColors.neutral300Dark : AppColors.neutral600Light,
          ),
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
    AppLocalizations l10n,
  ) {
    final isOverdue = payment.status == ExpectedCashFlowStatus.overdue;
    final isDueSoon = payment.status == ExpectedCashFlowStatus.dueSoon;
    final statusColor = isOverdue
        ? AppColors.errorLight
        : isDueSoon
            ? Colors.orange
            : AppColors.successLight;
    final statusIcon = isOverdue
        ? Icons.error_outline_rounded
        : isDueSoon
            ? Icons.schedule_rounded
            : Icons.check_circle_outline_rounded;

    // Get investment name asynchronously
    final investmentAsync = ref.watch(investmentByIdProvider(payment.investmentId));
    final investmentName = investmentAsync.when(
      data: (inv) => inv?.platform ?? inv?.name ?? l10n.dashboardUnknownInvestment,
      loading: () => l10n.dashboardLoading,
      error: (error, stack) => l10n.dashboardUnknownInvestment,
    );

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    SizedBox(width: 6),
                    Text(
                      l10n.dashboardNextExpected,
                      style: AppTypography.small.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Days until badge
              if (isOverdue)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'OVERDUE',
                    style: AppTypography.small.copyWith(
                      color: AppColors.errorLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          // Amount - Larger and more prominent
          PrivacyProtectionWrapper(
            child: Text(
              formatCompactCurrency(
                payment.expectedAmount,
                symbol: currencySymbol,
                locale: locale,
              ),
              style: AppTypography.h1.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 36,
                height: 1.1,
                shadows: [
                  Shadow(
                    color: statusColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.3),
                  statusColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          // Date and Investment Info
          Row(
            children: [
              // Date
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.event_rounded,
                        size: 18,
                        color: statusColor,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Due Date',
                          style: AppTypography.small.copyWith(
                            color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          DateFormat.MMMd().format(payment.expectedDate),
                          style: AppTypography.small.copyWith(
                            color: isDark ? AppColors.neutral200Dark : AppColors.neutral700Light,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          // Investment Name
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 18,
                  color: statusColor,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source',
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      investmentName,
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.neutral200Dark : AppColors.neutral700Light,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.successLight.withValues(alpha: 0.08),
            AppColors.successLight.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.successLight.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Success Icon with Glow Effect
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.successLight.withValues(alpha: 0.2),
                  AppColors.successLight.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.successLight.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.verified_rounded,
              size: 40,
              color: AppColors.successLight,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          // Primary Message
          Text(
            l10n.dashboardAllCaughtUp,
            style: AppTypography.h3.copyWith(
              color: AppColors.successLight,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs),
          // Subtitle
          Text(
            'No pending income payments',
            style: AppTypography.small.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.md),
          // Info Badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.successLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.successLight.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.successLight,
                ),
                SizedBox(width: 6),
                Text(
                  'All income on track',
                  style: AppTypography.small.copyWith(
                    color: AppColors.successLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            label: l10n.dashboardPending,
            value: totalPending.toString(),
            color: AppColors.primaryLight,
            isDark: isDark,
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildMetricItem(
            icon: Icons.error_outline_rounded,
            label: l10n.dashboardOverdue,
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
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Spacer(),
              Text(
                value,
                style: AppTypography.h2.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.small.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, AppLocalizations l10n, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AppColors.errorLight,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            l10n.dashboardLoadFailed,
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => ref.invalidate(allExpectedCashFlowsProvider),
            child: Text(l10n.calendarRetry),
          ),
        ],
      ),
    );
  }
}
