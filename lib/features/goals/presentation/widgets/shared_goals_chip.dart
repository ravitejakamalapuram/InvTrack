import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// "Also counted in N other goals": the goal's investments also count
/// towards other goals, so the same money is counted more than once.
class SharedGoalsChip extends StatelessWidget {
  final int count;

  const SharedGoalsChip({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = AppLocalizations.of(context).goalAlsoCountedIn(count);
    final color = isDark ? AppColors.neutral400Dark : AppColors.neutral500Light;
    return Semantics(
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
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
                  text,
                  style: AppTypography.small.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
