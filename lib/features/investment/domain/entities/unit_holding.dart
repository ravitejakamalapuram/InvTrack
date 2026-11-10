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
  /// from zero, once, at the end). The product is taken on the decimal
  /// numbers as written, not on their binary forms, so 0.1 g at 0.35 a gram
  /// is 0.035 and rounds to 0.04. Throws if the holding is not [isValid] or
  /// the product overflows; use [valueOrNull] on stored data.
  double value(String currencyCode) =>
      valueOrNull(currencyCode) ??
      (throw StateError('Cannot value this holding'));

  /// As [value], or null when the holding is not [isValid] or its value is
  /// not finite or too large to store (money rule 19.1).
  double? valueOrNull(String currencyCode) {
    if (!isValid) return null;
    final product = _decimalProduct(quantity, unitPrice);
    if (!product.isFinite) return null;
    final rounded = MoneyPrecision.round(product, currencyCode: currencyCode);
    return MoneyPrecision.reachesMaxAmount(rounded, currencyCode: currencyCode)
        ? null
        : rounded;
  }

  /// [a] × [b] computed on the shortest decimal form of each (both are
  /// finite and non-negative here), as the nearest double.
  static double _decimalProduct(double a, double b) {
    final (digitsA, scaleA) = _decimal(a);
    final (digitsB, scaleB) = _decimal(b);
    final digits = (digitsA * digitsB).toString();
    final scale = scaleA + scaleB;
    if (scale <= 0) return double.parse('$digits${'0' * -scale}');
    final padded = digits.padLeft(scale + 1, '0');
    final point = padded.length - scale;
    return double.parse(
      '${padded.substring(0, point)}.${padded.substring(point)}',
    );
  }

  /// [value] as integer digits and a count of decimal places.
  static (BigInt, int) _decimal(double value) {
    final parts = value.toString().toLowerCase().split('e');
    final exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
    final number = parts.first.split('.');
    final fraction = number.length == 2 ? number[1] : '';
    return (
      BigInt.parse('${number.first}$fraction'),
      fraction.length - exponent,
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
