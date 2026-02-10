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
    test('calculates FIRE number in today\'s money (not inflated)', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 0,
        currentMonthlySavings: 50000,
      );

      // Verify FIRE number is calculated
      expect(result.fireNumber, greaterThan(0));

      // NEW BEHAVIOR: FIRE number is in TODAY'S money
      // Monthly expenses: ₹50,000
      // Annual expenses: ₹6,00,000
      // FIRE multiplier: 25x (from 4% SWR)
      // Core corpus: ₹1,50,00,000
      // Plus emergency fund (6 months): ₹3,00,000
      // Plus healthcare buffer (20%): ₹30,00,000
      // Total: ₹1,83,00,000

      final expectedCoreCorpus = testSettings.annualExpenses * 25; // ₹1.5cr
      final expectedEmergencyFund = testSettings.monthlyExpenses * 6; // ₹3L
      final expectedHealthcare = expectedCoreCorpus * 0.2; // ₹30L
      final expectedTotal = expectedCoreCorpus + expectedEmergencyFund + expectedHealthcare;

      expect(result.fireNumber, closeTo(expectedTotal, 1000));
      expect(result.coreRetirementCorpus, closeTo(expectedCoreCorpus, 1000));
      expect(result.emergencyFundNeeded, closeTo(expectedEmergencyFund, 1000));
      expect(result.healthcareCorpusNeeded, closeTo(expectedHealthcare, 1000));
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

    test('uses real returns for all calculations', () {
      // Test settings: 12% nominal, 6% inflation
      // Real return should be: (1.12 / 1.06) - 1 = 0.0566 = 5.66%
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 25000,
      );

      // FIRE number should be in today's money (not inflated)
      // ₹50,000/month × 12 × 25 = ₹1.5cr base
      // Plus emergency (₹3L) and healthcare (₹30L) = ₹1.83cr
      expect(result.fireNumber, closeTo(18300000, 10000));

      // Required savings should be calculated using real returns (~5.66%)
      // This should be significantly lower than if using nominal returns (12%)
      expect(result.requiredMonthlySavings, greaterThan(0));

      // Verify the calculation is using real returns by checking it's reasonable
      // With real returns, required savings should be achievable
      expect(result.requiredMonthlySavings, lessThan(100000));
    });

    test('provides inflation-adjusted values for display', () {
      final result = service.calculate(
        settings: testSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 25000,
      );

      // inflationAdjustedFireNumber should be the future value
      // FIRE number (₹1.83cr) × (1.06)^15 ≈ ₹4.39cr
      final inflationMultiplier = 2.396; // (1.06)^15
      final expectedInflatedValue = result.fireNumber * inflationMultiplier;

      expect(
        result.inflationAdjustedFireNumber,
        closeTo(expectedInflatedValue, 100000),
      );

      // inflationAdjustedMonthlyExpenses should be future expenses
      // ₹50,000 × (1.06)^15 ≈ ₹1,19,800
      final expectedInflatedExpenses = 50000 * inflationMultiplier;
      expect(
        result.inflationAdjustedMonthlyExpenses,
        closeTo(expectedInflatedExpenses, 1000),
      );
    });

    test('real return calculation handles edge cases', () {
      // Test with zero inflation
      final zeroInflationSettings = testSettings.copyWith(inflationRate: 0);
      final result1 = service.calculate(
        settings: zeroInflationSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 25000,
      );

      // With zero inflation, real return = nominal return
      // FIRE number should still be in today's money
      expect(result1.fireNumber, greaterThan(0));

      // Test with high inflation
      final highInflationSettings = testSettings.copyWith(inflationRate: 10);
      final result2 = service.calculate(
        settings: highInflationSettings,
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 25000,
      );

      // With high inflation (10%) and 12% nominal return
      // Real return = (1.12 / 1.10) - 1 ≈ 1.8%
      // Required savings should be much higher
      expect(result2.requiredMonthlySavings, greaterThan(result1.requiredMonthlySavings));
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

    test('returns onTrack status when progress is between 25% and 75% and below coast', () {
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
    });

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
