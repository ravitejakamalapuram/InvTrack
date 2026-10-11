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

  /// The typical rate as the rate field's hint spells it: "7" for 7.0, "6.5"
  /// for 6.5. Null when the template has none.
  String? get typicalRateText {
    final rate = typicalRate;
    if (rate == null) return null;
    return rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toString();
  }
}
