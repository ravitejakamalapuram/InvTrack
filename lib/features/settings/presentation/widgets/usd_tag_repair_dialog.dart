import 'package:flutter/material.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/settings/data/services/usd_tag_repair_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The question: lists the flagged investments and goals (names and counts,
/// no amounts) with a tick each, saying what would change. Pops the ticked
/// ids for Change, an empty set for Keep, and null when closed with Back.
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
  // Only merged all-US-dollar investments start ticked: older merges always
  // wrote US dollars. Anything else may really be in US dollars (or the base
  // currency on this device may not be set yet), so the user ticks it.
  late final Set<String> _selected = {
    for (final c in widget.candidates)
      if (c.tickedByDefault) c.id,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final candidates = widget.candidates;
    final count = candidates.length;
    final symbol = getCurrencySymbol(widget.currency);
    final goals = candidates.where((c) => c.kind == UsdTagKind.goal).length;
    final investments = count - goals;
    return AlertDialog(
      title: Text(switch ((investments, goals)) {
        (_, 0) => l10n.usdTagRepairTitle,
        (0, _) => l10n.usdTagRepairTitleGoals,
        _ => l10n.usdTagRepairTitleWithGoals,
      }),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(switch ((investments, goals)) {
              (_, 0) => l10n.usdTagRepairMessage(
                count,
                symbol,
                widget.currency,
              ),
              (0, _) => l10n.usdTagRepairMessageGoals(
                count,
                symbol,
                widget.currency,
              ),
              _ => l10n.usdTagRepairMessageWithGoals(
                count,
                symbol,
                widget.currency,
              ),
            }),
            const SizedBox(height: 8),
            Text(l10n.usdTagRepairDetail, style: theme.textTheme.bodySmall),
            if (candidates.any((c) => c.kind != UsdTagKind.allUsd)) ...[
              const SizedBox(height: 8),
              Text(
                l10n.usdTagRepairExtendedDetail(widget.currency),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            for (final c in widget.candidates)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(c.id),
                onChanged: (ticked) => setState(() {
                  if (ticked == true) {
                    _selected.add(c.id);
                  } else {
                    _selected.remove(c.id);
                  }
                }),
                title: Text(c.name),
                subtitle: Text(_whatChanges(l10n, c).join(' · ')),
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

  /// What the fix would change for [c], without amounts.
  static List<String> _whatChanges(AppLocalizations l10n, UsdTagCandidate c) =>
      [
        switch (c.kind) {
          UsdTagKind.allUsd => l10n.usdTagRepairCashFlows(c.cashFlowCount),
          UsdTagKind.noCashFlows => l10n.usdTagRepairNoCashFlows,
          UsdTagKind.partlyUsd => l10n.usdTagRepairPartly,
          UsdTagKind.goal => l10n.usdTagRepairGoal,
        },
        if (c.kind == UsdTagKind.partlyUsd && c.investmentTagged)
          l10n.usdTagRepairInvestmentCurrency,
        if (c.kind == UsdTagKind.partlyUsd && c.usdCashFlowCount > 0)
          l10n.usdTagRepairSomeCashFlows(c.usdCashFlowCount, c.cashFlowCount),
        if (c.expectedPaymentCount > 0)
          l10n.usdTagRepairExpectedPayments(c.expectedPaymentCount),
        if (c.isMerged) l10n.usdTagRepairMerged,
        if (c.isArchived) l10n.usdTagRepairArchived,
      ];
}
