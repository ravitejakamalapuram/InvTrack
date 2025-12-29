/// Privacy mode provider for hiding/showing sensitive financial data.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

/// Key for storing privacy mode preference in SharedPreferences.
const _privacyModeKey = 'privacy_mode_enabled';

/// Notifier for managing privacy mode state.
/// Privacy mode hides all sensitive financial numbers throughout the app.
class PrivacyModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_privacyModeKey) ?? false;
  }

  /// Toggle privacy mode on/off.
  Future<void> toggle() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final newValue = !state;
    await prefs.setBool(_privacyModeKey, newValue);
    state = newValue;
  }

  /// Set privacy mode to a specific value.
  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_privacyModeKey, enabled);
    state = enabled;
  }
}

/// Provider for privacy mode state.
/// When true, sensitive financial data should be hidden.
final privacyModeProvider = NotifierProvider<PrivacyModeNotifier, bool>(
  PrivacyModeNotifier.new,
);

/// Convenience provider to check if privacy mode is active.
/// Use this in widgets to determine whether to show masked or actual values.
final isPrivacyModeActiveProvider = Provider<bool>((ref) {
  return ref.watch(privacyModeProvider);
});

