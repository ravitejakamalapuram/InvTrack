import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// UI-specific extensions for Investment domain entities.
/// Keeps domain entities framework-agnostic by moving Color and IconData here.
/// Follows InvTrack Enterprise Rules #1.1 (Architecture - Layer Boundaries).

/// The name to show for [investment]'s type (#936): the custom label of an
/// Other investment that has one while the feature flag is on, otherwise the
/// built-in type's name. The flag is read only for an investment that has a
/// label. Grouping, filtering and the type breakdown keep using the built-in
/// type, so they do not call this.
String investmentTypeName(WidgetRef ref, InvestmentEntity investment) =>
    investment.hasCustomTypeLabel &&
        ref.watch(isCustomInvestmentTypesEnabledProvider)
    ? investment.typeLabel
    : investment.type.displayName;

/// [fill] at 10% over the card of the theme, opaque.
Color _tintOver(Color fill, Brightness brightness) => Color.alphaBlend(
  fill.withValues(alpha: 0.1),
  brightness == Brightness.dark ? AppColors.cardDark : AppColors.cardLight,
);

// The purple and the blue of four investment types and of the certificate
// document type, deepened so that a white label on them reaches 4.5:1 (4.62
// and 4.64). The bright #8B5CF6 and #3B82F6 were 4.23:1 and 3.68:1 with white;
// the purple is 4.13:1 with ink, so no label colour could reach 4.5:1 on it.
const Color _deepPurple = Color(0xFF8555EF);
const Color _deepBlue = Color(0xFF2A70E3);

/// Extension providing UI-specific properties for [InvestmentType].
extension InvestmentTypeUI on InvestmentType {
  /// Icon representing this investment type
  IconData get icon {
    switch (this) {
      case InvestmentType.p2pLending:
        return Icons.handshake_rounded;
      case InvestmentType.fixedDeposit:
        return Icons.account_balance_rounded;
      case InvestmentType.bonds:
        return Icons.description_rounded;
      case InvestmentType.realEstate:
        return Icons.home_rounded;
      case InvestmentType.privateEquity:
        return Icons.business_center_rounded;
      case InvestmentType.angelInvesting:
        return Icons.rocket_launch_rounded;
      case InvestmentType.chitFunds:
        return Icons.group_rounded;
      case InvestmentType.gold:
        return Icons.monetization_on_rounded;
      case InvestmentType.crypto:
        return Icons.currency_bitcoin_rounded;
      case InvestmentType.mutualFunds:
        return Icons.pie_chart_rounded;
      case InvestmentType.stocks:
        return Icons.show_chart_rounded;
      case InvestmentType.invoiceDiscounting:
        return Icons.receipt_long_rounded;
      case InvestmentType.financing:
        return Icons.payments_rounded;
      case InvestmentType.other:
        return Icons.attach_money_rounded;
    }
  }

  /// Color representing this investment type: the fill of its tile and of its
  /// selected chip, and the source of its tint. A label or an icon on it takes
  /// [AppColors.onFill]. Text and icons on the pale tint take [textColor].
  Color get color {
    switch (this) {
      case InvestmentType.p2pLending:
        return _deepBlue;
      case InvestmentType.fixedDeposit:
        return const Color(0xFF10B981); // Emerald
      case InvestmentType.bonds:
        return const Color(0xFFF59E0B); // Amber
      case InvestmentType.realEstate:
        return const Color(0xFFEC4899); // Pink
      case InvestmentType.privateEquity:
        return _deepPurple;
      case InvestmentType.angelInvesting:
        return const Color(0xFF06B6D4); // Cyan
      case InvestmentType.chitFunds:
        return const Color(0xFFF97316); // Orange
      case InvestmentType.gold:
        return const Color(0xFFFFD700); // Gold
      case InvestmentType.crypto:
        return _deepPurple;
      case InvestmentType.mutualFunds:
        return _deepBlue;
      case InvestmentType.stocks:
        return const Color(0xFF10B981); // Emerald
      case InvestmentType.invoiceDiscounting:
        return const Color(0xFF0EA5E9); // Sky Blue
      case InvestmentType.financing:
        return const Color(0xFF14B8A6); // Teal
      case InvestmentType.other:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// The pale fill behind this type's name or icon: [color] at 10% over the
  /// card of the theme, opaque, so the text on it keeps the same ratio on the
  /// card, on the page and on a sheet. [textColor] reaches 4.5:1 on it.
  Color tintColor(Brightness brightness) => _tintOver(color, brightness);

  /// The colour of this type's name, and of its icon, on [tintColor]: 4.5:1 or
  /// more in both themes. It keeps the hue of [color], deeper in light, where
  /// the fill itself is 1.4:1 to 4.3:1 on its tint; in dark most fills already
  /// read, so five lighter variants stand in for the rest.
  Color textColor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (this) {
      case InvestmentType.p2pLending:
      case InvestmentType.mutualFunds:
        return dark ? const Color(0xFF4087FB) : const Color(0xFF2168DA);
      case InvestmentType.privateEquity:
      case InvestmentType.crypto:
        return dark ? const Color(0xFF976EFF) : const Color(0xFF7D4CE5);
      case InvestmentType.other:
        return dark ? const Color(0xFF818997) : const Color(0xFF666D7A);
      case InvestmentType.fixedDeposit:
      case InvestmentType.stocks:
        return dark ? color : const Color(0xFF007E56);
      case InvestmentType.bonds:
        return dark ? color : const Color(0xFF9D6300);
      case InvestmentType.realEstate:
        return dark ? color : const Color(0xFFCA227D);
      case InvestmentType.angelInvesting:
        return dark ? color : const Color(0xFF00798E);
      case InvestmentType.chitFunds:
        return dark ? color : const Color(0xFFB64F00);
      case InvestmentType.gold:
        return dark ? color : const Color(0xFF867000);
      case InvestmentType.invoiceDiscounting:
        return dark ? color : const Color(0xFF0075A8);
      case InvestmentType.financing:
        return dark ? color : const Color(0xFF007D70);
    }
  }
}

/// Extension providing UI-specific properties for [RiskLevel].
extension RiskLevelUI on RiskLevel {
  /// Icon representing this risk level
  IconData get icon {
    switch (this) {
      case RiskLevel.low:
        return Icons.shield_rounded;
      case RiskLevel.medium:
        return Icons.speed_rounded;
      case RiskLevel.high:
        return Icons.warning_amber_rounded;
      case RiskLevel.veryHigh:
        return Icons.whatshot_rounded;
    }
  }

  /// Color representing this risk level
  Color get color {
    switch (this) {
      case RiskLevel.low:
        return const Color(0xFF10B981); // Green
      case RiskLevel.medium:
        return const Color(0xFFF59E0B); // Amber
      case RiskLevel.high:
        return const Color(0xFFF97316); // Orange
      case RiskLevel.veryHigh:
        return const Color(0xFFEF4444); // Red
    }
  }
}

/// Extension providing UI-specific properties for [InterestPayoutMode].
extension InterestPayoutModeUI on InterestPayoutMode {
  /// Icon representing this payout mode
  IconData get icon {
    switch (this) {
      case InterestPayoutMode.cumulative:
        return Icons.trending_up_rounded;
      case InterestPayoutMode.periodic:
        return Icons.repeat_rounded;
      case InterestPayoutMode.atMaturity:
        return Icons.event_available_rounded;
    }
  }
}

/// Extension providing UI-specific properties for [IncomeFrequency].
extension IncomeFrequencyUI on IncomeFrequency {
  /// Icon for this frequency
  IconData get icon {
    switch (this) {
      case IncomeFrequency.monthly:
        return Icons.calendar_month_rounded;
      case IncomeFrequency.quarterly:
        return Icons.event_repeat_rounded;
      case IncomeFrequency.semiAnnual:
        return Icons.date_range_rounded;
      case IncomeFrequency.annual:
        return Icons.calendar_today_rounded;
    }
  }

  /// Color for this frequency
  Color get color {
    switch (this) {
      case IncomeFrequency.monthly:
        return const Color(0xFF3B82F6); // Blue
      case IncomeFrequency.quarterly:
        return const Color(0xFF10B981); // Emerald
      case IncomeFrequency.semiAnnual:
        return const Color(0xFFF59E0B); // Amber
      case IncomeFrequency.annual:
        return const Color(0xFF8B5CF6); // Purple
    }
  }
}

/// Extension providing UI-specific properties for [DocumentType].
extension DocumentTypeUI on DocumentType {
  /// Icon representing this document type
  IconData get icon {
    switch (this) {
      case DocumentType.receipt:
        return Icons.receipt_long_rounded;
      case DocumentType.contract:
        return Icons.description_rounded;
      case DocumentType.statement:
        return Icons.summarize_rounded;
      case DocumentType.certificate:
        return Icons.workspace_premium_rounded;
      case DocumentType.image:
        return Icons.image_rounded;
      case DocumentType.other:
        return Icons.attach_file_rounded;
    }
  }

  /// Color representing this document type
  Color get color {
    switch (this) {
      case DocumentType.receipt:
        return const Color(0xFF10B981); // Emerald
      case DocumentType.contract:
        return const Color(0xFF3B82F6); // Blue
      case DocumentType.statement:
        return const Color(0xFFF59E0B); // Amber
      case DocumentType.certificate:
        return _deepPurple;
      case DocumentType.image:
        return const Color(0xFFEC4899); // Pink
      case DocumentType.other:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// The pale fill behind this type's name or icon: [color] at 10% over the
  /// card of the theme, opaque, so [textColor] keeps the same ratio wherever
  /// it sits.
  Color tintColor(Brightness brightness) => _tintOver(color, brightness);

  /// The colour of this type's name, and of its icon, on [tintColor]: 4.5:1 or
  /// more in both themes. It keeps the hue of [color], deeper in light, where
  /// the fill itself is 1.9:1 to 4.3:1 on its tint; in dark most fills already
  /// read, so three lighter variants stand in for the rest. The same values as
  /// the investment types that share a fill.
  Color textColor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (this) {
      case DocumentType.receipt:
        return dark ? color : const Color(0xFF007E56);
      case DocumentType.contract:
        return dark ? const Color(0xFF4087FB) : const Color(0xFF2168DA);
      case DocumentType.statement:
        return dark ? color : const Color(0xFF9D6300);
      case DocumentType.certificate:
        return dark ? const Color(0xFF976EFF) : const Color(0xFF7D4CE5);
      case DocumentType.image:
        return dark ? color : const Color(0xFFCA227D);
      case DocumentType.other:
        return dark ? const Color(0xFF818997) : const Color(0xFF666D7A);
    }
  }
}

/// Extension providing UI-specific properties for [CashFlowType].
/// Moved from domain layer to maintain platform-agnostic domain (Rule 1.1).
extension CashFlowTypeUI on CashFlowType {
  /// Returns the color associated with this cash flow type
  Color get color {
    switch (this) {
      case CashFlowType.invest:
        return const Color(0xFF3B82F6); // Blue
      case CashFlowType.returnFlow:
        return const Color(0xFF10B981); // Emerald
      case CashFlowType.income:
        return const Color(0xFFF59E0B); // Amber
      case CashFlowType.fee:
        return const Color(0xFFEC4899); // Pink
    }
  }

  /// Returns the icon data for this cash flow type
  IconData get iconData {
    switch (this) {
      case CashFlowType.invest:
        return Icons.arrow_upward_rounded;
      case CashFlowType.returnFlow:
        return Icons.arrow_downward_rounded;
      case CashFlowType.income:
        return Icons.payments_rounded;
      case CashFlowType.fee:
        return Icons.receipt_long_rounded;
    }
  }
}
