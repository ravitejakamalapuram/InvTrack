import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// "Also in N goals": the goal's investments also count towards other goals,
/// so the same money is counted more than once.
///
/// On a list card the chip says it short ("Also in 2 goals", [compact]); on the
/// goal details screen it has room for "Also counted in 2 other goals". A
/// screen reader always hears the long sentence. The text wraps inside the
/// chip: it is never cut in the middle of a word.
class SharedGoalsChip extends StatelessWidget {
  final int count;

  /// Whether to show the short text, as a list card does.
  final bool compact;

  const SharedGoalsChip({super.key, required this.count, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final text = l10n.goalAlsoCountedIn(count);
    final shown = compact ? l10n.goalAlsoInGoals(count) : text;
    final color = isDark ? AppColors.neutral400Dark : AppColors.neutral500Light;
    return Semantics(
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: Container(
          // Tighter on a card, where a column beside the ring leaves little
          // room: at large text the longest word still has to fit.
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  shown,
                  style: AppTypography.small.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
