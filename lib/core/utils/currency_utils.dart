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
@Deprecated('Use formatCompactCurrency() with locale parameter for multi-currency support')
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
/// Uses locale-aware compact format for large numbers (100K/1M for Western, 1L/1Cr for Indian)
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
    // Use locale-aware compact formatting
    final compactFormatter = NumberFormat.compactCurrency(
      symbol: symbol,
      locale: locale,
      decimalDigits: 2,
    );
    return compactFormatter.format(amount);
  }

  return formatCurrency(amount, symbol, locale);
}

/// Format amount for display in constrained spaces (cards, lists)
/// Always uses locale-aware compact format for amounts >= 1000
String formatCompactCurrency(
  double amount, {
  required String symbol,
  String locale = 'en_US',
}) {
  final compactFormatter = NumberFormat.compactCurrency(
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
      final compactFormatter = NumberFormat.compactCurrency(
        symbol: currencySymbol,
        locale: locale?.toString(),
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
    final compactFormatter = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      locale: locale?.toString(),
      decimalDigits: 2,
    );
    return compactFormatter.format(amount);
  }

  /// Format compact with minimal decimals (for very tight spaces)
  /// Respects locale for proper number formatting
  String formatCompactShort(double amount) {
    final compactFormatter = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      locale: locale?.toString(),
      decimalDigits: 1,
    );
    return compactFormatter.format(amount);
  }
}
