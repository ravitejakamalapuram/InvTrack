/// Feature flags provider for enabling/disabling experimental features.
///
/// A feature ships by changing its [FeatureFlag.defaultEnabled] in code in a
/// release. Release builds always use that code default. Debug builds may
/// override it with a value stored from Debug Settings, so production never
/// depends on the debug menu or on values left on a device.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/core/providers/feature_flag_unlock_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

/// Individual feature flags
enum FeatureFlag {
  /// Portfolio Health Score feature (Week 1-3 implementation)
  /// - Dashboard card with circular progress
  /// - Historical trend chart
  /// - Details screen with component breakdown
  /// - Auto-save to Firestore
  portfolioHealthScore('portfolio_health_score', 'Portfolio Health Score'),

  /// Reports Tab (Developer Feature)
  /// - Smart Insights with auto-generated investment alerts
  /// - DIY Report Builder with custom configurations
  /// - Weekly/Monthly summaries and analytics
  /// - Off until the FY report is real (A60); most report cards are stubs
  reportsTab('reports_tab', 'Reports Tab'),

  /// Future: Predictive Risk Alerts
  predictiveAlerts('predictive_alerts', 'Predictive Risk Alerts'),

  /// Future: Peer Benchmarking
  peerBenchmarking('peer_benchmarking', 'Peer Benchmarking'),

  /// Future: AI Assistant
  aiAssistant('ai_assistant', 'AI Assistant'),

  /// Income Guardian: expected-payment tracking and alerts.
  /// - Off until something generates expected cash flows (founder decision,
  ///   2026-10-02). While off, its Settings tile, the investment "Upcoming"
  ///   tab and its background services are all hidden or stopped.
  incomeGuardian('income_guardian', 'Income Guardian'),

  /// Play in-app review prompt after a first recorded INCOME or RETURN.
  /// - One-shot per install, gated on a genuine success moment
  /// - On by default (A42)
  reviewPrompt('review_prompt', 'Play Review Prompt', defaultEnabled: true),

  /// Dated valuations of open investments (#941).
  /// - Snapshots in users/{uid}/valuations, mirrored into currentValue
  /// - Opening baselines for investments without history
  /// - Off until the screens ship; flag off reads and writes the single
  ///   current value exactly as before
  valuationSnapshots('valuation_snapshots', 'Dated Valuations'),

  /// Reusable custom labels for investments of type Other (#936).
  /// - Optional "Custom type" field on the investment form
  /// - Saved labels come back as suggestions
  /// - Off by default; saved labels are still exported, imported and deleted
  ///   with the account while it is off
  customInvestmentTypes('custom_investment_types', 'Custom Investment Types'),

  /// First Investment Flow (A40, #783).
  /// - Add Investment takes an optional amount and start date, and saves the
  ///   investment with its first cash flow in one write
  /// - Off by default; it ships by changing the default in a release PR, and
  ///   release builds read only that default
  firstInvestmentFlow('first_investment_flow', 'First Investment Flow'),

  /// Base currency prompt and profile sync (A31, #772).
  /// - A new user confirms a currency proposed from their phone's country
  /// - The base currency is kept on the profile and restored on a new device
  /// - Off by default; it ships by changing the default in a release PR, and
  ///   release builds read only that default. Read once per sign-in, so a
  ///   debug toggle applies from the next sign-in or start
  baseCurrencyPrompt('base_currency_prompt', 'Base Currency Prompt'),

  /// Notification permission asked after the first investment with a maturity
  /// date instead of at sign-in (A45, #788).
  /// - Off by default; flag off keeps the ask at sign-in. It ships by changing
  ///   the default in a release PR
  maturityReminderPrompt(
    'maturity_reminder_prompt',
    'Maturity Reminder Prompt',
  ),

  /// Monthly recap screen and notification (reports plan, phase 1). Off
  /// until a release PR turns it on.
  monthlyRecap('monthly_recap', 'Monthly Recap');

  const FeatureFlag(this.key, this.displayName, {this.defaultEnabled = false});

  final String key;
  final String displayName;

  /// Whether the feature is on in this release. Change it here, in a release
  /// PR, to ship or withdraw a feature.
  final bool defaultEnabled;
}

/// Whether values stored on the device (set from the feature-flag toggles)
/// may change a flag. In release builds only the code default counts, unless
/// the version-tap unlock is on for the signed-in account (#1012).
/// Overridable so tests can exercise the release-build behaviour.
final featureFlagOverridesAllowedProvider = Provider<bool>(
  (ref) =>
      ref.watch(developerToolsAvailableProvider) ||
      ref.watch(featureFlagUnlockProvider),
);

/// Provider for feature flag states
final featureFlagsProvider =
    NotifierProvider<FeatureFlagsNotifier, Map<FeatureFlag, bool>>(
      FeatureFlagsNotifier.new,
    );

/// Notifier for managing feature flag states
class FeatureFlagsNotifier extends Notifier<Map<FeatureFlag, bool>> {
  static const _prefPrefix = 'feature_flag_';

  @override
  Map<FeatureFlag, bool> build() {
    if (!ref.watch(featureFlagOverridesAllowedProvider)) {
      return {for (final flag in FeatureFlag.values) flag: flag.defaultEnabled};
    }
    final prefs = ref.watch(sharedPreferencesProvider);
    return {
      for (final flag in FeatureFlag.values)
        flag: prefs.getBool('$_prefPrefix${flag.key}') ?? flag.defaultEnabled,
    };
  }

  bool get _overridesAllowed => ref.read(featureFlagOverridesAllowedProvider);

  /// Check if a specific feature is enabled
  bool isEnabled(FeatureFlag flag) {
    return state[flag] ?? false;
  }

  /// Toggle a specific feature flag
  Future<void> toggle(FeatureFlag flag) async {
    if (!_overridesAllowed) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final newValue = !(state[flag] ?? false);

    await prefs.setBool('$_prefPrefix${flag.key}', newValue);

    state = {...state, flag: newValue};
  }

  /// Set a specific feature flag to a value
  Future<void> setEnabled(FeatureFlag flag, bool enabled) async {
    if (!_overridesAllowed) return;
    if (state[flag] == enabled) return; // No change

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('$_prefPrefix${flag.key}', enabled);

    state = {...state, flag: enabled};
  }

  /// Enable all feature flags (for testing)
  Future<void> enableAll() async {
    if (!_overridesAllowed) return;
    final prefs = ref.read(sharedPreferencesProvider);

    for (final flag in FeatureFlag.values) {
      await prefs.setBool('$_prefPrefix${flag.key}', true);
    }

    state = {for (final flag in FeatureFlag.values) flag: true};
  }

  /// Disable all feature flags (reset to defaults)
  Future<void> disableAll() async {
    if (!_overridesAllowed) return;
    final prefs = ref.read(sharedPreferencesProvider);

    for (final flag in FeatureFlag.values) {
      await prefs.setBool('$_prefPrefix${flag.key}', false);
    }

    state = {for (final flag in FeatureFlag.values) flag: false};
  }
}

/// Convenience provider for checking if Portfolio Health Score is enabled
final isPortfolioHealthEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.portfolioHealthScore] ?? false,
    ),
  );
});

/// Convenience provider for checking if Predictive Alerts is enabled
final isPredictiveAlertsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.predictiveAlerts] ?? false,
    ),
  );
});

/// Convenience provider for checking if Peer Benchmarking is enabled
final isPeerBenchmarkingEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.peerBenchmarking] ?? false,
    ),
  );
});

/// Convenience provider for checking if AI Assistant is enabled
final isAiAssistantEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.aiAssistant] ?? false,
    ),
  );
});

/// Convenience provider for checking if Reports Tab is enabled
final isReportsTabEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.reportsTab] ?? false,
    ),
  );
});

/// Convenience provider for checking if Income Guardian is enabled
final isIncomeGuardianEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.incomeGuardian] ?? false,
    ),
  );
});

/// Convenience provider for checking if the Play review prompt is enabled
final isReviewPromptEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.reviewPrompt] ?? false,
    ),
  );
});

/// Convenience provider for checking if dated valuations are enabled
final isValuationSnapshotsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.valuationSnapshots] ?? false,
    ),
  );
});

/// Convenience provider for checking if reusable custom investment types are
/// enabled (#936)
final isCustomInvestmentTypesEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.customInvestmentTypes] ?? false,
    ),
  );
});

/// Convenience provider for checking if the first investment flow (A40) is
/// enabled
final isFirstInvestmentFlowEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.firstInvestmentFlow] ?? false,
    ),
  );
});

/// Convenience provider for checking if the base currency prompt (A31) is
/// enabled
final isBaseCurrencyPromptEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.baseCurrencyPrompt] ?? false,
    ),
  );
});

/// Convenience provider for the maturity reminder prompt (A45)
final isMaturityReminderPromptEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.maturityReminderPrompt] ?? false,
    ),
  );
});

/// Convenience provider for checking if the monthly recap is enabled
final isMonthlyRecapEnabledProvider = Provider<bool>((ref) {
  return ref.watch(
    featureFlagsProvider.select(
      (flags) => flags[FeatureFlag.monthlyRecap] ?? false,
    ),
  );
});
