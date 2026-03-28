/// Centralized error handling for the InvTrack application.
///
/// This service provides a unified approach to error handling across the app:
/// - **Exception Mapping**: Converts platform exceptions to user-friendly [AppException]s
/// - **Error Logging**: Logs errors to console (debug) or Crashlytics (production)
/// - **User Feedback**: Shows user-friendly error messages via snackbars
/// - **Privacy-First**: Never logs sensitive data (amounts, PII)
///
/// ## Exception Hierarchy
///
/// All exceptions inherit from [AppException]:
/// - **[AuthException]**: Authentication/authorization errors
///   - `signInCancelled()`: User cancelled sign-in
///   - `signInFailed()`: Sign-in failed
///   - `notAuthenticated()`: User not authenticated
/// - **[NetworkException]**: Network connectivity errors
///   - `noConnection()`: No internet connection
///   - `timeout()`: Request timed out
/// - **[DataException]**: Data validation/storage errors
///   - `notFound()`: Resource not found
///   - `saveFailed()`: Failed to save data
/// - **[ValidationException]**: User input validation errors
///
/// ## Usage Example
///
/// ```dart
/// // Basic error handling
/// try {
///   await repository.saveInvestment(investment);
/// } catch (e, st) {
///   ErrorHandler.handle(e, st, context: context, showFeedback: true);
/// }
///
/// // Manual exception mapping
/// try {
///   await firebaseOperation();
/// } catch (e, st) {
///   final appException = ErrorHandler.mapException(e, st);
///   if (appException is NetworkException) {
///     // Handle network error specifically
///   }
/// }
///
/// // Show error without logging
/// ErrorHandler.showError(context, ValidationException('Invalid amount'));
/// ```
///
/// ## Privacy Guidelines
///
/// **NEVER log:**
/// - ❌ Exact investment amounts
/// - ❌ User names, emails, phone numbers
/// - ❌ Account numbers or sensitive IDs
/// - ❌ Transaction details
///
/// **Always log:**
/// - ✅ Error types and codes
/// - ✅ Stack traces (sanitized)
/// - ✅ User-facing error messages
/// - ✅ Technical error messages (no PII)
///
/// ## Error Reporting
///
/// - **Debug Mode**: Errors printed to console with 🔴 emoji
/// - **Production Mode**: Errors sent to Firebase Crashlytics
/// - **Validation Errors**: Not reported to Crashlytics (user input errors)
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';

/// Centralized error handler for the application.
///
/// See library documentation above for usage examples and exception hierarchy.
class ErrorHandler {
  /// Convert any exception to an [AppException].
  ///
  /// This method maps platform-specific exceptions (Firebase, network, etc.)
  /// to user-friendly [AppException] types with appropriate error messages.
  ///
  /// ## Parameters
  ///
  /// - [error]: The exception to map (can be any type)
  /// - [stackTrace]: Optional stack trace for debugging
  ///
  /// ## Returns
  ///
  /// - [AppException]: User-friendly exception with appropriate type
  ///
  /// ## Exception Mapping
  ///
  /// | Platform Exception | Mapped To | User Message |
  /// |-------------------|-----------|--------------|
  /// | `FirebaseAuthException` (user-cancelled) | `AuthException.signInCancelled()` | "Sign in was cancelled" |
  /// | `FirebaseAuthException` (network-request-failed) | `AuthException` | "Network error. Please check your connection." |
  /// | `FirebaseException` (unavailable) | `NetworkException.noConnection()` | "No internet connection" |
  /// | `FirebaseException` (deadline-exceeded) | `NetworkException.timeout()` | "Request timed out" |
  /// | `FirebaseException` (permission-denied) | `AuthException.notAuthenticated()` | "Not authenticated" |
  /// | `TimeoutException` | `NetworkException.timeout()` | "Request timed out" |
  /// | Any other exception | `DataException` | "An unexpected error occurred." |
  ///
  /// ## Example
  ///
  /// ```dart
  /// try {
  ///   await firebaseAuth.signInWithGoogle();
  /// } catch (e, st) {
  ///   final appException = ErrorHandler.mapException(e, st);
  ///
  ///   if (appException is AuthException) {
  ///     print('Auth error: ${appException.userMessage}');
  ///   } else if (appException is NetworkException) {
  ///     print('Network error: ${appException.userMessage}');
  ///   }
  /// }
  /// ```
  ///
  /// ## See Also
  ///
  /// - [handle] for automatic logging and UI feedback
  /// - [logError] for manual error logging
  static AppException mapException(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }

    // Firebase Auth errors
    if (error is FirebaseAuthException) {
      return _mapFirebaseAuthError(error, stackTrace);
    }

    // Firestore errors
    if (error is FirebaseException) {
      return _mapFirebaseError(error, stackTrace);
    }

    // Timeout errors
    if (error is TimeoutException) {
      return NetworkException.timeout(cause: error, stackTrace: stackTrace);
    }

    // Generic fallback
    return DataException(
      userMessage: 'An unexpected error occurred.',
      technicalMessage: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static AuthException _mapFirebaseAuthError(
    FirebaseAuthException error,
    StackTrace? stackTrace,
  ) {
    switch (error.code) {
      case 'user-cancelled':
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return AuthException.signInCancelled();
      case 'network-request-failed':
        return AuthException(
          userMessage: 'Network error. Please check your connection.',
          technicalMessage: 'Firebase auth network error: ${error.message}',
          cause: error,
          stackTrace: stackTrace,
        );
      case 'user-disabled':
        return AuthException(
          userMessage: 'This account has been disabled.',
          technicalMessage: 'User account disabled',
          cause: error,
          stackTrace: stackTrace,
        );
      default:
        return AuthException.signInFailed(cause: error, stackTrace: stackTrace);
    }
  }

  static AppException _mapFirebaseError(
    FirebaseException error,
    StackTrace? stackTrace,
  ) {
    switch (error.code) {
      case 'unavailable':
        return NetworkException.noConnection(
          cause: error,
          stackTrace: stackTrace,
        );
      case 'deadline-exceeded':
        return NetworkException.timeout(cause: error, stackTrace: stackTrace);
      case 'permission-denied':
      case 'unauthenticated':
        return AuthException.notAuthenticated();
      case 'not-found':
        return DataException.notFound('Resource', 'unknown');
      default:
        return DataException(
          userMessage: 'A data error occurred. Please try again.',
          technicalMessage: 'Firebase error [${error.code}]: ${error.message}',
          cause: error,
          stackTrace: stackTrace,
        );
    }
  }

  /// Log an error for debugging and crash reporting.
  ///
  /// Logs errors differently based on build mode:
  /// - **Debug Mode**: Prints formatted error to console with 🔴 emoji
  /// - **Production Mode**: Sends error to Firebase Crashlytics
  ///
  /// ## Parameters
  ///
  /// - [exception]: The [AppException] to log
  ///
  /// ## Privacy
  ///
  /// **Validation errors are NOT sent to Crashlytics** - they're user input errors,
  /// not app bugs. Only [AuthException], [NetworkException], and [DataException]
  /// are reported.
  ///
  /// ## Debug Output Format
  ///
  /// ```
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 🔴 ERROR: NetworkException
  /// User Message: No internet connection
  /// Technical: Firebase error [unavailable]: Network unavailable
  /// Cause: FirebaseException...
  /// Stack Trace:
  /// #0      ErrorHandler.handle (package:inv_tracker/...)
  /// ...
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// ```
  ///
  /// ## Example
  ///
  /// ```dart
  /// try {
  ///   await repository.saveInvestment(investment);
  /// } catch (e, st) {
  ///   final appException = ErrorHandler.mapException(e, st);
  ///   ErrorHandler.logError(appException); // Logs to console or Crashlytics
  /// }
  /// ```
  ///
  /// ## See Also
  ///
  /// - [handle] for automatic logging + UI feedback
  /// - [showError] for logging + snackbar display
  static void logError(AppException exception) {
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔴 ERROR: ${exception.runtimeType}');
      debugPrint('User Message: ${exception.userMessage}');
      debugPrint('Technical: ${exception.technicalMessage}');
      if (exception.cause != null) {
        debugPrint('Cause: ${exception.cause}');
      }
      if (exception.stackTrace != null) {
        debugPrint('Stack Trace:\n${exception.stackTrace}');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } else {
      // In production, only send to Crashlytics if shouldReport is true
      // This prevents spam from transient errors (network timeouts, validation errors)
      if (exception.shouldReport) {
        CrashlyticsService().recordError(
          exception.cause ?? exception,
          exception.stackTrace,
          reason: '${exception.runtimeType}: ${exception.technicalMessage}',
        );
      }
    }
  }

  /// Show error feedback to user via snackbar.
  ///
  /// Logs the error (see [logError]) and displays a user-friendly snackbar
  /// with the error message.
  ///
  /// ## Parameters
  ///
  /// - [context]: BuildContext for showing snackbar (must be mounted)
  /// - [exception]: The [AppException] to show
  ///
  /// ## Example
  ///
  /// ```dart
  /// try {
  ///   await repository.saveInvestment(investment);
  /// } catch (e, st) {
  ///   final appException = ErrorHandler.mapException(e, st);
  ///   if (context.mounted) {
  ///     ErrorHandler.showError(context, appException);
  ///   }
  /// }
  /// ```
  ///
  /// ## See Also
  ///
  /// - [handle] for automatic exception mapping + logging + UI feedback
  /// - [logError] for logging without UI feedback
  static void showError(BuildContext context, AppException exception) {
    logError(exception);
    AppFeedback.showError(context, exception.userMessage);
  }

  /// Handle an error: map, log, and optionally show UI feedback.
  ///
  /// This is the **recommended method** for error handling in the app.
  /// It combines [mapException], [logError], and optional UI feedback in one call.
  ///
  /// ## Parameters
  ///
  /// - [error]: The exception to handle (can be any type)
  /// - [stackTrace]: Optional stack trace for debugging
  /// - [context]: Optional BuildContext for showing snackbar
  /// - [showFeedback]: Whether to show snackbar (default: true)
  ///
  /// ## Returns
  ///
  /// - [AppException]: The mapped exception (useful for conditional handling)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Basic usage (with UI feedback)
  /// try {
  ///   await repository.saveInvestment(investment);
  /// } catch (e, st) {
  ///   ErrorHandler.handle(e, st, context: context, showFeedback: true);
  /// }
  ///
  /// // Without UI feedback (background operation)
  /// try {
  ///   await backgroundSync();
  /// } catch (e, st) {
  ///   ErrorHandler.handle(e, st, showFeedback: false);
  /// }
  ///
  /// // Conditional handling based on exception type
  /// try {
  ///   await repository.deleteInvestment(id);
  /// } catch (e, st) {
  ///   final appException = ErrorHandler.handle(e, st, context: context);
  ///
  ///   if (appException is NetworkException) {
  ///     // Retry logic for network errors
  ///     await retryOperation();
  ///   }
  /// }
  /// ```
  ///
  /// ## Best Practices
  ///
  /// - **Always check `context.mounted`** before passing context
  /// - **Use `showFeedback: false`** for background operations
  /// - **Return the exception** for conditional error handling
  ///
  /// ## See Also
  ///
  /// - [mapException] for manual exception mapping
  /// - [logError] for manual error logging
  /// - [showError] for manual UI feedback
  static AppException handle(
    Object error,
    StackTrace? stackTrace, {
    BuildContext? context,
    bool showFeedback = true,
  }) {
    final appException = mapException(error, stackTrace);
    logError(appException);

    if (showFeedback && context != null && context.mounted) {
      AppFeedback.showError(context, appException.userMessage);
    }

    return appException;
  }
}
