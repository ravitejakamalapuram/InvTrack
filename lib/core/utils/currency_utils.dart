import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

/// Currency symbol mapping for supported currencies
const Map<String, String> _currencySymbols = {
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
  'JPY': '¥',
};

/// Locale mapping for proper number formatting
const Map<String, String> _currencyLocales = {
  'USD': 'en_US',
  'EUR': 'de_DE',
  'GBP': 'en_GB',
  'INR': 'en_IN', // Indian numbering: 1,00,000 (lakhs) instead of 100,000
  'JPY': 'ja_JP',
};

/// Get currency symbol from currency code
String getCurrencySymbol(String currencyCode) {
  return _currencySymbols[currencyCode] ?? _currencySymbols['INR']!;
}

/// Get locale for currency code
String getCurrencyLocale(String currencyCode) {
  return _currencyLocales[currencyCode] ?? _currencyLocales['INR']!;
}

/// Provider for the current currency code
final currencyCodeProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.currency;
});

/// Provider for the current currency symbol based on settings
final currencySymbolProvider = Provider<String>((ref) {
  final currencyCode = ref.watch(currencyCodeProvider);
  return getCurrencySymbol(currencyCode);
});

/// Provider for the current locale based on currency
final currencyLocaleProvider = Provider<String>((ref) {
  final currencyCode = ref.watch(currencyCodeProvider);
  return getCurrencyLocale(currencyCode);
});

/// Provider for a NumberFormat configured with the user's currency preference
final currencyFormatProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  final locale = ref.watch(currencyLocaleProvider);
  return NumberFormat.currency(
    symbol: symbol,
    decimalDigits: 0,
    locale: locale,
  );
});

/// Provider for a NumberFormat with 2 decimal places (for prices)
final currencyFormatPreciseProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  final locale = ref.watch(currencyLocaleProvider);
  return NumberFormat.currency(
    symbol: symbol,
    decimalDigits: 2,
    locale: locale,
  );
});

/// Provider for compact currency format (e.g., $1.2K, ₹3.4L)
final currencyFormatCompactProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  final locale = ref.watch(currencyLocaleProvider);
  return NumberFormat.compactCurrency(symbol: symbol, locale: locale);
});

/// Format a number as currency with proper locale formatting
/// Use this function for displaying amounts throughout the app
String formatCurrency(
  double amount,
  String symbol,
  String locale, {
  int decimalDigits = 0,
}) {
  final formatter = NumberFormat.currency(
    symbol: symbol,
    decimalDigits: decimalDigits,
    locale: locale,
  );
  return formatter.format(amount);
}

/// Format a number with proper locale grouping (no currency symbol)
/// Useful for input fields or when symbol is added separately
String formatNumber(double amount, String locale, {int decimalDigits = 0}) {
  final formatter = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: decimalDigits,
  );
  return formatter.format(amount);
}

/// Indian number formatting thresholds
const double _croreThreshold = 10000000; // 1 Crore = 10 Million
const double _lakhThreshold = 100000; // 1 Lakh = 100 Thousand
const double _thousandThreshold = 1000;

/// Format amount with Indian compact notation (K, L, Cr)
///
/// Examples:
/// - 1500 → "1.5K"
/// - 150000 → "1.5L"
/// - 15000000 → "1.5Cr"
/// - 500 → "500"
///
/// [amount] - The amount to format
/// [symbol] - Currency symbol (e.g., "₹")
/// [maxDecimals] - Maximum decimal places (default 1)
/// [alwaysShowDecimals] - If true, always show decimal places
String formatCompactIndian(
  double amount, {
  String symbol = '₹',
  int maxDecimals = 1,
  bool alwaysShowDecimals = false,
}) {
  final absAmount = amount.abs();
  final sign = amount < 0 ? '-' : '';

  String formatted;
  String suffix;

  if (absAmount >= _croreThreshold) {
    final value = absAmount / _croreThreshold;
    formatted = _formatDecimal(value, maxDecimals, alwaysShowDecimals);
    suffix = 'Cr';
  } else if (absAmount >= _lakhThreshold) {
    final value = absAmount / _lakhThreshold;
    formatted = _formatDecimal(value, maxDecimals, alwaysShowDecimals);
    suffix = 'L';
  } else if (absAmount >= _thousandThreshold) {
    final value = absAmount / _thousandThreshold;
    formatted = _formatDecimal(value, maxDecimals, alwaysShowDecimals);
    suffix = 'K';
  } else {
    formatted = absAmount.toStringAsFixed(0);
    suffix = '';
  }

  return '$sign$symbol$formatted$suffix';
}

/// Format amount with automatic compact notation based on size
/// Uses compact format for large numbers, full format for small numbers
///
/// [amount] - The amount to format
/// [symbol] - Currency symbol
/// [locale] - Locale for number formatting
/// [compactThreshold] - Above this value, use compact format (default 100000 = 1L)
String formatSmartCurrency(
  double amount, {
  required String symbol,
  required String locale,
  double compactThreshold = 100000,
}) {
  final absAmount = amount.abs();

  if (absAmount >= compactThreshold) {
    return formatCompactIndian(amount, symbol: symbol);
  }

  return formatCurrency(amount, symbol, locale);
}

/// Format amount for display in constrained spaces (cards, lists)
/// Always uses compact format for amounts >= 1000
String formatCompactCurrency(double amount, {required String symbol}) {
  return formatCompactIndian(amount, symbol: symbol);
}

/// Format decimal value, removing trailing zeros if not alwaysShowDecimals
String _formatDecimal(double value, int maxDecimals, bool alwaysShowDecimals) {
  if (alwaysShowDecimals) {
    return value.toStringAsFixed(maxDecimals);
  }

  // Check if value is close to a whole number (only for 1 decimal display)
  if (maxDecimals <= 1 && (value - value.roundToDouble()).abs() < 0.05) {
    return value.round().toString();
  }

  // Format with decimals, but trim trailing zeros
  final formatted = value.toStringAsFixed(maxDecimals);
  if (formatted.contains('.')) {
    return formatted.replaceAll(RegExp(r'\.?0+$'), '');
  }
  return formatted;
}

/// Extension on NumberFormat for easy smart formatting
extension SmartCurrencyFormat on NumberFormat {
  /// Format with automatic compact notation for large values
  /// Uses 2 decimals for precision on important numbers
  String formatSmart(double amount, {double compactThreshold = 100000}) {
    final absAmount = amount.abs();

    if (absAmount >= compactThreshold) {
      // Use 2 decimals for important/hero numbers
      return formatCompactIndian(
        amount,
        symbol: currencySymbol,
        maxDecimals: 2,
      );
    }

    return format(amount);
  }

  /// Always format as compact (for constrained spaces like cards/lists)
  /// Uses 2 decimals for better precision
  String formatCompact(double amount) {
    return formatCompactIndian(amount, symbol: currencySymbol, maxDecimals: 2);
  }

  /// Format compact with minimal decimals (for very tight spaces)
  String formatCompactShort(double amount) {
    return formatCompactIndian(amount, symbol: currencySymbol, maxDecimals: 1);
  }
}
