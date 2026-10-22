import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_export_provider.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Drop-in "Export CSV" button for the Tax-Year report screen.
class FYExportCsvButton extends ConsumerStatefulWidget {
  const FYExportCsvButton({super.key, required this.fyYear});

  final int fyYear;

  @override
  ConsumerState<FYExportCsvButton> createState() => _FYExportCsvButtonState();
}

class _FYExportCsvButtonState extends ConsumerState<FYExportCsvButton> {
  bool _busy = false;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final report = await ref.read(fyReportProvider(widget.fyYear).future);
      await shareFYReportCsv(
        report,
        ref.read(currencyCodeProvider),
        subject: l10n.fyExportCsvSubject(report.fyLabel),
        maskSensitiveData: ref.read(privacyModeProvider),
      );
    } catch (e, st) {
      ErrorHandler.handle(e, st, showFeedback: false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.fyExportCsvFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _export,
      icon: const Icon(Icons.ios_share),
      label: Text(AppLocalizations.of(context).fyExportCsv),
    );
  }
}
