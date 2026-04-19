/// Risk Alert Report Screen
///
/// Displays portfolio risk analysis and recommendations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class RiskAlertReportScreen extends ConsumerStatefulWidget {
  const RiskAlertReportScreen({super.key});

  @override
  ConsumerState<RiskAlertReportScreen> createState() =>
      _RiskAlertReportScreenState();
}

class _RiskAlertReportScreenState
    extends ConsumerState<RiskAlertReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'risk_alert'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.shield_outlined,
        title: l10n.riskAlert,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: AppSpacing.lg),

            Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: AppColors.warningLight,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.portfolioRiskAlert,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your portfolio may have concentration risk in certain asset types.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommendations:',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text('• Diversify across multiple asset types'),
                        Text('• Review investment risk levels'),
                        Text('• Consider rebalancing portfolio'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.lg),

            ReportActionButtons(
              buttons: [
                ReportActionButton(
                  label: l10n.viewPortfolioHealth,
                  icon: Icons.health_and_safety_outlined,
                  onPressed: () {
                    context.go('/portfolio-health');
                  },
                ),
                ReportActionButton(
                  label: l10n.viewInvestments,
                  icon: Icons.list_rounded,
                  isPrimary: false,
                  onPressed: () {
                    context.go('/investments');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
