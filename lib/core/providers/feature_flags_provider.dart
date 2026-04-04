/// Feature flags provider for enabling/disabling experimental features.
///
/// Feature flags allow gradual rollout of new features, A/B testing, and
/// controlled release. Flags are persisted and can be toggled via Debug Settings.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

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
    final prefs = ref.watch(sharedPreferencesProvider);
    final flags = <FeatureFlag, bool>{};

    for (final flag in FeatureFlag.values) {
      // Default: Portfolio Health Score is DISABLED (developer-only)
      // Other flags default to false
      final defaultValue = flag == FeatureFlag.portfolioHealthScore ? false : false;
      flags[flag] = prefs.getBool('$_prefPrefix${flag.key}') ?? defaultValue;
    }

    return flags;
  }

  /// Check if a specific feature is enabled
  bool isEnabled(FeatureFlag flag) {
    return state[flag] ?? false;
  }

  /// Toggle a specific feature flag
  Future<void> toggle(FeatureFlag flag) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final newValue = !(state[flag] ?? false);

    await prefs.setBool('$_prefPrefix${flag.key}', newValue);

    state = {...state, flag: newValue};
  }

  /// Set a specific feature flag to a value
  Future<void> setEnabled(FeatureFlag flag, bool enabled) async {
    if (state[flag] == enabled) return; // No change

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('$_prefPrefix${flag.key}', enabled);

    state = {...state, flag: enabled};
  }

  /// Enable all feature flags (for testing)
  Future<void> enableAll() async {
    final prefs = ref.read(sharedPreferencesProvider);

    for (final flag in FeatureFlag.values) {
      await prefs.setBool('$_prefPrefix${flag.key}', true);
    }

    state = {for (final flag in FeatureFlag.values) flag: true};
  }

  /// Disable all feature flags (reset to defaults)
  Future<void> disableAll() async {
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
