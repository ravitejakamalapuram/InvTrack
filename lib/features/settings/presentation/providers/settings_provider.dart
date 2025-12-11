import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final String currency;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.currency = 'INR',
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? currency,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final themeIndex = _prefs.getInt('themeMode');
    final currency = _prefs.getString('currency') ?? 'INR';

    ThemeMode themeMode = ThemeMode.system;
    if (themeIndex != null) {
      themeMode = ThemeMode.values[themeIndex];
    }

    state = SettingsState(
      themeMode: themeMode,
      currency: currency,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt('themeMode', mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setCurrency(String currency) async {
    await _prefs.setString('currency', currency);
    state = state.copyWith(currency: currency);
  }
}
