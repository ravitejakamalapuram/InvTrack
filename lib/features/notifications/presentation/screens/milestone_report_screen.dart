/// Milestone Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

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
        parameters: {'report_type': 'milestone'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.trending_up_rounded,
        title: 'Milestone Achieved',
        subtitle: '${widget.milestonePercent}% of target',
      ),
      body: Center(child: Text('Milestone Report - TODO')),
    );
  }
}
