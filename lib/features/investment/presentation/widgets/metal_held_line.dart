import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/holding_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// "Gold held: 12.5 g" on a metal investment's page. A record without a
/// metal reads as gold. The weight is private like an amount, so privacy mode
/// masks it.
class MetalHeldLine extends StatelessWidget {
  const MetalHeldLine({super.key, required this.grams, this.metal});

  final double grams;
  final Metal? metal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = grams.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    return MaskedAmountText(
      text: l10n.metalHeld(metalName(l10n, metal ?? Metal.gold), '$text g'),
      style: AppTypography.bodyMedium,
    );
  }
}
