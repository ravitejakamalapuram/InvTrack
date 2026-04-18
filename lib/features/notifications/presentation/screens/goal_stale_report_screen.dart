/// Goal Stale Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

class GoalStaleReportScreen extends ConsumerStatefulWidget {
  final String goalId;
  final int daysSinceActivity;

  const GoalStaleReportScreen({
    super.key,
    required this.goalId,
    required this.daysSinceActivity,
  });

  @override
  ConsumerState<GoalStaleReportScreen> createState() =>
      _GoalStaleReportScreenState();
}

class _GoalStaleReportScreenState
    extends ConsumerState<GoalStaleReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'goal_stale'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.schedule_rounded,
        title: 'Goal Inactive',
        subtitle: '${widget.daysSinceActivity} days since activity',
      ),
      body: Center(child: Text('Goal Stale Report - TODO')),
    );
  }
}
