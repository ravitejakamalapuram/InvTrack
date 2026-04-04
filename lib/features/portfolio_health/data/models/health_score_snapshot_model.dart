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
    final data = doc.data() as Map<String, dynamic>;
    return HealthScoreSnapshotModel(
      id: doc.id,
      overallScore: (data['overallScore'] as num).toDouble(),
      returnsScore: (data['returnsScore'] as num).toDouble(),
      diversificationScore: (data['diversificationScore'] as num).toDouble(),
      liquidityScore: (data['liquidityScore'] as num).toDouble(),
      goalAlignmentScore: (data['goalAlignmentScore'] as num).toDouble(),
      actionReadinessScore: (data['actionReadinessScore'] as num).toDouble(),
      calculatedAt: (data['calculatedAt'] as Timestamp).toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
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
        other.calculatedAt == calculatedAt;
  }

  @override
  int get hashCode => Object.hash(id, calculatedAt);
}
