import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Expected Income section for investment detail screen.
/// Shows future payment predictions, reliability metrics, and payment history.
class ExpectedIncomeSection extends ConsumerWidget {
  final String investmentId;
  final bool isDark;

  const ExpectedIncomeSection({
    super.key,
    required this.investmentId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);
    final expectedCashFlowsAsync = ref.watch(
      expectedCashFlowsByInvestmentProvider(investmentId),
    );

    return expectedCashFlowsAsync.when(
      data: (expectedFlows) {
        if (expectedFlows.isEmpty) {
          return _buildEmptyState(l10n, isDark);
        }

        // Split into future and past payments
        final now = DateTime.now();
        final futurePayments = expectedFlows.where((e) =>
          e.expectedDate.isAfter(now) &&
          (e.status == ExpectedCashFlowStatus.upcoming ||
           e.status == ExpectedCashFlowStatus.dueSoon)
        ).toList();
        
        final pastPayments = expectedFlows.where((e) =>
          e.matchedCashFlowId != null ||
          e.status == ExpectedCashFlowStatus.received
        ).toList();

        final overduePayments = expectedFlows.where((e) =>
          e.status == ExpectedCashFlowStatus.overdue ||
          e.status == ExpectedCashFlowStatus.gracePeriod
        ).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reliability summary
            _buildReliabilitySummary(
              context,
              pastPayments.length,
              expectedFlows.length,
              isDark,
              l10n,
            ),
            
            if (overduePayments.isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              _buildSectionHeader('Overdue Payments', AppColors.errorLight, isDark),
              SizedBox(height: AppSpacing.sm),
              ...overduePayments.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPaymentCard(e, currencySymbol, locale, isDark, l10n, isOverdue: true),
              )),
            ],

            if (futurePayments.isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              _buildSectionHeader('Upcoming Payments', AppColors.successLight, isDark),
              SizedBox(height: AppSpacing.sm),
              ...futurePayments.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPaymentCard(e, currencySymbol, locale, isDark, l10n),
              )),
            ],

            if (pastPayments.isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              _buildSectionHeader('Payment History', AppColors.graphCyan, isDark),
              SizedBox(height: AppSpacing.sm),
              ...pastPayments.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPaymentCard(e, currencySymbol, locale, isDark, l10n, isPast: true),
              )),
            ],

            SizedBox(height: AppSpacing.lg),
          ],
        );
      },
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(
            color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
          ),
        ),
      ),
      error: (err, stack) => _buildErrorState(isDark, l10n),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: isDark ? AppColors.neutral600Dark : AppColors.neutral300Light,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'No Expected Payments',
              style: AppTypography.h3.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'This investment has no predicted income payments',
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Failed to load expected payments',
          style: AppTypography.body.copyWith(
            color: AppColors.errorLight,
          ),
        ),
      ),
    );
  }

  Widget _buildReliabilitySummary(
    BuildContext context,
    int receivedCount,
    int totalCount,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final reliabilityPercent = totalCount > 0
        ? ((receivedCount / totalCount) * 100).toInt()
        : 0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.verified_rounded,
            color: reliabilityPercent >= 80
                ? AppColors.successLight
                : reliabilityPercent >= 50
                    ? AppColors.warningLight
                    : AppColors.errorLight,
            size: 32,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Reliability',
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$reliabilityPercent%',
                  style: AppTypography.h2.copyWith(
                    color: reliabilityPercent >= 80
                        ? AppColors.successLight
                        : reliabilityPercent >= 50
                            ? AppColors.warningLight
                            : AppColors.errorLight,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '$receivedCount of $totalCount payments received',
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
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

  Widget _buildSectionHeader(String title, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(
    ExpectedCashFlowEntity payment,
    String currencySymbol,
    String locale,
    bool isDark,
    AppLocalizations l10n, {
    bool isOverdue = false,
    bool isPast = false,
  }) {
    final statusColor = isOverdue
        ? AppColors.errorLight
        : isPast
            ? AppColors.graphCyan
            : AppColors.successLight;

    final variance = payment.actualAmount != null
        ? ((payment.actualAmount! - payment.expectedAmount) / payment.expectedAmount * 100)
        : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    if (payment.actualAmount != null)
                      Icon(
                        variance.abs() < 5
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: variance.abs() < 5
                            ? AppColors.successLight
                            : AppColors.warningLight,
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat.yMMMd().format(payment.expectedDate),
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                ),
                if (payment.actualAmount != null) ...[
                  SizedBox(height: 4),
                  PrivacyMask(
                    child: Text(
                      'Received: ${formatCompactCurrency(payment.actualAmount!, symbol: currencySymbol, locale: locale)}',
                      style: AppTypography.small.copyWith(
                        color: AppColors.graphCyan,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
