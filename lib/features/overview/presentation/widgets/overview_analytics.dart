/// Analytics widgets for the overview screen.
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

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

        // Optimization: Replace .fold() with standard loop to avoid closure overhead
        double maxValue = 0.0;
        for (final d in data) {
          final maxVal = math.max(d.inflows, d.outflows);
          if (maxVal > maxValue) {
            maxValue = maxVal;
          }
        }

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
                                          color: AppColors.errorLight
                                              .withValues(alpha: 0.7),
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

        // Optimization: Replace .fold() with standard loop to avoid closure overhead
        double total = 0.0;
        for (final d in data) {
          total += d.totalInvested;
        }
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

/// Year over year comparison widget: the financial year to date against the
/// same days of the previous financial year, with invested, returned, income
/// and net shown separately. Amounts are in neutral colours, because
/// investing more is not a decline; only the change in income is
/// highlighted, since principal coming back is not growth.
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
        if (!data.hasActivity) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context);
        final dayFormat = DateFormat.MMMd(l10n.localeName);
        final secondary = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;
        final end = data.periodEnd;
        final lastDay = DateTime(end.year, end.month, end.day - 1);
        final lastYear = _fyLabel(l10n, data.previousPeriodStart);
        final thisYear = _fyLabel(l10n, data.periodStart);
        Widget amountRow(
          String label,
          double last,
          double current, {
          bool signed = false,
        }) => _buildAmountRow(
          l10n,
          label,
          (lastYear, last),
          (thisYear, current),
          secondary,
          isPrivacyMode,
          signed: signed,
        );

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
                  Text(
                    l10n.yoyTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.yoyPeriodCaption(
                  dayFormat.format(data.periodStart),
                  dayFormat.format(lastDay),
                ),
                style: TextStyle(color: secondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              // Each amount row is read with its own years.
              ExcludeSemantics(
                child: _buildRow(
                  label: const SizedBox.shrink(),
                  last: _header(lastYear, secondary),
                  current: _header(thisYear, secondary),
                ),
              ),
              const SizedBox(height: 8),
              amountRow(
                l10n.investedLabel,
                data.lastYearInvested,
                data.thisYearInvested,
              ),
              const SizedBox(height: 6),
              amountRow(
                l10n.yoyReturnedLabel,
                data.lastYearCapitalReturned,
                data.thisYearCapitalReturned,
              ),
              const SizedBox(height: 6),
              amountRow(
                l10n.yoyIncomeLabel,
                data.lastYearIncome,
                data.thisYearIncome,
              ),
              const SizedBox(height: 6),
              amountRow(
                l10n.yoyNetLabel,
                data.lastYearNet,
                data.thisYearNet,
                signed: true,
              ),
              if (data.incomeChangePercent case final change?) ...[
                const SizedBox(height: 12),
                _buildChangeIndicator(l10n, change, secondary, isPrivacyMode),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  /// "FY 2026-27" for the financial year starting on [start].
  String _fyLabel(AppLocalizations l10n, DateTime start) => l10n.fyLabel(
    start.year.toString(),
    ((start.year + 1) % 100).toString().padLeft(2, '0'),
  );

  Widget _header(String text, Color color) {
    return Text(
      text,
      textAlign: TextAlign.end,
      style: TextStyle(color: color, fontSize: 12),
    );
  }

  Widget _buildRow({
    required Widget label,
    required Widget last,
    required Widget current,
  }) {
    return Row(
      children: [
        Expanded(flex: 3, child: label),
        Expanded(flex: 2, child: last),
        Expanded(flex: 2, child: current),
      ],
    );
  }

  /// One row of amounts, read by screen readers as "Invested: FY 2025-26
  /// 6 lakh rupees, FY 2026-27 9 lakh rupees" (each amount "Hidden
  /// amount" in privacy mode), since the cells alone carry no year.
  Widget _buildAmountRow(
    AppLocalizations l10n,
    String label,
    (String, double) last,
    (String, double) current,
    Color labelColor,
    bool isPrivacyMode, {
    bool signed = false,
  }) {
    String spoken(double amount) => isPrivacyMode
        ? l10n.hiddenAmount
        : AccessibilityUtils.formatCurrencyForScreenReader(
            amount,
            currencyFormat.currencySymbol,
            locale: currencyFormat.locale,
          ).trim();
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.yoyRowSemantics(
        label,
        last.$1,
        spoken(last.$2),
        current.$1,
        spoken(current.$2),
      ),
      child: _buildRow(
        label: Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
        last: _buildAmount(last.$2, isPrivacyMode, signed: signed),
        current: _buildAmount(current.$2, isPrivacyMode, signed: signed),
      ),
    );
  }

  Widget _buildAmount(
    double amount,
    bool isPrivacyMode, {
    bool signed = false,
  }) {
    const style = TextStyle(fontWeight: FontWeight.w600, fontSize: 14);
    final prefix = signed ? (amount >= 0 ? '+' : '-') : null;
    final compact = currencyFormat.formatCompact(amount.abs());
    return Align(
      alignment: Alignment.centerRight,
      child: isPrivacyMode
          ? MaskedAmountText(
              text: '${prefix ?? ''}$compact',
              style: style,
              textAlign: TextAlign.end,
            )
          : CompactAmountText(
              amount: amount,
              compactText: compact,
              currencySymbol: currencyFormat.currencySymbol,
              locale: currencyFormat.locale,
              prefix: prefix,
              style: style,
              textAlign: TextAlign.end,
            ),
    );
  }

  /// The change in income. An increase is shown in green; a decrease in a
  /// neutral colour, since a holding may simply have matured.
  Widget _buildChangeIndicator(
    AppLocalizations l10n,
    double change,
    Color neutral,
    bool isPrivacyMode,
  ) {
    final isUp = change > 0;
    final color = isUp ? AppColors.successLight : neutral;
    final icon = isUp
        ? Icons.trending_up
        : change < 0
        ? Icons.trending_down
        : Icons.trending_flat;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isPrivacyMode ? 0.0 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.yoyIncomeChange(formatPercent(change, showSign: true)),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
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
                (item) => _buildClosedItem(
                  item,
                  isDark,
                  isPrivacyMode,
                  investmentTypeName(ref, item.investment),
                ),
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
    String typeName,
  ) {
    final isProfit = item.stats.netCashFlow >= 0;
    // Undefined (null) XIRR shows no IRR line, never "0.0% IRR".
    final xirr = item.stats.xirr;
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
                  typeName,
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
                      currencySymbol: currencyFormat.currencySymbol,
                      prefix: isProfit ? '+' : '-',
                      style: valueStyle,
                    ),
              if (xirr != null && xirr.isFinite)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isPrivacyMode ? 0.0 : 1.0,
                  child: Text(
                    '${(xirr * 100).toStringAsFixed(1)}% IRR',
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
