/// Expected Cash Flow Entity for Income Projections
///
/// Represents a predicted future income payment with ML-based amount prediction
/// and matching status tracking.
library;

/// Status of the expected cash flow
enum ExpectedCashFlowStatus {
  /// Payment is expected in the future (not yet due)
  upcoming,

  /// Payment is due within the next 24 hours
  dueSoon,

  /// Payment is overdue by 1-3 days (grace period)
  gracePeriod,

  /// Payment is overdue by 4+ days (escalation)
  overdue,

  /// Payment was received and matched
  received,

  /// Payment was manually marked as dismissed/not expected
  dismissed;
}

/// Source of the expected amount prediction
enum PredictionSource {
  /// Fixed amount from investment metadata (e.g., FD interest)
  fixed,

  /// Predicted using Weighted Moving Average (WMA)
  wma,

  /// Manually entered by user
  manual;
}

/// Expected Cash Flow Entity
class ExpectedCashFlowEntity {
  /// Unique identifier
  final String id;
  
  /// Related investment ID
  final String investmentId;
  
  /// Expected payment date
  final DateTime expectedDate;
  
  /// Predicted amount (can be ML-based or fixed)
  final double expectedAmount;
  
  /// Currency of the expected amount
  final String currency;
  
  /// Source of the prediction
  final PredictionSource predictionSource;
  
  /// Current status
  final ExpectedCashFlowStatus status;
  
  /// Matched actual cash flow ID (if received)
  final String? matchedCashFlowId;
  
  /// Actual amount received (if matched)
  final double? actualAmount;
  
  /// Actual date received (if matched)
  final DateTime? actualDate;
  
  /// Notes/reason for dismissal
  final String? notes;
  
  /// Created timestamp
  final DateTime createdAt;
  
  /// Last updated timestamp
  final DateTime updatedAt;
  
  /// Platform delay offset in days (learned from history)
  /// e.g., +2 days for LenDenClub
  final int? platformDelayDays;
  
  /// Variance factor (used for dynamic tolerance)
  /// Higher value = wider tolerance band
  final double? varianceFactor;

  const ExpectedCashFlowEntity({
    required this.id,
    required this.investmentId,
    required this.expectedDate,
    required this.expectedAmount,
    required this.currency,
    required this.predictionSource,
    required this.status,
    this.matchedCashFlowId,
    this.actualAmount,
    this.actualDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.platformDelayDays,
    this.varianceFactor,
  });

  /// Calculate tolerance band based on variance
  /// Returns [minAmount, maxAmount]
  List<double> get toleranceBand {
    if (varianceFactor == null || varianceFactor! < 0.05) {
      // Low variance: ±8%
      return [expectedAmount * 0.92, expectedAmount * 1.08];
    } else if (varianceFactor! < 0.15) {
      // Medium variance: ±12%
      return [expectedAmount * 0.88, expectedAmount * 1.12];
    } else {
      // High variance: ±15%
      return [expectedAmount * 0.85, expectedAmount * 1.15];
    }
  }

  /// Calculate date tolerance window based on platform delay
  /// Returns [earliestDate, latestDate]
  List<DateTime> get dateTolerance {
    final delayOffset = platformDelayDays ?? 0;
    return [
      expectedDate.subtract(Duration(days: 1)),
      expectedDate.add(Duration(days: 3 + delayOffset)),
    ];
  }

  /// Days overdue (0 if not overdue)
  int get daysOverdue {
    if (status == ExpectedCashFlowStatus.received ||
        status == ExpectedCashFlowStatus.dismissed) {
      return 0;
    }
    final now = DateTime.now();
    final daysDiff = now.difference(expectedDate).inDays;
    return daysDiff > 0 ? daysDiff : 0;
  }

  /// Is this payment within tolerance band?
  bool isWithinTolerance(double actualAmount, DateTime actualDate) {
    final amountBand = toleranceBand;
    final dateBand = dateTolerance;

    final amountOk = actualAmount >= amountBand[0] && actualAmount <= amountBand[1];
    final dateOk = !actualDate.isBefore(dateBand[0]) && !actualDate.isAfter(dateBand[1]);

    return amountOk && dateOk;
  }

  ExpectedCashFlowEntity copyWith({
    String? id,
    String? investmentId,
    DateTime? expectedDate,
    double? expectedAmount,
    String? currency,
    PredictionSource? predictionSource,
    ExpectedCashFlowStatus? status,
    String? matchedCashFlowId,
    double? actualAmount,
    DateTime? actualDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? platformDelayDays,
    double? varianceFactor,
  }) {
    return ExpectedCashFlowEntity(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      expectedDate: expectedDate ?? this.expectedDate,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      currency: currency ?? this.currency,
      predictionSource: predictionSource ?? this.predictionSource,
      status: status ?? this.status,
      matchedCashFlowId: matchedCashFlowId ?? this.matchedCashFlowId,
      actualAmount: actualAmount ?? this.actualAmount,
      actualDate: actualDate ?? this.actualDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      platformDelayDays: platformDelayDays ?? this.platformDelayDays,
      varianceFactor: varianceFactor ?? this.varianceFactor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpectedCashFlowEntity &&
        other.id == id &&
        other.investmentId == investmentId &&
        other.expectedDate == expectedDate &&
        other.expectedAmount == expectedAmount &&
        other.currency == currency &&
        other.predictionSource == predictionSource &&
        other.status == status &&
        other.matchedCashFlowId == matchedCashFlowId &&
        other.actualAmount == actualAmount &&
        other.actualDate == actualDate &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.platformDelayDays == platformDelayDays &&
        other.varianceFactor == varianceFactor;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      investmentId,
      expectedDate,
      expectedAmount,
      currency,
      predictionSource,
      status,
      matchedCashFlowId,
      actualAmount,
      actualDate,
      notes,
      createdAt,
      updatedAt,
      platformDelayDays,
      varianceFactor,
    );
  }

  @override
  String toString() {
    return 'ExpectedCashFlowEntity(id: $id, investmentId: $investmentId, '
        'expectedDate: $expectedDate, expectedAmount: $expectedAmount, '
        'status: $status, predictionSource: $predictionSource)';
  }
}
