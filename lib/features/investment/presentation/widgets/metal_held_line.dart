import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// "Gold held: 12.5 g" on a metal investment's page. The weight is private
/// like an amount, so privacy mode masks it.
class MetalHeldLine extends StatelessWidget {
  const MetalHeldLine({super.key, required this.grams});

  final double grams;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = grams.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    return MaskedAmountText(
      text: l10n.metalHeld('$text g'),
      style: AppTypography.bodyMedium,
    );
  }
}
