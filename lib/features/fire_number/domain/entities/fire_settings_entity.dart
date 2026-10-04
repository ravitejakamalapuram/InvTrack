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

  /// Types offered when choosing. Coast and Barista FIRE never had a
  /// target of their own (they used Regular's), so they are no longer
  /// offered; settings that chose them still load.
  static const selectable = [lean, regular, fat];

  /// The type whose target this type uses: Regular for Coast and Barista.
  FireType get effective => switch (this) {
    coast || barista => regular,
    _ => this,
  };

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

/// Ages the FIRE age editors offer.
abstract final class FireAgeLimits {
  static const minCurrentAge = 18;
  static const maxCurrentAge = 75;
  static const maxTargetAge = 80;

  /// Target ages offered for someone [currentAge] old: always after the
  /// current age, with at least 5 to choose from.
  static ({int min, int max}) targetRange(int currentAge) {
    final min = currentAge + 1;
    return (min: min, max: min + 5 > maxTargetAge ? min + 5 : maxTargetAge);
  }
}

/// FIRE Settings Entity - user's FIRE configuration
///
/// Amounts ([monthlyExpenses], [monthlyPassiveIncome], [expectedPension],
/// [otherAssets], [monthlySip]) are in [currency].
class FireSettingsEntity {
  final String id;

  // Core inputs
  final double monthlyExpenses;
  final double safeWithdrawalRate; // Default: 4.0

  /// Year of birth. The age is worked out from it on the day it is needed,
  /// so it advances every year.
  final int birthYear;
  final int targetFireAge;

  /// Stored for older app versions; no calculation uses it.
  final int lifeExpectancy; // Default: 85

  // Advanced inputs
  final double inflationRate; // Default: 6.0 (India)
  final double preRetirementReturn; // Default: 12.0

  /// Stored for older app versions; no calculation uses it.
  final double postRetirementReturn; // Default: 8.0
  final double healthcareBuffer; // Default: 20.0 (percentage)
  final double emergencyMonths; // Default: 6

  // FIRE type selection
  final FireType fireType;

  // Other income
  final double monthlyPassiveIncome; // Rental, dividends, etc.
  final double expectedPension;

  /// Savings held outside InvTrack (EPF, bank balance, equity elsewhere),
  /// added to the FIRE corpus.
  final double otherAssets;

  /// What the user invests every month. Null: estimated from the last 12
  /// months of cash flows.
  final double? monthlySip;

  /// Currency of every amount. Null for settings saved before amounts had
  /// one: they are read in the base currency until they are saved again.
  final String? currency;

  // Metadata
  final bool isSetupComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FireSettingsEntity({
    required this.id,
    required this.monthlyExpenses,
    this.safeWithdrawalRate = 4.0,
    required this.birthYear,
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
    this.otherAssets = 0,
    this.monthlySip,
    this.currency,
    this.isSetupComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The birth year of someone who is [age] on [date].
  static int birthYearForAge(int age, DateTime date) => date.year - age;

  /// Age on [date]: whole years since [birthYear].
  int ageAt(DateTime date) => date.year - birthYear;

  /// Age today.
  int get currentAge => ageAt(DateTime.now());

  /// Years from [date] until [targetFireAge].
  int yearsToFireAt(DateTime date) => targetFireAge - ageAt(date);

  /// Years until target FIRE age
  int get yearsToFire => yearsToFireAt(DateTime.now());

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
      birthYear: birthYearForAge(currentAge, now),
      targetFireAge: (currentAge + 15).clamp(currentAge + 5, 65),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Reads settings from a stored map (Firestore or an export), with dates
  /// already parsed. Documents written before birth years were stored have
  /// `currentAge` instead: the age entered when the settings were created.
  factory FireSettingsEntity.fromMap(
    Map<String, dynamic> data, {
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool defaultIsSetupComplete = false,
  }) {
    final storedBirthYear = (data['birthYear'] as num?)?.toInt();
    return FireSettingsEntity(
      id: id,
      monthlyExpenses: (data['monthlyExpenses'] as num).toDouble(),
      safeWithdrawalRate:
          (data['safeWithdrawalRate'] as num?)?.toDouble() ?? 4.0,
      birthYear:
          storedBirthYear ??
          legacyBirthYear(
            currentAge: (data['currentAge'] as num).toInt(),
            createdAt: createdAt,
          ),
      targetFireAge: (data['targetFireAge'] as num).toInt(),
      lifeExpectancy: (data['lifeExpectancy'] as num?)?.toInt() ?? 85,
      inflationRate: (data['inflationRate'] as num?)?.toDouble() ?? 6.0,
      preRetirementReturn:
          (data['preRetirementReturn'] as num?)?.toDouble() ?? 12.0,
      postRetirementReturn:
          (data['postRetirementReturn'] as num?)?.toDouble() ?? 8.0,
      healthcareBuffer: (data['healthcareBuffer'] as num?)?.toDouble() ?? 20.0,
      emergencyMonths: (data['emergencyMonths'] as num?)?.toDouble() ?? 6,
      fireType: FireType.fromString(data['fireType'] as String? ?? 'regular'),
      monthlyPassiveIncome:
          (data['monthlyPassiveIncome'] as num?)?.toDouble() ?? 0,
      expectedPension: (data['expectedPension'] as num?)?.toDouble() ?? 0,
      otherAssets: (data['otherAssets'] as num?)?.toDouble() ?? 0,
      monthlySip: (data['monthlySip'] as num?)?.toDouble(),
      currency: data['currency'] as String?,
      isSetupComplete:
          data['isSetupComplete'] as bool? ?? defaultIsSetupComplete,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Reads settings exported with [toJson], including exports written
  /// before birth years and currencies were stored.
  factory FireSettingsEntity.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
    bool defaultIsSetupComplete = false,
  }) {
    final now = DateTime.now();
    return FireSettingsEntity.fromMap(
      json,
      id: json['id'] as String? ?? fallbackId ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      defaultIsSetupComplete: defaultIsSetupComplete,
    );
  }

  /// Birth year for settings that stored the age instead: the age was
  /// entered in setup, when the settings were created.
  static int legacyBirthYear({
    required int currentAge,
    required DateTime createdAt,
  }) => birthYearForAge(currentAge, createdAt);

  FireSettingsEntity copyWith({
    String? id,
    double? monthlyExpenses,
    double? safeWithdrawalRate,
    int? birthYear,
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
    double? otherAssets,
    double? monthlySip,
    bool clearMonthlySip = false,
    String? currency,
    bool? isSetupComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FireSettingsEntity(
      id: id ?? this.id,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      safeWithdrawalRate: safeWithdrawalRate ?? this.safeWithdrawalRate,
      birthYear: birthYear ?? this.birthYear,
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
      otherAssets: otherAssets ?? this.otherAssets,
      monthlySip: clearMonthlySip ? null : (monthlySip ?? this.monthlySip),
      currency: currency ?? this.currency,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// The same settings with every amount multiplied by [rate], which
  /// converts one unit of [currency] to [toCurrency].
  FireSettingsEntity convertedTo(String toCurrency, double rate) {
    final sip = monthlySip;
    return copyWith(
      monthlyExpenses: monthlyExpenses * rate,
      monthlyPassiveIncome: monthlyPassiveIncome * rate,
      expectedPension: expectedPension * rate,
      otherAssets: otherAssets * rate,
      monthlySip: sip == null ? null : sip * rate,
      currency: toCurrency,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FireSettingsEntity &&
        other.id == id &&
        other.monthlyExpenses == monthlyExpenses &&
        other.safeWithdrawalRate == safeWithdrawalRate &&
        other.birthYear == birthYear &&
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
        other.otherAssets == otherAssets &&
        other.monthlySip == monthlySip &&
        other.currency == currency &&
        other.isSetupComplete == isSetupComplete;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      monthlyExpenses,
      safeWithdrawalRate,
      birthYear,
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
      otherAssets,
      monthlySip,
      currency,
      isSetupComplete,
    ]);
  }

  @override
  String toString() {
    return 'FireSettingsEntity(id: $id, fireType: $fireType, '
        'targetFireAge: $targetFireAge)';
  }

  /// Convert entity to JSON map for debugging and export purposes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'monthlyExpenses': monthlyExpenses,
      'safeWithdrawalRate': safeWithdrawalRate,
      'birthYear': birthYear,
      // Read by app versions from before birth years were stored.
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
      'otherAssets': otherAssets,
      'monthlySip': monthlySip,
      'currency': currency,
      'isSetupComplete': isSetupComplete,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
