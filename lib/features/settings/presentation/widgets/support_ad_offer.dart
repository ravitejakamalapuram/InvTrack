import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/ads/rewarded_export_gate.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/rewarded_export_prompt.dart';

/// Called after a CSV or ZIP export has finished. The export is already done,
/// so the ad is a plain "no thanks" choice and any failure is ignored.
Future<void> offerSupportAd(BuildContext context, WidgetRef ref) async {
  try {
    await ref
        .read(exportAdGateProvider)
        .offerAfterExport(
          privacyMode: ref.read(privacyModeProvider),
          askUser: () => showRewardedExportPrompt(context, afterExport: true),
        );
  } catch (e, st) {
    ErrorHandler.handle(e, st, showFeedback: false);
  }
}
