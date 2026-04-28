/// Providers for report export services
///
/// Provides access to CSV and PDF exporters with file sharing integration
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/reports/data/services/report_csv_exporter.dart';
import 'package:inv_tracker/features/reports/data/services/report_pdf_exporter.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

/// CSV exporter provider
final csvExporterProvider = Provider<ReportCsvExporter>((ref) {
  return ReportCsvExporter();
});

/// PDF exporter provider
final pdfExporterProvider = Provider<ReportPdfExporter>((ref) {
  return ReportPdfExporter();
});

/// Export state class
class ReportExportState {
  final bool isLoading;
  final String? error;

  const ReportExportState({
    this.isLoading = false,
    this.error,
  });

  ReportExportState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return ReportExportState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Export state notifier for managing export operations
class ReportExportNotifier extends Notifier<ReportExportState> {
  @override
  ReportExportState build() {
    return const ReportExportState();
  }

  /// Export report to CSV and share
  Future<void> exportToCsv({
    required BuildContext context,
    required dynamic reportData,
    required ReportType reportType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final symbol = ref.read(currencySymbolProvider);
      final locale = ref.read(currencyLocaleProvider);
      final exporter = ref.read(csvExporterProvider);

      final result = await exporter.export(
        reportData: reportData,
        reportType: reportType,
        currencySymbol: symbol,
        locale: locale,
      );

      // Share the file
      await _shareFile(result);

      state = state.copyWith(isLoading: false);

      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        AppFeedback.showSuccess(
          context,
          l10n.csvExportedSuccessfully(result.fileSizeKB.toString()),
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        AppFeedback.showError(context, l10n.failedToExportCsv(e.toString()));
      }
    }
  }

  /// Export report to PDF and share
  Future<void> exportToPdf({
    required BuildContext context,
    required dynamic reportData,
    required ReportType reportType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final symbol = ref.read(currencySymbolProvider);
      final locale = ref.read(currencyLocaleProvider);
      final exporter = ref.read(pdfExporterProvider);

      final result = await exporter.export(
        reportData: reportData,
        reportType: reportType,
        currencySymbol: symbol,
        locale: locale,
      );

      // Share the file
      await _shareFile(result);

      state = state.copyWith(isLoading: false);

      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        AppFeedback.showSuccess(
          context,
          l10n.pdfExportedSuccessfully(result.fileSizeKB.toString()),
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        AppFeedback.showError(context, l10n.failedToExportPdf(e.toString()));
      }
    }
  }

  /// Share exported file using share_plus
  Future<void> _shareFile(ExportResult result) async {
    final file = File(result.filePath);
    if (!await file.exists()) {
      throw Exception('Export file not found');
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.filePath, mimeType: result.format.mimeType)],
        subject: 'InvTrack ${result.reportType.displayName}',
        text: '${result.reportType.displayName} exported from InvTrack',
      ),
    );
  }
}

/// Provider for export state management
final reportExportProvider =
    NotifierProvider.autoDispose<ReportExportNotifier, ReportExportState>(
  ReportExportNotifier.new,
);
