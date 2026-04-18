/// Risk Alert Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

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
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.shield_outlined,
        title: 'Risk Alert',
      ),
      body: Center(child: Text('Risk Alert Report - TODO')),
    );
  }
}
