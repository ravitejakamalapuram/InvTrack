/// Debug mode provider for enabling/disabling developer features.
///
/// Debug mode is a hidden feature that can be activated by tapping the version
/// number 7 times on the About screen. When enabled, it reveals developer tools
/// and diagnostics in the Settings screen.
///
/// This is separate from Flutter's kDebugMode (build configuration) - this is
/// a runtime toggle that works in both debug and release builds.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

/// Provider for debug mode state.
///
/// When true, shows developer tools in Settings screen.
/// When false, hides all debug-related UI.
final debugModeProvider = NotifierProvider<DebugModeNotifier, bool>(
  DebugModeNotifier.new,
);

/// Notifier for managing debug mode state.
///
/// Debug mode is persisted in SharedPreferences and survives app restarts.
/// It can be toggled via:
/// 1. Tapping version number 7 times on About screen
/// 2. Using the toggle in Debug Settings screen
class DebugModeNotifier extends Notifier<bool> {
  static const _prefKey = 'debug_mode_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Toggle debug mode on/off.
  ///
  /// Returns the new state (true if enabled, false if disabled).
  Future<bool> toggle() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final newValue = !state;
    await prefs.setBool(_prefKey, newValue);
    state = newValue;
    return newValue;
  }

  /// Set debug mode to a specific value.
  ///
  /// Use this when you want to explicitly enable or disable debug mode
  /// rather than toggling it.
  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return; // No change needed
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_prefKey, enabled);
    state = enabled;
  }
}
