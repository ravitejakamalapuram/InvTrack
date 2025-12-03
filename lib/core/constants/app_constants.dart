/// Application-wide constants.
///
/// Contains configuration values, magic numbers, and other
/// constants used throughout the app.
class AppConstants {
  AppConstants._();

  /// App name displayed in UI
  static const String appName = 'InvTracker';

  /// App version
  static const String appVersion = '1.0.0';

  /// Minimum iOS version supported
  static const String minIosVersion = '13.0';

  /// Minimum Android API level supported
  static const int minAndroidSdk = 24;

  /// Default currency code
  static const String defaultCurrency = 'INR';

  /// Date format for display
  static const String dateFormat = 'dd MMM yyyy';

  /// Date format for storage
  static const String storageDateFormat = 'yyyy-MM-dd';

  /// Maximum investments allowed in free tier
  static const int maxFreeInvestments = 10;

  /// Maximum entries per investment in free tier
  static const int maxFreeEntriesPerInvestment = 50;
}

/// Google OAuth configuration constants.
///
/// Contains client IDs for different platforms.
/// Note: Client IDs are public and safe to include in code.
/// Client Secrets should NEVER be included in client-side code.
class GoogleAuthConstants {
  GoogleAuthConstants._();

  /// Web OAuth Client ID
  static const String webClientId =
      '20057918856-r6qh2gt5eqk2o3oiq8fkt8pgfhquja6a.apps.googleusercontent.com';

  /// iOS OAuth Client ID (to be added when iOS is set up)
  static const String? iosClientId = null;

  /// Android OAuth Client ID (to be added when Android is set up)
  static const String? androidClientId = null;

  /// OAuth scopes required by the app
  static const List<String> scopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/spreadsheets',
  ];
}

