import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Extension on BuildContext for safe navigation operations.
///
/// Prevents "Nothing to pop" crashes when using GoRouter's pop() method
/// on screens that may be opened directly via deep link or as root route.
extension SafeNavigationExtension on BuildContext {
  /// Safely pops the current route if possible.
  ///
  /// If there's nothing to pop (e.g., screen was opened as root route),
  /// navigates to the [fallbackRoute] instead (default: '/').
  ///
  /// Example:
  /// ```dart
  /// // Instead of context.pop() which may crash
  /// context.safePop();
  ///
  /// // With custom fallback
  /// context.safePop('/dashboard');
  /// ```
  void safePop([String fallbackRoute = '/']) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackRoute);
    }
  }

  /// Safely pops with a result if possible.
  ///
  /// If there's nothing to pop, navigates to the [fallbackRoute].
  ///
  /// **Important:** When falling back to [fallbackRoute], the [result] is
  /// discarded since `go()` does not support passing results. Ensure your
  /// calling code handles the case where no result is returned.
  ///
  /// Example:
  /// ```dart
  /// // Pop with result
  /// context.safePopWithResult(selectedItem);
  ///
  /// // With custom fallback (result discarded if fallback is used)
  /// context.safePopWithResult(data, '/home');
  /// ```
  void safePopWithResult<T>(T result, [String fallbackRoute = '/']) {
    if (canPop()) {
      pop(result);
    } else {
      go(fallbackRoute);
    }
  }
}
