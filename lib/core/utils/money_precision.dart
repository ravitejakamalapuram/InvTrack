/// Currency-aware monetary precision for values accepted or persisted by
/// InvTrack. This policy is separate from locale formatting and from the
/// intermediate precision used by compounding and return calculations.
class MoneyPrecision {
  MoneyPrecision._();

  /// ISO 4217 minor-unit digits for zero- and three-decimal currencies.
  /// Other supported currencies currently use two digits. Keep this list
  /// aligned with the app's supported currency metadata.
  static const Set<String> _zeroFractionCurrencies = {
    'BIF',
    'CLP',
    'DJF',
    'GNF',
    'ISK',
    'JPY',
    'KMF',
    'KRW',
    'PYG',
    'RWF',
    'UGX',
    'UYI',
    'VND',
    'VUV',
    'XAF',
    'XOF',
    'XPF',
  };

  static const Set<String> _threeFractionCurrencies = {
    'BHD',
    'IQD',
    'JOD',
    'KWD',
    'LYD',
    'OMR',
    'TND',
  };

  /// Number of minor-unit digits for a currency code.
  ///
  /// Unknown/nonstandard codes use the documented two-digit fallback. Callers
  /// must still validate the currency against supported app metadata at input
  /// boundaries; this fallback is not permission to invent a currency.
  static int fractionDigitsFor(String currencyCode) {
    final code = currencyCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'Must not be empty');
    }
    if (_zeroFractionCurrencies.contains(code)) return 0;
    if (_threeFractionCurrencies.contains(code)) return 3;
    return 2;
  }

  /// Round a finite monetary amount to the currency's minor unit using
  /// round-half-away-from-zero. The input's shortest round-trippable decimal
  /// representation is converted to integer arithmetic first, avoiding
  /// common binary floating-point boundary errors such as 1.005 × 100.
  ///
  /// Do not use this for intermediate interest/compounding steps. Round at
  /// defined input, persistence, reconciliation, or output boundaries only.
  static double round(double amount, {required String currencyCode}) {
    if (!amount.isFinite) {
      throw ArgumentError.value(amount, 'amount', 'Must be finite');
    }

    final fractionDigits = fractionDigitsFor(currencyCode);
    final decimal = amount.abs().toString().toLowerCase();
    final exponentParts = decimal.split('e');
    final coefficient = exponentParts.first;
    final exponent = exponentParts.length == 2
        ? int.parse(exponentParts.last)
        : 0;
    final coefficientParts = coefficient.split('.');
    final whole = coefficientParts.first;
    final fraction = coefficientParts.length == 2
        ? coefficientParts.last
        : '';
    final digits = BigInt.parse('$whole$fraction');
    final decimalPlaces = fraction.length - exponent;
    final shift = fractionDigits - decimalPlaces;
    final BigInt minorUnits;

    if (shift >= 0) {
      minorUnits = digits * BigInt.from(10).pow(shift);
    } else {
      final divisor = BigInt.from(10).pow(-shift);
      var quotient = digits ~/ divisor;
      final remainder = digits.remainder(divisor);
      if (remainder * BigInt.from(2) >= divisor) quotient += BigInt.one;
      minorUnits = quotient;
    }

    final signedMinorUnits = amount.isNegative ? -minorUnits : minorUnits;
    final sign = signedMinorUnits.isNegative ? '-' : '';
    final absoluteDigits = signedMinorUnits.abs().toString();
    if (fractionDigits == 0) {
      return double.parse('$sign$absoluteDigits');
    }

    final padded = absoluteDigits.padLeft(fractionDigits + 1, '0');
    final splitAt = padded.length - fractionDigits;
    final major = padded.substring(0, splitAt);
    final minor = padded.substring(splitAt);
    return double.parse('$sign$major.$minor');
  }
}
