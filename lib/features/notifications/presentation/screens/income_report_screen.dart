/// Income Report Screen
///
/// Displays expected income alert for an investment.
/// Shown when user taps the "Income Alert" notification.
///
/// ## Data Displayed
/// - Investment details
/// - Expected income amount
/// - Income frequency (monthly, quarterly, annual)
/// - Last income received date
/// - Action to record income
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

class IncomeReportScreen extends ConsumerStatefulWidget {
  final String investmentId;

  const IncomeReportScreen({super.key, required this.investmentId});

  @override
  ConsumerState<IncomeReportScreen> createState() =>
      _IncomeReportScreenState();
}

class _IncomeReportScreenState extends ConsumerState<IncomeReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'income'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final investmentsAsync = ref.watch(allInvestmentsProvider);
    final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.payments_rounded,
        title: l10n.incomeAlert,
      ),
      body: investmentsAsync.when(
        data: (investments) {
          final investment = investments.cast<InvestmentEntity?>().firstWhere(
            (inv) => inv?.id == widget.investmentId,
            orElse: () => null,
          );

          if (investment == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: AppColors.errorLight,
                  ),
                  SizedBox(height: AppSpacing.md),
                  const Text('Investment not found'),
                ],
              ),
            );
          }

          return cashFlowsAsync.when(
            data: (cashFlows) => _buildContent(context, investment, cashFlows),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading cashflows: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading investment: $error')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    InvestmentEntity investment,
    List<dynamic> cashFlows,
  ) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyLocale = ref.watch(currencyLocaleProvider);

    // Find last income cashflow for this investment
    final lastIncome = cashFlows
        .where((cf) =>
            cf.investmentId == widget.investmentId &&
            cf.type == CashFlowType.income)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lastIncomeDate =
        lastIncome.isNotEmpty ? lastIncome.first.date : null;
    final lastIncomeDateFormatted = lastIncomeDate != null
        ? DateFormat.yMMMd(locale).format(lastIncomeDate)
        : l10n.never;

    // Calculate expected income (simplified: use expected rate)
    // TODO: Use actual investment stats to calculate expected income
    final expectedMonthlyIncome = 0.0;

    final expectedIncomeFormatted = formatCompactCurrency(
      expectedMonthlyIncome,
      symbol: currencySymbol,
      locale: currencyLocale,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpacing.md),

          // Investment Name
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              investment.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // Metrics
          ReportMetricsGrid(
            metrics: [
              ReportMetricCard(
                label: l10n.expectedMonthlyIncome,
                value: expectedIncomeFormatted,
                icon: Icons.trending_up_rounded,
                accentColor: AppColors.successLight,
              ),
              ReportMetricCard(
                label: l10n.lastIncomeReceived,
                value: lastIncomeDateFormatted,
                icon: Icons.calendar_today_rounded,
              ),
            ],
          ),

          SizedBox(height: AppSpacing.lg),

          // Action Buttons
          ReportActionButtons(
            buttons: [
              ReportActionButton(
                label: 'Record Income',
                icon: Icons.add_circle_outline,
                onPressed: () {
                  context.go(
                    '/investments/${widget.investmentId}/cashflow/add?type=INCOME',
                  );
                },
              ),
              ReportActionButton(
                label: 'View Investment',
                icon: Icons.visibility_outlined,
                isPrimary: false,
                onPressed: () {
                  context.go('/investments/${widget.investmentId}');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
