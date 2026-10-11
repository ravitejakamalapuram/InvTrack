import 'package:flutter/foundation.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';

/// What choosing an investment type sets up in the add form (A40, #783):
/// the structure that goes with the type (income frequency, payout mode,
/// compounding) and nothing the user would have to confirm.
///
/// It has no field for a tenure, a name or a risk level, and [typicalRate] is
/// only the grey hint in the empty rate field. A rate or term the user never
/// typed would set a maturity date, a reminder and an estimated value for them.
@immutable
class InvestmentTypeDefaults {
  const InvestmentTypeDefaults({
    this.incomeFrequency,
    this.payoutMode,
    this.compounding,
    this.typicalRate,
  });

  /// The structure of the first template of [type]; [none] when no template
  /// has that type.
  factory InvestmentTypeDefaults.forType(InvestmentType type) {
    for (final template in InvestmentTemplates.all) {
      if (template.type == type)
        return InvestmentTypeDefaults.forTemplate(template);
    }
    return none;
  }

  factory InvestmentTypeDefaults.forTemplate(InvestmentTemplate template) =>
      InvestmentTypeDefaults(
        incomeFrequency: template.defaultIncomeFrequency,
        payoutMode: template.defaultPayoutMode,
        compounding: template.defaultCompoundingFrequency,
        typicalRate: template.typicalRate,
      );

  /// Nothing set: the type has no template.
  static const none = InvestmentTypeDefaults();

  final IncomeFrequency? incomeFrequency;
  final InterestPayoutMode? payoutMode;
  final CompoundingFrequency? compounding;

  /// Typical annual return % of the type. A hint only; never saved.
  final double? typicalRate;

  @override
  bool operator ==(Object other) =>
      other is InvestmentTypeDefaults &&
      other.incomeFrequency == incomeFrequency &&
      other.payoutMode == payoutMode &&
      other.compounding == compounding &&
      other.typicalRate == typicalRate;

  @override
  int get hashCode =>
      Object.hash(incomeFrequency, payoutMode, compounding, typicalRate);
}
