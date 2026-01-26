import 'package:flutter/material.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Pre-defined investment templates for quick-add functionality
/// These templates pre-fill common investment patterns to reduce friction
class InvestmentTemplate {
  /// Unique identifier for the template
  final String id;

  /// Display name shown to user
  final String name;

  /// Short description of this investment type
  final String description;

  /// Pre-selected investment type
  final InvestmentType type;

  /// Suggested name prefix (e.g., "SBI FD", "LenDenClub")
  final String? suggestedNamePrefix;

  /// Typical expected annual return % (for display)
  final double? typicalRate;

  /// Default tenure in months
  final int? defaultTenureMonths;

  /// Default income frequency
  final IncomeFrequency? defaultIncomeFrequency;

  /// Default interest payout mode
  final InterestPayoutMode? defaultPayoutMode;

  /// Default risk level
  final RiskLevel? defaultRiskLevel;

  /// Default compounding frequency
  final CompoundingFrequency? defaultCompoundingFrequency;

  /// Icon for the template
  final IconData icon;

  /// Color for the template
  final Color color;

  /// Emoji for quick visual identification
  final String emoji;

  const InvestmentTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.suggestedNamePrefix,
    this.typicalRate,
    this.defaultTenureMonths,
    this.defaultIncomeFrequency,
    this.defaultPayoutMode,
    this.defaultRiskLevel,
    this.defaultCompoundingFrequency,
    required this.icon,
    required this.color,
    required this.emoji,
  });
}

/// Pre-defined templates for common investment types
class InvestmentTemplates {
  InvestmentTemplates._();

  static const fixedDeposit = InvestmentTemplate(
    id: 'fd',
    name: 'Fixed Deposit',
    description: 'Bank FD with guaranteed returns',
    type: InvestmentType.fixedDeposit,
    suggestedNamePrefix: 'FD - ',
    typicalRate: 7.0,
    defaultTenureMonths: 12,
    defaultIncomeFrequency: IncomeFrequency.quarterly,
    defaultPayoutMode: InterestPayoutMode.cumulative,
    defaultRiskLevel: RiskLevel.low,
    defaultCompoundingFrequency: CompoundingFrequency.quarterly,
    icon: Icons.account_balance_rounded,
    color: Color(0xFF10B981),
    emoji: '🏦',
  );

  static const p2pLending = InvestmentTemplate(
    id: 'p2p',
    name: 'P2P Lending',
    description: 'Peer-to-peer lending platforms',
    type: InvestmentType.p2pLending,
    suggestedNamePrefix: '',
    typicalRate: 12.0,
    defaultTenureMonths: 12,
    defaultIncomeFrequency: IncomeFrequency.monthly,
    defaultPayoutMode: InterestPayoutMode.periodic,
    defaultRiskLevel: RiskLevel.medium,
    defaultCompoundingFrequency: CompoundingFrequency.none,
    icon: Icons.handshake_rounded,
    color: Color(0xFF3B82F6),
    emoji: '🤝',
  );

  static const mutualFundSIP = InvestmentTemplate(
    id: 'sip',
    name: 'Mutual Fund SIP',
    description: 'Systematic Investment Plan',
    type: InvestmentType.mutualFunds,
    suggestedNamePrefix: 'SIP - ',
    typicalRate: 12.0,
    defaultTenureMonths: null,
    defaultIncomeFrequency: null,
    defaultPayoutMode: null,
    defaultRiskLevel: RiskLevel.medium,
    defaultCompoundingFrequency: null,
    icon: Icons.pie_chart_rounded,
    color: Color(0xFF3B82F6),
    emoji: '📊',
  );

  static const gold = InvestmentTemplate(
    id: 'gold',
    name: 'Gold/SGB',
    description: 'Physical gold or Sovereign Gold Bonds',
    type: InvestmentType.gold,
    suggestedNamePrefix: '',
    typicalRate: 2.5,
    defaultTenureMonths: 96,
    defaultIncomeFrequency: IncomeFrequency.semiAnnual,
    defaultPayoutMode: InterestPayoutMode.periodic,
    defaultRiskLevel: RiskLevel.low,
    defaultCompoundingFrequency: CompoundingFrequency.none,
    icon: Icons.monetization_on_rounded,
    color: Color(0xFFFFD700),
    emoji: '🪙',
  );

  static const bonds = InvestmentTemplate(
    id: 'bonds',
    name: 'Bonds/NCDs',
    description: 'Corporate bonds and debentures',
    type: InvestmentType.bonds,
    suggestedNamePrefix: '',
    typicalRate: 9.0,
    defaultTenureMonths: 36,
    defaultIncomeFrequency: IncomeFrequency.monthly,
    defaultPayoutMode: InterestPayoutMode.periodic,
    defaultRiskLevel: RiskLevel.medium,
    defaultCompoundingFrequency: CompoundingFrequency.none,
    icon: Icons.description_rounded,
    color: Color(0xFFF59E0B),
    emoji: '📜',
  );

  static const recurringDeposit = InvestmentTemplate(
    id: 'rd',
    name: 'Recurring Deposit',
    description: 'Monthly RD with fixed returns',
    type: InvestmentType.fixedDeposit,
    suggestedNamePrefix: 'RD - ',
    typicalRate: 6.5,
    defaultTenureMonths: 12,
    defaultIncomeFrequency: null,
    defaultPayoutMode: InterestPayoutMode.atMaturity,
    defaultRiskLevel: RiskLevel.low,
    defaultCompoundingFrequency: CompoundingFrequency.quarterly,
    icon: Icons.repeat_rounded,
    color: Color(0xFF10B981),
    emoji: '🔄',
  );

  static const rentalProperty = InvestmentTemplate(
    id: 'rental',
    name: 'Rental Property',
    description: 'Real estate with rental income',
    type: InvestmentType.realEstate,
    suggestedNamePrefix: '',
    typicalRate: 3.0,
    defaultTenureMonths: null,
    defaultIncomeFrequency: IncomeFrequency.monthly,
    defaultPayoutMode: InterestPayoutMode.periodic,
    defaultRiskLevel: RiskLevel.medium,
    defaultCompoundingFrequency: CompoundingFrequency.none,
    icon: Icons.home_rounded,
    color: Color(0xFFEC4899),
    emoji: '🏠',
  );

  /// All available templates
  static const List<InvestmentTemplate> all = [
    fixedDeposit,
    p2pLending,
    mutualFundSIP,
    gold,
    bonds,
    recurringDeposit,
    rentalProperty,
  ];

  /// Get template by ID
  static InvestmentTemplate? byId(String id) {
    return all.where((t) => t.id == id).firstOrNull;
  }
}

