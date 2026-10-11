// A40 (#783) PR-2: the add form asks firstInvestmentFormEnabledProvider
// whether to show the new form. Reading the flag needs shared preferences; the
// older add-form tests pump the screen without them, and a screen that cannot
// read the flag must show today's form, never crash.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      featureFlagOverridesAllowedProvider.overrideWithValue(true),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('without shared preferences the answer is off, not an error', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(firstInvestmentFormEnabledProvider), isFalse);
  });

  test('flag on in the stored flags: the new form', () async {
    final container = await _container({
      'feature_flag_first_investment_flow': true,
    });

    expect(container.read(firstInvestmentFormEnabledProvider), isTrue);
  });

  test('flag off, stored or not: today\'s form', () async {
    final stored = await _container({
      'feature_flag_first_investment_flow': false,
    });
    final notStored = await _container({});

    expect(stored.read(firstInvestmentFormEnabledProvider), isFalse);
    expect(notStored.read(firstInvestmentFormEnabledProvider), isFalse);
  });

  test('it follows the flag when it changes', () async {
    final container = await _container({});
    final seen = <bool>[];
    container.listen(
      firstInvestmentFormEnabledProvider,
      (_, next) => seen.add(next),
    );

    await container
        .read(featureFlagsProvider.notifier)
        .setEnabled(FeatureFlag.firstInvestmentFlow, true);
    await pumpEventQueue();

    expect(seen, [true]);
  });

  test('a release build reads the code default, which is off', () async {
    SharedPreferences.setMockInitialValues({
      'feature_flag_first_investment_flow': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagOverridesAllowedProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(firstInvestmentFormEnabledProvider), isFalse);
  });
}
