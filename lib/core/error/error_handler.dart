import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';

/// Centralized error handler for the application.
/// Converts platform exceptions to app-specific exceptions and handles reporting.
class ErrorHandler {
  /// Convert any exception to an AppException
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
        return NetworkException.noConnection(cause: error, stackTrace: stackTrace);
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

  /// Log an error for debugging (and future crash reporting)
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
    }

    // Future enhancement: Add Firebase Crashlytics integration for production error reporting.
    // See: https://firebase.google.com/docs/crashlytics/get-started?platform=flutter
  }

  /// Show error feedback to user via snackbar
  static void showError(BuildContext context, AppException exception) {
    logError(exception);
    AppFeedback.showError(context, exception.userMessage);
  }

  /// Handle an error: log it and optionally show UI feedback
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

