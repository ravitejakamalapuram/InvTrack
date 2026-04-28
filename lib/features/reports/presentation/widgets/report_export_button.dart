/// Export button widget for reports
///
/// Provides a menu button with CSV and PDF export options
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:inv_tracker/features/reports/presentation/providers/report_export_providers.dart';

/// Export menu button for reports
class ReportExportButton extends ConsumerWidget {
  final dynamic reportData;
  final ReportType reportType;

  const ReportExportButton({
    super.key,
    required this.reportData,
    required this.reportType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportState = ref.watch(reportExportProvider);
    final isLoading = exportState.isLoading;

    return PopupMenuButton<ExportFormat>(
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded),
      tooltip: 'Export Report',
      enabled: !isLoading,
      onSelected: (format) => _handleExport(context, ref, format),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ExportFormat.csv,
          child: Row(
            children: [
              Icon(
                Icons.table_chart_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export as CSV'),
                  Text(
                    'For spreadsheet apps',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: ExportFormat.pdf,
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export as PDF'),
                  Text(
                    'For sharing & printing',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleExport(
    BuildContext context,
    WidgetRef ref,
    ExportFormat format,
  ) {
    final notifier = ref.read(reportExportProvider.notifier);

    switch (format) {
      case ExportFormat.csv:
        notifier.exportToCsv(
          context: context,
          reportData: reportData,
          reportType: reportType,
        );
        break;
      case ExportFormat.pdf:
        notifier.exportToPdf(
          context: context,
          reportData: reportData,
          reportType: reportType,
        );
        break;
    }
  }
}
