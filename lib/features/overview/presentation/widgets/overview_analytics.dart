/// Analytics widgets for the overview screen.
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

/// Monthly cash flow trend chart.
class MonthlyCashFlowTrend extends ConsumerWidget {
  final NumberFormat currencyFormat;

  const MonthlyCashFlowTrend({super.key, required this.currencyFormat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trendAsync = ref.watch(monthlyCashFlowTrendProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return trendAsync.when(
      data: (data) {
        if (data.isEmpty ||
            data.every((d) => d.inflows == 0 && d.outflows == 0)) {
          return const SizedBox.shrink();
        }

        // Optimization: Replace list creation and .reduce() with faster math.max calls
        // to avoid allocating a new list and invoking closures on every iteration.
        final maxValue = data.fold<double>(
          0,
          (max, d) => math.max(max, math.max(d.inflows, d.outflows)),
        );

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Cash Flow Trend',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              // Fade chart in privacy mode to hide relative proportions
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isPrivacyMode ? 0.15 : 1.0,
                child: SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.map((d) {
                      final months = [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec',
                      ];
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
                                        height: maxValue > 0
                                            ? (d.outflows / maxValue * 80)
                                            : 0,
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.errorLight.withValues(
                                            alpha: 0.7,
                                          ),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Container(
                                        height: maxValue > 0
                                            ? (d.inflows / maxValue * 80)
                                            : 0,
                                        decoration: BoxDecoration(
                                          color: AppColors.successLight
                                              .withValues(alpha: 0.7),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                months[d.month.month - 1],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white54 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// Investment type distribution chart.
class TypeDistributionChart extends ConsumerWidget {
  final NumberFormat currencyFormat;

  const TypeDistributionChart({super.key, required this.currencyFormat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final distAsync = ref.watch(investmentTypeDistributionProvider);

    return distAsync.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        final total = data.fold<double>(0, (sum, d) => sum + d.totalInvested);
        if (total == 0) return const SizedBox.shrink();

        final colors = [
          AppColors.graphBlue,
          AppColors.graphEmerald,
          AppColors.graphAmber,
          AppColors.graphPurple,
          AppColors.graphPink,
          AppColors.graphCyan,
        ];

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Investment Distribution',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildDistributionBar(data, total, colors),
              const SizedBox(height: 12),
              _buildLegend(data, total, colors, isDark),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildDistributionBar(
    List<TypeDistribution> data,
    double total,
    List<Color> colors,
  ) {
    return ClipRRect(
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
    );
  }

  Widget _buildLegend(
    List<TypeDistribution> data,
    double total,
    List<Color> colors,
    bool isDark,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: data.asMap().entries.map((e) {
        final pct = (e.value.totalInvested / total * 100).toStringAsFixed(0);
        final color = colors[e.key % colors.length];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${e.value.type.displayName} ($pct%)',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// Year over year comparison widget.
class YoYComparisonCard extends ConsumerWidget {
  final NumberFormat currencyFormat;

  const YoYComparisonCard({super.key, required this.currencyFormat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yoyAsync = ref.watch(yoyComparisonProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return yoyAsync.when(
      data: (data) {
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
                  Icon(
                    Icons.compare_arrows,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Year over Year',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildYoYColumn(
                      lastYear,
                      data.lastYearNet,
                      isDark,
                      isPrivacyMode,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: isDark ? Colors.white24 : Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildYoYColumn(
                      thisYear,
                      data.thisYearNet,
                      isDark,
                      isPrivacyMode,
                    ),
                  ),
                ],
              ),
              if (data.lastYearNet != 0) ...[
                const SizedBox(height: 12),
                _buildChangeIndicator(data, isPrivacyMode),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildYoYColumn(
    String year,
    double net,
    bool isDark,
    bool isPrivacyMode,
  ) {
    final isPositive = net >= 0;
    final valueStyle = TextStyle(
      color: isPositive ? AppColors.successLight : AppColors.errorLight,
      fontWeight: FontWeight.bold,
      fontSize: 18,
    );

    return Column(
      children: [
        Text(
          year,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        isPrivacyMode
            ? MaskedAmountText(
                text:
                    '${isPositive ? '+' : '-'}${currencyFormat.formatCompact(net.abs())}',
                style: valueStyle,
              )
            : CompactAmountText(
                amount: net,
                compactText: currencyFormat.formatCompact(net.abs()),
                prefix: isPositive ? '+' : '-',
                style: valueStyle,
              ),
      ],
    );
  }

  Widget _buildChangeIndicator(YoYComparison data, bool isPrivacyMode) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isPrivacyMode ? 0.0 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              (data.isImproved ? AppColors.successLight : AppColors.errorLight)
                  .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              data.isImproved ? Icons.trending_up : Icons.trending_down,
              color: data.isImproved
                  ? AppColors.successLight
                  : AppColors.errorLight,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '${data.netChange >= 0 ? '+' : ''}${data.netChange.toStringAsFixed(0)}% vs last year',
              style: TextStyle(
                color: data.isImproved
                    ? AppColors.successLight
                    : AppColors.errorLight,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recently closed investments widget.
class RecentlyClosedCard extends ConsumerWidget {
  final NumberFormat currencyFormat;

  const RecentlyClosedCard({super.key, required this.currencyFormat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final closedAsync = ref.watch(recentlyClosedInvestmentsProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return closedAsync.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.successLight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recently Closed',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...data.map(
                (item) => _buildClosedItem(item, isDark, isPrivacyMode),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildClosedItem(
    InvestmentWithStats item,
    bool isDark,
    bool isPrivacyMode,
  ) {
    final isProfit = item.stats.netCashFlow >= 0;
    final valueStyle = TextStyle(
      color: isProfit ? AppColors.successLight : AppColors.errorLight,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.investment.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.investment.type.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              isPrivacyMode
                  ? MaskedAmountText(
                      text:
                          '${isProfit ? '+' : '-'}${currencyFormat.formatCompact(item.stats.netCashFlow.abs())}',
                      style: valueStyle,
                    )
                  : CompactAmountText(
                      amount: item.stats.netCashFlow,
                      compactText: currencyFormat.formatCompact(
                        item.stats.netCashFlow.abs(),
                      ),
                      prefix: isProfit ? '+' : '-',
                      style: valueStyle,
                    ),
              if (item.stats.xirr != 0 && !item.stats.xirr.isNaN)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isPrivacyMode ? 0.0 : 1.0,
                  child: Text(
                    '${(item.stats.xirr * 100).toStringAsFixed(1)}% IRR',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
