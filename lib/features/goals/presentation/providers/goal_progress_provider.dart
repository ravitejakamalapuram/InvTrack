import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

/// Calculate progress for a single goal
class GoalProgressCalculator {
  /// Calculate progress for a goal based on investments and cash flows
  static GoalProgress calculate({
    required GoalEntity goal,
    required List<InvestmentEntity> allInvestments,
    required List<CashFlowEntity> allCashFlows,
  }) {
    // Filter investments based on tracking mode
    final linkedInvestments = _getLinkedInvestments(goal, allInvestments);
    final linkedIds = linkedInvestments.map((i) => i.id).toSet();

    // Filter cash flows for linked investments
    final linkedCashFlows = allCashFlows
        .where((cf) => linkedIds.contains(cf.investmentId))
        .toList();

    // Calculate current amount based on goal type
    double currentAmount;
    double monthlyIncome = 0;

    if (goal.isIncomeGoal) {
      // For income goals, calculate average monthly income
      monthlyIncome = _calculateMonthlyIncome(linkedCashFlows);
      currentAmount = monthlyIncome;
    } else {
      // For corpus goals, calculate net value (returns + income - invested - fees)
      currentAmount = _calculateNetValue(linkedCashFlows);
    }

    // Calculate target
    final targetAmount = goal.isIncomeGoal 
        ? (goal.targetMonthlyIncome ?? goal.targetAmount)
        : goal.targetAmount;

    // Calculate progress percentage
    final progressPercent = targetAmount > 0
        ? (currentAmount / targetAmount * 100).clamp(0.0, 100.0)
        : 0.0;

    // Calculate monthly velocity (average monthly contribution)
    final monthlyVelocity = _calculateMonthlyVelocity(linkedCashFlows);

    // Project completion date
    DateTime? projectedDate;
    if (monthlyVelocity > 0 && currentAmount < targetAmount) {
      final remaining = targetAmount - currentAmount;
      final monthsNeeded = remaining / monthlyVelocity;
      projectedDate = DateTime.now().add(Duration(days: (monthsNeeded * 30).round()));
    } else if (currentAmount >= targetAmount) {
      projectedDate = DateTime.now(); // Already achieved
    }

    // Determine status
    final status = _determineStatus(
      goal: goal,
      currentAmount: currentAmount,
      targetAmount: targetAmount,
      projectedDate: projectedDate,
    );

    // Get milestones
    final currentMilestone = GoalMilestone.forPercentage(progressPercent);
    final achievedMilestones = GoalMilestone.achievedMilestones(progressPercent);

    return GoalProgress(
      goal: goal,
      currentAmount: currentAmount,
      progressPercent: progressPercent,
      monthlyVelocity: monthlyVelocity,
      monthlyIncome: monthlyIncome,
      projectedCompletionDate: projectedDate,
      status: status,
      currentMilestone: currentMilestone,
      achievedMilestones: achievedMilestones,
      linkedInvestmentCount: linkedInvestments.length,
      calculatedAt: DateTime.now(),
    );
  }

  /// Get investments linked to this goal based on tracking mode
  static List<InvestmentEntity> _getLinkedInvestments(
    GoalEntity goal,
    List<InvestmentEntity> allInvestments,
  ) {
    switch (goal.trackingMode) {
      case GoalTrackingMode.all:
        return allInvestments;
      case GoalTrackingMode.byType:
        return allInvestments
            .where((i) => goal.linkedTypes.contains(i.type))
            .toList();
      case GoalTrackingMode.selected:
        return allInvestments
            .where((i) => goal.linkedInvestmentIds.contains(i.id))
            .toList();
    }
  }

  /// Calculate net value from cash flows (for corpus goals)
  static double _calculateNetValue(List<CashFlowEntity> cashFlows) {
    double totalReturned = 0;

    for (final cf in cashFlows) {
      if (cf.type != CashFlowType.invest && cf.type != CashFlowType.fee) {
        totalReturned += cf.amount;
      }
    }

    // For goal tracking, we track returns + income as progress
    // This represents "money back" toward the goal
    return totalReturned;
  }

  /// Calculate average monthly income (for income goals)
  static double _calculateMonthlyIncome(List<CashFlowEntity> cashFlows) {
    final incomeCashFlows = cashFlows
        .where((cf) => cf.type == CashFlowType.income)
        .toList();

    if (incomeCashFlows.isEmpty) return 0;

    // Get the date range
    incomeCashFlows.sort((a, b) => a.date.compareTo(b.date));
    final firstDate = incomeCashFlows.first.date;
    final lastDate = incomeCashFlows.last.date;

    // Calculate months between first and last income
    final monthsDiff = (lastDate.difference(firstDate).inDays / 30.0).ceil();
    final months = monthsDiff < 1 ? 1 : monthsDiff;

    // Total income
    final totalIncome = incomeCashFlows.fold(0.0, (sum, cf) => sum + cf.amount);

    return totalIncome / months;
  }

  /// Calculate average monthly contribution velocity
  static double _calculateMonthlyVelocity(List<CashFlowEntity> cashFlows) {
    if (cashFlows.isEmpty) return 0;

    // Sort by date
    final sorted = List<CashFlowEntity>.from(cashFlows)
      ..sort((a, b) => a.date.compareTo(b.date));

    final firstDate = sorted.first.date;
    final now = DateTime.now();

    // Calculate months since first cash flow
    final monthsDiff = (now.difference(firstDate).inDays / 30.0).ceil();
    final months = monthsDiff < 1 ? 1 : monthsDiff;

    // Calculate net positive flow (returns + income)
    double netPositive = 0;
    for (final cf in cashFlows) {
      if (cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income) {
        netPositive += cf.amount;
      }
    }

    return netPositive / months;
  }

  /// Determine goal status based on progress
  static GoalStatus _determineStatus({
    required GoalEntity goal,
    required double currentAmount,
    required double targetAmount,
    required DateTime? projectedDate,
  }) {
    if (goal.isArchived) return GoalStatus.archived;
    if (currentAmount >= targetAmount) return GoalStatus.achieved;
    if (currentAmount <= 0) return GoalStatus.notStarted;

    // If there's a deadline, check if on track
    if (goal.targetDate != null && projectedDate != null) {
      final daysAhead = goal.targetDate!.difference(projectedDate).inDays;
      if (daysAhead > 30) return GoalStatus.ahead;
      if (daysAhead < -30) return GoalStatus.behind;
    }

    return GoalStatus.onTrack;
  }
}

/// Provider for a single goal's progress (works for any goal including archived)
final goalProgressProvider = Provider.family<GoalProgress?, String>((ref, goalId) {
  // Watch the goal directly (not from active list - works for any goal)
  final goalAsync = ref.watch(watchGoalByIdProvider(goalId));
  final investmentsAsync = ref.watch(allInvestmentsProvider);
  final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

  return goalAsync.when(
    data: (goal) {
      if (goal == null) return null;

      return investmentsAsync.when(
        data: (investments) {
          return cashFlowsAsync.when(
            data: (cashFlows) {
              return GoalProgressCalculator.calculate(
                goal: goal,
                allInvestments: investments,
                allCashFlows: cashFlows,
              );
            },
            loading: () => null,
            error: (_, __) => null,
          );
        },
        loading: () => null,
        error: (_, __) => null,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for all goals with their progress
final allGoalsProgressProvider = Provider<AsyncValue<List<GoalProgress>>>((ref) {
  final goalsAsync = ref.watch(activeGoalsProvider);
  final investmentsAsync = ref.watch(allInvestmentsProvider);
  final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

  return goalsAsync.when(
    data: (goals) {
      return investmentsAsync.when(
        data: (investments) {
          return cashFlowsAsync.when(
            data: (cashFlows) {
              final progressList = goals.map((goal) {
                return GoalProgressCalculator.calculate(
                  goal: goal,
                  allInvestments: investments,
                  allCashFlows: cashFlows,
                );
              }).toList();
              return AsyncValue.data(progressList);
            },
            loading: () => const AsyncValue.loading(),
            error: (e, st) => AsyncValue.error(e, st),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider for goals summary (for dashboard card)
final goalsSummaryProvider = Provider<AsyncValue<GoalsSummary>>((ref) {
  final progressAsync = ref.watch(allGoalsProgressProvider);

  return progressAsync.when(
    data: (progressList) {
      if (progressList.isEmpty) {
        return AsyncValue.data(GoalsSummary.empty());
      }

      final totalGoals = progressList.length;
      final achievedGoals = progressList.where((p) => p.status == GoalStatus.achieved).length;
      final onTrackGoals = progressList.where((p) => p.status == GoalStatus.onTrack || p.status == GoalStatus.ahead).length;
      final behindGoals = progressList.where((p) => p.status == GoalStatus.behind).length;

      // Average progress across all goals
      final avgProgress = progressList.fold(0.0, (sum, p) => sum + p.progressPercent) / totalGoals;

      // Find the goal closest to completion (but not achieved)
      final activeGoals = progressList.where((p) => p.status != GoalStatus.achieved).toList();
      activeGoals.sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
      final closestToCompletion = activeGoals.isNotEmpty ? activeGoals.first : null;

      return AsyncValue.data(GoalsSummary(
        totalGoals: totalGoals,
        achievedGoals: achievedGoals,
        onTrackGoals: onTrackGoals,
        behindGoals: behindGoals,
        averageProgress: avgProgress,
        closestToCompletion: closestToCompletion,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Summary of all goals for dashboard display
class GoalsSummary {
  final int totalGoals;
  final int achievedGoals;
  final int onTrackGoals;
  final int behindGoals;
  final double averageProgress;
  final GoalProgress? closestToCompletion;

  const GoalsSummary({
    required this.totalGoals,
    required this.achievedGoals,
    required this.onTrackGoals,
    required this.behindGoals,
    required this.averageProgress,
    this.closestToCompletion,
  });

  factory GoalsSummary.empty() => const GoalsSummary(
    totalGoals: 0,
    achievedGoals: 0,
    onTrackGoals: 0,
    behindGoals: 0,
    averageProgress: 0,
  );

  bool get hasGoals => totalGoals > 0;
  bool get hasActiveGoals => totalGoals > achievedGoals;
}
