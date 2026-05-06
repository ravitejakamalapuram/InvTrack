/// Provider for dynamic report building
///
/// This is the central provider that takes a ReportConfiguration and
/// produces a DynamicReportData by calling the ReportBuilderService.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/dynamic_report_data.dart';
import 'package:inv_tracker/features/reports/data/services/report_builder_service.dart';

/// Provider for building dynamic reports
/// 
/// Usage:
/// ```dart
/// final config = ReportConfiguration.weeklySummary();
/// final reportAsync = ref.watch(dynamicReportProvider(config));
/// ```
final dynamicReportProvider = FutureProvider.autoDispose.family<
    DynamicReportData,
    ReportConfiguration
>((ref, config) async {
  final service = ref.watch(reportBuilderServiceProvider);
  
  // Build the report using the service
  // The service reads from other providers and aggregates data
  return service.buildReport(config, ref.container);
});

/// Provider for checking if a report has loaded successfully
final reportLoadedProvider = Provider.autoDispose.family<bool, ReportConfiguration>((
  ref,
  config,
) {
  final reportAsync = ref.watch(dynamicReportProvider(config));
  return reportAsync.hasValue && reportAsync.value?.hasData == true;
});

/// Provider for getting report error message
final reportErrorProvider = Provider.autoDispose.family<String?, ReportConfiguration>((
  ref,
  config,
) {
  final reportAsync = ref.watch(dynamicReportProvider(config));
  return reportAsync.when(
    data: (data) => data.hasData ? null : data.emptyStateMessage,
    loading: () => null,
    error: (e, st) => e.toString(),
  );
});
