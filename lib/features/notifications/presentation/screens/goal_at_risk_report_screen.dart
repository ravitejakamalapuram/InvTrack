/// Goal At-Risk Report Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';

class GoalAtRiskReportScreen extends ConsumerStatefulWidget {
  final String goalId;

  const GoalAtRiskReportScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalAtRiskReportScreen> createState() =>
      _GoalAtRiskReportScreenState();
}

class _GoalAtRiskReportScreenState
    extends ConsumerState<GoalAtRiskReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'goal_at_risk'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.warning_rounded,
        title: 'Goal At Risk',
      ),
      body: Center(child: Text('Goal At-Risk Report - TODO')),
    );
  }
}
