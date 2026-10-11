import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/utils/amount_input.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';

/// Why the text in the amount invested field cannot be saved.
enum AmountInputProblem {
  /// Zero, or an amount that rounds to zero in its currency.
  notPositive,

  /// Not a number, a minus sign, or separators that fit no reading.
  invalid,

  /// 16 digits or more (invtrack_rules 19.1).
  tooLarge,
}

/// The text of the amount invested field (A40, #783), read once for the field's
/// validator, its readout and the save.
///
/// The field is optional: blank text is no amount and no problem. Anything
/// typed must be a positive amount below 15 digits, written the way
/// [currencyCode]'s locale writes numbers, and is rounded to the currency's
/// minor unit, the same rounding the notifier applies, so what the readout
/// shows is what is saved.
class InvestmentAmountInput {
  const InvestmentAmountInput._({this.amount, this.problem});

  static const _blank = InvestmentAmountInput._();

  /// The amount to save, rounded to the minor unit. Null when [isBlank] or
  /// when there is a [problem].
  final double? amount;

  /// Why the text cannot be saved; null when it is blank or valid.
  final AmountInputProblem? problem;

  /// Nothing was typed.
  bool get isBlank => amount == null && problem == null;

  static InvestmentAmountInput parse(
    String text, {
    required String currencyCode,
  }) {
    if (text.trim().isEmpty) return _blank;
    final value = parseAmountInput(text, getCurrencyLocale(currencyCode));
    if (value == null) return _problem(AmountInputProblem.invalid);
    if (value >= ValidationConstants.maxAmount) {
      return _problem(AmountInputProblem.tooLarge);
    }
    // Rounding can carry an amount up to 16 digits, or down to zero.
    final rounded = MoneyPrecision.round(value, currencyCode: currencyCode);
    if (rounded <= 0) return _problem(AmountInputProblem.notPositive);
    if (rounded >= ValidationConstants.maxAmount) {
      return _problem(AmountInputProblem.tooLarge);
    }
    return InvestmentAmountInput._(amount: rounded);
  }

  static InvestmentAmountInput _problem(AmountInputProblem problem) =>
      InvestmentAmountInput._(problem: problem);
}
