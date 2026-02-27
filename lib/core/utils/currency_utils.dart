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
/// - 1,000 → "1K"
/// - 1,00,000 → "1L" (1 lakh)
/// - 10,00,000 → "10L" (10 lakhs)
/// - 1,00,00,000 → "1Cr" (1 crore)
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
/// print(compact); // ₹1L (Indian) or $100K (Western)
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
/// print(smart); // ₹1L (Indian) or $100K (Western)
///
/// // Using extension methods
/// final formatter = ref.watch(currencyFormatProvider);
/// print(formatter.formatCompact(100000)); // ₹1L or $100K
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
  required String type, // 'currency', 'compact', 'decimal'
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

/// Locale mapping for proper number formatting
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
  'BDT': 'bn_BD',
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
  'EGP': 'ar_EG',
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

/// Indian number formatting thresholds
const double _croreThreshold = 10000000; // 1 Crore = 10 Million
const double _lakhThreshold = 100000; // 1 Lakh = 100 Thousand
const double _thousandThreshold = 1000;

/// **DEPRECATED: Use `formatCompactCurrency()` instead for locale-aware formatting**
///
/// This function always uses Indian notation (K, L, Cr) regardless of the user's
/// selected currency. For proper multi-currency support, use `formatCompactCurrency()`
/// which respects the locale (100K/1M for Western currencies, 1L/1Cr for Indian).
///
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
@Deprecated(
  'Use formatCompactCurrency() with locale parameter for multi-currency support',
)
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
/// formatSmartCurrency(100000, symbol: '₹', locale: 'en_IN'); // ₹1L (compact)
/// formatSmartCurrency(1000000, symbol: '₹', locale: 'en_IN'); // ₹10L (compact)
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
    // Use locale-aware compact formatting
    final compactFormatter = _getCachedFormatter(
      type: 'compact',
      symbol: symbol,
      locale: locale,
      decimalDigits: 2,
    );
    return compactFormatter.format(amount);
  }

  return formatCurrency(amount, symbol, locale);
}

/// Format amount for display in constrained spaces (cards, lists).
///
/// **Always uses locale-aware compact format** for amounts >= 1000.
/// This is the **recommended function** for cards, lists, and tight spaces.
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
/// // Indian locale
/// formatCompactCurrency(1000, symbol: '₹', locale: 'en_IN'); // ₹1K
/// formatCompactCurrency(100000, symbol: '₹', locale: 'en_IN'); // ₹1L
/// formatCompactCurrency(1000000, symbol: '₹', locale: 'en_IN'); // ₹10L
/// formatCompactCurrency(10000000, symbol: '₹', locale: 'en_IN'); // ₹1Cr
///
/// // US locale
/// formatCompactCurrency(1000, symbol: '\$', locale: 'en_US'); // \$1K
/// formatCompactCurrency(100000, symbol: '\$', locale: 'en_US'); // \$100K
/// formatCompactCurrency(1000000, symbol: '\$', locale: 'en_US'); // \$1M
/// formatCompactCurrency(10000000, symbol: '\$', locale: 'en_US'); // \$10M
/// ```
///
/// ## When to Use
///
/// - **Use formatCompactCurrency()**: For cards, lists, constrained spaces
/// - **Use formatSmartCurrency()**: For adaptive formatting (compact for large amounts)
/// - **Use formatCurrency()**: For detail screens, full precision
///
/// ## Migration from formatCompactIndian()
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
/// - [formatSmartCurrency] for adaptive formatting
/// - [formatCurrency] for full formatting
String formatCompactCurrency(
  double amount, {
  required String symbol,
  String locale = 'en_US',
}) {
  final compactFormatter = _getCachedFormatter(
    type: 'compact',
    symbol: symbol,
    locale: locale,
    decimalDigits: 2,
  );
  return compactFormatter.format(amount);
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
  /// Respects locale for proper number formatting (Indian vs Western notation)
  String formatSmart(double amount, {double compactThreshold = 100000}) {
    final absAmount = amount.abs();

    if (absAmount >= compactThreshold) {
      // Use locale-aware compact formatting
      // Indian locale (en_IN) will show: 1L, 1Cr
      // Western locales (en_US, en_GB, etc.) will show: 100K, 1M
      final compactFormatter = _getCachedFormatter(
        type: 'compact',
        symbol: currencySymbol,
        locale: locale,
        decimalDigits: 2,
      );
      return compactFormatter.format(amount);
    }

    return format(amount);
  }

  /// Always format as compact (for constrained spaces like cards/lists)
  /// Uses 2 decimals for better precision
  /// Respects locale for proper number formatting
  String formatCompact(double amount) {
    final compactFormatter = _getCachedFormatter(
      type: 'compact',
      symbol: currencySymbol,
      locale: locale,
      decimalDigits: 2,
    );
    return compactFormatter.format(amount);
  }

  /// Format compact with minimal decimals (for very tight spaces)
  /// Respects locale for proper number formatting
  String formatCompactShort(double amount) {
    final compactFormatter = _getCachedFormatter(
      type: 'compact',
      symbol: currencySymbol,
      locale: locale,
      decimalDigits: 1,
    );
    return compactFormatter.format(amount);
  }
}
