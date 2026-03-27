import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/performance/performance_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
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
      projectedDate = DateTime.now().add(
        Duration(days: (monthsNeeded * 30).round()),
      );
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
    final achievedMilestones = GoalMilestone.achievedMilestones(
      progressPercent,
    );

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
    if (cashFlows.isEmpty) return 0;

    double totalIncome = 0.0;
    int minDateMs = -1;
    int maxDateMs = -1;
    bool hasIncome = false;

    // Optimization: Single pass loop replacing .where, .toList, .sort, and .fold
    for (final cf in cashFlows) {
      if (cf.type == CashFlowType.income) {
        totalIncome += cf.amount;
        final cfDateMs = cf.date.millisecondsSinceEpoch;

        if (!hasIncome) {
          minDateMs = cfDateMs;
          maxDateMs = cfDateMs;
          hasIncome = true;
        } else {
          if (cfDateMs < minDateMs) minDateMs = cfDateMs;
          if (cfDateMs > maxDateMs) maxDateMs = cfDateMs;
        }
      }
    }

    if (!hasIncome) return 0;

    // Optimization: Calculate date diff using ms integer division
    final daysDiff = (maxDateMs - minDateMs) ~/ 86400000;
    final monthsDiff = (daysDiff / 30.0).ceil();
    final months = monthsDiff < 1 ? 1 : monthsDiff;

    return totalIncome / months;
  }

  /// Calculate average monthly contribution velocity
  static double _calculateMonthlyVelocity(List<CashFlowEntity> cashFlows) {
    if (cashFlows.isEmpty) return 0;

    int minDateMs = -1;
    bool hasDate = false;
    double netPositive = 0.0;

    // Optimization: Find minimum date and calculate net positive flow in a single pass
    for (final cf in cashFlows) {
      final cfDateMs = cf.date.millisecondsSinceEpoch;
      if (!hasDate) {
        minDateMs = cfDateMs;
        hasDate = true;
      } else if (cfDateMs < minDateMs) {
        minDateMs = cfDateMs;
      }

      if (cf.type == CashFlowType.returnFlow ||
          cf.type == CashFlowType.income) {
        netPositive += cf.amount;
      }
    }

    if (!hasDate) return 0;

    // Calculate months since first cash flow
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Optimization: Calculate date diff using ms integer division
    final daysDiff = (nowMs - minDateMs) ~/ 86400000;
    final monthsDiff = (daysDiff / 30.0).ceil();
    final months = monthsDiff < 1 ? 1 : monthsDiff;

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

  /// Get the last activity date for a goal (most recent cash flow date)
  static DateTime? getLastActivityDate({
    required GoalEntity goal,
    required List<InvestmentEntity> allInvestments,
    required List<CashFlowEntity> allCashFlows,
  }) {
    final linkedInvestments = _getLinkedInvestments(goal, allInvestments);
    if (linkedInvestments.isEmpty) return null;

    final linkedIds = linkedInvestments.map((i) => i.id).toSet();
    DateTime? maxDate;

    // Optimization: Find max date in a single pass without allocating new lists or sorting
    for (final cf in allCashFlows) {
      if (linkedIds.contains(cf.investmentId)) {
        if (maxDate == null || cf.date.isAfter(maxDate)) {
          maxDate = cf.date;
        }
      }
    }

    return maxDate;
  }

  /// Calculate progress for a goal with multi-currency support
  ///
  /// Converts all cash flows to the goal's target currency (or base currency)
  /// before calculating progress. This ensures accurate progress tracking
  /// when investments are in different currencies.
  ///
  /// **Rule 21.3 Compliance:** All monetary displays MUST convert to base currency
  static Future<GoalProgress> calculateMultiCurrency({
    required GoalEntity goal,
    required List<InvestmentEntity> allInvestments,
    required List<CashFlowEntity> allCashFlows,
    required CurrencyConversionService conversionService,
    required String baseCurrency,
  }) async {
    // Filter investments based on tracking mode
    final linkedInvestments = _getLinkedInvestments(goal, allInvestments);
    final linkedIds = linkedInvestments.map((i) => i.id).toSet();

    // Filter cash flows for linked investments
    final linkedCashFlows = allCashFlows
        .where((cf) => linkedIds.contains(cf.investmentId))
        .toList();

    // Convert all cash flows to base currency
    final convertedCashFlows = <CashFlowEntity>[];
    for (final cf in linkedCashFlows) {
      final convertedAmount = await conversionService.convert(
        amount: cf.amount,
        from: cf.currency,
        to: baseCurrency,
        date: cf.date,
      );

      convertedCashFlows.add(
        cf.copyWith(amount: convertedAmount, currency: baseCurrency),
      );
    }

    // Calculate current amount based on goal type
    double currentAmount;
    double monthlyIncome = 0;

    if (goal.isIncomeGoal) {
      // For income goals, calculate average monthly income
      monthlyIncome = _calculateMonthlyIncome(convertedCashFlows);
      currentAmount = monthlyIncome;
    } else {
      // For corpus goals, calculate net value (returns + income - invested - fees)
      currentAmount = _calculateNetValue(convertedCashFlows);
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
    final monthlyVelocity = _calculateMonthlyVelocity(convertedCashFlows);

    // Project completion date
    DateTime? projectedDate;
    if (monthlyVelocity > 0 && currentAmount < targetAmount) {
      final remaining = targetAmount - currentAmount;
      final monthsNeeded = remaining / monthlyVelocity;
      projectedDate = DateTime.now().add(
        Duration(days: (monthsNeeded * 30).round()),
      );
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

    // Determine current milestone
    final currentMilestone = GoalMilestone.forPercentage(progressPercent);

    // Get achieved milestones
    final achievedMilestones = GoalMilestone.achievedMilestones(
      progressPercent,
    );

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
}

/// Provider for a single goal's progress (works for any goal including archived)
/// Uses only active (non-archived) investments for calculations.
final goalProgressProvider = Provider.family<GoalProgress?, String>((
  ref,
  goalId,
) {
  // Watch the goal directly (not from active list - works for any goal)
  final goalAsync = ref.watch(watchGoalByIdProvider(goalId));
  // Use activeInvestmentsProvider to exclude archived investments
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  // Use validCashFlowsProvider to only include cash flows from active investments
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

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
            error: (e, s) => null,
          );
        },
        loading: () => null,
        error: (e, s) => null,
      );
    },
    loading: () => null,
    error: (e, s) => null,
  );
});

/// Provider for all goals with their progress
/// Uses only active (non-archived) investments for calculations.
final allGoalsProgressProvider = Provider<AsyncValue<List<GoalProgress>>>((
  ref,
) {
  final goalsAsync = ref.watch(activeGoalsProvider);
  // Use activeInvestmentsProvider to exclude archived investments
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  // Use validCashFlowsProvider to only include cash flows from active investments
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return goalsAsync.when(
    data: (goals) {
      return investmentsAsync.when(
        data: (investments) {
          return cashFlowsAsync.when(
            data: (cashFlows) {
              // Track performance of goal progress calculation
              final progressList = ref
                  .read(performanceServiceProvider)
                  .trackSync(
                    'goal_progress_calculation',
                    () => goals.map((goal) {
                      return GoalProgressCalculator.calculate(
                        goal: goal,
                        allInvestments: investments,
                        allCashFlows: cashFlows,
                      );
                    }).toList(),
                    metrics: {
                      'goal_count': goals.length,
                      'investment_count': investments.length,
                      'cash_flow_count': cashFlows.length,
                    },
                  );
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
      final achievedGoals = progressList
          .where((p) => p.status == GoalStatus.achieved)
          .length;
      final onTrackGoals = progressList
          .where(
            (p) =>
                p.status == GoalStatus.onTrack || p.status == GoalStatus.ahead,
          )
          .length;
      final behindGoals = progressList
          .where((p) => p.status == GoalStatus.behind)
          .length;

      // Average progress across all goals
      double totalProgressSum = 0.0;
      for (final p in progressList) {
        totalProgressSum += p.progressPercent;
      }
      final avgProgress = totalProgressSum / totalGoals;

      // Get all active goals (not achieved) sorted by progress (highest first)
      final activeGoalsList = progressList
          .where((p) => p.status != GoalStatus.achieved)
          .toList();
      activeGoalsList.sort(
        (a, b) => b.progressPercent.compareTo(a.progressPercent),
      );
      final closestToCompletion = activeGoalsList.isNotEmpty
          ? activeGoalsList.first
          : null;

      // Get achieved goals sorted by updated date (most recent first), limit to 5
      final completedGoalsList = progressList
          .where((p) => p.status == GoalStatus.achieved)
          .toList();
      completedGoalsList.sort(
        (a, b) => b.goal.updatedAt.compareTo(a.goal.updatedAt),
      );
      final recentCompletedGoals = completedGoalsList.take(5).toList();

      return AsyncValue.data(
        GoalsSummary(
          totalGoals: totalGoals,
          achievedGoals: achievedGoals,
          onTrackGoals: onTrackGoals,
          behindGoals: behindGoals,
          averageProgress: avgProgress,
          closestToCompletion: closestToCompletion,
          activeGoals: activeGoalsList, // Pass all active goals for carousel
          completedGoals: recentCompletedGoals, // Pass recent completed goals
        ),
      );
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
  final List<GoalProgress> activeGoals; // Active (non-achieved) goals for carousel
  final List<GoalProgress> completedGoals; // Achieved goals for carousel (max 5)

  const GoalsSummary({
    required this.totalGoals,
    required this.achievedGoals,
    required this.onTrackGoals,
    required this.behindGoals,
    required this.averageProgress,
    this.closestToCompletion,
    this.activeGoals = const [],
    this.completedGoals = const [],
  });

  factory GoalsSummary.empty() => const GoalsSummary(
    totalGoals: 0,
    achievedGoals: 0,
    onTrackGoals: 0,
    behindGoals: 0,
    averageProgress: 0,
    activeGoals: [],
    completedGoals: [],
  );

  bool get hasGoals => totalGoals > 0;
  bool get hasActiveGoals => totalGoals > achievedGoals;

  /// All goals for carousel (active first, then completed)
  List<GoalProgress> get allCarouselGoals => [...activeGoals, ...completedGoals];
}

/// Multi-currency provider for a single goal's progress
///
/// Converts all cash flows to base currency before calculating progress.
/// This ensures accurate progress tracking when investments are in different currencies.
///
/// **Rule 21.3 Compliance:** All monetary displays MUST convert to base currency
final multiCurrencyGoalProgressProvider =
    FutureProvider.family<GoalProgress?, String>((ref, goalId) async {
      // Watch the goal directly (not from active list - works for any goal)
      final goalAsync = ref.watch(watchGoalByIdProvider(goalId));
      // Use activeInvestmentsProvider to exclude archived investments
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      // Use validCashFlowsProvider to only include cash flows from active investments
      final cashFlowsAsync = ref.watch(validCashFlowsProvider);

      final goal = await goalAsync.when(
        data: (g) async => g,
        loading: () async => null,
        error: (e, s) async => null,
      );

      if (goal == null) return null;

      final investments = await investmentsAsync.when(
        data: (i) async => i,
        loading: () async => <InvestmentEntity>[],
        error: (e, s) async => <InvestmentEntity>[],
      );

      final cashFlows = await cashFlowsAsync.when(
        data: (cf) async => cf,
        loading: () async => <CashFlowEntity>[],
        error: (e, s) async => <CashFlowEntity>[],
      );

      final conversionService = ref.watch(currencyConversionServiceProvider);
      final baseCurrency = ref.watch(currencyCodeProvider);

      return GoalProgressCalculator.calculateMultiCurrency(
        goal: goal,
        allInvestments: investments,
        allCashFlows: cashFlows,
        conversionService: conversionService,
        baseCurrency: baseCurrency,
      );
    });

/// Multi-currency provider for all goals with their progress
///
/// Converts all cash flows to base currency before calculating progress.
/// This ensures accurate progress tracking when investments are in different currencies.
///
/// **Rule 21.3 Compliance:** All monetary displays MUST convert to base currency
final multiCurrencyAllGoalsProgressProvider = FutureProvider<List<GoalProgress>>((
  ref,
) async {
  final goalsAsync = ref.watch(activeGoalsProvider);
  // Use activeInvestmentsProvider to exclude archived investments
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  // Use validCashFlowsProvider to only include cash flows from active investments
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  final goals = await goalsAsync.when(
    data: (g) async => g,
    loading: () async => <GoalEntity>[],
    error: (e, s) async => <GoalEntity>[],
  );

  final investments = await investmentsAsync.when(
    data: (i) async => i,
    loading: () async => <InvestmentEntity>[],
    error: (e, s) async => <InvestmentEntity>[],
  );

  final cashFlows = await cashFlowsAsync.when(
    data: (cf) async => cf,
    loading: () async => <CashFlowEntity>[],
    error: (e, s) async => <CashFlowEntity>[],
  );

  final conversionService = ref.watch(currencyConversionServiceProvider);
  final baseCurrency = ref.watch(currencyCodeProvider);

  // Calculate progress for each goal with currency conversion
  final progressList = <GoalProgress>[];
  for (final goal in goals) {
    final progress = await GoalProgressCalculator.calculateMultiCurrency(
      goal: goal,
      allInvestments: investments,
      allCashFlows: cashFlows,
      conversionService: conversionService,
      baseCurrency: baseCurrency,
    );
    progressList.add(progress);
  }

  return progressList;
});

/// Multi-currency provider for goals summary (for dashboard card)
///
/// Uses multi-currency goal progress calculations to ensure accurate
/// summary statistics when investments are in different currencies.
///
/// **Rule 21.3 Compliance:** All monetary displays MUST convert to base currency
final multiCurrencyGoalsSummaryProvider = FutureProvider<GoalsSummary>((
  ref,
) async {
  final progressList = await ref.watch(
    multiCurrencyAllGoalsProgressProvider.future,
  );

  if (progressList.isEmpty) {
    return GoalsSummary(
      totalGoals: 0,
      achievedGoals: 0,
      onTrackGoals: 0,
      behindGoals: 0,
      averageProgress: 0,
      closestToCompletion: null,
      activeGoals: [],
      completedGoals: [],
    );
  }

  // Calculate summary statistics
  final totalGoals = progressList.length;
  final achievedGoals = progressList
      .where((p) => p.status == GoalStatus.achieved)
      .length;
  final onTrackGoals = progressList
      .where((p) => p.status == GoalStatus.onTrack)
      .length;
  final behindGoals = progressList
      .where((p) => p.status == GoalStatus.behind)
      .length;

  // Calculate average progress
  double totalProgress = 0.0;
  for (final p in progressList) {
    totalProgress += p.progressPercent;
  }
  final avgProgress = totalProgress / totalGoals;

  // Get all active goals (not achieved) sorted by progress (highest first)
  final activeGoalsList = progressList
      .where((p) => p.status != GoalStatus.achieved)
      .toList();
  activeGoalsList.sort(
    (a, b) => b.progressPercent.compareTo(a.progressPercent),
  );
  final closestToCompletion = activeGoalsList.isNotEmpty
      ? activeGoalsList.first
      : null;

  // Get achieved goals sorted by updated date (most recent first), limit to 5
  final completedGoalsList = progressList
      .where((p) => p.status == GoalStatus.achieved)
      .toList();
  completedGoalsList.sort(
    (a, b) => b.goal.updatedAt.compareTo(a.goal.updatedAt),
  );
  final recentCompletedGoals = completedGoalsList.take(5).toList();

  return GoalsSummary(
    totalGoals: totalGoals,
    achievedGoals: achievedGoals,
    onTrackGoals: onTrackGoals,
    behindGoals: behindGoals,
    averageProgress: avgProgress,
    closestToCompletion: closestToCompletion,
    activeGoals: activeGoalsList, // Pass all active goals for carousel
    completedGoals: recentCompletedGoals, // Pass recent completed goals
  );
});
