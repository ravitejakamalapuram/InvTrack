import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/data/presentation/providers/data_provider.dart';
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
    final currencySymbol = ref.watch(currencySymbolProvider);
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
            // Refresh from cloud (for Google users) or just invalidate local data (for guests)
            final result = await ref.read(dataControllerProvider).refreshFromCloud();
            result.when(
              success: (_) {
                // Invalidate providers to refresh UI
                ref.invalidate(globalStatsProvider);
                ref.invalidate(openInvestmentsStatsProvider);
                ref.invalidate(closedInvestmentsStatsProvider);
              },
              failure: (error) {
                // Show error toast if refresh failed
                if (context.mounted) {
                  AppFeedback.showError(context, error);
                }
              },
            );
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
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Hero Card - Global Summary with toggle
                    _buildHeroCardWithToggle(context, ref, globalStats, closedStats, currencySymbol),

                    const SizedBox(height: 24),

                    // Quick Stats Grid
                    globalStats.when(
                      data: (stats) => _buildQuickStats(context, stats, currencySymbol),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),

                    // Net Position Breakdown (Open vs Closed)
                    _buildNetPositionBreakdown(context, ref, openStats, closedStats, currencySymbol, isDark),

                    const SizedBox(height: 24),

                    // Monthly Cash Flow Trend
                    _buildMonthlyCashFlowTrend(context, ref, currencySymbol, isDark),

                    const SizedBox(height: 24),

                    // Top Performers
                    _buildTopPerformers(context, ref, currencySymbol, isDark),

                    const SizedBox(height: 24),

                    // Investment Type Distribution
                    _buildTypeDistribution(context, ref, currencySymbol, isDark),

                    const SizedBox(height: 24),

                    // YoY Comparison
                    _buildYoYComparison(context, ref, currencySymbol, isDark),

                    const SizedBox(height: 24),

                    // Recently Closed
                    _buildRecentlyClosed(context, ref, currencySymbol, isDark),

                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(context, ref, isDark),

                    const SizedBox(height: 24),

                    // Empty state or Investment Period summary
                    globalStats.when(
                      data: (stats) => stats.hasData
                          ? _buildSummarySection(context, stats)
                          : _buildEmptyState(context),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),

                    // Recent Activity
                    _buildRecentActivity(context, ref, currencySymbol),

                    // Bottom padding for FAB
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetPositionBreakdown(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> openStats,
    AsyncValue<InvestmentStats> closedStats,
    String currency,
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
                        currency,
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
                        currency,
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
    String currency,
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
            '${isPositive ? '+' : ''}$currency${value.toStringAsFixed(0)}',
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

  Widget _buildMonthlyCashFlowTrend(BuildContext context, WidgetRef ref, String currency, bool isDark) {
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

  Widget _buildTopPerformers(BuildContext context, WidgetRef ref, String currency, bool isDark) {
    final topAsync = ref.watch(topPerformersProvider);

    return topAsync.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Text('Top Performers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              ...data.asMap().entries.map((e) {
                final rank = e.key + 1;
                final item = e.value;
                final xirrPercent = (item.stats.xirr * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey[400] : Colors.brown[300]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.investment.name, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(item.investment.type.displayName, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.successLight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('+$xirrPercent% IRR', style: TextStyle(color: AppColors.successLight, fontWeight: FontWeight.w600, fontSize: 12)),
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

  Widget _buildTypeDistribution(BuildContext context, WidgetRef ref, String currency, bool isDark) {
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

  Widget _buildYoYComparison(BuildContext context, WidgetRef ref, String currency, bool isDark) {
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
                  Expanded(child: _buildYoYColumn(lastYear, data.lastYearNet, currency, isDark)),
                  Container(width: 1, height: 60, color: isDark ? Colors.white24 : Colors.grey[300]),
                  Expanded(child: _buildYoYColumn(thisYear, data.thisYearNet, currency, isDark)),
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

  Widget _buildYoYColumn(String year, double net, String currency, bool isDark) {
    final isPositive = net >= 0;
    return Column(
      children: [
        Text(year, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '${isPositive ? '+' : ''}$currency${net.toStringAsFixed(0)}',
          style: TextStyle(
            color: isPositive ? AppColors.successLight : AppColors.errorLight,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyClosed(BuildContext context, WidgetRef ref, String currency, bool isDark) {
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
                            '${isProfit ? '+' : ''}$currency${item.stats.netCashFlow.toStringAsFixed(0)}',
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

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_circle,
                  label: 'New Investment',
                  color: AppColors.primaryLight,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInvestmentScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.refresh,
                  label: 'Refresh',
                  color: AppColors.graphBlue,
                  onTap: () async {
                    // Refresh from cloud (for Google users) or just invalidate local providers
                    final result = await ref.read(dataControllerProvider).refreshFromCloud();
                    result.when(
                      success: (_) {
                        // Invalidate local providers to refresh UI
                        ref.invalidate(globalStatsProvider);
                        ref.invalidate(openInvestmentsStatsProvider);
                        ref.invalidate(closedInvestmentsStatsProvider);
                        ref.invalidate(topPerformersProvider);
                        ref.invalidate(monthlyCashFlowTrendProvider);
                      },
                      failure: (error) {
                        // Still invalidate to show cached data
                        ref.invalidate(globalStatsProvider);
                        ref.invalidate(openInvestmentsStatsProvider);
                        ref.invalidate(closedInvestmentsStatsProvider);
                        ref.invalidate(topPerformersProvider);
                        ref.invalidate(monthlyCashFlowTrendProvider);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCardWithToggle(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<InvestmentStats> globalStats,
    AsyncValue<InvestmentStats> closedStats,
    String currency,
  ) {
    final showRealizedOnly = ref.watch(showRealizedOnlyProvider);

    return globalStats.when(
      loading: () => const _LoadingHeroCard(),
      error: (e, _) => _buildErrorCard(context, e.toString()),
      data: (global) => closedStats.when(
        loading: () => _buildHeroCardContent(context, ref, global, global, currency, showRealizedOnly),
        error: (_, __) => _buildHeroCardContent(context, ref, global, global, currency, showRealizedOnly),
        data: (closed) => _buildHeroCardContent(context, ref, global, closed, currency, showRealizedOnly),
      ),
    );
  }

  Widget _buildHeroCardContent(
    BuildContext context,
    WidgetRef ref,
    InvestmentStats globalStats,
    InvestmentStats closedStats,
    String currency,
    bool showRealizedOnly,
  ) {
    final stats = showRealizedOnly ? closedStats : globalStats;
    final netPosition = stats.netCashFlow;
    final isPositive = netPosition >= 0;

    final semanticLabel = AccessibilityUtils.statCardLabel(
      title: showRealizedOnly ? 'Realized Net Position' : 'Net Position All Investments',
      value: AccessibilityUtils.formatCurrencyForScreenReader(netPosition, currency),
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
                '${isPositive ? '+' : ''}$currency${netPosition.abs().toStringAsFixed(0)}',
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
              _buildHeroStat('Cash Out', '$currency${stats.totalInvested.toStringAsFixed(0)}'),
              const SizedBox(width: 24),
              _buildHeroStat('Cash In', '$currency${stats.totalReturned.toStringAsFixed(0)}'),
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

  Widget _buildQuickStats(BuildContext context, InvestmentStats stats, String currency) {
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

  Widget _buildEmptyState(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No investments yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first investment to start tracking cash flows',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
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

  Widget _buildRecentActivity(BuildContext context, WidgetRef ref, String currency) {
    final recentActivity = ref.watch(recentCashFlowsProvider);

    return recentActivity.when(
      data: (cashFlows) {
        if (cashFlows.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${cashFlows.length} items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...cashFlows.map((item) => _buildRecentActivityItem(context, item, currency)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentActivityItem(BuildContext context, CashFlowWithInvestment item, String currency) {
    final cf = item.cashFlow;
    final isInflow = cf.type.isInflow;
    final color = isInflow ? AppColors.successLight : AppColors.errorLight;
    final icon = isInflow ? Icons.arrow_downward : Icons.arrow_upward;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.investment?.name ?? 'Unknown Investment',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${cf.type.displayName} • ${cf.date.day}/${cf.date.month}/${cf.date.year}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isInflow ? '+' : '-'}$currency${cf.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
        ),
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
