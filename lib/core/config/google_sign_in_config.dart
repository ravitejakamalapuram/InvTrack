/// OAuth client IDs for Google Sign-In across platforms.
///
/// These are PUBLIC identifiers from Firebase project configuration
/// (google-services.json for Android, GoogleService-Info.plist for iOS).
/// NOT secrets - safe to include in source control.
///
/// References:
/// - Web Client ID: From Firebase Console > Authentication > Sign-in method > Google > Web SDK configuration
/// - Android Server Client ID: google-services.json (client_type: 3)
/// - iOS Client ID: GoogleService-Info.plist
class GoogleSignInConfig {
  /// Web OAuth Client ID for web platform
  /// Used in: google_sign_in initialization on web (clientId parameter)
  static const String webClientId =
      '20057918856-r6qh2gt5eqk2o3oiq8fkt8pgfhquja6a.apps.googleusercontent.com';

  /// Android/iOS Server Client ID (Web OAuth Client ID)
  /// Used in: google_sign_in initialization on mobile (serverClientId parameter)
  ///
  /// IMPORTANT: This is the SAME as the Web Client ID (client_type: 3 in google-services.json)
  /// Google Sign-In v7+ REQUIRES this on Android to prevent:
  /// GoogleSignInException: "serverClientId must be provided on Android"
  ///
  /// See: https://github.com/flutter/flutter/issues/172073
  static const String androidServerClientId =
      '784857267556-dkge5l37c12n1ohrljle8s6nim0cgq84.apps.googleusercontent.com';

  /// Prevent instantiation - this is a constants-only class
  GoogleSignInConfig._();
}
