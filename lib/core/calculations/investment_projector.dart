import 'dart:math' as math;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Utility class for projecting investment returns based on user inputs.
/// Used for live projections in the Add Investment form.
class InvestmentProjector {
  /// Calculate maturity value based on principal, rate, tenure, and compounding.
  ///
  /// Formula: A = P * (1 + r/n)^(n*t)
  /// Where:
  /// - P = Principal amount
  /// - r = Annual interest rate (as decimal)
  /// - n = Number of times interest is compounded per year
  /// - t = Time in years
  static double calculateMaturityValue({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    CompoundingFrequency? compounding,
  }) {
    if (principal <= 0 || annualRate <= 0 || tenureMonths <= 0) {
      return principal;
    }

    final rate = annualRate / 100; // Convert percentage to decimal
    final years = tenureMonths / 12;
    final periodsPerYear = compounding?.periodsPerYear ?? 1;

    if (periodsPerYear == 0) {
      // Simple interest: A = P * (1 + r*t)
      return principal * (1 + rate * years);
    }

    // Compound interest: A = P * (1 + r/n)^(n*t)
    final compoundFactor = math.pow(
      1 + rate / periodsPerYear,
      periodsPerYear * years,
    );
    return principal * compoundFactor;
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

  /// Get a human-readable projection summary
  static ProjectionSummary? getProjectionSummary({
    required double? principal,
    required double? annualRate,
    required int? tenureMonths,
    CompoundingFrequency? compounding,
  }) {
    if (principal == null ||
        annualRate == null ||
        tenureMonths == null ||
        principal <= 0 ||
        annualRate <= 0 ||
        tenureMonths <= 0) {
      return null;
    }

    final maturityValue = calculateMaturityValue(
      principal: principal,
      annualRate: annualRate,
      tenureMonths: tenureMonths,
      compounding: compounding,
    );

    final interestEarned = maturityValue - principal;
    final effectiveRate = calculateEffectiveAnnualRate(
      nominalRate: annualRate,
      compounding: compounding,
    );

    return ProjectionSummary(
      principal: principal,
      maturityValue: maturityValue,
      interestEarned: interestEarned,
      nominalRate: annualRate,
      effectiveRate: effectiveRate,
      tenureMonths: tenureMonths,
      compounding: compounding,
    );
  }
}

/// Summary of investment projection
class ProjectionSummary {
  final double principal;
  final double maturityValue;
  final double interestEarned;
  final double nominalRate;
  final double effectiveRate;
  final int tenureMonths;
  final CompoundingFrequency? compounding;

  const ProjectionSummary({
    required this.principal,
    required this.maturityValue,
    required this.interestEarned,
    required this.nominalRate,
    required this.effectiveRate,
    required this.tenureMonths,
    this.compounding,
  });

  /// Returns true if effective rate differs significantly from nominal rate
  bool get hasCompoundingBenefit => (effectiveRate - nominalRate).abs() > 0.01;

  /// Tenure in years (for display)
  double get tenureYears => tenureMonths / 12;
}
