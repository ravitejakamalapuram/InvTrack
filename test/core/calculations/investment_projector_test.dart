import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/investment_projector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

void main() {
  group('InvestmentProjector', () {
    group('calculateMaturityValue', () {
      test('should return principal when inputs are invalid', () {
        expect(
          InvestmentProjector.calculateMaturityValue(
            principal: 100000,
            annualRate: 0,
            tenureMonths: 12,
          ),
          100000,
        );
        expect(
          InvestmentProjector.calculateMaturityValue(
            principal: 100000,
            annualRate: 7,
            tenureMonths: 0,
          ),
          100000,
        );
        expect(
          InvestmentProjector.calculateMaturityValue(
            principal: 0,
            annualRate: 7,
            tenureMonths: 12,
          ),
          0,
        );
      });

      test('should calculate simple interest when compounding is none', () {
        // P = 100000, r = 7%, t = 1 year
        // A = P * (1 + r*t) = 100000 * (1 + 0.07*1) = 107000
        final result = InvestmentProjector.calculateMaturityValue(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 12,
          compounding: CompoundingFrequency.none,
        );
        expect(result, closeTo(107000, 0.01));
      });

      test('should calculate quarterly compounding correctly', () {
        // P = 100000, r = 7%, n = 4, t = 1 year
        // A = P * (1 + r/n)^(n*t) = 100000 * (1 + 0.07/4)^4 = 107185.90
        final result = InvestmentProjector.calculateMaturityValue(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 12,
          compounding: CompoundingFrequency.quarterly,
        );
        expect(result, closeTo(107185.90, 0.01));
      });

      test('should calculate monthly compounding correctly', () {
        // P = 100000, r = 7%, n = 12, t = 1 year
        // A = P * (1 + r/n)^(n*t) = 100000 * (1 + 0.07/12)^12 = 107229.01
        final result = InvestmentProjector.calculateMaturityValue(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 12,
          compounding: CompoundingFrequency.monthly,
        );
        expect(result, closeTo(107229.01, 0.01));
      });

      test('should calculate annual compounding correctly', () {
        // P = 100000, r = 7%, n = 1, t = 2 years
        // A = P * (1 + r/n)^(n*t) = 100000 * (1.07)^2 = 114490
        final result = InvestmentProjector.calculateMaturityValue(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 24,
          compounding: CompoundingFrequency.annual,
        );
        expect(result, closeTo(114490, 0.01));
      });

      test('should handle fractional tenure months', () {
        // 6 months = 0.5 years
        final result = InvestmentProjector.calculateMaturityValue(
          principal: 100000,
          annualRate: 8,
          tenureMonths: 6,
          compounding: CompoundingFrequency.quarterly,
        );
        // A = 100000 * (1 + 0.08/4)^(4*0.5) = 100000 * (1.02)^2 = 104040
        expect(result, closeTo(104040, 1));
      });
    });

    group('calculateInterestEarned', () {
      test('should calculate interest as maturity minus principal', () {
        final interest = InvestmentProjector.calculateInterestEarned(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 12,
          compounding: CompoundingFrequency.quarterly,
        );
        // Maturity = 107185.90, Interest = 7185.90
        expect(interest, closeTo(7185.90, 0.01));
      });
    });

    group('calculateEffectiveAnnualRate', () {
      test('should return 0 for zero or negative rate', () {
        expect(
          InvestmentProjector.calculateEffectiveAnnualRate(nominalRate: 0),
          0,
        );
        expect(
          InvestmentProjector.calculateEffectiveAnnualRate(nominalRate: -5),
          0,
        );
      });

      test('should return nominal rate for simple interest', () {
        final ear = InvestmentProjector.calculateEffectiveAnnualRate(
          nominalRate: 7,
          compounding: CompoundingFrequency.none,
        );
        expect(ear, 7);
      });

      test('should calculate EAR for quarterly compounding', () {
        // EAR = (1 + 0.07/4)^4 - 1 = 7.1859%
        final ear = InvestmentProjector.calculateEffectiveAnnualRate(
          nominalRate: 7,
          compounding: CompoundingFrequency.quarterly,
        );
        expect(ear, closeTo(7.1859, 0.001));
      });

      test('should calculate EAR for monthly compounding', () {
        // EAR = (1 + 0.07/12)^12 - 1 = 7.229%
        final ear = InvestmentProjector.calculateEffectiveAnnualRate(
          nominalRate: 7,
          compounding: CompoundingFrequency.monthly,
        );
        expect(ear, closeTo(7.229, 0.001));
      });
    });

    group('calculateMaturityDate', () {
      test('should return null for null inputs', () {
        expect(
          InvestmentProjector.calculateMaturityDate(
            startDate: null,
            tenureMonths: 12,
          ),
          isNull,
        );
        expect(
          InvestmentProjector.calculateMaturityDate(
            startDate: DateTime(2024, 1, 15),
            tenureMonths: null,
          ),
          isNull,
        );
      });

      test('should return null for zero or negative tenure', () {
        expect(
          InvestmentProjector.calculateMaturityDate(
            startDate: DateTime(2024, 1, 15),
            tenureMonths: 0,
          ),
          isNull,
        );
        expect(
          InvestmentProjector.calculateMaturityDate(
            startDate: DateTime(2024, 1, 15),
            tenureMonths: -5,
          ),
          isNull,
        );
      });

      test('should add months correctly', () {
        final result = InvestmentProjector.calculateMaturityDate(
          startDate: DateTime(2024, 1, 15),
          tenureMonths: 12,
        );
        expect(result, DateTime(2025, 1, 15));
      });

      test('should handle year overflow', () {
        final result = InvestmentProjector.calculateMaturityDate(
          startDate: DateTime(2024, 6, 15),
          tenureMonths: 18,
        );
        expect(result, DateTime(2025, 12, 15));
      });

      test('should handle day overflow for short months', () {
        // Jan 31 + 1 month = Feb 28/29
        final result = InvestmentProjector.calculateMaturityDate(
          startDate: DateTime(2024, 1, 31),
          tenureMonths: 1,
        );
        // 2024 is a leap year, so Feb has 29 days
        expect(result, DateTime(2024, 2, 29));
      });

      test('should handle day overflow for non-leap year', () {
        // Jan 31 + 1 month in non-leap year = Feb 28
        final result = InvestmentProjector.calculateMaturityDate(
          startDate: DateTime(2023, 1, 31),
          tenureMonths: 1,
        );
        expect(result, DateTime(2023, 2, 28));
      });
    });

    group('getProjectionSummary', () {
      test('should return null for invalid inputs', () {
        expect(
          InvestmentProjector.getProjectionSummary(
            principal: null,
            annualRate: 7,
            tenureMonths: 12,
          ),
          isNull,
        );
        expect(
          InvestmentProjector.getProjectionSummary(
            principal: 100000,
            annualRate: null,
            tenureMonths: 12,
          ),
          isNull,
        );
        expect(
          InvestmentProjector.getProjectionSummary(
            principal: 100000,
            annualRate: 7,
            tenureMonths: null,
          ),
          isNull,
        );
        expect(
          InvestmentProjector.getProjectionSummary(
            principal: 0,
            annualRate: 7,
            tenureMonths: 12,
          ),
          isNull,
        );
      });

      test('should return complete projection summary', () {
        final summary = InvestmentProjector.getProjectionSummary(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 12,
          compounding: CompoundingFrequency.quarterly,
        );

        expect(summary, isNotNull);
        expect(summary!.principal, 100000);
        expect(summary.nominalRate, 7);
        expect(summary.tenureMonths, 12);
        expect(summary.maturityValue, closeTo(107185.90, 0.01));
        expect(summary.interestEarned, closeTo(7185.90, 0.01));
        expect(summary.effectiveRate, closeTo(7.1859, 0.001));
        expect(summary.compounding, CompoundingFrequency.quarterly);
      });

      test('hasCompoundingBenefit should be true when EAR differs', () {
        final summary = InvestmentProjector.getProjectionSummary(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 12,
          compounding: CompoundingFrequency.monthly,
        );
        expect(summary!.hasCompoundingBenefit, isTrue);
      });

      test('hasCompoundingBenefit should be false for simple interest', () {
        final summary = InvestmentProjector.getProjectionSummary(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 12,
          compounding: CompoundingFrequency.none,
        );
        expect(summary!.hasCompoundingBenefit, isFalse);
      });

      test('tenureYears should convert months to years', () {
        final summary = InvestmentProjector.getProjectionSummary(
          principal: 100000,
          annualRate: 7,
          tenureMonths: 18,
        );
        expect(summary!.tenureYears, 1.5);
      });
    });
  });
}

