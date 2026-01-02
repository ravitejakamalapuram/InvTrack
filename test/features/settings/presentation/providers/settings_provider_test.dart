import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsState', () {
    test('has correct default values', () {
      const state = SettingsState();
      expect(state.themeMode, ThemeMode.system);
      expect(state.currency, 'INR');
    });

    test('copyWith preserves unchanged values', () {
      const original = SettingsState(
        themeMode: ThemeMode.dark,
        currency: 'USD',
      );
      final copied = original.copyWith();

      expect(copied.themeMode, ThemeMode.dark);
      expect(copied.currency, 'USD');
    });

    test('copyWith updates only specified values', () {
      const original = SettingsState(
        themeMode: ThemeMode.light,
        currency: 'EUR',
      );

      final updatedTheme = original.copyWith(themeMode: ThemeMode.dark);
      expect(updatedTheme.themeMode, ThemeMode.dark);
      expect(updatedTheme.currency, 'EUR');

      final updatedCurrency = original.copyWith(currency: 'GBP');
      expect(updatedCurrency.themeMode, ThemeMode.light);
      expect(updatedCurrency.currency, 'GBP');
    });
  });

  group('SettingsNotifier', () {
    late ProviderContainer container;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state uses default values when no prefs exist', () {
      final state = container.read(settingsProvider);

      expect(state.themeMode, ThemeMode.system);
      expect(state.currency, 'INR');
    });

    test('initial state loads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': ThemeMode.dark.index,
        'currency': 'USD',
      });
      final newPrefs = await SharedPreferences.getInstance();

      final newContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(newPrefs),
        ],
      );
      addTearDown(newContainer.dispose);

      final state = newContainer.read(settingsProvider);

      expect(state.themeMode, ThemeMode.dark);
      expect(state.currency, 'USD');
    });

    test('setThemeMode updates state and persists', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setThemeMode(ThemeMode.dark);

      final state = container.read(settingsProvider);
      expect(state.themeMode, ThemeMode.dark);
      expect(prefs.getInt('themeMode'), ThemeMode.dark.index);
    });

    test('setThemeMode works for all theme modes', () async {
      final notifier = container.read(settingsProvider.notifier);

      for (final mode in ThemeMode.values) {
        await notifier.setThemeMode(mode);
        final state = container.read(settingsProvider);
        expect(state.themeMode, mode);
      }
    });

    test('setCurrency updates state and persists', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setCurrency('EUR');

      final state = container.read(settingsProvider);
      expect(state.currency, 'EUR');
      expect(prefs.getString('currency'), 'EUR');
    });

    test('setCurrency works for all supported currencies', () async {
      final notifier = container.read(settingsProvider.notifier);
      const currencies = ['INR', 'USD', 'EUR', 'GBP', 'JPY'];

      for (final currency in currencies) {
        await notifier.setCurrency(currency);
        final state = container.read(settingsProvider);
        expect(state.currency, currency);
      }
    });
  });
}

