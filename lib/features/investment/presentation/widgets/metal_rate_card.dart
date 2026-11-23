import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/domain/services/metal_rate_quoter.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/providers/metal_rate_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/holding_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// "Gold today: ₹12,633.66 per gram" under "Gold held" on a metal
/// investment's page, with a button that sets the current value to the
/// weight held times that rate. The rate is the investment's own currency
/// (see [MetalRateQuoter]); nothing is shown when there is no fresh one, and
/// nothing is saved without a confirmation.
class MetalRateCard extends ConsumerWidget {
  const MetalRateCard({
    super.key,
    required this.investment,
    required this.grams,
  });

  final InvestmentEntity investment;

  /// The weight held, in grams (> 0 to offer the button).
  final double grams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metal = investment.metal ?? Metal.gold;
    final quote = ref
        .watch(
          metalRateQuoteProvider((metal: metal, currency: investment.currency)),
        )
        .value;
    if (quote == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat('d MMM yyyy', locale).format(quote.asOf.toLocal());
    final price = formatCurrencyForCode(
      quote.pricePerGram,
      investment.currency,
    );
    final source = switch (quote.kind) {
      MetalRateKind.indiaSelling => l10n.metalRateIndiaSelling(date),
      MetalRateKind.international => l10n.metalRateInternational(date),
    };
    final canUse = investment.isOpen && !investment.isArchived && grams > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.metalRateToday(metalName(l10n, metal), price),
          style: AppTypography.bodyMedium,
        ),
        Text(source, style: AppTypography.caption),
        if (!_isToday(quote.asOf))
          Text(l10n.metalRateNotToday, style: AppTypography.caption),
        if (quote.kind == MetalRateKind.international &&
            investment.currency.trim().toUpperCase() == 'INR')
          Text(l10n.metalRateShopHigher, style: AppTypography.caption),
        if (canUse)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => _confirmAndSave(context, ref, quote),
              child: Text(l10n.metalRateUse),
            ),
          ),
      ],
    );
  }

  /// Whether [at] falls on today's date on this device.
  static bool _isToday(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  Future<void> _confirmAndSave(
    BuildContext context,
    WidgetRef ref,
    MetalRateQuote quote,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final currency = investment.currency;
    final holding = UnitHolding(
      quantity: grams,
      unit: QuantityUnit.gram,
      unitPrice: quote.pricePerGram,
    );
    final total = holding.valueOrNull(currency);
    if (total == null) return;

    final weight = grams.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    final body = l10n.metalRateConfirmBody(
      '$weight g',
      formatCurrencyForCode(quote.pricePerGram, currency),
      formatCurrencyForCode(total, currency),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.metalRateConfirmTitle),
        // The weight and the total are the user's amounts: hidden in privacy
        // mode like every other amount.
        content: PrivacyMask(useTextMask: true, child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.metalRateConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final now = DateTime.now();
    try {
      await ref
          .read(investmentNotifierProvider.notifier)
          .setCurrentValue(
            id: investment.id,
            value: total,
            date: DateTime(now.year, now.month, now.day),
            holding: holding,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.metalRateApplied)));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.currentValueSaveFailed)),
      );
    }
  }
}
