// A11 (#755): projected FIRE age and date, status and the real multiple.
//
// Expected values were computed independently in Python. Defaults: ₹50,000 a
// month, SWR 4%, 20% healthcare buffer, 6 months emergency fund (FIRE number
// ₹1,83,00,000), 12% return and 6% inflation, so the real return is
// r = 1.12 / 1.06 − 1 = 5.660377% and the monthly rate is r / 12.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';

final _asOf = DateTime(2026, 10, 2);
const _fireNumber = 18300000.0;

FireSettingsEntity _settings({
  required int birthYear,
  int targetFireAge = 45,
  FireType fireType = FireType.regular,
  double monthlyPassiveIncome = 0,
}) => FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: birthYear,
  targetFireAge: targetFireAge,
  fireType: fireType,
  monthlyPassiveIncome: monthlyPassiveIncome,
  isSetupComplete: true,
  currency: 'INR',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  final service = FireCalculationService();

  group('PLAN-03: projected FIRE age without savings', () {
    test('₹50L and no savings reaches FIRE at 53, not 100', () {
      // n = ln(1.83 Cr / 50 L) / ln(1 + r/12) = 275.71 months → 276.
      final result = service.calculate(
        settings: _settings(birthYear: 1996),
        currentPortfolioValue: 5000000,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );

      expect(result.projectedFireAge, 53);
      expect(result.projectedFireDate, DateTime(2049, 10, 2));
    });

    test('the date adds the months solved for, not whole years', () {
      // ₹1,72,50,000, no savings: n = 12.556 months → 13 months, so
      // Nov 2027 at age 31 (the app rounded up to 2 years: Oct 2028, 32).
      final result = service.calculate(
        settings: _settings(birthYear: 1996),
        currentPortfolioValue: 17250000,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );

      expect(result.projectedFireDate, DateTime(2027, 11, 2));
      expect(result.projectedFireAge, 31);
    });

    test('nothing invested and nothing saved is not reachable', () {
      final result = service.calculate(
        settings: _settings(birthYear: 1996),
        currentPortfolioValue: 0,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );

      expect(result.projectedFireAge, isNull);
      expect(result.projectedFireDate, isNull);
    });
  });

  group('PLAN-04: status compares projected and target age', () {
    test('a rollover user with ₹14.03L and no new money is behind', () {
      // PV ₹14,02,551.73, no savings: n = 545.83 months → age 76 > 45.
      final result = service.calculate(
        settings: _settings(birthYear: 1996),
        currentPortfolioValue: 1402551.73,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );

      expect(result.progressPercentage, closeTo(7.664217, 1e-6));
      expect(result.projectedFireAge, 76);
      expect(result.status, FireProgressStatus.behind);
    });

    test('S5: 20% funded, saving ₹60k against ₹10.8k needed, is ahead', () {
      // Age 28, target 50, PV = 20% of ₹1.83 Cr. Projected at 60k/month:
      // 135.70 months → 136 → Feb 2038, age 40. Required over 22 years:
      // ₹10,764.78/month, so the gap is −₹49,235.22 (a surplus).
      final result = service.calculate(
        settings: _settings(birthYear: 1998, targetFireAge: 50),
        currentPortfolioValue: 0.2 * _fireNumber,
        currentMonthlySavings: 60000,
        asOf: _asOf,
      );

      expect(result.status, FireProgressStatus.ahead);
      expect(result.projectedFireAge, 40);
      expect(result.requiredMonthlySavings, closeTo(10764.78, 0.005));
      expect(result.monthlyGap, closeTo(-49235.22, 0.005));
    });

    test('reaching FIRE by the target age is on track', () {
      // ₹18.3L at ₹50k/month: n = 179.30 months → 180 → age 45 = target.
      final result = service.calculate(
        settings: _settings(birthYear: 1996),
        currentPortfolioValue: 0.1 * _fireNumber,
        currentMonthlySavings: 50000,
        asOf: _asOf,
      );

      expect(result.projectedFireAge, 45);
      expect(result.status, FireProgressStatus.onTrack);
    });
  });

  group('PLAN-05: age comes from the birth year', () {
    test('settings saved in 2024 at age 30 use 13 years, not 15, in 2026', () {
      // Born 1994: age 32 on 2026-10-02, 13 years to target 45.
      // PV ₹20L: required ₹61,518.02/month and coast ₹89,45,261.55 (the
      // frozen age gave ₹48,255.10 and ₹80,12,512.66).
      final result = service.calculate(
        settings: _settings(birthYear: 1994),
        currentPortfolioValue: 2000000,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );

      expect(result.requiredMonthlySavings, closeTo(61518.02, 0.005));
      expect(result.coastFireNumber, closeTo(8945261.55, 0.005));
    });
  });

  group('PLAN-06: the real multiple', () {
    test('₹1.83 Cr for ₹6L a year is 30.5× annual expenses', () {
      final result = service.calculate(
        settings: _settings(birthYear: 1996),
        currentPortfolioValue: 0,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );

      expect(result.fireNumber, closeTo(18300000.00, 0.005));
      expect(result.expenseMultiple, closeTo(30.5, 1e-9));
    });

    test('Fat and Lean FIRE are multiples of the expenses entered', () {
      // Fat: 150% of ₹6L a year → ₹2,74,50,000 = 45.75× (not 30.5×).
      // Lean: 70% → ₹1,28,10,000 = 21.35×.
      final fat = service.calculate(
        settings: _settings(birthYear: 1996, fireType: FireType.fat),
        currentPortfolioValue: 0,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );
      final lean = service.calculate(
        settings: _settings(birthYear: 1996, fireType: FireType.lean),
        currentPortfolioValue: 0,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );

      expect(fat.fireNumber, closeTo(27450000.00, 0.005));
      expect(fat.expenseMultiple, closeTo(45.75, 1e-9));
      expect(lean.fireNumber, closeTo(12810000.00, 0.005));
      expect(lean.expenseMultiple, closeTo(21.35, 1e-9));
    });

    test('passive income is shown as a deduction from the buffers', () {
      // ₹10,000 a month × 12 × 25 = ₹30,00,000 off ₹1.83 Cr.
      final result = service.calculate(
        settings: _settings(birthYear: 1996, monthlyPassiveIncome: 10000),
        currentPortfolioValue: 0,
        currentMonthlySavings: 0,
        asOf: _asOf,
      );

      expect(result.fireNumber, closeTo(15300000.00, 0.005));
      expect(result.otherIncomeDeduction, closeTo(3000000.00, 0.005));
      expect(
        result.coreRetirementCorpus +
            result.healthcareCorpusNeeded +
            result.emergencyFundNeeded -
            result.otherIncomeDeduction,
        closeTo(result.fireNumber, 0.005),
      );
    });
  });

  group('PLAN-02: savings that cannot be estimated yet', () {
    test('give no status or projection from an assumed ₹0 a month', () {
      // ₹10L invested 10 days ago: with ₹0 a month the projection was
      // Apr 2078 at age 82 and the status behind.
      final result = service.calculate(
        settings: _settings(birthYear: 1996),
        currentPortfolioValue: 1000000,
        currentMonthlySavings: 0,
        asOf: _asOf,
        inputs: const FireInputsSummary(
          investmentsValue: 1000000,
          principalWithoutValue: 0,
          otherAssets: 0,
          savingsSource: MonthlySavingsSource.notEnoughHistory,
        ),
      );

      expect(result.status.name, 'notEnoughHistory');
      expect(result.projectedFireDate, isNull);
      expect(result.projectedFireAge, isNull);
      // What is needed does not depend on the savings.
      expect(result.requiredMonthlySavings, closeTo(56511.29, 0.005));
    });

    test('a corpus already at the FIRE number is still achieved', () {
      final result = service.calculate(
        settings: _settings(birthYear: 1996),
        currentPortfolioValue: _fireNumber,
        currentMonthlySavings: 0,
        asOf: _asOf,
        inputs: const FireInputsSummary(
          investmentsValue: _fireNumber,
          principalWithoutValue: 0,
          otherAssets: 0,
          savingsSource: MonthlySavingsSource.notEnoughHistory,
        ),
      );

      expect(result.status, FireProgressStatus.achieved);
      expect(result.projectedFireDate, _asOf);
    });
  });
}
