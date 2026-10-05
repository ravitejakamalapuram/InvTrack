import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

/// Firestore model for FIRE Settings entity
class FireSettingsModel {
  /// Current schema version for FIRE settings.
  /// Increment this when making breaking changes to the data structure.
  ///
  /// 2: `birthYear` replaces the age entered at setup (`currentAge`, still
  /// written for older app versions), and amounts carry a `currency`.
  /// Version 1 documents are read with the birth year derived from
  /// `currentAge` and `createdAt`.
  static const int currentSchemaVersion = 2;

  /// Convert FireSettingsEntity to Firestore document
  static Map<String, dynamic> toFirestore(FireSettingsEntity settings) {
    return {
      'schemaVersion': currentSchemaVersion,
      'monthlyExpenses': settings.monthlyExpenses,
      'safeWithdrawalRate': settings.safeWithdrawalRate,
      'birthYear': settings.birthYear,
      // Older app versions read this as a required int.
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
      'otherAssets': settings.otherAssets,
      'monthlySip': settings.monthlySip,
      'currency': settings.currency,
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
    return FireSettingsEntity.fromMap(
      data,
      id: id,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
