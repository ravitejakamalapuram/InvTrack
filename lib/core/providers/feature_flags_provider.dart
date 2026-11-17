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

  /// Future: Predictive Risk Alerts
  predictiveAlerts('predictive_alerts', 'Predictive Risk Alerts'),

  /// Future: Peer Benchmarking
  peerBenchmarking('peer_benchmarking', 'Peer Benchmarking'),

  /// Future: AI Assistant
  aiAssistant('ai_assistant', 'AI Assistant');

  const FeatureFlag(this.key, this.displayName);

  final String key;
  final String displayName;

  /// Whether the feature is on in this release. Change it here, in a release
  /// PR, to ship or withdraw a feature.
  bool get defaultEnabled => false;
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
