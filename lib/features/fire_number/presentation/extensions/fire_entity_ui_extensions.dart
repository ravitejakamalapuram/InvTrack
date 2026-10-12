import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// UI-specific extensions for FIRE domain entities.
/// Keeps domain entities framework-agnostic by moving Color and IconData here.

/// Extension providing UI-specific properties for [FireType].
extension FireTypeUI on FireType {
  /// Icon representing this FIRE type
  IconData get icon {
    switch (this) {
      case FireType.lean:
        return Icons.eco_outlined;
      case FireType.regular:
        return Icons.balance_outlined;
      case FireType.fat:
        return Icons.diamond_outlined;
      case FireType.coast:
        return Icons.beach_access_outlined;
      case FireType.barista:
        return Icons.coffee_outlined;
    }
  }
}

/// Extension providing UI-specific properties for [FireProgressStatus].
extension FireProgressStatusUI on FireProgressStatus {
  /// Color representing this status (light mode)
  /// Uses the app's design system colors for consistency
  Color get color => colorForBrightness(Brightness.light);

  /// Color representing this status (dark mode)
  Color get colorDark => colorForBrightness(Brightness.dark);

  /// The color of this status for the theme it is painted in.
  Color colorForBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case FireProgressStatus.notStarted:
      case FireProgressStatus.notEnoughHistory:
        return isDark ? AppColors.neutral400Dark : AppColors.neutral500Light;
      case FireProgressStatus.behind:
        // Rich Amber #F59E0B, brighter Amber #FBBF24 in dark
        return isDark ? AppColors.warningDark : AppColors.warningLight;
      case FireProgressStatus.onTrack:
        // Teal/Cyan #0EA5E9, Cyan #38BDF8 in dark
        return isDark ? AppColors.accentDark : AppColors.accentLight;
      case FireProgressStatus.ahead:
      case FireProgressStatus.achieved:
        // Emerald #10B981, #34D399 in dark
        return isDark ? AppColors.successDark : AppColors.successLight;
      case FireProgressStatus.coasting:
        return AppColors.graphTeal; // Teal #14B8A6 in both themes
    }
  }

  /// The status colour for a tint (10 to 30% fills) and for the purple hero
  /// card: the original, brighter hue. It differs from [colorForBrightness]
  /// only for the two green statuses in light, whose text colour got deeper to
  /// read on white. A tint of the deeper green puts the label on it under
  /// 4.5:1, and on the purple hero the deeper green would be 1.0:1.
  Color vividColorForBrightness(Brightness brightness) {
    if (this == FireProgressStatus.ahead ||
        this == FireProgressStatus.achieved) {
      return brightness == Brightness.dark
          ? AppColors.successDark
          : AppColors.successTintLight;
    }
    return colorForBrightness(brightness);
  }

  /// Icon representing this status
  IconData get icon {
    switch (this) {
      case FireProgressStatus.notStarted:
        return Icons.hourglass_empty;
      case FireProgressStatus.behind:
        return Icons.trending_down;
      case FireProgressStatus.onTrack:
        return Icons.trending_flat;
      case FireProgressStatus.ahead:
        return Icons.trending_up;
      case FireProgressStatus.achieved:
        return Icons.celebration;
      case FireProgressStatus.coasting:
        return Icons.beach_access;
      case FireProgressStatus.notEnoughHistory:
        return Icons.hourglass_top;
    }
  }

  /// Whether this status is considered positive (on track or better)
  bool get isPositive {
    switch (this) {
      case FireProgressStatus.notStarted:
      case FireProgressStatus.behind:
      case FireProgressStatus.notEnoughHistory:
        return false;
      case FireProgressStatus.onTrack:
      case FireProgressStatus.ahead:
      case FireProgressStatus.achieved:
      case FireProgressStatus.coasting:
        return true;
    }
  }

  /// Status label for badges, from the app's strings.
  String label(AppLocalizations l10n) {
    switch (this) {
      case FireProgressStatus.notStarted:
        return l10n.fireStatusNotStarted;
      case FireProgressStatus.behind:
        return l10n.fireStatusBehind;
      case FireProgressStatus.onTrack:
        return l10n.fireStatusOnTrack;
      case FireProgressStatus.ahead:
        return l10n.fireStatusAhead;
      case FireProgressStatus.achieved:
        return l10n.fireStatusAchieved;
      case FireProgressStatus.coasting:
        return l10n.fireStatusCoasting;
      case FireProgressStatus.notEnoughHistory:
        return l10n.fireStatusNotEnoughHistory;
    }
  }

  /// Short subtitle for status display
  String shortSubtitle(AppLocalizations l10n) {
    switch (this) {
      case FireProgressStatus.notStarted:
        return l10n.fireStatusShortNotStarted;
      case FireProgressStatus.behind:
        return l10n.fireStatusShortBehind;
      case FireProgressStatus.onTrack:
        return l10n.fireStatusShortOnTrack;
      case FireProgressStatus.ahead:
        return l10n.fireStatusShortAhead;
      case FireProgressStatus.achieved:
        return l10n.fireStatusShortAchieved;
      case FireProgressStatus.coasting:
        return l10n.fireStatusShortCoasting;
      case FireProgressStatus.notEnoughHistory:
        return l10n.fireStatusShortNotEnoughHistory;
    }
  }
}
