/// Weekly Summary Report Screen
///
/// Displays a comprehensive report of investment activity for the past week.
/// Shown when user taps the "Weekly Summary" notification.
///
/// ## Data Displayed
/// - Number of investments tracked
/// - Total amount invested this week
/// - Total returns received
/// - Average return rate
/// - Chart of weekly cashflows
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
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_metric_card.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Weekly summary report screen
class WeeklySummaryReportScreen extends ConsumerStatefulWidget {
  const WeeklySummaryReportScreen({super.key});

  @override
  ConsumerState<WeeklySummaryReportScreen> createState() =>
      _WeeklySummaryReportScreenState();
}

class _WeeklySummaryReportScreenState
    extends ConsumerState<WeeklySummaryReportScreen> {
  @override
  void initState() {
    super.initState();
    
    // Track analytics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {
          'report_type': 'weekly_summary',
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final investmentsAsync = ref.watch(allInvestmentsProvider);
    final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

    // Calculate week range
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekRange =
        '${DateFormat.MMMd().format(weekStart)} - ${DateFormat.MMMd().format(weekEnd)}';

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.calendar_today_rounded,
        title: l10n.weeklySummary,
        subtitle: weekRange,
      ),
      body: investmentsAsync.when(
        data: (investments) {
          return cashFlowsAsync.when(
            data: (cashFlows) {
              return _buildContent(
                context,
                investments,
                cashFlows,
                weekStart,
                weekEnd,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error loading cash flows: $error'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading investments: $error'),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<InvestmentEntity> investments,
    List<dynamic> cashFlows,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final l10n = AppLocalizations.of(context);

    // Filter active investments
    final activeInvestments =
        investments.where((inv) => !inv.isArchived).toList();

    // Filter cashflows from this week
    final weeklyCashFlows = cashFlows.where((cf) {
      final date = cf.date;
      return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          date.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();

    // Calculate metrics
    final investmentsTracked = activeInvestments.length;
    final totalInvested = weeklyCashFlows
        .where((cf) => cf.type.name == 'INVEST')
        .fold<double>(0, (sum, cf) => sum + cf.amount);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpacing.md),

          // Key Metrics
          ReportMetricsGrid(
            metrics: [
              ReportMetricCard(
                label: 'Investments Tracked',
                value: '$investmentsTracked',
                icon: Icons.account_balance_wallet_outlined,
              ),
              ReportMetricCard(
                label: 'Added This Week',
                value: '₹${totalInvested.toStringAsFixed(0)}',
                trend: '${weeklyCashFlows.where((cf) => cf.type.name == 'INVEST').length} transactions',
                icon: Icons.add_circle_outline,
              ),
            ],
          ),

          SizedBox(height: AppSpacing.md),

          // TODO: Add chart visualization here
          // Weekly cashflow bar chart

          SizedBox(height: AppSpacing.lg),

          // Action Buttons
          ReportActionButtons(
            buttons: [
              ReportActionButton(
                label: l10n.viewAllInvestments,
                icon: Icons.list_rounded,
                onPressed: () => context.go('/investments'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
