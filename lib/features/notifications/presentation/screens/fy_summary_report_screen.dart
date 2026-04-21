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
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_metric_card.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
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
    final investmentsAsync = ref.watch(allInvestmentsProvider);
    final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

    // FY in India: April 1 to March 31
    final now = DateTime.now();
    final fyStart = now.month >= 4
        ? DateTime(now.year, 4, 1)
        : DateTime(now.year - 1, 4, 1);
    final fyEnd = DateTime(fyStart.year + 1, 3, 31);
    final fyLabel = 'FY ${fyStart.year}-${fyEnd.year % 100}';

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.calendar_today_rounded,
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
                Center(child: Text(l10n.errorLoadingData)),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.errorLoadingInvestment)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<InvestmentEntity> investments,
    List<CashFlowEntity> cashFlows,
    DateTime fyStart,
    DateTime fyEnd,
  ) {
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyLocale = ref.watch(currencyLocaleProvider);
    final userCurrency = ref.watch(currencyCodeProvider);
    final conversionService = ref.watch(currencyConversionServiceProvider);

    // Filter cashflows from this FY
    final fyCashFlows = cashFlows.where((cf) {
      final date = cf.date;
      return date.isAfter(fyStart.subtract(const Duration(days: 1))) &&
          date.isBefore(fyEnd.add(const Duration(days: 1)));
    }).toList();

    // Create future for calculating converted metrics
    final metricsFuture = _calculateConvertedMetrics(
      fyCashFlows,
      userCurrency,
      conversionService,
    );

    return FutureBuilder<Map<String, double>>(
      future: metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(l10n.errorLoadingData));
        }

        final metrics = snapshot.data!;
        final totalInvested = metrics['invested']!;
        final totalReturns = metrics['returns']!;

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
                    label: l10n.totalInvestedFY,
                    value: totalInvestedFormatted,
                    icon: Icons.add_circle_outline,
                    isSensitive: true,
                  ),
                  ReportMetricCard(
                    label: l10n.totalReturnsFY,
                    value: totalReturnsFormatted,
                    icon: Icons.trending_up_rounded,
                    accentColor: AppColors.successLight,
                    isSensitive: true,
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
      },
    );
  }

  Future<Map<String, double>> _calculateConvertedMetrics(
    List<CashFlowEntity> cashFlows,
    String userCurrency,
    CurrencyConversionService conversionService,
  ) async {
    // Build list of futures for invest cash flows
    final investFutures = cashFlows
        .where((cf) => cf.type == CashFlowType.invest)
        .map((cf) => conversionService.convert(
              amount: cf.amount,
              from: cf.currency,
              to: userCurrency,
            ))
        .toList();

    // Build list of futures for returns cash flows
    final returnsFutures = cashFlows
        .where((cf) => cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income)
        .map((cf) => conversionService.convert(
              amount: cf.amount,
              from: cf.currency,
              to: userCurrency,
            ))
        .toList();

    // Await all conversions in parallel
    final investResults = await Future.wait(investFutures);
    final returnsResults = await Future.wait(returnsFutures);

    // Sum the converted amounts
    final totalInvested = investResults.fold<double>(0, (sum, amount) => sum + amount);
    final totalReturns = returnsResults.fold<double>(0, (sum, amount) => sum + amount);

    return {
      'invested': totalInvested,
      'returns': totalReturns,
    };
  }
}