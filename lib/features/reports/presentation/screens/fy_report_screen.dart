/// Financial Year Report Screen
///
/// Shows comprehensive FY (Apr-Mar) performance including:
/// - Total invested/returned, net cashflow, XIRR
/// - Monthly breakdown with trends
/// - Capital gains (short-term vs long-term)
/// - Top performers by returns and XIRR
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/base_report_screen.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';

class FYReportScreen extends BaseReportScreen<FYReport> {
  final int? fyYear;

  const FYReportScreen({super.key, this.fyYear});

  @override
  String getTitle(BuildContext context) {
    if (fyYear != null) {
      return 'FY $fyYear-${(fyYear! + 1) % 100}';
    }
    return 'Financial Year Report';
  }

  @override
  FutureProvider<FYReport> getDataProvider(WidgetRef ref) {
    return fyYear != null
        ? fyReportProvider(fyYear!)
        : currentFYReportProvider;
  }

  @override
  Widget buildContent(BuildContext context, WidgetRef ref, FYReport report) {
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
            // Summary Stats
            Text(
              'Summary (${report.fyLabel})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ReportStatCard(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Total Invested',
                    value: formatCompactCurrency(
                      report.totalInvested,
                      symbol: symbol,
                      locale: locale,
                    ),
                    iconColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReportStatCard(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Total Returns',
                    value: formatCompactCurrency(
                      report.totalReturns,
                      symbol: symbol,
                      locale: locale,
                    ),
                    iconColor: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ReportStatCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Net Cashflow',
                    value: formatCompactCurrency(
                      report.netCashFlow,
                      symbol: symbol,
                      locale: locale,
                    ),
                    iconColor: report.netCashFlow >= 0 ? Colors.green : Colors.red,
                    isTrendPositive: report.netCashFlow >= 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReportStatCard(
                    icon: Icons.trending_up_rounded,
                    label: 'XIRR',
                    value: '${(report.xirr * 100).toStringAsFixed(2)}%',
                    iconColor: report.xirr >= 0 ? Colors.green : Colors.red,
                    isTrendPositive: report.xirr >= 0,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Capital Gains
            _buildCapitalGainsSection(context, report, symbol, locale),

            const SizedBox(height: 24),

            // Top Performers
            _buildTopPerformersSection(context, report, symbol, locale),

            const SizedBox(height: 24),

            // Monthly Breakdown
            _buildMonthlyBreakdownSection(context, report, symbol, locale),
          ],
        );
  }

  Widget _buildCapitalGainsSection(
    BuildContext context,
    report,
    String symbol,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capital Gains',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.flash_on_rounded,
                label: 'Short-term (<1yr)',
                value: formatCompactCurrency(
                  report.shortTermCapitalGains,
                  symbol: symbol,
                  locale: locale,
                ),
                iconColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.savings_rounded,
                label: 'Long-term (>1yr)',
                value: formatCompactCurrency(
                  report.longTermCapitalGains,
                  symbol: symbol,
                  locale: locale,
                ),
                iconColor: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopPerformersSection(
    BuildContext context,
    report,
    String symbol,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Performers',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        // By Returns
        Text(
          'By Absolute Returns',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...report.topPerformersByReturns.take(5).map((performer) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(performer.investment.name),
            trailing: PrivacyMask(
              child: Text(
                formatCompactCurrency(
                  performer.absoluteReturns,
                  symbol: symbol,
                  locale: locale,
                ),
                style: TextStyle(
                  color: performer.absoluteReturns >= 0
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // By XIRR
        Text(
          'By XIRR',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...report.topPerformersByXIRR.take(5).map((performer) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(performer.investment.name),
            trailing: PrivacyMask(
              child: Text(
                '${(performer.xirr * 100).toStringAsFixed(2)}%',
                style: TextStyle(
                  color: performer.xirr >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMonthlyBreakdownSection(
    BuildContext context,
    report,
    String symbol,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Breakdown',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...report.monthlyBreakdown.map((monthData) {
          final monthName = '${monthData.monthName} ${monthData.year}';
          return Card(
            child: ListTile(
              title: Text(monthName),
              subtitle: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invested: ${formatCompactCurrency(monthData.invested, symbol: symbol, locale: locale)}'),
                        Text('Returned: ${formatCompactCurrency(monthData.returns, symbol: symbol, locale: locale)}'),
                      ],
                    ),
                  ),
                ],
              ),
              trailing: PrivacyMask(
                child: Text(
                  formatCompactCurrency(
                    monthData.net,
                    symbol: symbol,
                    locale: locale,
                  ),
                  style: TextStyle(
                    color: monthData.net >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

