/// Exports the Tax-Year (FY) report as a CSV and shares it via the system
/// share sheet (same mechanism as the investments export).
library;

import 'dart:io';

import 'package:inv_tracker/features/reports/data/services/fy_report_csv_builder.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds and shares the CSV for [report]. Throws on failure.
///
/// A plain function (not a provider) so the file write and share run once,
/// outside Riverpod's auto-dispose and retry. [subject] is localised by the
/// caller; [maskSensitiveData] is the privacy-mode flag.
Future<void> shareFYReportCsv(
  FYReport report,
  String currency, {
  required String subject,
  required bool maskSensitiveData,
}) async {
  final csv = FYReportCsvBuilder.build(
    report,
    currency,
    maskSensitiveData: maskSensitiveData,
  );

  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/invtrack_fy_${report.fyLabel}_report.csv';
  await File(path).writeAsString(csv);

  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], subject: subject),
  );
}
