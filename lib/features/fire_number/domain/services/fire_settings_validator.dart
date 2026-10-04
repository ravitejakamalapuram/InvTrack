/// Validator for FIRE settings to ensure valid data before saving.
library;

import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

/// Why FIRE settings were rejected. The screens show their own localised
/// text for each; [message] is English for logs and tests.
enum FireSettingsError {
  currentAgeOutOfRange('Current age must be between 18 and 100'),
  targetAgeNotAfterCurrent('Target FIRE age must be greater than current age'),
  targetAgeTooHigh('Target FIRE age must be 100 or less'),
  lifeExpectancyBeforeTarget(
    'Life expectancy must be greater than target FIRE age',
  ),
  lifeExpectancyTooHigh('Life expectancy must be 120 or less'),
  expensesNotPositive('Monthly expenses must be greater than zero'),
  withdrawalRateOutOfRange('Safe withdrawal rate must be between 0.1% and 10%'),
  inflationOutOfRange('Inflation rate must be between 0% and 20%'),
  preRetirementReturnOutOfRange(
    'Pre-retirement return must be between 0% and 30%',
  ),
  postRetirementReturnOutOfRange(
    'Post-retirement return must be between 0% and 20%',
  ),
  healthcareBufferOutOfRange('Healthcare buffer must be between 0% and 100%'),
  emergencyMonthsOutOfRange('Emergency months must be between 0 and 36'),
  passiveIncomeNegative('Monthly passive income cannot be negative'),
  pensionNegative('Expected pension cannot be negative'),
  otherAssetsNegative('Other assets cannot be negative'),
  monthlySipNegative('Monthly SIP cannot be negative');

  const FireSettingsError(this.message);

  final String message;
}

/// Validation result containing either success or error details.
class FireSettingsValidationResult {
  final bool isValid;
  final List<FireSettingsError> codes;

  const FireSettingsValidationResult.valid() : isValid = true, codes = const [];

  const FireSettingsValidationResult.invalid(this.codes) : isValid = false;

  /// [codes] in English.
  List<String> get errors => [for (final code in codes) code.message];

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
    final errors = <FireSettingsError>[];

    // Age validations
    if (settings.currentAge < 18 || settings.currentAge > 100) {
      errors.add(FireSettingsError.currentAgeOutOfRange);
    }

    if (settings.targetFireAge <= settings.currentAge) {
      errors.add(FireSettingsError.targetAgeNotAfterCurrent);
    }

    if (settings.targetFireAge > 100) {
      errors.add(FireSettingsError.targetAgeTooHigh);
    }

    if (settings.lifeExpectancy < settings.targetFireAge) {
      errors.add(FireSettingsError.lifeExpectancyBeforeTarget);
    }

    if (settings.lifeExpectancy > 120) {
      errors.add(FireSettingsError.lifeExpectancyTooHigh);
    }

    // Financial validations
    if (settings.monthlyExpenses <= 0) {
      errors.add(FireSettingsError.expensesNotPositive);
    }

    if (settings.safeWithdrawalRate <= 0 || settings.safeWithdrawalRate > 10) {
      errors.add(FireSettingsError.withdrawalRateOutOfRange);
    }

    if (settings.inflationRate < 0 || settings.inflationRate > 20) {
      errors.add(FireSettingsError.inflationOutOfRange);
    }

    if (settings.preRetirementReturn < 0 || settings.preRetirementReturn > 30) {
      errors.add(FireSettingsError.preRetirementReturnOutOfRange);
    }

    if (settings.postRetirementReturn < 0 ||
        settings.postRetirementReturn > 20) {
      errors.add(FireSettingsError.postRetirementReturnOutOfRange);
    }

    if (settings.healthcareBuffer < 0 || settings.healthcareBuffer > 100) {
      errors.add(FireSettingsError.healthcareBufferOutOfRange);
    }

    if (settings.emergencyMonths < 0 || settings.emergencyMonths > 36) {
      errors.add(FireSettingsError.emergencyMonthsOutOfRange);
    }

    // Income validations
    if (settings.monthlyPassiveIncome < 0) {
      errors.add(FireSettingsError.passiveIncomeNegative);
    }

    if (settings.expectedPension < 0) {
      errors.add(FireSettingsError.pensionNegative);
    }

    if (settings.otherAssets < 0) {
      errors.add(FireSettingsError.otherAssetsNegative);
    }

    final sip = settings.monthlySip;
    if (sip != null && sip < 0) {
      errors.add(FireSettingsError.monthlySipNegative);
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
      throw FireSettingsValidationException(result.codes);
    }
  }
}

/// Exception thrown when FIRE settings validation fails.
class FireSettingsValidationException implements Exception {
  final List<FireSettingsError> codes;

  FireSettingsValidationException(this.codes);

  /// [codes] in English.
  List<String> get errors => [for (final code in codes) code.message];

  @override
  String toString() => 'Invalid FIRE settings: ${errors.join('; ')}';
}
