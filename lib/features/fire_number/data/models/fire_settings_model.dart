import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

/// Firestore model for FIRE Settings entity
class FireSettingsModel {
  /// Current schema version for FIRE settings.
  /// Increment this when making breaking changes to the data structure.
  static const int currentSchemaVersion = 1;

  /// Convert FireSettingsEntity to Firestore document
  static Map<String, dynamic> toFirestore(FireSettingsEntity settings) {
    return {
      'schemaVersion': currentSchemaVersion,
      'monthlyExpenses': settings.monthlyExpenses,
      'safeWithdrawalRate': settings.safeWithdrawalRate,
      'currentAge': settings.currentAge,
      'targetFireAge': settings.targetFireAge,
      'lifeExpectancy': settings.lifeExpectancy,
      'inflationRate': settings.inflationRate,
      'preRetirementReturn': settings.preRetirementReturn,
      'postRetirementReturn': settings.postRetirementReturn,
      'healthcareBuffer': settings.healthcareBuffer,
      'emergencyMonths': settings.emergencyMonths,
      'fireType': settings.fireType.name,
      'monthlyPassiveIncome': settings.monthlyPassiveIncome,
      'expectedPension': settings.expectedPension,
      'isSetupComplete': settings.isSetupComplete,
      'createdAt': Timestamp.fromDate(settings.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Firestore document to FireSettingsEntity
  static FireSettingsEntity fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return FireSettingsEntity(
      id: id,
      monthlyExpenses: (data['monthlyExpenses'] as num).toDouble(),
      safeWithdrawalRate: (data['safeWithdrawalRate'] as num?)?.toDouble() ?? 4.0,
      currentAge: data['currentAge'] as int,
      targetFireAge: data['targetFireAge'] as int,
      lifeExpectancy: data['lifeExpectancy'] as int? ?? 85,
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
      isSetupComplete: data['isSetupComplete'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

