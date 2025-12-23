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
  return NumberFormat.currency(symbol: symbol, decimalDigits: 0, locale: locale);
});

/// Provider for a NumberFormat with 2 decimal places (for prices)
final currencyFormatPreciseProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  final locale = ref.watch(currencyLocaleProvider);
  return NumberFormat.currency(symbol: symbol, decimalDigits: 2, locale: locale);
});

/// Provider for compact currency format (e.g., $1.2K, ₹3.4L)
final currencyFormatCompactProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  final locale = ref.watch(currencyLocaleProvider);
  return NumberFormat.compactCurrency(symbol: symbol, locale: locale);
});

/// Format a number as currency with proper locale formatting
/// Use this function for displaying amounts throughout the app
String formatCurrency(double amount, String symbol, String locale, {int decimalDigits = 0}) {
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

