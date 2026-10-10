import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/goal_progress_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';

export 'package:inv_tracker/core/calculations/goal_progress_calculator.dart';

/// What goal progress is worked out from, all in [baseCurrency]: the active
/// investments, their converted cash flows (A13) and the converted current
/// values of the open ones (A10). Archived investments are left out (money
/// rule 9).
class GoalPortfolioInputs {
  final List<InvestmentEntity> investments;
  final List<CashFlowEntity> cashFlows;
  final Map<String, TerminalValues> terminalValues;
  final String baseCurrency;
  final DateTime asOf;

  const GoalPortfolioInputs({
    required this.investments,
    required this.cashFlows,
    required this.terminalValues,
    required this.baseCurrency,
    required this.asOf,
  });
}

/// The goal inputs, from the converted snapshot every stats screen reads.
final goalPortfolioInputsProvider = FutureProvider<GoalPortfolioInputs>((
  ref,
) async {
  final baseCurrency = ref.watch(currencyCodeProvider);
  final asOf = ref.watch(valuationDateProvider);
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  final snapshotAsync = ref.watch(convertedCashFlowsSnapshotProvider);
  final convertedAsync = ref.watch(convertedTerminalValuesProvider);

  // Stay loading, or fail, with the sources: an empty portfolio here would
  // show '0%' and 'Not Started' for goals that have progress. The snapshot
  // is checked itself so that its load error shows even while Riverpod
  // retries it.
  final investments = await dataOf(investmentsAsync);
  await dataOf(snapshotAsync);
  final converted = await dataOf(convertedAsync);
  // Amounts are never used under a currency they were not converted to.
  if (converted.snapshot.baseCurrency != baseCurrency) {
    return Completer<GoalPortfolioInputs>().future;
  }

  return GoalPortfolioInputs(
    investments: investments,
    cashFlows: converted.snapshot.cashFlows,
    terminalValues: converted.byInvestment,
    baseCurrency: baseCurrency,
    asOf: asOf,
  );
}, retry: _noRetry);

/// Progress of [goal] from [inputs], with its target converted to the base
/// currency at today's rate. Without a rate it fails rather than read the
/// goal's currency as the base currency.
Future<GoalProgress> _progressOf(
  GoalEntity goal,
  GoalPortfolioInputs inputs,
  List<GoalEntity> activeGoals,
  CurrencyConverterModule Function() currency,
) async {
  var target = GoalProgressCalculator.targetInGoalCurrency(goal);
  if (goal.currency != inputs.baseCurrency) {
    target *= await currency().rateToday(
      from: goal.currency,
      to: inputs.baseCurrency,
    );
  }
  return GoalProgressCalculator.calculate(
    goal: goal,
    investments: inputs.investments,
    cashFlows: inputs.cashFlows,
    terminalValues: inputs.terminalValues,
    targetAmount: target,
    asOf: inputs.asOf,
    otherGoalsCount: GoalProgressCalculator.otherGoalsSharing(
      goal,
      activeGoals,
      inputs.investments,
    ),
  );
}

/// The currency module, read only when a goal's target is in another
/// currency: like the snapshot, the converter is needed only then.
CurrencyConverterModule Function() _currencyOf(Ref ref) =>
    () => ref.watch(calculationEngineProvider).currency;

/// Retry policy for the goal progress providers below: never retry them.
///
/// They only compute from their sources, which Riverpod retries on its own
/// and which rebuild them when they change. Retrying them as well would keep
/// a load error in an `AsyncLoading` that `.when` shows as loading, so goal
/// screens would spin indefinitely instead of showing the error.
Duration? _noRetry(int retryCount, Object error) => null;

/// Progress of one goal (archived goals too), in the base currency.
final multiCurrencyGoalProgressProvider =
    FutureProvider.family<GoalProgress?, String>((ref, goalId) async {
      // Watch the goal directly (not from active list - works for any goal)
      final goalAsync = ref.watch(watchGoalByIdProvider(goalId));
      final inputsAsync = ref.watch(goalPortfolioInputsProvider);
      // Only for the "also counted in N other goals" chip.
      final activeGoals = ref.watch(activeGoalsProvider).value ?? const [];

      // Stay loading, or fail, with the sources: substituting empty data
      // would show '0%' and 'Not Started' for goals that have progress.
      final goal = await dataOf(goalAsync);
      if (goal == null) return null;
      final inputs = await dataOf(inputsAsync);

      return _progressOf(goal, inputs, activeGoals, _currencyOf(ref));
    }, retry: _noRetry);

/// Progress of every active goal, in the base currency.
///
/// A goal whose target has no exchange rate is left out rather than fail
/// the list, so the other goals and the health score still show. Its own
/// progress ([multiCurrencyGoalProgressProvider]) fails, and its card says
/// so.
final multiCurrencyAllGoalsProgressProvider =
    FutureProvider<List<GoalProgress>>((ref) async {
      final goalsAsync = ref.watch(activeGoalsProvider);
      final inputsAsync = ref.watch(goalPortfolioInputsProvider);

      // Stay loading, or fail, with the sources: substituting empty lists
      // would show 'Set your first goal' or '0%' to users who have goals.
      final goals = await dataOf(goalsAsync);
      final inputs = await dataOf(inputsAsync);

      final progress = await Future.wait([
        for (final goal in goals)
          _progressOf(goal, inputs, goals, _currencyOf(ref))
              .then<GoalProgress?>((p) => p)
              .catchError(
                (Object _) => null,
                test: (e) => e is CurrencyConversionException,
              ),
      ]);
      return [for (final p in progress) ?p];
    }, retry: _noRetry);

/// What archiving an investment does to one goal: its progress with the
/// investment and without it.
class GoalArchiveImpact {
  final GoalEntity goal;
  final GoalProgress before;
  final GoalProgress after;

  const GoalArchiveImpact({
    required this.goal,
    required this.before,
    required this.after,
  });
}

/// The active goals whose progress changes when [investmentId] is archived
/// (money rule 9: archived investments are not counted), so that the archive
/// dialog can say so before the user confirms.
///
/// Both sides come from [GoalProgressCalculator], with and without the
/// investment, so they match the goal screens. A goal the investment does
/// not feed, for example because it is closed, is not listed. A goal whose
/// target has no exchange rate is left out, like in
/// [multiCurrencyAllGoalsProgressProvider].
final archiveGoalImpactProvider =
    FutureProvider.family<List<GoalArchiveImpact>, String>((
      ref,
      investmentId,
    ) async {
      final goalsAsync = ref.watch(activeGoalsProvider);
      final inputsAsync = ref.watch(goalPortfolioInputsProvider);

      final goals = await dataOf(goalsAsync);
      final inputs = await dataOf(inputsAsync);
      if (!inputs.investments.any((inv) => inv.id == investmentId)) {
        return const [];
      }
      final without = GoalPortfolioInputs(
        investments: [
          for (final inv in inputs.investments)
            if (inv.id != investmentId) inv,
        ],
        cashFlows: inputs.cashFlows,
        terminalValues: inputs.terminalValues,
        baseCurrency: inputs.baseCurrency,
        asOf: inputs.asOf,
      );

      final impacts = await Future.wait([
        for (final goal in goals)
          Future.wait([
                _progressOf(goal, inputs, goals, _currencyOf(ref)),
                _progressOf(goal, without, goals, _currencyOf(ref)),
              ])
              .then<GoalArchiveImpact?>(
                // To the paisa: floating-point noise is not a change.
                (both) =>
                    (both[0].currentAmount - both[1].currentAmount).abs() <
                        0.005
                    ? null
                    : GoalArchiveImpact(
                        goal: goal,
                        before: both[0],
                        after: both[1],
                      ),
              )
              .catchError(
                (Object _) => null,
                test: (e) => e is CurrencyConversionException,
              ),
      ]);
      return [for (final impact in impacts) ?impact];
    }, retry: _noRetry);

/// An investment a goal tracks, as listed on the goal details screen.
class LinkedGoalInvestment {
  final InvestmentEntity investment;
  final bool isArchived;

  /// Whether the goal counts it: open and not archived.
  final bool isCounted;

  const LinkedGoalInvestment({
    required this.investment,
    required this.isArchived,
    required this.isCounted,
  });
}

/// The investments a goal tracks, archived ones included so that the goal
/// details screen can say they are not counted (money rule 9).
final goalLinkedInvestmentsProvider =
    FutureProvider.family<List<LinkedGoalInvestment>, String>((
      ref,
      goalId,
    ) async {
      final goalAsync = ref.watch(watchGoalByIdProvider(goalId));
      final activeAsync = ref.watch(activeInvestmentsProvider);
      final archivedAsync = ref.watch(archivedInvestmentsProvider);

      final goal = await dataOf(goalAsync);
      if (goal == null) return const [];
      final active = await dataOf(activeAsync);
      final archived = await dataOf(archivedAsync);

      return [
        for (final inv in GoalProgressCalculator.linkedInvestments(
          goal,
          active,
        ))
          LinkedGoalInvestment(
            investment: inv,
            isArchived: inv.isArchived,
            isCounted: inv.isOpen && !inv.isArchived,
          ),
        for (final inv in GoalProgressCalculator.linkedInvestments(
          goal,
          archived,
        ))
          LinkedGoalInvestment(
            investment: inv,
            isArchived: true,
            isCounted: false,
          ),
      ];
    }, retry: _noRetry);

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
  int achievedGoals = 0;
  int onTrackGoals = 0;
  int behindGoals = 0;
  double totalProgress = 0.0;
  final activeGoalsList = <GoalProgress>[];
  final completedGoalsList = <GoalProgress>[];

  // Optimization: Single pass loop for all metrics replacing multiple sequential .where().toList() calls
  for (final p in progressList) {
    totalProgress += p.progressPercent;

    if (p.status == GoalStatus.achieved) {
      achievedGoals++;
      completedGoalsList.add(p);
    } else {
      activeGoalsList.add(p);
      if (p.status == GoalStatus.onTrack || p.status == GoalStatus.ahead) {
        onTrackGoals++;
      } else if (p.status == GoalStatus.behind) {
        behindGoals++;
      }
    }
  }

  final avgProgress = totalProgress / totalGoals;

  // Sort active goals by progress (highest first)
  activeGoalsList.sort(
    (a, b) => b.progressPercent.compareTo(a.progressPercent),
  );
  final closestToCompletion = activeGoalsList.isNotEmpty
      ? activeGoalsList.first
      : null;

  // Sort achieved goals by updated date (most recent first), limit to 5
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
}, retry: _noRetry);

/// Summary of all goals for dashboard display
class GoalsSummary {
  final int totalGoals;
  final int achievedGoals;
  final int onTrackGoals;
  final int behindGoals;
  final double averageProgress;
  final GoalProgress? closestToCompletion;
  final List<GoalProgress>
  activeGoals; // Active (non-achieved) goals for carousel
  final List<GoalProgress>
  completedGoals; // Achieved goals for carousel (max 5)

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
  List<GoalProgress> get allCarouselGoals => [
    ...activeGoals,
    ...completedGoals,
  ];
}
