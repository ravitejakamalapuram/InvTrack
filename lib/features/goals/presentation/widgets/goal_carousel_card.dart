/// Compact goal card for horizontal carousel display.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/text_scale.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Compact card for displaying a goal in horizontal carousel
class GoalCarouselCard extends ConsumerWidget {
  final GoalProgress progress;
  final double width;

  const GoalCarouselCard({super.key, required this.progress, this.width = 280});

  /// The height of the slot that holds a card, for the text size in [context].
  ///
  /// The card is three lines of text beside a 48dp icon, so it grows with the
  /// text size: measured on the real fonts it needs 39dp plus 45dp per unit of
  /// text scale, and this adds 2dp of slack. A fixed slot overflowed at large
  /// text. Never under 110dp, the height it was designed at.
  /// `test/layout/goal_carousel_height_test.dart` sweeps 1.0x to 2.0x text and
  /// fails when this falls behind the card.
  static double heightFor(BuildContext context) =>
      math.max(110.0, 41 + 45 * textScaleOf(context));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final goal = progress.goal;

    return SizedBox(
      width: width,
      child: GlassCard(
        onTap: () => context.push('/goals/${goal.id}'),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10, // Reduced from sm (12px) to 10px to fit in 110px
        ),
        borderRadius: 16,
        child: Row(
          children: [
            // Icon on left
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    goal.color.withValues(alpha: 0.15),
                    goal.color.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: goal.color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(goal.icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            SizedBox(width: AppSpacing.md),

            // Content on right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Goal name and percentage/completed badge in row. The badge
                  // takes at most 60% of the line and shrinks to fit, so the
                  // name keeps the rest and nothing overflows at large text.
                  LayoutBuilder(builder: (context, constraints) {
                  final badgeMaxWidth = constraints.maxWidth * 0.6;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          goal.name,
                          style: AppTypography.bodyLarge.copyWith(
                            color: isDark
                                ? Colors.white
                                : AppColors.neutral900Light,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      // Show "Completed" badge for achieved goals, percentage for others
                      if (progress.status == GoalStatus.achieved)
                        _BadgeCap(
                          maxWidth: badgeMaxWidth,
                          child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🎉',
                                style: TextStyle(fontSize: 10),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                l10n.goalCompleted,
                                style: AppTypography.caption.copyWith(
                                  color: isDark
                                      ? AppColors.successDark
                                      : AppColors.successLight,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ))
                      else
                        _BadgeCap(
                          maxWidth: badgeMaxWidth,
                          child: PrivacyMask(
                          useTextMask: true,
                          maskedText: '••%',
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: goal.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${progress.displayPercent}%',
                              style: AppTypography.caption.copyWith(
                                color: goal.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )),
                    ],
                  );
                  }),
                  SizedBox(height: AppSpacing.xxs),

                  // Progress amount
                  isPrivacyMode
                      ? MaskedAmountText(
                          text: progress.getProgressMessage(
                            currencySymbol,
                            locale,
                          ),
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? Colors.white54
                                : AppColors.neutral500Light,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          progress.getProgressMessage(currencySymbol, locale),
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? Colors.white54
                                : AppColors.neutral500Light,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  SizedBox(height: AppSpacing.xs),

                  // Progress bar with gradient
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Stack(
                      children: [
                        // Background bar
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        // Progress bar with gradient
                        FractionallySizedBox(
                          widthFactor: (progress.progressPercent / 100).clamp(
                            0.0,
                            1.0,
                          ),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  goal.color,
                                  goal.color.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: goal.color.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Holds a badge to [maxWidth]: a wider one is scaled down to fit, never cut
/// and never wider than the line it sits on.
class _BadgeCap extends StatelessWidget {
  const _BadgeCap({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerEnd,
        child: child,
      ),
    );
  }
}
