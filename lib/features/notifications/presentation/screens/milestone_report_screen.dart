/// Milestone Report Screen (Investment)
///
/// Displays congratulatory message when an investment reaches a milestone.
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

class MilestoneReportScreen extends ConsumerStatefulWidget {
  final String investmentId;
  final int milestonePercent;

  const MilestoneReportScreen({
    super.key,
    required this.investmentId,
    required this.milestonePercent,
  });

  @override
  ConsumerState<MilestoneReportScreen> createState() =>
      _MilestoneReportScreenState();
}

class _MilestoneReportScreenState
    extends ConsumerState<MilestoneReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {
          'report_type': 'milestone',
          'milestone_percent': widget.milestonePercent,
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
        icon: Icons.trending_up_rounded,
        title: l10n.milestoneAchieved,
        subtitle: '${widget.milestonePercent}% of target',
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
        error: (error, stack) =>
            Center(child: Text(l10n.errorLoadingInvestment)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, InvestmentEntity investment) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: AppSpacing.lg),

          // Congratulatory Message
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              '🎉 ${widget.milestonePercent}% Milestone Reached!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.successLight,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: AppSpacing.sm),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Your ${investment.name} has grown significantly!',
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: AppSpacing.xl),

          // Metrics
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ReportMetricCard(
              label: 'Milestone Achieved',
              value: '${widget.milestonePercent}%',
              icon: Icons.account_balance_wallet_outlined,
              accentColor: AppColors.successLight,
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          // Action Buttons
          ReportActionButtons(
            buttons: [
              ReportActionButton(
                label: 'View Investment Details',
                icon: Icons.visibility_outlined,
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
