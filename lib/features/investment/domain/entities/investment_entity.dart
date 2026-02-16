import 'package:flutter/material.dart';

// ============ NEW ENUMS FOR ENHANCED DATA CAPTURE ============

/// How interest/income is paid out
enum InterestPayoutMode {
  cumulative, // Reinvested, paid at maturity
  periodic, // Paid at regular intervals
  atMaturity; // Single payout at end

  String get displayName {
    switch (this) {
      case InterestPayoutMode.cumulative:
        return 'Cumulative';
      case InterestPayoutMode.periodic:
        return 'Periodic';
      case InterestPayoutMode.atMaturity:
        return 'At Maturity';
    }
  }

  String get description {
    switch (this) {
      case InterestPayoutMode.cumulative:
        return 'Interest reinvested, paid at maturity';
      case InterestPayoutMode.periodic:
        return 'Interest paid at regular intervals';
      case InterestPayoutMode.atMaturity:
        return 'Full amount paid at maturity';
    }
  }

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

  static InterestPayoutMode? fromString(String? value) {
    if (value == null) return null;
    return InterestPayoutMode.values.cast<InterestPayoutMode?>().firstWhere(
          (e) => e?.name == value,
          orElse: () => null,
        );
  }
}

/// Risk level of the investment
enum RiskLevel {
  low,
  medium,
  high,
  veryHigh;

  String get displayName {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.veryHigh:
        return 'Very High Risk';
    }
  }

  String get description {
    switch (this) {
      case RiskLevel.low:
        return 'Capital protection, stable returns (FDs, Govt Bonds)';
      case RiskLevel.medium:
        return 'Moderate risk with better returns (Corporate Bonds, P2P)';
      case RiskLevel.high:
        return 'Higher risk for higher returns (Stocks, MFs)';
      case RiskLevel.veryHigh:
        return 'Speculative, potential for significant loss (Crypto, Angel)';
    }
  }

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

  static RiskLevel? fromString(String? value) {
    if (value == null) return null;
    return RiskLevel.values.cast<RiskLevel?>().firstWhere(
          (e) => e?.name == value,
          orElse: () => null,
        );
  }
}

/// How often interest is compounded
enum CompoundingFrequency {
  daily,
  monthly,
  quarterly,
  semiAnnual,
  annual,
  none; // Simple interest

  String get displayName {
    switch (this) {
      case CompoundingFrequency.daily:
        return 'Daily';
      case CompoundingFrequency.monthly:
        return 'Monthly';
      case CompoundingFrequency.quarterly:
        return 'Quarterly';
      case CompoundingFrequency.semiAnnual:
        return 'Semi-Annual';
      case CompoundingFrequency.annual:
        return 'Annual';
      case CompoundingFrequency.none:
        return 'Simple Interest';
    }
  }

  /// Number of compounding periods per year
  int get periodsPerYear {
    switch (this) {
      case CompoundingFrequency.daily:
        return 365;
      case CompoundingFrequency.monthly:
        return 12;
      case CompoundingFrequency.quarterly:
        return 4;
      case CompoundingFrequency.semiAnnual:
        return 2;
      case CompoundingFrequency.annual:
        return 1;
      case CompoundingFrequency.none:
        return 0; // Simple interest
    }
  }

  static CompoundingFrequency? fromString(String? value) {
    if (value == null) return null;
    return CompoundingFrequency.values.cast<CompoundingFrequency?>().firstWhere(
          (e) => e?.name == value,
          orElse: () => null,
        );
  }
}

// ============ EXISTING ENUMS ============

/// Income frequency for investments that pay regular income
enum IncomeFrequency {
  monthly,
  quarterly,
  semiAnnual,
  annual;

  String get displayName {
    switch (this) {
      case IncomeFrequency.monthly:
        return 'Monthly';
      case IncomeFrequency.quarterly:
        return 'Quarterly';
      case IncomeFrequency.semiAnnual:
        return 'Semi-Annual';
      case IncomeFrequency.annual:
        return 'Annual';
    }
  }

  /// Number of months between income payments
  int get monthsBetweenPayments {
    switch (this) {
      case IncomeFrequency.monthly:
        return 1;
      case IncomeFrequency.quarterly:
        return 3;
      case IncomeFrequency.semiAnnual:
        return 6;
      case IncomeFrequency.annual:
        return 12;
    }
  }

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

  static IncomeFrequency? fromString(String? value) {
    if (value == null) return null;
    return IncomeFrequency.values.cast<IncomeFrequency?>().firstWhere(
      (e) => e?.name == value,
      orElse: () => null,
    );
  }
}

/// Investment Status - lifecycle states
enum InvestmentStatus {
  open,
  closed;

  String get displayName {
    switch (this) {
      case InvestmentStatus.open:
        return 'Open';
      case InvestmentStatus.closed:
        return 'Closed';
    }
  }

  static InvestmentStatus fromString(String value) {
    return InvestmentStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => InvestmentStatus.open,
    );
  }
}

/// Investment Types - for alternative investments
enum InvestmentType {
  p2pLending,
  fixedDeposit,
  bonds,
  realEstate,
  privateEquity,
  angelInvesting,
  chitFunds,
  gold,
  crypto,
  mutualFunds,
  stocks,
  invoiceDiscounting,
  financing,
  other;

  String get displayName {
    switch (this) {
      case InvestmentType.p2pLending:
        return 'P2P Lending';
      case InvestmentType.fixedDeposit:
        return 'Fixed Deposit';
      case InvestmentType.bonds:
        return 'Bonds/Debentures';
      case InvestmentType.realEstate:
        return 'Real Estate';
      case InvestmentType.privateEquity:
        return 'Private Equity';
      case InvestmentType.angelInvesting:
        return 'Angel Investing';
      case InvestmentType.chitFunds:
        return 'Chit Funds';
      case InvestmentType.gold:
        return 'Gold/Commodities';
      case InvestmentType.crypto:
        return 'Crypto';
      case InvestmentType.mutualFunds:
        return 'Mutual Funds';
      case InvestmentType.stocks:
        return 'Stocks';
      case InvestmentType.invoiceDiscounting:
        return 'Invoice Discounting';
      case InvestmentType.financing:
        return 'Financing';
      case InvestmentType.other:
        return 'Other';
    }
  }

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

  static InvestmentType fromString(String value) {
    return InvestmentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InvestmentType.other,
    );
  }
}

/// Investment Entity for Cash Flow Tracker
class InvestmentEntity {
  final String id;
  final String name;
  final InvestmentType type;
  final InvestmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? closedAt;
  final DateTime updatedAt;

  /// Date when this investment matures (for FDs, bonds, etc.)
  final DateTime? maturityDate;

  /// Frequency of expected income (for income-generating investments)
  final IncomeFrequency? incomeFrequency;

  /// Whether this investment is archived (hidden from active view)
  final bool isArchived;

  // ============ NEW ENHANCED DATA CAPTURE FIELDS ============

  /// Start date of the investment (when principal was invested)
  final DateTime? startDate;

  /// Expected/advertised rate of return (annual %)
  /// e.g., FD at 7.5%, P2P platform promising 12%
  final double? expectedRate;

  /// Investment tenure in months
  /// e.g., 12 months FD, 36 months bond
  final int? tenureMonths;

  /// Platform/institution name
  /// e.g., "SBI", "LenDenClub", "Grip Invest"
  final String? platform;

  /// How interest/income is paid out
  final InterestPayoutMode? interestPayoutMode;

  /// Whether auto-renewal is enabled (for FDs, bonds)
  final bool? autoRenewal;

  /// Risk level of the investment
  final RiskLevel? riskLevel;

  /// How often interest is compounded
  final CompoundingFrequency? compoundingFrequency;

  /// Primary/display currency for this investment
  /// All cash flows will be converted to this currency for display
  /// Default: 'USD' for backward compatibility
  final String currency;

  const InvestmentEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.notes,
    required this.createdAt,
    this.closedAt,
    required this.updatedAt,
    this.maturityDate,
    this.incomeFrequency,
    this.isArchived = false,
    // New fields - all optional for backward compatibility
    this.startDate,
    this.expectedRate,
    this.tenureMonths,
    this.platform,
    this.interestPayoutMode,
    this.autoRenewal,
    this.riskLevel,
    this.compoundingFrequency,
    this.currency = 'USD', // Default for backward compatibility
  });

  bool get isOpen => status == InvestmentStatus.open;
  bool get isClosed => status == InvestmentStatus.closed;

  /// Whether this investment has a maturity date set
  bool get hasMaturityDate => maturityDate != null;

  /// Whether this investment pays regular income
  bool get hasIncomeSchedule => incomeFrequency != null;

  /// Whether this investment has start date set
  bool get hasStartDate => startDate != null;

  /// Whether this investment has expected rate set
  bool get hasExpectedRate => expectedRate != null && expectedRate! > 0;

  /// Whether this investment has tenure defined
  bool get hasTenure => tenureMonths != null && tenureMonths! > 0;

  /// Whether this investment has platform info
  bool get hasPlatform => platform != null && platform!.isNotEmpty;

  /// Calculate maturity date from startDate + tenureMonths if not set directly
  DateTime? get calculatedMaturityDate {
    if (maturityDate != null) return maturityDate;
    if (startDate != null && tenureMonths != null) {
      return DateTime(
        startDate!.year,
        startDate!.month + tenureMonths!,
        startDate!.day,
      );
    }
    return null;
  }

  /// Get remaining tenure in days (null if no maturity info)
  int? get remainingDays {
    final maturity = calculatedMaturityDate;
    if (maturity == null) return null;
    final now = DateTime.now();
    if (maturity.isBefore(now)) return 0;
    return maturity.difference(now).inDays;
  }

  InvestmentEntity copyWith({
    String? id,
    String? name,
    InvestmentType? type,
    InvestmentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? closedAt,
    DateTime? updatedAt,
    DateTime? maturityDate,
    IncomeFrequency? incomeFrequency,
    bool? isArchived,
    // New fields
    DateTime? startDate,
    double? expectedRate,
    int? tenureMonths,
    String? platform,
    InterestPayoutMode? interestPayoutMode,
    bool? autoRenewal,
    RiskLevel? riskLevel,
    CompoundingFrequency? compoundingFrequency,
    String? currency,
  }) {
    return InvestmentEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      maturityDate: maturityDate ?? this.maturityDate,
      incomeFrequency: incomeFrequency ?? this.incomeFrequency,
      isArchived: isArchived ?? this.isArchived,
      // New fields
      startDate: startDate ?? this.startDate,
      expectedRate: expectedRate ?? this.expectedRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      platform: platform ?? this.platform,
      interestPayoutMode: interestPayoutMode ?? this.interestPayoutMode,
      autoRenewal: autoRenewal ?? this.autoRenewal,
      riskLevel: riskLevel ?? this.riskLevel,
      compoundingFrequency: compoundingFrequency ?? this.compoundingFrequency,
      currency: currency ?? this.currency,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvestmentEntity &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.status == status &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.closedAt == closedAt &&
        other.updatedAt == updatedAt &&
        other.maturityDate == maturityDate &&
        other.incomeFrequency == incomeFrequency &&
        other.isArchived == isArchived &&
        // New fields
        other.startDate == startDate &&
        other.expectedRate == expectedRate &&
        other.tenureMonths == tenureMonths &&
        other.platform == platform &&
        other.interestPayoutMode == interestPayoutMode &&
        other.autoRenewal == autoRenewal &&
        other.riskLevel == riskLevel &&
        other.compoundingFrequency == compoundingFrequency &&
        other.currency == currency;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      type,
      status,
      notes,
      createdAt,
      closedAt,
      updatedAt,
      maturityDate,
      incomeFrequency,
      isArchived,
      // New fields
      startDate,
      expectedRate,
      tenureMonths,
      platform,
      interestPayoutMode,
      autoRenewal,
      riskLevel,
      compoundingFrequency,
      currency,
    );
  }
}
