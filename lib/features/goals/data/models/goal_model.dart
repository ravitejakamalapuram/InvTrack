import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Firestore model for Goal entity
class GoalModel {
  /// Convert GoalEntity to Firestore document
  static Map<String, dynamic> toFirestore(GoalEntity goal) {
    return {
      'name': goal.name,
      'type': goal.type.name,
      'targetAmount': goal.targetAmount,
      'targetMonthlyIncome': goal.targetMonthlyIncome,
      'targetDate': goal.targetDate != null 
          ? Timestamp.fromDate(goal.targetDate!) 
          : null,
      'trackingMode': goal.trackingMode.name,
      'linkedInvestmentIds': goal.linkedInvestmentIds,
      'linkedTypes': goal.linkedTypes.map((t) => t.name).toList(),
      'icon': goal.icon,
      'colorValue': goal.colorValue,
      'isArchived': goal.isArchived,
      'createdAt': Timestamp.fromDate(goal.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Firestore document to GoalEntity
  static GoalEntity fromFirestore(Map<String, dynamic> data, String id) {
    return GoalEntity(
      id: id,
      name: data['name'] as String,
      type: GoalType.fromString(data['type'] as String),
      targetAmount: (data['targetAmount'] as num).toDouble(),
      targetMonthlyIncome: data['targetMonthlyIncome'] != null 
          ? (data['targetMonthlyIncome'] as num).toDouble() 
          : null,
      targetDate: data['targetDate'] != null 
          ? (data['targetDate'] as Timestamp).toDate() 
          : null,
      trackingMode: GoalTrackingMode.fromString(data['trackingMode'] as String),
      linkedInvestmentIds: List<String>.from(data['linkedInvestmentIds'] ?? []),
      linkedTypes: (data['linkedTypes'] as List<dynamic>?)
          ?.map((t) => InvestmentType.fromString(t as String))
          .toList() ?? [],
      icon: data['icon'] as String? ?? GoalIcons.defaultIcon,
      colorValue: data['colorValue'] as int? ?? GoalColors.defaultColor.toARGB32(),
      isArchived: data['isArchived'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}

