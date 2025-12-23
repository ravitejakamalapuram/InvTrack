import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';

/// Toggle state for showing realized-only net position
final showRealizedOnlyProvider = StateProvider<bool>((ref) => false);

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
                  'Cash Flow Tracker',
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
                  error: (_, __) => _buildEmptyStateContent(context, ref, globalStats, closedStats, currencyFormat, isDark),
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
        _buildHeroCardWithToggle(context, ref, globalStats, closedStats, currencyFormat),

        SizedBox(height: AppSpacing.xl),

        // Quick Stats Grid
        globalStats.when(
          data: (stats) => _buildQuickStats(context, stats, currencyFormat),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        SizedBox(height: AppSpacing.xl),

        // Net Position Breakdown (Open vs Closed)
        _buildNetPositionBreakdown(context, ref, openStats, closedStats, currencyFormat, isDark),

        SizedBox(height: AppSpacing.xl),

        // Monthly Cash Flow Trend
        _buildMonthlyCashFlowTrend(context, ref, currencyFormat, isDark),

        SizedBox(height: AppSpacing.xl),

        // Investment Type Distribution
        _buildTypeDistribution(context, ref, currencyFormat, isDark),

        SizedBox(height: AppSpacing.xl),

        // YoY Comparison
        _buildYoYComparison(context, ref, currencyFormat, isDark),

        SizedBox(height: AppSpacing.xl),

        // Recently Closed
        _buildRecentlyClosed(context, ref, currencyFormat, isDark),

        SizedBox(height: AppSpacing.xl),

        // Investment Period summary
        globalStats.when(
          data: (stats) => _buildSummarySection(context, stats),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
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
        _buildHeroCardWithToggle(context, ref, globalStats, closedStats, currencyFormat),

        const SizedBox(height: 32),

        // Beautiful empty state
        _buildEmptyState(context, isDark),

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
        error: (_, __) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
            '${isPositive ? '+' : ''}${currencyFormat.format(value.abs())}',
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

  Widget _buildMonthlyCashFlowTrend(BuildContext context, WidgetRef ref, NumberFormat currencyFormat, bool isDark) {
    final trendAsync = ref.watch(monthlyCashFlowTrendProvider);

    return trendAsync.when(
      data: (data) {
        if (data.isEmpty || data.every((d) => d.inflows == 0 && d.outflows == 0)) {
          return const SizedBox.shrink();
        }

        final maxValue = data.fold<double>(0, (max, d) =>
            [max, d.inflows, d.outflows].reduce((a, b) => a > b ? a : b));

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Cash Flow Trend',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.map((d) {
                    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: maxValue > 0 ? (d.outflows / maxValue * 80) : 0,
                                      decoration: BoxDecoration(
                                        color: AppColors.errorLight.withValues(alpha: 0.7),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Container(
                                      height: maxValue > 0 ? (d.inflows / maxValue * 80) : 0,
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight.withValues(alpha: 0.7),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              months[d.month.month - 1],
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Cash Out', AppColors.errorLight),
                  const SizedBox(width: 16),
                  _buildLegendItem('Cash In', AppColors.successLight),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildTypeDistribution(BuildContext context, WidgetRef ref, NumberFormat currencyFormat, bool isDark) {
    final distAsync = ref.watch(investmentTypeDistributionProvider);

    return distAsync.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        final total = data.fold<double>(0, (sum, d) => sum + d.totalInvested);
        if (total == 0) return const SizedBox.shrink();

        final colors = [
          AppColors.graphBlue, AppColors.graphEmerald, AppColors.graphAmber,
          AppColors.graphPurple, AppColors.graphPink, AppColors.graphCyan,
        ];

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Investment Distribution', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              // Simple horizontal bar chart
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 24,
                  child: Row(
                    children: data.asMap().entries.map((e) {
                      final pct = e.value.totalInvested / total;
                      final color = colors[e.key % colors.length];
                      return Expanded(
                        flex: (pct * 100).round().clamp(1, 100),
                        child: Container(color: color),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: data.asMap().entries.map((e) {
                  final pct = (e.value.totalInvested / total * 100).toStringAsFixed(0);
                  final color = colors[e.key % colors.length];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      Text('${e.value.type.displayName} ($pct%)', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[700])),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildYoYComparison(BuildContext context, WidgetRef ref, NumberFormat currencyFormat, bool isDark) {
    final yoyAsync = ref.watch(yoyComparisonProvider);

    return yoyAsync.when(
      data: (data) {
        // Only show if we have data from either year
        if (data.thisYearInvested == 0 && data.lastYearInvested == 0) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final thisYear = now.year.toString();
        final lastYear = (now.year - 1).toString();

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.compare_arrows, color: AppColors.primaryLight, size: 20),
                  const SizedBox(width: 8),
                  const Text('Year over Year', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildYoYColumn(lastYear, data.lastYearNet, currencyFormat, isDark)),
                  Container(width: 1, height: 60, color: isDark ? Colors.white24 : Colors.grey[300]),
                  Expanded(child: _buildYoYColumn(thisYear, data.thisYearNet, currencyFormat, isDark)),
                ],
              ),
              if (data.lastYearNet != 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (data.isImproved ? AppColors.successLight : AppColors.errorLight).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        data.isImproved ? Icons.trending_up : Icons.trending_down,
                        color: data.isImproved ? AppColors.successLight : AppColors.errorLight,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${data.netChange >= 0 ? '+' : ''}${data.netChange.toStringAsFixed(0)}% vs last year',
                        style: TextStyle(
                          color: data.isImproved ? AppColors.successLight : AppColors.errorLight,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildYoYColumn(String year, double net, NumberFormat currencyFormat, bool isDark) {
    final isPositive = net >= 0;
    return Column(
      children: [
        Text(year, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '${isPositive ? '+' : ''}${currencyFormat.format(net.abs())}',
          style: TextStyle(
            color: isPositive ? AppColors.successLight : AppColors.errorLight,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyClosed(BuildContext context, WidgetRef ref, NumberFormat currencyFormat, bool isDark) {
    final closedAsync = ref.watch(recentlyClosedInvestmentsProvider);

    return closedAsync.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.successLight, size: 20),
                  const SizedBox(width: 8),
                  const Text('Recently Closed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              ...data.map((item) {
                final isProfit = item.stats.netCashFlow >= 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.investment.name, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(item.investment.type.displayName, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isProfit ? '+' : ''}${currencyFormat.format(item.stats.netCashFlow.abs())}',
                            style: TextStyle(color: isProfit ? AppColors.successLight : AppColors.errorLight, fontWeight: FontWeight.w600),
                          ),
                          if (item.stats.xirr != 0 && !item.stats.xirr.isNaN)
                            Text('${(item.stats.xirr * 100).toStringAsFixed(1)}% IRR', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildHeroCardWithToggle(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> globalStats,
    AsyncValue<InvestmentStats> closedStats,
    NumberFormat currencyFormat,
  ) {
    final showRealizedOnly = ref.watch(showRealizedOnlyProvider);

    return globalStats.when(
      loading: () => const _LoadingHeroCard(),
      error: (e, _) => _buildErrorCard(context, e.toString()),
      data: (global) => closedStats.when(
        loading: () => _buildHeroCardContent(context, ref, global, global, currencyFormat, showRealizedOnly),
        error: (_, __) => _buildHeroCardContent(context, ref, global, global, currencyFormat, showRealizedOnly),
        data: (closed) => _buildHeroCardContent(context, ref, global, closed, currencyFormat, showRealizedOnly),
      ),
    );
  }

  Widget _buildHeroCardContent(
    BuildContext context,
    WidgetRef ref,
    InvestmentStats globalStats,
    InvestmentStats closedStats,
    NumberFormat currencyFormat,
    bool showRealizedOnly,
  ) {
    final stats = showRealizedOnly ? closedStats : globalStats;
    final netPosition = stats.netCashFlow;
    final isPositive = netPosition >= 0;

    final semanticLabel = AccessibilityUtils.statCardLabel(
      title: showRealizedOnly ? 'Realized Net Position' : 'Net Position All Investments',
      value: AccessibilityUtils.formatCurrencyForScreenReader(netPosition, currencyFormat.currencySymbol),
      subtitle: stats.hasData
          ? 'Return: ${AccessibilityUtils.formatPercentageForScreenReader(stats.absoluteReturn)}'
          : null,
    );

    return Semantics(
      label: semanticLabel,
      child: GlassHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                showRealizedOnly ? 'Realized Net Position' : 'Net Position (All)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              // Toggle button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(showRealizedOnlyProvider.notifier).state = !showRealizedOnly;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showRealizedOnly ? Icons.check_circle : Icons.all_inclusive,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showRealizedOnly ? 'Realized' : 'All',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.swap_horiz,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}${currencyFormat.format(netPosition.abs())}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              if (stats.hasData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${stats.absoluteReturn >= 0 ? '+' : ''}${stats.absoluteReturn.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHeroStat('Cash Out', currencyFormat.format(stats.totalInvested)),
              const SizedBox(width: 24),
              _buildHeroStat('Cash In', currencyFormat.format(stats.totalReturned)),
              const SizedBox(width: 24),
              _buildHeroStat('XIRR', '${(stats.xirr * 100).toStringAsFixed(1)}%'),
            ],
          ),
          // Subtitle showing which mode
          if (showRealizedOnly) ...[
            const SizedBox(height: 8),
            Text(
              'Showing closed investments only',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildHeroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, InvestmentStats stats, NumberFormat currencyFormat) {
    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            icon: Icons.trending_up,
            label: 'MOIC',
            value: '${stats.moic.toStringAsFixed(2)}x',
            color: AppColors.successLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickStatCard(
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
          '${date.day}/${date.month}/${date.year}',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Column(
      children: [
        // Welcome section
        GlassCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
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
                  Icons.rocket_launch_rounded,
                  size: 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to Cash Flow Tracker!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track your investments, monitor cash flows, and analyze returns with powerful insights.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Getting started steps
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const SizedBox(height: 16),
              _buildStep(1, 'Add Investment', 'Create your first investment entry', Icons.add_circle_outline, isDark),
              const SizedBox(height: 12),
              _buildStep(2, 'Record Cash Flows', 'Track money in and out over time', Icons.swap_vert_rounded, isDark),
              const SizedBox(height: 12),
              _buildStep(3, 'View Insights', 'Analyze returns, XIRR, and trends', Icons.insights_rounded, isDark),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Call to action hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.touch_app_rounded,
                color: primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap the "Add Investment" button below to begin!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.neutral800Light,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int number, String title, String subtitle, IconData icon, bool isDark) {
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                ),
              ),
            ],
          ),
        ),
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text('Error: $error'),
        ],
      ),
    );
  }
}

class _LoadingHeroCard extends StatelessWidget {
  const _LoadingHeroCard();

  @override
  Widget build(BuildContext context) {
    return GlassHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
