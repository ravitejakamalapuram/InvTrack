/// Settings section with the two privacy switches.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/privacy/privacy_choices.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class PrivacySettingsSection extends ConsumerWidget {
  const PrivacySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SettingsSection(
      title: l10n.privacySectionTitle,
      children: [
        SettingsToggleTile(
          icon: Icons.insights,
          title: l10n.shareUsageData,
          subtitle: l10n.shareUsageDataSubtitle,
          value: ref.watch(analyticsSharingProvider),
          onChanged: (value) =>
              ref.read(analyticsSharingProvider.notifier).setEnabled(value),
        ),
        SettingsToggleTile(
          icon: Icons.bug_report_outlined,
          title: l10n.sendCrashReports,
          subtitle: l10n.sendCrashReportsSubtitle,
          value: ref.watch(crashReportsProvider),
          onChanged: (value) =>
              ref.read(crashReportsProvider.notifier).setEnabled(value),
        ),
      ],
    );
  }
}
