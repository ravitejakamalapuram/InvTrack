import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Shown in place of the FIRE progress card when the portfolio fails to
/// load. It shows no FIRE number or amount: those would be computed from
/// missing data.
class FireLoadErrorCard extends StatelessWidget {
  /// Called when the user taps Retry.
  final VoidCallback onRetry;

  const FireLoadErrorCard({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.errorLight),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                l10n.fireProgressLoadError,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onRetry();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
