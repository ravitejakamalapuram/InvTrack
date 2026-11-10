import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/current_value_dialog.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/holding_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The dated values of one investment, newest first. Tap a row to change or
/// remove it; "Add a value" opens the same editor as the detail screen.
class ValueHistoryScreen extends ConsumerWidget {
  final InvestmentEntity investment;

  /// The earliest date a value can carry.
  final DateTime? firstCashFlowDate;

  const ValueHistoryScreen({
    super.key,
    required this.investment,
    this.firstCashFlowDate,
  });

  bool get _byWeight => investment.type == InvestmentType.gold;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    InvestmentValuationSnapshot snapshot,
  ) async {
    final result = await showDialog<CurrentValueEdit>(
      context: context,
      builder: (_) => CurrentValueDialog(
        currency: snapshot.currency,
        canRemove: true,
        removeLabel: AppLocalizations.of(context).valueHistoryRemove,
        firstDate: firstCashFlowDate,
        allowWeight: _byWeight,
        initialValue: snapshot.amount,
        initialDate: snapshot.effectiveDate,
        initialHolding: snapshot.holding,
      ),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(valuationNotifierProvider.notifier);
    try {
      if (result.isRemove) {
        await notifier.clearValuation(snapshot.id);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.valueHistoryRemoved),
            action: SnackBarAction(
              label: l10n.valueHistoryUndo,
              onPressed: () => notifier.undoClear(),
            ),
          ),
        );
      } else {
        await notifier.editValuation(
          snapshotId: snapshot.id,
          amount: result.value,
          date: result.date,
          holding: result.holding,
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.currentValueSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final snapshots = ref.watch(
      investmentValuationSnapshotsProvider(investment.id),
    );
    final mutedColor = isDark
        ? AppColors.neutral400Dark
        : AppColors.neutral500Light;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.valueHistoryTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              l10n.valueHistoryIntro,
              style: AppTypography.small.copyWith(color: mutedColor),
            ),
            const SizedBox(height: AppSpacing.md),
            if (snapshots.isEmpty)
              Text(l10n.valueHistoryEmpty)
            else
              for (final snapshot in snapshots)
                _Row(
                  snapshot: snapshot,
                  isPrivacyMode: isPrivacyMode,
                  mutedColor: mutedColor,
                  onTap: () => _edit(context, ref, snapshot),
                ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => showCurrentValueDialog(
                context,
                ref,
                investment: investment,
                hasUserValue: false,
                firstCashFlowDate: firstCashFlowDate,
              ),
              child: Text(l10n.valueHistoryAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final InvestmentValuationSnapshot snapshot;
  final bool isPrivacyMode;
  final Color mutedColor;
  final VoidCallback onTap;

  const _Row({
    required this.snapshot,
    required this.isPrivacyMode,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = AppDateUtils.formatShort(snapshot.effectiveDate);
    final amount = formatCurrencyForCode(snapshot.amount, snapshot.currency);
    final holding = snapshot.holding;
    return Semantics(
      button: true,
      label: isPrivacyMode
          ? l10n.valueHistoryRowHidden(date)
          : l10n.valueHistoryRowLabel(date, amount),
      child: ExcludeSemantics(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: onTap,
          title: Text(date),
          subtitle: holding == null
              ? null
              : MaskedAmountText(
                  text: holdingText(l10n, holding, snapshot.currency),
                  style: AppTypography.small.copyWith(color: mutedColor),
                ),
          trailing: MaskedAmountText(
            text: amount,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
