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

      test('$build: the review prompt is on', () async {
        final c = await _container(overridesAllowed: overridesAllowed);
        expect(c.read(isReviewPromptEnabledProvider), isTrue);
      });

      test('$build: custom investment types (#936) stay hidden', () async {
        final c = await _container(overridesAllowed: overridesAllowed);
        expect(c.read(isCustomInvestmentTypesEnabledProvider), isFalse);
        expect(FeatureFlag.customInvestmentTypes.defaultEnabled, isFalse);
        expect(
          FeatureFlag.customInvestmentTypes.key,
          'custom_investment_types',
        );
      });

      test(
        '$build: Income Guardian, Reports and Health Score stay hidden',
        () async {
          final c = await _container(overridesAllowed: overridesAllowed);
          expect(c.read(isIncomeGuardianEnabledProvider), isFalse);
          expect(c.read(isReportsTabEnabledProvider), isFalse);
          expect(c.read(isPortfolioHealthEnabledProvider), isFalse);
        },
      );
    }
  });

  group('values stored on the device', () {
    const stored = <String, Object>{
      'feature_flag_review_prompt': false,
      'feature_flag_income_guardian': true,
      'feature_flag_reports_tab': true,
      'feature_flag_portfolio_health_score': true,
      'feature_flag_custom_investment_types': true,
    };

    test('release ignores them and uses the code defaults', () async {
      final c = await _container(overridesAllowed: false, stored: stored);
      expect(c.read(isReviewPromptEnabledProvider), isTrue);
      expect(c.read(isIncomeGuardianEnabledProvider), isFalse);
      expect(c.read(isReportsTabEnabledProvider), isFalse);
      expect(c.read(isPortfolioHealthEnabledProvider), isFalse);
      expect(c.read(isCustomInvestmentTypesEnabledProvider), isFalse);
    });

    test('release ignores a toggle too', () async {
      final c = await _container(overridesAllowed: false);
      await c
          .read(featureFlagsProvider.notifier)
          .setEnabled(FeatureFlag.incomeGuardian, true);
      await c
          .read(featureFlagsProvider.notifier)
          .setEnabled(FeatureFlag.customInvestmentTypes, true);
      await c
          .read(featureFlagsProvider.notifier)
          .toggle(FeatureFlag.reviewPrompt);
      expect(c.read(isIncomeGuardianEnabledProvider), isFalse);
      expect(c.read(isCustomInvestmentTypesEnabledProvider), isFalse);
      expect(c.read(isReviewPromptEnabledProvider), isTrue);
    });

    test('debug builds still honour them (Debug Settings)', () async {
      final c = await _container(overridesAllowed: true, stored: stored);
      expect(c.read(isReviewPromptEnabledProvider), isFalse);
      expect(c.read(isIncomeGuardianEnabledProvider), isTrue);
      expect(c.read(isReportsTabEnabledProvider), isTrue);
      expect(c.read(isPortfolioHealthEnabledProvider), isTrue);
      expect(c.read(isCustomInvestmentTypesEnabledProvider), isTrue);
    });
  });
}
