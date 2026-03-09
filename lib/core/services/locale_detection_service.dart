/// Locale detection and country-to-currency mapping service.
///
/// This service provides automatic locale detection and comprehensive mappings
/// for currency, number formatting, and date formats based on the user's country.
///
/// ## Key Features
///
/// - **Automatic Locale Detection**: Detects device locale on first login
/// - **Currency Mapping**: Maps 50+ countries to their currencies
/// - **Number Formatting**: Provides locale-specific number formatting (e.g., Indian lakhs/crores)
/// - **Date Formatting**: Maps countries to date format patterns (MDY, DMY, YMD)
/// - **Fallback Handling**: Defaults to US locale if detection fails
///
/// ## Supported Regions
///
/// - **North America**: US, Canada, Mexico
/// - **Europe**: 20+ countries (EUR, GBP, CHF, SEK, NOK, etc.)
/// - **Asia**: 15+ countries (INR, CNY, JPY, SGD, AED, etc.)
/// - **Oceania**: Australia, New Zealand
/// - **South America**: Brazil, Argentina, Chile, Colombia, Peru
/// - **Africa**: South Africa, Nigeria, Kenya, Egypt
///
/// ## Usage Example
///
/// ```dart
/// // Detect device locale
/// final locale = LocaleDetectionService.detectDeviceLocale();
/// print('Locale: ${locale.languageCode}_${locale.countryCode}'); // en_IN
///
/// // Get country code
/// final countryCode = LocaleDetectionService.getCountryCode(locale);
/// print('Country: $countryCode'); // IN
///
/// // Get currency for country
/// final currency = LocaleDetectionService.getCurrencyForCountry(countryCode);
/// print('Currency: $currency'); // INR
///
/// // Get locale string for number formatting
/// final localeString = LocaleDetectionService.getLocaleStringForCountry(countryCode);
/// print('Locale String: $localeString'); // en_IN
///
/// // Get date format pattern
/// final dateFormat = LocaleDetectionService.getDateFormatForCountry(countryCode);
/// print('Date Format: $dateFormat'); // DateFormatPattern.dmy (DD/MM/YYYY)
///
/// // Get all supported currencies
/// final currencies = LocaleDetectionService.getSupportedCurrencies();
/// currencies.forEach((code, name) => print('$code: $name'));
/// // USD: US Dollar ($)
/// // EUR: Euro (€)
/// // INR: Indian Rupee (₹)
/// // ...
/// ```
///
/// ## Number Formatting Examples
///
/// Different locales format numbers differently:
/// - **en_US**: 1,000,000 (millions)
/// - **en_IN**: 10,00,000 (lakhs/crores)
/// - **de_DE**: 1.000.000 (periods as separators)
/// - **fr_FR**: 1 000 000 (spaces as separators)
///
/// ## Date Format Patterns
///
/// - **MDY** (US): 12/31/2024
/// - **DMY** (UK, India, Europe): 31/12/2024
/// - **YMD** (Japan, China, Korea, Canada): 2024/12/31
///
/// ## See Also
///
/// - [CurrencyUtils] for currency formatting with locale support
/// - [DateFormatPattern] enum for date format types
library;

import 'dart:ui' as ui;

/// Service for detecting user's locale and country on first login.
///
/// See library documentation above for usage examples and supported regions.
///
/// **All methods are static** - no need to instantiate this class.
class LocaleDetectionService {
  LocaleDetectionService._();

  /// Detect the user's locale from the device.
  ///
  /// Returns the first locale from the device's locale list.
  /// Falls back to `en_US` if no locales are available.
  ///
  /// ## Returns
  ///
  /// - [ui.Locale]: Device locale (e.g., `Locale('en', 'IN')`)
  /// - Fallback: `Locale('en', 'US')` if detection fails
  ///
  /// ## Example
  ///
  /// ```dart
  /// final locale = LocaleDetectionService.detectDeviceLocale();
  /// print('${locale.languageCode}_${locale.countryCode}'); // en_IN
  /// ```
  static ui.Locale detectDeviceLocale() {
    // Get the device's locale
    final deviceLocales = ui.PlatformDispatcher.instance.locales;
    if (deviceLocales.isNotEmpty) {
      return deviceLocales.first;
    }
    // Fallback to English (US)
    return const ui.Locale('en', 'US');
  }

  /// Get country code from locale (e.g., 'US', 'IN', 'GB').
  ///
  /// ## Parameters
  ///
  /// - [locale]: Device locale
  ///
  /// ## Returns
  ///
  /// - **String**: Country code (e.g., 'IN', 'US', 'GB')
  /// - Fallback: 'US' if country code is null
  ///
  /// ## Example
  ///
  /// ```dart
  /// final locale = Locale('en', 'IN');
  /// final countryCode = LocaleDetectionService.getCountryCode(locale);
  /// print(countryCode); // IN
  /// ```
  static String getCountryCode(ui.Locale locale) {
    return locale.countryCode ?? 'US';
  }

  /// Get language code from locale (e.g., 'en', 'hi', 'es').
  ///
  /// ## Parameters
  ///
  /// - [locale]: Device locale
  ///
  /// ## Returns
  ///
  /// - **String**: Language code (e.g., 'en', 'hi', 'es')
  ///
  /// ## Example
  ///
  /// ```dart
  /// final locale = Locale('hi', 'IN');
  /// final languageCode = LocaleDetectionService.getLanguageCode(locale);
  /// print(languageCode); // hi
  /// ```
  static String getLanguageCode(ui.Locale locale) {
    return locale.languageCode;
  }

  /// Map country code to currency code.
  ///
  /// This is an enterprise-grade mapping covering 50+ countries.
  ///
  /// ## Parameters
  ///
  /// - [countryCode]: ISO 3166-1 alpha-2 country code (e.g., 'IN', 'US', 'GB')
  ///
  /// ## Returns
  ///
  /// - **String**: ISO 4217 currency code (e.g., 'INR', 'USD', 'EUR')
  /// - Fallback: 'USD' if country not found
  ///
  /// ## Example
  ///
  /// ```dart
  /// final currency = LocaleDetectionService.getCurrencyForCountry('IN');
  /// print(currency); // INR
  ///
  /// final unknownCurrency = LocaleDetectionService.getCurrencyForCountry('XX');
  /// print(unknownCurrency); // USD (fallback)
  /// ```
  ///
  /// ## Supported Countries
  ///
  /// See [_countryToCurrencyMap] for full list (50+ countries).
  static String getCurrencyForCountry(String countryCode) {
    return _countryToCurrencyMap[countryCode.toUpperCase()] ?? 'USD';
  }

  /// Map country code to locale string for number formatting.
  ///
  /// Different locales format numbers differently:
  /// - **en_US**: 1,000,000 (millions)
  /// - **en_IN**: 10,00,000 (lakhs/crores)
  /// - **de_DE**: 1.000.000 (periods as separators)
  ///
  /// ## Parameters
  ///
  /// - [countryCode]: ISO 3166-1 alpha-2 country code (e.g., 'IN', 'US', 'GB')
  ///
  /// ## Returns
  ///
  /// - **String**: Locale string (e.g., 'en_IN', 'en_US', 'de_DE')
  /// - Fallback: 'en_US' if country not found
  ///
  /// ## Example
  ///
  /// ```dart
  /// final localeString = LocaleDetectionService.getLocaleStringForCountry('IN');
  /// print(localeString); // en_IN
  ///
  /// // Use with NumberFormat
  /// final formatter = NumberFormat.currency(locale: localeString, symbol: '₹');
  /// print(formatter.format(100000)); // ₹1,00,000 (Indian notation)
  /// ```
  ///
  /// ## See Also
  ///
  /// - [CurrencyUtils.formatCompactCurrency] for currency formatting
  static String getLocaleStringForCountry(String countryCode) {
    return _countryToLocaleMap[countryCode.toUpperCase()] ?? 'en_US';
  }

  /// Get date format pattern for country.
  ///
  /// Different countries use different date formats:
  /// - **MDY** (US): 12/31/2024
  /// - **DMY** (UK, India, Europe): 31/12/2024
  /// - **YMD** (Japan, China, Korea, Canada): 2024/12/31
  ///
  /// ## Parameters
  ///
  /// - [countryCode]: ISO 3166-1 alpha-2 country code (e.g., 'IN', 'US', 'GB')
  ///
  /// ## Returns
  ///
  /// - [DateFormatPattern]: Date format pattern enum
  /// - Fallback: [DateFormatPattern.mdy] if country not found
  ///
  /// ## Example
  ///
  /// ```dart
  /// final dateFormat = LocaleDetectionService.getDateFormatForCountry('IN');
  /// print(dateFormat); // DateFormatPattern.dmy
  ///
  /// // Use with DateFormat
  /// final formatter = dateFormat == DateFormatPattern.dmy
  ///     ? DateFormat('dd/MM/yyyy')
  ///     : DateFormat('MM/dd/yyyy');
  /// ```
  static DateFormatPattern getDateFormatForCountry(String countryCode) {
    return _countryToDateFormatMap[countryCode.toUpperCase()] ??
        DateFormatPattern.mdy;
  }

  /// Get all supported currencies with their display names.
  ///
  /// Returns a map of currency codes to display names with symbols.
  ///
  /// ## Returns
  ///
  /// - **Map of String to String**: Currency code → Display name
  ///
  /// ## Example
  ///
  /// ```dart
  /// final currencies = LocaleDetectionService.getSupportedCurrencies();
  /// currencies.forEach((code, name) {
  ///   print('$code: $name');
  /// });
  /// // USD: US Dollar ($)
  /// // EUR: Euro (€)
  /// // GBP: British Pound (£)
  /// // INR: Indian Rupee (₹)
  /// // ...
  /// ```
  ///
  /// ## Supported Currencies
  ///
  /// - USD, EUR, GBP, INR, JPY, CAD, AUD, CHF
  /// - CNY, SGD, HKD, AED, SAR, BRL, MXN, ZAR
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

/// Date format patterns used across different countries.
///
/// Different countries use different date formats. This enum helps
/// standardize date formatting based on the user's country.
///
/// ## Format Examples
///
/// For the date: December 31, 2024
///
/// - **[mdy]** (US): 12/31/2024
/// - **[dmy]** (UK, India, Europe): 31/12/2024
/// - **[ymd]** (Japan, China, Korea, Canada): 2024/12/31
///
/// ## Usage Example
///
/// ```dart
/// final countryCode = 'IN';
/// final pattern = LocaleDetectionService.getDateFormatForCountry(countryCode);
///
/// final formatter = switch (pattern) {
///   DateFormatPattern.mdy => DateFormat('MM/dd/yyyy'),
///   DateFormatPattern.dmy => DateFormat('dd/MM/yyyy'),
///   DateFormatPattern.ymd => DateFormat('yyyy/MM/dd'),
/// };
///
/// print(formatter.format(DateTime(2024, 12, 31))); // 31/12/2024 (for India)
/// ```
enum DateFormatPattern {
  /// Month/Day/Year format (US).
  ///
  /// **Example**: 12/31/2024
  ///
  /// **Used in**: United States
  mdy,

  /// Day/Month/Year format (UK, India, most of Europe).
  ///
  /// **Example**: 31/12/2024
  ///
  /// **Used in**: UK, India, Germany, France, Spain, Italy, Australia, etc.
  dmy,

  /// Year/Month/Day format (Japan, China, Korea, Canada).
  ///
  /// **Example**: 2024/12/31
  ///
  /// **Used in**: Japan, China, Korea, Canada
  ymd,
}
