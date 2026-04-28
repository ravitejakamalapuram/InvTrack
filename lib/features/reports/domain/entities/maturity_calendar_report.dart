/// Maturity Calendar Report Entity
///
/// Shows upcoming investment maturities in timeline view
library;

import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Represents a maturity calendar report showing upcoming investment maturities
class MaturityCalendarReport {
  /// Upcoming maturities within next 30 days
  final List<MaturityItem> upcoming30Days;

  /// Maturities in next 31-90 days
  final List<MaturityItem> next90Days;

  /// Maturities beyond 90 days
  final List<MaturityItem> beyond90Days;

  /// Total amount maturing in next 30 days
  final double totalUpcoming30Days;

  /// Total amount maturing in next 90 days
  final double totalNext90Days;

  /// Total investments with maturity dates
  final int totalInvestments;

  const MaturityCalendarReport({
    required this.upcoming30Days,
    required this.next90Days,
    required this.beyond90Days,
    required this.totalUpcoming30Days,
    required this.totalNext90Days,
    required this.totalInvestments,
  });
}

/// Represents a single maturity item
class MaturityItem {
  /// Investment entity
  final InvestmentEntity investment;

  /// Maturity date
  final DateTime maturityDate;

  /// Expected maturity amount
  final double maturityAmount;

  /// Days until maturity
  final int daysUntilMaturity;

  /// Maturity urgency level
  final MaturityUrgency urgency;

  const MaturityItem({
    required this.investment,
    required this.maturityDate,
    required this.maturityAmount,
    required this.daysUntilMaturity,
    required this.urgency,
  });
}

/// Maturity urgency levels
enum MaturityUrgency {
  /// Maturing within 7 days - requires immediate action
  critical,

  /// Maturing within 30 days - plan ahead
  warning,

  /// Maturing within 90 days - monitor
  normal,

  /// Maturing beyond 90 days - low priority
  low,
}
