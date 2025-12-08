import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/gradient_card.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:inv_tracker/features/dashboard/presentation/widgets/portfolio_value_chart.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:inv_tracker/features/sync/presentation/widgets/sync_status_icon.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _hasCheckedPortfolio = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Glow animation for hero card
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDefaultPortfolio();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _ensureDefaultPortfolio() async {
    if (_hasCheckedPortfolio) return;
    _hasCheckedPortfolio = true;
    await ref.read(portfolioProvider.notifier).createDefaultPortfolioIfNone();
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyFormat = ref.watch(currencyFormatProvider);
    final currencyFormatCompact = ref.watch(currencyFormatCompactProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 60,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_getGreeting()}',
                  style: AppTypography.caption.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                ),
                Text(
                  'Your Portfolio',
                  style: AppTypography.h2.copyWith(
                    color: isDark ? AppColors.neutral50Dark : AppColors.neutral900Light,
                  ),
                ),
              ],
            ),
            actions: const [
              SyncStatusIcon(),
              SizedBox(width: 16),
            ],
          ),

          // Main Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero Card - Total Portfolio Value
                _buildHeroCard(metricsAsync, isDark, currencySymbol, currencyFormatCompact),
                const SizedBox(height: 24),

                // Quick Stats Row
                _buildQuickStatsRow(metricsAsync, isDark, currencySymbol),
                const SizedBox(height: 28),

                // Portfolio Performance Section
                _buildSectionHeader('Performance', 'Last 30 days', isDark),
                const SizedBox(height: 16),
                _buildChartCard(metricsAsync, isDark),
                const SizedBox(height: 28),

                // Recent Activity Section
                _buildSectionHeader('Recent Activity', 'Last 5 transactions', isDark),
                const SizedBox(height: 16),
                _buildRecentActivitySection(isDark, currencyFormat),
                const SizedBox(height: 80), // Space for FAB
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(isDark),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildHeroCard(AsyncValue metricsAsync, bool isDark, String currencySymbol, NumberFormat currencyFormatCompact) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryLight.withValues(alpha: _glowAnimation.value),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: GradientCard(
            gradient: isDark ? AppColors.heroGradientDark : AppColors.heroGradient,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Portfolio',
                          style: AppTypography.label.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'All investments',
                          style: AppTypography.small.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Animated change badge
                    metricsAsync.when(
                      data: (m) => _buildAnimatedChangeBadge(m.dayChangePercent),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Animated counter for total value
                metricsAsync.when(
                  data: (m) => AnimatedCounter(
                    value: m.totalValue,
                    prefix: currencySymbol,
                    decimals: 0,
                    duration: const Duration(milliseconds: 1200),
                    style: AppTypography.numberLarge.copyWith(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  loading: () => _buildShimmer(width: 200, height: 52),
                  error: (_, __) => Text(
                    '${currencySymbol}0',
                    style: AppTypography.numberLarge.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                // Today's change with icon
                metricsAsync.when(
                  data: (m) => Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (m.dayChange >= 0 ? AppColors.successLight : AppColors.dangerLight)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              m.dayChange >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${m.dayChange >= 0 ? '+' : ''}${currencyFormatCompact.format(m.dayChange)}',
                              style: AppTypography.label.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'today',
                        style: AppTypography.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  loading: () => _buildShimmer(width: 120, height: 20),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedChangeBadge(double changePercent) {
    final isPositive = changePercent >= 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isPositive ? AppColors.successGradient : AppColors.dangerGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isPositive ? AppColors.successLight : AppColors.dangerLight)
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                  style: AppTypography.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStatsRow(AsyncValue metricsAsync, bool isDark, String currencySymbol) {
    return metricsAsync.when(
      data: (m) => Row(
        children: [
          Expanded(
            child: StaggeredFadeIn(
              index: 0,
              child: _buildPremiumMetricTile(
                label: 'Invested',
                value: m.totalInvested,
                icon: Icons.arrow_circle_down_rounded,
                iconColor: AppColors.accentLight,
                isDark: isDark,
                currencySymbol: currencySymbol,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StaggeredFadeIn(
              index: 1,
              child: _buildPremiumMetricTile(
                label: 'Returns',
                value: m.totalValue - m.totalInvested,
                changePercent: m.totalReturnPercent,
                icon: Icons.arrow_circle_up_rounded,
                iconColor: m.totalReturnPercent >= 0 ? AppColors.successLight : AppColors.dangerLight,
                isDark: isDark,
                currencySymbol: currencySymbol,
              ),
            ),
          ),
        ],
      ),
      loading: () => Row(
        children: [
          Expanded(child: _buildSkeletonTile(isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildSkeletonTile(isDark)),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPremiumMetricTile({
    required String label,
    required double value,
    double? changePercent,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required String currencySymbol,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.neutral700Dark.withValues(alpha: 0.5)
              : AppColors.neutral200Light,
          width: 1,
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: AppColors.neutral500Light.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
              if (changePercent != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (changePercent >= 0 ? AppColors.successLight : AppColors.dangerLight)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                    style: AppTypography.small.copyWith(
                      color: changePercent >= 0 ? AppColors.successLight : AppColors.dangerLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: AppTypography.small.copyWith(
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedCounter(
            value: value,
            prefix: currencySymbol,
            decimals: 0,
            duration: const Duration(milliseconds: 1000),
            style: AppTypography.h3.copyWith(
              color: isDark ? AppColors.neutral50Dark : AppColors.neutral900Light,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.h3.copyWith(
                color: isDark ? AppColors.neutral50Dark : AppColors.neutral900Light,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.neutral500Dark : AppColors.neutral500Light,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            'See all',
            style: AppTypography.label.copyWith(
              color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(AsyncValue<DashboardMetrics> metricsAsync, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 220,
        child: metricsAsync.when(
          data: (m) {
            if (m.historicalData.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 48,
                      color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No data yet',
                      style: AppTypography.body.copyWith(
                        color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                      ),
                    ),
                    Text(
                      'Add investments to see performance',
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.neutral500Dark : AppColors.neutral500Light,
                      ),
                    ),
                  ],
                ),
              );
            }
            final spots = <FlSpot>[
              for (final e in m.historicalData.entries)
                FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value),
            ];
            spots.sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));
            final minX = spots.first.x;
            final maxX = spots.last.x;
            final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
            final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
            final yPadding = (maxY - minY) * 0.1;

            return PortfolioValueChart(
              spots: spots,
              minX: minX,
              maxX: maxX,
              minY: minY - yPadding,
              maxY: maxY + yPadding,
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e', style: AppTypography.caption),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildSkeletonTile(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.neutral700Dark
                  : AppColors.neutral200Light,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 100,
            height: 24,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.neutral700Dark
                  : AppColors.neutral200Light,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(bool isDark, NumberFormat currencyFormat) {
    final recentAsync = ref.watch(recentTransactionsProvider);

    return recentAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 48,
                    color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: AppTypography.body.copyWith(
                      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your first investment to get started',
                    style: AppTypography.small.copyWith(
                      color: isDark ? AppColors.neutral500Dark : AppColors.neutral500Light,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: transactions.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == transactions.length - 1;

              return StaggeredFadeIn(
                index: index,
                child: _buildTransactionRow(item, currencyFormat, isDark, isLast),
              );
            }).toList(),
          ),
        );
      },
      loading: () => GlassCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTransactionRow(
    RecentTransaction item,
    NumberFormat currencyFormat,
    bool isDark,
    bool isLast,
  ) {
    final transaction = item.transaction;
    final typeColor = switch (transaction.type) {
      'BUY' => AppColors.successLight,
      'SELL' => AppColors.dangerLight,
      'DIVIDEND' => AppColors.graphAmber,
      _ => AppColors.neutral500Light,
    };
    final typeIcon = switch (transaction.type) {
      'BUY' => Icons.arrow_downward_rounded,
      'SELL' => Icons.arrow_upward_rounded,
      'DIVIDEND' => Icons.payments_rounded,
      _ => Icons.swap_horiz_rounded,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.investmentName,
                      style: AppTypography.body.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${transaction.type} • ${DateFormat.MMMd().format(transaction.date)}',
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                currencyFormat.format(transaction.totalAmount),
                style: AppTypography.body.copyWith(
                  color: typeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 68,
            color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
          ),
      ],
    );
  }

  Widget _buildFAB(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddInvestmentScreen()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Investment',
          style: AppTypography.button.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
