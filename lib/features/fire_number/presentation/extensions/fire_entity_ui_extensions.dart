import 'package:flutter/material.dart';
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
  /// Color representing this status
  Color get color {
    switch (this) {
      case FireProgressStatus.notStarted:
        return Colors.grey;
      case FireProgressStatus.behind:
        return Colors.orange;
      case FireProgressStatus.onTrack:
        return Colors.blue;
      case FireProgressStatus.ahead:
        return Colors.green;
      case FireProgressStatus.achieved:
        return Colors.green;
      case FireProgressStatus.coasting:
        return Colors.teal;
    }
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
}

