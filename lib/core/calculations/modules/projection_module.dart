import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/investment_projector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Module for handling investment projection and maturity calculations.
class ProjectionCalculatorModule implements CalculationModule {
  @override
  String get name => 'Projection';

  /// Calculate maturity value based on principal, rate, tenure, and compounding.
  double calculateMaturityValue({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    CompoundingFrequency? compounding,
  }) {
    return InvestmentProjector.calculateMaturityValue(
      principal: principal,
      annualRate: annualRate,
      tenureMonths: tenureMonths,
      compounding: compounding,
    );
  }

  /// Calculate total interest earned.
  double calculateInterestEarned({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    CompoundingFrequency? compounding,
  }) {
    return InvestmentProjector.calculateInterestEarned(
      principal: principal,
      annualRate: annualRate,
      tenureMonths: tenureMonths,
      compounding: compounding,
    );
  }

  /// Calculate effective annual rate (EAR) considering compounding.
  double calculateEffectiveAnnualRate({
    required double nominalRate,
    CompoundingFrequency? compounding,
  }) {
    return InvestmentProjector.calculateEffectiveAnnualRate(
      nominalRate: nominalRate,
      compounding: compounding,
    );
  }

  /// Calculate maturity date from start date and tenure.
  DateTime? calculateMaturityDate({
    required DateTime? startDate,
    required int? tenureMonths,
  }) {
    return InvestmentProjector.calculateMaturityDate(
      startDate: startDate,
      tenureMonths: tenureMonths,
    );
  }

  /// Get a human-readable projection summary.
  ProjectionSummary? getProjectionSummary({
    required double? principal,
    required double? annualRate,
    required int? tenureMonths,
    CompoundingFrequency? compounding,
  }) {
    return InvestmentProjector.getProjectionSummary(
      principal: principal,
      annualRate: annualRate,
      tenureMonths: tenureMonths,
      compounding: compounding,
    );
  }
}
