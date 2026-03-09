import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';

void main() {
  group('FireType', () {
    test('displayName returns correct names', () {
      expect(FireType.lean.displayName, 'Lean FIRE');
      expect(FireType.regular.displayName, 'Regular FIRE');
      expect(FireType.fat.displayName, 'Fat FIRE');
      expect(FireType.coast.displayName, 'Coast FIRE');
      expect(FireType.barista.displayName, 'Barista FIRE');
    });

    test('description returns correct descriptions', () {
      expect(
        FireType.lean.description,
        'Minimalist lifestyle - basic needs only',
      );
      expect(
        FireType.regular.description,
        'Maintain your current lifestyle comfortably',
      );
      expect(
        FireType.fat.description,
        'Premium lifestyle with travel & luxuries',
      );
      expect(
        FireType.coast.description,
        'Stop aggressive saving, let compound growth work',
      );
      expect(
        FireType.barista.description,
        'Partial independence + part-time work',
      );
    });

    test('expenseMultiplier returns correct values', () {
      expect(FireType.lean.expenseMultiplier, 0.7);
      expect(FireType.regular.expenseMultiplier, 1.0);
      expect(FireType.fat.expenseMultiplier, 1.5);
      expect(FireType.coast.expenseMultiplier, 1.0);
      expect(FireType.barista.expenseMultiplier, 1.0);
    });

    test('fromString returns correct enum value', () {
      expect(FireType.fromString('lean'), FireType.lean);
      expect(FireType.fromString('regular'), FireType.regular);
      expect(FireType.fromString('fat'), FireType.fat);
      expect(FireType.fromString('coast'), FireType.coast);
      expect(FireType.fromString('barista'), FireType.barista);
    });

    test('fromString returns default for unknown value', () {
      expect(FireType.fromString('unknown'), FireType.regular);
      expect(FireType.fromString(''), FireType.regular);
    });
  });

  group('FireProgressStatus', () {
    test('displayName returns correct names', () {
      expect(FireProgressStatus.notStarted.displayName, 'Not Started');
      expect(FireProgressStatus.behind.displayName, 'Behind Schedule');
      expect(FireProgressStatus.onTrack.displayName, 'On Track');
      expect(FireProgressStatus.ahead.displayName, 'Ahead of Schedule');
      expect(FireProgressStatus.achieved.displayName, 'FIRE Achieved!');
      expect(FireProgressStatus.coasting.displayName, 'Coasting');
    });
  });

  group('FireMilestoneType', () {
    test('percentage returns correct values', () {
      expect(FireMilestoneType.percent10.percentage, 10);
      expect(FireMilestoneType.percent25.percentage, 25);
      expect(FireMilestoneType.percent50.percentage, 50);
      expect(FireMilestoneType.percent75.percentage, 75);
      expect(FireMilestoneType.percent100.percentage, 100);
      expect(FireMilestoneType.coastAchieved.percentage, 0);
    });

    test('label returns correct labels', () {
      expect(FireMilestoneType.percent10.label, 'Getting Started');
      expect(FireMilestoneType.percent25.label, 'Quarter Way');
      expect(FireMilestoneType.percent50.label, 'Halfway There');
      expect(FireMilestoneType.percent75.label, 'Final Stretch');
      expect(FireMilestoneType.percent100.label, 'FIRE Achieved!');
      expect(FireMilestoneType.coastAchieved.label, 'Coast FIRE');
    });
  });

  group('FireSettingsEntity', () {
    late FireSettingsEntity testSettings;

    setUp(() {
      testSettings = FireSettingsEntity(
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
    });

    test('yearsToFire calculates correctly', () {
      expect(testSettings.yearsToFire, 15);
    });

    test('annualExpenses calculates correctly', () {
      expect(testSettings.annualExpenses, 600000);
    });

    test('fireMultiplier calculates correctly for 4% SWR', () {
      expect(testSettings.fireMultiplier, 25.0);
    });

    test('fireMultiplier calculates correctly for 3% SWR', () {
      final settings = testSettings.copyWith(safeWithdrawalRate: 3.0);
      expect(settings.fireMultiplier, closeTo(33.33, 0.01));
    });

    test('fireMultiplier returns default 25x when SWR is zero', () {
      final settings = testSettings.copyWith(safeWithdrawalRate: 0);
      expect(settings.fireMultiplier, 25.0);
    });

    test('fireMultiplier returns default 25x when SWR is negative', () {
      final settings = testSettings.copyWith(safeWithdrawalRate: -1);
      expect(settings.fireMultiplier, 25.0);
    });

    test('defaults factory creates correct default settings', () {
      final defaults = FireSettingsEntity.defaults(
        id: 'default-1',
        currentAge: 25,
      );

      expect(defaults.id, 'default-1');
      expect(defaults.currentAge, 25);
      expect(defaults.monthlyExpenses, 50000);
      expect(defaults.safeWithdrawalRate, 4.0);
      expect(defaults.targetFireAge, 40); // 25 + 15 = 40
      expect(defaults.isSetupComplete, false);
    });

    test('defaults factory clamps targetFireAge to valid range', () {
      final defaults = FireSettingsEntity.defaults(
        id: 'default-2',
        currentAge: 60,
      );

      // 60 + 15 = 75, but clamped to max 65
      expect(defaults.targetFireAge, 65);
    });

    test('copyWith creates new instance with updated values', () {
      final updated = testSettings.copyWith(
        monthlyExpenses: 75000,
        fireType: FireType.fat,
      );

      expect(updated.id, testSettings.id);
      expect(updated.monthlyExpenses, 75000);
      expect(updated.fireType, FireType.fat);
      expect(updated.currentAge, testSettings.currentAge);
    });

    test('toJson returns correct map', () {
      final json = testSettings.toJson();

      expect(json['id'], 'fire-1');
      expect(json['monthlyExpenses'], 50000);
      expect(json['safeWithdrawalRate'], 4.0);
      expect(json['currentAge'], 30);
      expect(json['targetFireAge'], 45);
      expect(json['fireType'], 'regular');
      expect(json['isSetupComplete'], true);
      expect(json['createdAt'], '2024-01-01T00:00:00.000');
      expect(json['updatedAt'], '2024-01-01T00:00:00.000');
    });
  });
}
