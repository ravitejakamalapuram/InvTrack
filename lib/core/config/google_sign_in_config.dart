/// OAuth client IDs for Google Sign-In across platforms.
///
/// These are PUBLIC identifiers from Firebase project configuration
/// (google-services.json for Android, GoogleService-Info.plist for iOS).
/// NOT secrets - safe to include in source control.
///
/// Firebase Project: invtracker-b19d1 (project number: 784857267556)
///
/// IMPORTANT: Both webClientId and androidServerClientId must come from the
/// active Firebase project's OAuth clients to ensure proper authentication and
/// cross-platform token verification. They may have the same value or different
/// values depending on the project's OAuth client configuration.
///
/// References:
/// - Web Client ID: From Firebase Console > Authentication > Sign-in method > Google > Web SDK configuration
/// - Android Server Client ID: google-services.json (client_type: 3)
/// - iOS Client ID: GoogleService-Info.plist
class GoogleSignInConfig {
  /// Web OAuth Client ID for web platform
  /// Used in: google_sign_in initialization on web (clientId parameter)
  /// Firebase project: invtracker-b19d1
  static const String webClientId =
      '784857267556-dkge5l37c12n1ohrljle8s6nim0cgq84.apps.googleusercontent.com';

  /// Android/iOS Server Client ID (Web OAuth Client ID)
  /// Used in: google_sign_in initialization on mobile (serverClientId parameter)
  /// Firebase project: invtracker-b19d1
  ///
  /// IMPORTANT: This is the Web OAuth Client ID (client_type: 3 in google-services.json)
  /// Google Sign-In v7+ REQUIRES this on Android to prevent:
  /// GoogleSignInException: "serverClientId must be provided on Android"
  ///
  /// See: https://github.com/flutter/flutter/issues/172073
  static const String androidServerClientId =
      '784857267556-dkge5l37c12n1ohrljle8s6nim0cgq84.apps.googleusercontent.com';

  /// Prevent instantiation - this is a constants-only class
  GoogleSignInConfig._();
}
