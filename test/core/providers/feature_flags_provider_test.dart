// A42: a feature ships by changing its code default in a release. Values
// stored on the device (from Debug Settings) must never decide what a
// release build shows.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container({
  required bool overridesAllowed,
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      featureFlagOverridesAllowedProvider.overrideWithValue(overridesAllowed),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('code defaults (nothing stored)', () {
    for (final overridesAllowed in [true, false]) {
      final build = overridesAllowed ? 'debug' : 'release';

      test('$build: Health Score stays hidden', () async {
        final c = await _container(overridesAllowed: overridesAllowed);
        expect(c.read(isPortfolioHealthEnabledProvider), isFalse);
      });
    }
  });

  group('values stored on the device', () {
    const stored = <String, Object>{
      'feature_flag_portfolio_health_score': true,
    };

    test('release ignores them and uses the code defaults', () async {
      final c = await _container(overridesAllowed: false, stored: stored);
      expect(c.read(isPortfolioHealthEnabledProvider), isFalse);
    });

    test('release ignores a toggle too', () async {
      final c = await _container(overridesAllowed: false);
      await c
          .read(featureFlagsProvider.notifier)
          .setEnabled(FeatureFlag.portfolioHealthScore, true);
      expect(c.read(isPortfolioHealthEnabledProvider), isFalse);
    });

    test('debug builds still honour them (Debug Settings)', () async {
      final c = await _container(overridesAllowed: true, stored: stored);
      expect(c.read(isPortfolioHealthEnabledProvider), isTrue);
    });
  });
}
