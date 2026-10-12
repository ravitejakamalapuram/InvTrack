import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';

/// The one place that says which colour a portfolio-health tier is painted in.
/// The card, the details screen, its component bars and the trend chart each
/// kept their own copy, and three of the four light colours were under 4.5:1
/// on white (green 3.77, amber 2.15, orange 2.80).
extension ScoreTierUI on ScoreTier {
  /// The colour of this tier's word, number, icon and ring on the card of the
  /// theme it is painted in. In light the green, amber and red are the deeper
  /// text colours of the palette and the orange is the deeper orange of the
  /// chit-fund type text (4.9:1 on the card). In dark the colours are the ones
  /// the screen always used, except Poor: its #EF4444 was 4.46:1 on its own
  /// pale tint, so it is the dark red of the palette.
  Color textColor(bool isDark) {
    switch (this) {
      case ScoreTier.excellent:
        return isDark ? AppColors.graphEmerald : AppColors.successLight;
      case ScoreTier.good:
        return isDark ? AppColors.warningDark : AppColors.warningTextLight;
      case ScoreTier.fair:
        return isDark ? const Color(0xFFFB923C) : const Color(0xFFB64F00);
      case ScoreTier.poor:
        return isDark ? AppColors.dangerDark : AppColors.dangerLight;
    }
  }

  /// The colour the pale fills behind a score are made of (the badge behind a
  /// component's number, the track of its bar): the bright hue the tier had
  /// before its text deepened. A tint of [textColor] itself puts the number on
  /// it under 4.5:1.
  Color tintColor(bool isDark) {
    switch (this) {
      case ScoreTier.excellent:
        return isDark ? AppColors.graphEmerald : AppColors.successTintLight;
      case ScoreTier.good:
        return isDark ? AppColors.warningDark : AppColors.warningLight;
      case ScoreTier.fair:
        return isDark ? const Color(0xFFFB923C) : AppColors.graphOrange;
      case ScoreTier.poor:
        return isDark ? AppColors.dangerDark : AppColors.dangerTintLight;
    }
  }
}
