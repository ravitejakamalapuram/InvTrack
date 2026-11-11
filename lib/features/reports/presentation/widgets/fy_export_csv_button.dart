import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_export_provider.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_pdf_export_button.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/support_ad_offer.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Signature of [shareFYReportCsv]; injectable for tests.
typedef FYCsvSharer =
    Future<void> Function(
      FYReport report,
      String currency, {
      required String subject,
      required bool maskSensitiveData,
    });

/// Drop-in "Export CSV" button for the Tax-Year report screen.
class FYExportCsvButton extends ConsumerStatefulWidget {
  const FYExportCsvButton({
    super.key,
    required this.fyYear,
    @visibleForTesting this.share = shareFYReportCsv,
    this.style = FyExportStyle.text,
  });

  final int fyYear;
  final FYCsvSharer share;
  final FyExportStyle style;

  @override
  ConsumerState<FYExportCsvButton> createState() => _FYExportCsvButtonState();
}

class _FYExportCsvButtonState extends ConsumerState<FYExportCsvButton> {
  bool _busy = false;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Busy first, so a second tap cannot start a second export.
    setState(() => _busy = true);
    // One snapshot, taken before the async load, so the CSV currency matches
    // the report even if the base currency changes meanwhile.
    final currency = ref.read(currencyCodeProvider);
    // The report provider is autoDispose; hold a listener so it is not
    // disposed while the load or the share sheet is still in flight.
    final keepAlive = ref.listenManual(
      fyReportProvider(widget.fyYear),
      (_, _) {},
    );
    try {
      final report = await ref.read(fyReportProvider(widget.fyYear).future);
      if (!mounted) return;
      await widget.share(
        report,
        currency,
        subject: l10n.fyExportCsvSubject(report.fyLabel),
        maskSensitiveData: ref.read(privacyModeProvider),
      );
      // The export is the user's own data, so the optional ad (see
      // ExportAdGate) only comes after it, and never blocks it.
      if (mounted) await offerSupportAd(context, ref);
    } catch (e, st) {
      ErrorHandler.handle(e, st, showFeedback: false);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.fyExportCsvFailed)));
    } finally {
      keepAlive.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return fyExportButton(
      style: widget.style,
      onPressed: _busy ? null : _export,
      icon: const Icon(Icons.ios_share),
      label: AppLocalizations.of(context).fyExportCsv,
    );
  }
}
