/// Firestore model for Portfolio Health Score snapshots
///
/// Stored in: users/{userId}/healthScores/{snapshotId}
/// Weekly snapshots for historical trend tracking
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';

/// Firestore model for health score snapshot
class HealthScoreSnapshotModel {
  final String id;
  final double overallScore;
  final double returnsScore;
  final double diversificationScore;
  final double liquidityScore;
  final double goalAlignmentScore;
  final double actionReadinessScore;
  final DateTime calculatedAt;
  final Map<String, dynamic>? metadata; // For future extensions

  const HealthScoreSnapshotModel({
    required this.id,
    required this.overallScore,
    required this.returnsScore,
    required this.diversificationScore,
    required this.liquidityScore,
    required this.goalAlignmentScore,
    required this.actionReadinessScore,
    required this.calculatedAt,
    this.metadata,
  });

  /// Convert from domain entity
  factory HealthScoreSnapshotModel.fromEntity(
    PortfolioHealthScore entity, {
    String? id,
  }) {
    return HealthScoreSnapshotModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      overallScore: entity.overallScore,
      returnsScore: entity.returnsPerformance.score,
      diversificationScore: entity.diversification.score,
      liquidityScore: entity.liquidity.score,
      goalAlignmentScore: entity.goalAlignment.score,
      actionReadinessScore: entity.actionReadiness.score,
      calculatedAt: entity.calculatedAt,
    );
  }

  /// Convert from Firestore document
  factory HealthScoreSnapshotModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data();

    // Defensive null checks
    if (data == null) {
      throw const FormatException('Health score snapshot data is null');
    }

    if (data is! Map<String, dynamic>) {
      throw FormatException('Invalid health score snapshot data type: ${data.runtimeType}');
    }

    // Helper to safely extract numeric fields
    double _getDouble(String field) {
      final value = data[field];
      if (value == null) {
        throw FormatException('Missing required field: $field');
      }
      if (value is! num) {
        throw FormatException('Invalid type for $field: ${value.runtimeType}');
      }
      final doubleValue = value.toDouble();
      if (!doubleValue.isFinite) {
        throw FormatException('Invalid value for $field: $doubleValue');
      }
      return doubleValue;
    }

    // Extract calculatedAt
    final calculatedAtValue = data['calculatedAt'];
    if (calculatedAtValue == null) {
      throw const FormatException('Missing required field: calculatedAt');
    }
    if (calculatedAtValue is! Timestamp) {
      throw FormatException('Invalid type for calculatedAt: ${calculatedAtValue.runtimeType}');
    }

    return HealthScoreSnapshotModel(
      id: doc.id,
      overallScore: _getDouble('overallScore'),
      returnsScore: _getDouble('returnsScore'),
      diversificationScore: _getDouble('diversificationScore'),
      liquidityScore: _getDouble('liquidityScore'),
      goalAlignmentScore: _getDouble('goalAlignmentScore'),
      actionReadinessScore: _getDouble('actionReadinessScore'),
      calculatedAt: calculatedAtValue.toDate(),
      metadata: data['metadata'] is Map<String, dynamic>
          ? data['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'overallScore': overallScore,
      'returnsScore': returnsScore,
      'diversificationScore': diversificationScore,
      'liquidityScore': liquidityScore,
      'goalAlignmentScore': goalAlignmentScore,
      'actionReadinessScore': actionReadinessScore,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
      'metadata': metadata,
    };
  }

  /// Convert to simplified map for trend chart
  Map<String, dynamic> toChartData() {
    return {
      'date': calculatedAt.millisecondsSinceEpoch,
      'score': overallScore.round(),
      'returns': returnsScore.round(),
      'diversification': diversificationScore.round(),
      'liquidity': liquidityScore.round(),
      'goals': goalAlignmentScore.round(),
      'actions': actionReadinessScore.round(),
    };
  }

  HealthScoreSnapshotModel copyWith({
    String? id,
    double? overallScore,
    double? returnsScore,
    double? diversificationScore,
    double? liquidityScore,
    double? goalAlignmentScore,
    double? actionReadinessScore,
    DateTime? calculatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return HealthScoreSnapshotModel(
      id: id ?? this.id,
      overallScore: overallScore ?? this.overallScore,
      returnsScore: returnsScore ?? this.returnsScore,
      diversificationScore: diversificationScore ?? this.diversificationScore,
      liquidityScore: liquidityScore ?? this.liquidityScore,
      goalAlignmentScore: goalAlignmentScore ?? this.goalAlignmentScore,
      actionReadinessScore: actionReadinessScore ?? this.actionReadinessScore,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HealthScoreSnapshotModel &&
        other.id == id &&
        other.overallScore == overallScore &&
        other.returnsScore == returnsScore &&
        other.diversificationScore == diversificationScore &&
        other.liquidityScore == liquidityScore &&
        other.goalAlignmentScore == goalAlignmentScore &&
        other.actionReadinessScore == actionReadinessScore &&
        other.calculatedAt == calculatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        overallScore,
        returnsScore,
        diversificationScore,
        liquidityScore,
        goalAlignmentScore,
        actionReadinessScore,
        calculatedAt,
      );
}
