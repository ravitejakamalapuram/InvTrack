/// Income Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

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
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.payments_rounded,
        title: 'Income Alert',
      ),
      body: Center(child: Text('Income Report - TODO')),
    );
  }
}
