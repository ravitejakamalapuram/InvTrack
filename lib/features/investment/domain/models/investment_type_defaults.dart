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

  /// The payout mode and compounding the form holds once the chip with these
  /// defaults is chosen. A field the user picked ([payoutModeChosen],
  /// [compoundingChosen], which the form tracks) keeps its value; every other
  /// field takes this chip's value, or none when the chip has no structure.
  ///
  /// The form tracks the picks because comparing a value with what the last
  /// chip set cannot tell a pick from a chip's value once they are equal.
  ({InterestPayoutMode? payoutMode, CompoundingFrequency? compounding})
  applyOver({
    required InterestPayoutMode? payoutMode,
    required bool payoutModeChosen,
    required CompoundingFrequency? compounding,
    required bool compoundingChosen,
  }) => (
    payoutMode: payoutModeChosen ? payoutMode : this.payoutMode,
    compounding: compoundingChosen ? compounding : this.compounding,
  );

  @override
  bool operator ==(Object other) =>
      other is InvestmentTypeDefaults &&
      other.payoutMode == payoutMode &&
      other.compounding == compounding &&
      other.typicalRate == typicalRate;

  @override
  int get hashCode => Object.hash(payoutMode, compounding, typicalRate);
}
