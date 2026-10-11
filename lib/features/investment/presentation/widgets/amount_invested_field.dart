import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/form_helper_text.dart';
import 'package:inv_tracker/features/investment/presentation/utils/investment_amount_input.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The optional "amount invested" field of the add investment form (A40,
/// #783).
///
/// The label and the prefix name [currencyCode], the currency the investment
/// is in (the base currency until the user picks another), so the amount is
/// never shown under another currency's symbol. Under the field: while it is
/// empty, a note that the amount is optional; once an amount is typed, that
/// amount in short form ("₹1.5 L"), so a misplaced separator shows before it
/// is saved; nothing while the text is not a valid amount, for the error
/// carries that. In privacy mode the readout reads "Hidden amount", visually
/// and to a screen reader. What the user types stays visible to them.
///
/// Read the typed value with [InvestmentAmountInput.parse] on the
/// [controller]; this field validates with the same function.
class AmountInvestedField extends ConsumerWidget {
  const AmountInvestedField({
    super.key,
    required this.controller,
    required this.currencyCode,
    this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final String currencyCode;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final privacy = ref.watch(isPrivacyModeActiveProvider);
    final locale = getCurrencyLocale(currencyCode);
    final symbol = getCurrencySymbol(currencyCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          key: AddInvestmentKeys.amount,
          controller: controller,
          focusNode: focusNode,
          label: l10n.amountInvestedLabel(currencyCode),
          hint: l10n.hintExample(formatNumber(100000, locale)),
          prefixText: symbol,
          showHintWhenEmpty: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // The minus sign is let through so "-5" gets the error instead of
          // silently becoming 5. The length is limited here rather than with
          // maxLength, which would print a counter over the helper line.
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
            LengthLimitingTextInputFormatter(
              ValidationConstants.maxAmountLength,
            ),
          ],
          validator: (value) => _validate(l10n, value),
          onChanged: onChanged,
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final input = InvestmentAmountInput.parse(
              value.text,
              currencyCode: currencyCode,
            );
            if (input.isBlank) {
              return FormHelperText(l10n.amountInvestedOptional);
            }
            final amount = input.amount;
            if (amount == null) return const SizedBox.shrink();
            if (privacy) {
              return FormHelperText(l10n.hiddenAmount, emphasized: true);
            }
            return FormHelperText(
              formatCompactCurrency(amount, symbol: symbol, locale: locale),
              emphasized: true,
              semanticsLabel: AccessibilityUtils.formatCurrencyForScreenReader(
                amount,
                symbol,
                locale: locale,
              ),
            );
          },
        ),
      ],
    );
  }

  String? _validate(AppLocalizations l10n, String? value) {
    final input = InvestmentAmountInput.parse(
      value ?? '',
      currencyCode: currencyCode,
    );
    return switch (input.problem) {
      null => null,
      AmountInputProblem.tooLarge => l10n.amountInvestedTooLarge,
      AmountInputProblem.notPositive => l10n.amountInvestedError,
      AmountInputProblem.invalid => l10n.amountInvestedInvalid,
    };
  }
}
