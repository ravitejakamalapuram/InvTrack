import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Pre-defined investment templates for quick-add functionality
/// These templates pre-fill common investment patterns to reduce friction
///
/// Note: Icon and color are stored as identifiers (string/int) to keep domain layer
/// platform-agnostic (Rule 1.1). UI extensions convert these to Flutter types.
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

  /// Icon identifier for the template (maps to Flutter IconData in UI layer)
  /// Uses Material Icons codePoint values
  final int iconCodePoint;

  /// Color value for the template (ARGB format)
  final int colorValue;

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
    required this.iconCodePoint,
    required this.colorValue,
    required this.emoji,
  });
}

/// Pre-defined templates for common investment types
/// Icon codepoints from Material Icons (account_balance_rounded: 0xe84a, handshake_rounded: 0xf4fc, etc.)
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
    iconCodePoint: 0xe84a, // Icons.account_balance_rounded
    colorValue: 0xFF10B981, // Emerald
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
    iconCodePoint: 0xf4fc, // Icons.handshake_rounded
    colorValue: 0xFF3B82F6, // Blue
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
    iconCodePoint: 0xe6c4, // Icons.pie_chart_rounded
    colorValue: 0xFF3B82F6, // Blue
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
    iconCodePoint: 0xe5d8, // Icons.monetization_on_rounded
    colorValue: 0xFFFFD700, // Gold
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
    iconCodePoint: 0xe1af, // Icons.description_rounded
    colorValue: 0xFFF59E0B, // Amber
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
    iconCodePoint: 0xf456, // Icons.repeat_rounded
    colorValue: 0xFF10B981, // Emerald
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
    iconCodePoint: 0xe318, // Icons.home_rounded
    colorValue: 0xFFEC4899, // Pink
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
