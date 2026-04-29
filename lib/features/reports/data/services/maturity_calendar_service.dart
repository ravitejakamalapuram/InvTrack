/// Maturity Calendar Service
///
/// Handles generation of maturity calendar reports
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/reports/domain/entities/maturity_calendar_report.dart';

/// Provider for maturity calendar service
final maturityCalendarServiceProvider = Provider<MaturityCalendarService>((ref) {
  return MaturityCalendarService();
});

/// Service for generating maturity calendar reports
class MaturityCalendarService {
  /// Generate maturity calendar report from all investments
  MaturityCalendarReport generateReport({
    required List<InvestmentEntity> investments,
    required Map<String, InvestmentStats> statsMap,
  }) {
    final now = DateTime.now();
    final upcoming30Days = <MaturityItem>[];
    final next90Days = <MaturityItem>[];
    final beyond90Days = <MaturityItem>[];

    double totalUpcoming30 = 0;
    double totalNext90 = 0;

    // Filter investments with maturity dates
    final investmentsWithMaturity = investments
        .where((inv) => inv.maturityDate != null)
        .toList();

    for (final investment in investmentsWithMaturity) {
      final maturityDate = investment.maturityDate!;
      final daysUntilMaturity = maturityDate.difference(now).inDays;

      // Skip already matured investments
      if (daysUntilMaturity < 0) continue;

      // Get invested amount from stats (what will mature)
      // For maturity purposes, we use totalInvested as the maturity value
      final stats = statsMap[investment.id];
      final maturityAmount = stats?.totalInvested ?? 0.0;

      final maturityItem = MaturityItem(
        investment: investment,
        maturityDate: maturityDate,
        maturityAmount: maturityAmount,
        daysUntilMaturity: daysUntilMaturity,
        urgency: _determineUrgency(daysUntilMaturity),
      );

      if (daysUntilMaturity <= 30) {
        upcoming30Days.add(maturityItem);
        totalUpcoming30 += maturityAmount;
        totalNext90 += maturityAmount;
      } else if (daysUntilMaturity <= 90) {
        next90Days.add(maturityItem);
        totalNext90 += maturityAmount;
      } else {
        beyond90Days.add(maturityItem);
      }
    }

    // Sort by maturity date (earliest first)
    upcoming30Days.sort((a, b) => a.maturityDate.compareTo(b.maturityDate));
    next90Days.sort((a, b) => a.maturityDate.compareTo(b.maturityDate));
    beyond90Days.sort((a, b) => a.maturityDate.compareTo(b.maturityDate));

    return MaturityCalendarReport(
      upcoming30Days: upcoming30Days,
      next90Days: next90Days,
      beyond90Days: beyond90Days,
      totalUpcoming30Days: totalUpcoming30,
      totalNext90Days: totalNext90,
      totalInvestments: investmentsWithMaturity.length,
    );
  }

  /// Determine urgency level based on days until maturity
  MaturityUrgency _determineUrgency(int daysUntilMaturity) {
    if (daysUntilMaturity <= 7) {
      return MaturityUrgency.critical;
    } else if (daysUntilMaturity <= 30) {
      return MaturityUrgency.warning;
    } else if (daysUntilMaturity <= 90) {
      return MaturityUrgency.normal;
    } else {
      return MaturityUrgency.low;
    }
  }
}
