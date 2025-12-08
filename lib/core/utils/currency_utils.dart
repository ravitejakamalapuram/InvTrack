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

/// Get currency symbol from currency code
String getCurrencySymbol(String currencyCode) {
  return _currencySymbols[currencyCode] ?? _currencySymbols['INR']!;
}

/// Provider for the current currency symbol based on settings
final currencySymbolProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return getCurrencySymbol(settings.currency);
});

/// Provider for a NumberFormat configured with the user's currency preference
final currencyFormatProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  return NumberFormat.currency(symbol: symbol, decimalDigits: 0);
});

/// Provider for a NumberFormat with 2 decimal places (for prices)
final currencyFormatPreciseProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  return NumberFormat.currency(symbol: symbol, decimalDigits: 2);
});

/// Provider for compact currency format (e.g., $1.2K, $3.4M)
final currencyFormatCompactProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  return NumberFormat.compactCurrency(symbol: symbol);
});

