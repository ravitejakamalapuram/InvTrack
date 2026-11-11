import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/holding_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The Gold or Silver choice on the form of a precious-metals investment
/// (#946). One of the two is always chosen.
class MetalChoice extends StatelessWidget {
  const MetalChoice({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Metal selected;
  final ValueChanged<Metal> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.metalChoiceLabel,
          style: AppTypography.small.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final metal in Metal.values)
              ChoiceChip(
                label: Text(metalName(l10n, metal)),
                selected: metal == selected,
                onSelected: (_) => onChanged(metal),
              ),
          ],
        ),
      ],
    );
  }
}
