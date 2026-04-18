/// Idle Alert Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

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
        parameters: {'report_type': 'idle_alert'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.hourglass_empty_rounded,
        title: 'Investment Idle',
        subtitle: '${widget.daysSinceActivity} days inactive',
      ),
      body: Center(child: Text('Idle Alert Report - TODO')),
    );
  }
}
