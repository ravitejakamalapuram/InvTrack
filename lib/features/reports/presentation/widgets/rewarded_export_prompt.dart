/// Asks whether to watch one short ad before the Tax-Year CSV export.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// True when the user agrees to watch the ad. Closing the dialog means no.
Future<bool> showRewardedExportPrompt(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.rewardedExportTitle),
      content: Text(l10n.rewardedExportBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.rewardedExportNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.rewardedExportWatch),
        ),
      ],
    ),
  );
  return agreed ?? false;
}
