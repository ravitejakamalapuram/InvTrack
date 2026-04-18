/// Monthly Summary Report Screen
///
/// Displays investment activity for the past month.
/// Shown when user taps the "Monthly Summary" notification.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
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

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.calendar_month_rounded,
        title: 'Monthly Summary',
        subtitle: 'March 2026',
      ),
      body: Center(
        child: Text('Monthly Summary Report - TODO'),
      ),
    );
  }
}
