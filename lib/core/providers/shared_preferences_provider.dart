/// Core provider for SharedPreferences dependency injection.
///
/// This provider is placed in core/ to avoid circular dependencies and
/// allow both core/analytics and features/settings to depend on it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for SharedPreferences instance.
///
/// This is initialized early in main.dart and provides access to
/// SharedPreferences throughout the app without circular dependencies.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main.dart',
  ),
);
