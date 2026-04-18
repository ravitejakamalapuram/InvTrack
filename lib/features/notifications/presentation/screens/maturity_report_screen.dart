/// Maturity Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

class MaturityReportScreen extends ConsumerStatefulWidget {
  final String investmentId;
  final int daysToMaturity;

  const MaturityReportScreen({
    super.key,
    required this.investmentId,
    required this.daysToMaturity,
  });

  @override
  ConsumerState<MaturityReportScreen> createState() =>
      _MaturityReportScreenState();
}

class _MaturityReportScreenState extends ConsumerState<MaturityReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'maturity'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.event_available_rounded,
        title: 'Maturity Reminder',
        subtitle: '${widget.daysToMaturity} days remaining',
      ),
      body: Center(
        child: Text('Maturity Report - TODO'),
      ),
    );
  }
}
