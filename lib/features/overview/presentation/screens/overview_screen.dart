import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goals_dashboard_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/hero_card.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_analytics.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/overview_empty_state.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/quick_stat_card.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalStats = ref.watch(globalStatsProvider);
    final openStats = ref.watch(openInvestmentsStatsProvider);
    final closedStats = ref.watch(closedInvestmentsStatsProvider);
    final currencyFormat = ref.watch(currencyFormatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'overview_add_investment_fab',
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddInvestmentScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Investment'),
        backgroundColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Invalidate base stream providers - all derived stats auto-update
            ref.invalidate(allInvestmentsProvider);
            ref.invalidate(allCashFlowsStreamProvider);
          },
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                title: const Text(
                  'Investment Tracker',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: false,
              ),

              // Content
              SliverPadding(
                padding: EdgeInsets.all(AppSpacing.md),
                sliver: globalStats.when(
                  data: (stats) => stats.hasData
                      ? _buildDataContent(context, ref, globalStats, openStats, closedStats, currencyFormat, isDark)
                      : _buildEmptyStateContent(context, ref, globalStats, closedStats, currencyFormat, isDark),
                  loading: () => _buildLoadingContent(context, ref, globalStats, closedStats, currencyFormat),
                  error: (e, s) => _buildEmptyStateContent(context, ref, globalStats, closedStats, currencyFormat, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build content when there is data
  SliverList _buildDataContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> globalStats,
    AsyncValue<InvestmentStats> openStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // Hero Card - Global Summary with toggle
        HeroCardWithToggle(
          globalStats: globalStats,
          closedStats: closedStats,
          currencyFormat: currencyFormat,
          errorBuilder: (error) => OverviewErrorCard(error: error),
        ),

        SizedBox(height: AppSpacing.xl),

        // Goals Summary Card
        const GoalsDashboardCard(),

        SizedBox(height: AppSpacing.xl),

        // Quick Stats Grid
        globalStats.when(
          data: (stats) => _buildQuickStats(context, stats, currencyFormat),
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        ),

        SizedBox(height: AppSpacing.xl),

        // Net Position Breakdown (Open vs Closed)
        _buildNetPositionBreakdown(context, ref, openStats, closedStats, currencyFormat, isDark),

        SizedBox(height: AppSpacing.xl),

        // Monthly Cash Flow Trend
        MonthlyCashFlowTrend(currencyFormat: currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // Investment Type Distribution
        TypeDistributionChart(currencyFormat: currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // YoY Comparison
        YoYComparisonCard(currencyFormat: currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // Recently Closed
        RecentlyClosedCard(currencyFormat: currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // Investment Period summary
        globalStats.when(
          data: (stats) => _buildSummarySection(context, stats),
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        ),

        // Bottom padding for FAB
        SizedBox(height: AppSpacing.fabBottomPadding),
      ]),
    );
  }

  /// Build content for empty state (no data)
  SliverList _buildEmptyStateContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> globalStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // Hero Card - shows zeros
        HeroCardWithToggle(
          globalStats: globalStats,
          closedStats: closedStats,
          currencyFormat: currencyFormat,
          errorBuilder: (error) => OverviewErrorCard(error: error),
        ),

        const SizedBox(height: 32),

        // Beautiful empty state
        const OverviewEmptyState(),

        // Bottom padding for FAB
        const SizedBox(height: 80),
      ]),
    );
  }

  /// Build loading state content with shimmer skeletons
  SliverList _buildLoadingContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> globalStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
  ) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // Hero Card Skeleton
        const HeroCardSkeleton(),

        const SizedBox(height: 24),

        // Quick Stats Skeleton
        const QuickStatsSkeleton(),

        const SizedBox(height: 24),

        // Net Position Breakdown Skeleton
        const SectionCardSkeleton(height: 120),

        const SizedBox(height: 24),

        // Monthly Trend Skeleton
        const SectionCardSkeleton(height: 180),

        const SizedBox(height: 24),

        // Type Distribution Skeleton
        const SectionCardSkeleton(height: 160),

        // Bottom padding for FAB
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildNetPositionBreakdown(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> openStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    return openStats.when(
      data: (open) => closedStats.when(
        data: (closed) {
          // Only show if we have data
          if (!open.hasData && !closed.hasData) {
            return const SizedBox.shrink();
          }

          return GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Net Position Breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildBreakdownItem(
                        'Open Investments',
                        open.netCashFlow,
                        currencyFormat,
                        AppColors.graphBlue,
                        Icons.hourglass_top,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBreakdownItem(
                        'Closed (Realized)',
                        closed.netCashFlow,
                        currencyFormat,
                        closed.netCashFlow >= 0 ? AppColors.successLight : AppColors.errorLight,
                        Icons.check_circle,
                        isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, s) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildBreakdownItem(
    String label,
    double value,
    NumberFormat currencyFormat,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    final isPositive = value >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${isPositive ? '+' : ''}${currencyFormat.formatCompact(value.abs())}',
            style: TextStyle(
              color: isPositive ? AppColors.successLight : AppColors.errorLight,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildQuickStats(BuildContext context, InvestmentStats stats, NumberFormat currencyFormat) {
    return Row(
      children: [
        Expanded(
          child: QuickStatCard(
            icon: Icons.trending_up,
            label: 'MOIC',
            value: '${stats.moic.toStringAsFixed(2)}x',
            color: AppColors.successLight,
            subtitle: stats.durationFormatted != null ? 'over ${stats.durationFormatted}' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: QuickStatCard(
            icon: Icons.receipt_long,
            label: 'Cash Flows',
            value: '${stats.cashFlowCount}',
            color: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(BuildContext context, InvestmentStats stats) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Investment Period',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (stats.firstCashFlowDate != null && stats.lastCashFlowDate != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDateInfo('First Cash Flow', stats.firstCashFlowDate!),
                _buildDateInfo('Last Cash Flow', stats.lastCashFlowDate!),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppDateUtils.formatShort(date),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

}
