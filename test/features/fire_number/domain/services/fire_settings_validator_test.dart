import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_settings_validator.dart';

void main() {
  late FireSettingsValidator validator;
  late FireSettingsEntity validSettings;

  setUp(() {
    validator = FireSettingsValidator();
    validSettings = FireSettingsEntity(
      id: 'test-1',
      monthlyExpenses: 50000,
      safeWithdrawalRate: 4.0,
      currentAge: 30,
      targetFireAge: 45,
      lifeExpectancy: 85,
      inflationRate: 6.0,
      preRetirementReturn: 12.0,
      postRetirementReturn: 8.0,
      healthcareBuffer: 20.0,
      emergencyMonths: 6,
      fireType: FireType.regular,
      monthlyPassiveIncome: 0,
      expectedPension: 0,
      isSetupComplete: true,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );
  });

  group('FireSettingsValidator', () {
    test('validates valid settings successfully', () {
      final result = validator.validate(validSettings);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejects current age below 18', () {
      final settings = validSettings.copyWith(currentAge: 17);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
      expect(result.errors, contains('Current age must be between 18 and 100'));
    });

    test('rejects current age above 100', () {
      final settings = validSettings.copyWith(currentAge: 101);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('rejects target FIRE age less than current age', () {
      final settings = validSettings.copyWith(
        currentAge: 40,
        targetFireAge: 35,
      );
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains('Target FIRE age must be greater than current age'),
      );
    });

    test('rejects target FIRE age above 100', () {
      final settings = validSettings.copyWith(targetFireAge: 101);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('rejects life expectancy less than target FIRE age', () {
      final settings = validSettings.copyWith(
        targetFireAge: 50,
        lifeExpectancy: 45,
      );
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('rejects zero monthly expenses', () {
      final settings = validSettings.copyWith(monthlyExpenses: 0);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains('Monthly expenses must be greater than zero'),
      );
    });

    test('rejects negative monthly expenses', () {
      final settings = validSettings.copyWith(monthlyExpenses: -1000);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('rejects zero safe withdrawal rate', () {
      final settings = validSettings.copyWith(safeWithdrawalRate: 0);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('rejects SWR above 10%', () {
      final settings = validSettings.copyWith(safeWithdrawalRate: 11);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('rejects negative inflation rate', () {
      final settings = validSettings.copyWith(inflationRate: -1);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('rejects negative passive income', () {
      final settings = validSettings.copyWith(monthlyPassiveIncome: -1000);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('rejects negative expected pension', () {
      final settings = validSettings.copyWith(expectedPension: -1000);
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
    });

    test('validateOrThrow throws on invalid settings', () {
      final settings = validSettings.copyWith(monthlyExpenses: 0);
      expect(
        () => validator.validateOrThrow(settings),
        throwsA(isA<FireSettingsValidationException>()),
      );
    });

    test('validateOrThrow does not throw on valid settings', () {
      expect(() => validator.validateOrThrow(validSettings), returnsNormally);
    });

    test('collects multiple errors', () {
      final settings = validSettings.copyWith(
        currentAge: 15,
        monthlyExpenses: 0,
        safeWithdrawalRate: 0,
      );
      final result = validator.validate(settings);
      expect(result.isValid, isFalse);
      expect(result.errors.length, greaterThanOrEqualTo(3));
    });
  });
}
