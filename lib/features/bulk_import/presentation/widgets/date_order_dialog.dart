import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Asks whether a CSV file's dates are day-first or month-first, showing
/// one of its dates read both ways. Returns null when the user cancels.
Future<CsvDateOrder?> showDateOrderDialog(
  BuildContext context,
  DateOrderQuestion question,
) {
  final l10n = AppLocalizations.of(context);
  // Month as a word, so the two readings cannot be confused with each other.
  final format = DateFormat(
    'd MMM yyyy',
    Localizations.localeOf(context).toString(),
  );

  return showDialog<CsvDateOrder>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.importDateOrderTitle),
      content: Text(l10n.importDateOrderMessage(question.sample)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(CsvDateOrder.monthFirst),
          child: Text(
            l10n.importDateOrderMonthFirst(format.format(question.monthFirst)),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(CsvDateOrder.dayFirst),
          child: Text(
            l10n.importDateOrderDayFirst(format.format(question.dayFirst)),
          ),
        ),
      ],
    ),
  );
}
