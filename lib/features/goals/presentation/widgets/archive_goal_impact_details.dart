/// The goals an archive changes, shown in the archive confirmation (A17).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Lists each goal in [impacts] with its progress before and after the
/// archive. Shows nothing when no goal changes.
///
/// Percentages are hidden in privacy mode, like the goal rings, and the
/// semantics follow what is on screen.
class ArchiveGoalImpactDetails extends ConsumerWidget {
  final List<GoalArchiveImpact> impacts;

  const ArchiveGoalImpactDetails({super.key, required this.impacts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (impacts.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : AppColors.neutral900Light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.archiveGoalImpactHeading,
            style: AppTypography.body.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final impact in impacts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              isPrivacyMode
                  ? l10n.archiveGoalImpactRowHidden(impact.goal.name)
                  : l10n.archiveGoalImpactRow(
                      impact.goal.name,
                      '${impact.before.displayPercent}%',
                      '${impact.after.displayPercent}%',
                    ),
              style: AppTypography.body.copyWith(color: color),
            ),
          ),
      ],
    );
  }
}
