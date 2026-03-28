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
