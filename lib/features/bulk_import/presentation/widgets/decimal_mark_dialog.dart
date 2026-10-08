import 'package:flutter/material.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Asks whether a CSV file's amounts use a decimal point (1,234.56) or a
/// decimal comma (1.234,56). Returns true for a comma, false for a point and
/// null when the user cancels. The examples are fixed, so no amount from
/// the file is shown (privacy mode).
Future<bool?> showDecimalMarkDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.importDecimalMarkTitle),
      content: Text(l10n.importDecimalMarkMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.importDecimalMarkComma),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.importDecimalMarkPoint),
        ),
      ],
    ),
  );
}
