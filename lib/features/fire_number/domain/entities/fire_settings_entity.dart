/// FIRE (Financial Independence, Retire Early) type variants
enum FireType {
  /// Minimal lifestyle - basic needs only
  lean,

  /// Current lifestyle maintained - recommended
  regular,

  /// Premium lifestyle with luxuries
  fat,

  /// Coasting - enough invested that compound growth handles retirement
  coast,

  /// Partial independence + part-time work
  barista;

  String get displayName {
    switch (this) {
      case FireType.lean:
        return 'Lean FIRE';
      case FireType.regular:
        return 'Regular FIRE';
      case FireType.fat:
        return 'Fat FIRE';
      case FireType.coast:
        return 'Coast FIRE';
      case FireType.barista:
        return 'Barista FIRE';
    }
  }

  String get description {
    switch (this) {
      case FireType.lean:
        return 'Minimalist lifestyle - basic needs only';
      case FireType.regular:
        return 'Maintain your current lifestyle comfortably';
      case FireType.fat:
        return 'Premium lifestyle with travel & luxuries';
      case FireType.coast:
        return 'Stop aggressive saving, let compound growth work';
      case FireType.barista:
        return 'Partial independence + part-time work';
    }
  }

  /// Expense multiplier for this FIRE type
  /// - Lean: 70% of regular expenses
  /// - Regular: 100% (base)
  /// - Fat: 150% of regular expenses
  /// - Coast/Barista: 100% (other calculations differ)
  double get expenseMultiplier {
    switch (this) {
      case FireType.lean:
        return 0.7;
      case FireType.regular:
        return 1.0;
      case FireType.fat:
        return 1.5;
      case FireType.coast:
        return 1.0;
      case FireType.barista:
        return 1.0;
    }
  }

  /// Parse from string (Firestore)
  static FireType fromString(String value) {
    return FireType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FireType.regular,
    );
  }
}

/// FIRE progress status
enum FireProgressStatus {
  /// No investments yet
  notStarted,

  /// More than 20% behind schedule
  behind,

  /// Within 10% of target pace
  onTrack,

  /// More than 10% ahead of schedule
  ahead,

  /// 100%+ reached - FIRE achieved!
  achieved,

  /// Coast FIRE number reached
  coasting;

  String get displayName {
    switch (this) {
      case FireProgressStatus.notStarted:
        return 'Not Started';
      case FireProgressStatus.behind:
        return 'Behind Schedule';
      case FireProgressStatus.onTrack:
        return 'On Track';
      case FireProgressStatus.ahead:
        return 'Ahead of Schedule';
      case FireProgressStatus.achieved:
        return 'FIRE Achieved!';
      case FireProgressStatus.coasting:
        return 'Coasting';
    }
  }
}

/// FIRE milestone types
enum FireMilestoneType {
  percent10(10, 'Getting Started'),
  percent25(25, 'Quarter Way'),
  percent50(50, 'Halfway There'),
  percent75(75, 'Final Stretch'),
  percent100(100, 'FIRE Achieved!'),
  coastAchieved(0, 'Coast FIRE');

  final int percentage;
  final String label;

  const FireMilestoneType(this.percentage, this.label);
}

/// FIRE Settings Entity - user's FIRE configuration
class FireSettingsEntity {
  final String id;

  // Core inputs
  final double monthlyExpenses;
  final double safeWithdrawalRate; // Default: 4.0
  final int currentAge;
  final int targetFireAge;
  final int lifeExpectancy; // Default: 85

  // Advanced inputs
  final double inflationRate; // Default: 6.0 (India)
  final double preRetirementReturn; // Default: 12.0
  final double postRetirementReturn; // Default: 8.0
  final double healthcareBuffer; // Default: 20.0 (percentage)
  final double emergencyMonths; // Default: 6

  // FIRE type selection
  final FireType fireType;

  // Other income
  final double monthlyPassiveIncome; // Rental, dividends, etc.
  final double expectedPension;

  // Metadata
  final bool isSetupComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FireSettingsEntity({
    required this.id,
    required this.monthlyExpenses,
    this.safeWithdrawalRate = 4.0,
    required this.currentAge,
    required this.targetFireAge,
    this.lifeExpectancy = 85,
    this.inflationRate = 6.0,
    this.preRetirementReturn = 12.0,
    this.postRetirementReturn = 8.0,
    this.healthcareBuffer = 20.0,
    this.emergencyMonths = 6,
    this.fireType = FireType.regular,
    this.monthlyPassiveIncome = 0,
    this.expectedPension = 0,
    this.isSetupComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Years until target FIRE age
  int get yearsToFire => targetFireAge - currentAge;

  /// Annual expenses (monthly × 12)
  double get annualExpenses => monthlyExpenses * 12;

  /// FIRE multiplier based on SWR (e.g., 4% → 25x)
  /// Returns default 25x if SWR is zero or negative to prevent division errors.
  double get fireMultiplier =>
      safeWithdrawalRate > 0 ? 100 / safeWithdrawalRate : 25.0;

  /// Create default settings for new users
  factory FireSettingsEntity.defaults({
    required String id,
    required int currentAge,
  }) {
    final now = DateTime.now();
    return FireSettingsEntity(
      id: id,
      monthlyExpenses: 50000, // ₹50K default for India
      currentAge: currentAge,
      targetFireAge: (currentAge + 15).clamp(currentAge + 5, 65),
      createdAt: now,
      updatedAt: now,
    );
  }

  FireSettingsEntity copyWith({
    String? id,
    double? monthlyExpenses,
    double? safeWithdrawalRate,
    int? currentAge,
    int? targetFireAge,
    int? lifeExpectancy,
    double? inflationRate,
    double? preRetirementReturn,
    double? postRetirementReturn,
    double? healthcareBuffer,
    double? emergencyMonths,
    FireType? fireType,
    double? monthlyPassiveIncome,
    double? expectedPension,
    bool? isSetupComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FireSettingsEntity(
      id: id ?? this.id,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      safeWithdrawalRate: safeWithdrawalRate ?? this.safeWithdrawalRate,
      currentAge: currentAge ?? this.currentAge,
      targetFireAge: targetFireAge ?? this.targetFireAge,
      lifeExpectancy: lifeExpectancy ?? this.lifeExpectancy,
      inflationRate: inflationRate ?? this.inflationRate,
      preRetirementReturn: preRetirementReturn ?? this.preRetirementReturn,
      postRetirementReturn: postRetirementReturn ?? this.postRetirementReturn,
      healthcareBuffer: healthcareBuffer ?? this.healthcareBuffer,
      emergencyMonths: emergencyMonths ?? this.emergencyMonths,
      fireType: fireType ?? this.fireType,
      monthlyPassiveIncome: monthlyPassiveIncome ?? this.monthlyPassiveIncome,
      expectedPension: expectedPension ?? this.expectedPension,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FireSettingsEntity &&
        other.id == id &&
        other.monthlyExpenses == monthlyExpenses &&
        other.safeWithdrawalRate == safeWithdrawalRate &&
        other.currentAge == currentAge &&
        other.targetFireAge == targetFireAge &&
        other.lifeExpectancy == lifeExpectancy &&
        other.inflationRate == inflationRate &&
        other.preRetirementReturn == preRetirementReturn &&
        other.postRetirementReturn == postRetirementReturn &&
        other.healthcareBuffer == healthcareBuffer &&
        other.emergencyMonths == emergencyMonths &&
        other.fireType == fireType &&
        other.monthlyPassiveIncome == monthlyPassiveIncome &&
        other.expectedPension == expectedPension &&
        other.isSetupComplete == isSetupComplete;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      monthlyExpenses,
      safeWithdrawalRate,
      currentAge,
      targetFireAge,
      lifeExpectancy,
      inflationRate,
      preRetirementReturn,
      postRetirementReturn,
      healthcareBuffer,
      emergencyMonths,
      fireType,
      monthlyPassiveIncome,
      expectedPension,
      isSetupComplete,
    );
  }

  @override
  String toString() {
    return 'FireSettingsEntity(id: $id, monthlyExpenses: $monthlyExpenses, '
        'fireType: $fireType, targetFireAge: $targetFireAge)';
  }

  /// Convert entity to JSON map for debugging and export purposes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'monthlyExpenses': monthlyExpenses,
      'safeWithdrawalRate': safeWithdrawalRate,
      'currentAge': currentAge,
      'targetFireAge': targetFireAge,
      'lifeExpectancy': lifeExpectancy,
      'inflationRate': inflationRate,
      'preRetirementReturn': preRetirementReturn,
      'postRetirementReturn': postRetirementReturn,
      'healthcareBuffer': healthcareBuffer,
      'emergencyMonths': emergencyMonths,
      'fireType': fireType.name,
      'monthlyPassiveIncome': monthlyPassiveIncome,
      'expectedPension': expectedPension,
      'isSetupComplete': isSetupComplete,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

