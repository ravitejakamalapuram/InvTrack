/// Action Required Provider
///
/// Provides action required report data
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/reports/data/services/action_required_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/action_required_report.dart';

/// Provider for action required report
final actionRequiredReportProvider =
    FutureProvider.autoDispose<ActionRequiredReport>((ref) async {
  // Get investments and cash flows
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);
  final goalsAsync = ref.watch(activeGoalsProvider);

  // Wait for all data
  final investments = await investmentsAsync.when(
    data: (data) async => data,
    loading: () async => <InvestmentEntity>[],
    error: (e, st) async => <InvestmentEntity>[],
  );

  final cashFlows = await cashFlowsAsync.when(
    data: (data) async => data,
    loading: () async => <CashFlowEntity>[],
    error: (e, st) async => <CashFlowEntity>[],
  );

  final goals = await goalsAsync.when(
    data: (data) async => data,
    loading: () async => <GoalEntity>[],
    error: (e, st) async => <GoalEntity>[],
  );

  // Generate report
  final service = ref.read(actionRequiredServiceProvider);
  return service.generateReport(
    investments: investments,
    cashFlows: cashFlows,
    goals: goals,
  );
});
