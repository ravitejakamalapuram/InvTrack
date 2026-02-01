import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final String currency;
  final String locale;
  final DateFormatPattern dateFormatPattern;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.currency = 'INR',
    this.locale = 'en_IN',
    this.dateFormatPattern = DateFormatPattern.dmy,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? currency,
    String? locale,
    DateFormatPattern? dateFormatPattern,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
      locale: locale ?? this.locale,
      dateFormatPattern: dateFormatPattern ?? this.dateFormatPattern,
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
    final locale = prefs.getString('locale') ?? 'en_IN';
    final dateFormatStr = prefs.getString('dateFormatPattern') ?? 'dmy';

    ThemeMode themeMode = ThemeMode.system;
    if (themeIndex != null) {
      themeMode = ThemeMode.values[themeIndex];
    }

    // Parse date format pattern
    final dateFormat = DateFormatPattern.values.firstWhere(
      (e) => e.name == dateFormatStr,
      orElse: () => DateFormatPattern.dmy,
    );

    return SettingsState(
      themeMode: themeMode,
      currency: currency,
      locale: locale,
      dateFormatPattern: dateFormat,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('themeMode', mode.index);
    state = state.copyWith(themeMode: mode);

    // Track analytics
    ref.read(analyticsServiceProvider).logThemeChanged(theme: mode.name);
  }

  Future<void> setCurrency(String currency) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('currency', currency);
    state = state.copyWith(currency: currency);

    // Track analytics
    ref.read(analyticsServiceProvider).logEvent(
      name: 'currency_changed',
      parameters: {'currency': currency},
    );
  }

  Future<void> setLocale(String locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('locale', locale);
    state = state.copyWith(locale: locale);

    // Track analytics
    ref.read(analyticsServiceProvider).logEvent(
      name: 'locale_changed',
      parameters: {'locale': locale},
    );
  }

  Future<void> setDateFormatPattern(DateFormatPattern pattern) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('dateFormatPattern', pattern.name);
    state = state.copyWith(dateFormatPattern: pattern);

    // Track analytics
    ref.read(analyticsServiceProvider).logEvent(
      name: 'date_format_changed',
      parameters: {'pattern': pattern.name},
    );
  }
}

/// Provider for storing the last file picker directory
/// This allows the file picker to open at the last used location
final lastFilePickerDirectoryProvider = Provider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('lastFilePickerDirectory');
});

/// Update the last file picker directory
void saveLastFilePickerDirectory(WidgetRef ref, String? path) {
  if (path == null || path.isEmpty) return;

  // Extract directory from file path
  final lastSlash = path.lastIndexOf('/');
  if (lastSlash > 0) {
    final directory = path.substring(0, lastSlash);

    // Persist to SharedPreferences (provider will be refreshed on next read)
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('lastFilePickerDirectory', directory);
  }
}
