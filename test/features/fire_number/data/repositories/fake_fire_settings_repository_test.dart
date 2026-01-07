import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'mock_fire_settings_repository.dart';

void main() {
  late FakeFireSettingsRepository repository;

  setUp(() {
    repository = FakeFireSettingsRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  final testSettings = FireSettingsEntity(
    id: 'fire-1',
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

  group('FakeFireSettingsRepository - Basic CRUD', () {
    test('initial state has no settings', () async {
      final result = await repository.getSettings();
      expect(result, isNull);
    });

    test('saveSettings stores settings', () async {
      await repository.saveSettings(testSettings);

      expect(repository.settings, isNotNull);
      expect(repository.settings!.id, 'fire-1');
      expect(repository.settings!.monthlyExpenses, 50000);
    });

    test('getSettings returns saved settings', () async {
      await repository.saveSettings(testSettings);

      final result = await repository.getSettings();

      expect(result, isNotNull);
      expect(result!.id, 'fire-1');
      expect(result.currentAge, 30);
      expect(result.targetFireAge, 45);
    });

    test('saveSettings updates existing settings', () async {
      await repository.saveSettings(testSettings);
      final updated = testSettings.copyWith(monthlyExpenses: 75000);

      await repository.saveSettings(updated);

      final result = await repository.getSettings();
      expect(result!.monthlyExpenses, 75000);
    });

    test('deleteSettings removes settings', () async {
      await repository.saveSettings(testSettings);

      await repository.deleteSettings();

      final result = await repository.getSettings();
      expect(result, isNull);
    });

    test('hasCompletedSetup returns true when setup is complete', () async {
      await repository.saveSettings(testSettings);

      final result = await repository.hasCompletedSetup();

      expect(result, isTrue);
    });

    test('hasCompletedSetup returns false when no settings', () async {
      final result = await repository.hasCompletedSetup();

      expect(result, isFalse);
    });

    test('hasCompletedSetup returns false when setup incomplete', () async {
      final incomplete = testSettings.copyWith(isSetupComplete: false);
      await repository.saveSettings(incomplete);

      final result = await repository.hasCompletedSetup();

      expect(result, isFalse);
    });
  });

  group('FakeFireSettingsRepository - Seed & Reset', () {
    test('seed populates repository with test data', () async {
      repository.seed(testSettings);

      final result = await repository.getSettings();
      expect(result, isNotNull);
      expect(result!.id, 'fire-1');
    });

    test('reset clears all data', () async {
      await repository.saveSettings(testSettings);

      repository.reset();

      final result = await repository.getSettings();
      expect(result, isNull);
    });
  });

  group('FakeFireSettingsRepository - Different FIRE Types', () {
    test('saves lean FIRE settings', () async {
      final leanSettings = testSettings.copyWith(fireType: FireType.lean);
      await repository.saveSettings(leanSettings);

      final result = await repository.getSettings();
      expect(result!.fireType, FireType.lean);
      expect(result.fireType.expenseMultiplier, 0.7);
    });

    test('saves fat FIRE settings', () async {
      final fatSettings = testSettings.copyWith(fireType: FireType.fat);
      await repository.saveSettings(fatSettings);

      final result = await repository.getSettings();
      expect(result!.fireType, FireType.fat);
      expect(result.fireType.expenseMultiplier, 1.5);
    });

    test('saves coast FIRE settings', () async {
      final coastSettings = testSettings.copyWith(fireType: FireType.coast);
      await repository.saveSettings(coastSettings);

      final result = await repository.getSettings();
      expect(result!.fireType, FireType.coast);
    });
  });
}

