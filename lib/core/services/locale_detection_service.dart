import 'dart:ui' as ui;

/// Service for detecting user's locale and country on first login
/// Uses device locale and provides country-to-currency mapping
class LocaleDetectionService {
  LocaleDetectionService._();

  /// Detect the user's locale from the device
  static ui.Locale detectDeviceLocale() {
    // Get the device's locale
    final deviceLocales = ui.PlatformDispatcher.instance.locales;
    if (deviceLocales.isNotEmpty) {
      return deviceLocales.first;
    }
    // Fallback to English (US)
    return const ui.Locale('en', 'US');
  }

  /// Get country code from locale (e.g., 'US', 'IN', 'GB')
  static String getCountryCode(ui.Locale locale) {
    return locale.countryCode ?? 'US';
  }

  /// Get language code from locale (e.g., 'en', 'hi', 'es')
  static String getLanguageCode(ui.Locale locale) {
    return locale.languageCode;
  }

  /// Map country code to currency code
  /// This is an enterprise-grade mapping covering major countries
  static String getCurrencyForCountry(String countryCode) {
    return _countryToCurrencyMap[countryCode.toUpperCase()] ?? 'USD';
  }

  /// Map country code to locale string for number formatting
  static String getLocaleStringForCountry(String countryCode) {
    return _countryToLocaleMap[countryCode.toUpperCase()] ?? 'en_US';
  }

  /// Get date format pattern for country
  static DateFormatPattern getDateFormatForCountry(String countryCode) {
    return _countryToDateFormatMap[countryCode.toUpperCase()] ??
        DateFormatPattern.mdy;
  }

  /// Get all supported currencies with their display names
  static Map<String, String> getSupportedCurrencies() {
    return {
      'USD': 'US Dollar (\$)',
      'EUR': 'Euro (€)',
      'GBP': 'British Pound (£)',
      'INR': 'Indian Rupee (₹)',
      'JPY': 'Japanese Yen (¥)',
      'CAD': 'Canadian Dollar (C\$)',
      'AUD': 'Australian Dollar (A\$)',
      'CHF': 'Swiss Franc (CHF)',
      'CNY': 'Chinese Yuan (¥)',
      'SGD': 'Singapore Dollar (S\$)',
      'HKD': 'Hong Kong Dollar (HK\$)',
      'AED': 'UAE Dirham (د.إ)',
      'SAR': 'Saudi Riyal (﷼)',
      'BRL': 'Brazilian Real (R\$)',
      'MXN': 'Mexican Peso (MX\$)',
      'ZAR': 'South African Rand (R)',
    };
  }

  /// Comprehensive country to currency mapping
  static const Map<String, String> _countryToCurrencyMap = {
    // North America
    'US': 'USD',
    'CA': 'CAD',
    'MX': 'MXN',

    // Europe
    'GB': 'GBP',
    'DE': 'EUR',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'NL': 'EUR',
    'BE': 'EUR',
    'AT': 'EUR',
    'PT': 'EUR',
    'IE': 'EUR',
    'GR': 'EUR',
    'FI': 'EUR',
    'CH': 'CHF',
    'SE': 'SEK',
    'NO': 'NOK',
    'DK': 'DKK',
    'PL': 'PLN',
    'CZ': 'CZK',
    'HU': 'HUF',
    'RO': 'RON',

    // Asia
    'IN': 'INR',
    'CN': 'CNY',
    'JP': 'JPY',
    'KR': 'KRW',
    'SG': 'SGD',
    'HK': 'HKD',
    'TW': 'TWD',
    'TH': 'THB',
    'MY': 'MYR',
    'ID': 'IDR',
    'PH': 'PHP',
    'VN': 'VND',
    'BD': 'BDT',
    'PK': 'PKR',
    'LK': 'LKR',
    'AE': 'AED',
    'SA': 'SAR',
    'IL': 'ILS',
    'TR': 'TRY',

    // Oceania
    'AU': 'AUD',
    'NZ': 'NZD',

    // South America
    'BR': 'BRL',
    'AR': 'ARS',
    'CL': 'CLP',
    'CO': 'COP',
    'PE': 'PEN',

    // Africa
    'ZA': 'ZAR',
    'NG': 'NGN',
    'KE': 'KES',
    'EG': 'EGP',
  };

  /// Country to locale string mapping for number formatting
  static const Map<String, String> _countryToLocaleMap = {
    'US': 'en_US',
    'GB': 'en_GB',
    'IN': 'en_IN', // Indian numbering: 1,00,000 (lakhs)
    'DE': 'de_DE',
    'FR': 'fr_FR',
    'ES': 'es_ES',
    'IT': 'it_IT',
    'JP': 'ja_JP',
    'CN': 'zh_CN',
    'KR': 'ko_KR',
    'BR': 'pt_BR',
    'MX': 'es_MX',
    'CA': 'en_CA',
    'AU': 'en_AU',
    'NZ': 'en_NZ',
    'SG': 'en_SG',
    'HK': 'zh_HK',
    'AE': 'ar_AE',
    'SA': 'ar_SA',
    'ZA': 'en_ZA',
  };

  /// Country to date format pattern mapping
  static const Map<String, DateFormatPattern> _countryToDateFormatMap = {
    'US': DateFormatPattern.mdy, // MM/DD/YYYY
    'GB': DateFormatPattern.dmy, // DD/MM/YYYY
    'IN': DateFormatPattern.dmy, // DD/MM/YYYY
    'DE': DateFormatPattern.dmy, // DD.MM.YYYY
    'FR': DateFormatPattern.dmy, // DD/MM/YYYY
    'JP': DateFormatPattern.ymd, // YYYY/MM/DD
    'CN': DateFormatPattern.ymd, // YYYY-MM-DD
    'KR': DateFormatPattern.ymd, // YYYY.MM.DD
    'CA': DateFormatPattern.ymd, // YYYY-MM-DD
  };
}

/// Date format patterns used across different countries
enum DateFormatPattern {
  mdy, // Month/Day/Year (US)
  dmy, // Day/Month/Year (UK, India, most of Europe)
  ymd, // Year/Month/Day (Japan, China, Korea, Canada)
}

