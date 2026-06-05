/// Income Calendar Grid Widget
///
/// Displays a scrollable grid with:
/// - Month columns (horizontally scrollable)
/// - Investment rows (vertically scrollable)
/// - Color-coded status cells
/// - Month navigation controls
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/features/income_projection/presentation/utils/status_display_helpers.dart';
import 'package:inv_tracker/features/income_projection/presentation/widgets/income_cell.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

// Currency providers from currency_utils.dart - imported for ref.watch
export 'package:inv_tracker/core/utils/currency_utils.dart' show currencySymbolProvider, currencyLocaleProvider;

class IncomeCalendarGrid extends ConsumerWidget {
  final List<ExpectedCashFlowEntity> expectedCashFlows;
  final int monthOffset;
  final ValueChanged<int> onMonthChanged;
  final bool isDark;

  const IncomeCalendarGrid({
    super.key,
    required this.expectedCashFlows,
    required this.monthOffset,
    required this.onMonthChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);
    final now = DateTime.now();
    final centerMonth = DateTime(now.year, now.month + monthOffset, 1);
    
    // Show 3 months: previous, current (center), next
    final months = [
      DateTime(centerMonth.year, centerMonth.month - 1, 1),
      centerMonth,
      DateTime(centerMonth.year, centerMonth.month + 1, 1),
    ];

    // Group expected cash flows by investment
    final groupedByInvestment = <String, List<ExpectedCashFlowEntity>>{};
    for (final expected in expectedCashFlows) {
      groupedByInvestment.putIfAbsent(expected.investmentId, () => []).add(expected);
    }

    if (groupedByInvestment.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Month navigation header
        _buildMonthNavigationHeader(context, centerMonth, l10n),

        const SizedBox(height: 8),

        // Horizontal scrollable table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row (month names)
              _buildHeaderRow(months, l10n),
              
              // Investment rows
              ...groupedByInvestment.entries.map((entry) {
                return _buildInvestmentRow(
                  context,
                  ref,
                  l10n,
                  currencySymbol,
                  locale,
                  entry.key,
                  entry.value,
                  months,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNavigationHeader(BuildContext context, DateTime centerMonth, AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onMonthChanged(monthOffset - 1),
            tooltip: l10n.calendarGridPreviousMonth,
          ),
          Text(
            DateFormat('MMMM yyyy').format(centerMonth),
            style: AppTypography.h3.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => onMonthChanged(monthOffset + 1),
            tooltip: l10n.calendarGridNextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(List<DateTime> months, AppLocalizations l10n) {
    return Row(
      children: [
        // Investment name column header
        Container(
          width: 150,
          height: 40,
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark ? AppColors.neutral800Dark : AppColors.neutral100Light,
            border: Border.all(
              color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
            ),
          ),
          child: Text(
            l10n.calendarGridInvestmentHeader,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
        ),
        // Month columns
        ...months.map((month) => Container(
          width: 100,
          height: 40,
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark ? AppColors.neutral800Dark : AppColors.neutral100Light,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              ),
              bottom: BorderSide(
                color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              ),
              right: BorderSide(
                color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              ),
            ),
          ),
          child: Text(
            DateFormat('MMM yy').format(month),
            textAlign: TextAlign.center,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildInvestmentRow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String currencySymbol,
    String locale,
    String investmentId,
    List<ExpectedCashFlowEntity> expectedForInvestment,
    List<DateTime> months,
  ) {
    // Get investment name
    final investmentAsync = ref.watch(investmentByIdProvider(investmentId));
    final investmentName = investmentAsync.when(
      data: (inv) => inv?.name ?? l10n.calendarGridUnknownInvestment,
      loading: () => l10n.dashboardLoading,
      error: (error, stackTrace) => l10n.dashboardUnknownInvestment,
    );

    return Row(
      children: [
        // Investment name cell
        Container(
          width: 150,
          height: 80,
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark ? AppColors.neutral900Dark : Colors.white,
            border: Border(
              left: BorderSide(
                color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              ),
              bottom: BorderSide(
                color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              ),
              right: BorderSide(
                color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                investmentName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.calendarGridExpectedCount(expectedForInvestment.length),
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
        ),
        // Month cells
        ...months.map((month) {
          // Find expected cash flows for this month
          final expectedForMonth = expectedForInvestment.where((e) {
            return e.expectedDate.year == month.year &&
                   e.expectedDate.month == month.month;
          }).toList();

          return IncomeCell(
            expected: expectedForMonth.isEmpty ? null : expectedForMonth.first,
            isDark: isDark,
            onTap: expectedForMonth.isEmpty ? null : () {
              _showPaymentDetails(context, expectedForMonth.first, ref, l10n, currencySymbol, locale);
            },
          );
        }),
      ],
    );
  }

  void _showPaymentDetails(
    BuildContext context,
    ExpectedCashFlowEntity expected,
    WidgetRef ref,
    AppLocalizations l10n,
    String currencySymbol,
    String locale,
  ) {
    // Show bottom sheet with payment details
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.calendarGridPaymentDetails,
                  style: AppTypography.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: l10n.tooltipClose,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(l10n.calendarGridExpectedDate, DateFormat('MMM dd, yyyy').format(expected.expectedDate)),
            _buildDetailRow(l10n.calendarGridExpectedAmount, formatCompactCurrency(expected.expectedAmount, symbol: currencySymbol, locale: locale)),
            _buildDetailRow(l10n.calendarGridStatus, getStatusDisplayName(l10n, expected.status)),
            if (expected.actualAmount != null)
              _buildDetailRow(l10n.calendarGridActualAmount, formatCompactCurrency(expected.actualAmount!, symbol: currencySymbol, locale: locale)),
            if (expected.actualDate != null)
              _buildDetailRow(l10n.calendarGridActualDate, DateFormat('MMM dd, yyyy').format(expected.actualDate!)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral600Light,
            ),
          ),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
        ],
      ),
    );
  }
}
