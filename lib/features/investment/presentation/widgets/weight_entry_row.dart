import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/form_helper_text.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/holding_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Optional weight of metal bought or sold, with its unit, on the Add
/// transaction screen and on the add investment form.
///
/// The amount stays what the user typed; the price per unit under the row is
/// only a hint (making charges and tax mean it is not weight times price).
/// [amount] is that typed amount, null when it is blank or not valid, and
/// [currency] the currency it is in. With [amountRequired] a weight typed
/// beside a blank amount is an error, for a weight is saved on a cash flow and
/// a blank amount makes none.
class WeightEntryRow extends StatelessWidget {
  const WeightEntryRow({
    super.key,
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
    required this.onChanged,
    required this.currency,
    required this.amount,
    this.amountRequired = false,
  });

  final TextEditingController controller;
  final QuantityUnit unit;
  final ValueChanged<QuantityUnit> onUnitChanged;
  final ValueChanged<String> onChanged;
  final String currency;
  final double? amount;
  final bool amountRequired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weight = double.tryParse(controller.text.trim());
    final implied =
        weight != null && weight > 0 && amount != null && amount! > 0
        ? amount! / weight
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: controller,
                label: l10n.weightQuantityLabel,
                hint: l10n.weightOptionalHint,
                prefixIcon: Icons.scale_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                maxLength: ValidationConstants.maxAmountLength,
                onChanged: onChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = double.tryParse(value);
                  if (parsed == null) return l10n.weightFieldInvalid;
                  if (parsed <= 0) return l10n.weightFieldMustBePositive;
                  if (amountRequired && amount == null) {
                    return l10n.weightNeedsAmount;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<QuantityUnit>(
                initialValue: unit,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.weightUnitLabel),
                items: [
                  for (final option in QuantityUnit.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(
                        quantityUnitName(l10n, option),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (picked) => onUnitChanged(picked ?? unit),
              ),
            ),
          ],
        ),
        if (implied != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FormHelperText(
              l10n.weightImpliedPrice(
                formatCurrencyForCode(implied, currency),
                quantityUnitName(l10n, unit),
              ),
            ),
          ),
      ],
    );
  }
}
