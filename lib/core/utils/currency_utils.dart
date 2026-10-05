/// Currency formatting utilities with locale-aware number formatting.
///
/// This library provides comprehensive currency formatting for InvTrack,
/// supporting 40+ currencies with proper locale-specific number formatting.
///
/// ## Key Features
///
/// - **Locale-Aware Formatting**: Respects currency locale (Indian lakhs/crores vs. Western thousands/millions)
/// - **Compact Notation**: Automatic compact formatting for large numbers (1L, 1Cr, 100K, 1M)
/// - **Performance**: Cached NumberFormat instances to avoid repeated instantiation
/// - **Riverpod Integration**: Providers for currency code, symbol, and locale
/// - **Multi-Currency Support**: 40+ currencies with proper symbols and locales
///
/// ## Number Formatting Examples
///
/// Different locales format numbers differently:
///
/// ### Indian Locale (en_IN)
/// - 99,999 → "99,999" (shown in full below one lakh)
/// - 1,00,000 → "1 L" (1 lakh)
/// - 99,94,999 → "99.95 L"
/// - 1,00,00,000 → "1 Cr" (1 crore)
///
/// ### Western Locales (en_US, en_GB, de_DE)
/// - 1,000 → "1K"
/// - 100,000 → "100K"
/// - 1,000,000 → "1M"
/// - 10,000,000 → "10M"
///
/// ## Usage Example
///
/// ```dart
/// // Using providers (recommended)
/// final symbol = ref.watch(currencySymbolProvider); // ₹
/// final locale = ref.watch(currencyLocaleProvider); // en_IN
///
/// // Compact formatting (for cards, lists)
/// final compact = formatCompactCurrency(100000, symbol: symbol, locale: locale);
/// print(compact); // ₹1 L (Indian) or $100K (Western)
///
/// // Full formatting (for detail screens)
/// final full = formatCurrency(100000, symbol, locale);
/// print(full); // ₹1,00,000 (Indian) or $100,000 (Western)
///
/// // Smart formatting (compact for large amounts, full for small)
/// final smart = formatSmartCurrency(
///   100000,
///   symbol: symbol,
///   locale: locale,
///   compactThreshold: 100000,
/// );
/// print(smart); // ₹1 L (Indian) or $100K (Western)
///
/// // Using extension methods
/// final formatter = ref.watch(currencyFormatProvider);
/// print(formatter.formatCompact(100000)); // ₹1 L or $100K
/// ```
///
/// ## Supported Currencies
///
/// - **North America**: USD, CAD, MXN
/// - **Europe**: EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, HUF, RON
/// - **Asia**: INR, JPY, CNY, KRW, SGD, HKD, TWD, THB, MYR, IDR, PHP, VND, BDT, PKR, LKR, AED, SAR, ILS, TRY
/// - **Oceania**: AUD, NZD
/// - **South America**: BRL, ARS, CLP, COP, PEN
/// - **Africa**: ZAR, NGN, KES, EGP
///
/// ## Migration from formatCompactIndian()
///
/// The old `formatCompactIndian()` function is deprecated. Use `formatCompactCurrency()`
/// with locale parameter for proper multi-currency support:
///
/// ```dart
/// // ❌ OLD (always uses Indian notation)
/// formatCompactIndian(100000, symbol: '₹');
///
/// // ✅ NEW (respects locale)
/// formatCompactCurrency(100000, symbol: '₹', locale: 'en_IN');
/// ```
///
/// ## See Also
///
/// - [LocaleDetectionService] for automatic locale detection
/// - [getCurrencySymbol] for currency symbol mapping
/// - [getCurrencyLocale] for currency locale mapping
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

/// Cache for NumberFormat instances to avoid repeated instantiation overhead.
///
/// Caching improves performance by reusing formatters instead of creating
/// new instances for every formatting operation.
final Map<String, NumberFormat> _formatters = {};

/// Helper to get cached formatter
NumberFormat _getCachedFormatter({
  required String type, // 'currency', 'scaled', 'compact', 'decimal'
  String? locale,
  String? symbol,
  int? decimalDigits,
}) {
  final key = '$type|$locale|$symbol|$decimalDigits';
  return _formatters.putIfAbsent(key, () {
    switch (type) {
      case 'currency':
        return NumberFormat.currency(
          locale: locale,
          symbol: symbol,
          decimalDigits: decimalDigits,
        );
      case 'scaled':
        // Up to [decimalDigits] decimals, trailing zeros dropped.
        return NumberFormat.currency(
          locale: locale,
          symbol: symbol,
          decimalDigits: decimalDigits,
        )..minimumFractionDigits = 0;
      case 'compact':
        return NumberFormat.compactCurrency(
          locale: locale,
          symbol: symbol,
          decimalDigits: decimalDigits,
        );
      case 'decimal':
        return NumberFormat.decimalPatternDigits(
          locale: locale,
          decimalDigits: decimalDigits,
        );
      default:
        throw ArgumentError('Unknown formatter type: $type');
    }
  });
}

/// Currency symbol mapping for supported currencies
const Map<String, String> _currencySymbols = {
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
  'JPY': '¥',
  'CAD': 'C\$',
  'AUD': 'A\$',
  'CHF': 'CHF',
  'CNY': '¥',
  'SGD': 'S\$',
  'HKD': 'HK\$',
  'AED': 'د.إ',
  'SAR': '﷼',
  'BRL': 'R\$',
  'MXN': 'MX\$',
  'ZAR': 'R',
  'SEK': 'kr',
  'NOK': 'kr',
  'DKK': 'kr',
  'PLN': 'zł',
  'CZK': 'Kč',
  'HUF': 'Ft',
  'RON': 'lei',
  'KRW': '₩',
  'TWD': 'NT\$',
  'THB': '฿',
  'MYR': 'RM',
  'IDR': 'Rp',
  'PHP': '₱',
  'VND': '₫',
  'BDT': '৳',
  'PKR': '₨',
  'LKR': 'Rs',
  'ILS': '₪',
  'TRY': '₺',
  'NZD': 'NZ\$',
  'ARS': 'AR\$',
  'CLP': 'CL\$',
  'COP': 'CO\$',
  'PEN': 'S/',
  'NGN': '₦',
  'KES': 'KSh',
  'EGP': 'E£',
};

/// Locale mapping for proper number formatting.
///
/// Every locale here must print Latin digits: the UI is English, and the
/// symbol is supplied separately. bn_BD and ar_EG print Bengali and
/// Arabic-Indic digits, so BDT uses en_IN (same lakh grouping) and EGP en_US.
const Map<String, String> _currencyLocales = {
  'USD': 'en_US',
  'EUR': 'de_DE',
  'GBP': 'en_GB',
  'INR': 'en_IN', // Indian numbering: 1,00,000 (lakhs) instead of 100,000
  'JPY': 'ja_JP',
  'CAD': 'en_CA',
  'AUD': 'en_AU',
  'CHF': 'de_CH',
  'CNY': 'zh_CN',
  'SGD': 'en_SG',
  'HKD': 'zh_HK',
  'AED': 'ar_AE',
  'SAR': 'ar_SA',
  'BRL': 'pt_BR',
  'MXN': 'es_MX',
  'ZAR': 'en_ZA',
  'SEK': 'sv_SE',
  'NOK': 'nb_NO',
  'DKK': 'da_DK',
  'PLN': 'pl_PL',
  'CZK': 'cs_CZ',
  'HUF': 'hu_HU',
  'RON': 'ro_RO',
  'KRW': 'ko_KR',
  'TWD': 'zh_TW',
  'THB': 'th_TH',
  'MYR': 'ms_MY',
  'IDR': 'id_ID',
  'PHP': 'fil_PH',
  'VND': 'vi_VN',
  'BDT': 'en_IN',
  'PKR': 'ur_PK',
  'LKR': 'si_LK',
  'ILS': 'he_IL',
  'TRY': 'tr_TR',
  'NZD': 'en_NZ',
  'ARS': 'es_AR',
  'CLP': 'es_CL',
  'COP': 'es_CO',
  'PEN': 'es_PE',
  'NGN': 'en_NG',
  'KES': 'sw_KE',
  'EGP': 'en_US',
};

/// Get currency symbol from currency code.
///
/// Maps ISO 4217 currency codes to their symbols.
///
/// ## Parameters
///
/// - [currencyCode]: ISO 4217 currency code (e.g., 'USD', 'EUR', 'INR')
///
/// ## Returns
///
/// - **String**: Currency symbol (e.g., '$', '€', '₹')
/// - Fallback: '₹' (INR) if currency not found
///
/// ## Example
///
/// ```dart
/// final symbol = getCurrencySymbol('USD'); // $
/// final symbol2 = getCurrencySymbol('EUR'); // €
/// final symbol3 = getCurrencySymbol('INR'); // ₹
/// final unknown = getCurrencySymbol('XXX'); // ₹ (fallback)
/// ```
///
/// ## Supported Currencies
///
/// See [_currencySymbols] map for full list (40+ currencies).
String getCurrencySymbol(String currencyCode) {
  return _currencySymbols[currencyCode] ?? _currencySymbols['INR']!;
}

/// Get locale for currency code.
///
/// Maps currency codes to their proper locales for number formatting.
/// This is critical for correct number formatting (Indian lakhs/crores vs. Western thousands/millions).
///
/// ## Parameters
///
/// - [currencyCode]: ISO 4217 currency code (e.g., 'USD', 'EUR', 'INR')
///
/// ## Returns
///
/// - **String**: Locale string (e.g., 'en_US', 'de_DE', 'en_IN')
/// - Fallback: 'en_IN' if currency not found
///
/// ## Example
///
/// ```dart
/// final locale = getCurrencyLocale('INR'); // en_IN (Indian numbering)
/// final locale2 = getCurrencyLocale('USD'); // en_US (Western numbering)
/// final locale3 = getCurrencyLocale('EUR'); // de_DE (European numbering)
/// ```
///
/// ## Number Formatting Differences
///
/// - **en_IN**: 1,00,000 (lakhs/crores)
/// - **en_US**: 100,000 (thousands/millions)
/// - **de_DE**: 100.000 (periods as separators)
///
/// ## See Also
///
/// - [formatCompactCurrency] for locale-aware compact formatting
/// - [LocaleDetectionService] for automatic locale detection
String getCurrencyLocale(String currencyCode) {
  return _currencyLocales[currencyCode] ?? _currencyLocales['INR']!;
}

/// Get set of all supported ISO 4217 currency codes.
///
/// Returns the complete set of currency codes supported by the app.
/// This is the single source of truth for currency validation.
///
/// ## Returns
///
/// - **Set of String**: Set of supported currency codes (40+ currencies)
///
/// ## Example
///
/// ```dart
/// final validCodes = getValidCurrencyCodes();
/// final isValid = validCodes.contains('USD'); // true
/// final isInvalid = validCodes.contains('XXX'); // false
/// ```
///
/// ## Use Cases
///
/// - CSV import validation
/// - API response validation
/// - Form input validation
/// - Currency picker dropdown
///
/// ## Supported Currencies
///
/// See [_currencySymbols] map for full list.
Set<String> getValidCurrencyCodes() {
  return _currencySymbols.keys.toSet();
}

/// Provider for the current currency code
final currencyCodeProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.currency;
});

/// Gives repositories the user's base currency for stored documents that have
/// no `currency` field (written before multi-currency support).
///
/// The returned function always reads the current base currency, but the
/// calling provider is not rebuilt when it changes, which would re-subscribe
/// every Firestore stream.
String Function() baseCurrencyReader(Ref ref) {
  var current = ref.read(currencyCodeProvider);
  ref.listen<String>(currencyCodeProvider, (_, next) => current = next);
  return () => current;
}

/// The currency of an investment built from several sources (its imported
/// rows, or the investments being merged): the one they share, or
/// [baseCurrency] when they disagree or there are none.
String resolveSharedCurrency(Iterable<String> currencies, String baseCurrency) {
  final distinct = currencies.toSet();
  return distinct.length == 1 ? distinct.single : baseCurrency;
}

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
  return _getCachedFormatter(
    type: 'currency',
    symbol: symbol,
    locale: locale,
    decimalDigits: 0,
  );
});

/// Provider for a NumberFormat with 2 decimal places (for prices)
final currencyFormatPreciseProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  final locale = ref.watch(currencyLocaleProvider);
  return _getCachedFormatter(
    type: 'currency',
    symbol: symbol,
    locale: locale,
    decimalDigits: 2,
  );
});

/// Provider for compact currency format (e.g., $1.2K, ₹3.4L)
final currencyFormatCompactProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  final locale = ref.watch(currencyLocaleProvider);
  return _getCachedFormatter(type: 'compact', symbol: symbol, locale: locale);
});

/// Format a number as currency with proper locale formatting.
///
/// This is the **primary function** for displaying currency amounts throughout the app.
/// Use this for detail screens where full precision is needed.
///
/// ## Parameters
///
/// - [amount]: Amount to format
/// - [symbol]: Currency symbol (e.g., '₹', '$', '€')
/// - [locale]: Locale for number formatting (e.g., 'en_IN', 'en_US')
/// - [decimalDigits]: Number of decimal places (default: 0)
///
/// ## Returns
///
/// - **String**: Formatted currency string with locale-specific grouping
///
/// ## Example
///
/// ```dart
/// // Indian locale
/// formatCurrency(100000, '₹', 'en_IN'); // ₹1,00,000
/// formatCurrency(100000, '₹', 'en_IN', decimalDigits: 2); // ₹1,00,000.00
///
/// // US locale
/// formatCurrency(100000, '\$', 'en_US'); // \$100,000
///
/// // German locale
/// formatCurrency(100000, '€', 'de_DE'); // 100.000 €
/// ```
///
/// ## When to Use
///
/// - **Use formatCurrency()**: For detail screens, full precision
/// - **Use formatCompactCurrency()**: For cards, lists, constrained spaces
/// - **Use formatSmartCurrency()**: For adaptive formatting (compact for large amounts)
///
/// ## See Also
///
/// - [formatCompactCurrency] for compact notation (1L, 1M)
/// - [formatSmartCurrency] for adaptive formatting
String formatCurrency(
  double amount,
  String symbol,
  String locale, {
  int decimalDigits = 0,
}) {
  final formatter = _getCachedFormatter(
    type: 'currency',
    symbol: symbol,
    locale: locale,
    decimalDigits: decimalDigits,
  );
  return formatter.format(amount);
}

/// Format a number with proper locale grouping (no currency symbol).
///
/// Useful for input fields or when symbol is added separately.
///
/// ## Parameters
///
/// - [amount]: Amount to format
/// - [locale]: Locale for number formatting (e.g., 'en_IN', 'en_US')
/// - [decimalDigits]: Number of decimal places (default: 0)
///
/// ## Returns
///
/// - **String**: Formatted number string with locale-specific grouping (no symbol)
///
/// ## Example
///
/// ```dart
/// // Indian locale
/// formatNumber(100000, 'en_IN'); // 1,00,000
///
/// // US locale
/// formatNumber(100000, 'en_US'); // 100,000
///
/// // With decimals
/// formatNumber(100000.50, 'en_US', decimalDigits: 2); // 100,000.50
/// ```
///
/// ## Use Cases
///
/// - Input fields (where symbol is shown separately)
/// - Charts/graphs (where symbol is in legend)
/// - Export files (CSV, Excel)
String formatNumber(double amount, String locale, {int decimalDigits = 0}) {
  final formatter = _getCachedFormatter(
    type: 'decimal',
    locale: locale,
    decimalDigits: decimalDigits,
  );
  return formatter.format(amount);
}

/// Format amount with automatic compact notation based on size.
///
/// Uses locale-aware compact format for large numbers (100K/1M for Western, 1L/1Cr for Indian).
/// For amounts below threshold, uses full formatting.
///
/// ## Parameters
///
/// - [amount]: Amount to format
/// - [symbol]: Currency symbol (e.g., '₹', '$', '€')
/// - [locale]: Locale for number formatting (e.g., 'en_IN', 'en_US')
/// - [compactThreshold]: Above this value, use compact format (default: 100000)
///
/// ## Returns
///
/// - **String**: Formatted currency string (compact for large amounts, full for small)
///
/// ## Example
///
/// ```dart
/// // Indian locale (threshold = 100000)
/// formatSmartCurrency(50000, symbol: '₹', locale: 'en_IN'); // ₹50,000 (full)
/// formatSmartCurrency(100000, symbol: '₹', locale: 'en_IN'); // ₹1 L (compact)
/// formatSmartCurrency(1000000, symbol: '₹', locale: 'en_IN'); // ₹10 L (compact)
///
/// // US locale (threshold = 100000)
/// formatSmartCurrency(50000, symbol: '\$', locale: 'en_US'); // \$50,000 (full)
/// formatSmartCurrency(100000, symbol: '\$', locale: 'en_US'); // \$100K (compact)
/// formatSmartCurrency(1000000, symbol: '\$', locale: 'en_US'); // \$1M (compact)
/// ```
///
/// ## When to Use
///
/// - **Use formatSmartCurrency()**: For adaptive formatting (dashboard cards)
/// - **Use formatCompactCurrency()**: Always compact (list items, tight spaces)
/// - **Use formatCurrency()**: Always full (detail screens)
///
/// ## See Also
///
/// - [formatCompactCurrency] for always-compact formatting
/// - [formatCurrency] for always-full formatting
String formatSmartCurrency(
  double amount, {
  required String symbol,
  required String locale,
  double compactThreshold = 100000,
}) {
  final absAmount = amount.abs();

  if (absAmount >= compactThreshold) {
    return _formatCompact(amount, symbol, locale, 2);
  }

  return formatCurrency(amount, symbol, locale);
}

/// Format amount for display in constrained spaces (cards, lists).
///
/// **Always uses compact format** for amounts >= 1000 (>= 1 lakh in en_IN).
/// This is the **recommended function** for cards, lists, and tight spaces.
/// Up to 2 decimals are shown and trailing zeros are dropped.
///
/// ## Parameters
///
/// - [amount]: Amount to format
/// - [symbol]: Currency symbol (e.g., '₹', '$', '€')
/// - [locale]: Locale for number formatting (default: 'en_US')
///
/// ## Returns
///
/// - **String**: Formatted currency string in compact notation
///
/// ## Example
///
/// ```dart
/// // Indian locale: lakh (L) and crore (Cr); below one lakh in full
/// formatCompactCurrency(99999, symbol: '₹', locale: 'en_IN'); // ₹99,999
/// formatCompactCurrency(9994999, symbol: '₹', locale: 'en_IN'); // ₹99.95 L
/// formatCompactCurrency(9999999, symbol: '₹', locale: 'en_IN'); // ₹1 Cr
/// formatCompactCurrency(1e10, symbol: '₹', locale: 'en_IN'); // ₹1,000 Cr
///
/// // Other locales: K, M, B, T with the locale's separators
/// formatCompactCurrency(1000, symbol: '\$', locale: 'en_US'); // \$1K
/// formatCompactCurrency(1234567, symbol: '\$', locale: 'en_US'); // \$1.23M
/// formatCompactCurrency(1234567, symbol: '€', locale: 'de_DE'); // 1,23M €
/// ```
///
/// ## When to Use
///
/// - **Use formatCompactCurrency()**: For cards, lists, constrained spaces
/// - **Use formatSmartCurrency()**: For adaptive formatting (compact for large amounts)
/// - **Use formatCurrency()**: For detail screens, full precision
///
/// ## See Also
///
/// - [formatSmartCurrency] for adaptive formatting
/// - [formatCurrency] for full formatting
String formatCompactCurrency(
  double amount, {
  required String symbol,
  String locale = 'en_US',
}) {
  return _formatCompact(amount, symbol, locale, 2);
}

/// Formats [amount] in the currency [currencyCode] with its own symbol and
/// number locale, e.g. 870000 INR → '₹8,70,000.00', 5000 USD → '\$5,000.00'.
///
/// For text built outside a widget (notifications); an unknown code is shown
/// as the code itself rather than another currency's symbol.
String formatCurrencyForCode(
  double amount,
  String currencyCode, {
  int decimalDigits = 2,
}) {
  final symbol = _currencySymbols[currencyCode] ?? currencyCode;
  return formatCurrency(
    amount,
    symbol,
    getCurrencyLocale(currencyCode),
    decimalDigits: decimalDigits,
  );
}

/// A positive amount split into a scaled value and its compact unit.
typedef CompactParts = ({double value, String unit});

/// Splits [absAmount] (>= 0) into lakh ('L') or crore ('Cr') units, rounded
/// to [maxDecimals]. Amounts that round below one lakh keep no unit and are
/// rounded to whole units from 1,000 up. A value that rounds to 100 L is
/// promoted to crore, so 9,999,999 gives 1 Cr, never 100 L or 0.99 Cr.
CompactParts indianCompactParts(double absAmount, {int maxDecimals = 2}) {
  if (absAmount < 1000) {
    return (value: _roundTo(absAmount, maxDecimals), unit: '');
  }
  final whole = absAmount.roundToDouble();
  if (whole < 1e5) return (value: whole, unit: '');
  final lakhs = _roundTo(absAmount / 1e5, maxDecimals);
  if (lakhs < 100) return (value: lakhs, unit: 'L');
  return (value: _roundTo(absAmount / 1e7, maxDecimals), unit: 'Cr');
}

/// Western compact units, smallest first.
const List<(double, String)> _westernUnits = [
  (1e3, 'K'),
  (1e6, 'M'),
  (1e9, 'B'),
  (1e12, 'T'),
];

/// Splits [absAmount] (>= 0) into K, M, B or T, rounded to [maxDecimals],
/// promoting 1,000 of a unit to the next one (999,999.999 gives 1M).
CompactParts _westernCompactParts(double absAmount, int maxDecimals) {
  final rounded = _roundTo(absAmount, maxDecimals);
  if (rounded < 1000) return (value: rounded, unit: '');
  var i = 0;
  var value = _roundTo(absAmount / _westernUnits[i].$1, maxDecimals);
  while (value >= 1000 && i < _westernUnits.length - 1) {
    i++;
    value = _roundTo(absAmount / _westernUnits[i].$1, maxDecimals);
  }
  return (value: value, unit: _westernUnits[i].$2);
}

double _roundTo(double value, int decimals) {
  final factor = math.pow(10, decimals);
  return (value * factor).roundToDouble() / factor;
}

/// Matches the last digit of a formatted amount, where the unit goes.
final RegExp _lastDigit = RegExp(r'\d(?!.*\d)');

/// The one compact formatter for every currency.
///
/// en_IN uses lakh and crore with a space ('₹99.95 L', '₹1,000 Cr'); other
/// locales use K/M/B/T ('\$1.23M', '1,23M €'). The number keeps the locale's
/// own separators and symbol position, and the sign appears once.
String _formatCompact(
  double amount,
  String symbol,
  String? locale,
  int maxDecimals,
) {
  final formatter = _getCachedFormatter(
    type: 'scaled',
    symbol: symbol,
    locale: locale,
    decimalDigits: maxDecimals,
  );
  if (!amount.isFinite) return formatter.format(amount);

  final isIndian = locale == 'en_IN';
  final parts = isIndian
      ? indianCompactParts(amount.abs(), maxDecimals: maxDecimals)
      : _westernCompactParts(amount.abs(), maxDecimals);
  // A value that rounds to zero must not print as '-₹0'.
  final signed = amount < 0 && parts.value != 0 ? -parts.value : parts.value;
  final text = formatter.format(signed);
  if (parts.unit.isEmpty) return text;

  final unit = isIndian ? ' ${parts.unit}' : parts.unit;
  return text.replaceFirstMapped(_lastDigit, (m) => '${m[0]}$unit');
}

/// Extension on NumberFormat for easy smart formatting
extension SmartCurrencyFormat on NumberFormat {
  /// Format with automatic compact notation for large values
  /// Uses 2 decimals for precision on important numbers
  /// Respects locale for proper number formatting (Indian vs Western notation)
  String formatSmart(double amount, {double compactThreshold = 100000}) {
    final absAmount = amount.abs();

    if (absAmount >= compactThreshold) {
      return _formatCompact(amount, currencySymbol, locale, 2);
    }

    return format(amount);
  }

  /// Always format as compact (for constrained spaces like cards/lists)
  /// Uses 2 decimals for better precision
  /// Respects locale for proper number formatting
  String formatCompact(double amount) {
    return _formatCompact(amount, currencySymbol, locale, 2);
  }

  /// Format compact with minimal decimals (for very tight spaces)
  /// Respects locale for proper number formatting
  String formatCompactShort(double amount) {
    return _formatCompact(amount, currencySymbol, locale, 1);
  }
}
