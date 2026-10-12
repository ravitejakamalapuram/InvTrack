// #1012: a release build can open the feature-flag toggles after the version
// is tapped five times in About. The unlock lives in memory only, ends when
// the signed-in account changes or signs out, and never opens data tools.
//
// Tests run in a debug build, so a release build is simulated by overriding
// developerToolsAvailableProvider with its release value (false).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/core/providers/feature_flag_unlock_provider.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _first = UserEntity(id: 'uid-1', email: '');
const _second = UserEntity(id: 'uid-2', email: '');

// The flag key a device stores when a flag was switched on in an older build.
const _storedOn = {'feature_flag_first_investment_flow': true};

void main() {
  late StreamController<UserEntity?> auth;

  Future<ProviderContainer> release({
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    auth = StreamController<UserEntity?>.broadcast();
    addTearDown(auth.close);
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        developerToolsAvailableProvider.overrideWithValue(false),
        authStateProvider.overrideWith((ref) => auth.stream),
      ],
    );
    addTearDown(c.dispose);
    // Keep the auth stream and the flags alive like the running app does.
    c.listen(authStateProvider, (_, _) {});
    c.listen(featureFlagsProvider, (_, _) {});
    c.listen(featureFlagUnlockProvider, (_, _) {});
    auth.add(_first);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  group('release build', () {
    test('starts locked: only the code default counts', () async {
      final c = await release(stored: _storedOn);

      expect(c.read(featureFlagUnlockProvider), isFalse);
      expect(c.read(featureFlagOverridesAllowedProvider), isFalse);
      expect(c.read(isFirstInvestmentFlowEnabledProvider), isFalse);
    });

    test('unlocking lets a value stored on the device decide', () async {
      final c = await release(stored: _storedOn);

      c.read(featureFlagUnlockProvider.notifier).toggle();

      expect(c.read(featureFlagUnlockProvider), isTrue);
      expect(c.read(featureFlagOverridesAllowedProvider), isTrue);
      expect(c.read(isFirstInvestmentFlowEnabledProvider), isTrue);
    });

    test('a toggle made while unlocked is saved and applied', () async {
      final c = await release();
      c.read(featureFlagUnlockProvider.notifier).toggle();

      await c
          .read(featureFlagsProvider.notifier)
          .setEnabled(FeatureFlag.firstInvestmentFlow, true);

      expect(c.read(isFirstInvestmentFlowEnabledProvider), isTrue);
    });

    test('a second unlock gesture locks it again', () async {
      final c = await release(stored: _storedOn);
      final notifier = c.read(featureFlagUnlockProvider.notifier);

      notifier.toggle();
      notifier.toggle();

      expect(c.read(featureFlagUnlockProvider), isFalse);
      expect(c.read(isFirstInvestmentFlowEnabledProvider), isFalse);
    });

    test('signing out ends the unlock', () async {
      final c = await release(stored: _storedOn);
      c.read(featureFlagUnlockProvider.notifier).toggle();

      auth.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(featureFlagUnlockProvider), isFalse);
      expect(c.read(isFirstInvestmentFlowEnabledProvider), isFalse);
    });

    test('switching to another account ends the unlock', () async {
      final c = await release(stored: _storedOn);
      c.read(featureFlagUnlockProvider.notifier).toggle();

      auth.add(_second);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(featureFlagUnlockProvider), isFalse);
      expect(c.read(isFirstInvestmentFlowEnabledProvider), isFalse);
    });

    test('is not written to the device', () async {
      final c = await release();
      final prefs = c.read(sharedPreferencesProvider);

      c.read(featureFlagUnlockProvider.notifier).toggle();

      expect(
        prefs.getKeys().where((k) => k.contains('unlock')),
        isEmpty,
        reason: 'The unlock must not survive an app restart',
      );
      expect(prefs.getKeys().where((k) => k.startsWith('debug_mode')), isEmpty);
    });

    test('never turns on the data tools or debug mode', () async {
      final c = await release(stored: {'debug_mode_enabled': true});

      c.read(featureFlagUnlockProvider.notifier).toggle();

      expect(c.read(developerToolsAvailableProvider), isFalse);
      expect(c.read(debugModeProvider), isFalse);
    });
  });

  test('debug build: overrides stay allowed without an unlock (control)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    expect(c.read(featureFlagUnlockProvider), isFalse);
    expect(c.read(featureFlagOverridesAllowedProvider), isTrue);
  });
}
