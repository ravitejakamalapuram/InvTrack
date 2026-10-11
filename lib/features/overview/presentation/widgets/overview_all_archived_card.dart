/// Overview card for an account whose investments are all archived (A17).
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Shown instead of the first-run onboarding when every investment is
/// archived: the totals are empty because archived investments are left out
/// of them, not because the account is new.
class OverviewAllArchivedCard extends StatelessWidget {
  /// Opens the Investments tab, where the archived ones are.
  final VoidCallback onViewInvestments;

  const OverviewAllArchivedCard({super.key, required this.onViewInvestments});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.archive_rounded,
                color: isDark ? Colors.white70 : AppColors.neutral500Light,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.overviewAllArchivedTitle,
                    style: AppTypography.h4.copyWith(
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.overviewAllArchivedBody,
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onViewInvestments,
              child: Text(l10n.overviewAllArchivedAction),
            ),
          ),
        ],
      ),
    );
  }
}
