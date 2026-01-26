import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Configuration for which enhanced fields to show for each investment type.
/// This makes the form dynamic and type-specific, reducing cognitive load.
class InvestmentFormConfig {
  /// Whether to show start date field
  final bool showStartDate;

  /// Whether to show expected rate field
  final bool showExpectedRate;

  /// Whether to show tenure field
  final bool showTenure;

  /// Whether to show platform field
  final bool showPlatform;

  /// Whether to show interest payout mode field
  final bool showPayoutMode;

  /// Whether to show auto renewal field
  final bool showAutoRenewal;

  /// Whether to show risk level field
  final bool showRiskLevel;

  /// Whether to show compounding frequency field
  final bool showCompoundingFrequency;

  const InvestmentFormConfig({
    this.showStartDate = false,
    this.showExpectedRate = false,
    this.showTenure = false,
    this.showPlatform = false,
    this.showPayoutMode = false,
    this.showAutoRenewal = false,
    this.showRiskLevel = false,
    this.showCompoundingFrequency = false,
  });

  /// Returns the form configuration for a given investment type
  static InvestmentFormConfig forType(InvestmentType type) {
    switch (type) {
      // Fixed-income with tenure and compounding
      case InvestmentType.fixedDeposit:
        return const InvestmentFormConfig(
          showStartDate: true,
          showExpectedRate: true,
          showTenure: true,
          showPlatform: true,
          showPayoutMode: true,
          showAutoRenewal: true,
          showCompoundingFrequency: true,
        );

      // P2P Lending - platform-based with risk
      case InvestmentType.p2pLending:
        return const InvestmentFormConfig(
          showStartDate: true,
          showExpectedRate: true,
          showTenure: true,
          showPlatform: true,
          showRiskLevel: true,
        );

      // Bonds - fixed income with payout mode
      case InvestmentType.bonds:
        return const InvestmentFormConfig(
          showStartDate: true,
          showExpectedRate: true,
          showTenure: true,
          showPlatform: true,
          showPayoutMode: true,
          showRiskLevel: true,
        );

      // Invoice Discounting - short tenure, platform-based
      case InvestmentType.invoiceDiscounting:
        return const InvestmentFormConfig(
          showStartDate: true,
          showExpectedRate: true,
          showTenure: true,
          showPlatform: true,
          showRiskLevel: true,
        );

      // Gold/SGB - long term with expected rate
      case InvestmentType.gold:
        return const InvestmentFormConfig(
          showStartDate: true,
          showExpectedRate: true,
          showTenure: true,
          showPlatform: true,
        );

      // Mutual Funds - platform and risk based
      case InvestmentType.mutualFunds:
        return const InvestmentFormConfig(
          showStartDate: true,
          showPlatform: true,
          showRiskLevel: true,
        );

      // Stocks - platform and risk based
      case InvestmentType.stocks:
        return const InvestmentFormConfig(
          showStartDate: true,
          showPlatform: true,
          showRiskLevel: true,
        );

      // Real Estate - platform based (REITs, fractional)
      case InvestmentType.realEstate:
        return const InvestmentFormConfig(
          showStartDate: true,
          showExpectedRate: true,
          showPlatform: true,
        );

      // Private Equity - high risk, long term
      case InvestmentType.privateEquity:
        return const InvestmentFormConfig(
          showStartDate: true,
          showPlatform: true,
          showRiskLevel: true,
        );

      // Angel Investing - very high risk
      case InvestmentType.angelInvesting:
        return const InvestmentFormConfig(
          showStartDate: true,
          showPlatform: true,
          showRiskLevel: true,
        );

      // Crypto - platform and high risk
      case InvestmentType.crypto:
        return const InvestmentFormConfig(
          showStartDate: true,
          showPlatform: true,
          showRiskLevel: true,
        );

      // Chit Funds - tenure based
      case InvestmentType.chitFunds:
        return const InvestmentFormConfig(
          showStartDate: true,
          showTenure: true,
          showPlatform: true,
        );

      // Financing - rate and tenure
      case InvestmentType.financing:
        return const InvestmentFormConfig(
          showStartDate: true,
          showExpectedRate: true,
          showTenure: true,
          showPlatform: true,
        );

      // Other - minimal fields
      case InvestmentType.other:
        return const InvestmentFormConfig(
          showStartDate: true,
          showPlatform: true,
        );
    }
  }
}

