import 'dart:math' as math;

import 'package:inv_tracker/core/calculations/planning_inputs_calculator.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

/// Service for calculating FIRE numbers and projections
///
/// **IMPORTANT**: This service uses REAL returns (inflation-adjusted) for all calculations.
/// This ensures accurate retirement planning by working in today's money.
///
/// Key concepts:
/// - FIRE number is calculated in TODAY'S money (not inflated)
/// - Real return = Nominal return - Inflation rate (using Fisher equation)
/// - All projections use real returns to maintain purchasing power
class FireCalculationService {
  /// Projections longer than this are shown as not reachable.
  static const maxProjectionMonths = 100 * 12;

  /// Projected this many years before the target age or earlier is ahead.
  static const aheadByYears = 2;

  /// Calculate complete FIRE analysis
  ///
  /// This method calculates the FIRE number in today's money and uses real returns
  /// for all projections. This approach is mathematically correct and user-friendly.
  ///
  /// [settings] amounts, [currentPortfolioValue] and [currentMonthlySavings]
  /// must be in one currency. Ages and dates are worked out as of [asOf]
  /// (today when omitted).
  ///
  /// Example:
  /// - Monthly expenses: ₹50,000
  /// - Inflation: 6%, Nominal return: 12%
  /// - Real return: ~5.66%
  /// - FIRE number: ₹1.83 crore (in today's money): 25× annual expenses at a
  ///   4% withdrawal rate, plus a 20% healthcare buffer and 6 months of
  ///   expenses, i.e. 30.5× annual expenses
  FireCalculationResult calculate({
    required FireSettingsEntity settings,
    required double currentPortfolioValue,
    required double currentMonthlySavings,
    DateTime? asOf,
    FireInputsSummary? inputs,
  }) {
    final now = DateTime.now();
    final today = asOf ?? DateTime(now.year, now.month, now.day);
    final currentAge = settings.ageAt(today);
    final yearsToFire = settings.targetFireAge - currentAge;

    // Calculate real return using Fisher equation
    // (1 + nominal) = (1 + real) × (1 + inflation)
    // Solving for real: real = (1 + nominal) / (1 + inflation) - 1
    final realReturn = _calculateRealReturn(
      settings.preRetirementReturn,
      settings.inflationRate,
    );

    // Calculate FIRE number in TODAY'S money (no inflation adjustment)
    // Apply FIRE type expense multiplier (e.g., lean = 70%, fat = 150%)
    final fireTypeAdjustedExpenses =
        settings.monthlyExpenses *
        settings.fireType.effective.expenseMultiplier;
    final currentAnnualExpenses = fireTypeAdjustedExpenses * 12;

    // Calculate core FIRE number (25x rule with SWR) - in today's money
    final coreRetirementCorpus =
        currentAnnualExpenses * settings.fireMultiplier;

    // Calculate emergency fund (in today's money)
    final emergencyFundNeeded =
        fireTypeAdjustedExpenses * settings.emergencyMonths;

    // Calculate healthcare buffer (percentage of core corpus)
    final healthcareCorpusNeeded =
        coreRetirementCorpus * (settings.healthcareBuffer / 100);

    // Total FIRE number (in today's money)
    final fireNumber =
        coreRetirementCorpus + emergencyFundNeeded + healthcareCorpusNeeded;

    // Adjust for passive income and pension (in today's money)
    final annualPassiveIncome = settings.monthlyPassiveIncome * 12;
    final annualPension = settings.expectedPension * 12;
    final totalOtherIncome = annualPassiveIncome + annualPension;
    final adjustedFireNumber =
        fireNumber - (totalOtherIncome * settings.fireMultiplier);
    final finalFireNumber = adjustedFireNumber > 0 ? adjustedFireNumber : 0.0;

    // The multiple of the annual expenses entered that the FIRE number
    // really is, the FIRE type's lifestyle factor included.
    final expenseMultiple = settings.annualExpenses > 0
        ? finalFireNumber / settings.annualExpenses
        : 0.0;

    // Calculate what this will be worth in future money (for display purposes)
    final inflationMultiplier = math.pow(
      1 + settings.inflationRate / 100,
      math.max(0, yearsToFire),
    );
    final inflationAdjustedFireNumber = finalFireNumber * inflationMultiplier;
    final inflationAdjustedMonthlyExpenses =
        fireTypeAdjustedExpenses * inflationMultiplier;

    // Calculate Coast FIRE number using REAL returns
    final coastFireNumber = _calculateCoastFireNumber(
      targetAmount: finalFireNumber,
      yearsToGrow: yearsToFire,
      returnRate: realReturn,
    );

    // Calculate Barista FIRE number (50% of FIRE number)
    final baristaFireNumber = finalFireNumber * 0.5;

    // Calculate progress
    final progressPercentage = finalFireNumber > 0
        ? (currentPortfolioValue / finalFireNumber * 100)
        : 0.0;

    // Calculate required monthly savings using REAL returns
    final requiredMonthlySavings =
        PlanningInputsCalculator.requiredMonthlyContribution(
          target: finalFireNumber,
          current: currentPortfolioValue,
          months: yearsToFire * 12,
          annualRatePercent: realReturn,
        );

    // Months until the corpus reaches the FIRE number, using REAL returns.
    // Savings that could not be estimated are not projected as ₹0 a month.
    final savingsUnknown =
        inputs?.savingsSource == MonthlySavingsSource.notEnoughHistory;
    final solvedMonths = PlanningInputsCalculator.monthsToReach(
      target: finalFireNumber,
      current: currentPortfolioValue,
      monthlySavings: currentMonthlySavings,
      annualRatePercent: realReturn,
      maxMonths: maxProjectionMonths,
    );
    final monthsToFire = savingsUnknown && solvedMonths != 0
        ? null
        : solvedMonths;
    final projectedFireDate = monthsToFire == null
        ? null
        : PlanningInputsCalculator.addMonths(today, monthsToFire);
    final projectedFireAge = projectedFireDate == null
        ? null
        : settings.ageAt(projectedFireDate);

    // Determine status
    final status = _determineStatus(
      progressPercentage: progressPercentage,
      currentValue: currentPortfolioValue,
      coastNumber: coastFireNumber,
      projectedFireAge: projectedFireAge,
      targetFireAge: settings.targetFireAge,
      savingsUnknown: savingsUnknown,
    );

    // Generate milestones
    final milestones = _generateMilestones(
      fireNumber: finalFireNumber,
      currentValue: currentPortfolioValue,
    );

    // Optimization: Single pass loop for achieved and next milestone
    final achievedMilestones = <FireMilestone>[];
    FireMilestone? nextMilestone;
    for (final m in milestones) {
      if (m.isAchieved) {
        achievedMilestones.add(m);
      } else {
        nextMilestone ??= m;
      }
    }

    return FireCalculationResult(
      fireNumber: finalFireNumber,
      coastFireNumber: coastFireNumber,
      baristaFireNumber: baristaFireNumber,
      currentPortfolioValue: currentPortfolioValue,
      progressPercentage: progressPercentage,
      status: status,
      requiredMonthlySavings: requiredMonthlySavings,
      currentMonthlySavingsRate: currentMonthlySavings,
      projectedFireAge: projectedFireAge,
      projectedFireDate: projectedFireDate,
      inflationAdjustedFireNumber: inflationAdjustedFireNumber,
      inflationAdjustedMonthlyExpenses: inflationAdjustedMonthlyExpenses,
      portfolioGap: finalFireNumber - currentPortfolioValue,
      monthlyGap: requiredMonthlySavings - currentMonthlySavings,
      milestones: milestones,
      nextMilestone: nextMilestone,
      achievedMilestones: achievedMilestones,
      emergencyFundNeeded: emergencyFundNeeded,
      healthcareCorpusNeeded: healthcareCorpusNeeded,
      coreRetirementCorpus: coreRetirementCorpus,
      otherIncomeDeduction: fireNumber - finalFireNumber,
      expenseMultiple: expenseMultiple,
      inputs: inputs,
      calculatedAt: now,
    );
  }

  /// Calculate real return using Fisher equation
  ///
  /// Fisher equation: (1 + nominal) = (1 + real) × (1 + inflation)
  /// Solving for real: real = (1 + nominal) / (1 + inflation) - 1
  ///
  /// Example:
  /// - Nominal return: 12%
  /// - Inflation: 6%
  /// - Real return: (1.12 / 1.06) - 1 = 0.0566 = 5.66%
  ///
  /// This is the actual purchasing power growth rate.
  double _calculateRealReturn(double nominalReturn, double inflationRate) {
    final nominal = nominalReturn / 100;
    final inflation = inflationRate / 100;
    final real = (1 + nominal) / (1 + inflation) - 1;
    return real * 100; // Convert back to percentage
  }

  /// Calculate Coast FIRE number using compound interest formula
  double _calculateCoastFireNumber({
    required double targetAmount,
    required int yearsToGrow,
    required double returnRate,
  }) {
    if (yearsToGrow <= 0) return targetAmount;
    final rate = returnRate / 100;
    return targetAmount / math.pow(1 + rate, yearsToGrow).toDouble();
  }

  /// FIRE progress status: projected FIRE age against the target age.
  ///
  /// - achieved: 100%+ of FIRE number reached
  /// - coasting: growth alone reaches the FIRE number by the target age,
  ///   which is the timeline too: with no savings the projection meets it
  /// - notStarted: nothing invested yet
  /// - ahead: projected [aheadByYears]+ years before the target age
  /// - onTrack: projected by the target age
  /// - behind: projected after the target age, or not reachable
  /// - notEnoughHistory: none of the above can be told, because the monthly
  ///   savings could not be estimated yet
  FireProgressStatus _determineStatus({
    required double progressPercentage,
    required double currentValue,
    required double coastNumber,
    required int? projectedFireAge,
    required int targetFireAge,
    required bool savingsUnknown,
  }) {
    if (progressPercentage >= 100) {
      return FireProgressStatus.achieved;
    }
    if (currentValue >= coastNumber) {
      return FireProgressStatus.coasting;
    }
    if (progressPercentage <= 0) {
      return FireProgressStatus.notStarted;
    }
    if (savingsUnknown) {
      return FireProgressStatus.notEnoughHistory;
    }
    if (projectedFireAge == null || projectedFireAge > targetFireAge) {
      return FireProgressStatus.behind;
    }
    if (projectedFireAge <= targetFireAge - aheadByYears) {
      return FireProgressStatus.ahead;
    }
    return FireProgressStatus.onTrack;
  }

  /// Generate milestone list
  List<FireMilestone> _generateMilestones({
    required double fireNumber,
    required double currentValue,
  }) {
    final milestoneTypes = [
      FireMilestoneType.percent10,
      FireMilestoneType.percent25,
      FireMilestoneType.percent50,
      FireMilestoneType.percent75,
      FireMilestoneType.percent100,
    ];

    return milestoneTypes.map((type) {
      final targetAmount = fireNumber * type.percentage / 100;
      final isAchieved = currentValue >= targetAmount;
      final double progress = targetAmount > 0
          ? (currentValue / targetAmount * 100).clamp(0.0, 100.0)
          : 0.0;

      return FireMilestone(
        type: type,
        targetAmount: targetAmount,
        isAchieved: isAchieved,
        currentProgress: progress,
      );
    }).toList();
  }

  /// Generate projection points for chart
  ///
  /// Uses REAL returns for projections to maintain consistency with FIRE calculations.
  /// All values are in today's money (purchasing power).
  List<FireProjectionPoint> generateProjections({
    required FireSettingsEntity settings,
    required double currentPortfolioValue,
    required double monthlySavings,
    required double fireNumber,
    DateTime? asOf,
  }) {
    final points = <FireProjectionPoint>[];
    final now = DateTime.now();
    final today = asOf ?? DateTime(now.year, now.month, now.day);
    final currentAge = settings.ageAt(today);

    // Calculate real return for projections
    final realReturn = _calculateRealReturn(
      settings.preRetirementReturn,
      settings.inflationRate,
    );
    final monthlyRate = realReturn / 100 / 12;
    var balance = currentPortfolioValue;

    for (var year = 0; year <= settings.yearsToFireAt(today) + 5; year++) {
      points.add(
        FireProjectionPoint(
          date: PlanningInputsCalculator.addMonths(today, year * 12),
          age: currentAge + year,
          projectedValue: balance,
          targetValue: fireNumber,
          isHistorical: year == 0,
        ),
      );

      // Compound for next year using real returns
      for (var month = 0; month < 12; month++) {
        balance = balance * (1 + monthlyRate) + monthlySavings;
      }
    }

    return points;
  }
}
