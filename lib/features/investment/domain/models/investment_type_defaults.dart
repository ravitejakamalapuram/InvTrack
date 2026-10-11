import 'package:flutter/foundation.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';

/// What choosing an investment type sets up in the add form (A40, #783):
/// the structure that goes with the type (payout mode, compounding) and
/// nothing the user would have to confirm.
///
/// It has no field for a tenure, a name, a risk level or an income frequency,
/// and [typicalRate] is only the grey hint in the empty rate field. A rate or
/// term the user never typed would set a maturity date, a reminder and an
/// estimated value for them; an income frequency would schedule income
/// reminders for payouts they never mentioned (a fixed deposit that pays at
/// maturity, physical gold, a plot of land).
@immutable
class InvestmentTypeDefaults {
  const InvestmentTypeDefaults({
    this.payoutMode,
    this.compounding,
    this.typicalRate,
  });

  /// The structure of the first template of [type]; [none] when no template
  /// has that type.
  factory InvestmentTypeDefaults.forType(InvestmentType type) {
    for (final template in InvestmentTemplates.all) {
      if (template.type == type) {
        return InvestmentTypeDefaults.forTemplate(template);
      }
    }
    return none;
  }

  factory InvestmentTypeDefaults.forTemplate(InvestmentTemplate template) =>
      InvestmentTypeDefaults(
        payoutMode: template.defaultPayoutMode,
        compounding: template.defaultCompoundingFrequency,
        typicalRate: template.typicalRate,
      );

  /// Nothing set: the type has no template.
  static const none = InvestmentTypeDefaults();

  final InterestPayoutMode? payoutMode;
  final CompoundingFrequency? compounding;

  /// Typical annual return % of the type. A hint only; never saved.
  final double? typicalRate;

  /// The payout mode and compounding after the user chooses a chip whose
  /// defaults are [next], given what the form holds now. A value that is still
  /// what this chip set follows [next]; one the user changed stays.
  ({InterestPayoutMode? payoutMode, CompoundingFrequency? compounding})
  reapplyTo(
    InvestmentTypeDefaults next, {
    required InterestPayoutMode? payoutMode,
    required CompoundingFrequency? compounding,
  }) => (
    payoutMode: payoutMode == this.payoutMode ? next.payoutMode : payoutMode,
    compounding: compounding == this.compounding
        ? next.compounding
        : compounding,
  );

  /// Whether [current] is a payout mode the user chose, not what the chip set.
  bool isPayoutModeUserChoice(InterestPayoutMode? current) =>
      current != null && current != payoutMode;

  /// Whether [current] is a compounding the user chose, not what the chip set.
  bool isCompoundingUserChoice(CompoundingFrequency? current) =>
      current != null && current != compounding;

  @override
  bool operator ==(Object other) =>
      other is InvestmentTypeDefaults &&
      other.payoutMode == payoutMode &&
      other.compounding == compounding &&
      other.typicalRate == typicalRate;

  @override
  int get hashCode => Object.hash(payoutMode, compounding, typicalRate);
}
