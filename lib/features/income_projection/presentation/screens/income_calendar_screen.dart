/// Income Calendar Screen
///
/// Displays a comprehensive calendar view of expected vs actual income payments:
/// - Grid view with month columns and investment rows
/// - Color-coded status indicators (Received, Expected, Overdue, Dismissed)
/// - Interactive filters (Show All, Pending Only, Overdue Only)
/// - Month navigation (swipe left/right)
/// - Pull-to-refresh for re-calculation
/// - Tap cell → Bottom sheet with payment details
/// - Tap investment row → Navigate to investment detail
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/income_projection/presentation/widgets/income_calendar_grid.dart';
import 'package:inv_tracker/features/income_projection/presentation/widgets/income_calendar_filter_chips.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Income Calendar Screen
class IncomeCalendarScreen extends ConsumerWidget {
  const IncomeCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(incomeCalendarFilterProvider);
    final monthOffset = ref.watch(incomeCalendarMonthOffsetProvider);
    
    // Watch all expected cash flows
    final allExpectedAsync = ref.watch(allExpectedCashFlowsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.incomeCalendar),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(allExpectedCashFlowsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allExpectedCashFlowsProvider);
          // Wait for the provider to complete
          await ref.read(allExpectedCashFlowsProvider.future);
        },
        child: allExpectedAsync.when(
          data: (allExpected) {
            // Filter expected cash flows based on current filter
            final filteredExpected = _filterExpected(allExpected, filter);

            if (filteredExpected.isEmpty) {
              return _buildEmptyState(context, isDark, filter, l10n);
            }

            return CustomScrollView(
              slivers: [
                // Filter chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: IncomeCalendarFilterChips(
                      isDark: isDark,
                      currentFilter: filter,
                      onFilterChanged: (newFilter) {
                        ref.read(incomeCalendarFilterProvider.notifier).state = newFilter;
                      },
                    ),
                  ),
                ),

                // Calendar grid
                SliverToBoxAdapter(
                  child: IncomeCalendarGrid(
                    expectedCashFlows: filteredExpected,
                    monthOffset: monthOffset,
                    onMonthChanged: (newOffset) {
                      ref.read(incomeCalendarMonthOffsetProvider.notifier).state = newOffset;
                    },
                    isDark: isDark,
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState(context, isDark, error),
        ),
      ),
    );
  }

  List<ExpectedCashFlowEntity> _filterExpected(
    List<ExpectedCashFlowEntity> all,
    IncomeCalendarFilter filter,
  ) {
    switch (filter) {
      case IncomeCalendarFilter.all:
        return all;
      case IncomeCalendarFilter.pending:
        return all.where((e) => 
          e.status == ExpectedCashFlowStatus.upcoming ||
          e.status == ExpectedCashFlowStatus.dueSoon
        ).toList();
      case IncomeCalendarFilter.overdue:
        return all.where((e) => e.status == ExpectedCashFlowStatus.overdue).toList();
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    IncomeCalendarFilter filter,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 64,
              color: isDark ? AppColors.neutral600Dark : AppColors.neutral400Light,
            ),
            const SizedBox(height: 16),
            Text(
              filter == IncomeCalendarFilter.all
                  ? 'No Expected Payments'
                  : filter == IncomeCalendarFilter.pending
                      ? 'No Pending Payments'
                      : 'No Overdue Payments',
              style: AppTypography.h3.copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: isDark ? AppColors.errorDark : AppColors.errorLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load calendar',
            style: AppTypography.h3.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
        ],
      ),
    );
  }
}
