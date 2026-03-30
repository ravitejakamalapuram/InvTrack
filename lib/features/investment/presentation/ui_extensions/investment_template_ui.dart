import 'package:flutter/material.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';

/// UI-specific extensions for InvestmentTemplate domain model.
/// Keeps domain layer platform-agnostic by converting icon/color identifiers to Flutter types here.
/// Follows InvTrack Enterprise Rules #1.1 (Architecture - Layer Boundaries).

extension InvestmentTemplateUI on InvestmentTemplate {
  /// Convert icon codepoint to Flutter IconData
  IconData get icon {
    return IconData(
      iconCodePoint,
      fontFamily: 'MaterialIcons',
      matchTextDirection: true,
    );
  }

  /// Convert color value to Flutter Color
  Color get color {
    return Color(colorValue);
  }
}

