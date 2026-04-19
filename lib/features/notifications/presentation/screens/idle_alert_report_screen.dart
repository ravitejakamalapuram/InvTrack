/// Idle Alert Report Screen
///
/// Notifies user about an investment with no recent activity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_metric_card.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class IdleAlertReportScreen extends ConsumerStatefulWidget {
  final String investmentId;
  final int daysSinceActivity;

  const IdleAlertReportScreen({
    super.key,
    required this.investmentId,
    required this.daysSinceActivity,
  });

  @override
  ConsumerState<IdleAlertReportScreen> createState() =>
      _IdleAlertReportScreenState();
}

class _IdleAlertReportScreenState
    extends ConsumerState<IdleAlertReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {
          'report_type': 'idle_alert',
          'days_since_activity': widget.daysSinceActivity,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final investmentsAsync = ref.watch(allInvestmentsProvider);

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.hourglass_empty_rounded,
        title: l10n.investmentIdle,
        subtitle: l10n.daysInactive(widget.daysSinceActivity),
      ),
      body: investmentsAsync.when(
        data: (investments) {
          final investment = investments.cast<InvestmentEntity?>().firstWhere(
            (inv) => inv?.id == widget.investmentId,
            orElse: () => null,
          );

          if (investment == null) {
            return Center(child: Text(l10n.investmentNotFound));
          }

          return _buildContent(context, investment);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.errorLoadingInvestment)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, InvestmentEntity investment) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: AppSpacing.md),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              investment.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // Metrics
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ReportMetricCard(
              label: 'Investment',
              value: investment.name,
              trend: 'No activity in ${widget.daysSinceActivity} days',
              icon: Icons.account_balance_wallet_outlined,
              accentColor: AppColors.warningLight,
            ),
          ),

          SizedBox(height: AppSpacing.md),

          // Info message
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primaryLight),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Consider adding a transaction to keep this investment active.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // Action Buttons
          ReportActionButtons(
            buttons: [
              ReportActionButton(
                label: 'Add Transaction',
                icon: Icons.add_circle_outline,
                onPressed: () {
                  context.pop();
                  context.push(
                    '/investments/${widget.investmentId}/cashflow/add',
                  );
                },
              ),
              ReportActionButton(
                label: 'View Investment',
                icon: Icons.visibility_outlined,
                isPrimary: false,
                onPressed: () {
                  context.pop();
                  context.push('/investments/${widget.investmentId}');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
