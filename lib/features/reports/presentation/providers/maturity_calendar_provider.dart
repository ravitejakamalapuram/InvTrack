/// Maturity Calendar Provider
///
/// Provides maturity calendar report data
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/reports/data/services/maturity_calendar_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/maturity_calendar_report.dart';

/// Provider for maturity calendar report
final maturityCalendarReportProvider =
    FutureProvider.autoDispose<MaturityCalendarReport>((ref) async {
  // Get all investments (already typed as List<InvestmentEntity>)
  final investmentsStream = ref.watch(activeInvestmentsProvider);

  // Get stats map for current values
  final statsMapAsync = ref.watch(activeInvestmentBasicStatsMapProvider);

  return investmentsStream.when(
    data: (investments) async {
      // Wait for stats map
      final statsMap = await statsMapAsync.when(
        data: (data) async => data,
        loading: () async => <String, InvestmentStats>{},
        error: (e, st) async => <String, InvestmentStats>{},
      );

      // Generate report
      final service = ref.read(maturityCalendarServiceProvider);
      return service.generateReport(
        investments: investments,
        statsMap: statsMap,
      );
    },
    loading: () {
      // While loading, return an empty report
      final service = ref.read(maturityCalendarServiceProvider);
      return service.generateReport(
        investments: [],
        statsMap: {},
      );
    },
    error: (e, st) => throw e,
  );
});
