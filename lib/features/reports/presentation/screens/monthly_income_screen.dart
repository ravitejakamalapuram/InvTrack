/// Monthly Income & Cash Flow Report Screen
///
/// Displays a detailed monthly summary including:
/// - Total income, invested, returns, fees
/// - Net cashflow with month-over-month comparison
/// - Income breakdown by type (Dividend, Interest, Rent, etc.)
/// - Top income-generating investments
/// - All income transactions for the month
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/monthly_income_report.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:inv_tracker/features/reports/presentation/providers/monthly_income_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/base_report_screen.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_export_button.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Monthly income report screen
class MonthlyIncomeScreen extends BaseReportScreen<MonthlyIncomeReport> {
  final DateTime? period;

  const MonthlyIncomeScreen({super.key, this.period});

  @override
  String getTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (period != null) {
      final monthNames = [
        l10n.january, l10n.february, l10n.march, l10n.april,
        l10n.may, l10n.june, l10n.july, l10n.august,
        l10n.september, l10n.october, l10n.november, l10n.december,
      ];
      return '${monthNames[period!.month - 1]} ${period!.year}';
    }
    return l10n.monthlyIncomeReportTitle;
  }

  @override
  FutureProvider<MonthlyIncomeReport> getDataProvider(WidgetRef ref) {
    return period != null
        ? monthlyIncomeProvider(period!)
        : currentMonthlyIncomeProvider;
  }

  @override
  List<Widget> buildActions(BuildContext context, WidgetRef ref, MonthlyIncomeReport data) {
    return [
      ReportExportButton(
        reportData: data,
        reportType: ReportType.monthlyIncome,
      ),
    ];
  }

  @override
  Widget buildContent(
    BuildContext context,
    WidgetRef ref,
    MonthlyIncomeReport data,
  ) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period header
        Text(
          DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(data.period),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.lg),

        // Summary cards
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ReportStatCard(
              icon: Icons.trending_up_rounded,
              label: l10n.totalIncome,
              value: formatCompactCurrency(
                data.totalIncome,
                symbol: symbol,
                locale: locale,
              ),
              iconColor: Colors.green,
            ),
            ReportStatCard(
              icon: Icons.account_balance_wallet_rounded,
              label: l10n.netCashflow,
              value: formatCompactCurrency(
                data.netCashFlow,
                symbol: symbol,
                locale: locale,
              ),
              iconColor: data.isPositiveMonth ? Colors.green : Colors.red,
            ),
            ReportStatCard(
              icon: Icons.attach_money_rounded,
              label: l10n.totalInvested,
              value: formatCompactCurrency(
                data.totalInvested,
                symbol: symbol,
                locale: locale,
              ),
            ),
            ReportStatCard(
              icon: Icons.payments_rounded,
              label: l10n.totalReturns,
              value: formatCompactCurrency(
                data.totalReturns,
                symbol: symbol,
                locale: locale,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // Income by type
        if (data.incomeByType.isNotEmpty) ...[
          _buildIncomeBreakdown(context, ref, data),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Top earners
        if (data.topEarners.isNotEmpty) ...[
          _buildTopEarners(context, ref, data),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Transactions list
        if (data.transactions.isNotEmpty) ...[
          _buildTransactionsList(context, ref, data),
        ],
      ],
    );
  }

  Widget _buildIncomeBreakdown(
    BuildContext context,
    WidgetRef ref,
    MonthlyIncomeReport data,
  ) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.incomeBreakdown,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.incomeByType.entries.map((entry) {
            final percentage = data.totalIncome <= 0
                ? 0.0
                : (entry.value / data.totalIncome) * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(entry.key),
                  ),
                  MaskedAmountText(
                    text: formatCompactCurrency(
                      entry.value,
                      symbol: symbol,
                      locale: locale,
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  MaskedAmountText(
                    text: '${percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopEarners(
    BuildContext context,
    WidgetRef ref,
    MonthlyIncomeReport data,
  ) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.topIncomeGenerators,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.topEarners.map((earner) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          earner.investment.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          earner.incomeType,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  MaskedAmountText(
                    text: formatCompactCurrency(
                      earner.income,
                      symbol: symbol,
                      locale: locale,
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    WidgetRef ref,
    MonthlyIncomeReport data,
  ) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    // Limit to 50 transactions for performance (can show all with pagination later)
    final displayTransactions = data.transactions.take(50).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.allTransactions} (${data.transactions.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          // Use ListView.builder for efficient rendering
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayTransactions.length,
            itemBuilder: (context, index) {
              final tx = displayTransactions[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.investmentName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${DateFormat.MMMd(locale).format(tx.date)} • ${tx.type}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    MaskedAmountText(
                      text: formatCompactCurrency(
                        tx.amount,
                        symbol: symbol,
                        locale: locale,
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.green,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (data.transactions.length > 50) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                '+ ${data.transactions.length - 50} more transactions',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
