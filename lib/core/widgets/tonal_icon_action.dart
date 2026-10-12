/// The tonal chip used for every app bar action on the main screens.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';

/// Where an action sits.
enum TonalIconActionTone {
  /// On the app bar surface: a 10% tint, solid when selected.
  surface,

  /// On a coloured hero: a 20% black scrim with a white icon; on a hero whose
  /// colour is given as [TonalIconAction.heroFill], the foreground that reads
  /// better on it and a 20% scrim of the opposite tone.
  onHero,
}

/// A 36px tonal chip inside a 48px tap box, labelled for screen readers.
///
/// The [tooltip] is required: it is the semantics label and the long-press
/// hint, so an action without a label cannot be written. In an app bar the
/// first and the last chip sit on [AppSpacing.screenEdge] and only the
/// transparent box hangs into the gutter:
///
/// ```dart
/// SliverAppBar(
///   leading: TonalIconAction.leading(TonalIconAction(...)),
///   leadingWidth: AppSpacing.appBarLeadingWidth,
///   actions: [TonalIconAction(...)],
///   actionsPadding: const EdgeInsetsDirectional.only(
///     end: AppSpacing.appBarTrailingGap,
///   ),
/// )
/// ```
class TonalIconAction extends StatelessWidget {
  const TonalIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.tone = TonalIconActionTone.surface,
    this.heroFill,
  });

  final IconData icon;

  /// The semantics label and tooltip. Localise it.
  final String tooltip;
  final VoidCallback onPressed;

  /// Shows the action as switched on (a mode is active, a filter is set).
  final bool selected;
  final TonalIconActionTone tone;

  /// The colour of the hero an [TonalIconActionTone.onHero] action sits on. The
  /// icon is white or ink, whichever has the higher contrast on it
  /// ([AppColors.onFill]), and the chip is a 20% scrim of the other tone. Left
  /// out, the action is a black 20% scrim with a white icon.
  final Color? heroFill;

  /// Key of the visible 36px chip, for tests that measure it.
  static const chipKey = ValueKey<String>('tonal-action-chip');

  /// Puts [action] in the leading slot of an app bar so its chip starts on the
  /// screen edge. Pair it with `leadingWidth: AppSpacing.appBarLeadingWidth`.
  static Widget leading(Widget action) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.appBarTrailingGap,
        ),
        child: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill;
    final Color ink;
    switch (tone) {
      case TonalIconActionTone.onHero:
        final hero = heroFill;
        ink = hero == null ? Colors.white : AppColors.onFill(hero);
        fill = (ink == Colors.white ? Colors.black : Colors.white).withValues(
          alpha: 0.2,
        );
      case TonalIconActionTone.surface:
        if (selected) {
          fill = AppColors.primaryLight;
          ink = Colors.white;
        } else {
          fill = (isDark ? Colors.white : AppColors.primaryLight).withValues(
            alpha: 0.1,
          );
          ink = isDark ? Colors.white : AppColors.neutral700Light;
        }
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        fixedSize: const Size.square(AppSizes.minTouchTarget),
        minimumSize: const Size.square(AppSizes.minTouchTarget),
      ),
      icon: Container(
        key: chipKey,
        width: AppSizes.tonalActionChip,
        height: AppSizes.tonalActionChip,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: AppSizes.borderRadiusMd,
        ),
        child: Icon(icon, color: ink, size: AppSizes.iconSm),
      ),
    );
  }
}
