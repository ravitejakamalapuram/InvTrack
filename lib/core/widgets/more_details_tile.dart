import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';

/// A collapsed tile that holds the optional fields of a form (A40, #783).
///
/// The header is a button at least 64dp high: a tinted icon, the [title], a
/// one-line [summary] of what is inside, and an expand arrow. The caller owns
/// [expanded], so the answer survives a rebuild, and keeps the controllers of
/// the fields in [children], so closing the tile loses nothing the user typed.
/// The children exist only while it is open. They bring their own spacing; the
/// tile adds one form gap above the first.
class MoreDetailsTile extends StatelessWidget {
  const MoreDetailsTile({
    super.key,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onChanged,
    required this.children,
  });

  final String title;
  final String summary;
  final bool expanded;
  final ValueChanged<bool> onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.neutral400Dark : AppColors.neutral500Light;
    final strong = isDark ? Colors.white : AppColors.neutral900Light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: title,
          hint: summary,
          excludeSemantics: true,
          onTap: () => onChanged(!expanded),
          child: GlassCard(
            onTap: () => onChanged(!expanded),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: isDark
                          ? AppColors.primaryDark
                          : AppColors.primaryLight,
                      size: AppSizes.iconMd,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w600,
                            color: strong,
                          ),
                        ),
                        Text(
                          summary,
                          style: AppTypography.small.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: muted,
                    size: AppSizes.iconMd,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.formFieldSpacing),
                    ...children,
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
