import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/planning_inputs_calculator.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Goal progress: the single implementation every goal screen, alert and
/// report reads (money rule 3).
///
/// A corpus goal has reached the current value of its open investments (A10:
/// the user's value, else an estimate, else the principal still invested),
/// not the payouts they made. An income goal earns the INCOME of its open
/// investments over the last 12 months, per month held. Progress towards a
/// date compounds at [assumedAnnualReturn] with the net new money of the
/// last 12 months. Archived investments are never counted (money rule 9).
class GoalProgressCalculator {
  GoalProgressCalculator._();

  /// Annual return (%) that goal projections and "required per month"
  /// assume. The goal details screen states it.
  static const assumedAnnualReturn = 8.0;

  /// A projected date within this many days of the goal's date is on track.
  static const onTrackWindowDays = 30;

  /// The investments [goal] tracks among [investments], by its tracking
  /// mode, in the order given. Archived and closed ones are included; the
  /// calculation leaves them out.
  static List<InvestmentEntity> linkedInvestments(
    GoalEntity goal,
    Iterable<InvestmentEntity> investments,
  ) {
    switch (goal.trackingMode) {
      case GoalTrackingMode.all:
        return investments.toList();
      case GoalTrackingMode.byType:
        return [
          for (final inv in investments)
            if (goal.linkedTypes.contains(inv.type)) inv,
        ];
      case GoalTrackingMode.selected:
        return [
          for (final inv in investments)
            if (goal.linkedInvestmentIds.contains(inv.id)) inv,
        ];
    }
  }

  /// How many other active goals in [goals] count at least one investment
  /// that [goal] counts (open and not archived), so that the screen can say
  /// the same money is counted more than once.
  static int otherGoalsSharing(
    GoalEntity goal,
    Iterable<GoalEntity> goals,
    Iterable<InvestmentEntity> investments,
  ) {
    Set<String> counted(GoalEntity g) => {
      for (final inv in linkedInvestments(g, investments))
        if (inv.isOpen && !inv.isArchived) inv.id,
    };
    final mine = counted(goal);
    if (mine.isEmpty) return 0;
    var count = 0;
    for (final other in goals) {
      if (other.id == goal.id || other.isArchived) continue;
      if (counted(other).any(mine.contains)) count++;
    }
    return count;
  }

  /// The goal's target in its own currency: the monthly income target for
  /// an income goal, otherwise the target amount.
  static double targetInGoalCurrency(GoalEntity goal) => goal.isIncomeGoal
      ? (goal.targetMonthlyIncome ?? goal.targetAmount)
      : goal.targetAmount;

  /// Progress of [goal] as of [asOf].
  ///
  /// [cashFlows] and [terminalValues] must already be in the base currency
  /// (money rule 2), and [targetAmount] is [targetInGoalCurrency] converted
  /// to it. [investments] are the active (non-archived) investments.
  static GoalProgress calculate({
    required GoalEntity goal,
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required Map<String, TerminalValues> terminalValues,
    required double targetAmount,
    required DateTime asOf,
    int otherGoalsCount = 0,
  }) {
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final linked = [
      for (final inv in linkedInvestments(goal, investments))
        if (!inv.isArchived) inv,
    ];
    final ids = {for (final inv in linked) inv.id};
    final flows = [
      for (final cf in cashFlows)
        if (ids.contains(cf.investmentId)) cf,
    ];

    var monthlyIncome = 0.0;
    var monthlySavings = 0.0;
    final double current;
    if (goal.isIncomeGoal) {
      monthlyIncome = PlanningInputsCalculator.monthlyIncome(
        investments: linked,
        cashFlows: flows,
        asOf: today,
      );
      current = monthlyIncome;
    } else {
      current = PlanningInputsCalculator.corpus(
        investments: linked,
        cashFlows: flows,
        terminalValues: terminalValues,
      ).total;
      monthlySavings =
          PlanningInputsCalculator.monthlySavings(
            cashFlows: flows,
            asOf: today,
          ).amount ??
          0.0;
    }

    final progressPercent = targetAmount > 0
        ? (current / targetAmount * 100).clamp(0.0, 100.0)
        : 0.0;
    final reached = targetAmount > 0 && current >= targetAmount;
    final deadline = goal.targetDate == null
        ? null
        : DateTime(
            goal.targetDate!.year,
            goal.targetDate!.month,
            goal.targetDate!.day,
          );

    DateTime? projected;
    double? requiredMonthly;
    if (reached) {
      projected = today;
    } else if (!goal.isIncomeGoal && targetAmount > 0) {
      final months = PlanningInputsCalculator.monthsToReach(
        target: targetAmount,
        current: current,
        monthlySavings: monthlySavings,
        annualRatePercent: assumedAnnualReturn,
      );
      if (months != null) {
        projected = PlanningInputsCalculator.addMonths(today, months);
      }
      if (deadline != null && deadline.isAfter(today)) {
        final monthsLeft = PlanningInputsCalculator.wholeMonthsBetween(
          today,
          deadline,
        );
        requiredMonthly = PlanningInputsCalculator.requiredMonthlyContribution(
          target: targetAmount,
          current: current,
          months: monthsLeft < 1 ? 1 : monthsLeft,
          annualRatePercent: assumedAnnualReturn,
        );
      }
    }

    return GoalProgress(
      goal: goal,
      currentAmount: current,
      targetAmount: targetAmount,
      progressPercent: progressPercent,
      monthlyVelocity: monthlySavings,
      monthlyIncome: monthlyIncome,
      requiredMonthly: requiredMonthly,
      otherGoalsCount: otherGoalsCount,
      projectedCompletionDate: projected,
      status: _status(
        goal: goal,
        reached: reached,
        current: current,
        today: today,
        deadline: deadline,
        projected: projected,
      ),
      currentMilestone: GoalMilestone.forPercentage(progressPercent),
      achievedMilestones: GoalMilestone.achievedMilestones(progressPercent),
      linkedInvestmentCount: linked.length,
      calculatedAt: DateTime.now(),
    );
  }

  static GoalStatus _status({
    required GoalEntity goal,
    required bool reached,
    required double current,
    required DateTime today,
    required DateTime? deadline,
    required DateTime? projected,
  }) {
    if (goal.isArchived) return GoalStatus.archived;
    if (reached) return GoalStatus.achieved;
    if (current <= 0) return GoalStatus.notStarted;
    if (deadline == null) return GoalStatus.onTrack;
    if (!deadline.isAfter(today)) return GoalStatus.behind;
    // Income is not projected: an income goal is on track until its date.
    if (goal.isIncomeGoal) return GoalStatus.onTrack;
    if (projected == null) return GoalStatus.behind;
    final daysAhead = deadline.difference(projected).inDays;
    if (daysAhead > onTrackWindowDays) return GoalStatus.ahead;
    if (daysAhead < -onTrackWindowDays) return GoalStatus.behind;
    return GoalStatus.onTrack;
  }

  /// The goal's target converted to [baseCurrency] at today's rate, else
  /// the last known one when [fallbackStrategy] allows it. It never falls
  /// back to the unconverted amount: without a rate it throws a
  /// [CurrencyConversionException].
  static Future<double> targetInBaseCurrency({
    required GoalEntity goal,
    required BatchCurrencyConverter batchConverter,
    required String baseCurrency,
    ConversionFallbackStrategy fallbackStrategy =
        ConversionFallbackStrategy.useLastKnown,
  }) async {
    final amount = targetInGoalCurrency(goal);
    if (goal.currency == baseCurrency) return amount;
    try {
      return await batchConverter.convert(
        amount: amount,
        from: goal.currency,
        to: baseCurrency,
        fallbackStrategy: ConversionFallbackStrategy.throwError,
      );
    } on CurrencyConversionException {
      if (fallbackStrategy != ConversionFallbackStrategy.useLastKnown) {
        rethrow;
      }
      final rate = await batchConverter.getLastKnownRate(
        from: goal.currency,
        to: baseCurrency,
      );
      if (rate == null) rethrow;
      return amount * rate;
    }
  }

  /// Progress of [goal] from unconverted [allCashFlows]: converts the linked
  /// cash flows, their current values and the target to [baseCurrency],
  /// then [calculate]s. Used where the converted snapshot is not at hand,
  /// such as the alerts checked right after a cash flow is saved.
  ///
  /// Archived investments are left out. Throws a
  /// [CurrencyConversionException] rather than count an amount that could
  /// not be converted.
  static Future<GoalProgress> calculateMultiCurrency({
    required GoalEntity goal,
    required List<InvestmentEntity> allInvestments,
    required List<CashFlowEntity> allCashFlows,
    required BatchCurrencyConverter batchConverter,
    required String baseCurrency,
    ConversionFallbackStrategy fallbackStrategy =
        ConversionFallbackStrategy.useLastKnown,
    DateTime? asOf,
  }) async {
    final now = asOf ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final investments = [
      for (final inv in linkedInvestments(goal, allInvestments))
        if (!inv.isArchived) inv,
    ];
    final ids = {for (final inv in investments) inv.id};
    final flows = [
      for (final cf in allCashFlows)
        if (ids.contains(cf.investmentId)) cf,
    ];

    final converted = await batchConverter.batchConvert(
      cashFlows: flows,
      baseCurrency: baseCurrency,
      fallbackStrategy: fallbackStrategy,
    );
    for (final cf in converted) {
      if (cf.currency != baseCurrency) {
        throw CurrencyConversionException(
          'No exchange rate for ${cf.currency} → $baseCurrency',
        );
      }
    }

    final values = <String, TerminalValues>{
      for (final inv in investments)
        inv.id: CurrentValueCalculator.terminalValues(
          investments: [inv],
          cashFlows: flows,
          asOf: today,
        ),
    };
    final valueFlows = [for (final v in values.values) ...v.flows];
    final convertedValues = await batchConverter.batchConvert(
      cashFlows: valueFlows,
      baseCurrency: baseCurrency,
      fallbackStrategy: fallbackStrategy,
    );
    // A value with no rate at all counts as missing, never as a native
    // amount under the base-currency symbol.
    final valuesByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in convertedValues) {
      if (cf.currency != baseCurrency) continue;
      valuesByInvestment.putIfAbsent(cf.investmentId, () => []).add(cf);
    }

    return calculate(
      goal: goal,
      investments: investments,
      cashFlows: converted,
      terminalValues: {
        for (final MapEntry(:key, :value) in values.entries)
          key: value.flows.isEmpty
              ? value
              : value.withConvertedFlows(valuesByInvestment[key] ?? const []),
      },
      targetAmount: await targetInBaseCurrency(
        goal: goal,
        batchConverter: batchConverter,
        baseCurrency: baseCurrency,
        fallbackStrategy: fallbackStrategy,
      ),
      asOf: today,
    );
  }

  /// The date of the latest cash flow of the investments [goal] tracks, or
  /// null when there is none.
  static DateTime? getLastActivityDate({
    required GoalEntity goal,
    required List<InvestmentEntity> allInvestments,
    required List<CashFlowEntity> allCashFlows,
  }) {
    final ids = {
      for (final inv in linkedInvestments(goal, allInvestments)) inv.id,
    };
    if (ids.isEmpty) return null;
    DateTime? latest;
    for (final cf in allCashFlows) {
      if (!ids.contains(cf.investmentId)) continue;
      if (latest == null || cf.date.isAfter(latest)) latest = cf.date;
    }
    return latest;
  }
}
