import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Extension on BuildContext for safe navigation operations
extension SafeNavigationExtension on BuildContext {
  /// Safely pops the current route if possible.
  /// If there's nothing to pop, navigates to the fallback route (default: '/').
  void safePop([String fallbackRoute = '/']) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackRoute);
    }
  }

  /// Safely pops with a result if possible.
  /// If there's nothing to pop, navigates to the fallback route.
  void safePopWithResult<T>(T result, [String fallbackRoute = '/']) {
    if (canPop()) {
      pop(result);
    } else {
      go(fallbackRoute);
    }
  }
}

