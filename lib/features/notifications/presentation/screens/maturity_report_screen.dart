/// Maturity Report Screen
///
/// Displays details about an investment approaching maturity.
/// Shown when user taps the "Maturity Reminder" notification.
///
/// ## Data Displayed
/// - Investment details (name, type, platform)
/// - Days to maturity (countdown)
/// - Principal amount invested
/// - Expected maturity amount (with interest calculation)
/// - Expected interest earned
/// - Maturity date
/// - Action buttons (Renew, View Details)
///
/// ## Edge Cases
/// - Investment already matured (days = 0) → Show "Matured" badge
/// - Investment redeemed early → Show error state
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/calculations/investment_projector.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_metric_card.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class MaturityReportScreen extends ConsumerStatefulWidget {
  final String investmentId;
  final int daysToMaturity;

  const MaturityReportScreen({
    super.key,
    required this.investmentId,
    required this.daysToMaturity,
  });

  @override
  ConsumerState<MaturityReportScreen> createState() =>
      _MaturityReportScreenState();
}

class _MaturityReportScreenState extends ConsumerState<MaturityReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {
          'report_type': 'maturity',
          'days_to_maturity': widget.daysToMaturity,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final investmentsAsync = ref.watch(allInvestmentsProvider);

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.event_available_rounded,
        title: l10n.maturityReminder,
        subtitle: widget.daysToMaturity == 0
            ? 'Matured today'
            : widget.daysToMaturity == 1
                ? '1 day remaining'
                : '${widget.daysToMaturity} days remaining',
      ),
      body: investmentsAsync.when(
        data: (investments) {
          final investment = investments.cast<InvestmentEntity?>().firstWhere(
            (inv) => inv?.id == widget.investmentId,
            orElse: () => null,
          );

          if (investment == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: AppColors.errorLight,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Investment not found',
                    style: AppTypography.h3,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'This investment may have been deleted',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            );
          }

          return _buildContent(context, investment);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading investment: $error'),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, InvestmentEntity investment) {
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyLocale = ref.watch(currencyLocaleProvider);
    final statsAsync = ref.watch(
      investmentStatsProvider(investment.id),
    );

    // Calculate expected maturity amount
    final principal = statsAsync.value?.totalInvested ?? 0;
    final expectedMaturityAmount = _calculateExpectedMaturity(
      investment,
      principal,
    );
    final expectedInterest = expectedMaturityAmount - principal;

    // Format amounts
    final principalFormatted = formatCompactCurrency(
      principal,
      symbol: currencySymbol,
      locale: currencyLocale,
    );
    final maturityAmountFormatted = formatCompactCurrency(
      expectedMaturityAmount,
      symbol: currencySymbol,
      locale: currencyLocale,
    );
    final interestFormatted = formatCompactCurrency(
      expectedInterest,
      symbol: currencySymbol,
      locale: currencyLocale,
    );

    // Maturity date
    final maturityDate = investment.calculatedMaturityDate;
    final maturityDateFormatted = maturityDate != null
        ? DateFormat.yMMMd().format(maturityDate)
        : 'Unknown';

    final isMatured = widget.daysToMaturity == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpacing.md),

          // Maturity Status Badge
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isMatured
                    ? AppColors.successLight.withOpacity(0.1)
                    : AppColors.warningLight.withOpacity(0.1),
                borderRadius: AppSizes.borderRadiusMd,
                border: Border.all(
                  color: isMatured
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMatured
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: isMatured
                        ? AppColors.successLight
                        : AppColors.warningLight,
                    size: 24,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    isMatured ? 'Matured' : 'Maturing Soon',
                    style: AppTypography.h3.copyWith(
                      color: isMatured
                          ? AppColors.successLight
                          : AppColors.warningLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // Investment Details Card
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.neutral800Dark : Colors.white,
                borderRadius: AppSizes.borderRadiusMd,
                border: Border.all(
                  color: isDark
                      ? AppColors.neutral700Dark
                      : AppColors.neutral200Light,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investment.name,
                    style: AppTypography.h2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral600Light,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        investment.type.displayName,
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral600Light,
                        ),
                      ),
                      if (investment.hasPlatform) ...[
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          '•',
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.neutral400Dark
                                : AppColors.neutral600Light,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          investment.platform!,
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.neutral400Dark
                                : AppColors.neutral600Light,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Divider(
                    color: isDark
                        ? AppColors.neutral700Dark
                        : AppColors.neutral200Light,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Maturity Date',
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral600Light,
                        ),
                      ),
                      Text(
                        maturityDateFormatted,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (investment.hasExpectedRate) ...[
                    SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expected Rate',
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.neutral400Dark
                                : AppColors.neutral600Light,
                          ),
                        ),
                        Text(
                          '${investment.expectedRate!.toStringAsFixed(2)}% p.a.',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.successLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // Key Metrics
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ReportMetricCard(
                        label: 'Principal',
                        value: principalFormatted,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ReportMetricCard(
                        label: 'Expected Interest',
                        value: interestFormatted,
                        icon: Icons.trending_up_rounded,
                        accentColor: AppColors.successLight,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                ReportMetricCard(
                  label: 'Maturity Amount',
                  value: maturityAmountFormatted,
                  icon: Icons.monetization_on_outlined,
                  accentColor: AppColors.primaryLight,
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // Action Buttons
          ReportActionButtons(
            buttons: [
              if (!isMatured)
                ReportActionButton(
                  label: 'Renew Investment',
                  icon: Icons.autorenew_rounded,
                  onPressed: () {
                    // Navigate to add investment with pre-filled data
                    context.pop();
                    context.push('/investments/add', extra: investment);
                  },
                ),
              ReportActionButton(
                label: 'View Investment Details',
                icon: Icons.visibility_outlined,
                isPrimary: isMatured,
                onPressed: () {
                  context.pop();
                  context.push('/investments/${widget.investmentId}');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Calculate expected maturity amount
  double _calculateExpectedMaturity(
    InvestmentEntity investment,
    double principal,
  ) {
    // If no expected rate or tenure, return principal
    if (!investment.hasExpectedRate || !investment.hasTenure) {
      return principal;
    }

    // Use InvestmentProjector to calculate maturity value
    return InvestmentProjector.calculateMaturityValue(
      principal: principal,
      annualRate: investment.expectedRate!,
      tenureMonths: investment.tenureMonths!,
      compounding: investment.compoundingFrequency,
    );
  }
}
