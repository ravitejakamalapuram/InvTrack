// A16 (#761, CALC-08 / PLAN-15): the FD and RD projector follows Indian bank
// conventions. Expected values were computed independently in Python:
//   FD:  P * (1 + r/n)^k * (1 + r * remainingYears), k = full periods
//   RD:  sum over k = 0..n-1 of I * (1 + r/4)^((n - k) / 3)
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/investment_projector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Money to the paisa.
const _paisa = 0.005;

void main() {
  group('FD compounding when none is chosen', () {
    test('a Fixed Deposit compounds quarterly: Rs1L @7% for 5 years', () {
      // 100000 * 1.0175^20 = 1,41,477.82 (annual would give 1,40,255.17).
      final summary = InvestmentProjector.getProjectionSummary(
        principal: 100000,
        annualRate: 7,
        tenureMonths: 60,
        type: InvestmentType.fixedDeposit,
      );

      expect(summary, isNotNull);
      expect(summary!.maturityValue, closeTo(141477.82, _paisa));
      expect(summary.interestEarned, closeTo(41477.82, _paisa));
      expect(summary.compounding, CompoundingFrequency.quarterly);
      // EAR = 1.0175^4 - 1 = 7.185903%.
      expect(summary.effectiveRate, closeTo(7.185903, 1e-6));
    });

    test('a frequency the user chose is kept', () {
      expect(
        InvestmentProjector.resolveCompounding(
          chosen: CompoundingFrequency.monthly,
          type: InvestmentType.fixedDeposit,
        ),
        CompoundingFrequency.monthly,
      );
      expect(
        InvestmentProjector.resolveCompounding(
          chosen: CompoundingFrequency.none,
          type: InvestmentType.fixedDeposit,
        ),
        CompoundingFrequency.none,
      );
    });

    test('other types keep no assumed frequency', () {
      expect(
        InvestmentProjector.resolveCompounding(
          chosen: null,
          type: InvestmentType.bonds,
        ),
        isNull,
      );
    });
  });

  group('Recurring Deposit', () {
    test('Rs1L over 12 months @6.5% quarterly earns Rs3,572.05', () {
      // 12 monthly installments of 8,333.33; the app used to compound the
      // whole lakh for a year and show 6,660.16.
      final maturity = InvestmentProjector.calculateRecurringDepositMaturity(
        installment: 100000 / 12,
        annualRate: 6.5,
        months: 12,
        compounding: CompoundingFrequency.quarterly,
      );
      expect(maturity, closeTo(103572.05, _paisa));

      final summary = InvestmentProjector.getProjectionSummary(
        principal: 100000,
        annualRate: 6.5,
        tenureMonths: 12,
        compounding: CompoundingFrequency.quarterly,
        recurring: true,
      );
      expect(summary, isNotNull);
      expect(summary!.principal, 100000);
      expect(summary.maturityValue, closeTo(103572.05, _paisa));
      expect(summary.interestEarned, closeTo(3572.05, _paisa));
    });

    test('an RD with no frequency chosen compounds quarterly', () {
      final summary = InvestmentProjector.getProjectionSummary(
        principal: 100000,
        annualRate: 6.5,
        tenureMonths: 12,
        type: InvestmentType.fixedDeposit,
        recurring: true,
      );
      expect(summary!.interestEarned, closeTo(3572.05, _paisa));
    });
  });

  group('Full periods compound, the rest earns simple interest', () {
    test('13 months @7% quarterly: 4 quarters, then 1 month simple', () {
      // 100000 * 1.0175^4 * (1 + 0.07 / 12) = 1,07,811.15
      // (a fractional 4.33 quarters would give 1,07,807.54).
      final result = InvestmentProjector.calculateMaturityValue(
        principal: 100000,
        annualRate: 7,
        tenureMonths: 13,
        compounding: CompoundingFrequency.quarterly,
      );
      expect(result, closeTo(107811.15, _paisa));
    });

    test('whole periods are unchanged: 12 months @7% quarterly', () {
      final result = InvestmentProjector.calculateMaturityValue(
        principal: 100000,
        annualRate: 7,
        tenureMonths: 12,
        compounding: CompoundingFrequency.quarterly,
      );
      expect(result, closeTo(107185.90, _paisa));
    });
  });

  group('Tenure in days', () {
    test('444 days @7% quarterly: 4 quarters, then 79 days simple', () {
      // 100000 * 1.0175^4 * (1 + 0.07 * 79 / 365) = 1,08,809.84
      final result = InvestmentProjector.calculateMaturityValue(
        principal: 100000,
        annualRate: 7,
        tenureDays: 444,
        compounding: CompoundingFrequency.quarterly,
      );
      expect(result, closeTo(108809.84, _paisa));

      final summary = InvestmentProjector.getProjectionSummary(
        principal: 100000,
        annualRate: 7,
        tenureMonths: null,
        tenureDays: 444,
        type: InvestmentType.fixedDeposit,
      );
      expect(summary, isNotNull);
      expect(summary!.maturityValue, closeTo(108809.84, _paisa));
      expect(summary.tenureDays, 444);
      expect(summary.tenureYears, closeTo(444 / 365, 1e-9));
    });

    test('444 days of simple interest @7% is Rs8,515.07', () {
      // 100000 * 0.07 * 444 / 365 = 8,515.07
      final result = InvestmentProjector.calculateMaturityValue(
        principal: 100000,
        annualRate: 7,
        tenureDays: 444,
        compounding: CompoundingFrequency.none,
      );
      expect(result, closeTo(108515.07, _paisa));
    });

    test('days between start and maturity count calendar dates only', () {
      // 1 Jan 2025 + 444 days = 21 Mar 2026.
      expect(
        InvestmentProjector.tenureDaysBetween(
          DateTime(2025, 1, 1, 23, 30),
          DateTime(2026, 3, 21, 0, 15),
        ),
        444,
      );
      expect(
        InvestmentProjector.tenureDaysBetween(
          DateTime.utc(2025, 1, 1),
          DateTime(2026, 3, 21),
        ),
        444,
      );
      expect(InvestmentProjector.tenureDaysBetween(null, DateTime(2026)), null);
      expect(
        InvestmentProjector.tenureDaysBetween(
          DateTime(2026, 3, 21),
          DateTime(2025, 1, 1),
        ),
        isNull,
      );
    });
  });

  group('Month-end maturity dates are clamped', () {
    InvestmentEntity fd(DateTime start, int months) => InvestmentEntity(
      id: 'fd',
      name: 'FD',
      type: InvestmentType.fixedDeposit,
      status: InvestmentStatus.open,
      createdAt: start,
      updatedAt: start,
      startDate: start,
      tenureMonths: months,
      currency: 'INR',
    );

    test('Jan 31 + 1 month is the last day of February', () {
      expect(
        fd(DateTime(2024, 1, 31), 1).calculatedMaturityDate,
        DateTime(2024, 2, 29),
      );
      expect(
        fd(DateTime(2025, 1, 31), 1).calculatedMaturityDate,
        DateTime(2025, 2, 28),
      );
    });

    test('31 Aug 2025 + 6 months is 28 Feb 2026, not 3 Mar 2026', () {
      expect(
        fd(DateTime(2025, 8, 31), 6).calculatedMaturityDate,
        DateTime(2026, 2, 28),
      );
    });

    test('a maturity date the user set wins', () {
      final withDate = InvestmentEntity(
        id: 'fd',
        name: 'FD',
        type: InvestmentType.fixedDeposit,
        status: InvestmentStatus.open,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        startDate: DateTime(2025, 1, 1),
        tenureMonths: 12,
        maturityDate: DateTime(2026, 3, 21),
        currency: 'INR',
      );
      expect(withDate.calculatedMaturityDate, DateTime(2026, 3, 21));
    });
  });
}
