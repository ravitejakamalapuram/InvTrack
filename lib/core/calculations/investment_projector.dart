import 'dart:math' as math;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Utility class for projecting investment returns based on user inputs.
/// Used for live projections in the Add Investment form and the detail
/// screen.
///
/// It follows Indian bank conventions: a Fixed Deposit compounds quarterly
/// unless another frequency is chosen, only full periods compound and the
/// remainder earns simple interest, and a Recurring Deposit grows each
/// installment for the months it is held.
class InvestmentProjector {
  /// Maturity value of a lump sum.
  ///
  /// The tenure is [tenureMonths] or, when that is not given, [tenureDays]
  /// (actual/365). Full compounding periods compound and the rest of the
  /// tenure earns simple interest, as banks pay it:
  ///
  /// A = P * (1 + r/n)^k * (1 + r * remainingYears)
  ///
  /// where k is the number of full periods. 13 months at quarterly
  /// compounding is 4 quarters plus 1 month of simple interest; 444 days is
  /// 4 quarters plus 79 days. [CompoundingFrequency.none] is simple interest
  /// and a null [compounding] is annual (see [resolveCompounding]).
  static double calculateMaturityValue({
    required double principal,
    required double annualRate,
    int? tenureMonths,
    int? tenureDays,
    CompoundingFrequency? compounding,
  }) {
    final tenure = _Tenure.of(months: tenureMonths, days: tenureDays);
    if (tenure == null || principal <= 0 || annualRate <= 0) {
      return principal;
    }

    final rate = annualRate / 100; // Convert percentage to decimal
    final periodsPerYear = compounding?.periodsPerYear ?? 1;

    if (periodsPerYear == 0) {
      // Simple interest: A = P * (1 + r*t)
      return principal * (1 + rate * tenure.years);
    }

    // Count full periods in whole tenure units so that 12 months is exactly
    // 4 quarters, without floating-point rounding.
    final scaled = tenure.units * periodsPerYear;
    final fullPeriods = scaled ~/ tenure.unitsPerYear;
    final remainingYears =
        (scaled - fullPeriods * tenure.unitsPerYear) /
        (tenure.unitsPerYear * periodsPerYear);

    return principal *
        math.pow(1 + rate / periodsPerYear, fullPeriods) *
        (1 + rate * remainingYears);
  }

  /// The compounding to project with: the one the user chose, else
  /// quarterly for a Fixed Deposit (the RBI and bank convention), else null.
  static CompoundingFrequency? resolveCompounding({
    required CompoundingFrequency? chosen,
    InvestmentType? type,
  }) {
    if (chosen != null) return chosen;
    return type == InvestmentType.fixedDeposit
        ? CompoundingFrequency.quarterly
        : null;
  }

  /// Maturity value of a Recurring Deposit of [months] monthly installments
  /// of [installment], the first paid at the start:
  ///
  /// M = sum over k = 0..months-1 of I * (1 + r/n)^(n * (months - k) / 12)
  ///
  /// which for quarterly compounding is the banks' I * (1 + r/4)^((n-k)/3).
  /// A null [compounding] is quarterly; [CompoundingFrequency.none] is
  /// simple interest on each installment.
  static double calculateRecurringDepositMaturity({
    required double installment,
    required double annualRate,
    required int months,
    CompoundingFrequency? compounding,
  }) {
    if (months <= 0 || installment <= 0) return 0;
    final deposited = installment * months;
    if (annualRate <= 0) return deposited;

    final rate = annualRate / 100;
    final periodsPerYear =
        (compounding ?? CompoundingFrequency.quarterly).periodsPerYear;

    var maturity = 0.0;
    for (var k = 0; k < months; k++) {
      final monthsHeld = months - k;
      maturity += periodsPerYear == 0
          ? installment * (1 + rate * monthsHeld / 12)
          : installment *
                math.pow(
                  1 + rate / periodsPerYear,
                  periodsPerYear * monthsHeld / 12,
                );
    }
    return maturity;
  }

  /// Whole calendar days from [start] to [end], ignoring the time of day and
  /// daylight-saving changes. Null when either is missing or [end] is not
  /// after [start].
  static int? tenureDaysBetween(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    return days > 0 ? days : null;
  }

  /// Calculate total interest earned
  static double calculateInterestEarned({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    CompoundingFrequency? compounding,
  }) {
    final maturityValue = calculateMaturityValue(
      principal: principal,
      annualRate: annualRate,
      tenureMonths: tenureMonths,
      compounding: compounding,
    );
    return maturityValue - principal;
  }

  /// Calculate effective annual rate (EAR) considering compounding
  /// EAR = (1 + r/n)^n - 1
  static double calculateEffectiveAnnualRate({
    required double nominalRate,
    CompoundingFrequency? compounding,
  }) {
    if (nominalRate <= 0) return 0;

    final rate = nominalRate / 100;
    final periodsPerYear = compounding?.periodsPerYear ?? 1;

    if (periodsPerYear == 0) {
      // Simple interest - EAR equals nominal rate
      return nominalRate;
    }

    final ear = math.pow(1 + rate / periodsPerYear, periodsPerYear) - 1;
    return ear * 100; // Convert back to percentage
  }

  /// Calculate maturity date from start date and tenure
  static DateTime? calculateMaturityDate({
    required DateTime? startDate,
    required int? tenureMonths,
  }) {
    if (startDate == null || tenureMonths == null || tenureMonths <= 0) {
      return null;
    }

    // Add months to start date
    var year = startDate.year;
    var month = startDate.month + tenureMonths;

    // Handle year overflow
    while (month > 12) {
      month -= 12;
      year += 1;
    }

    // Handle day overflow (e.g., Jan 31 + 1 month = Feb 28/29)
    var day = startDate.day;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInMonth) {
      day = daysInMonth;
    }

    return DateTime(year, month, day);
  }

  /// Get a human-readable projection summary.
  ///
  /// The tenure is [tenureMonths] or, when that is not given, [tenureDays].
  /// A null [compounding] is resolved with [resolveCompounding] for [type].
  /// When [recurring] is true, [principal] is the total of equal monthly
  /// installments over [tenureMonths] (a Recurring Deposit).
  static ProjectionSummary? getProjectionSummary({
    required double? principal,
    required double? annualRate,
    required int? tenureMonths,
    int? tenureDays,
    CompoundingFrequency? compounding,
    InvestmentType? type,
    bool recurring = false,
  }) {
    final tenure = _Tenure.of(months: tenureMonths, days: tenureDays);
    if (principal == null ||
        annualRate == null ||
        tenure == null ||
        principal <= 0 ||
        annualRate <= 0) {
      return null;
    }
    final months = tenure.unitsPerYear == 12 ? tenure.units : null;
    // An RD is a monthly schedule: it needs a tenure in months.
    if (recurring && months == null) return null;

    final resolved = recurring
        ? (compounding ?? CompoundingFrequency.quarterly)
        : resolveCompounding(chosen: compounding, type: type);

    final maturityValue = recurring
        ? calculateRecurringDepositMaturity(
            installment: principal / months!,
            annualRate: annualRate,
            months: months,
            compounding: resolved,
          )
        : calculateMaturityValue(
            principal: principal,
            annualRate: annualRate,
            tenureMonths: months,
            tenureDays: months == null ? tenure.units : null,
            compounding: resolved,
          );

    final interestEarned = maturityValue - principal;
    final effectiveRate = calculateEffectiveAnnualRate(
      nominalRate: annualRate,
      compounding: resolved,
    );

    return ProjectionSummary(
      principal: principal,
      maturityValue: maturityValue,
      interestEarned: interestEarned,
      nominalRate: annualRate,
      effectiveRate: effectiveRate,
      tenureMonths: months,
      tenureDays: months == null ? tenure.units : null,
      compounding: resolved,
    );
  }
}

/// A tenure in whole months (12 a year) or whole days (365 a year).
class _Tenure {
  const _Tenure(this.units, this.unitsPerYear);

  final int units;
  final int unitsPerYear;

  /// [months] when positive, else [days] when positive, else null.
  static _Tenure? of({int? months, int? days}) {
    if (months != null && months > 0) return _Tenure(months, 12);
    if (days != null && days > 0) return _Tenure(days, 365);
    return null;
  }

  double get years => units / unitsPerYear;
}

/// Summary of investment projection
class ProjectionSummary {
  final double principal;
  final double maturityValue;
  final double interestEarned;
  final double nominalRate;
  final double effectiveRate;

  /// Tenure in months, or null when it is given in [tenureDays].
  final int? tenureMonths;

  /// Tenure in days when it is not given in months.
  final int? tenureDays;
  final CompoundingFrequency? compounding;

  const ProjectionSummary({
    required this.principal,
    required this.maturityValue,
    required this.interestEarned,
    required this.nominalRate,
    required this.effectiveRate,
    required this.tenureMonths,
    this.tenureDays,
    this.compounding,
  });

  /// Returns true if effective rate differs significantly from nominal rate
  bool get hasCompoundingBenefit => (effectiveRate - nominalRate).abs() > 0.01;

  /// Tenure in years (for display)
  double get tenureYears =>
      tenureMonths != null ? tenureMonths! / 12 : (tenureDays ?? 0) / 365;
}
