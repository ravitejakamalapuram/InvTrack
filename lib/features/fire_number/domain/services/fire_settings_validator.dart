/// Validator for FIRE settings to ensure valid data before saving.
library;

import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

/// Validation result containing either success or error details.
class FireSettingsValidationResult {
  final bool isValid;
  final List<String> errors;

  const FireSettingsValidationResult.valid()
    : isValid = true,
      errors = const [];

  const FireSettingsValidationResult.invalid(this.errors) : isValid = false;

  @override
  String toString() {
    if (isValid) return 'Valid';
    return 'Invalid: ${errors.join(', ')}';
  }
}

/// Validator for FIRE settings.
/// Ensures all values are within acceptable ranges before persisting.
class FireSettingsValidator {
  /// Validates the given FIRE settings entity.
  /// Returns a result with any validation errors found.
  FireSettingsValidationResult validate(FireSettingsEntity settings) {
    final errors = <String>[];

    // Age validations
    if (settings.currentAge < 18 || settings.currentAge > 100) {
      errors.add('Current age must be between 18 and 100');
    }

    if (settings.targetFireAge < settings.currentAge) {
      errors.add('Target FIRE age must be greater than current age');
    }

    if (settings.targetFireAge > 100) {
      errors.add('Target FIRE age must be 100 or less');
    }

    if (settings.lifeExpectancy < settings.targetFireAge) {
      errors.add('Life expectancy must be greater than target FIRE age');
    }

    if (settings.lifeExpectancy > 120) {
      errors.add('Life expectancy must be 120 or less');
    }

    // Financial validations
    if (settings.monthlyExpenses <= 0) {
      errors.add('Monthly expenses must be greater than zero');
    }

    if (settings.safeWithdrawalRate <= 0 || settings.safeWithdrawalRate > 10) {
      errors.add('Safe withdrawal rate must be between 0.1% and 10%');
    }

    if (settings.inflationRate < 0 || settings.inflationRate > 20) {
      errors.add('Inflation rate must be between 0% and 20%');
    }

    if (settings.preRetirementReturn < 0 || settings.preRetirementReturn > 30) {
      errors.add('Pre-retirement return must be between 0% and 30%');
    }

    if (settings.postRetirementReturn < 0 ||
        settings.postRetirementReturn > 20) {
      errors.add('Post-retirement return must be between 0% and 20%');
    }

    if (settings.healthcareBuffer < 0 || settings.healthcareBuffer > 100) {
      errors.add('Healthcare buffer must be between 0% and 100%');
    }

    if (settings.emergencyMonths < 0 || settings.emergencyMonths > 36) {
      errors.add('Emergency months must be between 0 and 36');
    }

    // Income validations
    if (settings.monthlyPassiveIncome < 0) {
      errors.add('Monthly passive income cannot be negative');
    }

    if (settings.expectedPension < 0) {
      errors.add('Expected pension cannot be negative');
    }

    // Passive income should not exceed expenses (warning level, but we'll allow it)
    // This is just data - users might have legitimate high passive income

    if (errors.isEmpty) {
      return const FireSettingsValidationResult.valid();
    }
    return FireSettingsValidationResult.invalid(errors);
  }

  /// Quick validation that throws on error - for use in notifiers.
  void validateOrThrow(FireSettingsEntity settings) {
    final result = validate(settings);
    if (!result.isValid) {
      throw FireSettingsValidationException(result.errors);
    }
  }
}

/// Exception thrown when FIRE settings validation fails.
class FireSettingsValidationException implements Exception {
  final List<String> errors;

  FireSettingsValidationException(this.errors);

  @override
  String toString() => 'Invalid FIRE settings: ${errors.join('; ')}';
}
