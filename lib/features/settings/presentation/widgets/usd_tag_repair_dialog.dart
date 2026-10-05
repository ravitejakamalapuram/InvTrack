import 'package:flutter/material.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The question: lists the flagged investments (names and cash-flow counts,
/// no amounts) with a tick each. Pops the ticked ids for Change, an empty
/// set for Keep, and null when closed with Back.
class UsdTagRepairDialog extends StatefulWidget {
  const UsdTagRepairDialog({
    super.key,
    required this.candidates,
    required this.currency,
  });

  final List<UsdTagCandidate> candidates;
  final String currency;

  @override
  State<UsdTagRepairDialog> createState() => _UsdTagRepairDialogState();
}

class _UsdTagRepairDialogState extends State<UsdTagRepairDialog> {
  // Only merged investments start ticked: older merges always wrote US
  // dollars. An imported investment may really be in US dollars (or the base
  // currency on this device may not be set yet), so the user ticks it.
  late final Set<String> _selected = {
    for (final c in widget.candidates)
      if (c.isMerged) c.investmentId,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.usdTagRepairTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              l10n.usdTagRepairMessage(
                widget.candidates.length,
                getCurrencySymbol(widget.currency),
                widget.currency,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.usdTagRepairDetail, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final c in widget.candidates)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(c.investmentId),
                onChanged: (ticked) => setState(() {
                  if (ticked == true) {
                    _selected.add(c.investmentId);
                  } else {
                    _selected.remove(c.investmentId);
                  }
                }),
                title: Text(c.name),
                subtitle: Text(
                  [
                    l10n.usdTagRepairCashFlows(c.cashFlowCount),
                    if (c.isMerged) l10n.usdTagRepairMerged,
                    if (c.isArchived) l10n.usdTagRepairArchived,
                  ].join(' · '),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(<String>{}),
          child: Text(l10n.usdTagRepairKeep),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set.of(_selected)),
          child: Text(l10n.usdTagRepairFix(widget.currency)),
        ),
      ],
    );
  }
}
