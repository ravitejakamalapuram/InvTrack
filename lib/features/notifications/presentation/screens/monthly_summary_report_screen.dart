/// Monthly Summary Report Screen
///
/// Displays a comprehensive report of investment activity for the past month.
/// Shown when user taps the "Monthly Summary" notification.
///
/// ## Data Displayed
/// - Number of investments tracked
/// - Total amount invested this month
/// - Total returns received
/// - Net cashflow (invested - returns)
/// - Month-over-month comparison
/// - (Future) Chart of monthly cashflows by week
///
/// ## Actions
/// - View All Investments
/// - Add New Transaction
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_metric_card.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class MonthlySummaryReportScreen extends ConsumerStatefulWidget {
  const MonthlySummaryReportScreen({super.key});

  @override
  ConsumerState<MonthlySummaryReportScreen> createState() =>
      _MonthlySummaryReportScreenState();
}

class _MonthlySummaryReportScreenState
    extends ConsumerState<MonthlySummaryReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'monthly_summary'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final investmentsAsync = ref.watch(allInvestmentsProvider);
    final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

    // Calculate month range (1st to last day of current month)
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0); // Last day of month
    final locale = Localizations.localeOf(context).toString();
    final monthName = DateFormat.yMMMM(locale).format(now);

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.calendar_month_rounded,
        title: l10n.monthlySummaryReport,
        subtitle: monthName,
      ),
      body: investmentsAsync.when(
        data: (investments) {
          return cashFlowsAsync.when(
            data: (cashFlows) {
              return _buildContent(
                context,
                investments,
                cashFlows,
                monthStart,
                monthEnd,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(l10n.errorLoadingData),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(l10n.errorLoadingInvestment),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<InvestmentEntity> investments,
    List<dynamic> cashFlows,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyLocale = ref.watch(currencyLocaleProvider);

    // Filter active investments
    final activeInvestments =
        investments.where((inv) => !inv.isArchived).toList();

    // Filter cashflows from this month
    final monthlyCashFlows = cashFlows.where((cf) {
      final date = cf.date;
      return date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          date.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    // Calculate previous month for comparison
    final prevMonthStart = DateTime(monthStart.year, monthStart.month - 1, 1);
    final prevMonthEnd = DateTime(monthStart.year, monthStart.month, 0);
    final prevMonthlyCashFlows = cashFlows.where((cf) {
      final date = cf.date;
      return date.isAfter(prevMonthStart.subtract(const Duration(days: 1))) &&
          date.isBefore(prevMonthEnd.add(const Duration(days: 1)));
    }).toList();

    // Calculate metrics for current month
    final investmentsTracked = activeInvestments.length;
    final totalInvested = monthlyCashFlows
        .where((cf) => cf.type == CashFlowType.invest)
        .fold<double>(0, (sum, cf) => sum + cf.amount);
    final totalReturns = monthlyCashFlows
        .where((cf) => cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income)
        .fold<double>(0, (sum, cf) => sum + cf.amount);
    final netCashFlow = totalInvested - totalReturns;

    // Calculate previous month metrics
    final prevTotalInvested = prevMonthlyCashFlows
        .where((cf) => cf.type == CashFlowType.invest)
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    // Month-over-month change
    final monthOverMonthChange = prevTotalInvested > 0
        ? ((totalInvested - prevTotalInvested) / prevTotalInvested) * 100
        : 0.0;
    final isPositiveChange = monthOverMonthChange >= 0;

    // Format amounts
    final totalInvestedFormatted = formatCompactCurrency(
      totalInvested,
      symbol: currencySymbol,
      locale: currencyLocale,
    );
    final totalReturnsFormatted = formatCompactCurrency(
      totalReturns,
      symbol: currencySymbol,
      locale: currencyLocale,
    );
    final netCashFlowFormatted = formatCompactCurrency(
      netCashFlow,
      symbol: currencySymbol,
      locale: currencyLocale,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpacing.md),

          // Key Metrics Grid
          ReportMetricsGrid(
            metrics: [
              ReportMetricCard(
                label: 'Investments Tracked',
                value: '$investmentsTracked',
                icon: Icons.account_balance_wallet_outlined,
              ),
              ReportMetricCard(
                label: 'Invested This Month',
                value: totalInvestedFormatted,
                trend: monthOverMonthChange != 0
                    ? '${isPositiveChange ? '+' : ''}${monthOverMonthChange.toStringAsFixed(1)}% from last month'
                    : null,
                icon: Icons.add_circle_outline,
                isSensitive: true,
              ),
              ReportMetricCard(
                label: 'Returns Received',
                value: totalReturnsFormatted,
                trend:
                    '${monthlyCashFlows.where((cf) => cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income).length} transactions',
                icon: Icons.trending_up_rounded,
                accentColor: AppColors.successLight,
                isSensitive: true,
              ),
              ReportMetricCard(
                label: 'Net Cash Flow',
                value: netCashFlowFormatted,
                trend: netCashFlow > 0
                    ? 'Net investment'
                    : netCashFlow < 0
                        ? 'Net return'
                        : 'Break-even',
                icon: Icons.account_balance_rounded,
                accentColor: netCashFlow > 0
                    ? AppColors.warningLight
                    : AppColors.successLight,
                isSensitive: true,
              ),
            ],
          ),

          SizedBox(height: AppSpacing.lg),

          // TODO: Add monthly cashflow chart (bar chart with 4 weeks)

          SizedBox(height: AppSpacing.lg),

          // Action Buttons
          ReportActionButtons(
            buttons: [
              ReportActionButton(
                label: l10n.viewAllInvestments,
                icon: Icons.list_rounded,
                onPressed: () => context.go('/investments'),
              ),
              ReportActionButton(
                label: l10n.addNewTransaction,
                icon: Icons.add_rounded,
                isPrimary: false,
                onPressed: () {
                  context.go('/investments/add');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
