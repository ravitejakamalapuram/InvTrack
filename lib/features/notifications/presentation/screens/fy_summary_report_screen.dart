/// FY Summary Report Screen
///
/// Displays annual summary for the financial year.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_metric_card.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investments_provider.dart';
import 'package:inv_tracker/features/cashflow/presentation/providers/cashflows_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class FYSummaryReportScreen extends ConsumerStatefulWidget {
  const FYSummaryReportScreen({super.key});

  @override
  ConsumerState<FYSummaryReportScreen> createState() =>
      _FYSummaryReportScreenState();
}

class _FYSummaryReportScreenState
    extends ConsumerState<FYSummaryReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'fy_summary'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final investmentsAsync = ref.watch(investmentsStreamProvider);
    final cashFlowsAsync = ref.watch(cashFlowsStreamProvider);

    // FY in India: April 1 to March 31
    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
    final fyEnd = DateTime(fyStart.year + 1, 3, 31);
    final fyLabel = 'FY ${fyStart.year}-${fyEnd.year % 100}';

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.calendar_view_year_rounded,
        title: l10n.fySummary,
        subtitle: fyLabel,
      ),
      body: investmentsAsync.when(
        data: (investments) {
          return cashFlowsAsync.when(
            data: (cashFlows) {
              return _buildContent(context, investments, cashFlows, fyStart, fyEnd);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading cashflows: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading investments: $error')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<InvestmentEntity> investments,
    List<dynamic> cashFlows,
    DateTime fyStart,
    DateTime fyEnd,
  ) {
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyLocale = ref.watch(currencyLocaleProvider);

    // Filter cashflows from this FY
    final fyCashFlows = cashFlows.where((cf) {
      final date = cf.date;
      return date.isAfter(fyStart.subtract(const Duration(days: 1))) &&
          date.isBefore(fyEnd.add(const Duration(days: 1)));
    }).toList();

    // Calculate metrics
    final totalInvested = fyCashFlows
        .where((cf) => cf.type.name == 'INVEST')
        .fold<double>(0, (sum, cf) => sum + cf.amount);
    final totalReturns = fyCashFlows
        .where((cf) => cf.type.name == 'RETURN' || cf.type.name == 'INCOME')
        .fold<double>(0, (sum, cf) => sum + cf.amount);

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

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: AppSpacing.md),

          // Metrics
          ReportMetricsGrid(
            metrics: [
              ReportMetricCard(
                label: 'Total Invested (FY)',
                value: totalInvestedFormatted,
                icon: Icons.add_circle_outline,
              ),
              ReportMetricCard(
                label: 'Total Returns (FY)',
                value: totalReturnsFormatted,
                icon: Icons.trending_up_rounded,
                accentColor: AppColors.successLight,
              ),
            ],
          ),

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
