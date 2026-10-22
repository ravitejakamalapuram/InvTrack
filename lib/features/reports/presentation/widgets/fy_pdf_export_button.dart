import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
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
    // Everything that needs context or ref is read before the first await:
    // the user may leave the screen while the PDF is built.
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final baseCurrency = ref.read(currencyCodeProvider);
    final reportFuture = ref.read(fyReportProvider(widget.fyYear).future);
    setState(() => _busy = true);
    try {
      final report = await reportFuture;
      await const FyReportPdfService().share(
        report: report,
        l10n: l10n,
        baseCurrency: baseCurrency,
      );
    } catch (e, st) {
      ErrorHandler.handle(e, st, showFeedback: false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.fyPdfExportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _export,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(AppLocalizations.of(context).fyPdfExport),
    );
  }
}
