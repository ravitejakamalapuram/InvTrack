/// Exports the Tax-Year (FY) report as a CSV and shares it via the system
/// share sheet (same mechanism as the investments export).
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_csv_builder.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds and shares the CSV for [fyYear]. Throws on failure.
Future<void> exportFYReportCsv(Ref ref, int fyYear) async {
  final report = await ref.read(fyReportProvider(fyYear).future);
  final currency = ref.read(currencyCodeProvider);
  final csv = FYReportCsvBuilder.build(report, currency);

  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/invtrack_fy_${report.fyLabel}_report.csv';
  await File(path).writeAsString(csv);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path)],
      subject: 'InvTrack FY ${report.fyLabel} report',
    ),
  );
}

/// Call with `ref.read(fyReportExportProvider(fyYear).future)`.
final fyReportExportProvider = FutureProvider.autoDispose.family<void, int>(
  (ref, fyYear) => exportFYReportCsv(ref, fyYear),
);
