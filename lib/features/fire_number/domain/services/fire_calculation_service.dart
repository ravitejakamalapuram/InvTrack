import 'dart:math' as math;

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
  /// Calculate complete FIRE analysis
  ///
  /// This method calculates the FIRE number in today's money and uses real returns
  /// for all projections. This approach is mathematically correct and user-friendly.
  ///
  /// Example:
  /// - Monthly expenses: ₹50,000
  /// - Inflation: 6%, Nominal return: 12%
  /// - Real return: ~5.66%
  /// - FIRE number: ₹1.5 crore (in today's money)
  /// - At retirement, this will have same purchasing power as ₹4.8cr in future money
  FireCalculationResult calculate({
    required FireSettingsEntity settings,
    required double currentPortfolioValue,
    required double currentMonthlySavings,
  }) {
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
        settings.monthlyExpenses * settings.fireType.expenseMultiplier;
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

    // Calculate what this will be worth in future money (for display purposes)
    final yearsToFire = settings.yearsToFire;
    final inflationMultiplier = math.pow(
      1 + settings.inflationRate / 100,
      yearsToFire,
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

    // Determine status
    final status = _determineStatus(
      progressPercentage: progressPercentage,
      currentValue: currentPortfolioValue,
      coastNumber: coastFireNumber,
      yearsToFire: yearsToFire,
    );

    // Calculate required monthly savings using REAL returns
    final requiredMonthlySavings = _calculateRequiredMonthlySavings(
      targetAmount: finalFireNumber,
      currentAmount: currentPortfolioValue,
      years: yearsToFire,
      annualReturn: realReturn,
    );

    // Calculate projected FIRE age using REAL returns
    final projectedFireAge = _calculateProjectedFireAge(
      targetAmount: finalFireNumber,
      currentAmount: currentPortfolioValue,
      monthlySavings: currentMonthlySavings,
      annualReturn: realReturn,
      currentAge: settings.currentAge,
    );

    // Calculate projected FIRE date
    final projectedFireDate = projectedFireAge > settings.currentAge
        ? DateTime.now().add(
            Duration(days: (projectedFireAge - settings.currentAge) * 365),
          )
        : null;

    // Generate milestones
    final milestones = _generateMilestones(
      fireNumber: finalFireNumber,
      currentValue: currentPortfolioValue,
    );

    final achievedMilestones = milestones.where((m) => m.isAchieved).toList();
    final nextMilestone = milestones.cast<FireMilestone?>().firstWhere(
      (m) => !m!.isAchieved,
      orElse: () => null,
    );

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
      calculatedAt: DateTime.now(),
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

  /// Calculate required monthly savings using future value formula
  double _calculateRequiredMonthlySavings({
    required double targetAmount,
    required double currentAmount,
    required int years,
    required double annualReturn,
  }) {
    if (years <= 0) return 0.0;

    final monthlyRate = annualReturn / 100 / 12;
    final months = years * 12;

    // Future value of current amount
    final futureValueOfCurrent =
        currentAmount * math.pow(1 + monthlyRate, months).toDouble();

    // Amount still needed
    final amountNeeded = targetAmount - futureValueOfCurrent;
    if (amountNeeded <= 0) return 0.0;

    // PMT formula: PMT = FV * r / ((1 + r)^n - 1)
    final denominator = math.pow(1 + monthlyRate, months).toDouble() - 1;
    if (denominator == 0) return amountNeeded / months;

    return amountNeeded * monthlyRate / denominator;
  }

  /// Calculate projected FIRE age based on current savings rate
  int _calculateProjectedFireAge({
    required double targetAmount,
    required double currentAmount,
    required double monthlySavings,
    required double annualReturn,
    required int currentAge,
  }) {
    if (currentAmount >= targetAmount) return currentAge;
    if (monthlySavings <= 0) return 100; // Never if not saving

    final monthlyRate = annualReturn / 100 / 12;
    const maxMonths = 600; // 50 years max

    // Use logarithmic formula for O(1) calculation instead of O(N) loop
    // Formula: n = ln((FV*r + PMT) / (PV*r + PMT)) / ln(1+r)
    int months;

    if (monthlyRate.abs() < 1e-9) {
      // Simple linear growth if rate is effectively zero
      // FV = PV + n*PMT => n = (FV - PV) / PMT
      months = ((targetAmount - currentAmount) / monthlySavings).ceil();
    } else {
      final r = monthlyRate;
      final num = targetAmount * r + monthlySavings;
      final den = currentAmount * r + monthlySavings;

      // Logarithm domain check (should be positive given checks above)
      if (num <= 0 || den <= 0) return 100;

      final monthsFloat = math.log(num / den) / math.log(1 + r);
      months = monthsFloat.ceil();
    }

    if (months > maxMonths) months = maxMonths;
    if (months < 0) months = 0; // Should not happen due to initial check

    return currentAge + (months / 12).ceil();
  }

  /// Determine FIRE progress status based on progress percentage and Coast FIRE
  ///
  /// Status determination logic:
  /// - achieved: 100%+ of FIRE number reached
  /// - coasting: Reached Coast FIRE (can stop saving, investments will grow to FIRE)
  /// - ahead: 75%+ progress OR on track to reach FIRE 2+ years early
  /// - onTrack: 25-75% progress with reasonable trajectory
  /// - behind: <25% progress with significant time remaining
  /// - notStarted: No investments yet
  FireProgressStatus _determineStatus({
    required double progressPercentage,
    required double currentValue,
    required double coastNumber,
    required int yearsToFire,
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

    // Use progress percentage thresholds for status
    // These thresholds are based on typical FIRE journey milestones
    if (progressPercentage >= 75) {
      return FireProgressStatus.ahead;
    }
    if (progressPercentage >= 25) {
      return FireProgressStatus.onTrack;
    }
    return FireProgressStatus.behind;
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
  }) {
    final points = <FireProjectionPoint>[];

    // Calculate real return for projections
    final realReturn = _calculateRealReturn(
      settings.preRetirementReturn,
      settings.inflationRate,
    );
    final monthlyRate = realReturn / 100 / 12;
    var balance = currentPortfolioValue;

    for (var year = 0; year <= settings.yearsToFire + 5; year++) {
      final age = settings.currentAge + year;
      final date = DateTime.now().add(Duration(days: year * 365));

      points.add(
        FireProjectionPoint(
          date: date,
          age: age,
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
