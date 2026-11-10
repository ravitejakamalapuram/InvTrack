import 'package:inv_tracker/core/utils/money_precision.dart';

/// The unit a quantity is counted in (#946). Mass units only for now; each
/// knows its weight in grams so a holding can be compared across units.
enum QuantityUnit {
  gram(1.0),
  kilogram(1000.0),
  troyOunce(31.1034768),
  tola(11.6638038),
  sovereign(8.0);

  const QuantityUnit(this.gramsPerUnit);

  final double gramsPerUnit;

  /// The unit stored under [value], or null when it is unknown. An unknown
  /// unit is never reinterpreted as another one.
  static QuantityUnit? tryParse(Object? value) {
    for (final unit in values) {
      if (unit.name == value) return unit;
    }
    return null;
  }
}

/// How a unit-based valuation was reached: [quantity] of [unit] at
/// [unitPrice] per [unit], in the valuation's own currency. The total is
/// always derived with [value], never stored separately from it, and it is
/// kept apart from cash flows: it says what is held, not what was paid.
class UnitHolding {
  final double quantity;
  final QuantityUnit unit;

  /// Price of one [unit], in the valuation's currency.
  final double unitPrice;

  const UnitHolding({
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });

  /// A usable holding: a finite, positive quantity and a finite,
  /// non-negative price.
  bool get isValid =>
      quantity.isFinite && quantity > 0 && unitPrice.isFinite && unitPrice >= 0;

  /// quantity × price at the precision of [currencyCode] (round half away
  /// from zero, once, at the end). Throws if the holding is not [isValid].
  double value(String currencyCode) {
    if (!isValid) {
      throw StateError('Cannot value an invalid holding');
    }
    return MoneyPrecision.round(
      quantity * unitPrice,
      currencyCode: currencyCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitHolding &&
          other.quantity == quantity &&
          other.unit == unit &&
          other.unitPrice == unitPrice;

  @override
  int get hashCode => Object.hash(quantity, unit, unitPrice);
}
