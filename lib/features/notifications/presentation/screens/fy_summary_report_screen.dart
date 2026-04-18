/// FY Summary Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

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
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.calendar_view_year_rounded,
        title: 'FY Summary',
        subtitle: 'Financial Year 2025-26',
      ),
      body: Center(child: Text('FY Summary Report - TODO')),
    );
  }
}
