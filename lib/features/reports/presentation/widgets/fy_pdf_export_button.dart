import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_pdf_service.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// "Export PDF" action for the Tax-Year report of [fyYear].
class FyPdfExportButton extends ConsumerStatefulWidget {
  final int fyYear;

  const FyPdfExportButton({super.key, required this.fyYear});

  @override
  ConsumerState<FyPdfExportButton> createState() => _FyPdfExportButtonState();
}

class _FyPdfExportButtonState extends ConsumerState<FyPdfExportButton> {
  bool _busy = false;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final report = await ref.read(fyReportProvider(widget.fyYear).future);
      await const FyReportPdfService().share(
        report: report,
        l10n: l10n,
        baseCurrency: ref.read(currencyCodeProvider),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.fyPdfExportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _export,
      icon: const Icon(Icons.picture_as_pdf_outlined),
      label: Text(AppLocalizations.of(context).fyPdfExport),
    );
  }
}
