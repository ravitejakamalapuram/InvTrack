import 'package:flutter/material.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';

/// UI-specific extensions for Goal domain entities.
/// Keeps domain entities framework-agnostic by moving Color and IconData here.
/// Follows InvTrack Enterprise Rules #1.1 (Architecture - Layer Boundaries).

/// Extension providing UI-specific properties for [GoalType].
extension GoalTypeUI on GoalType {
  /// Icon representing this goal type
  IconData get icon {
    switch (this) {
      case GoalType.targetAmount:
        return Icons.savings_rounded;
      case GoalType.targetDate:
        return Icons.event_rounded;
      case GoalType.incomeTarget:
        return Icons.trending_up_rounded;
    }
  }

  /// Color representing this goal type
  Color get color {
    switch (this) {
      case GoalType.targetAmount:
        return const Color(0xFF3B82F6); // Blue
      case GoalType.targetDate:
        return const Color(0xFFF59E0B); // Amber
      case GoalType.incomeTarget:
        return const Color(0xFF10B981); // Emerald
    }
  }
}

/// Extension providing UI-specific properties for [GoalStatus].
extension GoalStatusUI on GoalStatus {
  /// Color representing this goal status
  Color get color {
    switch (this) {
      case GoalStatus.notStarted:
        return const Color(0xFF6B7280); // Gray
      case GoalStatus.onTrack:
        return const Color(0xFF3B82F6); // Blue
      case GoalStatus.ahead:
        return const Color(0xFF10B981); // Emerald
      case GoalStatus.behind:
        return const Color(0xFFF59E0B); // Amber
      case GoalStatus.achieved:
        return const Color(0xFF10B981); // Emerald
      case GoalStatus.archived:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// Icon representing this goal status
  IconData get icon {
    switch (this) {
      case GoalStatus.notStarted:
        return Icons.hourglass_empty_rounded;
      case GoalStatus.onTrack:
        return Icons.trending_flat_rounded;
      case GoalStatus.ahead:
        return Icons.trending_up_rounded;
      case GoalStatus.behind:
        return Icons.trending_down_rounded;
      case GoalStatus.achieved:
        return Icons.check_circle_rounded;
      case GoalStatus.archived:
        return Icons.archive_rounded;
    }
  }
}

/// Extension providing UI-specific properties for [GoalEntity].
extension GoalEntityUI on GoalEntity {
  /// Color object from stored colorValue
  Color get color => Color(colorValue);
}

/// Default goal colors for selection (presentation layer)
class GoalColors {
  static const List<Color> available = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFFEF4444), // Red
  ];

  static Color get defaultColor => available[0];
}

