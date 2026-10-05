import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

/// FIRE calculation result - computed values based on settings and portfolio
class FireCalculationResult {
  // Core FIRE numbers
  final double fireNumber; // Target corpus needed
  final double coastFireNumber; // Amount needed to coast
  final double baristaFireNumber; // Amount for partial independence

  // Current status
  final double currentPortfolioValue;
  final double progressPercentage; // 0-100+
  final FireProgressStatus status;

  // Projections
  final double requiredMonthlySavings;
  final double currentMonthlySavingsRate;

  /// Age at [projectedFireDate]; null when FIRE is not reachable at the
  /// current savings rate.
  final int? projectedFireAge;
  final DateTime? projectedFireDate;

  // Inflation-adjusted values
  final double inflationAdjustedFireNumber;
  final double inflationAdjustedMonthlyExpenses;

  // Gap analysis
  final double portfolioGap; // fireNumber - currentPortfolioValue
  final double monthlyGap; // requiredMonthlySavings - currentMonthlySavingsRate

  // Milestones
  final List<FireMilestone> milestones;
  final FireMilestone? nextMilestone;
  final List<FireMilestone> achievedMilestones;

  // Breakdown
  final double emergencyFundNeeded;
  final double healthcareCorpusNeeded;
  final double coreRetirementCorpus;

  /// Passive income and pension, as a corpus, taken off the buffers above:
  /// [coreRetirementCorpus] + [healthcareCorpusNeeded] +
  /// [emergencyFundNeeded] − this = [fireNumber].
  final double otherIncomeDeduction;

  /// [fireNumber] as a multiple of annual expenses (30.5× with the
  /// defaults: 25× at a 4% withdrawal rate, plus the buffers).
  final double expenseMultiple;

  /// Where the corpus and the monthly savings came from.
  final FireInputsSummary? inputs;

  // Metadata
  final DateTime calculatedAt;

  const FireCalculationResult({
    required this.fireNumber,
    required this.coastFireNumber,
    required this.baristaFireNumber,
    required this.currentPortfolioValue,
    required this.progressPercentage,
    required this.status,
    required this.requiredMonthlySavings,
    required this.currentMonthlySavingsRate,
    this.projectedFireAge,
    this.projectedFireDate,
    required this.inflationAdjustedFireNumber,
    required this.inflationAdjustedMonthlyExpenses,
    required this.portfolioGap,
    required this.monthlyGap,
    required this.milestones,
    this.nextMilestone,
    required this.achievedMilestones,
    required this.emergencyFundNeeded,
    required this.healthcareCorpusNeeded,
    required this.coreRetirementCorpus,
    this.otherIncomeDeduction = 0,
    this.expenseMultiple = 0,
    this.inputs,
    required this.calculatedAt,
  });

  /// Whether FIRE has been achieved
  bool get isFireAchieved => progressPercentage >= 100;

  /// Whether Coast FIRE has been achieved
  bool get isCoastFireAchieved => currentPortfolioValue >= coastFireNumber;

  /// Formatted progress (capped at 100 for display)
  double get displayProgress => progressPercentage.clamp(0, 100);

  /// Years remaining to projected FIRE (can be negative if behind)
  int get yearsToProjectedFire {
    if (projectedFireDate == null) return 0;
    return projectedFireDate!.difference(DateTime.now()).inDays ~/ 365;
  }

  /// Create empty result for initial state
  factory FireCalculationResult.empty() {
    return FireCalculationResult(
      fireNumber: 0,
      coastFireNumber: 0,
      baristaFireNumber: 0,
      currentPortfolioValue: 0,
      progressPercentage: 0,
      status: FireProgressStatus.notStarted,
      requiredMonthlySavings: 0,
      currentMonthlySavingsRate: 0,
      inflationAdjustedFireNumber: 0,
      inflationAdjustedMonthlyExpenses: 0,
      portfolioGap: 0,
      monthlyGap: 0,
      milestones: [],
      achievedMilestones: [],
      emergencyFundNeeded: 0,
      healthcareCorpusNeeded: 0,
      coreRetirementCorpus: 0,
      calculatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'FireCalculationResult(fireNumber: $fireNumber, '
        'progress: ${progressPercentage.toStringAsFixed(1)}%, '
        'status: ${status.displayName})';
  }
}

/// Where the monthly savings figure came from.
enum MonthlySavingsSource {
  /// The SIP the user declared.
  declared,

  /// Net new money of the last 12 months.
  history,

  /// Less than 3 months of cash flows: no estimate, 0 is used.
  notEnoughHistory,
}

/// How the FIRE corpus is built, in the base currency.
class FireInputsSummary {
  /// Current values of open investments that have one.
  final double investmentsValue;

  /// Principal still invested in open investments without a current value.
  final double principalWithoutValue;

  /// The user's other assets.
  final double otherAssets;
  final MonthlySavingsSource savingsSource;

  const FireInputsSummary({
    required this.investmentsValue,
    required this.principalWithoutValue,
    required this.otherAssets,
    required this.savingsSource,
  });

  double get corpus => investmentsValue + principalWithoutValue + otherAssets;
}

/// Individual FIRE milestone
class FireMilestone {
  final FireMilestoneType type;
  final double targetAmount;
  final bool isAchieved;
  final DateTime? achievedDate;
  final double currentProgress; // 0-100 within this milestone

  const FireMilestone({
    required this.type,
    required this.targetAmount,
    required this.isAchieved,
    this.achievedDate,
    required this.currentProgress,
  });

  String get label => type.label;
  int get percentage => type.percentage;

  @override
  String toString() {
    return 'FireMilestone(${type.label}, achieved: $isAchieved)';
  }
}

/// Projection data point for charts
class FireProjectionPoint {
  final DateTime date;
  final int age;
  final double projectedValue;
  final double targetValue;
  final bool isHistorical;

  const FireProjectionPoint({
    required this.date,
    required this.age,
    required this.projectedValue,
    required this.targetValue,
    this.isHistorical = false,
  });

  double get progressAtPoint =>
      targetValue > 0 ? (projectedValue / targetValue * 100) : 0;
}

/// FIRE scenario for what-if analysis
class FireScenario {
  final String name;
  final double monthlySavings;
  final double returnRate;
  final int projectedFireAge;
  final DateTime projectedFireDate;
  final double finalCorpus;

  const FireScenario({
    required this.name,
    required this.monthlySavings,
    required this.returnRate,
    required this.projectedFireAge,
    required this.projectedFireDate,
    required this.finalCorpus,
  });
}
