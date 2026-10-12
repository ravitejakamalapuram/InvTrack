/// The feature-flag toggles, shared by Debug Settings (debug builds) and the
/// Feature flags screen that a release build opens after the version-tap
/// unlock (#1012). It holds no data tools.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Section with one toggle per experimental feature.
class FeatureFlagsSection extends ConsumerWidget {
  const FeatureFlagsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final featureFlags = ref.watch(featureFlagsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SettingsSection(
      title: l10n.experimentalFeatures,
      children: [
        // Portfolio Health Score feature flag
        SettingsToggleTile(
          icon: Icons.favorite,
          iconColor: Colors.red,
          title: l10n.portfolioHealthScoreFeature,
          subtitle: l10n.portfolioHealthScoreSubtitle,
          value: featureFlags[FeatureFlag.portfolioHealthScore] ?? false,
          onChanged: (value) async {
            try {
              await ref
                  .read(featureFlagsProvider.notifier)
                  .toggle(FeatureFlag.portfolioHealthScore);

              // Verify the toggle succeeded
              final newState = ref.read(featureFlagsProvider)[FeatureFlag.portfolioHealthScore] ?? false;

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newState
                          ? l10n.portfolioHealthScoreEnabled
                          : l10n.portfolioHealthScoreDisabled,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e, stackTrace) {
              if (context.mounted) {
                ErrorHandler.handle(e, stackTrace, context: context);
              }
            }
          },
        ),

        // Reports Tab feature flag
        SettingsToggleTile(
          icon: Icons.assessment,
          iconColor: Colors.purple,
          title: l10n.reportsTabFeature,
          subtitle: l10n.reportsTabSubtitle,
          value: featureFlags[FeatureFlag.reportsTab] ?? false,
          onChanged: (value) async {
            try {
              await ref
                  .read(featureFlagsProvider.notifier)
                  .toggle(FeatureFlag.reportsTab);

              // Verify the toggle succeeded
              final newState = ref.read(featureFlagsProvider)[FeatureFlag.reportsTab] ?? false;

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newState
                          ? l10n.reportsTabEnabled
                          : l10n.reportsTabDisabled,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e, stackTrace) {
              if (context.mounted) {
                ErrorHandler.handle(e, stackTrace, context: context);
              }
            }
          },
        ),

        // Income Guardian feature flag
        SettingsToggleTile(
          icon: Icons.shield_outlined,
          iconColor: isDark ? AppColors.successDark : AppColors.successLight,
          title: l10n.incomeGuardianFeature,
          subtitle: l10n.incomeGuardianFeatureSubtitle,
          value: featureFlags[FeatureFlag.incomeGuardian] ?? false,
          onChanged: (value) async {
            try {
              await ref
                  .read(featureFlagsProvider.notifier)
                  .toggle(FeatureFlag.incomeGuardian);

              // Verify the toggle succeeded
              final newState = ref.read(featureFlagsProvider)[FeatureFlag.incomeGuardian] ?? false;

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newState
                          ? l10n.incomeGuardianFeatureEnabled
                          : l10n.incomeGuardianFeatureDisabled,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e, stackTrace) {
              if (context.mounted) {
                ErrorHandler.handle(e, stackTrace, context: context);
              }
            }
          },
        ),

        // Reusable custom labels for Other investments (#936)
        SettingsToggleTile(
          icon: Icons.label_outline_rounded,
          iconColor: AppColors.primaryLight,
          title: l10n.customInvestmentTypesFeature,
          subtitle: l10n.customInvestmentTypesFeatureSubtitle,
          value: featureFlags[FeatureFlag.customInvestmentTypes] ?? false,
          onChanged: (value) async {
            try {
              await ref
                  .read(featureFlagsProvider.notifier)
                  .toggle(FeatureFlag.customInvestmentTypes);

              final newState =
                  ref.read(featureFlagsProvider)[FeatureFlag
                      .customInvestmentTypes] ??
                  false;

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newState
                          ? l10n.customInvestmentTypesFeatureEnabled
                          : l10n.customInvestmentTypesFeatureDisabled,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e, stackTrace) {
              if (context.mounted) {
                ErrorHandler.handle(e, stackTrace, context: context);
              }
            }
          },
        ),

        // Play review prompt feature flag
        SettingsToggleTile(
          icon: Icons.star_outline,
          iconColor: Colors.amber,
          title: FeatureFlag.reviewPrompt.displayName,
          subtitle: 'Ask for a Play Store review after the first recorded exit',
          value: featureFlags[FeatureFlag.reviewPrompt] ?? false,
          onChanged: (value) async {
            try {
              await ref
                  .read(featureFlagsProvider.notifier)
                  .toggle(FeatureFlag.reviewPrompt);
            } catch (e, stackTrace) {
              if (context.mounted) {
                ErrorHandler.handle(e, stackTrace, context: context);
              }
            }
          },
        ),

        // Dated valuations feature flag (#941)
        SettingsToggleTile(
          icon: Icons.event_note,
          iconColor: Colors.teal,
          title: l10n.valuationSnapshotsFeature,
          subtitle: l10n.valuationSnapshotsSubtitle,
          value: featureFlags[FeatureFlag.valuationSnapshots] ?? false,
          onChanged: (value) async {
            try {
              await ref
                  .read(featureFlagsProvider.notifier)
                  .toggle(FeatureFlag.valuationSnapshots);

              final newState =
                  ref.read(
                    featureFlagsProvider,
                  )[FeatureFlag.valuationSnapshots] ??
                  false;

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newState
                          ? l10n.valuationSnapshotsEnabled
                          : l10n.valuationSnapshotsDisabled,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e, stackTrace) {
              if (context.mounted) {
                ErrorHandler.handle(e, stackTrace, context: context);
              }
            }
          },
        ),

        // First investment flow feature flag (A40, #783)
        SettingsToggleTile(
          icon: Icons.add_card_rounded,
          iconColor: Colors.indigo,
          title: l10n.firstInvestmentFlowFeature,
          subtitle: l10n.firstInvestmentFlowSubtitle,
          value: featureFlags[FeatureFlag.firstInvestmentFlow] ?? false,
          onChanged: (value) async {
            try {
              await ref
                  .read(featureFlagsProvider.notifier)
                  .toggle(FeatureFlag.firstInvestmentFlow);

              final newState =
                  ref.read(
                    featureFlagsProvider,
                  )[FeatureFlag.firstInvestmentFlow] ??
                  false;

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newState
                          ? l10n.firstInvestmentFlowEnabled
                          : l10n.firstInvestmentFlowDisabled,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e, stackTrace) {
              if (context.mounted) {
                ErrorHandler.handle(e, stackTrace, context: context);
              }
            }
          },
        ),

        // Future features (disabled - coming soon)
        Opacity(
          opacity: 0.5,
          child: IgnorePointer(
            child: Column(
              children: [
                SettingsToggleTile(
                  icon: Icons.warning_amber,
                  iconColor: Colors.orange,
                  title: FeatureFlag.predictiveAlerts.displayName,
                  subtitle: 'Risk alerts (Coming soon)',
                  value: false,
                  onChanged: (_) {}, // Disabled
                ),
                SettingsToggleTile(
                  icon: Icons.people,
                  iconColor: Colors.blue,
                  title: FeatureFlag.peerBenchmarking.displayName,
                  subtitle: 'Compare with community (Coming soon)',
                  value: false,
                  onChanged: (_) {}, // Disabled
                ),
                SettingsToggleTile(
                  icon: Icons.smart_toy,
                  iconColor: Colors.purple,
                  title: FeatureFlag.aiAssistant.displayName,
                  subtitle: 'Chat-based investment advisor (Coming soon)',
                  value: false,
                  onChanged: (_) {}, // Disabled
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
