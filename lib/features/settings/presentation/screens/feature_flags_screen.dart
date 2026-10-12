/// Feature flags screen for release builds (#1012).
///
/// Opened from Settings after the app version was tapped five times in About.
/// It holds the feature-flag switches only: no demo-data seeding, no crash
/// button and no other data tool, which stay in Debug Settings (debug builds).
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/feature_flags_section.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class FeatureFlagsScreen extends StatelessWidget {
  const FeatureFlagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featureFlagsScreenTitle, style: AppTypography.h3),
      ),
      body: ListView(
        children: [
          const FeatureFlagsSection(),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
