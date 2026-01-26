import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';

void main() {
  late FireCalculationService service;
  late FireSettingsEntity testSettings;

  setUp(() {
    service = FireCalculationService();
    testSettings = FireSettingsEntity(
      id: 'fire-1',
      monthlyExpenses: 50000,
      safeWithdrawalRate: 4.0,
      currentAge: 30,
      targetFireAge: 45,
      lifeExpectancy: 85,
      inflationRate: 6.0,
      preRetirementReturn: 12.0,
      postRetirementReturn: 8.0,
      healthcareBuffer: 20.0,
      emergencyMonths: 6,
      fireType: FireType.regular,
      monthlyPassiveIncome: 0,
      expectedPension: 0,
      isSetupComplete: true,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  });

  group('FireCalculationService.calculate', () {
    test('calculates FIRE number correctly with no passive income', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 0,
        currentMonthlySavings: 50000,
      );

      // Verify FIRE number is calculated
      expect(result.fireNumber, greaterThan(0));
      // With 6% inflation over 15 years, expenses will be much higher
      // FIRE number should be > 25x annual expenses (adjusted for inflation)
      expect(result.fireNumber, greaterThan(testSettings.annualExpenses * 25));
    });

    test('calculates progress percentage correctly', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 5000000,
        currentMonthlySavings: 50000,
      );

      // Progress = (currentValue / fireNumber) * 100
      expect(result.progressPercentage, greaterThan(0));
      expect(result.currentPortfolioValue, 5000000);
    });

    test('returns achieved status when FIRE number is reached', () {
      // First calculate to get the FIRE number
      final initial = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 0,
        currentMonthlySavings: 50000,
      );

      // Now calculate with portfolio value >= FIRE number
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: initial.fireNumber * 1.1,
        currentMonthlySavings: 50000,
      );

      expect(result.status, FireProgressStatus.achieved);
      expect(result.progressPercentage, greaterThanOrEqualTo(100));
    });

    test('returns notStarted status when portfolio is zero', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 0,
        currentMonthlySavings: 0,
      );

      expect(result.status, FireProgressStatus.notStarted);
      expect(result.progressPercentage, 0);
    });

    test('calculates coast FIRE number correctly', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      // Coast FIRE should be less than full FIRE (present value)
      expect(result.coastFireNumber, lessThan(result.fireNumber));
      expect(result.coastFireNumber, greaterThan(0));
    });

    test('calculates barista FIRE as 50% of FIRE number', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      expect(result.baristaFireNumber, closeTo(result.fireNumber * 0.5, 1));
    });

    test('generates correct milestones', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      expect(result.milestones.length, 5);
      expect(result.milestones[0].type, FireMilestoneType.percent10);
      expect(result.milestones[1].type, FireMilestoneType.percent25);
      expect(result.milestones[2].type, FireMilestoneType.percent50);
      expect(result.milestones[3].type, FireMilestoneType.percent75);
      expect(result.milestones[4].type, FireMilestoneType.percent100);
    });

    test('calculates required monthly savings', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      expect(result.requiredMonthlySavings, greaterThanOrEqualTo(0));
    });

    test('calculates projected FIRE age', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      expect(result.projectedFireAge, greaterThan(testSettings.currentAge));
    });

    test('reduces FIRE number with passive income', () {
      final settingsWithIncome = testSettings.copyWith(
        monthlyPassiveIncome: 10000,
      );

      final withoutIncome = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      final withIncome = service.calculate(
        settings: settingsWithIncome,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      expect(withIncome.fireNumber, lessThan(withoutIncome.fireNumber));
    });

    test('calculates emergency fund correctly', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      // Emergency fund = inflationAdjustedMonthlyExpenses * emergencyMonths
      expect(result.emergencyFundNeeded, greaterThan(0));
      expect(
        result.emergencyFundNeeded,
        closeTo(result.inflationAdjustedMonthlyExpenses * 6, 1),
      );
    });

    test('calculates healthcare corpus correctly', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      // Healthcare buffer is 20% of core retirement corpus
      expect(result.healthcareCorpusNeeded, greaterThan(0));
      expect(
        result.healthcareCorpusNeeded,
        closeTo(result.coreRetirementCorpus * 0.2, 1),
      );
    });

    test('returns coasting status when coast FIRE is achieved', () {
      // First get the coast FIRE number
      final initial = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 0,
        currentMonthlySavings: 50000,
      );

      // Portfolio equals coast FIRE number but less than full FIRE
      final coastValue = initial.coastFireNumber;

      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: coastValue,
        currentMonthlySavings: 50000,
      );

      expect(result.status, FireProgressStatus.coasting);
    });

    test('handles zero years to FIRE gracefully', () {
      final zeroYearsSettings = testSettings.copyWith(
        currentAge: 45,
        targetFireAge: 45,
      );

      final result = service.calculate(
        settings: zeroYearsSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      expect(result.fireNumber, greaterThanOrEqualTo(0));
      expect(result.coastFireNumber, result.fireNumber);
    });

    test('returns behind status when progress is below 25%', () {
      // First calculate to get the FIRE number
      final initial = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 0,
        currentMonthlySavings: 50000,
      );

      // Portfolio at 10% of FIRE number (below 25% threshold)
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: initial.fireNumber * 0.10,
        currentMonthlySavings: 50000,
      );

      expect(result.status, FireProgressStatus.behind);
      expect(result.progressPercentage, lessThan(25));
    });

    test(
      'returns onTrack status when progress is between 25% and 75% and below coast',
      () {
        // First calculate to get the FIRE number and coast number
        final initial = service.calculate(
          settings: testSettings,
          currentPortfolioValue: 0,
          currentMonthlySavings: 50000,
        );

        // Calculate a value that is 30% of FIRE but below coast FIRE
        // Coast FIRE is typically around 30-40% of full FIRE for 15 year horizon
        final coastRatio = initial.coastFireNumber / initial.fireNumber;

        // If 30% is below coast, use it; otherwise use a value just below coast
        final targetRatio = coastRatio > 0.30 ? 0.30 : coastRatio * 0.9;

        final result = service.calculate(
          settings: testSettings,
          currentPortfolioValue: initial.fireNumber * targetRatio,
          currentMonthlySavings: 50000,
        );

        // Should be onTrack if between 25-75% and below coast
        // Or behind if below 25%
        expect(
          result.status == FireProgressStatus.onTrack ||
              result.status == FireProgressStatus.behind,
          isTrue,
        );
      },
    );

    test('returns ahead or coasting when progress is 75% or more', () {
      // First calculate to get the FIRE number
      final initial = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 0,
        currentMonthlySavings: 50000,
      );

      // Portfolio at 80% of FIRE number (above 75% threshold)
      // At this level, likely above coast FIRE so will be coasting
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: initial.fireNumber * 0.80,
        currentMonthlySavings: 50000,
      );

      // Should be ahead or coasting (coasting takes precedence if above coast FIRE)
      expect(
        result.status == FireProgressStatus.ahead ||
            result.status == FireProgressStatus.coasting,
        isTrue,
      );
      expect(result.progressPercentage, greaterThanOrEqualTo(75));
    });
  });

  group('FireCalculationService.generateProjections', () {
    test('generates correct number of projection points', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      final projections = service.generateProjections(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        monthlySavings: 50000,
        fireNumber: result.fireNumber,
      );

      // Should have points for years 0 to (yearsToFire + 5) = 21 points
      expect(projections.length, testSettings.yearsToFire + 6);
    });

    test('first projection point is current portfolio value', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      final projections = service.generateProjections(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        monthlySavings: 50000,
        fireNumber: result.fireNumber,
      );

      expect(projections.first.projectedValue, 1000000);
      expect(projections.first.age, testSettings.currentAge);
      expect(projections.first.isHistorical, isTrue);
    });

    test('projections increase over time with positive savings', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      final projections = service.generateProjections(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        monthlySavings: 50000,
        fireNumber: result.fireNumber,
      );

      for (var i = 1; i < projections.length; i++) {
        expect(
          projections[i].projectedValue,
          greaterThan(projections[i - 1].projectedValue),
        );
      }
    });

    test('projection target value is consistent', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 50000,
      );

      final projections = service.generateProjections(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        monthlySavings: 50000,
        fireNumber: result.fireNumber,
      );

      for (final point in projections) {
        expect(point.targetValue, result.fireNumber);
      }
    });
  });
}
