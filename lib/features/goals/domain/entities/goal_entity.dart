import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Goal type - what kind of target the user is aiming for
enum GoalType {
  targetAmount, // Accumulate a specific amount
  targetDate, // Reach amount by a specific date
  incomeTarget; // Monthly passive income goal

  String get displayName {
    switch (this) {
      case GoalType.targetAmount:
        return 'Target Amount';
      case GoalType.targetDate:
        return 'Target by Date';
      case GoalType.incomeTarget:
        return 'Income Target';
    }
  }

  String get description {
    switch (this) {
      case GoalType.targetAmount:
        return 'Accumulate a specific corpus';
      case GoalType.targetDate:
        return 'Reach your target by a deadline';
      case GoalType.incomeTarget:
        return 'Generate monthly passive income';
    }
  }

  static GoalType fromString(String value) {
    return GoalType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GoalType.targetAmount,
    );
  }
}

/// How the goal tracks investments
enum GoalTrackingMode {
  all, // Track all investments
  byType, // Track investments of specific types
  selected; // Track manually selected investments

  String get displayName {
    switch (this) {
      case GoalTrackingMode.all:
        return 'All Investments';
      case GoalTrackingMode.byType:
        return 'By Investment Type';
      case GoalTrackingMode.selected:
        return 'Selected Investments';
    }
  }

  String get description {
    switch (this) {
      case GoalTrackingMode.all:
        return 'Track progress across your entire portfolio';
      case GoalTrackingMode.byType:
        return 'Track investments of specific types (e.g., P2P, FDs)';
      case GoalTrackingMode.selected:
        return 'Choose specific investments to track';
    }
  }

  static GoalTrackingMode fromString(String value) {
    return GoalTrackingMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GoalTrackingMode.all,
    );
  }
}

/// Goal status based on progress
enum GoalStatus {
  notStarted,
  onTrack,
  ahead,
  behind,
  achieved,
  archived;

  String get displayName {
    switch (this) {
      case GoalStatus.notStarted:
        return 'Not Started';
      case GoalStatus.onTrack:
        return 'On Track';
      case GoalStatus.ahead:
        return 'Ahead';
      case GoalStatus.behind:
        return 'Behind';
      case GoalStatus.achieved:
        return 'Achieved';
      case GoalStatus.archived:
        return 'Archived';
    }
  }
}

/// Default goal icons for selection
class GoalIcons {
  static const List<String> available = [
    '🎯',
    '🏠',
    '🚗',
    '🎓',
    '💰',
    '🏝️',
    '👶',
    '💍',
    '🏦',
    '📈',
    '🛡️',
    '🎁',
    '🏥',
    '✈️',
    '🎮',
    '📱',
  ];

  static String get defaultIcon => '🎯';
}

/// Goal Entity - represents a financial goal
class GoalEntity {
  final String id;
  final String name;
  final GoalType type;
  final double targetAmount;
  final double? targetMonthlyIncome; // For income goals
  final DateTime? targetDate; // For time-bound goals
  final GoalTrackingMode trackingMode;
  final List<String> linkedInvestmentIds; // For 'selected' mode
  final List<InvestmentType> linkedTypes; // For 'byType' mode
  final String icon;
  final int colorValue;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String currency; // Multi-currency support (Rule 21.2)

  const GoalEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.targetAmount,
    this.targetMonthlyIncome,
    this.targetDate,
    required this.trackingMode,
    this.linkedInvestmentIds = const [],
    this.linkedTypes = const [],
    required this.icon,
    required this.colorValue,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.currency = 'USD', // Default for backward compatibility
  });

  /// Check if goal has a deadline
  bool get hasDeadline => targetDate != null;

  /// Check if this is an income-based goal
  bool get isIncomeGoal => type == GoalType.incomeTarget;

  /// Days remaining until target date (null if no deadline)
  int? get daysRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    return targetDate!.difference(now).inDays;
  }

  /// Whether the deadline has passed
  bool get isOverdue {
    if (targetDate == null) return false;
    return DateTime.now().isAfter(targetDate!);
  }

  GoalEntity copyWith({
    String? id,
    String? name,
    GoalType? type,
    double? targetAmount,
    double? targetMonthlyIncome,
    DateTime? targetDate,
    GoalTrackingMode? trackingMode,
    List<String>? linkedInvestmentIds,
    List<InvestmentType>? linkedTypes,
    String? icon,
    int? colorValue,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? currency,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
      targetMonthlyIncome: targetMonthlyIncome ?? this.targetMonthlyIncome,
      targetDate: targetDate ?? this.targetDate,
      trackingMode: trackingMode ?? this.trackingMode,
      linkedInvestmentIds: linkedInvestmentIds ?? this.linkedInvestmentIds,
      linkedTypes: linkedTypes ?? this.linkedTypes,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currency: currency ?? this.currency,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoalEntity &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.targetAmount == targetAmount &&
        other.targetMonthlyIncome == targetMonthlyIncome &&
        other.targetDate == targetDate &&
        other.trackingMode == trackingMode &&
        other.icon == icon &&
        other.colorValue == colorValue &&
        other.isArchived == isArchived &&
        other.currency == currency;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        type.hashCode ^
        targetAmount.hashCode ^
        targetMonthlyIncome.hashCode ^
        targetDate.hashCode ^
        trackingMode.hashCode ^
        icon.hashCode ^
        colorValue.hashCode ^
        isArchived.hashCode ^
        currency.hashCode;
  }
}
