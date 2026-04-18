/// Goal Milestone Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

class GoalMilestoneReportScreen extends ConsumerStatefulWidget {
  final String goalId;
  final int milestonePercent;

  const GoalMilestoneReportScreen({
    super.key,
    required this.goalId,
    required this.milestonePercent,
  });

  @override
  ConsumerState<GoalMilestoneReportScreen> createState() =>
      _GoalMilestoneReportScreenState();
}

class _GoalMilestoneReportScreenState
    extends ConsumerState<GoalMilestoneReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'goal_milestone'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.flag_rounded,
        title: 'Goal Milestone',
        subtitle: '${widget.milestonePercent}% Complete',
      ),
      body: Center(child: Text('Goal Milestone Report - TODO')),
    );
  }
}
