/// Reinvestment Opportunity Entity
///
/// Represents an idle cash opportunity with investment suggestions
library;

/// Type of reinvestment suggestion
enum ReinvestmentType {
  /// Fixed Deposit
  fixedDeposit,
  
  /// P2P Lending
  p2pLending,
  
  /// Top-up existing investment
  existingInvestment,
  
  /// Tax-saving instrument (ELSS, PPF, etc.)
  taxSaving,
  
  /// Other custom option
  other;

  String get displayName {
    switch (this) {
      case ReinvestmentType.fixedDeposit:
        return 'Fixed Deposit';
      case ReinvestmentType.p2pLending:
        return 'P2P Lending';
      case ReinvestmentType.existingInvestment:
        return 'Top-up Existing';
      case ReinvestmentType.taxSaving:
        return 'Tax Saving';
      case ReinvestmentType.other:
        return 'Other';
    }
  }
}

/// Investment suggestion for idle cash
class InvestmentSuggestion {
  final String id;
  final ReinvestmentType type;
  final String name;
  final String description;
  final double suggestedAmount;
  final double expectedReturn; // Annual % return
  final int tenureMonths;
  final String? existingInvestmentId; // For top-up suggestions
  
  const InvestmentSuggestion({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.suggestedAmount,
    required this.expectedReturn,
    required this.tenureMonths,
    this.existingInvestmentId,
  });

  @override
  String toString() => 'InvestmentSuggestion($name: $expectedReturn%)';
}

/// Reinvestment Opportunity
class ReinvestmentOpportunity {
  /// Unique identifier
  final String id;
  
  /// Related cash flow ID (the idle income)
  final String cashFlowId;
  
  /// Related investment ID
  final String investmentId;
  
  /// Available amount sitting idle
  final double availableAmount;
  
  /// Currency
  final String currency;
  
  /// Number of days the cash has been idle
  final int daysIdle;
  
  /// Date when income was received
  final DateTime receivedDate;
  
  /// Current savings account rate (for opportunity cost calculation)
  final double savingsRate;
  
  /// Benchmark rate (e.g., FD rate for comparison)
  final double benchmarkRate;
  
  /// Opportunity cost lost (per day/month)
  final double opportunityCostDaily;
  final double opportunityCostMonthly;
  
  /// Investment suggestions (3 options)
  final List<InvestmentSuggestion> suggestions;
  
  /// Created timestamp
  final DateTime createdAt;
  
  /// Last notified timestamp (for escalation tracking)
  final DateTime? lastNotifiedAt;
  
  /// Whether user dismissed this opportunity
  final bool isDismissed;
  
  /// Dismissal reason
  final String? dismissalReason;

  const ReinvestmentOpportunity({
    required this.id,
    required this.cashFlowId,
    required this.investmentId,
    required this.availableAmount,
    required this.currency,
    required this.daysIdle,
    required this.receivedDate,
    required this.savingsRate,
    required this.benchmarkRate,
    required this.opportunityCostDaily,
    required this.opportunityCostMonthly,
    required this.suggestions,
    required this.createdAt,
    this.lastNotifiedAt,
    this.isDismissed = false,
    this.dismissalReason,
  });

  /// Total opportunity cost lost so far
  double get totalOpportunityCostLost => opportunityCostDaily * daysIdle;

  /// Notification urgency level (1-3)
  int get urgencyLevel {
    if (daysIdle >= 14) return 3; // Final
    if (daysIdle >= 7) return 2;  // Follow-up
    if (daysIdle >= 3) return 1;  // Gentle
    return 0; // Not yet
  }

  /// Should notify user?
  bool get shouldNotify {
    if (isDismissed) return false;
    if (daysIdle < 3) return false;
    
    // Escalation schedule: Day 3, 7, 14
    if (daysIdle == 3 || daysIdle == 7 || daysIdle == 14) {
      return lastNotifiedAt == null ||
          DateTime.now().difference(lastNotifiedAt!).inHours > 23;
    }
    
    return false;
  }

  ReinvestmentOpportunity copyWith({
    String? id,
    String? cashFlowId,
    String? investmentId,
    double? availableAmount,
    String? currency,
    int? daysIdle,
    DateTime? receivedDate,
    double? savingsRate,
    double? benchmarkRate,
    double? opportunityCostDaily,
    double? opportunityCostMonthly,
    List<InvestmentSuggestion>? suggestions,
    DateTime? createdAt,
    DateTime? lastNotifiedAt,
    bool? isDismissed,
    String? dismissalReason,
  }) {
    return ReinvestmentOpportunity(
      id: id ?? this.id,
      cashFlowId: cashFlowId ?? this.cashFlowId,
      investmentId: investmentId ?? this.investmentId,
      availableAmount: availableAmount ?? this.availableAmount,
      currency: currency ?? this.currency,
      daysIdle: daysIdle ?? this.daysIdle,
      receivedDate: receivedDate ?? this.receivedDate,
      savingsRate: savingsRate ?? this.savingsRate,
      benchmarkRate: benchmarkRate ?? this.benchmarkRate,
      opportunityCostDaily: opportunityCostDaily ?? this.opportunityCostDaily,
      opportunityCostMonthly: opportunityCostMonthly ?? this.opportunityCostMonthly,
      suggestions: suggestions ?? this.suggestions,
      createdAt: createdAt ?? this.createdAt,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
      isDismissed: isDismissed ?? this.isDismissed,
      dismissalReason: dismissalReason ?? this.dismissalReason,
    );
  }

  @override
  String toString() {
    return 'ReinvestmentOpportunity(availableAmount: $availableAmount, '
        'daysIdle: $daysIdle, urgencyLevel: $urgencyLevel)';
  }
}
