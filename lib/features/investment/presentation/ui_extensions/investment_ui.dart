import 'package:flutter/material.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// UI-specific extensions for Investment domain entities.
/// Keeps domain entities framework-agnostic by moving Color and IconData here.
/// Follows InvTrack Enterprise Rules #1.1 (Architecture - Layer Boundaries).

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

  /// Color representing this investment type
  Color get color {
    switch (this) {
      case InvestmentType.p2pLending:
        return const Color(0xFF3B82F6); // Blue
      case InvestmentType.fixedDeposit:
        return const Color(0xFF10B981); // Emerald
      case InvestmentType.bonds:
        return const Color(0xFFF59E0B); // Amber
      case InvestmentType.realEstate:
        return const Color(0xFFEC4899); // Pink
      case InvestmentType.privateEquity:
        return const Color(0xFF8B5CF6); // Purple
      case InvestmentType.angelInvesting:
        return const Color(0xFF06B6D4); // Cyan
      case InvestmentType.chitFunds:
        return const Color(0xFFF97316); // Orange
      case InvestmentType.gold:
        return const Color(0xFFFFD700); // Gold
      case InvestmentType.crypto:
        return const Color(0xFF8B5CF6); // Purple
      case InvestmentType.mutualFunds:
        return const Color(0xFF3B82F6); // Blue
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
        return const Color(0xFF8B5CF6); // Purple
      case DocumentType.image:
        return const Color(0xFFEC4899); // Pink
      case DocumentType.other:
        return const Color(0xFF6B7280); // Gray
    }
  }
}

