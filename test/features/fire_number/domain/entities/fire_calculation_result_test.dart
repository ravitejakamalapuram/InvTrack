import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

void main() {
  group('FireCalculationResult', () {
    late FireCalculationResult testResult;

    setUp(() {
      testResult = FireCalculationResult(
        fireNumber: 10000000,
        coastFireNumber: 5000000,
        baristaFireNumber: 5000000,
        currentPortfolioValue: 2500000,
        progressPercentage: 25.0,
        status: FireProgressStatus.onTrack,
        requiredMonthlySavings: 50000,
        currentMonthlySavingsRate: 40000,
        projectedFireAge: 48,
        projectedFireDate: DateTime(2038, 1, 1),
        inflationAdjustedFireNumber: 10000000,
        inflationAdjustedMonthlyExpenses: 100000,
        portfolioGap: 7500000,
        monthlyGap: 10000,
        milestones: [],
        achievedMilestones: [],
        emergencyFundNeeded: 600000,
        healthcareCorpusNeeded: 2000000,
        coreRetirementCorpus: 8000000,
        calculatedAt: DateTime(2024, 1, 1),
      );
    });

    test('isFireAchieved returns true when progress >= 100%', () {
      final achieved = FireCalculationResult(
        fireNumber: 10000000,
        coastFireNumber: 5000000,
        baristaFireNumber: 5000000,
        currentPortfolioValue: 12000000,
        progressPercentage: 120.0,
        status: FireProgressStatus.achieved,
        requiredMonthlySavings: 0,
        currentMonthlySavingsRate: 40000,
        projectedFireAge: 30,
        inflationAdjustedFireNumber: 10000000,
        inflationAdjustedMonthlyExpenses: 100000,
        portfolioGap: -2000000,
        monthlyGap: -40000,
        milestones: [],
        achievedMilestones: [],
        emergencyFundNeeded: 600000,
        healthcareCorpusNeeded: 2000000,
        coreRetirementCorpus: 8000000,
        calculatedAt: DateTime(2024, 1, 1),
      );

      expect(achieved.isFireAchieved, isTrue);
    });

    test('isFireAchieved returns false when progress < 100%', () {
      expect(testResult.isFireAchieved, isFalse);
    });

    test('isCoastFireAchieved returns true when value >= coastNumber', () {
      final coasting = FireCalculationResult(
        fireNumber: 10000000,
        coastFireNumber: 5000000,
        baristaFireNumber: 5000000,
        currentPortfolioValue: 5000000,
        progressPercentage: 50.0,
        status: FireProgressStatus.coasting,
        requiredMonthlySavings: 25000,
        currentMonthlySavingsRate: 40000,
        projectedFireAge: 42,
        inflationAdjustedFireNumber: 10000000,
        inflationAdjustedMonthlyExpenses: 100000,
        portfolioGap: 5000000,
        monthlyGap: -15000,
        milestones: [],
        achievedMilestones: [],
        emergencyFundNeeded: 600000,
        healthcareCorpusNeeded: 2000000,
        coreRetirementCorpus: 8000000,
        calculatedAt: DateTime(2024, 1, 1),
      );

      expect(coasting.isCoastFireAchieved, isTrue);
    });

    test('isCoastFireAchieved returns false when value < coastNumber', () {
      expect(testResult.isCoastFireAchieved, isFalse);
    });

    test('displayProgress clamps to 0-100 range', () {
      expect(testResult.displayProgress, 25.0);

      final overAchieved = FireCalculationResult(
        fireNumber: 10000000,
        coastFireNumber: 5000000,
        baristaFireNumber: 5000000,
        currentPortfolioValue: 15000000,
        progressPercentage: 150.0,
        status: FireProgressStatus.achieved,
        requiredMonthlySavings: 0,
        currentMonthlySavingsRate: 40000,
        projectedFireAge: 30,
        inflationAdjustedFireNumber: 10000000,
        inflationAdjustedMonthlyExpenses: 100000,
        portfolioGap: -5000000,
        monthlyGap: -40000,
        milestones: [],
        achievedMilestones: [],
        emergencyFundNeeded: 600000,
        healthcareCorpusNeeded: 2000000,
        coreRetirementCorpus: 8000000,
        calculatedAt: DateTime(2024, 1, 1),
      );

      expect(overAchieved.displayProgress, 100.0);
    });

    test('empty factory creates valid empty result', () {
      final empty = FireCalculationResult.empty();

      expect(empty.fireNumber, 0);
      expect(empty.progressPercentage, 0);
      expect(empty.status, FireProgressStatus.notStarted);
      expect(empty.milestones, isEmpty);
    });

    test('toString returns formatted string', () {
      final str = testResult.toString();

      expect(str, contains('fireNumber: 10000000'));
      expect(str, contains('progress: 25.0%'));
      expect(str, contains('status: On Track'));
    });
  });

  group('FireMilestone', () {
    test('creates milestone with correct properties', () {
      final milestone = FireMilestone(
        type: FireMilestoneType.percent25,
        targetAmount: 2500000,
        isAchieved: true,
        currentProgress: 100.0,
        achievedDate: DateTime(2024, 6, 1),
      );

      expect(milestone.type, FireMilestoneType.percent25);
      expect(milestone.targetAmount, 2500000);
      expect(milestone.isAchieved, isTrue);
      expect(milestone.currentProgress, 100.0);
      expect(milestone.achievedDate, DateTime(2024, 6, 1));
    });
  });
}
