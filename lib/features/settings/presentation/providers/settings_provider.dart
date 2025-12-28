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

  SettingsState copyWith({ThemeMode? themeMode, String? currency}) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _loadSettings(prefs);
  }

  SettingsState _loadSettings(SharedPreferences prefs) {
    final themeIndex = prefs.getInt('themeMode');
    final currency = prefs.getString('currency') ?? 'INR';

    ThemeMode themeMode = ThemeMode.system;
    if (themeIndex != null) {
      themeMode = ThemeMode.values[themeIndex];
    }

    return SettingsState(themeMode: themeMode, currency: currency);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('themeMode', mode.index);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setCurrency(String currency) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('currency', currency);
    state = state.copyWith(currency: currency);
  }
}
