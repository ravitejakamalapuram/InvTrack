import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

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
  Color get color {
    switch (this) {
      case FireProgressStatus.notStarted:
        return AppColors.neutral500Light;
      case FireProgressStatus.behind:
        return AppColors.warningLight; // Rich Amber #F59E0B
      case FireProgressStatus.onTrack:
        return AppColors.accentLight; // Teal/Cyan #0EA5E9
      case FireProgressStatus.ahead:
        return AppColors.successLight; // Emerald #10B981
      case FireProgressStatus.achieved:
        return AppColors.successLight; // Emerald #10B981
      case FireProgressStatus.coasting:
        return AppColors.graphTeal; // Teal #14B8A6
    }
  }

  /// Color representing this status (dark mode)
  Color get colorDark {
    switch (this) {
      case FireProgressStatus.notStarted:
        return AppColors.neutral400Dark;
      case FireProgressStatus.behind:
        return AppColors.warningDark; // Brighter Amber #FBBF24
      case FireProgressStatus.onTrack:
        return AppColors.accentDark; // Cyan #38BDF8
      case FireProgressStatus.ahead:
        return AppColors.successDark; // Emerald #34D399
      case FireProgressStatus.achieved:
        return AppColors.successDark; // Emerald #34D399
      case FireProgressStatus.coasting:
        return AppColors.graphTeal; // Teal #14B8A6
    }
  }

  /// Get the appropriate color based on brightness
  Color colorForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? colorDark : color;
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
    }
  }

  /// Whether this status is considered positive (on track or better)
  bool get isPositive {
    switch (this) {
      case FireProgressStatus.notStarted:
      case FireProgressStatus.behind:
        return false;
      case FireProgressStatus.onTrack:
      case FireProgressStatus.ahead:
      case FireProgressStatus.achieved:
      case FireProgressStatus.coasting:
        return true;
    }
  }

  /// Short subtitle for status display
  String get shortSubtitle {
    switch (this) {
      case FireProgressStatus.notStarted:
        return 'Start investing';
      case FireProgressStatus.behind:
        return 'Needs focus';
      case FireProgressStatus.onTrack:
        return 'On track';
      case FireProgressStatus.ahead:
        return 'Ahead';
      case FireProgressStatus.achieved:
        return 'Achieved!';
      case FireProgressStatus.coasting:
        return 'Coasting';
    }
  }
}

